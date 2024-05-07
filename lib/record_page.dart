import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';

import 'ecg_data.dart';
import 'main.dart';

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
    final docsDirectory = await getApplicationDocumentsDirectory();
    db = await openDatabase(
      join(docsDirectory.path, dbName),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $tableName(id INTEGER PRIMARY KEY, start INTEGER, duration INTEGER, data BLOB)',
        );
      },
      version: 2,
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
    final res = await db.insert(
      tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print(res);
    updateRecordList();
  }

  Future<void> updateRecordList() async {
    // TODO: lazy loading (pagination)
    refreshing.value = true;
    await awaitWithOverlay(() async {
      final List<Map<String, Object?>> recordMaps = await db.query(tableName,
          columns: [
            "start",
            "duration"
          ]); // don't query data now to avoid long load time

      final result = [
        for (final {
              'start': startTime as int,
              'duration': duration as int,
            } in recordMaps)
          Record(DateTime.fromMillisecondsSinceEpoch(startTime),
              Duration(milliseconds: duration), []),
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
      'data': data as Uint8List
    } = resultMap.first;
    return Record(DateTime.fromMillisecondsSinceEpoch(startTime),
        Duration(milliseconds: duration), ECGData.deserialize(data));
  }
}

class RecordPage extends StatelessWidget {
  final RecordController controller = Get.find();

  RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return makePage(
      "Record Management",
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Obx(() => Padding(
              padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
              child: Text(
                "${controller.records.length} records available.",
                style: theme.textTheme.titleMedium,
              ),
            )),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
        Obx(() => Expanded(
                child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: controller.records.length,
              itemBuilder: (context, index) {
                final record = controller.records[index];
                final startDisplay = dateFormatter.format(record.startTime);
                final durationDisplay = formatDuration(record.duration);
                return Dismissible(
                    key: Key(record.startTime.toString()),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      controller.removeRecord(record.startTime);
                    },
                    background: Container(
                        color: Colors.red,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                            Text(
                              "Delete",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 10)
                          ],
                        )),
                    child: ListTile(
                      title: Text(startDisplay),
                      subtitle: Text(
                        durationDisplay,
                        style: theme.textTheme.bodySmall,
                        softWrap: false,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Get.toNamed("/viewRecord", arguments: record.startTime);
                      },
                    ));
              },
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(),
            )))
      ]),
      actions: [
        Obx(() => controller.refreshing()
            ? const SpinKitFadingCircle(size: 24, color: Colors.black)
            : IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: 24,
                onPressed: () {
                  controller.updateRecordList();
                },
              ))
      ],
    );
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

// TODO: delete record
