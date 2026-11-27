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
- Recipe teaching-item relationships and product level gates are generated
  offline from build-stamped Blizzard `ItemEffect`, `ItemXItemEffect` and
  `ItemSparse` client tables. No runtime worker scans QuestieDB's item records.
  QuestieDB is queried only for the small mapped set whose live acquisition
  sources are being evaluated.
- Global item- and spell-data events are ignored unless Adventure Tracker
  requested that exact record. Requests are coalesced and record which provider
  needs the result, so unrelated cache activity cannot start provider rebuilds.
- A failed data load does not invalidate its provider and cannot be requested
  again for five minutes. This backoff is timestamp-based and owns no timer.
- Broad discovery passes must use instant or generated facts. Bag food checks
  reject non-food item classes before cached tooltip evaluation, and worldwide
  crafted-upgrade scoring never requests missing product data.

## Development profiling

Profiling is disabled and silent by default. Use `/at profile` to enable it,
reproduce an interaction, then use `/at profile report` to print last, average
and maximum milliseconds for provider builds, snapshots, renders, zone quest
composition and recipe-index batches. Use `/at profile` again to disable it.

## Validation matrix

Test after both a full client restart and `/reload`:

- continuous movement in the open world for at least 30 seconds;
- stopped/idle for at least 30 seconds after reload, including the former
  ten-second recipe-index boundary;
- party dungeon and raid entry, boss combat and completion;
- taxi travel, including an early landing when available;
- quest acceptance, removal and turn-in across multiple visited zones;
- leveling, profession skill changes, trainer windows and recipe windows;
- combat entry/exit, group changes and frequent aura updates.

The expected result is no half-second render cadence, no QuestieDB provider
build caused by a timer tick or unrelated cache event, and no permanently
running Adventure Tracker worker. Session, instance, boss and flight tickers
may update their already-visible text or progress only.
