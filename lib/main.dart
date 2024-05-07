import 'dart:io';

import 'package:flutter/material.dart';
import 'package:watchtower/signal_page.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'algorithm/ECG/clean.dart';
import 'algorithm/ECG/find_peaks.dart';
import 'bluetooth_page.dart';
import 'buffer_controller.dart';
import 'record_page.dart';
import 'mock_page.dart';

Future main() async {
  Get.put(BufferController(pipelines: pipelines, detector: detector));
  Get.put(RecordController());
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }
  databaseFactory = databaseFactoryFfi; // TODO: test this on mobile platforms
  runApp(App());
}

class App extends StatelessWidget {
  final selectedIndex = 0.obs;
  App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    return GetMaterialApp(
        title: 'Watchtower',
        themeMode: ThemeMode.system,
        navigatorKey: Get.key,
        initialRoute: '/bluetooth',
        builder: (context, child) => Scaffold(
              key: scaffoldKey,
              drawer: Obx(() => NavigationDrawer(
                    selectedIndex: selectedIndex(),
                    onDestinationSelected: (index) {
                      selectedIndex.value = index;
                      Get.toNamed("/${shownNavigationList[index].name}");
                      scaffoldKey.currentState!.closeDrawer();
                    },
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(28, 16, 24, 10),
                          child: Center(child: Image.asset("assets/logo.png"))),
                      ...shownNavigationList.map((entry) =>
                          NavigationDrawerDestination(
                              label: Text(entry.title),
                              icon: Icon(entry.icon),
                              selectedIcon: Icon(entry.selectedIcon)))
                    ],
                  )),
              body: child,
            ),
        getPages: navigationList
            .map((entry) => GetPage(
                name: "/${entry.name}",
                page: entry.page,
                title: entry.title,
                transition: Transition.native))
            .toList());
  }
}

// TODO: use flutter/packages - animations - shared axis for transitions
// TODO: dark mode
// TODO: unified error logging

const fs =
    333; // for csv data exported from https://archive.physionet.org/cgi-bin/atm/ATM
final pipelines = [CleanPT(fs)];
final detector = PtPeakDetector(fs);

// TODO: move bluetoothpage and mockpage into separate pages
// TODO: hide signalpage
final List<AppPage> navigationList = [
  AppPage("bluetooth", "Setup Bluetooth Device", () => BluetoothPage(),
      Icons.devices_other, Icons.devices_other_outlined),
  AppPage("mock", "Setup Mock Device", () => MockPage(), Icons.file_open,
      Icons.file_open_outlined),
  AppPage("signal", "View Signal", () => SignalPage(), Icons.timeline,
      Icons.timeline_outlined,
      hidden: true),
  AppPage("record", "Record Management", () => RecordPage(), Icons.save,
      Icons.save_rounded)
];

final List<AppPage> shownNavigationList =
    navigationList.where((item) => !item.hidden).toList();

class AppPage {
  final String name;
  final String title;
  final Widget Function() page;
  final IconData icon;
  final IconData selectedIcon;
  final bool hidden;
  AppPage(this.name, this.title, this.page, this.icon, this.selectedIcon,
      {this.hidden = false});
}

// TODO: extract components into their own files

class DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showDrawerButton;
  final List<Widget> actions;
  const DefaultAppBar(this.title,
      {this.showDrawerButton = true, this.actions = const [], super.key});

  @override
  Widget build(BuildContext context) {
    final ScaffoldState? scaffoldState =
        context.findRootAncestorStateOfType<ScaffoldState>();
    return AppBar(
      leading: showDrawerButton
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: scaffoldState?.openDrawer,
            )
          : null,
      title: Text(title),
      actions: actions,
    );
  }

  @override
  final Size preferredSize = const Size.fromHeight(kToolbarHeight);
}

Widget makePage(String title, Widget body,
        {bool showDrawerButton = true,
        List<Widget> actions = const [],
        Widget? floatingActionButton}) =>
    Scaffold(
      appBar: DefaultAppBar(title,
          showDrawerButton: showDrawerButton, actions: actions),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );

void snackbar(String title, String message) {
  Get.showSnackbar(GetSnackBar(
    title: title,
    message: message,
  ));
}
