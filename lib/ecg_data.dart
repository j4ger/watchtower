import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:scidart/numdart.dart';
import 'package:watchtower/buffer_controller.dart';

class ECGData {
  int timestamp;
  double value;
  late int index;

  ECGData(this.timestamp, this.value) {
    index = timestamp % bufferLength;
  }

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

List<ECGData> mapArrayToData(List<ECGData> originalData, Array processedData) {
  return originalData
      .mapIndexed(
          (index, element) => ECGData(element.timestamp, processedData[index]))
      .toList();
}


// TODO: push directly into buffer
