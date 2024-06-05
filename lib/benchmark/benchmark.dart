import 'dart:io';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../ecg_data.dart';
import '../utils.dart';
import '../algorithm/ECG/pt/clean.dart';
import '../algorithm/ECG/neurokit/clean.dart';
import '../algorithm/ECG/pt/detect.dart';
import '../algorithm/ECG/neurokit/detect.dart';

/// determines how far off from a human annotation is acceptable
const benchmarkToleration = 80;

/// sample rate of benchmark input files
const fs = 360;

/// prompt user to select file, begin a benchmark
Future<void> promptBench() async {
  final String? path = (await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
          dialogTitle: "Select RECORDS filelist file"))
      ?.files[0]
      .path;
  if (path == null) {
    snackbar("Cancelled", "No file was selected.");
    return;
  }

  final pathSplit = path.split('/');
  final pathBase = pathSplit.take(pathSplit.length - 1).join('/');

  final file = File(path);
  final content = await file.readAsString();
  final result = <String>[];

  int sampleCountSum = 0, fpSum = 0, fnSum = 0;
  for (String line
      in content.split('\n').where((line) => line.trim().isNotEmpty)) {
    final filename = "$pathBase/$line.csv";
    final (sampleCount, fp, fn) = await bench(filename);
    final totalFailures = fp + fn;
    final failRate = (totalFailures / sampleCount * 100).toStringAsFixed(2);
    sampleCountSum += sampleCount;
    fpSum += fp;
    fnSum += fn;
    result.add("$line, $sampleCount, $fp, $fn, $totalFailures, $failRate%");
  }
  final failureSum = fpSum + fnSum;
  final failureRate = (failureSum / sampleCountSum * 100).toStringAsFixed(2);
  final sumConclusion =
      "overall, $sampleCountSum, $fpSum, $fnSum, $failureSum, $failureRate%";
  print("Benchmark complete: $sumConclusion");
  result.add(sumConclusion);

  /// path to write benchmark result to
  final outputPath = "$pathBase/benchmark-nk-2.csv";
  final outputFile = File(outputPath);
  await outputFile.writeAsString(result.join('\n'));

  print("Benchmark result written to $outputPath");
}

/// benchmark procedure for a single record
Future<(int, int, int)> bench(String path) async {
  // sampleCount, FP, FN
  final file = File(path);
  final content = file
      .readAsStringSync(); // TODO: might block for a while, use async and loading indicator to improve experience
  final csv = const CsvToListConverter(eol: "\n").convert(content);

  final data = csv
      .sublist(2)
      .mapIndexed((index, element) => ECGData(index, element[1] as double))
      .toList();

  final detectResult = detectWithNk(data);
  final detectCount = detectResult.length;

  final correctResult = <int>[];

  try {
    final correctPath = "${path.substring(0, path.length - 3)}txt";
    final file = File(correctPath);
    final content = await file.readAsString();
    final lines = content.trim().split("\n");

    for (String line in lines.skip(1)) {
      final values =
          line.split(RegExp(r'\s+')).map((value) => value.trim()).toList();
      String sampleValue = values[2];
      correctResult.add(int.parse(sampleValue));
    }
  } on PlatformException catch (e) {
    snackbar("Error", "Failed to open file dialog: $e");
  }

  int correct = 0;
  int falseNegative = 0;
  int falsePositive = 0;

  final missed = <int>[];

  outer:
  for (final timestamp in correctResult) {
    for (final (index, detection) in detectResult.indexed) {
      if (timestamp - benchmarkToleration < detection &&
          detection < timestamp + benchmarkToleration) {
        detectResult.removeAt(index);
        correct += 1;
        continue outer;
      }
    }
    falseNegative += 1;
    missed.add(timestamp);
  }

  falsePositive = detectResult.length;

  print("Benchmark result for record $path:");
  print("  total: $detectCount");
  print("  correct: $correct;");

  print("  missed: $missed");
  print("  imagined: $detectResult");

  print(
      "  falseNegative: $falseNegative; FNRate: ${falseNegative / detectCount}");
  print(
      "  falsePositive: $falsePositive; FPRate: ${falsePositive / detectCount}");

  return (detectCount, falseNegative, falsePositive);
}

/// preprocess & detect with neurokit
List<int> detectWithNk(List<ECGData> input) {
  final preprocessor = CleanBP(fs);
  final detector = NkPeakDetector(fs);
  final preprocessed = preprocessor.apply(input);
  final result = detector.rawDetect(preprocessed, preprocessed);
  return result;
}

/// preprocess & detect with pan-tompkins
List<int> detectWithPt(List<ECGData> input) {
  final preprocessor = CleanPT(fs);
  final detector = PtPeakDetector(fs);
  final preprocessed = preprocessor.apply(input);
  final result = detector.rawDetect(preprocessed, preprocessed);
  return result;
}
