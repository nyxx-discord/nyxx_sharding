/// Options to customize how nyxx_sharding behaves.
class ShardingOptions {
  /// Whether to redirect the stdout and stderr of the spawned processes to this processe's stdout and stderr.
  ///
  /// Standard input is not redirected.
  ///
  /// Default `true`.
  final bool redirectOutput;

  /// Whether to respawn processes upon exiting if the exit code is non-zero.
  final bool respawnProcesses;

  /// Whether to wait after spawning a process for enough time for all shards to initialise before spawning the next process.
  ///
  /// Generally you will not want to disable this; this option should be used for testing only.
  final bool timeoutSpawn;

  const ShardingOptions({
    this.redirectOutput = true,
    this.timeoutSpawn = true,
    this.respawnProcesses = true,
  });
}
