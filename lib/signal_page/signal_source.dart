import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

enum SignalSourceType { ble, mock }

class SignalSource {
  final SignalSourceType type;
  final String? path;
  final Peripheral? device;

  SignalSource(this.type, {this.path, this.device});

  bool get isMock => type == SignalSourceType.mock;
}
