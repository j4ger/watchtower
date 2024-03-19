// TODO: compensation for missing data

import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';
import 'package:watchtower/algorithm/digital_filters.dart';

Array cleanPT(Array input, int fs) {
  const numtaps = 9;
  final lp = lowpass(fs, 15, input, numtaps: numtaps);
  final hp = highpass(fs, 5, lp, numtaps: numtaps);
  return hp;
}

Array cleanPowerline(Array input, int fs) {
  // filter out 50Hz signal by applying a smoothing window
  // with the width of a period of 50Hz
  final width = fs ~/ 50;
  final window = ones(width);
  final conv = convolution(input, window, fast: true);
  return conv;
}

Array cleanNK(Array input, int fs) {
  const numtaps = 5;
  final hp = highpass(fs, 0.5, input, numtaps: numtaps);
  final pwrLine = cleanPowerline(hp, fs);
  return pwrLine;
}
