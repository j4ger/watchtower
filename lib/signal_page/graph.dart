import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_counter/smooth_counter.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../ecg_data.dart';
import 'buffer_controller.dart';
import '../constants.dart';

const graphUpperLimit = 2;
const graphLowerLimit = -2;

class Graph extends StatelessWidget {
  final BufferController controller = Get.find();
  Graph({super.key});

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
        Card(
            clipBehavior: Clip.hardEdge,
            child: Stack(children: [
              SizedBox(
                  height: 300,
                  child: GetBuilder<BufferController>(builder: (controller) {
                    final buffer = controller.buffer;

                    int freshStart, freshEnd;
                    if (controller.cursorIndex > graphBufferLength) {
                      freshStart = controller.cursorIndex - graphBufferLength;
                      freshEnd = graphBufferLength;
                    } else {
                      freshStart = 0;
                      freshEnd = controller.cursorIndex;
                    }

                    final staleStart = controller.cursorIndex + hiddenLength;

                    final List<charts.Series<ECGData, int>> data = [];

                    final List<charts.RangeAnnotationSegment<int>>
                        rangeAnnotations = [];
                    if (staleStart < graphBufferLength) {
                      rangeAnnotations.add(charts.RangeAnnotationSegment(
                          freshEnd,
                          staleStart,
                          charts.RangeAnnotationAxisType.domain,
                          color: hiddenColor));
                    } else {
                      rangeAnnotations.add(charts.RangeAnnotationSegment(
                          freshEnd,
                          graphBufferLength - 1,
                          charts.RangeAnnotationAxisType.domain,
                          color: hiddenColor));
                    }
                    if (freshStart > 0) {
                      rangeAnnotations.add(charts.RangeAnnotationSegment(
                          0, freshStart, charts.RangeAnnotationAxisType.domain,
                          color: hiddenColor));
                    }

                    if (controller.debug.value) {
                      final List<ECGData> processData =
                          controller.processData.isNotEmpty
                              ? ListSlice(
                                  controller.processData,
                                  graphBufferLength - controller.lastFreshIndex,
                                  graphBufferLength - 1)
                              : [];
                      data.add(charts.Series<ECGData, int>(
                          id: "debug",
                          domainFn: (ECGData item, _) => item.index,
                          measureFn: (ECGData item, _) =>
                              item.value - 1, // added offset
                          data: processData,
                          colorFn: (_, __) =>
                              const charts.Color(r: 0x12, g: 0xff, b: 0x59)));

                      final List<ECGData> preprocessedData =
                          controller.preprocessedData.isNotEmpty
                              ? ListSlice(
                                  controller.preprocessedData,
                                  graphBufferLength - controller.lastFreshIndex,
                                  graphBufferLength - 1)
                              : [];

                      data.add(charts.Series<ECGData, int>(
                          id: "debug-preprocessed",
                          domainFn: (ECGData item, _) => item.index,
                          measureFn: (ECGData item, _) =>
                              item.value - 2, // added offset
                          data: preprocessedData,
                          colorFn: (_, __) =>
                              const charts.Color(r: 0x12, g: 0x16, b: 0xff)));
                    }

                    final finalAnnotation = controller.finalAnnotation;
                    for (final timestamp in finalAnnotation) {
                      if (timestamp < controller.frameStartTimestamp) {
                        continue;
                      }
                      final index = timestamp % graphBufferLength;
                      final lowerIndex = index - markLength;
                      final upperIndex = index + markLength;
                      if (lowerIndex < controller.cursorIndex &&
                          upperIndex > 0) {
                        rangeAnnotations.add(charts.RangeAnnotationSegment(
                            lowerIndex,
                            upperIndex,
                            charts.RangeAnnotationAxisType.domain,
                            color: markColor));
                      }
                    }

                    data.add(charts.Series<ECGData, int>(
                        id: "fresh",
                        domainFn: (ECGData item, _) => item.index,
                        measureFn: (ECGData item, _) => item.value,
                        data: ListSlice(buffer, freshStart, freshEnd),
                        colorFn: (_, __) => freshColor));
                    if (staleStart < graphBufferLength) {
                      data.add(charts.Series<ECGData, int>(
                          id: "stale",
                          domainFn: (ECGData item, _) => item.index,
                          measureFn: (ECGData item, _) => item.value,
                          data:
                              ListSlice(buffer, staleStart, graphBufferLength),
                          colorFn: (_, __) => staleColor));
                    }

                    return charts.LineChart(
                      data,
                      animate: false,
                      domainAxis: const charts.NumericAxisSpec(
                          viewport:
                              charts.NumericExtents(0, graphBufferLength - 1),
                          renderSpec: charts.NoneRenderSpec()),
                      primaryMeasureAxis: const charts.NumericAxisSpec(
                          renderSpec: charts.NoneRenderSpec(),
                          viewport: charts.NumericExtents(
                              graphLowerLimit, graphUpperLimit)),
                      behaviors: [charts.RangeAnnotation(rangeAnnotations)],
                    );
                  })),
              Container(
                  padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Obx(() =>
                          controller.state() == BufferControllerState.recording
                              ? const SizedBox(
                                  height: 24,
                                  child: SpinKitDoubleBounce(
                                      color: Colors.redAccent, size: 24))
                              : const SizedBox.shrink()),
                      const SizedBox(width: 6),
                      Obx(() => controller.heartRate.value != null
                          ? SmoothCounter(
                              count: controller.heartRate.value!.toInt(),
                              textStyle: const TextStyle(
                                  fontSize: 30,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5))
                          : const Text("--",
                              style: TextStyle(
                                  fontSize: 30, letterSpacing: 4, height: 1))),
                      const SizedBox(width: 3),
                      const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text("bpm",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black87)))
                    ],
                  ))
            ])),
        Card(
            child: Column(children: [
          const SizedBox(
            height: 10,
          ),
          Text("Interval History",
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(
              height: 300,
              child: Obx(() {
                final intervalHistoryData = [
                  charts.Series<(int, int), int>(
                      id: "interval",
                      domainFn: (data, _) => data.$1,
                      measureFn: (data, _) => data.$2,
                      data: controller.intervalHistory())
                ];
                return charts.LineChart(
                  intervalHistoryData,
                  animate: false, //TODO: animate
                  defaultRenderer:
                      charts.LineRendererConfig(includePoints: true),
                  domainAxis: const charts.NumericAxisSpec(
                      viewport:
                          charts.NumericExtents(0, peakBufferCapacity - 2),
                      renderSpec: charts.NoneRenderSpec()),
                  primaryMeasureAxis: const charts.NumericAxisSpec(
                      viewport: charts.NumericExtents(250, 1200)),
                  behaviors: [
                    if (controller.heartRate.value != null)
                      charts.RangeAnnotation([
                        charts.LineAnnotationSegment(
                            60 * 1000 / controller.heartRate.value!,
                            charts.RangeAnnotationAxisType.measure,
                            endLabel: "Average",
                            color: averageLineColor)
                      ])
                  ],
                  layoutConfig: charts.LayoutConfig(
                      leftMarginSpec: charts.MarginSpec.fixedPixel(45),
                      rightMarginSpec: charts.MarginSpec.fixedPixel(30),
                      topMarginSpec: charts.MarginSpec.fixedPixel(15),
                      bottomMarginSpec: charts.MarginSpec.fixedPixel(10)),
                );
              }))
        ])),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text("Debug"),
          trailing: Obx(() => Switch(
                value: controller.debug.value,
                onChanged: (bool value) {
                  controller.debug.value = value;
                },
              )),
        )
      ]);
}

const hiddenLength = packLength;


// TODO: stale color tween
