import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/bluetooth_page.dart';

const previousFileKey = "PreviousFile";

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
            MockPage(),
            BluetoothPage(),
          ])),
          bottomNavigationBar: BottomAppBar(
              color: Colors.white,
              elevation: 0,
              child: Center(child: Image.asset("assets/logo.png"))),
        ));
  }
}

class MockPageController extends GetxController {
  var previousFile = "".obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    previousFile.value = prefs.getString(previousFileKey) ?? "";
  }

  Future<void> save(String file) async {
    previousFile.value = file;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(previousFileKey, file);
  }
}

class MockPage extends StatelessWidget {
  MockPage({super.key});

  final controller = Get.put(MockPageController());

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    Get.toNamed("/signal",
                        arguments: Target(TargetType.mock,
                            path: controller.previousFile.value));
                  },
                )),
          const SizedBox(
            height: 10,
          ),
          FilledButton(
              onPressed: () async {
                try {
                  final String? path = (await FilePicker.platform.pickFiles(
                          allowMultiple: false,
                          type: FileType.custom,
                          allowedExtensions: ["csv"],
                          dialogTitle: "Select mock file"))
                      ?.files[0]
                      .path;
                  if (path != null) {
                    controller.save(path);
                    Get.toNamed("/signal",
                        arguments: Target(TargetType.mock, path: path));
                  } else {
                    Get.snackbar("Cancelled", "No file was selected.");
                  }
                } on PlatformException catch (e) {
                  Get.snackbar("Error", "Failed to open file dialog: $e");
                }
              },
              child: const Text("Open File"))
        ]));
  }
}
