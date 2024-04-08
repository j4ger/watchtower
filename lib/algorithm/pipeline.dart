import 'package:collection/collection.dart';
import 'package:scidart/numdart.dart';
import 'package:watchtower/ecg_data.dart';

abstract class Pipeline {
  abstract final String name;
  Array apply(Array input);
}

abstract class Detector {
  abstract final String name;
  int lastTimestamp = 0;
  List<int> lastResult = [];

  /// This should return a List containing the timestamps of peaks
  List<int> rawDetect(Array input, int timestampStart, Array fullInput);

  List<int> detect(List<ECGData> rawInput, Array input) {
    // use caching to avoid recalculation
    final currentLastTimestamp = rawInput.last.timestamp;
    if (currentLastTimestamp == lastTimestamp) {
      return lastResult;
    }

    final sliceStart =
        rawInput.indexWhere((e) => e.timestamp == lastTimestamp) + 1;
    final sliceStartTimestamp = rawInput[sliceStart].timestamp;
    final slice = Array(input
        .getRange(sliceStart, input.length)
        .toList()); // TODO: optimize this
    final rawResult = rawDetect(slice, sliceStartTimestamp, input);

    final currentFirstTimestamp = rawInput.first.timestamp;
    final lastResultKeepStart =
        lastResult.indexWhere((e) => e > currentFirstTimestamp);
    final result = lastResultKeepStart == -1
        ? rawResult
        : lastResult.sublist(lastResultKeepStart) + rawResult;

    lastResult = result;
    lastTimestamp = currentLastTimestamp;
    return result;
  }
}
