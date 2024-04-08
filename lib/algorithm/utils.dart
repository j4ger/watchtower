List<double> movingWindowAverage(List<double> input, int windowSize) {
  final List<double> averages = [];
  double windowSum = 0.0;

  // Calculate the initial window sum
  for (int i = 0; i < windowSize; i++) {
    windowSum += input[i];
  }
  averages.add(windowSum / windowSize);

  // Calculate the moving window average for the rest of the list
  for (int i = windowSize; i < input.length; i++) {
    windowSum += input[i] - input[i - windowSize];
    averages.add(windowSum / windowSize);
  }

  // Pad the end of the averages list to match the input length
  final padStartLength = (input.length - averages.length) ~/ 2;
  final padEndLength = input.length - averages.length - padStartLength;

  final padStart = averages.first;
  final padEnd = averages.last;
  for (int i = 0; i < padStartLength; i++) {
    averages.insert(0, padStart);
  }
  for (int i = 0; i < padEndLength; i++) {
    averages.add(padEnd);
  }

  return averages;
}

List<double> arrayDiff(List<double> input) {
  List<double> differences = [];
  for (int i = 0; i < input.length - 1; i++) {
    differences.add(input[i + 1] - input[i]);
  }

  differences.add(0); // pad the end

  return differences;
}

List<double> arraySquare(List<double> input) =>
    input.map((e) => e * e).toList();

List<(int, double)> arrayFindPeaks(List<double> a, {double? threshold}) {
  final N = a.length - 2;

  final List<(int, double)> result = [];

  if (threshold != null) {
    for (var i = 1; i <= N; i++) {
      if (a[i - 1] < a[i] && a[i] > a[i + 1] && a[i] >= threshold) {
        result.add((i, a[i]));
      }
    }
  } else {
    for (var i = 1; i <= N; i++) {
      if (a[i - 1] < a[i] && a[i] > a[i + 1]) {
        result.add((i, a[i]));
      }
    }
  }
  return result;
}
