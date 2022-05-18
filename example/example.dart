// ---------------------------------------------------------------------------------------------------------------------------------
// | You might not need the nyxx_sharding API, have you tried `dart pub global activate nyxx_sharding` and `nyxx-sharding --help`? |
// ---------------------------------------------------------------------------------------------------------------------------------

// Refer to example_client.dart for an example on how to use nyxx_sharding in your client process.

// nyxx_sharding also provides a Dart API for advanced usage, and this is an example usage of that API. Most users won't need to use this and should instead use
// the CLI provided by nyxx_sharding.

// To run this file:
// - Set the environment variable `TOKEN` to your bot's token.
// - Run `dart run example/example.dart` from the repository root (this is important because of relative file paths)

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nyxx_sharding/nyxx_sharding.dart';

void main() async {
  // Create the sharding manager
  IShardingManager manager = IShardingManager.create(
    UncompiledDart('example/example_client.dart'),
    token: Platform.environment['TOKEN']!,
    maxGuildsPerShard: 1,
    shardsPerProcess: 1,
  );

  // Set up logging
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen(print);

  // Start the client processes
  await manager.start();

  // Periodically query and log info from the client processes using the API
  Timer.periodic(Duration(seconds: 5), (timer) async {
    print('Guild cache sizes in processes: ${await manager.getCachedGuilds()}');
  });
}
