import 'package:collection/collection.dart';

import '../../../ecg_data.dart';
import '../../detector.dart';
import '../../signal_processing/ecg_array_dsp.dart';

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
      final peakIndex =
          arrayFindPeakByProminence(ListSlice(smoothedBuffer, begin, end));
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
