import 'package:collection/collection.dart';
import 'package:watchtower/ecg_data.dart';

import '../buffer_controller.dart';

const heartRateUpdateRatio = 0.5;
const bufferLookbackLength = 6 * packLength;
const minimumPeaksForStable = 6;

abstract class Pipeline {
  late final int fs;
  Pipeline(this.fs);

  abstract final String name;
  List<ECGData> apply(List<ECGData> input);
}

abstract class Detector {
  late final int fs;
  Detector(this.fs);

  abstract final String name;
  int lastTimestamp = 0;
  List<int> lastResult = [];

  double? _heartRate;

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
        rawInput.indexWhere((e) => e.timestamp == lastTimestamp) +
            1 -
            bufferLookbackLength;
    final slice =
        ListSlice(rawInput, sliceStart > 0 ? sliceStart : 0, rawInput.length);
    final rawResult = rawDetect(slice, rawInput);

    if (rawResult.length > minimumPeaksForStable) {
      final newHeartRate =
          60 * fs / (rawResult.last - rawResult.first) * (rawResult.length + 1);
      if (_heartRate != null) {
        _heartRate = newHeartRate * heartRateUpdateRatio +
            _heartRate! * (1 - heartRateUpdateRatio);
      } else {
        _heartRate = newHeartRate;
      }
    }

    lastResult = rawResult;
    lastTimestamp = currentLastTimestamp;

    return rawResult;
  }

  double? get heartRate => _heartRate;
}
