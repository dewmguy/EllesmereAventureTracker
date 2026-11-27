# Adventure Tracker: Research and Implementation Plan

Date: 2026-11-26

## Product boundary

Adventure Tracker should remain an EllesmereUI-native recommendation layer. It
should not become a quest guide, route planner, map-pin addon or general database
browser.

The floating window should answer one question: **What is the most useful thing I
can do next, here, at my current level?** Detailed lists belong in the Adventure
Tracker settings panes.

For quests, the boundary is explicit:

- show only known missing quests that are available to start **right now** in the
  current zone;
- for an NPC-started quest, show the quest giver's name;
- for an item-started quest, show the starting item and the mob or mobs known to
  drop it;
- suppress every quest whose earlier chain step or other prerequisite is incomplete;
- do not show coordinates, map pins, arrows, routes, objectives or turn-in
  directions;
- do not replace Questie's questing interface.

There is meaningful overlap with QuestieDB, All The Things, Recipe Radar Forever,
ItemTree, Crafter's Journal, OneForAll and Wowhead's Character Planner. The addon
still has a distinct role if it consumes reliable data and ranks a few useful
actions instead of reproducing those products' full interfaces.

## Research conclusions

### Legacy challenges

- Ordinary zone quest completion does not directly award a Legacy point. Zone
  questing can still advance a class level challenge, profession materials or the
  account's exploration challenge.
- The launch system exposes 65 obtainable points and allows each character to spend
  up to 16. Blizzard expects the challenge catalogue and caps to grow.
- Current point sources include class level milestones, crafting-profession skill
  milestones, three dungeon groups, exploration, PvP ranks/reputations/journey,
  raids and the Dungeon Set 2 questline.
- The live Forever client exposes Legacy Challenges through the achievement APIs.
  Blizzard's own UI enumerates GetCategoryList, GetCategoryInfo,
  GetAchievementInfo and achievement criteria. A challenge's point value is
  available from C_Traits.GetTraitCurrencyForAchievement using the live Legacy
  point currency constant.

The addon must not hard-code the current challenge catalogue as its source of
truth. It should enumerate incomplete, point-bearing challenges from the client and
apply contextual metadata only for ranking and presentation.

### Missing quests

- The client reports completed quest IDs through
  C_QuestLog.GetAllCompletedQuestIDs and can test individual IDs with
  C_QuestLog.IsQuestFlaggedCompleted.
- The client does not expose a complete enumerable catalogue of every unaccepted
  quest in a zone. A database provider is required to know what might be missing.
- QuestieDB is the strongest current Forever-oriented provider. Its public API
  exposes every known quest ID, level, race/class restrictions, prerequisites,
  exclusivity, breadcrumb relations, starters, finishers and zone classification.
- QuestieDB's Forever documentation is candid that new content and relations are
  still improved through traces and corrections. No external database can
  guarantee perfect completeness for a newly released and changing game.

Use QuestieDB as an optional-but-recommended **data provider only**. Adventure
Tracker will not invoke Questie routing, add quest pins or expose coordinates.
It will use starter and drop relationships only to name the NPC or item source that
starts a currently available quest.
Do not copy QuestieDB into this repository. Show its version in settings and use
the phrase **known quests**, not **all quests**, whenever completeness matters.

### Recipe catalogue and sources

- The Forever client documents recipe lookup functions such as
  C_TradeSkillUI.GetRecipeInfo, GetRecipeSchematic and GetRecipeSourceText, but it
  does not document a global function that enumerates every recipe ID.
- A complete base catalogue therefore needs to be generated outside the game from
  client DB2 tables and tied to a specific Forever build.
- The MIT-licensed ExcEssIv3/profit project demonstrates a maintained extraction
  path from wago.tools DB2 exports. Its model includes recipe/product IDs,
  reagents, quantities, skill ranges, tools, stations and recipe-item mappings.
- Vendor and drop locations are server facts and are not fully described by client
  DB2 files. QuestieDB can resolve known recipe-item vendors, NPC/object drops,
  quests and their zones. Live profession, trainer and merchant windows can add
  character-local observations.
- Recipe Radar Forever specializes in vendor recipes. Adventure Tracker should
  rank a few attainable recipes, not duplicate its browsing window.

