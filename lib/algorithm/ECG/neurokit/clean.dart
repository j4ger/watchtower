import '../../../ecg_data.dart';
import '../../pipeline.dart';
import '../../signal_processing/digital_filters.dart';

/// adapted from: https://neuropsychology.github.io/NeuroKit/functions/ecg.html#preprocessing
class CleanBP extends Pipeline {
  @override
  final name = "Biosppy.clean";

  late final DigitalFilter highpassFilter;
  late final DigitalFilter lowpassFilter;

  CleanBP(super.fs) {
    highpassFilter = DigitalFilter.highpass(fs, 0.67);
    lowpassFilter = DigitalFilter.lowpass(fs, 45);
  }

  @override
  List<ECGData> apply(List<ECGData> input) {
    final hp = highpassFilter.apply(input);
    final lp = lowpassFilter.apply(hp);
    return lp;
  }
}
