import 'dart:typed_data';

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
