// TODO: alternative scrolling method: render directly from circularBuffer
// probably need to change the way "timestamp" is assigned

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:watchtower/buffer_controller.dart';

class ECGGraph extends StatelessWidget {
  const ECGGraph({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<BufferController>(
      builder: (controller) => Column(children: [
            Container(
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
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        stops: [
                          0.05,
                          0.95,
                        ],
                        colors: [
                          Color.fromRGBO(0x24, 0x2a, 0xcf, 1),
                          Color.fromRGBO(0x52, 0x57, 0xd5, 0.5),
                        ])),
                margin: const EdgeInsets.all(8.0),
                width: 400,
                height: 200,
                child: Stack(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 6, 0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SpinKitPumpingHeart(
                              size: 20.0,
                              color: controller.percentage.value == 1.0
                                  ? Colors.redAccent
                                  : Colors.grey),
                          const SizedBox(
                            width: 2,
                          ),
                          Text(
                            controller.heartRate?.toString() ?? "--",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9)),
                          )
                        ]),
                  ),
                  LineChart(
                    duration: Duration.zero,
                    LineChartData(
                      minY: -1,
                      maxY: 2,
                      minX: controller.minX,
                      maxX: controller.minY,
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                            show: controller.buffer.isNotEmpty,
                            spots: controller.buffer,
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
                      extraLinesData:
                          ExtraLinesData(verticalLines: controller.annotations),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      clipData: const FlClipData.all(),
                    ),
                  )
                ]))
          ]));
}
