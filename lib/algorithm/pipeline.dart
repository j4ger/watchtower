import 'package:watchtower/ecg_data.dart';

abstract class Pipeline {
  abstract final String name;
  List<double> apply(List<double> input);
}

abstract class Detector {
  abstract final String name;
  int lastTimestamp = 0;
  List<int> lastResult = [];

  /// This should return a List containing the timestamps of peaks
  List<int> rawDetect(
      List<double> input, int timestampStart, List<double> fullInput);

  List<int> detect(List<ECGData> rawInput, List<double> input) {
    // use caching to avoid recalculation
    final currentLastTimestamp = rawInput.last.timestamp;
    if (currentLastTimestamp == lastTimestamp) {
      return lastResult;
    }

    final sliceStart =
        rawInput.indexWhere((e) => e.timestamp == lastTimestamp) + 1;
    final sliceStartTimestamp = rawInput[sliceStart].timestamp;
    final slice =
        input.sublist(sliceStart, input.length); // TODO: optimize this
    final rawResult = rawDetect(slice, sliceStartTimestamp, input);

    lastResult = rawResult;
    lastTimestamp = currentLastTimestamp;
    return rawResult;
  }
}
