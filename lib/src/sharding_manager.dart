import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

import 'package:nyxx_sharding/src/communication/common.dart';
import 'package:nyxx_sharding/src/exceptions.dart';
import 'package:nyxx_sharding/src/process_data/process_data.dart';
import 'package:nyxx_sharding/src/sharding_options.dart';
import 'package:nyxx_sharding/src/communication/sharding_plugin.dart';
import 'package:nyxx_sharding/src/communication/sharding_server.dart';

/// Spawns and contains processes running individual instances of the bot.
///
/// The total number of shards, total number of processes and number of shards per process can be manually set, or automatically calculated if [token] is
/// provided. [token] can also be set in conjunction with either [shardsPerProcess] or [numProcesses] for more control.
abstract class IShardingManager implements IDataProvider {
  /// The [ProcessData] that will be used to spawn the child processes.
  ProcessData get processData;

  /// The number of shards to spawn in each process.
  int? get shardsPerProcess;

  /// The total number of processes to spawn.
  int? get numProcesses;

  /// The total number of shards to spawn across all processes.
  int? get totalShards;

  /// The maximum number of guilds on a single shard.
  int? get maxGuildsPerShard;

  /// The maximum number of guilds on a single process.
  int? get maxGuildsPerProcess;

  /// A Discord bot token used to automatically determine the maximum IDENTIFY concurrency for the bot. If [totalShards] is not provided, [token] will also be
  /// used to get the total shard count.
  ///
  /// If [token] is not set, the maximum concurrency will default to `1`, and either [totalShards] or [numProcesses] and [shardsPerProcess] must be provided.
  String? get token;

  /// The options for this [IShardingManager].
  ShardingOptions get options;

  /// The processes spawned by this [IShardingManager].
  ///
  /// This list will be empty until the [Future] returned by [start] completes.
  List<Process> get processes;

  /// Start all the child processes. This is a lengthy operation.
  Future<void> start();

  /// Kills all child processes.
  ///
  /// [signal] will be sent to all processes.
  Future<void> kill([ProcessSignal signal = ProcessSignal.sigterm]);

  /// A stream of events received on this process.
  ///
  /// Events can be sent using [IShardingPlugin.sendManager].
  Stream<String> get events;

  /// Sends a message to all child processes.
  ///
  /// The message will be added to the [IShardingPlugin.events] stream.
  void broadcast(String message);

