import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:fili.dart/iir_coeffs.dart';
import 'package:fili.dart/iir_filter.dart';
import 'package:fili.dart/calc_cascades.dart';

import '../ecg_data.dart';

const filterOrder = 3;

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

  List<ECGData> apply(List<ECGData> input) {
    // TODO: optimize this
    filter.reInit();
    final wrapper = ECGListWrapper(input);
    final result = filter.filtfilt(wrapper);
    return input
        .mapIndexed((index, e) => ECGData(e.timestamp, result[index]))
        .toList();
  }
}

class ECGListWrapper extends ListBase<double> {
  final List<ECGData> inner;
  ECGListWrapper(this.inner);

  @override
  set length(int newLength) => inner.length = newLength;
  @override
  int get length => inner.length;
  @override
  double operator [](int index) => inner[index].value;
  @override
  void operator []=(int index, double value) => inner[index].value = value;
}
