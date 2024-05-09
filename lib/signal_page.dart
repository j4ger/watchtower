import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'main.dart';
import 'buffer_controller.dart';
import 'graph.dart';
import 'mock_device.dart';
import 'signal_controller.dart';
import 'mock_page.dart';

class SignalPage extends StatelessWidget {
  final Target target = Get.arguments;

  SignalPage({super.key});

  late final SignalController? signalController;
  late final MockController? mockController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              await CentralManager.instance
                  .disconnect(signalController!.device);
            }
            signalController!.dispose();
            Get.delete<SignalController>();
          } else {
            mockController!.dispose();
            Get.delete<MockController>();
          }
        },
        child: makePage(
            "View Signal",
            Column(
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
            showDrawerButton: false,
            actions: [
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
            ],
            floatingActionButton: Obx(() => FloatingActionButton.extended(
                  onPressed: switch (bufferController.state()) {
                    BufferControllerState.normal =>
                      bufferController.startRecord,
                    BufferControllerState.recording =>
                      bufferController.stopRecord,
                    BufferControllerState.saving => null
                  },
                  label: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) =>
                              FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axis: Axis.horizontal,
                                    child: child,
                                  )),
                      child: switch (bufferController.state()) {
                        BufferControllerState.normal => const Icon(
                            Icons.video_file,
                            key: ValueKey(BufferControllerState.normal)),
                        BufferControllerState.recording => Row(
                              key: const ValueKey(
                                  BufferControllerState.recording),
                              children: [
                                const Icon(Icons.stop_circle),
                                const SizedBox(width: 10),
                                Text(
                                  "${(bufferController.recordDuration() ~/ 60).toString().padLeft(2, '0')}:${(bufferController.recordDuration() % 60).toString().padLeft(2, '0')}",
                                  style: theme.textTheme.labelLarge,
                                )
                              ]),
                        BufferControllerState.saving => const SpinKitRing(
                            key: ValueKey(BufferControllerState.saving),
                            color: Colors.grey)
                      }),
                  backgroundColor: bufferController.state() ==
                          BufferControllerState.recording
                      ? Colors.redAccent
                      : null,
                ))));
  }
}

// TODO: use theme.colorscheme
