import 'dart:io';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ecg_data.dart';
import '../signal_page/buffer_controller.dart';
import '../signal_page/signal_source.dart';
import '../utils.dart';
import 'mock_device.dart';
import '../record_page/record_controller.dart';
import '../benchmark/benchmark.dart' as bench;

const previousFileKey = "PreviousFile";

class MockPageController extends GetxController {
  final BufferController bufferController = Get.find();
  final RecordController recordController = Get.find();

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

  Future<void> promptLoadFromDataset() async {
    try {
      final String? path = (await FilePicker.platform.pickFiles(
              allowMultiple: false,
              type: FileType.custom,
              allowedExtensions: ["csv"],
              dialogTitle: "Select mock file"))
          ?.files[0]
          .path;
      if (path != null) {
        save(path);
        bufferController.reset();
        Get.put(MockController(path, bufferController));
        Get.toNamed("/signal",
            arguments: SignalSource(SignalSourceType.mock, path: path));
      } else {
        snackbar("Cancelled", "No file was selected.");
      }
    } on PlatformException catch (e) {
      snackbar("Error", "Failed to open file dialog: $e");
    }
  }

  Future<void> promptLoadIntoDB() async {
    final String? path = (await FilePicker.platform.pickFiles(
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
      final csv = const CsvToListConverter(eol: "\n").convert(content);

      final data = csv
          .sublist(2)
          .mapIndexed((index, element) => ECGData(index, element[1] as double))
          .toList();

      // TODO: decide detector
      final detectResult = bench.detectWithPt(data);
      final record = Record(DateTime.now(),
          Duration(milliseconds: data.length * 1000 ~/ bench.fs), data,
          annotations: detectResult);
      await recordController.addRecord(record);
    }
  }
}
