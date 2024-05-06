import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'ecg_data.dart';

const String dbName = "watchtower.db";
const String tableName = "records";

DateFormat dateFormatter = DateFormat('yyyy-MM-dd kk:mm:ss');

class Record {
  final DateTime startTime;
  final Duration duration;
  final List<ECGData> data;

  Record(this.startTime, this.duration, this.data);

  Map<String, Object?> toMap() {
    return {
      'start': startTime.millisecondsSinceEpoch,
      'duration': duration.inMilliseconds,
      'data': ECGData.serialize(data),
    };
  }

  @override
  String toString() =>
      "record from $startTime for $duration with ${data.length} samples";
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
          'CREATE TABLE $tableName(id INTEGER PRIMARY KEY, start INTEGER, duration INTEGER, data BLOB)',
        );
      },
      version: 2,
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
    // TODO: lazy loading
    refreshing.value = true;
    final List<Map<String, Object?>> recordMaps = await db.query(tableName);

    final result = [
      for (final {
            'start': startTime as int,
            'duration': duration as int,
            'data': data as Uint8List,
          } in recordMaps)
        Record(DateTime.fromMillisecondsSinceEpoch(startTime),
            Duration(milliseconds: duration), ECGData.deserialize(data)),
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
                    itemBuilder: (context, index) {
                      final theme = Theme.of(context);
                      final record = controller.records[index];
                      final startDisplay =
                          dateFormatter.format(record.startTime);
                      final durationDisplay = formatDuration(record.duration);
                      return ListTile(
                        title: Text(startDisplay),
                        subtitle: Text(
                          durationDisplay,
                          style: theme.textTheme.bodySmall,
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })))));
  }
}

String formatDuration(Duration input) {
  var seconds = input.inSeconds;
  final days = seconds ~/ Duration.secondsPerDay;
  seconds -= days * Duration.secondsPerDay;
  final hours = seconds ~/ Duration.secondsPerHour;
  seconds -= hours * Duration.secondsPerHour;
  final minutes = seconds ~/ Duration.secondsPerMinute;
  seconds -= minutes * Duration.secondsPerMinute;

  final List<String> tokens = [];
  if (days != 0) {
    tokens.add('${days}d');
  }
  if (tokens.isNotEmpty || hours != 0) {
    tokens.add('${hours}h');
  }
  if (tokens.isNotEmpty || minutes != 0) {
    tokens.add('${minutes}m');
  }
  tokens.add('${seconds}s');

  return tokens.join(':');
}
