import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:watchtower/buffer_controller.dart';
import 'package:watchtower/ecg_data.dart';

const timerInterval = Duration(milliseconds: delayMs);

class MockController extends GetxController {
  final String path;
  int index = 0;
  late List<double> data;
  late Timer timer;
  final BufferController bufferController;

  MockController(this.path, this.bufferController);

  ECGData getData() {
    final currentIndex = (index % data.length).toInt();
    final result = ECGData(index, data[currentIndex]);
    index++;
    return result;
  }

  @override
  void onInit() {
    super.onInit();

    final file = File(path);
    final content = file.readAsStringSync();
    final csv = const CsvToListConverter(eol: "\n").convert(content);

    data = csv.sublist(2).map((element) => element[1] as double).toList();

    int i = 0;
    final List<ECGData> initialData = [];
    while (i < bufferLength) {
      initialData.add(getData());
      i++;
    }
    bufferController.extend(initialData);

    timer = Timer.periodic(timerInterval, (timer) {
      final List<ECGData> newData = [];
      int i = 0;
      while (i < packLength) {
        newData.add(getData());
        i++;
      }
      bufferController.extend(newData);
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}
