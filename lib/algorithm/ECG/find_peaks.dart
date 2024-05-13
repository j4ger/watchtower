import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:watchtower/algorithm/pipeline.dart';

import '../../ecg_data.dart';
import '../utils.dart';

const peakBufferCapacity = 12;

class PtPeakDetector extends Detector {
  @override
  final name = "Pan-Tompkins Peak Detector";

  late final EcgPeakDetector _detector;
  late final int windowSize;

  PtPeakDetector(super.fs) {
    _detector = EcgPeakDetector(fs);
    windowSize = (fs * 0.075).toInt();
  }

  List<ECGData> preprocess(List<ECGData> input) {
    final diffed = arrayDiff(input);
    final squared = arraySquare(diffed);
    final mwa = movingWindowAverage(squared, windowSize,
        compensationLength: (fs * 0.2).toInt());

    return mwa;
  }

  @override
  List<int> rawDetect(List<ECGData> input, List<ECGData> backtrackBuffer) {
    final mwa = preprocess(input);

    final peaks = _detector.rawDetect(mwa,
        preprocess(backtrackBuffer) // TODO: optimize this, maybe lazy evaluate
        );

    return peaks;
  }
}

class EcgPeakDetector extends Detector {
  @override
  final name = "ECG Peak Detector";

  late final int minPeakDistance, minMissedDistance;
  double sPKI = 0.0, nPKI = 0.0;
  final signalPeaks = <int>[];
  int lastPeakTimestamp = -500;

  EcgPeakDetector(super.fs) {
    minPeakDistance = (0.3 * fs).toInt();
    minMissedDistance = (0.25 * fs).toInt();
  }

  @override
  List<int> rawDetect(List<ECGData> input, List<ECGData> backtrackBuffer) {
    final peaks = arrayFindPeaks(input);
    for (final element in peaks) {
      final peakValue = element.value;
      final peakTimestamp = element.timestamp;

      final thresholdI1 = nPKI + 0.25 * (sPKI - nPKI);
      if (peakValue > thresholdI1 &&
          peakTimestamp > lastPeakTimestamp + minPeakDistance) {
        signalPeaks.add(peakTimestamp);

        if (signalPeaks.length > 9) {
          final rrAve = (signalPeaks[signalPeaks.length - 2] -
                  signalPeaks[signalPeaks.length - 10]) /
              8;
          final rrMissed = (rrAve * 1.66).toInt();

          if (peakTimestamp - lastPeakTimestamp > rrMissed) {
            // backtrack
            print("backtrack triggered");
            final thresholdI2 = 0.5 * thresholdI1;
            int? missedPeakTimestamp;
            double? missedPeakValue;

            int backtrackStart = lastPeakTimestamp -
                backtrackBuffer.first.timestamp +
                minMissedDistance;
            int backtrackEnd = peakTimestamp -
                backtrackBuffer.first.timestamp -
                minMissedDistance;
            backtrackStart = backtrackStart > 0 ? backtrackStart : 0;
            backtrackEnd =
                backtrackEnd > backtrackStart ? backtrackEnd : backtrackStart;
            final backtrackData =
                ListSlice(backtrackBuffer, backtrackStart, backtrackEnd);
            final backtrackPeaks = arrayFindPeaks(backtrackData);

            for (final element in backtrackPeaks) {
              final timestamp = element.timestamp;
              final value = element.value;
              if (value > thresholdI2) {
                if (missedPeakValue != null) {
                  if (element.value > missedPeakValue) {
                    missedPeakTimestamp = timestamp;
                    missedPeakValue = value;
                  }
                } else {
                  missedPeakTimestamp = timestamp;
                  missedPeakValue = value;
                }
              }
            }

            if (missedPeakTimestamp != null) {
              print("backtrack success");
              final last = signalPeaks.last;
              signalPeaks[signalPeaks.length - 1] = missedPeakTimestamp;
              signalPeaks.add(last);
            }
          }
        }
        lastPeakTimestamp = peakTimestamp;
        sPKI = 0.125 * peakValue + 0.875 * sPKI;
      } else {
        nPKI = 0.125 * peakValue + 0.875 * nPKI;
      }
    }

    return signalPeaks.toList(); // TODO: optimize this?
  }
}

class NkPeakDetector extends Detector {
  @override
  final String name = "biopeaks detector";

  late final int smoothWindow, avgWindow;
  late final double minDelay;
  static const double smoothWindowRatio = 0.1,
      avgWindowRatio = 0.75,
      gradientThresholdWeight = 1.5,
      minLengthRatio = 0.4,
      minDelayRatio = 0.3;

  NkPeakDetector(super.fs) {
    smoothWindow = (smoothWindowRatio * fs).toInt();
    avgWindow = (avgWindowRatio * fs).toInt();
    minDelay = minDelayRatio * fs;
  }

  @override
  List<int> rawDetect(List<ECGData> input, List<ECGData> backtrackBuffer) {
    final gradientBuffer = arrayGradient(input);
    final absBuffer = arrayAbs(gradientBuffer);

    final smoothedBuffer = arrayMwaPadless(absBuffer, smoothWindow);
    final avgBuffer = arrayMwaPadless(smoothedBuffer, avgWindow);

    final gradientThreshold = arrayMultiply(avgBuffer, gradientThresholdWeight);

    final qrsResults = <(int, int, int)>[];
    bool inQRS = false;
    int startIndex = 0;
    for (int i = 0; i < input.length; i++) {
      if (inQRS) {
        // still inside of a QRS sequence
        // look for a negative edge
        if (smoothedBuffer[i].value < gradientThreshold[i].value) {
          // found negative edge, mark the end of a QRS sequence
          inQRS = false;

          final endIndex = i;
          final duration = endIndex - startIndex + 1;
          qrsResults.add((startIndex, endIndex, duration));
        }
      } else {
        // look for a positive edge
        if (smoothedBuffer[i].value > gradientThreshold[i].value) {
          // found positive edge, begin a new QRS sequence
          inQRS = true;
          // cleanup & init states
          startIndex = i;
        }
      }
    }

    final durationThreshold = qrsResults.map((group) => group.$3).sum /
        qrsResults.length *
        minLengthRatio;

    final result = [-fs]; // for convenience
    for (final (begin, end, duration) in qrsResults) {
      if (duration < durationThreshold) {
        // too short for a QRS sequence
        print("start: $begin, end: $end, dropped for too short");
        continue;
      }

      // TODO: filter QRS sequences that have at lease two peaks inside
      final peakIndex = arrayFindPeakByProminence(ListSlice(input, begin, end));
      if (peakIndex == -1) {
        print("start: $begin, end: $end, dropped for no peak found");
        // no peak found, skip
        continue;
      }
      final rPeakTimestamp = input[begin + peakIndex].timestamp;
      if (rPeakTimestamp - result.last > minDelay) {
        result.add(rPeakTimestamp);
      } else {
        print(
            "start: $begin, end: $end, peak: $rPeakTimestamp, prev: ${result.last}, dropped for too close to previous");
      }
    }

    result.removeAt(0);

    return result;
  }
}
