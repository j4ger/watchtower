import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_counter/smooth_counter.dart';
import 'package:watchtower/algorithm/pipeline.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:watchtower/ecg_data.dart';

import 'algorithm/ECG/find_peaks.dart';

// const DEBUG = false; // moved to BufferController

const GRAPH_UPPER_LIMIT = 2;
const GRAPH_LOWER_LIMIT = -2;

class Graph extends StatelessWidget {
  final List<Pipeline>? pipelines;
  // final Detector? detector;
  final PtPeakDetector? detector;

  const Graph({this.pipelines, this.detector, super.key});

  @override
  Widget build(BuildContext context) =>
      GetBuilder<BufferController>(builder: (controller) {
        final buffer = controller.buffer;

        int freshStart, freshEnd;
        if (controller.cursorIndex > bufferLength) {
          freshStart = controller.cursorIndex - bufferLength;
          freshEnd = bufferLength;
        } else {
          freshStart = 0;
          freshEnd = controller.cursorIndex;
        }

        final staleStart = controller.cursorIndex + hiddenLength;

        final List<charts.Series<ECGData, int>> data = [];

        final List<charts.RangeAnnotationSegment<int>> rangeAnnotations = [];
        if (staleStart < bufferLength) {
          rangeAnnotations.add(charts.RangeAnnotationSegment(
              freshEnd, staleStart, charts.RangeAnnotationAxisType.domain,
              color: hiddenColor));
        } else {
          rangeAnnotations.add(charts.RangeAnnotationSegment(
              freshEnd, bufferLength - 1, charts.RangeAnnotationAxisType.domain,
              color: hiddenColor));
        }
        if (freshStart > 0) {
          rangeAnnotations.add(charts.RangeAnnotationSegment(
              0, freshStart, charts.RangeAnnotationAxisType.domain,
              color: hiddenColor));
        }

        List<ECGData> processData = controller.actualData;
        if (pipelines != null) {
          for (final step in pipelines!) {
            processData = step.apply(processData);
          }
        }

        if (controller.debug.value) {
          data.add(charts.Series<ECGData, int>(
              id: "debug",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value - 1, // added offset
              data: ListSlice(processData,
                  bufferLength - controller.lastFreshIndex, bufferLength - 1),
              colorFn: (_, __) =>
                  const charts.Color(r: 0x12, g: 0xff, b: 0x59)));

          final preprocessedData = detector!
              .preprocess(processData)
              .map((e) => ECGData(e.timestamp, e.value * 400))
              .toList();
          data.add(charts.Series<ECGData, int>(
              id: "debug-preprocessed",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value - 2, // added offset
              data: ListSlice(preprocessedData,
                  bufferLength - controller.lastFreshIndex, bufferLength - 1),
              colorFn: (_, __) =>
                  const charts.Color(r: 0x12, g: 0x16, b: 0xff)));
        }

        final finalAnnotation = detector?.detect(processData);
        if (finalAnnotation != null) {
          for (final timestamp in finalAnnotation) {
            if (timestamp < controller.frameStartTimestamp) {
              continue;
            }
            final index = timestamp % bufferLength;
            final lowerIndex = index - markLength;
            final upperIndex = index + markLength;
            if (lowerIndex < controller.cursorIndex && upperIndex > 0) {
              rangeAnnotations.add(charts.RangeAnnotationSegment(
                  lowerIndex, upperIndex, charts.RangeAnnotationAxisType.domain,
                  color: markColor));
            }
          }
        }

        final List<(int, int)> intervalHistory = [];
        if (finalAnnotation != null) {
          for (int i = 1; i < finalAnnotation.length; i++) {
            intervalHistory
                .add((i - 1, finalAnnotation[i] - finalAnnotation[i - 1]));
          }
        }
        final intervalHistoryData = [
          charts.Series(
              id: "interval",
              domainFn: (data, _) => data.$1,
              measureFn: (data, _) => data.$2,
              data: intervalHistory)
        ];

        data.add(charts.Series<ECGData, int>(
            id: "fresh",
            domainFn: (ECGData item, _) => item.index,
            measureFn: (ECGData item, _) => item.value,
            data: ListSlice(buffer, freshStart, freshEnd),
            colorFn: (_, __) => freshColor));
        if (staleStart < bufferLength) {
          data.add(charts.Series<ECGData, int>(
              id: "stale",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value,
              data: ListSlice(buffer, staleStart, bufferLength),
              colorFn: (_, __) => staleColor));
        }

        return Column(children: [
          SizedBox(
              height: 300,
              child: Stack(children: [
                Container(
                    height: 300,
                    padding: const EdgeInsets.all(10),
                    child: charts.LineChart(
                      data,
                      animate: false,
                      domainAxis: const charts.NumericAxisSpec(
                          viewport: charts.NumericExtents(0, bufferLength - 1),
                          renderSpec: charts.NoneRenderSpec()),
                      primaryMeasureAxis: const charts.NumericAxisSpec(
                          renderSpec: charts.NoneRenderSpec(),
                          viewport: charts.NumericExtents(
                              GRAPH_LOWER_LIMIT, GRAPH_UPPER_LIMIT)),
                      behaviors: [charts.RangeAnnotation(rangeAnnotations)],
                    )),
                Container(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        detector!.heartRate != null
                            ? SmoothCounter(
                                count: detector!.heartRate!.toInt(),
                                textStyle: const TextStyle(
                                    fontSize: 30,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5))
                            : const Text("--",
                                style: TextStyle(
                                    fontSize: 30, letterSpacing: 4, height: 1)),
                        const SizedBox(width: 3),
                        const Text("bpm",
                            style:
                                TextStyle(fontSize: 12, color: Colors.black87))
                      ],
                    ))
              ])),
          Container(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 0),
              height: 300,
              child: charts.LineChart(intervalHistoryData,
                  animate: false, // TODO: avoid triggering rebuild
                  defaultRenderer:
                      charts.LineRendererConfig(includePoints: true))),
          Expanded(
              child: ListView(children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text("Debug"),
              trailing: Switch(
                value: controller.debug.value,
                onChanged: (bool value) {
                  controller.debug.value = value;
                },
              ),
            )
          ]))
        ]);
      });
}

const hiddenLength = packLength;

const freshColor = charts.Color(r: 0xdb, g: 0x16, b: 0x16);
const staleColor = charts.Color(r: 0xee, g: 0xcc, b: 0xcc);

const hiddenColor = charts.Color(r: 0xfe, g: 0xfe, b: 0xfe);

const upperLimit = 1;
const lowerLimit = -0.8;

const markLength = 40;
const markColor = charts.Color(r: 0xff, g: 0xbf, b: 0xb8);

// TODO: stale color tween
