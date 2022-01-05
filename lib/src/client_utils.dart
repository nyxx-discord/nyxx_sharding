import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_sharding/src/exceptions.dart';

/// Get the options to pass to the [INyxxFactory.createNyxxWebsocket] constructor when instanciating nyxx. Only for use in spawned processes.
///
/// [defaultOptions] can be provided to specify defaults for other options in [ClientOptions]. This function overrides [ClientOptions.shardCount] and
/// [ClientOptions.shardIds], so their values will be ignored.
///
/// Calling this function in a process that was not spawned by nyxx_sharding will throw a [ShardingError].
ClientOptions getOptions([ClientOptions? defaultOptions]) {
  defaultOptions ??= ClientOptions();

  defaultOptions
    ..shardCount = totalShards
    ..shardIds = shardIds;

  return defaultOptions;
}

/// The total number of shards spawned across all processes. Only for use in spawned processes.
///
/// Invoking this getter in a process that was not spawned by nyxx_sharding will throw a [ShardingError].
int get totalShards {
  if (Platform.environment.containsKey('NYXX_SHARDING_TOTAL_SHARDS')) {
    return int.parse(Platform.environment['NYXX_SHARDING_TOTAL_SHARDS']!);
  }
  throw ShardingError('Missing NYXX_SHARDING_TOTAL_SHARDS variable');
}

/// The shards to spawn in this process. Only for use in spawned processes.
///
/// Invoking this getter in a process that was not spawned by nyxx_sharding will throw a [ShardingError].
List<int> get shardIds {
  if (Platform.environment.containsKey('NYXX_SHARDING_SHARD_IDS')) {
    return List.of(Platform.environment['NYXX_SHARDING_SHARD_IDS']!.split(',').map(int.parse));
  }
  throw ShardingError('Missing NYXX_SHARDING_SHARD_IDS variable');
}
