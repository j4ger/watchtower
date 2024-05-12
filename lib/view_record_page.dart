import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'buffer_controller.dart';
import 'ecg_data.dart';
import 'graph.dart';
import 'record_page.dart';
import 'main.dart';

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

class ViewRecordPage extends StatelessWidget {
  late final DateTime startTime;
  ViewRecordPage({super.key}) {
    startTime = Get.arguments as DateTime;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ViewRecordController(startTime));

    return makePage(
        "View Record",
        PopScope(
          onPopInvoked: (_) {
            SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          },
          child: Obx(() => controller.loading()
              ? Container()
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: charts.LineChart(
                    [
                      charts.Series<ECGData, int>(
                          id: "data",
                          domainFn: (ECGData item, _) =>
                              item.timestamp - controller.timestampStart,
                          measureFn: (ECGData item, _) => item.value,
                          data: controller.record.data,
                          colorFn: (_, __) => freshColor)
                    ],
                    domainAxis: charts.NumericAxisSpec(
                        viewport: const charts.NumericExtents(
                            0, displayTimestampRange),
                        tickFormatterSpec:
                            charts.BasicNumericTickFormatterSpec((input) {
                          final number = (input ?? 0) / fs;
                          return "${number.toStringAsFixed(2)}s";
                        })),
                    primaryMeasureAxis: const charts.NumericAxisSpec(
                        renderSpec: charts.NoneRenderSpec(),
                        viewport: charts.NumericExtents(
                            graphLowerLimit, graphUpperLimit)),
                    behaviors: [
                      charts.PanAndZoomBehavior(),
                      if (controller.record.annotations.isNotEmpty)
                        charts.RangeAnnotation(controller.record.annotations
                            .map((timestamp) => charts.RangeAnnotationSegment(
                                timestamp -
                                    controller.timestampStart -
                                    markLength,
                                timestamp -
                                    controller.timestampStart +
                                    markLength,
                                charts.RangeAnnotationAxisType.domain,
                                color: markColor))
                            .toList()),
                      if (controller.correctAnnotations.value != null)
                        charts.RangeAnnotation(controller
                            .correctAnnotations.value!
                            .map((timestamp) => charts.RangeAnnotationSegment(
                                timestamp - 1,
                                timestamp + 1,
                                charts.RangeAnnotationAxisType.domain,
                                color: const charts.Color(r: 10, g: 10, b: 10)))
                            .toList())
                    ],
                  ))),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: controller.promptLoadCorrectAnnotations,
          tooltip: "Load Correct Annotations",
          child: const Icon(Icons.assignment),
        ),
        showDrawerButton: false);
  }
}

const displayTimestampRange = bufferLength;
