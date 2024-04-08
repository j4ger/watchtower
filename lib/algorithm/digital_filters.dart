import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';

const defaultNumTaps = 1;

class DigitalFilter {
  late final Array coefficients;

  DigitalFilter.lowpass(int fs, double freq,
      {int numtaps = defaultNumTaps, String windowType = "blackman"}) {
    final nyq = fs / 2;
    final normalizeFreq = freq / nyq;

    coefficients = firwin(numtaps, Array([normalizeFreq]),
        window: windowType, pass_zero: 'lowpass');
  }

  DigitalFilter.highpass(int fs, double freq,
      {int numtaps = defaultNumTaps, String windowType = "blackman"}) {
    final nyq = fs / 2;
    final normalizeFreq = freq / nyq;

    coefficients = firwin(numtaps, Array([normalizeFreq]),
        window: windowType, pass_zero: 'highpass');
  }

  Array apply(Array input) {
    final fowardResult = lfilter(coefficients, Array([1.0]), input);
    final backwardResult = lfilter(
        coefficients,
        Array([1.0]),
        arrayReverse(
            fowardResult)); // TODO: arrayReverse is unnecessarily expensive
    return arrayReverse(backwardResult);
  }
}
