import 'package:args/args.dart';
import 'package:nyxx_sharding/nyxx_sharding.dart';

void main(List<String> args) async {
  ArgParser parser = ArgParser(allowTrailingOptions: false)
    ..addOption('shards-per-process', abbr: 's', help: 'The maximum number of shards to spawn per process', valueHelp: 'num')
    ..addOption('total-shards', abbr: 'S', help: 'The total number of shards to spawn across all processes', valueHelp: 'num')
    ..addOption('total-processes', abbr: 'p', help: 'The total number of processes to spawn', valueHelp: 'num')
    ..addOption('token',
        abbr: 't',
        help: '''
    A Discord bot token to use for determining the total number of shards.

    If total-shards or both shards-per-process and total-processes are given, the Discord API will not be queried on the total number of shards to use.
    '''
            .trim(),
        valueHelp: 'token')
    ..addOption('cwd', help: 'The working directory to spawn the processes in');

  ArgResults parsed = parser.parse(args);

  int? shardsPerProcess;
  if (parsed['shards-per-process'] != null) {
    shardsPerProcess = int.parse(parsed['shards-per-process'] as String);
  }

  int? totalShards;
  if (parsed['total-shards'] != null) {
    totalShards = int.parse(parsed['total-shards'] as String);
  }

  int? numProcesses;
  if (parsed['total-processes'] != null) {
    numProcesses = int.parse(parsed['total-processes'] as String);
  }

  ShardingManager manager = ShardingManager(
    Executable(
      parsed.rest[0],
      args: parsed.rest.skip(1).toList(),
      cwd: parsed['cwd'] as String?,
    ),
    shardsPerProcess: shardsPerProcess,
    totalShards: totalShards,
    numProcesses: numProcesses,
    token: parsed['token'] as String?,
  );

  await manager.start();

  await Future.wait(manager.processes.map((e) => e.exitCode));
}
