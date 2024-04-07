import 'package:scidart/numdart.dart';
import 'package:watchtower/ecg_data.dart';

abstract class Pipeline {
  abstract final String name;
  Array apply(Array input);
}

abstract class Detector {
  abstract final String name;

  /// This should return a List containing the relative timestamps of peaks
  List<int> rawDetect(Array input);

  List<int> _indexTransform(List<ECGData> rawInput, List<int> peaks) =>
      peaks.map((e) => rawInput[e].timestamp).toList();

  List<int> detect(List<ECGData> rawInput, Array input) {
    // use caching to avoid recalculation
    print(
        "firstTimestamp: ${rawInput.first.timestamp}, lastTimestamp: ${rawInput.last.timestamp}");
    return _indexTransform(rawInput, rawDetect(input));
  }
}
