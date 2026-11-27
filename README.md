# EllesmereUI Adventure Tracker

Adventure Tracker is an EllesmereUI companion addon for World of Warcraft:
Forever. It answers two questions in one small window:

- What important preparation am I missing before I head out?
- What useful progress can I make in the zone I am already in?

## First preview

Version 0.1.2 establishes the addon structure and a playable first pass:

- a draggable, lockable and collapsible EllesmereUI-skinned window;
- a compact readiness icon strip with green, amber, red, gray, violet and blue
  states;
- live Camp Benefits, Well-Rested, food, class-buff and weapon-enhancement
  checks;
- Camp Benefits equivalence for Incense Candle/Intellect and First Aid
  Kit/Fortitude;
- an explicit per-character activity role because Forever does not reliably
  expose a solo specialization role;
- a separate World Buffs submenu and tracker section for active timers and
  opt-in missing-buff acquisition sources;
- unspent Legacy point reminders and a current-zone provider boundary;
- profession Legacy checkpoints, trainer-cap reminders and honest contextual
  gathering hints;
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
/at reset           Reset position, size, scale and opacity
/at options         Open its EllesmereUI settings
```

Long forms `/advtracker` and `/adventuretracker` are also available.

## Project layout

- `Core.lua` — saved settings, provider registry and slash commands
- `Readiness.lua` — preparation and buff-family interpretation
- `WorldBuffs.lua` — world-buff presence, timers and acquisition sources
- `Legacy.lua` — Legacy points and current-zone provider
- `Professions.lua` — skill checkpoints and zone opportunities
- `Tracker.lua` — floating tracker window
- `Options.lua` — supported EllesmereUI plugin settings integration

The addon uses EllesmereUI's public plugin and skinning APIs. It does not edit
or hook EllesmereUI vendor files.
