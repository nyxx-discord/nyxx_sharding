## 2.0.0-dev.1
__New features__
- Added an `autoScale` option that will automatically scale youru processes & shards according to youur bot's size in realtime.

__Bug fixes__
- Fixed fetching guild count being inconsistent

## 2.0.0-dev.0.2
__Bug fixes__:
- Fixed an issue with ratelimiting when fetching guild counts.

## 2.0.0-dev.0.1
__Bug fixes__:
- Fixed an issue with query parameter formatting preventing guild counts from being fetched.

## 2.0.0-dev.0
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
