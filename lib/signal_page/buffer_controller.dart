import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watchtower/ecg_data.dart';

import '../record_page/record_controller.dart';
import '../algorithm/detector.dart';
import '../algorithm/pipeline.dart';
import '../constants.dart';
import '../utils.dart';

const intervalCorrectionRatio = 0.5;

const defaultInterval = Duration(milliseconds: delayMs);

class BufferController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final List<Pipeline>? pipelines;
  final Detector detector;
  // final PtPeakDetector detector;

  BufferController({this.pipelines, required this.detector});

  final debug = false.obs;

  final List<ECGData> buffer = [];

  DateTime? lastTimestamp;
  Duration interval = defaultInterval;

  int get cursorIndex => lastPackStart + tween.value;
  int get frameStartTimestamp =>
      lastPackEndTimestamp - lastPackEndTimestamp % graphBufferLength;

  int lastIndex = 0;

  int lastFreshIndex = 0;
  int lastPackStart = 0;
  int lastPackEndTimestamp = 0;

  late AnimationController animationController;
  late Animation<int> tween;

  bool get isFilled => buffer.length >= graphBufferLength;

  void reset() {
    lastIndex = 0;
    lastFreshIndex = 0;
    lastPackStart = 0;
    buffer.clear();
    interval = defaultInterval;

    processData.clear();
    preprocessedData.clear();
    finalAnnotation.clear();
    lastBeatTimestamp = 0;
    intervalHistory.clear();
  }

  void _add(ECGData item) {
    if (isFilled) {
      buffer[item.index] = (item);
    } else {
      buffer.add(item);
      updatePercentage();
    }
    if (state() == BufferControllerState.recording) {
      recordBuffer.add(item);
    }
  }

  void extend(List<ECGData> items) {
    // TODO: optimize this
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
    lastPackEndTimestamp = items.last.timestamp;

    process();
  }

  final percentage = 0.0.obs;
  void updatePercentage() {
    percentage.value = buffer.length / graphBufferLength;
  }

  List<ECGData> get actualData =>
      ListSlice(buffer, lastFreshIndex + 1, graphBufferLength) +
      ListSlice(
          buffer,
          0,
          lastFreshIndex +
              1); // TODO: optimize this by implementing an alternative indexed read

  final processData = <ECGData>[].obs;
  final preprocessedData = <ECGData>[].obs;
  final finalAnnotation = <int>[].obs;
  int lastBeatTimestamp = 0;
  final intervalHistory = <(int, int)>[].obs;

  void process() {
    List<ECGData> newProcessData = actualData;
    if (pipelines != null) {
      for (final step in pipelines!) {
        newProcessData = step.apply(newProcessData);
      }
    }
    processData.value = newProcessData;

    // TODO: fix debug view by implementing a way to extract pipeline status
    if (debug.value) {
      // preprocessedData.value = detector
      //   .preprocess(newProcessData)
      // .map((e) => ECGData(e.timestamp, e.value * 400))
      //  .toList();
    }

    finalAnnotation.value = detector.detect(newProcessData);

    if (finalAnnotation.isNotEmpty) {
      if (finalAnnotation.last != lastBeatTimestamp) {
        List<(int, int)> newIntervalHistory = [];
        lastBeatTimestamp = finalAnnotation.last;
        for (int i = 1; i < finalAnnotation.length; i++) {
          final newValue =
              (finalAnnotation[i] - finalAnnotation[i - 1]) * 1000 ~/ fs;
          newIntervalHistory.add((i - 1, newValue));
        }
        intervalHistory.value = newIntervalHistory;
      }
    }
  }

  Rx<double?> get heartRate => detector.heartRate;

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

  final state = BufferControllerState.normal.obs;
  DateTime? recordStartTime;
  final recordDuration = 0.obs;
  Timer? recordDurationTimer;
  final List<ECGData> recordBuffer = [];

  void startRecord() {
    recordStartTime = DateTime.now();
    recordDurationTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => recordDuration.value++);
    state.value = BufferControllerState.recording;
  }

  Future<void> stopRecord() async {
    state.value = BufferControllerState.recording;
    final recordStopTime = DateTime.now();
    final duration = recordStopTime.difference(recordStartTime!);
    final record = Record(recordStartTime!, duration, recordBuffer);

    final RecordController recordController = Get.find();
    await recordController.addRecord(record);

    state.value = BufferControllerState.normal;
    snackbar("Info", "Record successfully saved.");
    recordBuffer.clear();
    recordDurationTimer!.cancel();
    recordDurationTimer = null; // TODO: is this necessary?
  }
}

enum BufferControllerState { normal, recording, saving }