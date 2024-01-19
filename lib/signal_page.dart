import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/bluetooth_device.dart';
import 'package:watchtower/ecg_data.dart';
import 'package:get/get.dart';

import 'ecg_graph.dart';

class SignalController extends GetxController {
  final connectionState = false.obs;
  DiscoveredEventArgs eventArgs = Get.arguments;
  late final StreamSubscription connectionStateChangedSubscription;
  late final StreamSubscription characteristicNotifiedSubscription;

  final BufferController bufferController = Get.find();

  @override
  void onInit() {
    super.onInit();

    connectionStateChangedSubscription =
        CentralManager.instance.connectionStateChanged.listen(
      (eventArgs) {
        if (eventArgs.peripheral != this.eventArgs.peripheral) {
          return;
        }
        final connectionState = eventArgs.connectionState;
        this.connectionState.value = connectionState;
      },
    );
    characteristicNotifiedSubscription =
        CentralManager.instance.characteristicNotified.listen(
      (eventArgs) {
        if (eventArgs.characteristic.uuid != targetCharateristic) {
          return;
        }
        final packet = eventArgs.value;
        final data = ECGData.fromPacket(packet);
        bufferController.extend(data);
        bufferController.doDetection();
        bufferController.update();
      },
    );

    runZonedGuarded(connect, onCrashed);
  }

  void onCrashed(Object error, StackTrace stackTrace) {
    Get.defaultDialog(
      title: "Error",
      barrierDismissible: false,
      middleText:
          "Critical error occurred during BLE connection: $error\nRestart app to retry.",
    );
  }

  void connect() async {
    // TODO: full screen cover while connecting

    await CentralManager.instance.connect(eventArgs.peripheral).onError(
      (error, stackTrace) {
        Get.snackbar("Error", "Failed to connect to device: $error");
      },
    );
    final services =
        await CentralManager.instance.discoverGATT(eventArgs.peripheral);
    // TODO: better error management
    GattCharacteristic? target;
    outer:
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == targetCharateristic) {
          target = characteristic;
          break outer;
        }
      }
    }
    if (target == null) {
      Get.defaultDialog(
          title: "Error",
          middleText: "Not a valid device.",
          textConfirm: "OK",
          onConfirm: () {
            Get.offAllNamed("/bluetooth");
          });
      return;
    }
    await CentralManager.instance
        .setCharacteristicNotifyState(target, state: true);
  }

  void disconnect() async {
    await CentralManager.instance.disconnect(eventArgs.peripheral).onError(
      (error, stackTrace) {
        Get.snackbar("Error", "Failed to connect to device: $error");
      },
    );
  }
}

class SignalPage extends StatelessWidget {
  SignalPage({super.key});
  final bufferController = Get.put(BufferController());
  final controller = Get.put(SignalController());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (controller.connectionState.value) {
          final peripheral = controller.eventArgs.peripheral;
          await CentralManager.instance.disconnect(peripheral);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("View Signal"), actions: [
          Obx(() => controller.connectionState.value
              ? IconButton(
                  icon: const Icon(Icons.bluetooth_connected),
                  iconSize: 24,
                  color: Colors.greenAccent,
                  onPressed: () {
                    controller.disconnect();
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  iconSize: 24,
                  color: Colors.yellowAccent,
                  onPressed: () {
                    controller.connect();
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
              const ECGGraph()
            ],
          ),
        ),
      ),
    );
  }
}

// TODO: alternative method: plot all the data and only change minX and maxX
// TODO: use theme.colorscheme
