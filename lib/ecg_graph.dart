import 'dart:async';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

import 'ecg_data.dart';
import "detector.dart";

const bufferLength = 600;
const baseOffset = 150;
const plotLength = 300;
const delayMs = 300;
const packLength = 50;

class BufferController extends GetxController {
  final CircularBuffer<ECGData> buffer = CircularBuffer(bufferLength);

  int dataAvailable = 0;
  int timeUntilNextPack = delayMs;
  int updateInterval = (delayMs / packLength).floor();
  int updateCounter = 0;
  int offset = 0;
  int? lastTimestamp;

  late final Timer tickTimer;

  void calcInterval() {
    if (dataAvailable > 0) {
      updateInterval = (timeUntilNextPack / dataAvailable).floor();
    } else {
      // wait
      updateInterval = 0;
    }
  }

  void tick(Timer timer) {
    timeUntilNextPack -= 1;
    if (updateInterval == 0) {
      calcInterval();
      if (updateInterval == 0) {
        return;
      }
    }

    if (updateCounter < updateInterval) {
      updateCounter += 1;
    } else {
      offset += 1;
      update();
      dataAvailable -= 1;
      updateCounter = 0;
      calcInterval();
    }
  }

  void add(ECGData item) {
    buffer.add(item);
    updatePercentage();
  }

  void extend(List<ECGData> items) {
    for (ECGData item in items) {
      add(item);
    }
    dataAvailable += items.length;
    offset -= items.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastTimestamp != null) {
      timeUntilNextPack = now - lastTimestamp!;
    } else {
      timeUntilNextPack = delayMs;
    }
    lastTimestamp = now;
  }

  double get start => buffer.firstOrNull?.x ?? 0;
  double get end => buffer.lastOrNull?.x ?? 0;

  int? heartRate;
  List<VerticalLine> annotations = [];

  final detector = QRSDetector(250, 0.9);

  void doDetection() {
    if (buffer.isFilled) {
      annotations = detector.detect(buffer);
      heartRate = detector.heartRate?.floor();
    }
  }

  final percentage = 0.0.obs;
  void updatePercentage() {
    percentage.value = buffer.length / buffer.capacity;
  }

  @override
  void onInit() {
    super.onInit();
    tickTimer = Timer.periodic(const Duration(milliseconds: 1), tick);
  }

  @override
  void dispose() {
    tickTimer.cancel();
    super.dispose();
  }
}

class ECGGraph extends StatelessWidget {
  const ECGGraph({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<BufferController>(
      builder: (controller) => Container(
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
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const SpinKitPumpingHeart(size: 20.0, color: Colors.redAccent),
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
                minX: controller.start + controller.offset + baseOffset,
                maxX: controller.start +
                    controller.offset +
                    baseOffset +
                    plotLength,
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
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
          ])));
}
