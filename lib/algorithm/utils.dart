import '../ecg_data.dart';
import 'dart:math';

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

List<int> intListDiff(List<int> input) {
  List<int> differences = [];
  for (int i = 0; i < input.length - 1; i++) {
    differences.add(input[i + 1] - input[i]);
  }
  return differences;
}

int intListSum(List<int> input) => input.reduce((a, b) => a + b);

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

int arrayFindPeakByProminence(List<ECGData> input) {
  int result = -1;
  double maxProminence = double.negativeInfinity;

  for (int i = 1; i < input.length - 1; i++) {
    final value = input[i].value;
    if (value > input[i - 1].value && value > input[i + 1].value) {
      // Potential peak
      double leftBase = input[i - 1].value;
      double rightBase = input[i + 1].value;
      for (int j = i - 2; j >= 0; j--) {
        if (input[j].value < leftBase) {
          leftBase = input[j].value;
        }
      }
      for (int j = i + 2; j < input.length; j++) {
        if (input[j].value < rightBase) {
          rightBase = input[j].value;
        }
      }
      double prominence = value - max(leftBase, rightBase);
      if (prominence > maxProminence) {
        result = i;
        maxProminence = prominence;
      }
    }
  }

  return result;
}

List<ECGData> arrayGradient(List<ECGData> input) {
  final result = <ECGData>[];
  result.add(ECGData(input[0].timestamp, input[1].value - input[0].value));
  for (int i = 0; i < input.length - 2; i++) {
    result.add(ECGData(
        input[i + 1].timestamp, (input[i + 2].value - input[i].value) / 2));
  }
  result.add(ECGData(
      input.last.timestamp, input.last.value - input[input.length - 2].value));
  return result;
}

List<ECGData> arrayAbs(List<ECGData> input) => input.map((data) {
      data.value = data.value.abs();
      return data;
    }).toList();

List<ECGData> arrayMwaPadless(List<ECGData> input, int windowSize) {
  final paddingLength = windowSize - 1;

  final result = <ECGData>[];

  double sum = 0;
  for (int i = 0; i < paddingLength; i++) {
    sum = 0;
    for (int j = 0; j <= i; j++) {
      sum += input[j].value;
    }
    result.add(ECGData(input[i].timestamp, sum / (i + 1)));
  }

  for (int i = paddingLength; i < input.length; i++) {
    final removeIndex = i - windowSize;
    if (removeIndex >= 0) {
      // TODO: optimize this
      sum -= input[removeIndex].value;
    }
    sum += input[i].value;
    result.add(ECGData(input[i].timestamp, sum / windowSize));
  }

  return result;
}

List<ECGData> arrayMultiply(List<ECGData> input, double multiplier) =>
    input.map((element) {
      element.value = element.value * multiplier;
      return element;
    }).toList();

// TODO: rewrite using iterators
