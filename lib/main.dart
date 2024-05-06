import 'dart:io';

import 'package:flutter/material.dart';
import 'package:watchtower/signal_page.dart';
import 'package:get/get.dart';
import 'package:watchtower/target_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'algorithm/ECG/clean.dart';
import 'algorithm/ECG/find_peaks.dart';
import 'buffer_controller.dart';
import 'record_page.dart';

Future main() async {
  Get.put(BufferController(pipelines: pipelines, detector: detector));
  Get.put(RecordController());
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }
  databaseFactory = databaseFactoryFfi; // TODO: test this on mobile platforms
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

// TODO: use flutter/packages - animations - shared axis for transitions
// TODO: dark mode
// TODO: unified error logging

const fs =
    333; // for csv data exported from https://archive.physionet.org/cgi-bin/atm/ATM
final pipelines = [CleanPT(fs)];
final detector = PtPeakDetector(fs);