  /// Create a new [IShardingManager].
  ///
  /// The table below indicates how the different combinations of values are combined to calculate process counts and shard counts:
  /// ```
  /// sPP = shardsPerProcess
  /// nP = numProcesses
  /// tS = totalShards
  /// gPS = guildsPerShard
  /// gPP = guildsPerProcess
  /// tkn = token
  /// gC = guildCount
  ///
  /// fetch(d) = fetch `d` from the Discord API using the provided token
  ///
  /// |t|s|n|t|g|g|
  /// |k|P|P|S|P|P|
  /// |n|P| | |S|P|
  /// |-|-|-|-|-|-|
  /// |x|x|x|x|x|x| CHECK tS = nP * sPP; WARN IF fetch(gC) / nP > gPP; WARN IF fetch(gC) / tS > gPS;
  /// |x|x|x|x|x| | CHECK tS = nP * sPP; WARN IF fetch(gC) / tS > gPS;
  /// |x|x|x|x| |x| CHECK tS = nP * sPP; WARN IF fetch(gC) / nP > gPP;
  /// |x|x|x|x| | | CHECK tS = nP * sPP;
  /// |x|x|x| |x|x| USE tS = sPP * nP; WARN IF fetch(gC) / nP > gPP; WARN IF fetch(gC) / tS > gPS;
  /// |x|x|x| |x| | USE tS = sPP * nP; WARN IF fetch(gC) / tS > gPS;
  /// |x|x|x| | |x| USE tS = sPP * nP; WARN IF fetch(gC) / nP > gPP;
  /// |x|x|x| | | | USE tS = sPP * nP;
  /// |x|x| |x|x|x| USE nP = ceil(tS / sPP); WARN IF fetch(gC) / nP > gPP; WARN IF fetch(gC) / tS > gPS;
  /// |x|x| |x|x| | USE nP = ceil(tS / sPP); WARN IF fetch(gC) / tS > gPS;
  /// |x|x| |x| |x| USE nP = ceil(tS / sPP); WARN IF fetch(gC) / nP > gPP;
  /// |x|x| |x| | | USE nP = ceil(tS / sPP);
  /// |x|x| | |x|x| USE tS = ceil(fetch(gC) / gPS); USE nP = ceil(tS / sPP); WARN IF fetch(gC) / nP > gPP;
  /// |x|x| | |x| | USE tS = ceil(fetch(gC) / gPS); USE nP = ceil(tS / sPP);
  /// |x|x| | | |x| USE nP = ceil(fetch(gC) / gPP); USE tS = sPP * nP;
  /// |x|x| | | | | USE tS = fetch(tS); USE nP = ceil(tS / sPP);
  /// |x| |x|x|x|x| USE sPP = ceil(tS / nP); WARN IF fetch(gC) / nP > gPP; WARN IF fetch(gC) / tS > gPS;
  /// |x| |x|x|x| | USE sPP = ceil(tS / nP); WARN IF fetch(gC) / tS > gPS;
  /// |x| |x|x| |x| USE sPP = ceil(tS / nP); WARN IF fetch(gC) / nP > gPP;
  /// |x| |x|x| | | USE sPP = ceil(tS / nP);
  /// |x| |x| |x|x| USE tS = ceil(fetch(gC) / gPS); USE sPP = ceil(tS / nP); WARN IF fetch(gC) / nP > gPP;
  /// |x| |x| |x| | USE tS = ceil(fetch(gC) / gPS); USE sPP = ceil(tS / nP);
  /// |x| |x| | |x| USE tS = fetch(tS); USE sPP = ceil(tS / nP); WARN IF fetch(gC) / nP > gPP;
  /// |x| |x| | | | USE tS = fetch(tS); USE sPP = ceil(tS / nP);
  /// |x| | |x|x|x| USE nP = ceil(fetch(gC) / gPP); USE sPP = ceil(tS / nP); WARN IF fetch(gC) / tS > gPS;
  /// |x| | |x|x| | ERROR
  /// |x| | |x| |x| USE nP = ceil(fetch(gC) / gPP); USE sPP = ceil(tS / nP);
  /// |x| | |x| | | ERROR
  /// |x| | | |x|x| USE nP = ceil(fetch(gC) / gPP); USE tS = ceil(fetch(gC) / gPS); USE sPP = ceil(tS / nP);
  /// |x| | | |x| | ERROR
  /// |x| | | | |x| USE nP = ceil(fetch(gC) / gPP); USE tS = fetch(tS); USE sPP = ceil(tS / nP);
  /// |x| | | | | | ERROR
  /// | |x|x|x|x|x| CHECK tS = nP * sPP; WARN "No token to fetch guild count";
  /// | |x|x|x|x| | CHECK tS = nP * sPP; WARN "No token to fetch guild count";
  /// | |x|x|x| |x| CHECK tS = nP * sPP; WARN "No token to fetch guild count";
  /// | |x|x|x| | | CHECK tS = nP * sPP;
  /// | |x|x| |x|x| USE tS = sPP * nP; WARN "No token to fetch guild count";
  /// | |x|x| |x| | USE tS = sPP * nP; WARN "No token to fetch guild count";
  /// | |x|x| | |x| USE tS = sPP * nP; WARN "No token to fetch guild count";
  /// | |x|x| | | | USE tS = sPP * nP;
  /// | |x| |x|x|x| USE nP = ceil(tS / sPP); WARN "No token to fetch guild count";
  /// | |x| |x|x| | USE nP = ceil(tS / sPP); WARN "No token to fetch guild count";
  /// | |x| |x| |x| USE nP = ceil(tS / sPP); WARN "No token to fetch guild count";
  /// | |x| |x| | | USE nP = ceil(tS / sPP);
  /// | |x| | |x|x| ERROR
  /// | |x| | |x| | ERROR
  /// | |x| | | |x| ERROR
  /// | |x| | | | | ERROR
  /// | | |x|x|x|x| USE sPP = ceil(tS / nP); WARN "No token to fetch guild count";
  /// | | |x|x|x| | USE sPP = ceil(tS / nP); WARN "No token to fetch guild count";
  /// | | |x|x| |x| USE sPP = ceil(tS / nP); WARN "No token to fetch guild count";
  /// | | |x|x| | | USE sPP = ceil(tS / nP);
  /// | | |x| |x|x| ERROR
  /// | | |x| |x| | ERROR
  /// | | |x| | |x| ERROR
  /// | | |x| | | | ERROR
  /// | | | |x|x|x| ERROR
  /// | | | |x|x| | ERROR
  /// | | | |x| |x| ERROR
  /// | | | |x| | | ERROR
  /// | | | | |x|x| ERROR
  /// | | | | |x| | ERROR
  /// | | | | | |x| ERROR
  /// | | | | | | | ERROR
  /// ```
  factory IShardingManager.create(
    ProcessData processData, {
    int? shardsPerProcess,
    int? numProcesses,
    int? totalShards,
    int? maxGuildsPerShard,
    int? maxGuildsPerProcess,
    String? token,
    ShardingOptions options = const ShardingOptions(),
  }) =>
      ShardingManager(
        processData,
        shardsPerProcess: shardsPerProcess,
        numProcesses: numProcesses,
        totalShards: totalShards,
        maxGuildsPerProcess: maxGuildsPerProcess,
        maxGuildsPerShard: maxGuildsPerShard,
        token: token,
        options: options,
      );
}

