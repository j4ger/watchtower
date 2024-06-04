import '../../../ecg_data.dart';
import '../../pipeline.dart';
import '../../signal_processing/digital_filters.dart';

class CleanPT extends Pipeline {
  @override
  final name = "Pan-Tompkins.clean";

  late final DigitalFilter lowpassFilter, highpassFilter;

  CleanPT(super.fs) {
    lowpassFilter = DigitalFilter.lowpass(fs, 15);
    highpassFilter = DigitalFilter.highpass(fs, 5);
  }

  @override
  List<ECGData> apply(List<ECGData> input) {
    final lp = lowpassFilter.apply(input);
    final hp = highpassFilter.apply(lp);
    return hp;
  }
}
