import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import '../constants.dart';
import '../ecg_data.dart';
import '../navigation.dart';
import 'view_record_controller.dart';

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
                        viewport:
                            charts.NumericExtents(lowerLimit, upperLimit)),
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
