# Changelog

## 0.1.4 - 2026-11-26

- Added Mining, Herbalism, Skinning and Fishing skill rows alongside crafting
  profession progress.
- Fixed Fishing being skipped when `GetProfessions()` contains an empty
  Archaeology slot.
- Added coordinate-free herb, ore and fishing-pool summaries generated from a
  pinned Forever Nodes snapshot. Duskwood now lists its vein types from most to
  least known locations.
- Changed a missing Well Fed row to recommend the strongest role-appropriate
  combat food in the character's bags, otherwise the strongest supported
  learned Cooking recipe.
- Added third-party notices and a reproducible Node.js gathering-data generator.

## 0.1.3 - 2026-11-26

- Fixed active buffs and other readiness checks briefly turning red when combat
  restrictions made their live values unreadable.
- The tracker now retains its last verified out-of-combat snapshot throughout
  combat and performs a live refresh after combat ends.

## 0.1.2 - 2026-11-26

- Defined the zone gathering experience: herbs and ore ranked by known node
  coverage, observed skinning materials, fish availability and recommended
  effective Fishing skill.
- Selected licensed upstream sources and documented the attribution,
  provenance, confidence and generated-data requirements.
- Kept coordinates and route guidance out of Adventure Tracker; source node
  data is reduced to zone-level summaries.

## 0.1.1 - 2026-11-26

- Removed the player-facing Legacy development placeholder. The section now stays
  hidden unless it has real information to show.
- Added a researched implementation plan for contextual Legacy, missing-quest,
  recipe, profession-synergy and crafted-gear recommendations.

## 0.1.0 - 2026-11-26

- Added the Adventure Tracker sidebar section with Tracker, Readiness, Legacy
  and Professions submenu groups.
- Added the first floating tracker window with drag, lock, collapse, scaling,
  opacity and visibility controls.
- Added live readiness checks for Camp Benefits, Cozy Sleeping Bag stacks,
  food, common class preparation and Rogue/Shaman weapon enhancements.
- Added initial camp-to-class-buff equivalence handling.
- Added per-character activity roles.
- Added a separate World Buffs submenu and provider with active durations,
  opt-in missing-buff sources and current-zone filtering.
- Added unspent Legacy point reminders and the current-zone Legacy provider
  boundary.
- Added profession Legacy checkpoints, skill-cap reminders and gathering
  context.
