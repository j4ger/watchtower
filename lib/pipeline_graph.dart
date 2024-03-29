import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:scidart/numdart.dart';
import 'package:watchtower/algorithm/pipeline.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:watchtower/ecg_data.dart';
import 'package:watchtower/graph.dart';

class PipelineGraph extends StatelessWidget {
  final List<Pipeline> pipelines;
  final List<Detector> detectors;
  const PipelineGraph(this.pipelines, this.detectors, {super.key});

  @override
  Widget build(BuildContext context) =>
      GetBuilder<BufferController>(builder: (controller) {
        Array result =
            Array(controller.largeBuffer.map((e) => e.value).toList());
        List<(Array, String)> pipelineResults = [];
        List<(List<int>, String)> detectorResults = [];
        if (controller.isFilled) {
          for (Pipeline pipeline in pipelines) {
            result = pipeline.apply(result);
            pipelineResults.add((result, pipeline.name));
          }
          for (Detector detector in detectors) {
            detectorResults.add((detector.detect(result), detector.name));
          }
        }

        final List<Widget> children = [];

        for (final (result, name) in pipelineResults) {
          print("$name : ${result.length}");
          final source = mapArrayToData(controller.buffer, result);
          final sourceShifted = ListSlice(source,
                  bufferLength - controller.lastFreshIndex, bufferLength - 1) +
              ListSlice(source, 0, bufferLength - controller.lastFreshIndex);
          children.add(Graph(source: sourceShifted));
          children.add(Center(child: Text(name)));
        }

        return Column(children: children);
      });
}
