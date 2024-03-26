import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watchtower/detector.dart';
import 'package:watchtower/ecg_data.dart';

const bufferLength = 600;
const delayMs = 300;
const packLength = 50;

const intervalCorrectionRatio = 0.5;

const defaultInterval = Duration(milliseconds: delayMs);

class BufferController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final List<ECGData> buffer = [];

  DateTime? lastTimestamp;
  Duration interval = defaultInterval;

  int get cursorIndex => lastPackStart + tween.value;
  int lastIndex = 0;

  int lastFreshIndex = 0;
  int lastPackStart = 0;

  late AnimationController animationController;
  late Animation<int> tween;

  bool get isFilled => buffer.length >= bufferLength;

  void _add(ECGData item) {
    if (isFilled) {
      buffer[item.index] = (item);
    } else {
      buffer.add(item);
      updatePercentage();
    }
  }

  void extend(List<ECGData> items) {
    for (ECGData item in items) {
      _add(item);
    }
    final now = DateTime.now();
    if (lastTimestamp != null) {
      final delta = now.difference(lastTimestamp!);
      interval = interval * (1 - intervalCorrectionRatio) +
          delta * intervalCorrectionRatio;
      animationController.duration = interval;
      animationController.reset();
      animationController.forward();
    }
    lastTimestamp = now;
    lastFreshIndex = items.last.index;
    lastPackStart = items.first.index;
  }

  int? heartRate;
  List<VerticalLine> annotations = [];

  final detector = QRSDetector(250, 0.9);

  void doDetection() {
    if (isFilled) {
      annotations = detector.detect(buffer);
      heartRate = detector.heartRate?.floor();
    }
  }

  final percentage = 0.0.obs;
  void updatePercentage() {
    percentage.value = buffer.length / bufferLength;
  }

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(vsync: this, duration: interval);
    tween = IntTween(begin: 0, end: packLength - 1).animate(animationController)
      ..addListener(() {
        final current = cursorIndex;
        if (lastIndex != current) {
          update();
          lastIndex = current;
        }
      });
    animationController.forward();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
}
