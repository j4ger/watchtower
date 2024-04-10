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
  final CircularBuffer<int> signalPeaks = CircularBuffer(peakBufferCapacity);
  int lastPeakTimestamp = 0;

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

            final backtrackStart =
                lastPeakTimestamp - backtrackBuffer.first.timestamp;
            final backtrackData = ListSlice(
                backtrackBuffer,
                backtrackStart >= 0 ? backtrackStart : 0,
                peakTimestamp - backtrackBuffer.first.timestamp);
            final backtrackPeaks = arrayFindPeaks(backtrackData);

            for (final element in backtrackPeaks) {
              final timestamp = element.timestamp;
              final value = element.value;
              if ((timestamp > lastPeakTimestamp + minMissedDistance) &&
                  (timestamp < peakTimestamp - minMissedDistance) &&
                  (value > thresholdI2)) {
                if (missedPeakValue != null) {
                  if (element.value > missedPeakValue!) {
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
              signalPeaks[signalPeaks.length - 1] = missedPeakTimestamp!;
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
