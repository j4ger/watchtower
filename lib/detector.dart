import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iirjdart/butterworth.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';
import 'package:watchtower/ecg_data.dart';

const filterLowCut = 8.0;
const filterHighCut = 20.0;
const integrationWindowSize = 10;
const shiftLength = 12;
const updateRatio = 0.7;

class QRSDetector {
  double sampleRate;
  double threshold;
  late final Butterworth filterLow;
  late final Butterworth filterHigh;
  double? heartRate;

  QRSDetector(this.sampleRate, this.threshold)
      : filterLow = Butterworth()..lowPass(1, 2, filterLowCut * 2 / sampleRate),
        filterHigh = Butterworth()
          ..highPass(1, 2, filterHighCut * 2 / sampleRate);

  List<VerticalLine> detect(List<ECGData> data) {
    final baseIndex = data.first.timestamp;
    filterLow.reset();
    filterHigh.reset();
    // TODO: potential performance optimization
    final filteredData = Array(List.generate(data.length,
        (i) => filterHigh.filter(filterLow.filter(data[i].value))));
    // final differentiatedData = List.generate(
    //     filteredData.length - 1, (i) => filteredData[i + 1] - filteredData[i]);
    // final squaredData = differentiatedData.map((item) => item * item).toList();
    // final integratedData = convolution(Array(squaredData),
    //     ones(integrationWindowSize)); // TODO: use fast parameter

    final thresholdValue = arrayMax(filteredData) * threshold;

    final peaksRes = findPeaks(filteredData, threshold: thresholdValue);
    final List<double> peaks = peaksRes[0].toList();

    // TODO: remove peaks that are too close

    double? avgHeartRate = peaks.length > 1
        ? (peaks.length - 1) / (peaks.last - peaks.first) * sampleRate * 60
        : null;
    if (heartRate != null) {
      if (avgHeartRate != null) {
        heartRate = heartRate! * (1 - updateRatio) + avgHeartRate * updateRatio;
      }
    } else {
      heartRate = avgHeartRate;
    }

    return peaks
        .map((double x) => VerticalLine(
            x: x + baseIndex - shiftLength,
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.2),
                ],
                stops: const [
                  0.2,
                  0.5,
                  0.8,
                ])))
        .toList();
  }
}
