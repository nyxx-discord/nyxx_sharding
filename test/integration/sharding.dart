@Timeout(Duration(minutes: 5))
import 'dart:convert';

import 'package:nyxx_sharding/nyxx_sharding.dart';

import 'package:test/test.dart';

ProcessData _emptyData = UncompiledDart('./test/_empty.dart');
ProcessData _logsOnceData = UncompiledDart('./test/_logs_once.dart');
ProcessData _configData = UncompiledDart('./test/_config.dart');

void main() {
  group('Invalid input', () {
    test('Missing input', () {
      expect(() => IShardingManager.create(_emptyData).start(), throwsA(isA<ShardingError>()));
    });

    test('Mismatched input', () {
      expect(
          () => IShardingManager.create(
                _emptyData,
                totalShards: 50,
                numProcesses: 5,
                shardsPerProcess: 20,
              ).start(),
          throwsA(isA<ShardingError>()));
    });
  });

  group('totalShards', () {
    test('calculated from numProcesses and shardsPerProcess', () async {
      IShardingManager manager = IShardingManager.create(
        _emptyData,
        numProcesses: 5,
        shardsPerProcess: 20,
        options: ShardingOptions(timeoutSpawn: false),
      );

      await manager.start();

      expect(manager.totalShards, equals(100));
    });
  });

  group('shardsPerProcess', () {
    test('calculated from totalShards and numProcesses', () async {
      IShardingManager manager = IShardingManager.create(
        _emptyData,
        numProcesses: 10,
        totalShards: 100,
        options: ShardingOptions(timeoutSpawn: false),
      );

      await manager.start();

      expect(manager.shardsPerProcess, equals(10));
    });
  });

  group('numProcesses', () {
    test('calculated from totalShards and shardsPerProcess', () async {
      IShardingManager manager = IShardingManager.create(
        _emptyData,
        totalShards: 20,
        shardsPerProcess: 4,
        options: ShardingOptions(timeoutSpawn: false),
      );

      await manager.start();

      expect(manager.numProcesses, equals(5));
    });
  });

  group('Process spawning', () {
    test('Processes are spawned correctly', () async {
      IShardingManager manager = IShardingManager.create(
        _logsOnceData,
        totalShards: 1,
        numProcesses: 1,
        options: ShardingOptions(timeoutSpawn: false, redirectOutput: false),
      );

      await manager.start();

      expect(manager.processes.length, equals(1));
      expect(manager.processes.first.stdout.transform(utf8.decoder), emits(equals('Process spawned successfully\n')));
    });
  });

  group('Utilities', () {
    test('totalShards', () async {
      IShardingManager manager = IShardingManager.create(
        _configData,
        totalShards: 150,
        numProcesses: 1,
        options: ShardingOptions(timeoutSpawn: false, redirectOutput: false),
      );

      await manager.start();

      expect(manager.processes.first.stdout.transform(utf8.decoder), emits(equals('150\n')));
    });

    test('shardIds', () async {
      IShardingManager manager = IShardingManager.create(
        _configData,
        totalShards: 150,
        numProcesses: 1,
        options: ShardingOptions(timeoutSpawn: false, redirectOutput: false),
      );

      await manager.start();

      expect(manager.processes.first.stdout.transform(utf8.decoder).skip(1), emits(equals(List.generate(150, (id) => id).toString() + '\n')));
    });
  });
}
