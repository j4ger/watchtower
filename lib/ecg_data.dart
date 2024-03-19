import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';

class ECGData extends FlSpot {
// TODO: avoid multiple type casting

  ECGData(int timestamp, double value) : super(timestamp.toDouble(), value);

  static List<ECGData> fromPacket(Uint8List data) {
    final bytes = ByteData.sublistView(data);
    List<ECGData> result = [];
    final count = (bytes.lengthInBytes / 8).floor();
    for (var i = 0; i < count; i++) {
      final timestamp = bytes.getUint32(i * 8);
      final value = bytes.getFloat32(i * 8 + 4);
      result.add(ECGData(timestamp, value));
    }
    return result;
  }
}

// TODO: push directly into buffer
