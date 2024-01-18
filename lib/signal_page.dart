import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:circular_buffer/circular_buffer.dart';
import 'package:convert/convert.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:watchtower/bluetooth_device.dart';
import 'package:watchtower/ecg_data.dart';

const bufferLength = 800;
const plotLength = 500;
const delayMs = 200;
const packLength = 50;
const moveForwardInterval = 23.5;
const minDataCount = plotLength + 2 * packLength;

class CircularBufferNotifier<T> extends ValueNotifier<CircularBuffer<T>> {
  late final CircularBuffer<T> _buffer;

  CircularBufferNotifier(super.buffer) : _buffer = buffer;

  void fill(T item) {
    _buffer.fillRange(0, _buffer.length, item);
  }

  void add(T item) {
    _buffer.add(item);

    notifyListeners();
  }

  void extend(List<T> items) {
    for (T item in items) {
      _buffer.add(item);
    }
  }

  void update() {
    notifyListeners();
  }
}

class SignalPage extends StatefulWidget {
  final DiscoveredEventArgs eventArgs;

  const SignalPage({
    super.key,
    required this.eventArgs,
  });

  @override
  State<SignalPage> createState() => _SignalPageState();
}

class _SignalPageState extends State<SignalPage> {
  late final ValueNotifier<bool> connectionState;
  late final DiscoveredEventArgs eventArgs;
  late final ValueNotifier<List<GattService>> services;
  late final ValueNotifier<List<GattCharacteristic>> characteristics;
  late final ValueNotifier<GattService?> service;
  late final ValueNotifier<GattCharacteristic?> characteristic;
  late final StreamSubscription connectionStateChangedSubscription;
  late final StreamSubscription characteristicNotifiedSubscription;

  late final CircularBufferNotifier<ECGData> dataBuffer;

  late final Timer _moveForwardTimer;

  double plotEnd = 0;
  int plotIndexStart = 0;

  @override
  void initState() {
    super.initState();
    eventArgs = widget.eventArgs;
    connectionState = ValueNotifier(false);
    services = ValueNotifier([]);
    characteristics = ValueNotifier([]);
    service = ValueNotifier(null);
    characteristic = ValueNotifier(null);

    dataBuffer = CircularBufferNotifier(CircularBuffer(bufferLength));

    connectionStateChangedSubscription =
        CentralManager.instance.connectionStateChanged.listen(
      (eventArgs) {
        if (eventArgs.peripheral != this.eventArgs.peripheral) {
          return;
        }
        final connectionState = eventArgs.connectionState;
        this.connectionState.value = connectionState;
        if (!connectionState) {
          services.value = [];
          characteristics.value = [];
          service.value = null;
          characteristic.value = null;
        }
      },
    );
    characteristicNotifiedSubscription =
        CentralManager.instance.characteristicNotified.listen(
      (eventArgs) {
        if (eventArgs.characteristic.uuid != targetCharateristic) {
          return;
        }
        final packet = eventArgs.value;
        final data = ECGData.fromPacket(packet);
        plotEnd = data.last.x;
        plotIndexStart = 0;
        dataBuffer.extend(data);
      },
    );

    initTimer();
  }

  void initTimer() {
    _moveForwardTimer = Timer.periodic(
        Duration(milliseconds: moveForwardInterval.floor()), (timer) {
      plotIndexStart = plotIndexStart + 1;
      dataBuffer.update();
    });
  }

  void connect(BuildContext context) async {
    // TODO: full screen cover while connecting

    await CentralManager.instance.connect(eventArgs.peripheral).onError(
      (error, stackTrace) {
        _showAlert(context, "Failed to connect to device: $error.");
      },
    );
    services.value =
        await CentralManager.instance.discoverGATT(eventArgs.peripheral);
    // TODO: better error management
    GattCharacteristic? target;
    outer:
    for (var service in services.value) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid == targetCharateristic) {
          target = characteristic;
          break outer;
        }
      }
    }
    if (target == null) {
      if (context.mounted) {
        _showAlert(context, "Not a valid device.", "Error", () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
      return;
    }
    await CentralManager.instance
        .setCharacteristicNotifyState(target, state: true);

    initTimer();
  }

  void disconnect(BuildContext context) async {
    _moveForwardTimer.cancel();
    await CentralManager.instance.disconnect(eventArgs.peripheral).onError(
      (error, stackTrace) {
        _showAlert(context, "Failed to disconnect device: $error.");
      },
    );
    services.value = [];
  }

  @override
  Widget build(BuildContext context) {
    connect(context);
    return PopScope(
      onPopInvoked: (didPop) async {
        if (connectionState.value) {
          final peripheral = eventArgs.peripheral;
          await CentralManager.instance.disconnect(peripheral);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("View Signal"), actions: [
          ValueListenableBuilder(
            valueListenable: connectionState,
            builder: (context, connectionState, child) {
              return connectionState
                  ? IconButton(
                      icon: const Icon(Icons.bluetooth_connected),
                      iconSize: 24,
                      color: Colors.greenAccent,
                      onPressed: () {
                        disconnect(context);
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      iconSize: 24,
                      color: Colors.yellowAccent,
                      onPressed: () {
                        connect(context);
                      },
                    );
            },
          )
        ]),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder(
            valueListenable: dataBuffer,
            builder: (context, dataBuffer, child) {
              return dataBuffer.length < minDataCount
                  ? TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(
                          begin: 0, end: dataBuffer.length / minDataCount),
                      builder: (context, value, child) =>
                          LinearProgressIndicator(value: value))
                  : Container();
            },
          ),
          ValueListenableBuilder(
              valueListenable: dataBuffer,
              builder: (context, dataBuffer, child) {
                return (dataBuffer.length < minDataCount)
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Center(
                          child: SpinKitRing(
                            color: Colors.lightBlueAccent,
                          ),
                        ))
                    : Container(
                        padding: const EdgeInsets.all(8.0),
                        width: 400,
                        height: 200,
                        child: LineChart(
                          duration: Duration.zero,
                          LineChartData(
                            minY: -2,
                            maxY: 3,
                            minX: plotEnd - dataBuffer.length + plotIndexStart,
                            maxX: plotEnd -
                                dataBuffer.length +
                                plotLength +
                                plotIndexStart,
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                  spots: dataBuffer
                                      .getRange(plotIndexStart,
                                          plotIndexStart + plotLength)
                                      .toList(growable: false), // toList?
                                  dotData: const FlDotData(show: false),
                                  barWidth: 1,
                                  isCurved: false)
                            ],
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            clipData: const FlClipData.all(),
                          ),
                        ));
              })
        ],
      ),
    );
  }

  Future<void> _showAlert(BuildContext context, String message,
      [String title = "Error", Function()? action]) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Center(
                    child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
                if (action == null)
                  const Center(
                    child: Text(
                      "Please restart the app to retry.",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
              ],
            ),
          ),
          actions: <Widget>[
            if (action != null)
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  action();
                },
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();

    _moveForwardTimer.cancel();

    connectionStateChangedSubscription.cancel();
    characteristicNotifiedSubscription.cancel();
    connectionState.dispose();
    services.dispose();
    characteristics.dispose();
    service.dispose();
    characteristic.dispose();

    dataBuffer.dispose();
  }
}

// TODO: alternative method: plot all the data and only change minX and maxX
