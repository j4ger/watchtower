// TODO: compensation for missing data

import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';
import 'package:watchtower/algorithm/digital_filters.dart';
import 'package:watchtower/algorithm/pipeline.dart';

class CleanPT extends Pipeline {
  static const numtaps = 9;
  late final DigitalFilter lowpassFilter, highpassFilter;

  CleanPT(int fs) {
    lowpassFilter = DigitalFilter.lowpass(fs, 15, numtaps: numtaps);
    highpassFilter = DigitalFilter.highpass(fs, 5, numtaps: numtaps);
  }

  @override
  Array apply(Array input) {
    final lp = lowpassFilter.apply(input);
    final hp = highpassFilter.apply(lp);
    return hp;
  }
}

class CleanPowerline extends Pipeline {
  late final Array window;

  CleanPowerline(int fs) {
    final width = fs ~/ 50;
    window = ones(width);
  }

  @override
  Array apply(Array input) {
    final conv = convolution(input, window);
    return conv;
  }
}

class CleanNK extends Pipeline {
  static const numtaps = 5;
  late final DigitalFilter highpassFilter;
  late final Pipeline powerlineCleaner;

  CleanNK(int fs) {
    highpassFilter = DigitalFilter.highpass(fs, 0.5, numtaps: numtaps);
    powerlineCleaner = CleanPowerline(fs);
  }

  @override
  Array apply(Array input) {
    final hp = highpassFilter.apply(input);
    final pwrLine = powerlineCleaner.apply(hp);
    return pwrLine;
  }
}
