import 'dart:async';

import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:get/get.dart';
import 'package:watchtower/target_page.dart';

import 'buffer_controller.dart';
import 'rssi_widget.dart';
import 'signal_controller.dart';

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

class BluetoothPage extends StatelessWidget {
  BluetoothPage({super.key});
  final controller = Get.put(BluetoothController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(
                width: 10,
              ),
              SpinKitDoubleBounce(
                color: Colors.lightBlueAccent,
                size: 25,
                controller: controller.spinnerController,
              ),
              const SizedBox(
                width: 5,
              ),
              const Text("Peripherals:"),
            ]),
            const SizedBox(
              height: 5,
            ),
            Obx(
              () {
                final items = controller.discoveredEventArgs
                    .where((eventArgs) => eventArgs.advertisement.name != null)
                    .toList();
                return Expanded(
                    child: ListView.separated(
                  itemBuilder: (context, i) {
                    final theme = Theme.of(context);
                    final item = items[i];
                    final uuid = item.peripheral.uuid;
                    final rssi = item.rssi;
                    final advertisement = item.advertisement;
                    final name = advertisement.name;
                    return ListTile(
                      onTap: () async {
                        final discovering = controller.discovering.value;
                        if (discovering) {
                          await controller.stopDiscovery();
                        }
                        controller.bufferController.reset();
                        Get.put(SignalController(
                            controller.discoveredEventArgs[i].peripheral,
                            controller.bufferController));
                        Get.toNamed("/signal",
                            arguments: Target(TargetType.ble,
                                device: controller.discoveredEventArgs[i]
                                    .peripheral)); // TODO: redesign this
                      },
                      title: Text(name ?? 'N/A'),
                      subtitle: Text(
                        '$uuid',
                        style: theme.textTheme.bodySmall,
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RssiWidget(rssi),
                          Text('$rssi'),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (context, i) {
                    return const Divider(
                      height: 0.0,
                    );
                  },
                  itemCount: items.length,
                ));
              },
            )
          ],
        ),
        floatingActionButton: Obx(() => FloatingActionButton(
              onPressed: controller.state() == BluetoothLowEnergyState.poweredOn
                  ? () async {
                      if (controller.discovering.value) {
                        await controller.stopDiscovery();
                      } else {
                        await controller.startDiscovery();
                      }
                    }
                  : null,
              tooltip: 'Scan',
              child: Icon(
                  controller.discovering.value ? Icons.stop : Icons.refresh),
            )));
  }
}
