import 'dart:async';

import 'package:circular_buffer/circular_buffer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:watchtower/detector.dart';
import 'package:watchtower/ecg_data.dart';

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
      if (buffer.isFilled) {
        offset += 1;
      }
      update();
      dataAvailable -= 1;
      updateCounter = 0;
      calcInterval();
    }
  }

  void _add(ECGData item) {
    buffer.add(item);
    updatePercentage();
  }

  void extend(List<ECGData> items) {
    for (ECGData item in items) {
      _add(item);
    }
    dataAvailable += items.length;
    if (buffer.isFilled) {
      offset -= items.length;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastTimestamp != null) {
      timeUntilNextPack = now - lastTimestamp!;
    } else {
      timeUntilNextPack = delayMs;
    }
    lastTimestamp = now;
  }

  void add(ECGData item) {
    extend([item]);
  }

  double get start => buffer.firstOrNull?.x ?? 0;
  double get end => buffer.lastOrNull?.x ?? 0;

  double get minX => start + offset + baseOffset;
  double get minY => start + offset + baseOffset + plotLength;

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