class ShardingManager with ShardingServer implements IShardingManager {
  @override
  final ProcessData processData;

  @override
  int? get shardsPerProcess => _providedShardsPerProcess ?? _shardsPerProcess;
  @override
  int? get numProcesses => _providedNumProcesses ?? _numProcesses;
  @override
  int? get totalShards => _providedTotalShards ?? _totalShards;
  @override
  int? get maxGuildsPerShard => _maxGuildsPerShard;
  @override
  int? get maxGuildsPerProcess => _maxGuildsPerProcess;

  int? _shardsPerProcess;
  int? _numProcesses;
  int? _totalShards;
  final int? _maxGuildsPerShard;
  final int? _maxGuildsPerProcess;

  final int? _providedShardsPerProcess;
  final int? _providedNumProcesses;
  final int? _providedTotalShards;

  @override
  final String? token;

  final Logger _logger = Logger('Sharding');

  @override
  final ShardingOptions options;

  @override
  final List<Process> processes = [];

  bool _exiting = false;

  ShardingManager(
    this.processData, {
    int? shardsPerProcess,
    int? numProcesses,
    int? totalShards,
    int? maxGuildsPerShard,
    int? maxGuildsPerProcess,
    this.token,
    this.options = const ShardingOptions(),
  })  : _providedShardsPerProcess = shardsPerProcess,
        _providedNumProcesses = numProcesses,
        _providedTotalShards = totalShards,
        _maxGuildsPerShard = maxGuildsPerShard,
        _maxGuildsPerProcess = maxGuildsPerProcess {
    if (_providedTotalShards != null && _providedTotalShards! < 1) {
      throw ShardingError('Invalid shard count specified: total shard count cannot be below 1');
    }

    if (_providedNumProcesses != null && _providedNumProcesses! < 1) {
      throw ShardingError('Invalid process count: total process count cannot be below 1');
    }

    if (_providedShardsPerProcess != null && _providedShardsPerProcess! < 1) {
      throw ShardingError('Invalid shard per process count specified: total shards per process cannot be less than 1');
    }

    if (_maxGuildsPerProcess != null && _maxGuildsPerProcess! < 1) {
      throw ShardingError('Invalid guild count per process: maximum guild count cannot be below 1');
    }

    if (_maxGuildsPerShard != null && _maxGuildsPerShard! < 1) {
      throw ShardingError('Invalid guild count per shard: maximum guild count cannot be below 1');
    }
  }

  @override
  Future<void> start() async {
    await super.startServer();

    await _computeShardAndProcessCounts();

    _logger.fine('Process count: $numProcesses');
    _logger.fine('Shard count: $totalShards');
    _logger.fine('Shards per process: $shardsPerProcess');

    if ((totalShards! / shardsPerProcess!).ceil() < numProcesses!) {
      _logger.info('Number of processes is larger than needed; less processes will be spawned');
      _logger.info(
        'Reducing process count from $numProcesses to ${(totalShards! / shardsPerProcess!).ceil()}',
      );

      _numProcesses = (totalShards! / shardsPerProcess!).ceil();
    }

    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      signal.watch().listen((event) async {
        _logger.info('Exiting...');

        await kill(event);

        Isolate.current.kill();
      });
    }

    await _startProcesses();