Ship a compact, build-stamped recipe catalogue generated from client data. Resolve
known acquisition sources through QuestieDB and live observations. Do not scrape
or bundle Wowhead data. Everloot's observed data is available under CC BY-SA 4.0,
but including it would add attribution and share-alike obligations; it is not
selected for the initial implementation.

### Profession synergies

Do not rely only on a hand-written list such as Mining -> Blacksmithing. Derive
relationships from recipe reagents:

1. Each recipe creates an edge from its producing profession to its output item.
2. Each reagent creates an edge from that item to every consuming recipe and
   profession.
3. Gathering sources create edges from Mining, Herbalism, Skinning and Fishing to
   their materials.
4. A synergy becomes actionable when the player can obtain or craft an input used
   by a known, learnable or useful recipe in another profession.

This naturally finds relationships such as Mining feeding Blacksmithing and
Engineering, Skinning feeding Leatherworking, Herbalism feeding Alchemy,
Blacksmithing rods feeding Enchanting, Tailoring items feeding Disenchanting, and
Alchemy transmutes feeding other crafts. It also adapts to Forever additions.

### Crafted gear upgrades

Treat recommendations as **likely upgrades**, not absolute best-in-slot judgments.
The first evaluator should use facts the client can verify:

- current equipment links and item levels;
- crafted output slot, armor/weapon type, required level and item level;
- whether the character can use the item;
- learned versus unlearned recipe state;
- profession skill requirement and acquisition source;
- reagent ownership and whether the recipe is craftable now.

Default to an item-level improvement threshold, with special handling for rings,
trinkets, one-hand/two-hand weapons and off-hands. Stat weights and specialization
ranking are later opt-in work because Forever does not expose standard Retail
specializations and many low-level effects are not represented by item level alone.

## Data-source policy

| Feature | Primary source | Fallback | Player-facing confidence |
| --- | --- | --- | --- |
| Legacy challenges | Blizzard achievement and trait APIs | Hide until loaded | Live |
| Quest completion | Blizzard quest-history APIs | Saved character snapshot | Live |
| Known zone quests | QuestieDB public API | Active quest log only | Provider version |
| Recipe catalogue | Build-stamped client DB2 extraction | Observed profession recipes | Client build |
| Recipe vendors/drops | QuestieDB relations | Live trainer/merchant observations | Known/observed |
| Equipped gear | Blizzard inventory and item APIs | None | Live |
| Prices | Auctionator or TSM when installed | No price score | Snapshot age |

Rules:

- Never claim a database is complete without a build/version and a defined scope.
- Never present a guessed source as verified.
- Preserve source provenance on every recommendation and show it in the tooltip.
- If an integration is missing, hide its rows and show setup status only in the
  settings pane, never as a development note in the floating tracker.

## Compact presentation

### Floating tracker

Each section is independently collapsible and remembers its state. A collapsed
section shows its single highest-ranked recommendation. Expanding shows up to five
rows, followed by a +N more row that opens the relevant Adventure Tracker pane.

Example:

~~~text
LEGACY IN THIS ZONE                         2 more  >
  Novice Spelunker 5/6 — The Deadmines       +1 point

AVAILABLE MISSING QUESTS                    3 more  >
  Quest Name — Quest giver: NPC Name

PROFESSION OPPORTUNITIES                   3 more  >
  Mine Tin for Engineering — 18 needed

CRAFTED UPGRADES                           1 more  >
  Heavy Copper Broadsword — +5 item levels
~~~

The quest row names the allowed starting source but does not provide a location or
completion instructions. An item-started row uses the form Quest Name — Item Name
from Mob Name.

The compact tracker normally shows no more than one row per section. Completed,
ineligible, blocked, low-confidence and distant results stay out of the compact
view.

### Main panes

Add or expand these Adventure Tracker submenu groups:

- **Legacy**
  - Recommendations
  - All Challenges
- **Quests**
  - Available Missing Quests
  - Completion & Data Source
- **Professions**
  - Progress
  - Synergies
  - Recipe Sources
  - Crafted Gear

The Available Missing Quests pane remains a checklist, not a guide. It shows only
quests whose requirements are already satisfied, plus the quest giver or the
starting item's dropping mob. It never shows unavailable chain steps, coordinates
or objective instructions.

For recipes, the main pane uses two scopes:

- **Here & Reasonable**: sources in the current zone or appropriate to the player's
  level and profession skill.
- **Worldwide**: every known attainable vendor/drop/quest recipe. This list is
  collapsed by default and expands only when requested.

