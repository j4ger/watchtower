import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../record_page/record_controller.dart';
import '../utils.dart';

class ViewRecordController extends GetxController {
  late final Record record;
  final Rx<List<int>?> correctAnnotations = null.obs;
  final DateTime startTime;
  final loading = true.obs;

  final RecordController recordController = Get.find();

  ViewRecordController(this.startTime);

  @override
  void onInit() {
    super.onInit();
    initRecord();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  Future<void> initRecord() async {
    final result = await recordController.getRecordByStartTime(startTime);
    record = result;
    loading.value = false;
  }

  Future<void> promptLoadCorrectAnnotations() async {
    try {
      final String? path = (await FilePicker.platform.pickFiles(
              allowMultiple: false,
              type: FileType.custom,
              allowedExtensions: ["txt"],
              dialogTitle: "Select annotation file"))
          ?.files[0]
          .path;
      if (path != null) {
        final file = File(path);
        final content = await file.readAsString();
        final result = <int>[];
        List<String> lines = content.trim().split("\n");

        // Assuming the header is always present and the format is consistent
        List<String> headers = lines.first
            .split(RegExp(r'\s+'))
            .map((header) => header.trim())
            .toList();
        int sampleIndex = headers.indexOf("Sample");

        for (String line in lines.skip(1)) {
          List<String> values =
              line.split(RegExp(r'\s+')).map((value) => value.trim()).toList();
          if (values.length > sampleIndex) {
            String sampleValue = values[sampleIndex];
            result.add(int.parse(sampleValue));
          }
        }

        correctAnnotations.value = result;
      } else {
        snackbar("Cancelled", "No file was selected.");
      }
    } on PlatformException catch (e) {
      snackbar("Error", "Failed to open file dialog: $e");
    }
  }

  int get timestampStart => record.data.first.timestamp;
  int get timestampEnd => timestampStart + displayTimestampRange;
}

const displayTimestampRange = graphBufferLength;
