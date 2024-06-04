import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'constants.dart';
import 'navigation.dart';

Future main() async {
  initGlobalControllers();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }
  databaseFactory = databaseFactoryFfi; // TODO: test this on mobile platforms

  runApp(App());
}

class App extends StatelessWidget {
  final selectedIndex = 0.obs;
  App({super.key});

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

// TODO: dark mode
// TODO: unified error logging