## Recommendation scoring

Each candidate receives a score and confidence level:

- 100: completing it now directly awards a Legacy point;
- 90: one remaining criterion and available in the current zone;
- 80: available now, current-zone, solo-friendly quest/recipe/upgrade;
- 70: craftable gear upgrade or profession cap blocker;
- 60: meaningful progress toward a nearby Legacy checkpoint;
- 40: available within the next three character levels or 25 profession skill;
- 20: worldwide option with travel, group, reputation or uncertain-source cost.

Apply penalties for excessive travel, group requirements, unknown drop chance,
missing prerequisites, unaffordable known cost and stale or low-confidence data.
The future-level score applies to Legacy, profession and recipe candidates only;
quest candidates must be available now or they are omitted.

Tie breakers:

1. Direct point or unlock value.
2. Current zone.
3. Can complete now.
4. Fewer remaining steps.
5. Solo before group content unless group-first is enabled.
6. Stable vendor/quest source before random drop.

The tooltip explains why a row ranked highly.

## Feature specifications

### Legacy recommendations

1. Enumerate visible achievement categories.
2. Keep only achievements whose live trait-currency result is positive.
3. Read completion and criteria progress from the achievement APIs.
4. Classify the challenge from its category and criteria, not only its localized
   name.
5. Attach context:
   - class thresholds at levels 25, 45 and 60;
   - profession thresholds at skills 150, 225 and 300;
   - dungeon criteria with entrance zone and recommended level;
   - current-map exploration state;
   - Dungeon Set 2 quest-chain progress at level 60;
   - PvP and raid goals only when relevant and enabled.
6. Label rows either Awards 1 point or Progress toward 1 point.
7. Hide the section when no verified recommendation applies.

### Available missing quests in the current zone

1. Resolve the current map to QuestieDB's zone classification.
2. Build a lazy index of quests assigned to that zone.
3. Remove completed quests and quests already present in the quest log.
4. Require every faction, race, class, level, skill, reputation, specialization,
   prerequisite and availability condition to be satisfied now.
5. Suppress breadcrumb conflicts, mutually exclusive alternatives, disabled quests,
   unavailable chain steps and quests with an unknown required state.
6. Accept only two verified start forms:
   - NPC start: read QuestDB.startedBy group 1 and show the quest giver's name;
   - item start: read QuestDB.startedBy group 3, then show the starting item and
     ItemDB.npcDrops names.
7. Hide a candidate when its starter is unknown, its starting item has no verified
   mob drop source, or it starts only from an object/container.
8. Rank the remaining available quests, preferring level-appropriate class,
   profession and dungeon quests and stable NPC starts over random item drops.
9. Show completed / known currently available in the section header.
10. Provide no coordinates, routing, objective guidance, waypoint or map
    integration.

Repeatables and breadcrumbs need explicit handling so the same recurring or
alternative offer does not make the missing count misleading.
For prerequisite semantics, every preQuestGroup entry must be complete, while at
least one preQuestSingle entry must be complete. A failure or unknown value excludes
the quest rather than exposing a later chain step.

### Profession synergy goals

1. Generate a reagent dependency graph from the recipe catalogue.
2. Mark current professions, skill ranks, learned recipes and available materials.
3. Find cross-profession edges that unlock a skill-up, Legacy checkpoint, crafted
   upgrade or important prerequisite.
4. Prefer goals with materials available in the current zone.
5. State the purpose: Mine Tin -> Engineering: Bronze Framework, not a generic
   gathering reminder.

### Crafted gear recommendations

1. Snapshot equipped item links and item levels by slot.
2. Enumerate learned and unlearned equippable recipe outputs.
3. Exclude items above the configured level window, unusable armor/weapons and
   recipes with unreachable requirements.
4. Rank craftable-now learned recipes first, then attainable unlearned recipes.
5. Show slot, current item level, candidate item level and missing reagents/source.
6. Clicking opens the profession recipe when learned; otherwise it opens the
   Adventure Tracker recipe-source detail.

### Looted and purchased recipes

1. Generate the complete recipe and recipe-item mapping for the client build.
2. For every unlearned recipe item, query known QuestieDB vendors, NPC drops, object
   drops and quest relations.
3. Apply faction, level, profession skill, zone and prerequisite filters.
4. Treat vendor recipes as highly attainable when the vendor is friendly and the
   cost or stock is known.
