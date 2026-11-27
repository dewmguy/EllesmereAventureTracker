# Performance architecture

Adventure Tracker treats QuestieDB as an event-driven data provider. QuestieDB
does not poll on Adventure Tracker's behalf; the addon must avoid turning
presentation timers into repeated database queries.

## Runtime rules

- Providers cache their last result and rebuild only after an explicit relevant
  invalidation. A cached out-of-combat result is retained when combat data is
  restricted.
- Instance, boss and flight timers update only the already-visible row once per
  second. A timer tick never calls `BuildSnapshot`, rebuilds layout or queries
  QuestieDB.
- Zone recommendations are cached by character, area, player level,
  quest-state revision and XP multiplier. Quest-log, level, spell,
  specialization, profession and reputation events invalidate eligibility.
- The runtime recipe-source reverse index is a compatibility path for the
  installed QuestieDB correction layer. It runs only when the recipe-source
  feature is enabled, pauses during movement/combat/taxi/encounters, and has a
  0.35 ms idle-frame budget. It performs one provider invalidation when done.

An offline-generated reverse index remains the preferred durable replacement
once its build process can preserve the installed QuestieDB version's composed
corrections without copying unsupported database content.

## Development profiling

Profiling is disabled and silent by default. Use `/at profile` to enable it,
reproduce an interaction, then use `/at profile report` to print last, average
and maximum milliseconds for provider builds, snapshots, renders, zone quest
composition and recipe-index batches. Use `/at profile` again to disable it.

## Validation matrix

Test after both a full client restart and `/reload`:

- continuous movement in the open world for at least 30 seconds;
- stopped/idle until the recipe-source index completes;
- party dungeon and raid entry, boss combat and completion;
- taxi travel, including an early landing when available;
- quest acceptance, removal and turn-in across multiple visited zones;
- leveling, profession skill changes, trainer windows and recipe windows;
- combat entry/exit, group changes and frequent aura updates.

The expected result is no half-second render cadence, no QuestieDB provider
build caused by a timer tick, recipe-index batches at or below their 0.35 ms
budget apart from a single indivisible database getter, and no worker left
running after indexing completes.
