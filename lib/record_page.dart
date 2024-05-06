import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'ecg_data.dart';

const String dbName = "watchtower.db";
const String tableName = "records";

class Record {
  final DateTime timestamp;
  final List<ECGData> data;

  Record(this.timestamp, this.data);

  Map<String, Object?> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'data': ECGData.serialize(data),
    };
  }

  @override
  String toString() => "record at $timestamp with ${data.length} samples";
}

class RecordController extends GetxController {
  late final Database db;
  final RxList<Record> records = <Record>[].obs;
  final refreshing = false.obs;

  @override
  void onInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runZonedGuarded(onStartUp, onCrashed);
    });
    super.onInit();
  }

  @override
  void dispose() {
    db.close();
    super.dispose();
  }

  void onStartUp() async {
    WidgetsFlutterBinding.ensureInitialized();
    db = await openDatabase(
      join(await getDatabasesPath(), dbName),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $tableName(id INTEGER PRIMARY KEY, timestamp INTEGER, data BLOB)',
        );
      },
      version: 1,
    );
  }

  void onCrashed(Object error, StackTrace stackTrace) {
    print(error);
    Get.defaultDialog(
        title: "Error",
        barrierDismissible: false,
        middleText: "Failed to initialize local database.",
        actions: [
          FilledButton(
            child: const Text("Exit"),
            onPressed: () {
              Get.back(closeOverlays: true);
            },
          )
        ]);
  }

  Future<void> insertRecord(Record record) async {
    await db.insert(
      tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRecordList() async {
    refreshing.value = true;
    final List<Map<String, Object?>> recordMaps = await db.query(tableName);

    final result = [
      for (final {
            'timestamp': timestamp as int,
            'data': data as Uint8List,
          } in recordMaps)
        Record(DateTime.fromMillisecondsSinceEpoch(timestamp),
            ECGData.deserialize(data)),
    ];

    records.value = result;
    refreshing.value = false;
  }
}

class RecordPage extends StatelessWidget {
  final RecordController controller = Get.find();

  RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
        child: Scaffold(
            appBar: AppBar(
              title: const Text("Record Management"),
              actions: [
                Obx(() => controller.refreshing()
                    ? SpinKitFadingCircle(size: 24)
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        iconSize: 24,
                        onPressed: () {
                          controller.updateRecordList();
                        },
                      ))
              ],
            ),
            body: SafeArea(
                child: Obx(() => ListView.builder(
                      itemCount: controller.records.length,
                      itemBuilder: (content, index) =>
                          Text("$content.timestamp"),
                    )))));
  }
}