5. Treat targeted drops as reasonable only when the source level is appropriate.
   Unknown global world drops do not enter the compact tracker by default.
6. Keep the Worldwide list collapsed and show its count before expansion.

## Architecture

Proposed modules:

~~~text
Core.lua
Tracker.lua                         per-section collapse and row limits
Services/RecommendationEngine.lua  scoring, confidence and explanations
Services/CharacterState.lua        level, zone, equipment and professions
Integrations/QuestieDB.lua          data-only adapter and provider status
Integrations/Prices.lua             Auctionator/TSM optional adapter
Legacy/Challenges.lua               live challenge enumeration
Legacy/Context.lua                  level, zone and dungeon metadata
Quests/Catalog.lua                  missing-quest index and eligibility
Professions/Catalog.lua             recipe catalogue adapter
Professions/Synergies.lua           reagent graph
Professions/Gear.lua                crafted upgrade evaluator
Data/RecipeCatalog/*.lua            build-stamped and split by profession
tools/build_recipes.py              reproducible DB2 generator
tests/                               pure Lua ranking and eligibility fixtures
~~~

Extend provider results with section collapse metadata, total counts, score,
confidence, reason and source provenance.

## Performance and refresh

- Build QuestieDB indexes in coroutine batches.
- Cache indexes by QuestieDB version and Forever client build.
- Load recipe data by profession rather than loading the entire catalogue at login.
- Recompute only affected groups after zone, level, quest, profession,
  achievement, equipment or bag events.
- Debounce bursty bag and quest-log updates.
- Keep indexing and recommendation analysis out of combat.

Targets:

- no indexing frame longer than 8 ms on the development machine;
- warm compact refresh under 5 ms;
- no unbounded per-frame database scans;
- no error when optional integrations are absent.

## Delivery milestones

### 0.2.0 — Tracker foundation and live Legacy

- per-section collapse and one-row compact mode;
- enumerate live point-bearing Legacy challenges;
- class, profession, dungeon and exploration recommendations;
- no development placeholders in player-facing rows.

### 0.3.0 — Missing quests by zone

- QuestieDB data adapter and provider-status pane;
- completed-history comparison and strict available-now filtering;
- quest-giver names or item-start mob names, with no location data;
- compact available missing-quest suggestion and full checklist;
- explicitly no Questie-style maps, coordinates, arrows or objectives.

### 0.4.0 — Recipe catalogue and sources

- reproducible DB2 recipe generator;
- learned and unlearned tracking;
- QuestieDB vendor/drop/quest source overlay;
- Here & Reasonable plus collapsed Worldwide views.

### 0.5.0 — Synergies and crafted upgrades

- reagent dependency graph;
- cross-profession goals;
- learned and attainable-unlearned gear comparisons;
- optional Auctionator/TSM cost scoring.

## Validation

- Parse every Lua file as Lua 5.1.
- Unit-test that incomplete prerequisites, later chain steps, exclusive quests,
  breadcrumbs and ambiguous starters are excluded, plus ranking tie breakers,
  dual-slot gear and profession dependency cycles.
- Compare known zone quest counts with the selected QuestieDB build without
  rendering its location data.
- Test Alliance and Horde characters at levels 1-24, 25-44, 45-59 and 60.
- Test missing integrations and stale data without showing setup notes in the
  floating tracker.
- In game, verify event refresh, collapse persistence, tooltip provenance and
  settings-pane navigation.

## Sources reviewed

- [Blizzard: WoW Forever Deep Dive](https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap)
- [Forever Blizzard UI source mirror](https://github.com/reckhou/WoWBlzCode)
- [QuestieDB public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md)
- [QuestieDB Forever notes](https://github.com/Questie/QuestieDB/blob/master/docs/forever.md)
- [QuestieDB licensing](https://github.com/Questie/QuestieDB/blob/master/LICENSE.md)
- [MIT DB2 recipe extraction reference](https://github.com/ExcEssIv3/profit)
- [Recipe Radar Forever](https://github.com/Cebion/RecipeRadarForever)
- [Everloot addon-author data policy](https://everloot.app/docs/addon-authors)
- [Wowhead Legacy overview](https://www.wowhead.com/forever/guide/legacy-system-overview-rewards)
- [Wowhead Character Planner](https://www.wowhead.com/forever/character-planner)
