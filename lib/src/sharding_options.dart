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

  /// Whether to automatically restart processes when they grow beyond a certain threshold with updated shard and process counts.
  ///
  /// This setting requires the child processes to add [IShardingPlugin] to their respective clients.
  ///
  /// This setting can cause downtime while the processes restart, so it is disabled by default.
  final bool autoScale;

  /// The interval at which to check if processes should be restarted, if [autoScale] is `true`.
  final Duration autoScaleInterval;

  /// Whether to get the guild count using an approximation rather than an exact number.
  ///
  /// This will be faster than fetching the exact count.
  final bool useImpreciseGuildCount;

  const ShardingOptions({
    this.redirectOutput = true,
    this.timeoutSpawn = true,
    this.respawnProcesses = true,
    this.autoScale = false,
    this.autoScaleInterval = const Duration(minutes: 15),
    this.useImpreciseGuildCount = false,
  });
}
