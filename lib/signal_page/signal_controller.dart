// TODO: should probably move this to bluetooth-related directory

import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import "package:get/get.dart";

import '../bluetooth_page/bluetooth_device.dart';
import '../ecg_data.dart';
import '../utils.dart';
import 'buffer_controller.dart';

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
        snackbar("Error", "Failed to connect to device: $error");
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
        snackbar("Error", "Failed to connect to device: $error");
      },
    );
  }
}
