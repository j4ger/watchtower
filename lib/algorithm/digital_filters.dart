import 'package:fili.dart/iir_coeffs.dart';
import 'package:fili.dart/iir_filter.dart';
import 'package:fili.dart/calc_cascades.dart';

const filterOrder = 4;

class DigitalFilter {
  late final IirFilter filter;
  final coeffCalculator = CalcCascades();

  DigitalFilter.lowpass(int fs, double freq) {
    final filterCoeffs = coeffCalculator['lowpass'](FcFsParams(
        order: filterOrder,
        characteristic: 'bessel',
        Fs: fs.toDouble(),
        Fc: freq));
    filter = IirFilter(filterCoeffs);
  }

  DigitalFilter.highpass(int fs, double freq) {
    final filterCoeffs = coeffCalculator['highpass'](FcFsParams(
        order: filterOrder,
        characteristic: 'bessel',
        Fs: fs.toDouble(),
        Fc: freq));
    filter = IirFilter(filterCoeffs);
  }

  List<double> apply(List<double> input) => filter.filtfilt(input);
}
