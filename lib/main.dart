import 'package:flutter/material.dart';
import 'package:watchtower/bluetooth_page.dart';
import 'package:watchtower/signal_page.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Watchtower',
      themeMode: ThemeMode.system,
      initialRoute: '/bluetooth',
      getPages: [
        GetPage(name: "/bluetooth", page: () => BluetoothPage()),
        GetPage(
            name: "/signal",
            page: () => SignalPage(),
            transition: Transition.cupertino)
      ],
    );
  }
}

// TODO: use getx to simplify code
// TODO: use flutter/packages - animations - shared axis for transitions
// TODO: dark mode
