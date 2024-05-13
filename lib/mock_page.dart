import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'algorithm/ECG/clean.dart';
import 'algorithm/ECG/find_peaks.dart';
import 'buffer_controller.dart';
import 'ecg_data.dart';
import 'mock_device.dart';
import 'main.dart';
import 'record_page.dart';

const previousFileKey = "PreviousFile";

enum TargetType { ble, mock }

class Target {
  final TargetType type;
  final String? path;
  final Peripheral? device;

  Target(this.type, {this.path, this.device});

  bool get isMock => type == TargetType.mock;
}

class MockPageController extends GetxController {
  final BufferController bufferController = Get.find();

  var previousFile = "".obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    previousFile.value = prefs.getString(previousFileKey) ?? "";
  }

  Future<void> save(String file) async {
    previousFile.value = file;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(previousFileKey, file);
  }
}

class MockPage extends StatelessWidget {
  MockPage({super.key});

  final controller = Get.put(MockPageController());
  final RecordController recordController = Get.find();

  @override
  Widget build(BuildContext context) {
    return makePage(
        "Setup Mock Device",
        Container(
            alignment: AlignmentDirectional.center,
            child: Column(children: [
              const SizedBox(
                height: 10,
              ),
              Obx(() => controller.previousFile.value == ""
                  ? Container()
                  : FilledButton(
                      child: const Text("Load Previous"),
                      onPressed: () {
                        controller.bufferController.reset();
                        Get.put(MockController(controller.previousFile.value,
                            controller.bufferController));
                        Get.toNamed("/signal",
                            arguments: Target(TargetType.mock,
                                path: controller.previousFile
                                    .value)); // TODO: redesign this
                      },
                    )),
              const SizedBox(
                height: 10,
              ),
              FilledButton(
                  onPressed: () async => awaitWithOverlay(() async {
                        try {
                          final String? path = (await FilePicker.platform
                                  .pickFiles(
                                      allowMultiple: false,
                                      type: FileType.custom,
                                      allowedExtensions: ["csv"],
                                      dialogTitle: "Select mock file"))
                              ?.files[0]
                              .path;
                          if (path != null) {
                            controller.save(path);
                            controller.bufferController.reset();
                            Get.put(MockController(
                                path, controller.bufferController));
                            Get.toNamed("/signal",
                                arguments: Target(TargetType.mock, path: path));
                          } else {
                            snackbar("Cancelled", "No file was selected.");
                          }
                        } on PlatformException catch (e) {
                          snackbar("Error", "Failed to open file dialog: $e");
                        }
                      }),
                  child: const Text("Open File")),
              const SizedBox(
                height: 10,
              ),
              FilledButton(
                  onPressed: () async => awaitWithOverlay(() async {
                        final String? path = (await FilePicker.platform
                                .pickFiles(
                                    allowMultiple: false,
                                    type: FileType.custom,
                                    allowedExtensions: ["csv"],
                                    dialogTitle: "Select mock file"))
                            ?.files[0]
                            .path;
                        if (path != null) {
                          final file = File(path);
                          final content = file
                              .readAsStringSync(); // TODO: might block for a while, use async and loading indicator to improve experience
                          final csv = const CsvToListConverter(eol: "\n")
                              .convert(content);

                          final data = csv
                              .sublist(2)
                              .mapIndexed((index, element) =>
                                  ECGData(index, element[1] as double))
                              .toList();

                          final detectResult = processWithPT(data);
                          final record = Record(
                              DateTime.now(),
                              Duration(milliseconds: data.length * 1000 ~/ fs),
                              data,
                              annotations: detectResult);
                          await recordController.addRecord(record);
                        }
                      }),
                  child: const Text("Load file to database")),
              const SizedBox(height: 10),
              FilledButton(
                  onPressed: () async => awaitWithOverlay(promptTest),
                  child: const Text("Begin Benchmarking"))
            ])));
  }
}

Future<void> promptTest() async {
  final String? path = (await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: ["csv"],
          dialogTitle: "Select source file"))
      ?.files[0]
      .path;
  if (path == null) {
    snackbar("Cancelled", "No file was selected.");
    return;
  }
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
}

const benchmarkToleration = 80;

List<int> detectWithNk(List<ECGData> input) {
  final preprocessor = CleanBP(fs);
  final detector = NkPeakDetector(fs);
  final preprocessed = preprocessor.apply(input);
  final result = detector.rawDetect(preprocessed, preprocessed);
  return result;
}
