import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:watchtower/ecg_data.dart';

const displayStart = 2 * packLength;

class Graph extends StatelessWidget {
  const Graph({super.key});

  @override
  Widget build(BuildContext context) =>
      GetBuilder<BufferController>(builder: (controller) {
        int freshStart, freshEnd;
        if (controller.cursorIndex > bufferLength) {
          freshStart = controller.cursorIndex - bufferLength;
          freshEnd = bufferLength - 1;
        } else {
          freshStart = 0;
          freshEnd = controller.cursorIndex;
        }
        final staleStart = controller.cursorIndex + hiddenLength;
        final data = [
          charts.Series<ECGData, int>(
              id: "fresh",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value,
              data: ListSlice(controller.buffer, freshStart, freshEnd))
        ];
        if (staleStart < bufferLength) {
          data.add(charts.Series<ECGData, int>(
              id: "stale",
              domainFn: (ECGData item, _) => item.index,
              measureFn: (ECGData item, _) => item.value,
              data:
                  ListSlice(controller.buffer, staleStart, bufferLength - 1)));
        }
        return SizedBox(
            width: 400,
            height: 300,
            child: charts.LineChart(
              data,
              animate: false,
            ));
      });
}

const hiddenLength = packLength;
