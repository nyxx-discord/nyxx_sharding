import 'dart:io';

abstract class ProcessData {
  String get executable;

  List<String> get args;

  String? get cwd;

  Future<Process> spawn(List<int> processShards) => Process.start(executable, args,
      environment: {
        'NYXX_SHARDING_SHARD_IDS': processShards.join(","),
      },
      workingDirectory: cwd);
}
