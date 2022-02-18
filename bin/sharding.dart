import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:nyxx_sharding/nyxx_sharding.dart';

void main(List<String> args) async {
  ArgParser parser = ArgParser()
    ..addOption(
      'shards-per-process',
      abbr: 's',
      help: 'The maximum number of shards to spawn on each process.',
    )
    ..addOption(
      'shards',
      abbr: 'S',
      help: 'The total number of shards to spawn.',
    )
    ..addOption(
      'process-count',
      abbr: 'p',
      help: 'The total number of processes to spawn.',
    )
    ..addOption(
      'guilds-per-shard',
      abbr: 'g',
      help: 'The maximum number of guilds to spawn on each shard.',
    )
    ..addOption(
      'guilds-per-process',
      abbr: 'G',
      help: 'The maximum number of guilds to spawn on each process.',
    )
    ..addOption(
      'token',
      abbr: 'T',
      help: 'The token to use for querying the Discord API for guild counts and the recommended shard count.',
    )
    ..addOption(
      'verbose',
      abbr: 'v',
      allowed: Level.LEVELS.map((level) => level.name.toLowerCase()),
      defaultsTo: Level.INFO.name.toLowerCase(),
      help: 'The verbosity level.',
    )
    ..addFlag(
      'executable',
      abbr: 'E',
      defaultsTo: false,
      help: 'Treat file as an executable instead of a Dart program to be run with dart run.',
    )
    ..addFlag(
      'help',
      defaultsTo: false,
      help: 'Print this help message and exit.',
      negatable: false,
    );

  if (args.isEmpty) {
    printHelp(parser);
    return;
  }

  ArgResults results = parser.parse(args);

  if (results['help'] as bool) {
    printHelp(parser);
    return;
  }

  if (results.rest.isEmpty) {
    print('No program specified.\nuse nyxx-sharding --help for help.');
    return;
  }

  int? shardsPerProcess;
  int? shards;
  int? processCount;
  int? guildsPerShard;
  int? guildsPerProcess;

  try {
    if (results.wasParsed('shards-per-process')) {
      shardsPerProcess = int.parse(results['shards-per-process'] as String);
    }

    if (results.wasParsed('shards')) {
      shards = int.parse(results['shards'] as String);
    }

    if (results.wasParsed('process-count')) {
      processCount = int.parse(results['process-count'] as String);
    }

    if (results.wasParsed('guilds-per-shard')) {
      guildsPerShard = int.parse(results['guilds-per-shard'] as String);
    }

    if (results.wasParsed('guilds-per-process')) {
      guildsPerProcess = int.parse(results['guilds-per-process'] as String);
    }
  } on FormatException {
    print('Invalid argument.');
    return;
  }

  ProcessData data;
  if (results['executable'] as bool) {
    data = Executable(
      results.rest.first,
      args: results.rest.skip(1).toList(),
    );
  } else {
    data = UncompiledDart(
      results.rest.first,
      processArgs: results.rest.skip(1).toList(),
    );
  }

  Logger.root.level = Level.LEVELS.singleWhere((level) => level.name.toLowerCase() == results['verbose']);

  Logger.root.onRecord.listen((rec) {
    print("[${rec.time}] [${rec.level.name}] [${rec.loggerName}] ${rec.message}");
  });

  try {
    IShardingManager manager = IShardingManager.create(
      data,
      token: results['token'] as String?,
      maxGuildsPerProcess: guildsPerProcess,
      maxGuildsPerShard: guildsPerShard,
      numProcesses: processCount,
      shardsPerProcess: shardsPerProcess,
      totalShards: shards,
    );

    await manager.start();
  } on ShardingError catch (e) {
    print(e.message);
  }
}

void printHelp(ArgParser parser) {
  print('''
nyxx-sharding - Run Discord shards across multiple processes

Usage:
  nyxx-sharding [OPTIONS] file [...ARGUMENTS]

Options:
${parser.usage}
''');
}
