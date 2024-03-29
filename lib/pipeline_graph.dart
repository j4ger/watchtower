import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:scidart/numdart.dart';
import 'package:watchtower/algorithm/pipeline.dart';
import 'package:watchtower/buffer_controller.dart';

import 'ecg_data.dart';

class PipelineGraph extends StatelessWidget {
  final List<Pipeline> pipelines;
  const PipelineGraph({super.key, required this.pipelines});

  @override
  Widget build(BuildContext context) => GetBuilder<BufferController>(
      builder: (controller) => Column(
          children: pipelines
              .map((pipeline) => Container(
                  decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(
                            color: Color.fromRGBO(0x47, 0x66, 0xf4, 0.3),
                            spreadRadius: 2,
                            blurRadius: 3,
                            offset: Offset(0, 1))
                      ],
                      borderRadius: BorderRadius.circular(6),
                      border: null,
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [
                            0.05,
                            0.95,
                          ],
                          colors: [
                            Color.fromRGBO(0x52, 0x57, 0xd5, 1),
                            Color.fromRGBO(0x24, 0x2a, 0xcf, 0.5),
                          ])),
                  margin: const EdgeInsets.all(8.0),
                  width: 400,
                  height: 200,
                  child: LineChart(
                    duration: Duration.zero,
                    LineChartData(
                      // minY: -1,
                      // maxY: 2,
                      minX: controller.start + controller.offset + baseOffset,
                      maxX: controller.start +
                          controller.offset +
                          baseOffset +
                          plotLength,
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                            show: controller.buffer.isNotEmpty,
                            spots: mapArrayToData(
                                controller.buffer,
                                pipeline.apply(Array(controller.buffer
                                    .map((element) => element.y)
                                    .toList()))),
                            dotData: const FlDotData(show: false),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            // gradient: LinearGradient(colors: [
                            //   Colors.white.withOpacity(0),
                            //   Colors.white
                            // ], stops: const [
                            //   0.05,
                            //   0.25
                            // ]),
                            color: Colors.white,
                            isCurved: false)
                      ],
                      borderData: FlBorderData(
                        show: false,
                      ),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      clipData: const FlClipData.all(),
                    ),
                  )))
              .toList()));
}
