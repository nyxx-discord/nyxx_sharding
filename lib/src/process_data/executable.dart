import 'package:nyxx_sharding/src/process_data/process_data.dart';

/// Indicates an arbitrary executable file as a target for a [ShardingManager].
///
/// This executable could be a compiled Dart project, but could also be a different language's executable.
///
/// For example, starting a bot written in JavaScript with nodejs: ```dart
/// Executable('node', args: ['index.js']);
/// ```
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
