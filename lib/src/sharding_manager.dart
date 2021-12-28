import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx/src/internal/http_endpoints.dart';
import 'package:nyxx_sharding/src/exceptions.dart';

import 'package:nyxx_sharding/src/process_data/process_data.dart';
import 'package:nyxx_sharding/src/sharding_options.dart';

class ShardingManager {
  final ProcessData processData;

  int? get shardsPerProcess => _shardsPerProcess;
  int? get numProcesses => _numProcesses;
  int? get totalShards => _totalShards;

  int? _shardsPerProcess;
  int? _numProcesses;
  int? _totalShards;

  final String? token;

  final Logger _logger = Logger('Sharding');

  final ShardingOptions options;

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

  Future<void> _startProcesses() async {
    List<int> shardIds = List.generate(_totalShards!, (id) => id);

    for (int totalSpawned = 0; totalSpawned < _totalShards!; totalSpawned += _shardsPerProcess!) {
      int lastIndex = totalSpawned + _shardsPerProcess!;

      if (lastIndex > shardIds.length) {
        lastIndex = shardIds.length;
      }

      Process spawned = await processData.spawn(shardIds.sublist(totalSpawned, lastIndex), _totalShards!);

      if (options.redirectOutput) {
        spawned.stdout.transform(utf8.decoder).forEach(print);
        spawned.stderr.transform(utf8.decoder).forEach(print);
      }

      processes.add(spawned);
    }

    _logger.info('Successfully started ${processes.length} processes, totalling $_totalShards shards');
  }
}
