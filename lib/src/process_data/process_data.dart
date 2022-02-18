import 'dart:io';

/// Represents a target executable and arguments for a [ShardingManager] to spawn.
///
/// This is essentially a "blueprint" for the processes that nyxx_sharding will spawn. Each process spawned will run [executable], with [cwd] as the Current
/// Working Directory and [args] as the command-line arguments passed to the process.
abstract class ProcessData {
  /// The executable ran for each process.
  String get executable;

  /// The command-line arguments passed to each process.
  List<String> get args;

  /// The working directory to spawn each process in.
  String? get cwd;

  /// Spawns a single [Process] according to the information in this [ProcessManager].
  ///
  /// The spawned process will have the following environment variables set in addition to the existing variables:
  /// - `NYXX_SHARDING_SHARD_IDS`: The ids of the shards to spawn in the process;
  /// - `NYXX_SHARDING_TOTAL_SHARDS`: The total number of shards being spawned across all processes;
  /// - `NYXX_SHARDING_PORT`: The port to connect to in order to establish a websocket connection with the manager process.
  Future<Process> spawn(List<int> processShards, int totalShards, int port) => Process.start(executable, args,
      environment: {
        'NYXX_SHARDING_SHARD_IDS': processShards.join(","),
        'NYXX_SHARDING_TOTAL_SHARDS': totalShards.toString(),
        'NYXX_SHARDING_PORT': port.toString(),
      },
      workingDirectory: cwd);
}
