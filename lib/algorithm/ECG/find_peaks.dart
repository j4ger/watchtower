import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';

List<int> findPeaksPanTompkins(Array input, int fs) {
  final diffed = arrayDiff(input);
  final squared = Array(diffed.map((element) => element * element).toList());
  final windowSize = (0.12 * fs).toInt();
  final window = ones(
      windowSize); // TODO: optimizations by implementing more efficient MWA
  final mwa = convolution(squared, window, fast: true);
  final zeroCompensation = (0.2 * fs).toInt();
  mwa.addAll(zeros(zeroCompensation));
// TODO: ecgFindPeaks
}

List<int> ecgFindPeaks(Array input, int fs) {}
