## 2.0.0
__Breaking changes__:
- Added a new `port` parameter to `ProcessData.spawn`.

__New features__:
- Added a CLI for easier usage of nyxx_sharding. Run `dart pub global activate nyxx_sharding` to enable the CLI and then `nyxx-sharding --help` for more.
- Added new `maxGuildsPerShard` and `maxGuildsPerProcess` options for spawning processes.
- Added methods for fetching data across processes. See the docs for `IShardingManager` and `IShardingPlugin` for more.

__Bug fixes__:
- Spawned processes no longer prevent the parent from exiting.

## 1.0.0

- Initial version.
