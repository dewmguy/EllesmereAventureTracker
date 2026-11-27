# EllesmereUI Adventure Tracker

Adventure Tracker is an EllesmereUI companion addon for World of Warcraft:
Forever. It answers two questions in one small window:

- What important preparation am I missing before I head out?
- What useful progress can I make in the zone I am already in?

## First preview

Version 0.8.6 establishes the addon structure and a playable first pass:

- a draggable, lockable and collapsible window that keeps its enabled title,
  status and readiness-buff rows visible while collapsed and can be repositioned
  from its background, content, section headers, status icons or recommendation
  rows, plus an EllesmereUI Unlock Mode mover for precise anchoring and width;
- a left-, center- or right-aligned context and status line showing zone,
  character level, and the dominant Forever talent tree and class as a compact
  `27 Prot Paladin`-style segment, plus live `Solo`, `Party` or `Raid` group
  context and a specifically selected role such as Tank or Healer;
- custom, player-class or EllesmereUI-accent coloring for the title and collapse
  glyph, which aligns with the zone/class context line when the title bar is
  hidden without reserving an empty title row;
- Quest Tracker-style per-character collapse controls on every visible section,
  with important breathing alerts carried onto collapsed section headers and
  the overall collapse control, plus a soft synchronized background tint on
  alerted section headers and recommendation entries; child entries inside
  expandable skill and recipe lists are inset as a visually distinct sub-list;
- mouse-wheel scrolling when the tracker contents exceed its screen-relative
  maximum height, with optional full-viewport sizing and explicit upward or
  downward pane growth; a vertical EllesmereUI anchor remains authoritative and
  uses the full safe span between its fixed edge and the viewport, while
  context/status lines and readiness icons remain fixed above the scrolling
  recommendation sections; an optional custom limit can cap total pane height
  by viewport percentage or absolute UI pixels without crossing that safe span;
- one combined Tracker settings page with customizable pane padding, independent
  pane/section/entry backgrounds, font face, outline and text sizes, plus compact
  Class, Accent and Custom color swatches for every tracker text category and a
  main-pane strata picker for controlling its position relative to other UI windows;
- a Quest Tracker-style minimize glyph and a Damage Meter-style lock control;
- a compact readiness icon strip with green, amber, red, gray, violet and blue
  states, customizable sizing, wrapping, spacing, border style, per-state border
  colors and independently positioned stack text;
- live Camp Benefits, Well-Rested, food, class-buff and weapon-enhancement
  checks, with expiring-soon states kept in the icon strip instead of duplicated
  as entries under Missing Buffs;
- combat-safe state retention so restricted aura reads do not become false
  missing-buff warnings;
- a role-aware Well Fed recommendation that prefers suitable food already in
  the bags, can eat that exact item through a secure out-of-combat hardware
  click, then falls back to a supported learned Cooking recipe;
- Camp Benefits equivalence for Incense Candle/Intellect and First Aid
  Kit/Fortitude;
- an explicit per-character activity role because Forever does not reliably
  expose a solo specialization role; this drives recommendations without
  replacing the live group-context label and appears beside it when specific;
- a separate World Buffs submenu and tracker section for active timers and
  acquisition hints, with the faction Rend buff retained while missing and
  other missing buffs opt-in;
- unspent Legacy point reminders, profession checkpoints and live point-bearing
  Legacy Challenge recommendations ranked for the current zone, instance,
  level, class, professions and existing progress;
- an unspent talent reminder that can replace Blizzard's callout to the hidden
  Player Spells microbutton and breathes yellow until every point is spent;
- a bundled, attributed Forever class-training catalog that lists every
  currently available skill, its price and the total cost to learn them all
  without requiring a trainer visit, with a clickable summary, indented skill
  rows and native spell tooltips; live trainer visits quietly refine matching
  prices without becoming setup objectives;
- a one-time yellow breathing alert when a collapsed class-training list gains
  newly available skills, cleared as soon as the list is opened;
- configurable red breathing alerts for missing long-lived role preparation,
  including party coverage for appropriate class buffs;
