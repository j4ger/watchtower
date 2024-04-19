import 'package:flutter/material.dart';
import 'package:watchtower/signal_page.dart';
import 'package:get/get.dart';
import 'package:watchtower/target_page.dart';

import 'algorithm/ECG/clean.dart';
import 'algorithm/ECG/find_peaks.dart';
import 'buffer_controller.dart';

void main() {
  Get.put(BufferController(pipelines: pipelines, detector: detector));
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
      initialRoute: '/target',
      getPages: [
        GetPage(name: "/target", page: () => const TargetPage()),
        GetPage(
          name: "/signal",
          page: () => SignalPage(),
        )
      ],
    );
  }
}

// TODO: use getx to simplify code
// TODO: use flutter/packages - animations - shared axis for transitions
// TODO: dark mode

const fs =
    333; // for csv data exported from https://archive.physionet.org/cgi-bin/atm/ATM
final pipelines = [CleanPT(fs)];
final detector = PtPeakDetector(fs);
