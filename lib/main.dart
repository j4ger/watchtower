import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'constants.dart';
import 'navigation.dart';

/// app entry
Future main() async {
  /// initialize a few common controllers, defined in constants.dart
  initGlobalControllers();

  /// sqflite quirks
  /// on Android, the SQLite lib provided by system doesn't play well with BLOB data
  /// we ship our own libs with sqlite3_flutter_libs
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }
  databaseFactory = databaseFactoryFfi;

  /// render UI
  runApp(App());
}

/// main app view
class App extends StatelessWidget {
  /// state of navigationDrawer
  final selectedIndex = 0.obs;

  App({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return GetMaterialApp(
        title: 'Watchtower',

        /// app title displayed in system app switcher, etc.
        themeMode: ThemeMode.system,
        navigatorKey: Get.key,
        initialRoute: entryURL,
        builder: (context, child) => Scaffold(
              key: scaffoldKey,

              /// inject global navigationDrawer
              drawer: Obx(() => NavigationDrawer(
                    selectedIndex: selectedIndex(),
                    onDestinationSelected: (index) {
                      selectedIndex.value = index;
                      Get.toNamed("/${shownNavigationList[index].name}");
                      scaffoldKey.currentState!.closeDrawer();
                    },
                    children: [
                      /// logo image
                      Padding(
                          padding: const EdgeInsets.fromLTRB(28, 16, 24, 10),
                          child: Center(child: Image.asset("assets/logo.png"))),

                      /// navigationDrawer items
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

// TODO: dark mode
// TODO: unified error logging
