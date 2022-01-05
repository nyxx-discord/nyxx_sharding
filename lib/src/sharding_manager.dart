import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx/src/internal/http_endpoints.dart';
import 'package:nyxx_sharding/src/exceptions.dart';

import 'package:nyxx_sharding/src/process_data/process_data.dart';
import 'package:nyxx_sharding/src/sharding_options.dart';

/// Spawns and contains processes running individual instances of the bot.
///
/// The total number of shards, total number of processes and number of shards per process can be manually set, or automatically calculated if [token] is
/// provided. [token] can also be set in conjunction with either [shardsPerProcess] or [numProcesses] for more control.
abstract class IShardingManager {
  /// The [ProcessData] that will be used to spawn the child processes.
  ProcessData get processData;

  /// The number of shards to spawn in each process.
  int? get shardsPerProcess;

  /// The total number of processes to spawn.
  int? get numProcesses;

  /// The total number of shards to spawn across all processes.
  int? get totalShards;

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

  /// Create a new [IShardingManager]
  factory IShardingManager.create(
    ProcessData processData, {
    int? shardsPerProcess,
    int? numProcesses,
    int? totalShards,
    String? token,
    ShardingOptions options = const ShardingOptions(),
  }) =>
      ShardingManager(processData, shardsPerProcess: shardsPerProcess, numProcesses: numProcesses, totalShards: totalShards, token: token, options: options);
}

class ShardingManager implements IShardingManager {
  @override
  final ProcessData processData;

  @override
  int? get shardsPerProcess => _shardsPerProcess;
  @override
  int? get numProcesses => _numProcesses;
  @override
  int? get totalShards => _totalShards;

  int? _shardsPerProcess;
  int? _numProcesses;
  int? _totalShards;

  @override
  final String? token;

  final Logger _logger = Logger('Sharding');

  @override
  final ShardingOptions options;

  @override
  final List<Process> processes = [];

  ShardingManager(
    this.processData, {
    int? shardsPerProcess,
    int? numProcesses,
    int? totalShards,
    this.token,
    this.options = const ShardingOptions(),
  })  : _shardsPerProcess = shardsPerProcess,
        _numProcesses = numProcesses,
        _totalShards = totalShards {
    if (_shardsPerProcess == null && _numProcesses == null && _totalShards == null && token == null) {
      throw ShardingError('One of token, totalShards, or shardsPerProcess and numProcesses must be specified');
    }

    if (_totalShards != null && _shardsPerProcess != null && _numProcesses != null) {
      if (_totalShards != _shardsPerProcess! * _numProcesses!) {
        throw ShardingError('Invalid total shard count specified: total shard count does not equal product of shardsPerProcess and numProcesses');
      }
    }

    if (_totalShards != null && _totalShards! < 1) {
      throw ShardingError('Invalid shard count specified: total shard count cannot be below 1');
    }

    if (_numProcesses != null && _numProcesses! < 1) {
      throw ShardingError('Invalid process count: total process count cannot be below 1');
    }

    if (_shardsPerProcess != null && _shardsPerProcess! < 1) {
      throw ShardingError('Invalid shard per process count specified: total shards per process cannot be less than 1');
    }
  }

  @override
  Future<void> start() async {
    await _computeShardAndProcessCounts();

    if ((_totalShards! / _shardsPerProcess!).ceil() < _numProcesses!) {
      _logger.info('Number of processes is larger than needed; less processes will be spawned');
    }

    await _startProcesses();
  }

  Future<void> _computeShardAndProcessCounts() async {
    if (_totalShards == null) {
      if (_shardsPerProcess != null && _numProcesses != null) {
        _totalShards = _numProcesses! * _shardsPerProcess!;
      } else {
        _totalShards = await _getRecomendedShards(token!);
      }
    }

    if (_numProcesses == null && _shardsPerProcess == null) {
      _shardsPerProcess = 5; // TODO determine best default
    }

    _numProcesses ??= (_totalShards! / _shardsPerProcess!).ceil();
    _shardsPerProcess ??= (_totalShards! / _numProcesses!).ceil();
  }

  Future<int> _getRecomendedShards(String token) async {
    INyxx client = NyxxFactory.createNyxxRest(token, GatewayIntents.none, Snowflake.zero());

    await client.connect();

    IHttpResponse gatewayBot = await (client.httpEndpoints as HttpEndpoints).getGatewayBot();

    if (gatewayBot is IHttpResponseError) {
      throw ShardingError('Cannot connect to Discord to get recommended shard count: [$gatewayBot]');
    }

    await client.dispose();

    int recommended = (gatewayBot as IHttpResponseSucess).jsonBody["shards"] as int;

    _logger.info('Got recommended number of shards: $recommended');

    return recommended;
  }

  Future<int> _getMaxConcurrency() async {
    if (token == null) {
      return 1;
    }

    INyxx client = NyxxFactory.createNyxxRest(token!, GatewayIntents.none, Snowflake.zero());

    await client.connect();

    IHttpResponse gatewayBot = await (client.httpEndpoints as HttpEndpoints).getGatewayBot();

    if (gatewayBot is IHttpResponseError) {
      throw ShardingError('Cannot connect to Discord to get max connection concurrency: [$gatewayBot]');
    }

    await client.dispose();

    int maxConcurrency = (gatewayBot as IHttpResponseSucess).jsonBody['session_start_limit']['max_concurrency'] as int;

    _logger.info('Got max concurrency: $maxConcurrency');

    return maxConcurrency;
  }

  Future<void> _startProcesses() async {
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

      Process spawned = await processData.spawn(shardIds.sublist(totalSpawned, lastIndex), _totalShards!);

      if (options.redirectOutput) {
        spawned.stdout.transform(utf8.decoder).forEach(stdout.write);
        spawned.stderr.transform(utf8.decoder).forEach(stderr.write);
      }

      processes.add(spawned);

      if (lastIndex != shardIds.length) {
        await Future.delayed(individualConnectionDelay * (lastIndex - totalSpawned));
      }
    }

    _logger.info('Successfully started ${processes.length} processes, totalling $_totalShards shards');
  }
}
