import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../utils.dart';
import 'ser_de.dart';
import '../ecg_data.dart';

const String dbName = "watchtower.db";
const String tableName = "records";

DateFormat dateFormatter = DateFormat('yyyy-MM-dd kk:mm:ss');

class Record {
  final DateTime startTime;
  final Duration duration;
  final List<ECGData> data;
  final List<int> annotations;

  Record(this.startTime, this.duration, this.data,
      {this.annotations = const []});

  Map<String, Object?> toMap() {
    return {
      'start': startTime.millisecondsSinceEpoch,
      'duration': duration.inMilliseconds,
      'data': ECGData.serialize(data),
      'annotations': serializeListToInt32(annotations),
    };
  }

  @override
  String toString() =>
      "record from $startTime for $duration with ${data.length} samples, ${annotations.length} annotations";
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
    final docsDirectory = await getApplicationSupportDirectory();
    db = await openDatabase(
      join(docsDirectory.path, dbName),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $tableName(id INTEGER PRIMARY KEY, start INTEGER, duration INTEGER, data BLOB, annotations BLOB)',
        );
      },
      version: 3,
    );
    updateRecordList();
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

  Future<void> addRecord(Record record) async {
    await db.insert(
      tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    updateRecordList();
  }

  Future<void> updateRecordList() async {
    // TODO: lazy loading (pagination)
    refreshing.value = true;
    await awaitWithOverlay(() async {
      final List<Map<String, Object?>> recordMaps = await db.query(tableName,
          columns: [
            "start",
            "duration",
            "annotations"
          ]); // don't query data now to avoid long load time

      final result = [
        for (final {
              'start': startTime as int,
              'duration': duration as int,
              'annotations': annotations as Uint8List
            } in recordMaps)
          Record(DateTime.fromMillisecondsSinceEpoch(startTime),
              Duration(milliseconds: duration), [],
              annotations: deserializeInt32ToList(annotations)),
      ];

      records.value = result;
    });
    refreshing.value = false;
  }

  Future<void> removeRecord(DateTime startTimeInput) async {
    await awaitWithOverlay(() async => db.delete(tableName,
        where: '"start" = ?',
        whereArgs: [startTimeInput.millisecondsSinceEpoch]));

    snackbar("Info", "Record successfully removed.");
    await updateRecordList();
  }

  Future<Record> getRecordByStartTime(DateTime startTimeInput) async {
    final resultMap = await db.query(tableName,
        where: '"start" = ?',
        whereArgs: [startTimeInput.millisecondsSinceEpoch]);
    final {
      'start': startTime as int,
      'duration': duration as int,
      'data': data as Uint8List,
      'annotations': annotations as Uint8List,
    } = resultMap.first;
    return Record(DateTime.fromMillisecondsSinceEpoch(startTime),
        Duration(milliseconds: duration), ECGData.deserialize(data),
        annotations: deserializeInt32ToList(annotations));
  }
}
