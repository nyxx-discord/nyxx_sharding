/// A utility library for implementing external sharding with [nyxx](https://pub.dev/packages/nyxx), or alternatively with any Discord bot framework.
///
/// Automatically splits shards across multiple processes that will be automatically spawned.
library nyxx_sharding;

export 'src/client_utils.dart' show shardIds, totalShards, getOptions;
export 'src/communication/sharding_plugin.dart' show IShardingPlugin;
export 'src/exceptions.dart' show ShardingError;
export 'src/process_data/process_data.dart' show ProcessData;
export 'src/process_data/uncomplied_dart.dart' show UncompiledDart;
export 'src/process_data/executable.dart' show Executable;
export 'src/sharding_manager.dart' show IShardingManager;
export 'src/sharding_options.dart' show ShardingOptions;
