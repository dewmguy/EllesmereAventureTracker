# Changelog

## 0.1.7 - 2026-11-26

- Added a Character summary of every skill currently available from the last
  class trainer visited, with individual prices and the total cost to learn all.
- Class-training data is kept per character, refreshes as skills are learned
  and asks for a new trainer scan after the character levels.
- Profession trainers and unavailable future skills are excluded from the
  Character training list and cost total.

## 0.1.6 - 2026-11-26

- Moved crafting-skill Legacy checkpoints into the Legacy section and rewrote
  them as explicit goals such as 'Raise Blacksmithing to 150'.
- Reorganized profession tracking into one section per profession, with the
  current/maximum skill in its heading and local resource advice in that same
  section.
- Replaced cap countdowns with the next trainable profession rank, the remaining
  skill-ups and a trainer, book or quest destination.
- Added learned-recipe caching and ranking for a dependable next skill-up,
  including Mining-to-Blacksmithing ore, bar and stone guidance that favors
  resources available in the current zone.
- Added class-usable crafted-gear recommendations that prefer an item-level
  upgrade over currently equipped gear.
- Renamed the readiness section to 'Missing Buffs' and added the exact number of
  unspent class, specialization and hero talent points to its reminder.

## 0.1.5 - 2026-11-26

- Added full tracker-window appearance controls for background color and alpha,
  border style, size, color and alpha, plus title-bar mode, height, color,
  title visibility, alignment, separator and text color.
- Replaced the boxed minimize control with the Quest Tracker's unboxed `+` / `-`
  treatment and replaced the text lock control with the Damage Meter's
  hover-faded lock icon behavior.
- Registered Adventure Tracker with EllesmereUI Unlock Mode for precise
  placement, width adjustment and anchor relationships.
- Added an actionable unspent class/hero talent reminder and an option to hide
  only Blizzard's matching callout to the hidden Player Spells microbutton.

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
