import '../ecg_data.dart';

abstract class Pipeline {
  late final int fs;
  Pipeline(this.fs);

  abstract final String name;
  List<ECGData> apply(List<ECGData> input);
}
