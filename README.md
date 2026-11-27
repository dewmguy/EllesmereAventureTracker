# EllesmereUI Adventure Tracker

Adventure Tracker is an EllesmereUI companion addon for World of Warcraft:
Forever. It answers two questions in one small window:

- What important preparation am I missing before I head out?
- What useful progress can I make in the zone I am already in?

## First preview

Version 0.3.6 establishes the addon structure and a playable first pass:

- a draggable, lockable and collapsible window that can be repositioned from
  its background, content, section headers, status icons or recommendation rows,
  plus an EllesmereUI Unlock Mode mover for precise anchoring and width;
- a context line showing zone, specialization, class and selected activity role;
- custom, player-class or EllesmereUI-accent coloring for the title and collapse
  glyph, which aligns with the zone/class context line when the title bar is
  hidden without reserving an empty title row;
- Quest Tracker-style per-character collapse controls on every visible section,
  with important breathing alerts carried onto collapsed section headers and
  the overall collapse control, plus a soft synchronized background tint on
  alerted section headers and recommendation entries;
- mouse-wheel scrolling when the tracker contents exceed its screen-relative
  maximum height, with optional full-viewport sizing and explicit upward or
  downward pane growth; context/status lines and readiness icons remain fixed
  while recommendation sections scroll underneath;
- one combined Tracker settings page with customizable pane padding, independent
  pane/section/entry backgrounds, font face, outline and text sizes, plus Class,
  Accent and Custom color modes for every tracker text category and a main-pane
  strata picker for controlling its position relative to other UI windows;
- a Quest Tracker-style minimize glyph and a Damage Meter-style lock control;
- a compact readiness icon strip with green, amber, red, gray, violet and blue
  states;
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
  expose a solo specialization role;
- a separate World Buffs submenu and tracker section for active timers and
  acquisition hints, with the faction Rend buff retained while missing and
  other missing buffs opt-in;
- unspent Legacy point reminders and a current-zone provider boundary;
- an unspent talent reminder that can replace Blizzard's callout to the hidden
  Player Spells microbutton and breathes yellow until every point is spent;
- a per-character class-trainer scan that lists every currently available
  skill, its price and the total cost to learn them all, with a clickable
  summary that expands or collapses the individual list, the full native
  trainer tooltip while the trainer is open, and a cached skill description
  afterward;
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
- Encounter Journal upgrade suggestions filtered for the current class and
  specialization and then limited to drops whose item level beats the relevant
  equipped slot;
- a compact in-tracker flight-master timer with destination, configurable time
  fields and progress, plus its own learned route history independent of the
  native and Custom Tweaks flight timers;
- independent flight bar texture, fill, background, border, font, outline,
  text-size, text-color and icon controls;
- contextual In Flight, In Combat, Resting, Mounted, instance, life and
  presence statuses beside the zone/class context;
- a live session duration in the main status row without a leading zero-hour
  field, with verbose current-session and character `/played` details on hover;
- carried gold with denomination icons and a hover summary of session changes,
  the available lifetime statistic, known other-character balances and the
  Warband bank through EllesmereUI's shared ledger;
- profession Legacy checkpoints kept in the Legacy section;
- one section per profession, with current skill, the next trainable rank and a
  verified trainer or acquisition destination;
- collapsible per-profession lists of currently available unlearned trainer
  recipes, their individual prices and the total cost to learn them all;
- learned-recipe scanning that recommends a dependable next skill-up, turns
  Mining materials into a concrete ore/bar plan, and favors materials available
  in the current zone;
- a learned crafted-gear recommendation that prefers a class-usable upgrade
  over the currently equipped item;
- coordinate-free gathering and Fishing summaries without repeating the zone
  name in each row;
- a researched zone-gathering design for ranked herbs and ore, observed
  skinning materials, available fish and recommended effective Fishing skill;
- an `Adventure Tracker` sidebar section in EllesmereUI with Tracker,
  Readiness, World Buffs, Travel & Status, Instances, Legacy and Professions
  submenu groups.

Current-zone Legacy objectives and exact profession node/mob recommendations are
hidden until their providers can return verified actions. The researched source,
UX and implementation decisions are recorded in
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
- `Professions.lua` — rank goals, learned-recipe plans, gear and local resources
- `Instances.lua` — run and boss timers, QuestieDB quest suggestions and
  Encounter Journal upgrade drops
- `Flight.lua` — independent in-tracker flight timing, route learning and
  progress-bar data
- `Status.lua` — contextual activity states, session duration and `/played`
- `Data/GatheringCatalog.lua` — generated per-zone node types and known-position counts
- `Data/CookingFoods.lua` — Cooking recipe/output discovery seeds
- `Tracker.lua` — floating tracker window
- `Options.lua` — supported EllesmereUI plugin settings integration
- `docs/API_RESTRICTIONS.md` — protected-action and combat-data rules

The addon uses EllesmereUI's public plugin and skinning APIs. It does not edit
or hook EllesmereUI vendor files.

Third-party data sources and retained notices are recorded in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Protected actions, combat-sensitive reads and their supported implementation
patterns are recorded in [`docs/API_RESTRICTIONS.md`](docs/API_RESTRICTIONS.md).
