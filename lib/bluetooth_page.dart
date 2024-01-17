import 'dart:async';

import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

// TODO: timeout and stop

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<BluetoothLowEnergyState> state;
  late final ValueNotifier<bool> discovering;
  late final ValueNotifier<List<DiscoveredEventArgs>> discoveredEventArgs;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription discoveredSubscription;
  late final AnimationController _spinnerController;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Select device"),
        ),
        body: _buildBody(context),
        floatingActionButton: ValueListenableBuilder(
            valueListenable: state,
            builder: (context, state, child) {
              return ValueListenableBuilder(
                  valueListenable: discovering,
                  builder: (context, discovering, child) {
                    return FloatingActionButton(
                      onPressed: state == BluetoothLowEnergyState.poweredOn
                          ? () async {
                              if (discovering) {
                                await stopDiscovery();
                              } else {
                                await startDiscovery();
                              }
                            }
                          : null,
                      tooltip: 'Scan',
                      child: Icon(discovering ? Icons.stop : Icons.refresh),
                    );
                  });
            }));
  }

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    state = ValueNotifier(BluetoothLowEnergyState.unknown);
    discovering = ValueNotifier(false);
    discoveredEventArgs = ValueNotifier([]);
    stateChangedSubscription = CentralManager.instance.stateChanged.listen(
      (eventArgs) {
        state.value = eventArgs.state;
      },
    );
    discoveredSubscription = CentralManager.instance.discovered.listen(
      (eventArgs) {
        final items = discoveredEventArgs.value;
        final i = items.indexWhere(
          (item) => item.peripheral == eventArgs.peripheral,
        );
        if (i < 0) {
          discoveredEventArgs.value = [...items, eventArgs];
        } else {
          items[i] = eventArgs;
          discoveredEventArgs.value = [...items];
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runZonedGuarded(onStartUp, onCrashed);
    });
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
        child: Column(
      children: [
        Row(children: [
          const SizedBox(
            width: 10,
          ),
          SpinKitDoubleBounce(
            color: Colors.lightBlueAccent,
            size: 25,
            controller: _spinnerController,
          ),
          const SizedBox(
            width: 5,
          ),
          const Text("Peripherals:"),
        ]),
        const SizedBox(
          height: 5,
        ),
        ValueListenableBuilder(
          valueListenable: discoveredEventArgs,
          builder: (context, discoveredEventArgs, child) {
            final items = discoveredEventArgs
                .where((eventArgs) => eventArgs.advertisement.name != null)
                .toList();
            return Expanded(
                child: ListView.separated(
              itemBuilder: (context, i) {
                final theme = Theme.of(context);
                final item = items[i];
                final uuid = item.peripheral.uuid;
                final rssi = item.rssi;
                final advertisement = item.advertisement;
                final name = advertisement.name;
                return ListTile(
                  onTap: () async {
                    final discovering = this.discovering.value;
                    if (discovering) {
                      await stopDiscovery();
                    }
                    if (!mounted) {
                      throw UnimplementedError();
                    }
                    await Navigator.of(context).pushNamed(
                      'signal',
                      arguments: discoveredEventArgs[i],
                    );
                  },
                  title: Text(name ?? 'N/A'),
                  subtitle: Text(
                    '$uuid',
                    style: theme.textTheme.bodySmall,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RssiWidget(rssi),
                      Text('$rssi'),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, i) {
                return const Divider(
                  height: 0.0,
                );
              },
              itemCount: items.length,
            ));
          },
        )
      ],
    ));
  }

  @override
  void dispose() {
    // TODO: cancel event subscription
    super.dispose();
    stateChangedSubscription.cancel();
    state.dispose();
  }

  void onStartUp() async {
    // CentralManager.instance.logLevel = Level.WARNING;
    WidgetsFlutterBinding.ensureInitialized();
    _spinnerController.stop();
    await CentralManager.instance.setUp();
    state.value = await CentralManager.instance.getState();
  }

  void onCrashed(Object error, StackTrace stackTrace) {
    Logger.root.shout('App crached.', error, stackTrace);
    _showAlert("Failed to initialize BLE: $error", "Error", false);
  }

  Future<void> startDiscovery() async {
    discoveredEventArgs.value = [];
    await CentralManager.instance.startDiscovery();
    discovering.value = true;
    _spinnerController.repeat();
  }

  Future<void> stopDiscovery() async {
    await CentralManager.instance.stopDiscovery();
    discovering.value = false;
    _spinnerController.stop();
  }

  Future<void> _showAlert(String message,
      [String title = "Error", bool dismissable = true]) async {
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
                if (!dismissable)
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
            if (dismissable)
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }
}

class RssiWidget extends StatelessWidget {
  final int rssi;

  const RssiWidget(
    this.rssi, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    if (rssi > -70) {
      icon = Icons.wifi_rounded;
    } else if (rssi > -100) {
      icon = Icons.wifi_2_bar_rounded;
    } else {
      icon = Icons.wifi_1_bar_rounded;
    }
    return Icon(icon);
  }
}
