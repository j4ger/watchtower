import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'constants.dart';

const packSize = 4 * 2; // 4 bytes for each int and float

class ECGData {
  int timestamp;
  double value;
  late int index;

  ECGData(this.timestamp, this.value) {
    index = timestamp % graphBufferLength;
  }

  @override
  String toString() => "ECGData of $value at $timestamp.";

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

  static Uint8List serialize(List<ECGData> input) {
    final byteData = ByteData(input.length * packSize);
    for (final (i, pack) in input.indexed) {
      byteData.setInt32(i * packSize, pack.timestamp);
      byteData.setFloat32(i * packSize + 4, pack.value);
    }
    return byteData.buffer.asUint8List();
  }

  static List<ECGData> deserialize(Uint8List data) {
    final List<ECGData> result = [];
    final byteData = ByteData.view(data.buffer);
    // TODO: for some reason the following check won't pass on android
    // on Linux this works fine tho
    // if (byteData.lengthInBytes % packSize != 0) {
    //   throw FormatException(
    //       "Invalid format for data buffer, got byteData with length: ${byteData.lengthInBytes}");
    // }
    for (int i = 0; i < byteData.lengthInBytes ~/ packSize; i++) {
      final timestamp = byteData.getInt32(i * packSize);
      final value = byteData.getFloat32(i * packSize + 4);
      result.add(ECGData(timestamp, value));
    }
    return result;
  }
}

List<ECGData> mapArrayToData(
    List<ECGData> originalData, List<double> processedData) {
  return processedData
      .mapIndexed(
          (index, element) => ECGData(originalData[index].timestamp, element))
      .toList();
}


// TODO: push directly into buffer
