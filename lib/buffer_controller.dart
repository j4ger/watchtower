import 'package:circular_buffer/circular_buffer.dart';
import 'package:collection/collection.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watchtower/ecg_data.dart';

const largeBufferLength = 2500; // 2500 / 250 s^-1 = 10s

const bufferLength = 600;
const delayMs = 300;
const packLength = 50;

const intervalCorrectionRatio = 0.5;

const defaultInterval = Duration(milliseconds: delayMs);

class BufferController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final List<ECGData> buffer = [];

  // TODO: largeBuffer is not actually large
  // final CircularBuffer<ECGData> largeBuffer = CircularBuffer(largeBufferLength);
  List<ECGData> get largeBuffer => isFilled
      ? ListSlice(buffer, lastFreshIndex + 1, bufferLength) +
          ListSlice(buffer, 0, lastFreshIndex)
      : [];

  DateTime? lastTimestamp;
  Duration interval = defaultInterval;

  int get cursorIndex => lastPackStart + tween.value;
  int lastIndex = 0;

  int lastFreshIndex = 0;
  int lastPackStart = 0;

  late AnimationController animationController;
  late Animation<int> tween;

  bool get isFilled => buffer.length >= bufferLength;

  void reset() {
    lastIndex = 0;
    lastFreshIndex = 0;
    lastPackStart = 0;
    buffer.clear();
    interval = defaultInterval;
  }

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
    // largeBuffer.addAll(items);
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

  // final detector = QRSDetector(250, 0.9);

  void doDetection() {
    // TODO:
  }

  final percentage = 0.0.obs;
  void updatePercentage() {
    percentage.value = buffer.length / bufferLength;
  }

  List<ECGData> get actualData =>
      ListSlice(buffer, lastFreshIndex, bufferLength) +
      ListSlice(buffer, 0, lastFreshIndex);

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
//    animationController.forward();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
}
