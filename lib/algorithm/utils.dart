import '../ecg_data.dart';

// TODO: something here is causing a stable offset after applying
// fix it

List<ECGData> movingWindowAverage(List<ECGData> input, int windowSize,
    {int compensationLength = 0}) {
  // Pad both ends of the averages list to match the input length
  final actualLength = input.length - windowSize + 1;
  final padStartLength = (input.length - actualLength) ~/ 2;
  final padEndLength = input.length - actualLength - padStartLength;

  final List<ECGData> averages = [];
  double windowSum = 0.0;

  // Calculate the initial window sum
  for (int i = 0; i < windowSize; i++) {
    windowSum += input[i].value;
  }
  final padStart = windowSum / windowSize;
  for (int i = 0; i < padStartLength + 1; i++) {
    averages.add(ECGData(input[i].timestamp, padStart));
  }

  // Calculate the moving window average for the rest of the list
  final baseIndex = padStartLength - windowSize + 1;
  for (int i = windowSize; i < input.length; i++) {
    windowSum += input[i].value - input[i - windowSize].value;
    averages
        .add(ECGData(input[i + baseIndex].timestamp, windowSum / windowSize));
  }

  final padEndIndexStart = averages.length;
  final padEnd = averages.last.value;
  for (int i = 0; i < padEndLength; i++) {
    averages.add(ECGData(input[i + padEndIndexStart].timestamp, padEnd));
  }

  // TODO: optimize this
  for (int i = input.length - 1;
      i > input.length - 1 - compensationLength;
      i--) {
    averages[i].value = 0;
  }
  return averages;
}

List<ECGData> arrayDiff(List<ECGData> input) {
  List<ECGData> differences = [];
  for (int i = 0; i < input.length - 1; i++) {
    differences
        .add(ECGData(input[i].timestamp, input[i + 1].value - input[i].value));
  }

  differences.add(
      ECGData(input.last.timestamp + 1, differences.last.value)); // pad the end

  return differences;
}

List<ECGData> arraySquare(List<ECGData> input) =>
    input.map((e) => ECGData(e.timestamp, e.value * e.value)).toList();

List<ECGData> arrayFindPeaks(List<ECGData> a, {double? threshold}) {
  final N = a.length - 2;

  final List<ECGData> result = [];

  if (threshold != null) {
    for (var i = 1; i <= N; i++) {
      if (a[i - 1].value < a[i].value &&
          a[i].value > a[i + 1].value &&
          a[i].value >= threshold) {
        result.add(a[i]);
      }
    }
  } else {
    for (var i = 1; i <= N; i++) {
      if (a[i - 1].value < a[i].value && a[i].value > a[i + 1].value) {
        result.add(a[i]);
      }
    }
  }
  return result;
}
