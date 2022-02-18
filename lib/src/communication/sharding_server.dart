import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:nyxx_sharding/src/communication/common.dart';
import 'package:nyxx_sharding/src/sharding_manager.dart';

mixin ShardingServer implements IShardingManager, IDataProvider {
  HttpServer? server;
  final List<WebSocket> connections = [];

  int get port => server!.port;

  late int seqNum = Random().nextInt(1000);

  Map<int, StreamController<dynamic>> pendingDataRequests = {};

  final StreamController<String> eventController = StreamController.broadcast();
  @override
  Stream<String> get events => eventController.stream;

  Future<void> startServer() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server!.transform(WebSocketTransformer()).listen((socket) {
      connections.add(socket);

      StreamSubscription<String> subscription = socket.cast<String>().listen((event) => handleEvent(event, socket));

      socket.done.then((_) {
        subscription.cancel();
        connections.remove(socket);
      });
    });
  }

  void send(WebSocket socket, EventType type, int id, dynamic data) {
    socket.add(jsonEncode({
      'type': type.index,
      'data': data,
      'id': id,
    }));
  }

  void handleEvent(String rawEvent, WebSocket socket) async {
    Map<String, dynamic> event = jsonDecode(rawEvent) as Map<String, dynamic>;

    dynamic data = event['data'];
    int id = event['id'] as int;
    EventType type = EventType.values[event['type'] as int];

    switch (type) {
      case EventType.sendManager:
        eventController.add(data as String);
        break;

      case EventType.broadcast:
        for (final connection in connections) {
          if (connection == socket) {
            continue;
          }

          send(connection, type, id, data);
        }
        break;

      case EventType.getData:
        send(socket, EventType.sendData, id, await getData(DataRequestType.values[data['type'] as int]));
        break;

      case EventType.sendData:
        if (pendingDataRequests.containsKey(id)) {
          pendingDataRequests[id]!.add(data);
        }
        break;
    }
  }

  @override
  void broadcast(String message) {
    for (final connection in connections) {
      send(connection, EventType.broadcast, seqNum++, message);
    }
  }

  Future<List<dynamic>> getData(DataRequestType type) async {
    StreamController<dynamic> controller = StreamController();

    int id = seqNum++;

    pendingDataRequests[id] = controller;

    Completer<void> completer = Completer();

    List<dynamic> result = [];

    controller.stream.listen((data) {
      result.add(data);

      if (result.length == connections.length && !completer.isCompleted) {
        completer.complete();
      }
    });

    for (final connection in connections) {
      send(connection, EventType.getData, id, {
        'type': type.index,
      });
    }

    Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;

    return result;
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
}
