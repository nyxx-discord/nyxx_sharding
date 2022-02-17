enum EventType {
  sendManager,
  broadcast,
  getData,
  sendData,
}

enum DataRequestType {
  cachedChannels,
  cachedGuilds,
  cachedUsers,
  cachedMembers,
  currentRss,
  maxxRss,
}

abstract class IDataProvider {
  /// Fetches the cached channels count from all processes.
  ///
  /// Each element in the list is the result of querying a single process. The list is unordered, and might not contain information from all processes if
  /// the request times out (5s).
  Future<List<int>> getCachedChannels();

  /// Fetches the cached guilds count from all processes.
  ///
  /// Each element in the list is the result of querying a single process. The list is unordered, and might not contain information from all processes if
  /// the request times out (5s).
  Future<List<int>> getCachedGuilds();

  /// Fetches the cached users count from all processes.
  ///
  /// Each element in the list is the result of querying a single process. The list is unordered, and might not contain information from all processes if
  /// the request times out (5s).
  Future<List<int>> getCachedUsers();

  /// Fetches the cached members count from all processes.
  ///
  /// Each element in the list is the result of querying a single process. The list is unordered, and might not contain information from all processes if
  /// the request times out (5s).
  Future<List<int>> getCachedMembers();

  /// Fetches the current RSS from all processes.
  ///
  /// Each element in the list is the result of querying a single process. The list is unordered, and might not contain information from all processes if
  /// the request times out (5s).
  Future<List<int>> getCurrentRss();

  /// Fetches the maximum RSS count from all processes.
  ///
  /// Each element in the list is the result of querying a single process. The list is unordered, and might not contain information from all processes if
  /// the request times out (5s).
  Future<List<int>> getMaxRss();
}
