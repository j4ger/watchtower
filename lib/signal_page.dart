import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/bluetooth_device.dart';
import 'package:watchtower/ecg_data.dart';
import 'package:get/get.dart';
import 'package:watchtower/mock_device.dart';
import 'package:watchtower/target_page.dart';

import 'ecg_graph.dart';

class SignalController extends GetxController {
  final connectionState = false.obs;
  final Peripheral device;
  final BufferController bufferController;

  SignalController(this.device, this.bufferController);

  late StreamSubscription connectionStateChangedSubscription;
  late StreamSubscription characteristicNotifiedSubscription;

  @override
  void onInit() {
    super.onInit();

    CentralManager.instance.connectionStateChanged.listen(
      (eventArgs) {
        if (eventArgs.peripheral != device) {
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

    await CentralManager.instance.connect(device).onError(
      (error, stackTrace) {
        Get.snackbar("Error", "Failed to connect to device: $error");
      },
    );
    final services = await CentralManager.instance.discoverGATT(device);
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
    await CentralManager.instance.disconnect(device).onError(
      (error, stackTrace) {
        Get.snackbar("Error", "Failed to connect to device: $error");
      },
    );
  }
}

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
