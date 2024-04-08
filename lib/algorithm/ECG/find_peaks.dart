import 'package:collection/collection.dart';
import 'package:watchtower/algorithm/pipeline.dart';

import '../utils.dart';

class PtPeakDetector extends Detector {
  @override
  final name = "Pan-Tompkins Peak Detector";

  late final int fs;
  late final EcgPeakDetector _detector;
  late final int windowSize;

  PtPeakDetector(this.fs) {
    _detector = EcgPeakDetector(fs);
    windowSize = (0.12 * fs).toInt();
  }

  @override
  List<int> rawDetect(
      List<double> input, int timestampStart, List<double> fullInput) {
    final diffed = arrayDiff(input);
    final squared = arraySquare(diffed);
    final mwa = movingWindowAverage(squared, windowSize);

    final peaks = _detector.rawDetect(mwa, timestampStart, fullInput);

    return peaks;
  }
}

class EcgPeakDetector extends Detector {
  @override
  final name = "ECG Peak Detector";

  late final int minPeakDistance, minMissedDistance;
  double sPKI = 0.0, nPKI = 0.0;
  final List<int> signalPeaks = [];
  int lastPeakTimestamp = 0, lastIndex = -1;

  EcgPeakDetector(int fs) {
    minPeakDistance = (0.3 * fs).toInt();
    minMissedDistance = (0.3 * fs).toInt();
  }

  @override
  List<int> rawDetect(
      List<double> input, int timestampStart, List<double> fullInput) {
    final batchPeakStart = signalPeaks.length;
    final peaks = arrayFindPeaks(input);
    peaks.forEachIndexed((index, element) {
      final (peakRawIndex, peakValue) = element;
      final peakTimestamp = peakRawIndex + timestampStart;

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

            final fullInputFirstTimestamp =
                timestampStart + input.length - fullInput.length;
            final backtrackStart = lastPeakTimestamp - fullInputFirstTimestamp;
            final backtrackData = fullInput.sublist(
                backtrackStart, peakTimestamp - fullInputFirstTimestamp);
            final backtrackPeaks = arrayFindPeaks(backtrackData);

            backtrackPeaks.forEach((element) {
              final timestamp = element.$1 + backtrackStart;
              final value = element.$2;
              if ((timestamp > lastPeakTimestamp + minMissedDistance) &&
                  (timestamp < peakTimestamp - minMissedDistance) &&
                  (value > thresholdI2)) {
                if (missedPeakValue != null) {
                  if (element.$2 > missedPeakValue!) {
                    missedPeakTimestamp = timestamp;
                    missedPeakValue = value;
                  }
                } else {
                  missedPeakTimestamp = timestamp;
                  missedPeakValue = value;
                }
              }
            });

            if (missedPeakTimestamp != null) {
              print("backtrack success");
              signalPeaks.insert(signalPeaks.length - 1, missedPeakTimestamp!);
            }
          }
        }
        lastPeakTimestamp = peakTimestamp;
        lastIndex = index;
        sPKI = 0.125 * peakValue + 0.875 * sPKI;
      } else {
        nPKI = 0.125 * peakValue + 0.875 * nPKI;
      }
    });
    final batchPeakEnd = signalPeaks.length;
    return ListSlice(signalPeaks, batchPeakStart, batchPeakEnd);
  }
}
