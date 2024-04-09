import 'package:collection/collection.dart';
import 'package:watchtower/ecg_data.dart';

const heartRateUpdateRatio = 0.5;

abstract class Pipeline {
  abstract final String name;
  List<ECGData> apply(List<ECGData> input);
}

abstract class Detector {
  abstract final String name;
  int lastTimestamp = 0;
  List<int> lastResult = [];

  /// This should return a List containing the timestamps of peaks
  List<int> rawDetect(List<ECGData> input, List<ECGData> backtrackBuffer);

  /// Here provides a default implementation that utilizes caching. Override if needed.
  List<int> detect(List<ECGData> rawInput) {
    // use caching to avoid recalculation
    final currentLastTimestamp = rawInput.last.timestamp;
    if (currentLastTimestamp == lastTimestamp) {
      return lastResult;
    }

    final sliceStart =
        rawInput.indexWhere((e) => e.timestamp == lastTimestamp) + 1;
    final slice = ListSlice(rawInput, sliceStart, rawInput.length);
    final rawResult = rawDetect(slice, rawInput);

    lastResult = rawResult;
    lastTimestamp = currentLastTimestamp;
    return rawResult;
  }
}
