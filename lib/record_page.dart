import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'algorithm/ECG/clean.dart';
import 'algorithm/ECG/find_peaks.dart';
import 'algorithm/utils.dart';
import 'ecg_data.dart';
import 'main.dart';

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
                      trailing: record.annotations.isNotEmpty
                          ? Container(
                              height: 30,
                              width: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black54),
                              ),
                              padding: EdgeInsets.zero,
                              child: charts.LineChart(
                                [
                                  charts.Series(
                                      id: "gap",
                                      data: intListDiff(record.annotations),
                                      domainFn: (value, index) => index ?? 0,
                                      measureFn: (value, index) => value)
                                ],
                                animate: false,
                                domainAxis: const charts.NumericAxisSpec(
                                    renderSpec: charts.NoneRenderSpec()),
                                primaryMeasureAxis:
                                    const charts.NumericAxisSpec(
                                        renderSpec: charts.NoneRenderSpec(),
                                        viewport: charts.NumericExtents(
                                            thumbnailLowerLimit,
                                            thumbnailUpperLimit)),
                                layoutConfig: charts.LayoutConfig(
                                    leftMarginSpec:
                                        charts.MarginSpec.fixedPixel(5),
                                    rightMarginSpec:
                                        charts.MarginSpec.fixedPixel(5),
                                    topMarginSpec:
                                        charts.MarginSpec.fixedPixel(2),
                                    bottomMarginSpec:
                                        charts.MarginSpec.fixedPixel(2)),
                              ),
                            )
                          : null, // TODO: thumbnail for a segment of heartrate graph
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

Uint8List serializeListToInt32(List<int> intList) {
  final uint8List = Uint8List(intList.length * 4);
  for (int i = 0; i < intList.length; i++) {
    final value = intList[i];
    uint8List[i * 4 + 0] = (value >> 24) & 0xFF;
    uint8List[i * 4 + 1] = (value >> 16) & 0xFF;
    uint8List[i * 4 + 2] = (value >> 8) & 0xFF;
    uint8List[i * 4 + 3] = value & 0xFF;
  }
  return uint8List;
}

List<int> deserializeInt32ToList(Uint8List uint8List) {
  final int length = uint8List.length ~/ 4;
  final List<int> intList = [];
  for (int i = 0; i < length; i++) {
    int value = 0;
    value += (uint8List[i * 4 + 0] << 24);
    value += (uint8List[i * 4 + 1] << 16);
    value += (uint8List[i * 4 + 2] << 8);
    value += (uint8List[i * 4 + 3]);
    intList.add(value);
  }
  return intList;
}

List<int> processWithPT(List<ECGData> input) {
  final preprocessor = CleanPT(fs);
  final detector = PtPeakDetector(fs);
  final preprocessed = preprocessor.apply(input);
  final result = detector.detect(preprocessed);
  return result;
}

const int thumbnailUpperLimit = 400;
const int thumbnailLowerLimit = 200;
