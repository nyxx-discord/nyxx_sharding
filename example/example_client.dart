// An example target file. See example.dart for the example on how to start this.

import 'dart:io';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_sharding/nyxx_sharding.dart';
import 'package:nyxx_sharding/src/communication/sharding_plugin.dart';

void main() async {
  // [shardIds] and [totalShards] are two getters exposed by nyxx_sharding, indicating which shards to spawn in this process and the total number of shards
  // across all processes respectively.
  print('Process $pid started with shards $shardIds (total $totalShards)');

  INyxxWebsocket client = NyxxFactory.createNyxxWebsocket(
    Platform.environment['TOKEN']!,
    GatewayIntents.allUnprivileged,
    // Call [getOptions] to let nyxx_sharding create the correct client options for you
    options: getOptions(),
  );

  // Register the sharding plugin to allow other processes to query this process about data like memory usage and cache sizes.
  // The plugin is also how you can request that data, so you might want to extract it to a variable.
  client.registerPlugin(ShardingPlugin());

  client.connect();
}
