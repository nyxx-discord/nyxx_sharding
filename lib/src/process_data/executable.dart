import 'package:nyxx_sharding/src/process_data/process_data.dart';

class Executable extends ProcessData {
  @override
  final List<String> args;

  @override
  final String? cwd;

  @override
  final String executable;

  Executable(
    this.executable, {
    this.args = const [],
    this.cwd,
  });
}
