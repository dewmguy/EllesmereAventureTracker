# Data Sources and Licensing

Date: 2026-11-27

This document records which external resources Adventure Tracker may use and
how. It is an engineering policy and inventory. Version 0.7.0 ships a
coordinate-free Forever Nodes aggregate, Cooking recipe/output discovery seeds,
an attributed build-stamped recipe catalogue, a static Forever class-training
catalogue and OneCast-derived Fishing thresholds; retained notices are in the
root `THIRD_PARTY_NOTICES.md`.

## Rules

- Publicly visible is not the same as reusable. Import only material with an
  explicit licence or a documented API permission.
- Pin every generated pack to an upstream commit, release or snapshot date and
  record the WoW Forever client build it targets.
- Preserve copyright, licence and attribution notices in the generated file and
  in a future root `THIRD_PARTY_NOTICES.md` before the first data pack ships.
- Keep differently licensed data in separate generated files. In particular,
  do not merge CC BY-SA observations into MIT-derived tables or Blizzard
  game-file extracts.
- Generate compact facts needed by the tracker. Do not vendor complete upstream
  databases when an aggregate or optional runtime adapter is sufficient.
- Never ship source coordinates, player/install pseudonyms, API keys or scraped
  website content.
- Treat missing data as Unknown, not zero. Ship sample sizes and confidence with
  every observed rate or ordering.

## Accepted sources

### Forever Nodes

- Source: <https://github.com/LvcidLabs/ForeverNodes>
- Declared licence: MIT, copyright 2026 Lvcid.
- Upstream credit: its node data and icons are based on GatherLite by Wuild,
  also under an MIT notice retained in `CREDITS.txt`.
- Intended use: build-time aggregation of herb, ore and fishing-pool node types,
  required skill and unique known-position counts by zone.
- Included beginning in 0.1.4 as `Data/GatheringCatalog.lua`, pinned to revision
  `60d61b4f477a23d02d9707399fe8f1a7d2525d10`.
- Boundary: no coordinates, pins or routes are shipped or shown. The upstream
  file says its converted database originated as a Wowhead import, so only the
  minimal zone aggregate is selected and the provenance is disclosed.
- Required notices: Forever Nodes MIT text and the retained GatherLite MIT text.

### OneCast

- Source: <https://github.com/rynmon/OneCast>
- Declared licence: MIT on the project's CurseForge licence page.
- Intended use: zone Fishing skill baselines and clearly separated
  player-confirmed Forever overrides from `ZoneLevels.lua` and `ZoneNames.lua`.
- Included beginning in 0.6.0 as `Data/FishingLevels.lua`, pinned to revision
  `2f4a6b02e25ef5f4ab025a14b09f48c352948c3a`.
- Boundary: do not import `FishData.lua` zone ordering. Its own header documents
  mixed Wowhead, Classic database and player-report provenance.
- Required notice: credit OneCast/rynmon and link the MIT declaration. Preserve
  its documented attribution to the Classic databases behind baseline values.

### Everloot observed data

- Source and author guidance: <https://everloot.app/docs/addon-authors>
- Licence: CC BY-SA 4.0, credited to Everloot contributors.
- Intended use: build-time aggregation of observed fishing catches, gathering
  loot and skinning loot. Only records with a stated source kind are eligible.
- Required credit: `Data from Everloot (https://everloot.app), CC BY-SA 4.0.`
- Packaging: a separate `Data/ObservedGathering.lua` pack under CC BY-SA 4.0,
  stamped with `dataAsOf`, window/catch counts and distinct-install counts.
- Privacy and quality: discard install pseudonyms after counting them; require
  agreement from at least three installs for a confirmed fact; never turn an
  absent record into a measured zero.
- Deferred in 0.6.0: the public bulk `corpus.ndjson` pointer still names a
  pre-launch empty snapshot from 2026-10-19, while the live anonymous corpus is
  larger than the no-key paging allowance. Everloot's current profession pages
  also report no confirmed leather, herb or ore zones. Adventure Tracker ships
  no Everloot-derived observation pack until a complete, reproducible snapshot
  can satisfy the rules above.

### QuestieDB

- Source: <https://github.com/Questie/QuestieDB>
- Intended use: optional runtime data provider through its public API for quest,
  NPC, item, vendor and drop relationships.
