import 'package:nyxx_sharding/src/process_data/process_data.dart';

class UncompiledDart extends ProcessData {
  @override
  String get executable => 'dart';

  @override
  List<String> get args => ['run', ...?dartArgs, file, ...?processArgs];

  @override
  final String? cwd;

  final String file;
  final List<String>? dartArgs;
  final List<String>? processArgs;

  UncompiledDart(this.file, {this.dartArgs, this.processArgs, this.cwd});
}