- class-buff icons that follow the currently active spell, remember the last
  active choice per character and role, and fall back to a suitable known spell;
- real spell tooltips and secure out-of-combat self-casting when a class-buff
  readiness icon is clicked;
- an instance run timer that begins on entry and records per-character,
  per-difficulty personal bests when the final boss or dungeon-completion event
  is detected;
- live boss encounter timers with their own per-character personal bests, kept
  visible during boss combat even when the general Hide in Combat option is on;
- compact, collapsible instance-quest suggestions from an optional QuestieDB
  runtime provider, limited to eligible quests that are incomplete and absent
  from the quest log, with only a quest giver or starting item and its dropping
  mobs shown;
- a Quest Progress section with one expandable summary per zone the character
  has actually entered outside flight-path travel, combined player-level XP
  and coin rewards, and conservative QuestieDB filtering for level, class,
  race, profession and chain availability without exposing locations, routes
  or objectives; recommendations remain within five levels of the character;
- event-invalidated provider and composed zone-result caches that keep
  QuestieDB lookups out of timer, aura, group and unrelated presentation
  refreshes;
- red, breathing future quest-material warnings when a newly vendored item is
  still needed by a meaningful unaccepted quest in a visited zone, with direct
  merchant buyback while available and an explicit per-item dismiss button;
- Encounter Journal upgrade suggestions filtered for the current class and
  specialization and then limited to drops whose item level beats the relevant
  equipped slot;
- a compact in-tracker flight-master timer with destination, configurable time
  fields and progress, plus its own learned route history independent of the
  native and Custom Tweaks flight timers;
- lightweight one-second instance, boss and flight display updates that change
  only their existing visible row text/progress instead of rebuilding the pane;
- a build-stamped Blizzard client-data recipe-item index, generated before
  packaging, that preserves live QuestieDB vendor/drop/source recommendations
  without scanning QuestieDB's entire item database after login or reload;
- request-scoped item- and spell-data callbacks so cache activity from other
  addons cannot invalidate Adventure Tracker providers;
- independent flight bar texture, fill, background, border, font, outline,
  text-size, text-color and icon controls;
- contextual In Flight, In Combat, Resting, Mounted, instance, life and
  presence statuses beside the zone/class context;
- a live session duration in the main status row without a leading zero-hour
  field, with verbose current-session and character `/played` details on hover;
- carried gold with denomination icons and a hover summary of session changes,
  the available lifetime statistic, known other-character balances and the
  Warband bank through EllesmereUI's shared ledger;
- profession Legacy checkpoints kept in the Legacy Progress section;
- one section per profession, with current skill, the next trainable rank and a
  verified trainer or acquisition destination;
- collapsible per-profession lists of currently available unlearned trainer
  recipes, their individual prices and the total cost to learn them all from a
  permanent Forever catalog, without requiring a trainer scan;
- an inventory-aware profession route that prefers orange/guaranteed crafts,
  estimates crafts to the next useful skill target, recommends the next trainer
  recipe when needed and turns missing materials into a concrete local mob,
  object, vendor or paired-Mining action;
- a narrow useful-bulk exception for reusable components such as grinding
  stones when the character already carries enough material for a worthwhile
  batch, instead of blindly discarding every yellow or green option;
- optional missing-material cost scoring that automatically prefers
  TradeSkillMaster when its price API is available and falls back to
  Auctionator, without making either addon mandatory;
- an attributed, build-stamped catalogue of 2,090 Forever recipes with
  QuestieDB vendor, reasonable-level mob-drop, object-loot and currently
  eligible quest-reward overlays;
- a best attainable unlearned recipe recommendation plus an expandable
  per-character worldwide list, with source details but no coordinates;
- cross-profession reagent goals when one opened profession can craft a
  material needed by another opened profession's current skill-up recipe;
- a learned crafted-gear recommendation that prefers a class-usable upgrade
  over the currently equipped item, plus attainable unlearned crafted upgrades;
- coordinate-free gathering and Fishing summaries without repeating the zone
  name in each row;
