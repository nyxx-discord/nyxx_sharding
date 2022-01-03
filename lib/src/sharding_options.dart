/// Options to customize how nyxx_sharding behaves.
class ShardingOptions {
  /// Whether to redirect the stdout and stderr of the spawned processes to this processe's stdout and stderr.
  ///
  /// Standard input is not redirected.
  ///
  /// Default `true`.
  final bool redirectOutput;

  const ShardingOptions({
    this.redirectOutput = true,
  });
}
