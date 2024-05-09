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
                            GRAPH_LOWER_LIMIT, GRAPH_UPPER_LIMIT)),
                    behaviors: [charts.PanAndZoomBehavior()],
                  ))),
        ),
        showDrawerButton: false);
  }
}

const displayTimestampRange = bufferLength;
