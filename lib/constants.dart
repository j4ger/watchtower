/// declares some shared constants
library;

import 'package:get/get.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'algorithm/ECG/pt/clean.dart';
import 'algorithm/ECG/pt/detect.dart';
import 'signal_page/buffer_controller.dart';
import 'record_page/record_controller.dart';

/// frames in a packet transfer
const packLength = 50;

/// sample rate
// TODO: decide sample rate
const int fs =
    333; // for csv data exported from https://archive.physionet.org/cgi-bin/atm/ATM

/// pipelines for pre-processing
final pipelines = [CleanPT(fs)];

/// detector
final detector = PtPeakDetector(fs);

const int delayMs = 1000 ~/ fs * packLength;

const int graphBufferLength = 600;

const int peakBufferCapacity = 12;

void initGlobalControllers() {
  Get.put(BufferController(pipelines: pipelines, detector: detector));
  Get.put(RecordController());
}

const freshColor = charts.Color(r: 0xdb, g: 0x16, b: 0x16);
const staleColor = charts.Color(r: 0xee, g: 0xcc, b: 0xcc);

const hiddenColor = charts.Color(r: 0xfe, g: 0xfe, b: 0xfe);

const upperLimit = 1.5;
const lowerLimit = -1;

const markLength = 40;
const markColor = charts.Color(r: 0xff, g: 0xbf, b: 0xb8);

const averageLineColor = charts.Color(r: 0xff, g: 0x63, b: 0x61);
