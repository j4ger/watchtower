import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:watchtower/ecg_data.dart';

const timerInterval = Duration(milliseconds: 200);

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
      List<ECGData> newData = [];
      int i = 0;
      while (i < packLength) {
        newData.add(ECGData(index + i, data[currentIndex + i]));
        i++;
      }
      bufferController.extend(newData);
      bufferController.doDetection();

      index += packLength;
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
  }
}
