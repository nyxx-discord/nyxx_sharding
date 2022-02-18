import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_sharding/src/communication/common.dart';
import 'package:nyxx_sharding/src/exceptions.dart';
import 'package:nyxx_sharding/src/sharding_manager.dart';

/// A plugin that can be used in spawned processes to allow communication between processes.
abstract class IShardingPlugin implements BasePlugin, IDataProvider {
  /// A stream of events received on this process.
  ///
  /// Events can be sent to other processes with [sendManager] or [broadcast].
  Stream<String> get events;

  /// Sends a message to the manager process.
  ///
  /// The message will be added to the [IShardingManager.events] stream.
  void sendManager(String message);

  /// Sends a message to all other child processes, excluding this one.
  ///
  /// The message will be added to the [events] stream in other processes.
  void broadcast(String message);

  /// Create a new instance of the sharding plugin.
  factory IShardingPlugin() = ShardingPlugin;
}

class ShardingPlugin implements IShardingPlugin {
  INyxx? client;
  WebSocket? connection;

  final Completer<void> connectedCompleter = Completer();
  Future<void> get connected => connectedCompleter.future;

  final Map<int, Completer<List<dynamic>>> pendingDataRequests = {};

  final Logger _logger = Logger('Sharding Client');

  final StreamController<String> eventsController = StreamController.broadcast();
  @override
  Stream<String> get events => eventsController.stream;

  late int seqNum = Random().nextInt(1000);

  @override
  Future<void> onRegister(INyxx nyxx, Logger logger) async {
    if (!Platform.environment.containsKey('NYXX_SHARDING_PORT')) {
      throw ShardingError('Missing NYXX_SHARDING_PORT variable');
    }

    client = nyxx;

    int port = int.parse(Platform.environment['NYXX_SHARDING_PORT']!);

    String url = 'ws://${InternetAddress.loopbackIPv4.address}:$port';

    _logger.fine('Connecting to sharding server at $url...');

    connection = await WebSocket.connect(url);

    _logger.fine('Connected to sharding server!');

    connection!.cast<String>().listen(handleEvent);

    connectedCompleter.complete();
  }

  void send(EventType type, int id, dynamic data) async {
    if (connection == null) {
      await connected;
    }

    _logger.finer('Sending $data to manager with id $id and type $type');

    connection!.add(jsonEncode({
      'type': type.index,
      'data': data,
      'id': id,
    }));
  }

  void handleEvent(String rawEvent) {
    Map<String, dynamic> event = jsonDecode(rawEvent) as Map<String, dynamic>;

    dynamic data = event['data'];
    int id = event['id'] as int;
    EventType type = EventType.values[event['type'] as int];

    _logger.finer('Got message $data with id $id and type $type');

    switch (type) {
      case EventType.sendManager:
        assert(false, 'unreachable');
        break;

      case EventType.broadcast:
        eventsController.add(data as String);
        break;

      case EventType.sendData:
        if (pendingDataRequests.containsKey(id)) {
          pendingDataRequests[id]!.complete(data as List<dynamic>);
          pendingDataRequests.remove(id);
        }
        break;

      case EventType.getData:
        if (client != null) {
          send(EventType.sendData, id, getDataFromType(DataRequestType.values[data['type'] as int]));
        }
    }
  }

  dynamic getDataFromType(DataRequestType type) {
    switch (type) {
      case DataRequestType.cachedChannels:
        return client!.channels.length;
      case DataRequestType.cachedGuilds:
        return client!.guilds.length;
      case DataRequestType.cachedUsers:
        return client!.users.length;
      case DataRequestType.cachedMembers:
        return client!.guilds.values.fold<int>(0, (acc, guild) => acc + guild.members.length);
      case DataRequestType.currentRss:
        return ProcessInfo.currentRss;
      case DataRequestType.maxxRss:
        return ProcessInfo.maxRss;
    }
  }

  @override
  void broadcast(String message) => send(EventType.broadcast, seqNum++, message);

  @override
  void sendManager(String message) => send(EventType.sendManager, seqNum++, message);

  Future<List<dynamic>> getData(DataRequestType type) {
    int id = seqNum++;

    send(EventType.getData, id, {
      'type': type.index,
    });

    Completer<List<dynamic>> completer = Completer();
    pendingDataRequests[id] = completer;

    return completer.future;
  }

  @override
  Future<List<int>> getCachedChannels() async => (await getData(DataRequestType.cachedChannels)).cast<int>();

  @override
  Future<List<int>> getCachedGuilds() async => (await getData(DataRequestType.cachedGuilds)).cast<int>();

  @override
  Future<List<int>> getCachedMembers() async => (await getData(DataRequestType.cachedMembers)).cast<int>();

  @override
  Future<List<int>> getCachedUsers() async => (await getData(DataRequestType.cachedUsers)).cast<int>();

  @override
  Future<List<int>> getCurrentRss() async => (await getData(DataRequestType.currentRss)).cast<int>();

  @override
  Future<List<int>> getMaxRss() async => (await getData(DataRequestType.maxxRss)).cast<int>();

  @override
  void onBotStart(INyxx nyxx, Logger logger) {}

  @override
  void onBotStop(INyxx nyxx, Logger logger) {}
}
