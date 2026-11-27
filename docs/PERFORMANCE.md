# Performance architecture

Adventure Tracker treats QuestieDB as an event-driven data provider. QuestieDB
does not poll on Adventure Tracker's behalf; the addon must avoid turning
presentation timers into repeated database queries.

## Runtime rules

- Settings are scoped by effect. Lock and position state never render or dirty
  providers; presentation state renders cached results; feature state dirties
  only its owning provider. A generic option must not default to rebuilding all
  data providers merely because its value changed.
- Aura events must be classified from their delta before invalidation. Generic
  eating, drinking and unrelated effects do no provider or pane work; player
  flag changes update only context text. Bag signatures exclude food/drink
  items already classified as irrelevant to combat-food recommendations and
  rescan only bags marked dirty by `BAG_UPDATE`.
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
- `BAG_UPDATE_DELAYED` first compares a compact signature containing Food &
  Drink stacks and reagents for the selected profession routes. An unrelated
  item change stops there without invalidating a provider or rendering the pane.
- A relevant bag change rebuilds only readiness or the active profession route,
  according to which signature changed. Stable profession rows retain trainer,
  gathering, gear, catalogue and source results. Quest Progress is never
  invalidated by a generic bag event.
- Learned profession schematics are a versioned, per-character SavedVariables
  snapshot. `TRADE_SKILL_SHOW` and list-update events reuse it unless a learned-
  spell event marked it dirty; window filters never replace it with a subset.
- Class and profession trainer snapshots carry versioned service signatures.
  An unchanged trainer skips tooltip reads and does not invalidate a provider.
  Trainer close never causes a refresh, and trainer show has one deferred scan
  instead of an immediate scan followed by a duplicate deferred scan.
- The instance provider does not listen directly to global item-data or
  profession-window events. Requested item completions remain routed through
  the central per-item consumer registry.

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
