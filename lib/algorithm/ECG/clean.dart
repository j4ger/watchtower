import '../../ecg_data.dart';
import '../pipeline.dart';
import '../signal_processing/ecg_array_dsp.dart';

class CleanPowerline extends Pipeline {
  @override
  final name = "Clean powerline interference";

  late final int width;

  CleanPowerline(super.fs) {
    width = fs ~/ 50;
  }

  @override
  List<ECGData> apply(List<ECGData> input) {
    final conv = movingWindowAverage(input, width);
    return conv;
  }
}
