import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:get/get.dart';

import '../navigation.dart';
import '../signal_page/signal_controller.dart';
import '../signal_page/signal_source.dart';
import 'rssi_widget.dart';
import 'bluetooth_controller.dart';

class BluetoothPage extends StatelessWidget {
  BluetoothPage({super.key});
  final controller = Get.put(BluetoothController());

  @override
  Widget build(BuildContext context) {
    return makePage(
        "Select Bluetooth Device",
        Column(
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
                            arguments: SignalSource(SignalSourceType.ble,
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
