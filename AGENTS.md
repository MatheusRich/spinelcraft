# Notes for agents

Spinelcraft is pre-alpha. No player, save or tool depends on old behavior yet.

- Do not keep compatibility with old saves, old names or old behavior. When a change makes old code obsolete, remove it.
- Do not add importers, fallbacks or guards for data from an earlier version of the game.
- When the save format changes, change the version in the first line of `world.sav` (now `SPINELCRAFT8`). Then an old save does not load, and the game moves it to `world-bad.sav` and starts a new world. That is all the old save gets.
- Remove code that nothing calls.
