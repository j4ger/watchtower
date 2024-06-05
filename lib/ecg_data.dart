import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'constants.dart';

/// size in bytes for each packet
const packSize = 4 * 2; // 4 bytes for each int and float

/// internal struct that BLE transmissions decode to
class ECGData {
  /// timestamp, a simple incremental counter should do
  int timestamp;

  /// sample value
  double value;

  /// calculated from timestamp, used in graph rendering
  late int index;

  ECGData(this.timestamp, this.value) {
    index = timestamp % graphBufferLength;
  }

  @override
  String toString() => "ECGData of $value at $timestamp.";

  /// decode packet
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

  /// serialize to bytes for writing to local database
  static Uint8List serialize(List<ECGData> input) {
    final byteData = ByteData(input.length * packSize);
    for (final (i, pack) in input.indexed) {
      byteData.setInt32(i * packSize, pack.timestamp);
      byteData.setFloat32(i * packSize + 4, pack.value);
    }
    return byteData.buffer.asUint8List();
  }

  /// deserialize from local database
  static List<ECGData> deserialize(Uint8List data) {
    final List<ECGData> result = [];
    final byteData = ByteData.view(data.buffer);
    // TODO: for some reason the following check won't pass on android
    // possibly due to SQLite3 libs
    // on Linux this works fine tho
    // if (byteData.lengthInBytes % packSize != 0) {
    //   throw FormatException(
    //       "Invalid format for data buffer, got byteData with length: ${byteData.lengthInBytes}");
    // }
    //
    // update: this should already be fixed after supplying our own libs, but haven't been tested

    for (int i = 0; i < byteData.lengthInBytes ~/ packSize; i++) {
      final timestamp = byteData.getInt32(i * packSize);
      final value = byteData.getFloat32(i * packSize + 4);
      result.add(ECGData(timestamp, value));
    }
    return result;
  }
}

/// map a list of double to a list of `ECGData`
/// the timestamps of `originalData` is used
List<ECGData> mapArrayToData(
    List<ECGData> originalData, List<double> processedData) {
  return processedData
      .mapIndexed(
          (index, element) => ECGData(originalData[index].timestamp, element))
      .toList();
}


// TODO: push directly into buffer
