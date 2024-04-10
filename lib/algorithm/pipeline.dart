import 'package:collection/collection.dart';
import 'package:watchtower/ecg_data.dart';

const heartRateUpdateRatio = 0.5;

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
        rawInput.indexWhere((e) => e.timestamp == lastTimestamp) + 1;
    final slice = ListSlice(rawInput, sliceStart, rawInput.length);
    final rawResult = rawDetect(slice, rawInput);

    final newIndex = rawResult.indexWhere((e) => e > lastTimestamp);
    if (rawResult.length != 1 && newIndex != -1) {
      // new peaks were found
      final double newHeartRate;
      if (newIndex != 0) {
        // there are old peaks
        final lastOldTimestamp = rawResult[newIndex - 1];
        final lastNewTimestamp = rawResult.last;
        final count = rawResult.length - newIndex + 1;
        newHeartRate = 60 * fs / (lastNewTimestamp - lastOldTimestamp) * count;
      } else {
        // there are no old peaks
        final firstNewTimestamp = rawResult[newIndex];
        final lastNewTimestamp = rawResult.last;
        final count = rawResult.length - newIndex;
        newHeartRate = 60 * fs / (firstNewTimestamp - lastNewTimestamp) * count;
      }
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