    if (options.autoScale) {
      _startMonitoring();
    }
  }

  Future<void> _computeShardAndProcessCounts([int? existingGuildCount]) async {
    if ([_providedTotalShards, _providedNumProcesses, _providedShardsPerProcess].where((element) => element != null).length >= 2) {
      // If two of [totalShards], [numProcesses] or [shardsPerProcess] are given, the third can be calculated with
      // this identity: totalShards = numProcesses * shardsPerProcess
      if (_providedTotalShards != null && _providedNumProcesses != null && _providedShardsPerProcess != null) {
        // If all three are provided, check that the values respect the identity
        if (_providedTotalShards != _providedNumProcesses! * _providedShardsPerProcess!) {
          throw ShardingError(
            'Total shard count ($_providedTotalShards) was not equal to product of process count and shards per process ($_providedNumProcesses * $_providedShardsPerProcess = ${_providedNumProcesses! * _providedShardsPerProcess!})',
          );
        }
      } else if (_providedNumProcesses != null && _providedShardsPerProcess != null) {
        _totalShards = _providedNumProcesses! * _providedShardsPerProcess!;
      } else if (_providedTotalShards != null && _providedShardsPerProcess != null) {
        _numProcesses = (_providedTotalShards! / _providedShardsPerProcess!).ceil();
      } else if (_providedTotalShards != null && _providedNumProcesses != null) {
        _shardsPerProcess = (_providedTotalShards! / _providedNumProcesses!).ceil();
      }

      // Warn about guild limits
      await _warnGuildLimits(existingGuildCount);
    } else {
      // If less than 2 are provided, we need a token as we will need to fetch guild count or recommended shard count.
      if (token == null) {
        throw ShardingError('A token must be provided if less than two of total shards, shards per process or process count are provided');
      }

      if (_providedShardsPerProcess != null) {
        // Get [totalShards] and [numProcesses] from the guild limits if we have them
        if (maxGuildsPerShard != null || maxGuildsPerProcess != null) {
          int guildCount = existingGuildCount ?? await _getGuildCount();

          if (maxGuildsPerShard != null) {
            _totalShards = (guildCount / maxGuildsPerShard!).ceil();
            _numProcesses = (totalShards! / _providedShardsPerProcess!).ceil();
          } else if (maxGuildsPerProcess != null) {
            _numProcesses = (guildCount / maxGuildsPerProcess!).ceil();
            _totalShards = numProcesses! * _providedShardsPerProcess!;
          }

          await _warnGuildLimits(guildCount);
        } else {
          // If there are no guild limits, fall back to fetching the recommended shard count from Discord
          _totalShards = await _getRecommendedShards();
          _numProcesses = (totalShards! / _providedShardsPerProcess!).ceil();
        }
      } else if (_providedNumProcesses != null) {
        int guildCount = existingGuildCount ?? await _getGuildCount();

        // We can't use maxGuildPerProcess since we already have a number of processes
        if (maxGuildsPerShard != null) {
          _totalShards = (guildCount / maxGuildsPerShard!).ceil();
          _shardsPerProcess = (totalShards! / _providedNumProcesses!).ceil();
        } else {
          _totalShards = await _getRecommendedShards();
          _shardsPerProcess = (totalShards! / _providedNumProcesses!).ceil();
        }

        await _warnGuildLimits(guildCount);
      } else if (maxGuildsPerProcess != null) {
        int guildCount = existingGuildCount ?? await _getGuildCount();

        _numProcesses = (guildCount / maxGuildsPerProcess!).ceil();

        if (totalShards == null) {
          if (maxGuildsPerShard != null) {
            _totalShards = (guildCount / maxGuildsPerShard!).ceil();
          } else {
            _totalShards = await _getRecommendedShards();
          }
        }

        _shardsPerProcess = (totalShards! / numProcesses!).ceil();

        await _warnGuildLimits(guildCount);
      } else {
        throw ShardingError('Not enough parameters were provided to calculate shard and process counts');
      }
    }
  }

  Future<void> _warnGuildLimits([int? guildCount]) async {
    if (maxGuildsPerProcess != null || maxGuildsPerShard != null) {
      if (guildCount == null) {
        if (token == null) {
          _logger.warning('No token to fetch guild count to validate maximum guilds per shard and per process');
          return;
        }

        guildCount = await _getGuildCount();
      }

      if (maxGuildsPerProcess != null && guildCount / numProcesses! > maxGuildsPerProcess!) {
        _logger.warning('Current setup causes guilds per process (${guildCount / numProcesses!}) to be larger than maximum ($maxGuildsPerProcess)');
      }

      if (maxGuildsPerShard != null && guildCount / totalShards! > maxGuildsPerShard!) {
        _logger.warning('Current setup causes guilds per shard (${guildCount / totalShards!}) to be larger than maximum ($maxGuildsPerShard)');
      }
    }
  }

  Future<int> _getRecommendedShards() async {
    if (token == null) {
      throw ShardingError('Cannot get recommended shard count when token is null');
    }

    http.Response response = await http.get(
      Uri.parse('https://discord.com/api/gateway/bot'),
      headers: {
        'Authorization': 'Bot $token',
      },
    );

    if (response.statusCode != 200) {
      throw ShardingError('Got invalid response ${response.statusCode} from Discord API when querying recommended shards');
    }

    Map<String, dynamic> gatewayBot = jsonDecode(response.body) as Map<String, dynamic>;

    return gatewayBot['shards'] as int;
  }

  Future<int> _getGuildCount() async {
    if (token == null) {
      throw ShardingError('Cannot get guild count when token is null');
    }

    if (options.useImpreciseGuildCount) {
      _logger.info('Fetching guilds using approximation...');

      // Discord seems to recommend 1000 guilds per shard
      return await _getRecommendedShards() * 1000;
    }

    String? after;

    int total = 0;

    _logger.info('Fetching guilds... (this may take a while)');

    while (true) {
      http.Response response = await http.get(
        Uri.parse('https://discord.com/api/users/@me/guilds${after == null ? '' : '?after=$after'}'),
        headers: {
          'Authorization': 'Bot $token',
        },
      );

      if (response.statusCode != 200) {
        throw ShardingError('Got invalid response ${response.statusCode} from Discord API when querying guilds');
      }

      List<Map<String, dynamic>> data = (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();

      // Query guilds until we reach the final page, which will be empty
      if (data.isEmpty) {
        _logger.finer('Got empty response from guilds endpoint, assuming all guilds have been fetched.');
        break;
      }

      after = data.last['id'] as String;

      total += data.length;

      _logger.finer('Got response from guilds endpoint with ${data.length} guilds');

      if (int.parse(response.headers['x-ratelimit-remaining']!) < 2) {
        int resetTimestamp = num.parse(response.headers['x-ratelimit-reset']!).ceil();

        DateTime resetTime = DateTime.fromMillisecondsSinceEpoch(resetTimestamp * 1000);

        _logger.finer('Waiting until $resetTime to avoid rate limits on guilds endpoint');

        await Future.delayed(resetTime.difference(DateTime.now()));
      }
    }

    _logger.info('Found a total of $total guilds');

    return total;
  }

  Future<void> _startProcesses() async {
    _logger.info('Starting $numProcesses processes, each with $shardsPerProcess shards (for a total of $totalShards)');

    List<int> shardIds = List.generate(totalShards!, (id) => id);

    Duration individualConnectionDelay = await _getConnectionDelay();

    for (int totalSpawned = 0; totalSpawned < totalShards!; totalSpawned += shardsPerProcess!) {
      int lastIndex = totalSpawned + shardsPerProcess!;

      if (lastIndex > shardIds.length) {
        lastIndex = shardIds.length;
      }

      await _spawn(shardIds.sublist(totalSpawned, lastIndex));

      _logger.fine('Spawned process with shards ${shardIds.sublist(totalSpawned, lastIndex)}');

      if (lastIndex != shardIds.length) {
        await Future.delayed(individualConnectionDelay * (lastIndex - totalSpawned));
      }
    }

    _logger.info('Successfully started ${processes.length} processes, totalling $totalShards shards');
  }

  Future<Duration> _getConnectionDelay() async {
    if (options.timeoutSpawn) {
      int maxConcurrency = await _getMaxConcurrency();
      return Duration(milliseconds: (5 * 1000) ~/ maxConcurrency + 1000);
    }

    return Duration.zero;
  }

  Future<int> _getMaxConcurrency() async {
    if (token == null) {
      _logger.fine('No token; returning default max concurrency (1)');
      return 1;
    }

    _logger.fine('Fetching maximum concurrency...');

    http.Response response = await http.get(
      Uri.parse('https://discord.com/api/gateway/bot'),
      headers: {
        'Authorization': 'Bot $token',
      },
    );

    if (response.statusCode != 200) {
      throw ShardingError('Got invalid response ${response.statusCode} from Discord API when querying maximum concurrency');
    }

    Map<String, dynamic> gatewayBot = jsonDecode(response.body) as Map<String, dynamic>;

    int maxConcurrency = gatewayBot['session_start_limit']['max_concurrency'] as int;

    _logger.fine('Got maximum concurrency: $maxConcurrency');

    return maxConcurrency;
  }

  Future<Process> _spawn(List<int> shardIds) async {
    final spawnedProcess = await processData.spawn(shardIds, totalShards!, port);

    if (options.redirectOutput) {
      spawnedProcess.stdout.transform(utf8.decoder).forEach(stdout.write);
      spawnedProcess.stderr.transform(utf8.decoder).forEach(stderr.write);
    }

    processes.add(spawnedProcess);

    spawnedProcess.exitCode.then((code) {
      processes.remove(spawnedProcess);

      String message = 'Process ${spawnedProcess.pid} exited with exit code $code';

      if (code == 0) {
        _logger.info(message);
      } else {
        _logger.warning(message);
      }

      if (code != 0 && !_exiting && options.respawnProcesses) {
        _logger.info('Respawning process with shard IDs $shardIds');

        _spawn(shardIds);
      }
    });

    return spawnedProcess;
  }

  Future<void> _startMonitoring() async {
    _logger.info('Waiting for all processes to connect to manager...');

    while (connections.length != numProcesses) {
      Completer<void> nextConnection = Completer();

      StreamSubscription<WebSocket> nextConnectionSubscription = onConnection.listen((event) => nextConnection.complete());

      await nextConnection.future;
      nextConnectionSubscription.cancel();
    }

    _logger.info('Starting to monitor processes');

    while (!_exiting) {
      await Future.delayed(options.autoScaleInterval);
      await _updateProcesses();
    }
  }

  Future<void> _updateProcesses() async {
    int oldShardsPerProcess = shardsPerProcess!;
    int oldNumProcesses = numProcesses!;
    int oldTotalShards = totalShards!;

    _logger.finer('Updating processes...');

    // Use the guild count obtained from the processes themselves instesad of refetching it
    await _computeShardAndProcessCounts((await getCachedGuilds()).reduce((a, b) => a + b));

    // Restart processes if needed
    if (oldShardsPerProcess != shardsPerProcess || oldNumProcesses != numProcesses || oldTotalShards != totalShards) {
      _logger.info('Restarting $numProcesses processes, each with $shardsPerProcess shards (for a total of $totalShards)');
      _logger.fine('(Previously $oldNumProcesses processes, each with $oldShardsPerProcess shards (for a total of $oldTotalShards))');

      // Prevent processes from restarting
      _exiting = true;

      List<int> shardIds = List.generate(totalShards!, (i) => i);

      Duration individualConnectionDelay = await _getConnectionDelay();

      List<Process> oldProcesses = List.from(processes);

      for (int totalSpawned = 0; totalSpawned < totalShards!; totalSpawned += shardsPerProcess!) {
        int lastIndex = totalSpawned + shardsPerProcess!;

        if (lastIndex > shardIds.length) {
          lastIndex = shardIds.length;
        }

        // Ensure all processes handling shards we are about to spawn are dead so we don't get single events twice
        double progress = lastIndex / totalShards!;
        int progressIndex = (progress * oldProcesses.length).ceil();
        for (int i = 0; i < progressIndex; i++) {
          if (oldProcesses[i].kill(ProcessSignal.sigterm)) {
            _logger.fine('Killing old process #${i + 1} of ${oldProcesses.length}...');
            await oldProcesses[i].exitCode.timeout(
              Duration(minutes: 1),
              onTimeout: () {
                _logger.warning('Forcefully killing old process #${i + 1} of ${oldProcesses.length} as it did not shutdown gracefully'
                    ' (did you add CliIntegration to your client?)');

                oldProcesses[i].kill(ProcessSignal.sigkill);
                return oldProcesses[i].exitCode;
              },
            );
            _logger.info('Killed old process #${i + 1} of ${oldProcesses.length}');
          }
        }

        await _spawn(shardIds.sublist(totalSpawned, lastIndex));

        _logger.fine('Spawned new process with shards ${shardIds.sublist(totalSpawned, lastIndex)}');

        if (lastIndex != shardIds.length) {
          await Future.delayed(individualConnectionDelay * (lastIndex - totalSpawned));
        }
      }

      _exiting = false;
    }
  }

  @override
  Future<void> kill([ProcessSignal signal = ProcessSignal.sigterm]) async {
    _exiting = true;
    for (final process in processes) {
      process.kill(signal);
    }
  }
}
