import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:watchtower/ecg_data.dart';
import 'package:watchtower/ecg_graph.dart';

const timerInterval = Duration(milliseconds: 4);

class MockController extends GetxController {
  final String path;
  int index = 0;
  late List<double> data;
  late Timer timer;
  final BufferController bufferController;

  MockController(this.path, this.bufferController);

  @override
  void onInit() {
    super.onInit();

    final file = File(path);
    final content = file.readAsStringSync();
    final csv = const CsvToListConverter(eol: "\n").convert(content);

    data = csv.sublist(2).map((element) => element[1] as double).toList();

    timer = Timer.periodic(timerInterval, (timer) {
      final currentIndex = (index % data.length).toInt();
      bufferController.add(ECGData(index, data[currentIndex]));
      print("add: $currentIndex, len: ${data.length}");
      if (currentIndex == data.length - 1) {
        bufferController.doDetection();
        print("do det");
      }

      index++;
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
  }
}
