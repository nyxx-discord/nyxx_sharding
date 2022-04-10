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
  int? get shardsPerProcess => _shardsPerProcess;
  @override
  int? get numProcesses => _numProcesses;
  @override
  int? get totalShards => _totalShards;
  @override
  int? get maxGuildsPerShard => _maxGuildsPerShard;
  @override
  int? get maxGuildsPerProcess => _maxGuildsPerProcess;

  int? _shardsPerProcess;
  int? _numProcesses;
  int? _totalShards;
  final int? _maxGuildsPerShard;
  final int? _maxGuildsPerProcess;

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
  })  : _shardsPerProcess = shardsPerProcess,
        _numProcesses = numProcesses,
        _totalShards = totalShards,
        _maxGuildsPerShard = maxGuildsPerShard,
        _maxGuildsPerProcess = maxGuildsPerProcess {
    if (_totalShards != null && _totalShards! < 1) {
      throw ShardingError('Invalid shard count specified: total shard count cannot be below 1');
    }

    if (_numProcesses != null && _numProcesses! < 1) {
      throw ShardingError('Invalid process count: total process count cannot be below 1');
    }

    if (_shardsPerProcess != null && _shardsPerProcess! < 1) {
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
  }

  Future<void> _computeShardAndProcessCounts() async {
    if ([totalShards, numProcesses, shardsPerProcess].where((element) => element != null).length >= 2) {
      // If two of [totalShards], [numProcesses] or [shardsPerProcess] are given, the third can be calculated with
      // this identity: totalShards = numProcesses * shardsPerProcess
      if (totalShards != null && numProcesses != null && shardsPerProcess != null) {
        // If all three are provided, check that the values respect the identity
        if (totalShards != numProcesses! * shardsPerProcess!) {
          throw ShardingError(
            'Total shard count ($totalShards) was not equal to product of process count and shards per process ($numProcesses * $shardsPerProcess = ${numProcesses! * shardsPerProcess!})',
          );
        }
      } else if (numProcesses != null && shardsPerProcess != null) {
        _totalShards = numProcesses! * shardsPerProcess!;
      } else if (totalShards != null && shardsPerProcess != null) {
        _numProcesses = (totalShards! / shardsPerProcess!).ceil();
      } else if (totalShards != null && numProcesses != null) {
        _shardsPerProcess = (totalShards! / numProcesses!).ceil();
      }

      // Warn about guild limits
      await _warnGuildLimits();
    } else {
      // If less than 2 are provided, we need a token as we will need to fetch guild count or recommended shard count.
      if (token == null) {
        throw ShardingError('A token must be provided if less than two of total shards, shards per process or process count are provided');
      }

      if (shardsPerProcess != null) {
        // Get [totalShards] and [numProcesses] from the guild limits if we have them
        if (maxGuildsPerShard != null || maxGuildsPerProcess != null) {
          int guildCount = await _getGuildCount();

          if (maxGuildsPerShard != null) {
            _totalShards = (guildCount / maxGuildsPerShard!).ceil();
            _numProcesses = (totalShards! / shardsPerProcess!).ceil();
          } else if (maxGuildsPerProcess != null) {
            _numProcesses = (guildCount / maxGuildsPerProcess!).ceil();
            _totalShards = numProcesses! * shardsPerProcess!;
          }

          await _warnGuildLimits(guildCount);
        } else {
          // If there are no guild limits, fall back to fetching the recommended shard count from Discord
          _totalShards = await _getRecommendedShards();
          _numProcesses = (totalShards! / shardsPerProcess!).ceil();
        }
      } else if (numProcesses != null) {
        int guildCount = await _getGuildCount();

        // We can't use maxGuildPerProcess since we already have a number of processes
        if (maxGuildsPerShard != null) {
          _totalShards = (guildCount / maxGuildsPerShard!).ceil();
          _shardsPerProcess = (totalShards! / numProcesses!).ceil();
        } else {
          _totalShards = await _getRecommendedShards();
          _shardsPerProcess = (totalShards! / numProcesses!).ceil();
        }

        await _warnGuildLimits(guildCount);
      } else if (maxGuildsPerProcess != null) {
        int guildCount = await _getGuildCount();

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

    String? after;

    int total = 0;

    _logger.info('Fetching guilds...');

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

      after = data.last['id'] as String;

      total += data.length;

      _logger.finer('Got response from guilds endpoint with ${data.length} guilds');

      // Endpoint returns 200 guilds per page; if we get less than 200 we have reached the end of the guild list
      if (data.length < 200) {
        break;
      }

      if (int.parse(response.headers['x-ratelimit-remaining']!) < 2) {
        int resetTimestamp = num.parse(response.headers['x-ratelimit-reset']!).ceil();

        DateTime resetTime = DateTime.fromMillisecondsSinceEpoch(resetTimestamp * 1000);

        await Future.delayed(resetTime.difference(DateTime.now()));
      }
    }

    _logger.info('Found a total of $total guilds');

    return total;
  }

  Future<void> _startProcesses() async {
    _logger.info('Starting $numProcesses processes, each with $shardsPerProcess shards (for a total of $totalShards)');

    List<int> shardIds = List.generate(_totalShards!, (id) => id);

    Duration individualConnectionDelay;
    if (options.timeoutSpawn) {
      int maxConcurrency = await _getMaxConcurrency();
      individualConnectionDelay = Duration(milliseconds: (5 * 1000) ~/ maxConcurrency + 1000);
    } else {
      individualConnectionDelay = Duration.zero;
    }

    for (int totalSpawned = 0; totalSpawned < _totalShards!; totalSpawned += _shardsPerProcess!) {
      int lastIndex = totalSpawned + _shardsPerProcess!;

      if (lastIndex > shardIds.length) {
        lastIndex = shardIds.length;
      }

      await _spawn(shardIds.sublist(totalSpawned, lastIndex));

      _logger.fine('Spawned process with shards ${shardIds.sublist(totalSpawned, lastIndex)}');

      if (lastIndex != shardIds.length) {
        await Future.delayed(individualConnectionDelay * (lastIndex - totalSpawned));
      }
    }

    _logger.info('Successfully started ${processes.length} processes, totalling $_totalShards shards');
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
    final spawnedProcess = await processData.spawn(shardIds, _totalShards!, port);

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

  @override
  Future<void> kill([ProcessSignal signal = ProcessSignal.sigterm]) async {
    _exiting = true;
    for (final process in processes) {
      process.kill(signal);
    }
  }
}
