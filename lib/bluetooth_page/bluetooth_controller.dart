import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:get/get.dart';

import '../signal_page/buffer_controller.dart';

// TODO: timeout and stop

class BluetoothController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final BufferController bufferController = Get.find();

  late AnimationController spinnerController;

  var state = BluetoothLowEnergyState.unknown.obs;
  var discovering = false.obs;
  var discoveredEventArgs = [].obs;

  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription discoveredSubscription;

  void onStartUp() async {
    // TODO: reduce logging level after debugging
    // CentralManager.instance.logLevel = Level.WARNING;
    WidgetsFlutterBinding.ensureInitialized();
    spinnerController.stop();
    await CentralManager.instance.setUp();
    state.value = await CentralManager.instance.getState();
    await startDiscovery();
  }

  void onCrashed(Object error, StackTrace stackTrace) {
    Get.defaultDialog(
      title: "Error",
      barrierDismissible: false,
      middleText: "Failed to initialize BLE: $error\nRestart app to retry.",
    );
  }

  Future<void> startDiscovery() async {
    discoveredEventArgs.value = [];
    await CentralManager.instance.startDiscovery();
    discovering.value = true;
    spinnerController.repeat();
  }

  Future<void> stopDiscovery() async {
    await CentralManager.instance.stopDiscovery();
    discovering.value = false;
    spinnerController.stop();
  }

  @override
  void onInit() {
    spinnerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    stateChangedSubscription = CentralManager.instance.stateChanged.listen(
      (eventArgs) {
        state.value = eventArgs.state;
      },
    );
    discoveredSubscription = CentralManager.instance.discovered.listen(
      (eventArgs) {
        final items = discoveredEventArgs;
        final i = items.indexWhere(
          (item) => item.peripheral == eventArgs.peripheral,
        );
        if (i < 0) {
          discoveredEventArgs.value = [...items, eventArgs];
        } else {
          items[i] = eventArgs;
          discoveredEventArgs.value = [...items];
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runZonedGuarded(onStartUp, onCrashed);
    });
    super.onInit();
  }

  @override
  void dispose() {
    stateChangedSubscription.cancel();
    discoveredSubscription.cancel();
    super.dispose();
  }
}
