import 'dart:io';

abstract class ProcessData {
  String get executable;

  List<String> get args;

  String? get cwd;

  Future<Process> spawn(List<int> processShards, int totalShards) => Process.start(executable, args,
      environment: {
        'NYXX_SHARDING_SHARD_IDS': processShards.join(","),
        'NYXX_SHARDING_TOTAL_SHARDS': totalShards.toString(),
      },
      workingDirectory: cwd);
}
