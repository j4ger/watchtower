/// controls graph render process
library;

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

/// the ratio used to update predicted `nextPacketInterval`
const intervalCorrectionRatio = 0.5;

const defaultInterval = Duration(milliseconds: delayMs);

/// `GetSingleTickerProviderStateMixin` is used to provide ticker for cursor tween AnimationController
class BufferController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final List<Pipeline>? pipelines;
  final Detector detector;

  BufferController({this.pipelines, required this.detector});

  /// this is currently unimplemented, until a better way to extract pipeline mid-stage status is decided
  final debug = false.obs;

  /// actual buffer for rendering
  /// a fixed length list to save up memory
  /// every write should perform according to a calculated `index`
  /// in order to achieve a wipe-off/overwrite effect
  final List<ECGData> buffer = [];

  /// the time when the last packet arrived
  DateTime? lastPackArrivalTime;

  /// predicted interval of packets
  Duration interval = defaultInterval;

  /// the current index of cursor
  int get cursorIndex => firstFreshIndex + tween.value;

  /// the timestamp of the first frame, of the latest packet
  int get frameStartTimestamp =>
      lastFreshTimestamp - lastFreshTimestamp % graphBufferLength;

  /// the cursor index, when the ticker ticked last time
  /// used to determine whether a rerender should be triggered
  int lastIndex = 0;

  /// the index of the last frame, of the latest packet
  int lastFreshIndex = 0;

  /// the timestamp of the last frame, of the latest packet
  int lastFreshTimestamp = 0;

  /// the index of the first frame, of the latest packet
  int firstFreshIndex = 0;

  /// controls the IntTween
  late AnimationController animationController;

  /// tweens the cursor between packets
  late Animation<int> tween;

  /// whether the initial data has been filled
  bool get isFilled => buffer.length >= graphBufferLength;

  /// reset everything
  void reset() {
    lastIndex = 0;
    lastFreshIndex = 0;
    firstFreshIndex = 0;
    buffer.clear();
    interval = defaultInterval;

    processData.clear();
    preprocessedData.clear();
    finalAnnotation.clear();
    lastBeatTimestamp = 0;
    intervalHistory.clear();
  }

  /// push a frame into the buffer
  void _add(ECGData item) {
    if (isFilled) {
      buffer[item.index] = (item);
    } else {
      buffer.add(item);
      updatePercentage();
    }
  }

  /// pushes a list of frames into the buffer
  void extend(List<ECGData> items) {
    // TODO: optimize this
    for (ECGData item in items) {
      _add(item);
    }
    if (state() == BufferControllerState.recording) {
      recordBuffer.addAll(items);
    }

    final now = DateTime.now();
    if (lastPackArrivalTime != null) {
      /// update interval prediction
      final delta = now.difference(lastPackArrivalTime!);
      interval = interval * (1 - intervalCorrectionRatio) +
          delta * intervalCorrectionRatio;
      animationController.duration = interval;

      /// let the animation catch on
      animationController.reset();
      animationController.forward();
    }

    lastPackArrivalTime = now;
    lastFreshIndex = items.last.index;
    firstFreshIndex = items.first.index;
    lastFreshTimestamp = items.last.timestamp;

    process();
  }

  /// represents how full is the buffer
  /// is this really necessary?
  final percentage = 0.0.obs;
  void updatePercentage() {
    percentage.value = buffer.length / graphBufferLength;
  }

  /// cuts and shifts the buffer so that frames are sorted by their timestamp
  List<ECGData> get actualData =>
      ListSlice(buffer, lastFreshIndex + 1, graphBufferLength) +
      ListSlice(
          buffer,
          0,
          lastFreshIndex +
              1); // TODO: optimize this by implementing an alternative indexed read

  /// data after pipeline process
  final processData = <ECGData>[].obs;

  /// data after detector preprocessing, currently unused
  final preprocessedData = <ECGData>[].obs;

  /// detector result
  final finalAnnotation = <int>[].obs;

  /// the timestamp of the last r-peak
  int lastBeatTimestamp = 0;

  /// data for interval history graph
  final intervalHistory = <(int, int)>[].obs;

  /// apply pipeline and detection
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

  /// proxy heartrate from detector
  Rx<double?> get heartRate => detector.heartRate;

  /// initialize tween controller
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

  /// dispose tween controller
  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  /// record state
  final state = BufferControllerState.normal.obs;
  DateTime? recordStartTime;
  final recordDuration = 0.obs;

  /// a timer for displaying record duration
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
