# Changelog

## 0.1.22 - 2026-11-26

- Made class-buff readiness icons use the exact spell currently active on the
  player, then the most recently observed choice for that character and role.
- Added Paladin blessing and aura fallbacks tailored to the selected activity
  role, with Holy, Protection and Retribution preferences for Solo mode.
- Added real spell tooltips to class-buff recommendations.
- Added secure out-of-combat self-casting from class-buff icons. The invisible
  secure click surfaces follow tracker movement and scrolling and hide in combat.

## 0.1.21 - 2026-11-26

- Removed duration-only expiring-soon entries from the Missing Buffs section.
- Kept those buffs amber in the readiness icon strip with their remaining time
  available in the icon tooltip.
- Preserved actionable warning rows such as incomplete Well-Rested stacks and
  all genuinely missing or unreadable readiness items.

## 0.1.20 - 2026-11-26

- Added a soft, synchronized yellow or red background pulse to alerted section
  headers and recommendation entries while retaining the existing border glow.
- Kept the attention tint translucent so customized normal and hover entry
  backgrounds remain visible and return unchanged when the alert clears.

## 0.1.19 - 2026-11-26

- Combined the former Window and Appearance tabs into one Tracker settings page.
- Added adjustable pane padding on every side of the tracker contents.
- Added independent normal and hover background colors and alpha for section
  titles and recommendation entries.
- Changed Main Pane Opacity to affect only the pane backdrop instead of fading
  the title, text, section backgrounds and entry backgrounds with the parent.
- Added a tracker font picker and outline control plus independent size and color
  controls for the context line, section titles, entry labels, entry details and
  readiness-icon badges. Larger text now expands its containing rows.

## 0.1.18 - 2026-11-26

- Made the unlocked tracker draggable from its background, context and scroll
  areas, section headers, readiness icons and recommendation rows.
- Kept the lock and overall collapse controls dedicated to their own actions.
- Suppressed a row, icon or section's click action when that same gesture moved
  the tracker, preventing accidental activation after repositioning.

## 0.1.17 - 2026-11-26

- Removed the empty vertical row that remained above the context line when the
  title bar was hidden.
- Kept the overall collapse control aligned with the context line in the newly
  compact hidden-title layout.

## 0.1.16 - 2026-11-26

- Aligned the overall collapse control with the zone, specialization, class and
  role context line when the title bar is hidden.
- Reserved space at the right of that context line so long zone or build names
  cannot overlap the control.

## 0.1.15 - 2026-11-26

- Made every visible tracker section independently collapsible per character,
  using Quest Tracker-style plus and minus headers.
- Added a clipped mouse-wheel scroll viewport when the tracker exceeds its
  screen-relative maximum height.
- Collapsed section headers and the overall collapse control inherit active
  yellow or red breathing alerts so important reminders remain visible.
- Made the unspent-talent reminder breathe yellow continuously until all talent
  points are spent.

## 0.1.14 - 2026-11-26

- Added a yellow breathing border when a collapsed class-trainer list gains
  newly available skills after leveling. Opening the list acknowledges and
  permanently clears that alert for those skills.
- Added red breathing borders for missing long-lived class preparation while a
  non-Solo role is selected, including summarized party-member coverage for
  appropriate party buffs.
- Added a configurable minimum expected duration for role alerts, defaulting to
  five minutes so short-cycle effects such as seals do not nag the player.
- Added a party-buff coverage toggle and live party aura refreshes.

## 0.1.13 - 2026-11-26

- Removed the redundant Unlock Mode button from the tracker Window settings.
- Expanded the context line to show zone, specialization, class and selected
  activity role.
- Added Custom, Class Color and Accent Color choices for the shared title and
  collapse-glyph color.
- Kept the collapse control visible in a compact pane row when the title bar is
  hidden, and allowed the tracker to remain collapsed in that appearance mode.

## 0.1.12 - 2026-11-26

- Added per-profession trainer scans for currently available unlearned recipes
  and profession abilities, with individual prices and a total training cost.
- Added a compact, per-character disclosure row to every supported profession;
  click it to expand or collapse that profession's trainer offerings.
- Profession-rank services remain in the existing rank guidance instead of
  being duplicated in the recipe list.
- Added live trainer-service tooltips with cached details after leaving the
  trainer, matching the class-training presentation.

## 0.1.11 - 2026-11-26

- Made the available class-trainer skill list collapsible by clicking its total
  summary row.
- The summary and total cost remain visible while the individual skills are
  collapsed, and expansion state is remembered separately for each character.
- New characters start with the individual list collapsed to keep the tracker
  compact.
- Hovering an expanded untrained skill now shows its real trainer tooltip when
  available, with cached skill details after leaving the trainer, rather than
  repeating the training cost already printed on the row.

## 0.1.10 - 2026-11-26

- Fixed the Blizzard unspent-talent notification remaining visible on Forever's
  current HelpTip-based microbutton UI.
- The suppression now hides the active Player Spells HelpTip and stops its
  pulsing button while matching only the unspent-talent message; unrelated
  Player Spells and microbutton notifications remain available.
- Retained fallbacks for older named talent-alert frames.

## 0.1.9 - 2026-11-26

- Kept the faction Rend world buff visible when missing: Alliance characters
  see Might of Stormwind and Horde characters see Warchief's Blessing.
- Replaced the terse source text with a direct hint naming the turn-in NPC and
  the towns where the character can wait for the buff.
- Other missing world buffs remain optional to avoid filling the tracker with
  unrelated acquisition goals.

## 0.1.8 - 2026-11-26

- Made owned-food recommendations clickable: clicking the Well Fed icon or row
  consumes the exact recommended food through WoW's normal item-use action.
- Crafted-but-not-owned recommendations remain informational, and combat or a
  food item that has left the bags fails safely without substituting another.

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
