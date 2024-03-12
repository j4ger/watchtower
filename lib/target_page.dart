import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:watchtower/bluetooth_page.dart';

enum TargetType { ble, mock }

class Target {
  final TargetType type;
  final String? path;
  final Peripheral? device;

  Target(this.type, {this.path, this.device});

  bool get isMock => type == TargetType.mock;
}

class TargetPage extends StatelessWidget {
  const TargetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        initialIndex: 0,
        length: 2,
        child: Scaffold(
            appBar: AppBar(
                title: const Text("Select device"),
                bottom: const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.description), text: "Mock"),
                    Tab(icon: Icon(Icons.bluetooth), text: "Bluetooth")
                  ],
                )),
            body: SafeArea(
                child: TabBarView(children: [
              const MockPage(),
              BluetoothPage(),
            ]))));
  }
}

class MockPage extends StatelessWidget {
  const MockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        alignment: AlignmentDirectional.center,
        child: FilledButton(
            onPressed: () async {
              try {
                final String? path = (await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        allowedExtensions: ["csv"],
                        dialogTitle: "Select mock file"))
                    ?.files[0]
                    .path;
                if (path != null) {
                  Get.toNamed("/signal",
                      arguments: Target(TargetType.mock, path: path));
                }
              } on PlatformException catch (e) {
                Get.snackbar("Error", "Failed to open file dialog: $e");
              }
            },
            child: const Text("Open File")));
  }
}