- a current-zone effective Fishing target based on OneCast's documented
  Forever measurements or clearly labelled Classic baselines, with the live
  profession bonus and remaining skill gap shown;
- local account-wide fishing and skinning observations ranked by item count,
  with explicit per-zone catch/window sample sizes, no uploads and a dedicated
  clear-history control;
- an `Adventure Tracker` sidebar section in EllesmereUI with Tracker,
  Readiness, World Buffs, Travel & Status, Instances, Quests, Legacy and Professions
  submenu groups.

Legacy, quest and recipe recommendations remain hidden when their live
providers cannot verify an action. The researched source, UX and implementation
decisions are recorded in
[`docs/RESEARCH_AND_IMPLEMENTATION_PLAN.md`](docs/RESEARCH_AND_IMPLEMENTATION_PLAN.md).
The rules for reusing public datasets without hiding their provenance are in
[`docs/DATA_SOURCES_AND_LICENSES.md`](docs/DATA_SOURCES_AND_LICENSES.md).

## Install

Place the `EllesmereUIAdventureTracker` folder in:

```text
World of Warcraft/_forever_/Interface/AddOns/
```

EllesmereUI is required. Restart WoW or reload the UI, then open the normal
EllesmereUI settings panel. The sidebar section is named `Adventure Tracker`.

## Commands

```text
/at                 Toggle the tracker
/at show            Show the tracker
/at hide            Hide the tracker
/at lock            Lock its position
/at unlock          Unlock its position
/at reset           Reset position, width and scale
/at options         Open its EllesmereUI settings
```

Long forms `/advtracker` and `/adventuretracker` are also available.

## Project layout

- `Core.lua` — saved settings, provider registry and slash commands
- `Reminders.lua` — talent and class-training reminders plus scoped
  Blizzard-callout suppression
- `Readiness.lua` — preparation and buff-family interpretation
- `WorldBuffs.lua` — world-buff presence, timers and acquisition sources
- `Legacy.lua` — Legacy points and current-zone provider
- `Prices.lua` — optional TradeSkillMaster and Auctionator market adapters
- `Professions.lua` — rank goals, learned-recipe plans, gear and local resources
- `Instances.lua` — run and boss timers, QuestieDB quest suggestions and
  Encounter Journal upgrade drops
- `Quests.lua` — visited-zone quest progress, aggregate rewards and future
  quest-material merchant warnings without route guidance
- `Flight.lua` — independent in-tracker flight timing, route learning and
  progress-bar data
- `Status.lua` — contextual activity states, session duration and `/played`
- `Media/Currency/` — bundled denomination icons independent of client artwork
- `tools/Generate-CurrencyIcons.ps1` — deterministic source generator for those
  transparent power-of-two PNG assets
- `Data/GatheringCatalog.lua` — generated per-zone node types and known-position counts
- `Data/CookingFoods.lua` — Cooking recipe/output discovery seeds
- `Data/ClassTraining/` — attributed static Forever class-trainer catalog
- `Data/RecipeCatalog.lua` — attributed build-stamped recipe and reagent facts
- `Data/ProfessionTraining.lua` — attributed permanent learn-at, source and
  trainer-price facts for every Forever profession
- `RecipeCatalog.lua` — learned-state, source, synergy and upgrade evaluation
- `ProfessionRoutes.lua` — level-, inventory-, price- and zone-aware profession
  progression routes
- `Tracker.lua` — floating tracker window
- `Options.lua` — supported EllesmereUI plugin settings integration
- `docs/API_RESTRICTIONS.md` — protected-action and combat-data rules
- `docs/PERFORMANCE.md` — QuestieDB integration performance design and test plan

The addon uses EllesmereUI's public plugin and skinning APIs. It does not edit
or hook EllesmereUI vendor files.

Third-party data sources and retained notices are recorded in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Protected actions, combat-sensitive reads and their supported implementation
patterns are recorded in [`docs/API_RESTRICTIONS.md`](docs/API_RESTRICTIONS.md).
