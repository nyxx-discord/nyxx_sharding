/// Options to customize how nyxx_sharding behaves.
class ShardingOptions {
  /// Whether to redirect the stdout and stderr of the spawned processes to this processe's stdout and stderr.
  ///
  /// Standard input is not redirected.
  ///
  /// Default `true`.
  final bool redirectOutput;

  final bool respawnProcesses;

  /// Whether to respawn processes upon exiting if the exit code is non-zero.
  const ShardingOptions({
    this.redirectOutput = true,
    this.respawnProcesses = true,
  });
}
