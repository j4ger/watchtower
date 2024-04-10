// TODO: compensation for missing data

import 'package:watchtower/algorithm/digital_filters.dart';
import 'package:watchtower/algorithm/pipeline.dart';

import '../../ecg_data.dart';
import '../utils.dart';

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

class CleanNK extends Pipeline {
  @override
  final name = "NeuroKit.clean";

  late final DigitalFilter highpassFilter;
  late final Pipeline powerlineCleaner;

  CleanNK(super.fs) {
    highpassFilter = DigitalFilter.highpass(fs, 0.5);
    powerlineCleaner = CleanPowerline(fs);
  }

  @override
  List<ECGData> apply(List<ECGData> input) {
    final hp = highpassFilter.apply(input);
    final pwrLine = powerlineCleaner.apply(hp);
    return pwrLine;
  }
}
