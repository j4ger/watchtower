import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/bluetooth_page.dart';
import 'package:watchtower/signal_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Watchtower',
        themeMode: ThemeMode.system,
        home: const BluetoothPage(),
        routes: {
          'signal': (context) {
            // TODO: probably shouldn't use modal route
            final route = ModalRoute.of(context);
            final eventArgs = route!.settings.arguments as DiscoveredEventArgs;
            return SignalPage(
              eventArgs: eventArgs,
            );
          }
        });
  }
}

// TODO: use getx to simplify code
// TODO: use flutter/packages - animations - shared axis for transitions
// TODO: dark mode
