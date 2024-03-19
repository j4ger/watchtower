import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';

const defaultNumTaps = 1;

// TODO: cache filter coefficients generation

Array lowpass(int fs, double freq, Array input,
    {int numtaps = defaultNumTaps, String windowType = "blackman"}) {
  final nyq = fs / 2;
  final normalizeFreq = freq / nyq;

  final coeffs = firwin(numtaps, Array([normalizeFreq]),
      window: windowType, pass_zero: 'lowpass');

  return lfilter(coeffs, Array([1.0]), input);
}

Array highpass(int fs, double freq, Array input,
    {int numtaps = defaultNumTaps, String windowType = "blackman"}) {
  final nyq = fs / 2;
  final normalizeFreq = freq / nyq;

  final coeffs = firwin(numtaps, Array([normalizeFreq]),
      window: windowType, pass_zero: 'highpass');

  return lfilter(coeffs, Array([1.0]), input);
}