- Boundary: do not copy its database into this repository. Do not expose its
  coordinates, routes or map pins through Adventure Tracker.
- Implemented in 0.2.0 for instance quests. The adapter reads only quest
  eligibility, chain prerequisites, quest names, NPC names, starting items and
  item-to-mob drop relationships. QuestieDB remains an optional dependency.
- Extended in 0.4.0 and 0.5.0 for current-zone quest eligibility and runtime
  recipe-item vendor, mob-drop, object-loot and quest-reward relationships.
  The recipe index is built in coroutine batches and retains no coordinates.
- Extended in 0.7.0 for character-visited zone summaries and player-level
  aggregate XP from QuestieDB's public QuestXP support table. Coin rewards are
  read from the live client API by quest ID and are not copied from QuestieDB.

### What's Training?

- Source: <https://github.com/fusionpit/WhatsTraining>
- Declared licence: MIT, copyright 2019.
- Intended use: a static class-trainer spell, level, prerequisite and base-cost
  catalogue so Adventure Tracker never asks the player to visit a trainer just
  to populate addon data.
- Included beginning in 0.7.0 as `Data/ClassTraining/`, pinned to revision
  `59763c2105428ccf99926919824c23d850bfbaa4`.
- Boundary: Adventure Tracker imports only the nine Forever class tables. It
  does not copy What's Training's interface, navigation, weapon-master data,
  profession catalogue, saved variables or ignored-spell system. Live trainer
  reads remain a quiet price/description refinement.
- Required notice: the What's Training MIT text in
  `THIRD_PARTY_NOTICES.md` and an attribution header on every imported table.

### Dwarf Explorer's Bible

- Source: <https://github.com/masterred92/DwarfExplorersBible>
- Declared licence: MIT, copyright 2026 Kenny (masterred92).
- Intended use: generated Forever recipe products, spell IDs, profession
  associations, skill thresholds and reagent quantities.
- Included beginning in 0.5.0 as `Data/RecipeCatalog.lua`, pinned to upstream
  blob `a6d5d40fd4b5cf61a7d2d857acbf34c7e06989d1`.
- Snapshot: WoW Forever 1.60.1.71037 client tables with the upstream project's
  documented 70959 server-hotfix overlay.
- Boundary: Adventure Tracker imports the compact generated facts, not the
  upstream UI, price cache, loot history or player observations. Acquisition
  sources remain a live QuestieDB overlay.
- Required notice: Kenny's MIT copyright and licence text.

### Blizzard client data

- Source: the installed WoW Forever client and documented in-game APIs.
- Intended use: live character state and build-stamped recipe/item facts.
- Version 0.2.0 also uses Encounter Journal class/spec loot filters, encounter
  names and item IDs at runtime, then compares live item levels with equipped
  slots. No Encounter Journal database is copied into the addon.
- Version 0.3.0 reads EllesmereUI Forever Essentials' already-loaded TaxiPath
  distance table at runtime for a simplified in-tracker flight estimate. Its
  measured route history and every appearance setting are stored separately in
  Adventure Tracker and do not modify the native or Custom Tweaks flight timer.
- Boundary: Blizzard game data is not relicensed as Adventure Tracker content.
  Generated files identify the client build and retain the appropriate Blizzard
  ownership notice.

## Rejected or deferred sources

- All Rights Reserved addons are not copied. They may be studied only as product
  overlap when ordinary use permits it.
- Wowhead pages are not bulk scraped or repackaged. A compatible open-source
  project having once imported Wowhead does not erase that provenance.
- Repositories without a clear licence are not copied.
- GatherMate2 Data and similar large databases remain deferred until the exact
  dataset licence and upstream provenance are verified.

## Generated-pack checklist

Before committing a generated pack:

1. Record upstream URL, revision, snapshot time and Forever client build.
2. Record the generator revision and deterministic command.
3. Include the exact required credit and licence identifier in the file header.
4. Store source/confidence/sample-size fields beside each aggregate.
5. Confirm the output contains no coordinates, routes, pseudonyms or credentials.
6. Add or update root `THIRD_PARTY_NOTICES.md`.
7. Run fixture tests for Unknown values, ordering ties and stale snapshots.
