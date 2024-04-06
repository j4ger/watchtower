import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scidart/numdart.dart';
import 'package:watchtower/algorithm/pipeline.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:watchtower/ecg_data.dart';

const displayStart = 2 * packLength;

const rendererId = "a";

class Graph extends StatelessWidget {
  final List<ECGData>? source;
  final List<int>? annotations;
  final List<Pipeline>? pipelines;
  final Detector? detector;
  const Graph(
      {this.source,
      this.annotations,
      this.pipelines,
      this.detector,
      super.key});

  @override
  Widget build(BuildContext context) =>
      GetBuilder<BufferController>(builder: (controller) {
        final buffer = source ?? controller.buffer;
        int freshStart, freshEnd;
        if (controller.cursorIndex > bufferLength) {
          freshStart = controller.cursorIndex - bufferLength;
          freshEnd = bufferLength;
        } else {
          freshStart = 0;
          freshEnd = controller.cursorIndex;
        }
        final staleStart = controller.cursorIndex + hiddenLength;
        final data = [
          charts.Series<ECGData, int>(
              id: "fresh",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value,
              data: ListSlice(buffer, freshStart, freshEnd),
              colorFn: (_, __) => freshColor) as charts.Series<dynamic, int>
        ];
        final List<charts.RangeAnnotationSegment<int>> rangeAnnotations = [];
        if (staleStart < bufferLength) {
          data.add(charts.Series<ECGData, int>(
              id: "stale",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value,
              data: ListSlice(buffer, staleStart, bufferLength),
              colorFn: (_, __) => staleColor) as charts.Series<dynamic, int>);
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

        final List<ECGData> processData = source ?? controller.actualData;
        Array bufferArray = Array(processData.map((e) => e.value).toList());
        if (pipelines != null) {
          for (final step in pipelines!) {
            bufferArray = step.apply(bufferArray);
          }
        }
        final finalAnnotations =
            annotations ?? detector?.detect(processData, bufferArray);
        if (finalAnnotations != null && finalAnnotations.isNotEmpty) {
          data.add(charts.Series<int, int>(
              id: "annotations",
              domainFn: (int index, _) => index % bufferLength,
              domainLowerBoundFn: (_, __) => null,
              domainUpperBoundFn: (_, __) => null,
              measureFn: (_, __) => null,
              data: finalAnnotations) as charts.Series<dynamic, int>
            ..setAttribute(charts.rendererIdKey, rendererId));
        }
        return SizedBox(
            width: 400,
            height: 300,
            child: charts.LineChart(
              data,
              animate: false,
              domainAxis: const charts.NumericAxisSpec(
                  viewport: charts.NumericExtents(0, bufferLength - 1),
                  renderSpec: charts.NoneRenderSpec()),
              primaryMeasureAxis: const charts.NumericAxisSpec(
                  renderSpec: charts.NoneRenderSpec()),
              behaviors: [charts.RangeAnnotation(rangeAnnotations)],
              customSeriesRenderers: [
                charts.SymbolAnnotationRendererConfig(
                    customRendererId: rendererId)
              ],
            ));
      });
}

const hiddenLength = packLength;

const freshColor = charts.Color(r: 0xdb, g: 0x16, b: 0x16);
const staleColor = charts.Color(r: 0xee, g: 0x72, b: 0x64);

const hiddenColor = charts.Color(r: 0xfe, g: 0xfe, b: 0xfe);

// TODO: stale color tween
