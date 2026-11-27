# EllesmereUI Adventure Tracker

Adventure Tracker is an EllesmereUI companion addon for World of Warcraft:
Forever. It answers two questions in one small window:

- What important preparation am I missing before I head out?
- What useful progress can I make in the zone I am already in?

## First preview

Version 0.1.20 establishes the addon structure and a playable first pass:

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
  maximum height;
- one combined Tracker settings page with customizable pane padding, independent
  pane/section/entry backgrounds, font face, outline, text sizes and text colors,
  plus border and title-bar presentation;
- a Quest Tracker-style minimize glyph and a Damage Meter-style lock control;
- a compact readiness icon strip with green, amber, red, gray, violet and blue
  states;
- live Camp Benefits, Well-Rested, food, class-buff and weapon-enhancement
  checks;
- combat-safe state retention so restricted aura reads do not become false
  missing-buff warnings;
- a role-aware Well Fed recommendation that prefers suitable food already in
  the bags, can eat that exact item when clicked, then falls back to a supported
  learned Cooking recipe;
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
  summary that expands or collapses the individual list and trainer details on
  skill hover;
- a one-time yellow breathing alert when a collapsed class-training list gains
  newly available skills, cleared as soon as the list is opened;
- configurable red breathing alerts for missing long-lived role preparation,
  including party coverage for appropriate class buffs;
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
  Readiness, Legacy and Professions submenu groups.

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
- `Data/GatheringCatalog.lua` — generated per-zone node types and known-position counts
- `Data/CookingFoods.lua` — Cooking recipe/output discovery seeds
- `Tracker.lua` — floating tracker window
- `Options.lua` — supported EllesmereUI plugin settings integration

The addon uses EllesmereUI's public plugin and skinning APIs. It does not edit
or hook EllesmereUI vendor files.

Third-party data sources and retained notices are recorded in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
