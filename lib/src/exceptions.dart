class ShardingError extends Error {
  final String message;

  ShardingError(this.message);

  @override
  String toString() => message;
}
