import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watchtower/algorithm/ECG/clean.dart';
import 'package:watchtower/algorithm/pipeline.dart';
import 'package:watchtower/mock_device.dart';
import 'package:watchtower/pipeline_graph.dart';
import 'package:watchtower/signal_controller.dart';
import 'package:watchtower/target_page.dart';

import 'ecg_graph.dart';

class SignalPage extends StatelessWidget {
  final Target target = Get.arguments;

  SignalPage({super.key}) {
    if (target.isMock) {
      mockController = Get.put(MockController(target.path!, bufferController));
    } else {
      signalController =
          Get.put(SignalController(target.device!, bufferController));
    }
  }

  final bufferController = Get.put(BufferController());
  late final SignalController? signalController;
  late final MockController? mockController;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (!target.isMock) {
          if (signalController!.connectionState.value) {
            await CentralManager.instance.disconnect(signalController!.device);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("View Signal"), actions: [
          if (!target.isMock)
            Obx(() => signalController!.connectionState.value
                ? IconButton(
                    icon: const Icon(Icons.bluetooth_connected),
                    iconSize: 24,
                    color: Colors.greenAccent,
                    onPressed: () {
                      signalController!.disconnect();
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    iconSize: 24,
                    color: Colors.yellowAccent,
                    onPressed: () {
                      signalController!.connect();
                    },
                  ))
        ]),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() => bufferController.percentage.value != 1.0
                  ? TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(
                          begin: 0, end: bufferController.percentage.value),
                      builder: (context, value, child) =>
                          LinearProgressIndicator(value: value))
                  : Container()),
              const ECGGraph(),
              PipelineGraph(pipelines: pipelines)
            ],
          ),
        ),
      ),
    );
  }
}

const fs = 250;
final List<Pipeline> pipelines = [CleanPT(fs), CleanNK(fs)];

// TODO: alternative method: plot all the data and only change minX and maxX
// TODO: use theme.colorscheme
