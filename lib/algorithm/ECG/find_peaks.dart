import 'package:collection/collection.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';
import 'package:watchtower/algorithm/pipeline.dart';

class PtPeakDetector extends Detector {
  @override
  final name = "Pan-Tompkins Peak Detector";

  late final int fs;
  late final EcgPeakDetector _detector;
  late final Array window;

  PtPeakDetector(this.fs) {
    _detector = EcgPeakDetector(fs);
    final windowSize = (0.12 * fs).toInt();
    window = ones(windowSize);
  }

  @override
  List<int> rawDetect(Array input, int timestampStart) {
    final diffed = arrayDiff(input);
    final squared = Array(diffed.map((element) => element * element).toList());
    final mwa = convolution(squared, window, fast: false);
    final zeroCompensation = (0.2 * fs).toInt();
    mwa.addAll(zeros(zeroCompensation));

    final peaks = _detector.rawDetect(mwa, timestampStart);

    return peaks;
  }
}

class EcgPeakDetector extends Detector {
  @override
  final name = "ECG Peak Detector";

  late final int minPeakDistance, minMissedDistance;
  double sPKI = 0.0, nPKI = 0.0;
  final List<int> signalPeaks = [];
  int lastPeak = 0, lastIndex = -1;

  EcgPeakDetector(int fs) {
    minPeakDistance = (0.3 * fs).toInt();
    minMissedDistance = (0.3 * fs).toInt();
  }

  @override
  List<int> rawDetect(Array input, int timestampStart) {
    final batchPeakStart = signalPeaks.length;
    final peaks = _findPeaks(input);
    peaks.forEachIndexed((index, element) {
      final (peakRawIndex, peakValue) = element;
      final peak = peakRawIndex + timestampStart;

      final thresholdI1 = nPKI + 0.25 * (sPKI - nPKI);
      print(
          "peak: ${peak}, lastPeak: ${lastPeak}, minPeakDistance: ${minPeakDistance}");
      if (peakValue > thresholdI1 && peak > lastPeak + minPeakDistance) {
        signalPeaks.add(peak);

        if (signalPeaks.length > 9) {
          final rrAve = (signalPeaks[signalPeaks.length - 2] -
                  signalPeaks[signalPeaks.length - 10]) /
              8;
          final rrMissed = (rrAve * 1.66).toInt();

          if (peak - lastPeak > rrMissed) {
            final thresholdI2 = 0.5 * thresholdI1;
            int? missedPeak;
            double? missedPeakValue;
            ListSlice(peaks, lastIndex + 1, index).forEach((element) {
              if ((element.$1 > lastPeak + minMissedDistance) &&
                  (element.$1 < peak - minMissedDistance) &&
                  (element.$2 > thresholdI2)) {
                if (missedPeakValue != null) {
                  if (element.$2 > missedPeakValue!) {
                    missedPeak = element.$1;
                    missedPeakValue = element.$2;
                  }
                } else {
                  missedPeak = element.$1;
                  missedPeakValue = element.$2;
                }
              }
            });

            if (missedPeak != null) {
              signalPeaks.insert(signalPeaks.length - 1, missedPeak!);
            }
          }
        }
        lastPeak = peak;
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

List<(int, double)> _findPeaks(Array a, {double? threshold}) {
  final N = a.length - 2;

  final List<(int, double)> result = [];

  if (threshold != null) {
    for (var i = 1; i <= N; i++) {
      if (a[i - 1] < a[i] && a[i] > a[i + 1] && a[i] >= threshold) {
        result.add((i, a[i]));
      }
    }
  } else {
    for (var i = 1; i <= N; i++) {
      if (a[i - 1] < a[i] && a[i] > a[i + 1]) {
        result.add((i, a[i]));
      }
    }
  }
  return result;
}
