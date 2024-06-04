import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../benchmark/benchmark.dart';
import '../navigation.dart';
import '../signal_page/signal_source.dart';
import '../utils.dart';
import 'mock_controller.dart';
import 'mock_device.dart';

class MockPage extends StatelessWidget {
  MockPage({super.key});

  final controller = Get.put(MockPageController());

  @override
  Widget build(BuildContext context) {
    return makePage(
        "Setup Mock Device",
        Container(
            alignment: AlignmentDirectional.center,
            child: Column(children: [
              const SizedBox(
                height: 10,
              ),
              Obx(() => controller.previousFile.value == ""
                  ? Container()
                  : FilledButton(
                      child: const Text("Load Previous"),
                      onPressed: () {
                        controller.bufferController.reset();
                        Get.put(MockController(controller.previousFile.value,
                            controller.bufferController));
                        Get.toNamed("/signal",
                            arguments: SignalSource(SignalSourceType.mock,
                                path: controller.previousFile
                                    .value)); // TODO: redesign this
                      },
                    )),
              const SizedBox(
                height: 10,
              ),
              FilledButton(
                  onPressed: () async =>
                      awaitWithOverlay(controller.promptLoadFromDataset),
                  child: const Text("Open File")),
              const SizedBox(
                height: 10,
              ),
              FilledButton(
                  onPressed: () async =>
                      awaitWithOverlay(controller.promptLoadIntoDB),
                  child: const Text("Load file to database")),
              const SizedBox(height: 10),
              FilledButton(
                  onPressed: () async => awaitWithOverlay(promptBench),
                  child: const Text("Begin Benchmarking"))
            ])));
  }
}
