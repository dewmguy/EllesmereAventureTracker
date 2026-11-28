# Performance architecture

Adventure Tracker treats QuestieDB as an event-driven data provider. QuestieDB
does not poll on Adventure Tracker's behalf; the addon must avoid turning
presentation timers into repeated database queries.

## Runtime rules

- All variable-size runtime work shares a configurable 5–25% of the current
  frame time (10% by default), clamped between 0.35 and 4.00 ms. Providers,
  Questie indexing, inventory signatures, trainer/profession capture, large
  sorts and pane rendering must call `ns.YieldForBudget()` at safe record or UI
  element boundaries. They resume on a later frame through the central keyed
  scheduler; no module owns a competing permanent worker.
- Provider builds and rendering are separate phases. An invalidation queues a
  provider build, a successful build atomically commits `lastResult`, and
  `BuildSnapshot` composes only committed cache entries. Rendering must never
  call `provider.build` or wait for a provider to finish.
- Derived state used by another worker follows the same commit boundary. The
  profession provider stages selected routes and their reagent signature while
  building; bag-signature work sees only the last committed route set. A stale
  or failed provider generation discards its staging table.
- A provider may publish an immutable lightweight progress snapshot while a
  slower enrichment continues. Profession rank, trainer and gathering rows use
  this path so frame budgeting never makes the whole profession area appear
  absent; the provider's final generation check still controls the full result.
- The profession provider exposes loading, enrichment and failure state in a
  synthetic summary row. This row never starts data work; it reads provider
  state only. `/at providers` prints generations, reasons, section counts and
  stored errors, and the optional setting keeps the row visible when idle.
- Work keys coalesce event bursts into the latest pending rerun. Structural
  result changes queue one time-sliced pane layout; results with identical
  section, status and row geometry patch their visible keyed elements in place.
  Pooled elements are hidden only after a replacement layout is complete.
- Combat-restricted tasks retain their queued state but the scheduler sleeps
  when every task is gated. `PLAYER_REGEN_ENABLED` wakes the queue; it is not
  polled every frame during combat.

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
- QuestieDB quest records are indexed by area in one cold, time-sliced pass and
  the finished index is published atomically. Visited zones and instance quest
  suggestions share that index instead of each scanning the complete quest
  database.
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
- Well Fed evaluation does not call `GetAllRecipeIDs`. It combines the shipped
  Cooking food catalogue with the durable learned-recipe cache captured by the
  budgeted profession-window scanner.

## Development profiling

Profiling is disabled and silent by default. Use `/at profile` to enable it,
reproduce an interaction, then use `/at profile report` to print last, average
and maximum active milliseconds for each budgeted task. Providers appear as
`provider:<id>`; layout is `Render`; inventory, trainer and profession capture
have their own names. A `runtime-overrun:<task>` entry means one uninterrupted
resume exceeded the current dynamic frame target and identifies the remaining atomic hot
path. Use `/at profile` again to disable profiling.

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
- repeated looting, eating, drinking, lock toggles and bag rearrangement while
  moving, including the first cold Questie-area build after reload.

The expected result is no visible frame spike, no half-second render cadence,
no QuestieDB provider build caused by a timer tick or unrelated cache event,
and no permanently running Adventure Tracker worker. Session, instance, boss
and flight tickers may update their already-visible text or progress only.
