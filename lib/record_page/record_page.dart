import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import '../algorithm/signal_processing/int_list_dsp.dart';
import '../navigation.dart';
import 'record_controller.dart';

DateFormat dateFormatter = DateFormat('yyyy-MM-dd kk:mm:ss');

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

const int thumbnailUpperLimit = 400;
const int thumbnailLowerLimit = 200;
