import 'package:nyxx_sharding/src/process_data/process_data.dart';

/// Indicates an uncompiled Dart file to be invoked with `dart run` as a target for a [ShardingManager].
///
/// Using: ```dart
/// UncompiledDart('foo.dart');
/// ```
/// Is the same as ```dart
/// Executable('dart', args: ['run', 'foo.dart']);
/// ```
class UncompiledDart extends ProcessData {
  @override
  String get executable => 'dart';

  @override
  List<String> get args => ['run', ...?dartArgs, file, ...?processArgs];

  @override
  final String? cwd;

  /// The target file.
  final String file;

  /// Arguments to pass when invoking the Dart command.
  final List<String>? dartArgs;

  /// Arguments to pass to the process.
  final List<String>? processArgs;

  UncompiledDart(this.file, {this.dartArgs, this.processArgs, this.cwd});
}
