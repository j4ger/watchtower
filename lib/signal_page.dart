import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:watchtower/graph.dart';
import 'package:watchtower/mock_device.dart';
import 'package:watchtower/signal_controller.dart';
import 'package:watchtower/target_page.dart';

class SignalPage extends StatelessWidget {
  final Target target = Get.arguments;

  SignalPage({super.key});

  late final SignalController? signalController;
  late final MockController? mockController;

  @override
  Widget build(BuildContext context) {
    final bufferController = Get.find<BufferController>();
    if (target.isMock) {
      mockController = Get.find<MockController>();
    } else {
      signalController = Get.find<SignalController>();
    }

    return PopScope(
      onPopInvoked: (didPop) async {
        if (!target.isMock) {
          if (signalController!.connectionState.value) {
            await CentralManager.instance.disconnect(signalController!.device);
          }
          signalController!.dispose();
          Get.delete<SignalController>();
        } else {
          mockController!.dispose();
          Get.delete<MockController>();
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
              // const ECGGraph(),
              Obx(() => bufferController.percentage.value == 1.0
                  ? Expanded(child: Graph())
                  : Container()),
              // PipelineGraph(pipelines, detectors)
            ],
          ),
        ),
      ),
    );
  }
}

// TODO: use theme.colorscheme
