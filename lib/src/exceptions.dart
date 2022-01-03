/// Base class for all errors thrown by nyxx_sharding.
class ShardingError extends Error {
  final String message;

  ShardingError(this.message);

  @override
  String toString() => message;
}
