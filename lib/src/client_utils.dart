import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_sharding/src/exceptions.dart';

ClientOptions getOptions([ClientOptions? defaultOptions]) {
  defaultOptions ??= ClientOptions();

  defaultOptions
    ..shardCount = totalShards
    ..shardIds = shardIds;

  return defaultOptions;
}

int get totalShards {
  if (Platform.environment.containsKey('NYXX_SHARDING_TOTAL_SHARDS')) {
    return int.parse(Platform.environment['NYXX_SHARDING_TOTAL_SHARDS']!);
  }
  throw ShardingError('Missing NYXX_SHARDING_TOTAL_SHARDS variable');
}

List<int> get shardIds {
  if (Platform.environment.containsKey('NYXX_SHARDING_SHARD_IDS')) {
    return List.of(Platform.environment['NYXX_SHARDING_SHARD_IDS']!.split(',').map(int.parse));
  }
  throw ShardingError('Missing NYXX_SHARDING_SHARD_IDS variable');
}
