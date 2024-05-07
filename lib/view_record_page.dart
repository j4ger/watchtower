import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'record_page.dart';

class ViewRecordController {
  late final Record record;
  final DateTime startTime;
  final loading = true.obs;

  final RecordController recordController = Get.find();

  ViewRecordController(this.startTime) {
    initRecord();
  }

  Future<void> initRecord() async {
    final result = await recordController.getRecordByStartTime(startTime);
    record = result;
    loading.value = false;
  }
}

class ViewRecordPage extends StatelessWidget {
  late final DateTime startTime;
  ViewRecordPage({super.key}) {
    startTime = Get.arguments as DateTime;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ViewRecordController(startTime));

    return Container();
  }
}
