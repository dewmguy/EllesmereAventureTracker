# Changelog

## 0.9.5 - 2026-11-27

- Kept all profession sections at the bottom of the tracker while grouping the
  character's primary professions before secondary professions. Names remain
  alphabetical within each group.

## 0.9.4 - 2026-11-27

- Tightened Quest Progress to standalone quest starts. Any quest carrying a
  recorded grouped, alternative, parent-active or available-starting-with chain
  prerequisite is now excluded, even if completion history might otherwise make
  a later chain step appear eligible. Future quest-item warnings use the same
  conservative chain filter.
- Added Questie's upstream non-SoD blacklist for Duskwood Mission I–XVIII
  (81730–81747). QuestieDB's Forever records expose ordinary starters and no
  availability flag for these Season of Discovery quests, so its public fields
  alone cannot distinguish them from real Forever offers.

## 0.9.3 - 2026-11-27

- Filtered purchased recipe sources by the current character's faction before
  scoring attainability, locality or display names. Shared recipes now show the
  matching Alliance or Horde vendor instead of combining both faction-specific
  vendors, while neutral vendors remain eligible to either faction.

## 0.9.2 - 2026-11-27

- Fixed the profession area remaining completely absent while its detailed
  recipe, source, upgrade and route analysis was still running inside the frame
  budget. The provider now publishes lightweight rank, trainer, fishing and
  gathering recommendations first, then atomically replaces them with the full
  result when detailed analysis finishes.
- Preserved that lightweight profession result if a detailed analysis fails,
  so one bad enrichment can no longer hide every profession section.
- Included stored provider errors in `/at profile report`, making a persistent
  detailed-analysis failure identifiable without enabling a separate debugger.
- Added a persistent profession status row while recommendations are loading or
  have failed. Optional diagnostics keep the row visible when ready; hovering
  shows runtime state and clicking prints every provider's state in chat.
- Corrected the prior-result check so an empty result cannot prevent the fast
  profession summary from being published on a same-session retry.

## 0.9.1 - 2026-11-27

- Fixed profession recommendations disappearing after reload when the new
  time-sliced profession build and bag-signature worker interleaved. Selected
  profession routes now build in a private staging table and become visible
  only when the matching provider generation is successfully committed.
- Committed each profession route set together with the exact reagent inventory
  signature used to build it. Bag changes compare against that stable baseline
  instead of observing a partially reset or partially populated route set and
  repeatedly invalidating the provider.
- Discarded staged profession state when a provider result becomes stale or
  errors, while retaining the last committed routes for inventory filtering.
- Added one bounded post-login recovery: if WoW reports learned professions but
  the completed provider has no sections, Adventure Tracker retries that
  provider once after the profession API has settled. It does not poll.

## 0.9.0 - 2026-11-27

- Rebuilt the runtime around one shared 0.35 ms frame-work budget. Provider
  builds, inventory signatures, trainer and profession scans, Questie indexing,
  large sorts and tracker rendering now yield at safe record boundaries and
  continue on later frames instead of monopolizing WoW's render thread.
- Separated provider computation from presentation. `BuildSnapshot` only
  composes committed cached results; it can no longer synchronously invoke a
  dirty provider while the pane is rendering.
- Replaced the immediate monolithic refresh with a coalescing budgeted render.
  Old frames remain visible while a structural update is applied, then unused
  pooled elements are hidden after the new layout is complete.
- Added keyed in-place presentation updates for stable provider results. If row,
  section and status structure is unchanged, labels, details, progress, states,
  tooltips and alert styling update without rebuilding or resizing the pane.
- Replaced one full QuestieDB quest scan per visited zone with a shared,
  time-sliced area index built in one pass. The index is published atomically so
  a failed cold build cannot expose partial results or strand another provider.
- Moved merchant buyback capture, bag-signature comparison, class/profession
  trainer capture and profession-window recipe capture out of event callbacks
  and into the shared scheduler. Their frequent events now only enqueue and
  coalesce work.
- Removed broad live profession enumeration from the Well Fed provider. Crafted
  food recommendations use the shipped Cooking catalogue plus the durable
  learned-recipe cache populated from the profession window.
- Made the scheduler sleep when all remaining jobs are combat-gated and wake on
  combat exit, preventing a hidden per-frame retry loop.
- Expanded `/at profile report` with budgeted task names and
  `runtime-overrun:<task>` metrics for any individual coroutine resume that
  exceeds the frame slice.

## 0.8.10 - 2026-11-27

- Filtered `UNIT_AURA` deltas against the exact readiness and world-buff spell
  sets. Temporary eating, drinking and unrelated aura instances no longer
  invalidate either provider or render the pane; tracked additions, updates
  and removals still refresh their owner.
- Stopped the secure food button from scheduling a speculative second refresh;
  successful actions already report their authoritative aura and bag changes.
- Changed resting, mounted, presence, life and player-flag events to update the
  compact context text directly instead of rebuilding all tracker rows. This
  removes the full render previously caused when eating or drinking made the
  character sit.
- Added negative caching for food/drink tooltip classification. Drinks and
  other items without a combat-food benefit are excluded from the readiness
  inventory signature after their first evaluation, preventing every consumed
  stack from dirtying readiness.
- Replaced the readiness signature's whole-inventory walk with a per-bag cache.
  `BAG_UPDATE` marks only the changed player bag dirty, and the delayed event
  scans that bag before comparing the compact cached signature.

## 0.8.9 - 2026-11-27

- Fixed lock/unlock marking every provider dirty, immediately rebuilding the
  full tracker and then performing a second queued render. The lock button,
  settings toggle and slash commands now update only the saved lock state,
  icon and hover fade without a provider build or pane render.
- Replaced the generic setting-wide invalidation with explicit scopes. Pure
  interaction settings perform no render, presentation settings reuse cached
  provider results, and feature settings invalidate only their character,
  readiness, world-buff, Legacy, quest, profession, instance or flight owner.
- Changed slider application to invalidate its scoped provider once and use the
  immediate settings render, avoiding a second delayed render.
- Removed unnecessary pane renders from EllesmereUI Unlock Mode position save,
  reset and apply callbacks. A real dynamic-anchor geometry change retains its
  single debounced height recalculation.

## 0.8.8 - 2026-11-27

- Replaced blanket loot invalidation with a compact inventory signature for
  combat food and reagents used by the currently recommended profession route.
  Looting, deleting or moving unrelated items now performs no provider rebuild
  and no tracker render; relevant changes invalidate only the affected provider.
- Removed ordinary bag changes from Quest Progress. Merchant buyback events and
  actual quest-state events remain the authorities for future-material warnings
  and available-quest results.
- Split profession rendering into cached stable rows and one lightweight active
  route. Relevant reagent changes recalculate the route while reusing trainer,
  gathering, gear, worldwide recipe and QuestieDB source results.
- Preserved pending full invalidations when a bag event lands in the same
  coalescing window, so skill-ups, level changes and settings changes cannot be
  accidentally reduced to an inventory-only refresh.
- Made the existing learned-recipe SavedVariables cache authoritative across
  reloads and relogs. Opening or filtering an unchanged profession window no
  longer walks every recipe schematic; a full capture occurs only for a missing,
  version-stale or explicitly dirty cache.
- Marked recipe caches dirty when WoW reports a newly learned spell and switched
  first-time capture to the unfiltered recipe list when that API is available.
  Cache schema v3 performs one intentional migration scan so older snapshots
  potentially created under a profession-window filter are not trusted forever.
- Added versioned persistent signatures to class and profession trainer caches.
  Reopening an unchanged trainer performs only a small service comparison and
  skips tooltip collection, cache replacement, provider invalidation and render.
- Removed duplicate immediate/deferred trainer scans and stopped profession and
  trainer window events from refreshing the tracker when their caches did not change.
- Removed profession-window and unscoped global item-data events from the
  instance provider; its quest and loot caches now respond only to events that
  can actually change instance eligibility, equipment or requested item data.

## 0.8.7 - 2026-11-27

- Stopped failed asynchronous item and spell loads from rebuilding a provider
  and immediately requesting the same unavailable record again. Failures now
  use a five-minute, timer-free retry backoff, removing the approximately
  20-second timeout/retry cadence.
- Filtered bag contents through their instant item class before evaluating
  combat food, so ordinary equipment, quest items and materials can no longer
  generate food-related item-data requests.
- Made worldwide crafted-upgrade scoring cache-only. The catalogue still shows
  attainable recipe opportunities and scores products already known to the
  client, but cannot bulk-request scores of uncached products after reload.

## 0.8.6 - 2026-11-27

- Removed the post-reload QuestieDB item-database worker completely. Recipe
  teaching items now come from a compact, deterministic index generated from
  the WoW: Forever 1.60.1.71139 `ItemEffect` and `ItemXItemEffect` client tables.
- Added build-stamped product level gates from `ItemSparse`, eliminating the
  bulk item-data requests that began when the old source index completed.
- Scoped item- and spell-data completion events to loads explicitly requested
  by Adventure Tracker. Cache traffic from other addons no longer rebuilds
  readiness, professions, class reminders and instance loot, and duplicate
  requests for the same pending record are coalesced.
- Added a reproducible source-index generator and documented the no-worker
  performance boundary. The live QuestieDB overlay still supplies vendor,
  creature-drop, object-loot and quest-reward descriptions for mapped items.

## 0.8.5 - 2026-11-27

- Stopped tracker renders from explicitly reapplying their EllesmereUI dynamic
  anchor after every height calculation. EllesmereUI's registered resize hook
  remains the single anchor authority when the pane actually changes size.
- Made tracker width and height writes idempotent within the same half-unit
  tolerance as EllesmereUI's resize observer, preventing unchanged layouts and
  scale-rounding noise from starting redundant anchor cascades and settle passes.
- Fixed the full-height limiter's center-anchor feedback loop by measuring from
  the frame point that actually owns the pane. Centered panes now calculate one
  stable symmetric limit instead of repeatedly shrinking toward half-height.
- Removed the legacy 10-second whole-pane status refresh. Aura changes remain
  event-driven, while configurable expiration warnings now use exact one-shot
  threshold timers and dynamic target movement gets one debounced layout pass.

## 0.8.4 - 2026-11-27

- Removed the half-second global tracker renders from instance, boss and flight
  timers. Their visible text and progress now update directly once per second
  without rebuilding providers, sections, layout or secure actions.
- Added provider-level dirty-state caching and event-specific invalidation, so
  aura, group, bag, trainer and timed-status changes no longer cause unrelated
  QuestieDB quest providers to run.
- Cached composed zone-quest recommendations by character, area, level and
  quest-state revision. Quest, spell, profession, specialization and reputation
  events invalidate the cache while unrelated renders reuse it.
- Replaced the fixed 250-item-per-frame QuestieDB recipe index with a hard
  0.35 ms idle-frame budget. Indexing pauses during movement, combat, taxi
  travel and boss encounters, and stops entirely when its feature is disabled.
- Added opt-in provider, snapshot, render, quest and recipe-index profiling via
  `/at profile` and `/at profile report`; production logging remains silent.

## 0.8.3 - 2026-11-27

- Added the character level before the compact specialization and class in the
  fixed status row, such as `27 Prot Paladin`.
- Limited Quest Progress and instance-quest suggestions to quests no more than
  five levels above the character, preventing low-minimum but level-60 city
  quests from inflating a leveling character's available count.
- Completed the QuestieDB chain-state checks by honoring active parent quests
  and hiding an earlier chain entry once its successor is active or complete.

## 0.8.2 - 2026-11-27

- Added live `Solo`, `Party` or `Raid` context to the fixed status row and kept
  a specifically selected Tank, Healer or DPS role beside it.
- Kept the per-character Tank, Healer, Physical DPS and Caster DPS selection as
  a separate recommendation input, so joining a group updates the visible
  context without silently changing buff or profession advice. The default
  Solo recommendation profile is omitted while grouped to avoid `Party • Solo`.

## 0.8.1 - 2026-11-27

- Added red, breathing Quest Progress warnings when a newly vendored item is
  still needed by a non-trivial, unaccepted quest in a genuinely visited zone.
- Limited future-material matching to real item objectives, the current
  character's race/class, and quests no more than five levels ahead while
  intentionally allowing later steps in an unfinished chain.
- Made an active warning buy the matching stack back when clicked while the
  merchant still offers it, with the volatile buyback index resolved again at
  click time.
- Added a per-warning X that dismisses the current notification without
  suppressing a later warning if another stack is sold.

## 0.8.0 - 2026-11-27

- Replaced the generic highest-scoring learned-recipe suggestion with a
  permanent profession route that strongly prefers orange/guaranteed crafts,
  calculates an expected craft count and names the skill target to stop at.
- Added a narrow useful-bulk exception for reusable components when the bags
  already support a worthwhile batch, so grinding stones and similar inputs
  are not discarded merely because they have turned yellow or green.
- Added 2,193 attributed Forever profession learn-at, trainer-price, level and
  acquisition facts from the pinned MIT-licensed What's Training? snapshot.
- Replaced profession-trainer scan/setup prompts with a permanent collapsible
  list of currently available unlearned trainer recipes and their total cost.
- Added inventory-aware material goals backed by QuestieDB mob, object, vendor
  and zone relations, plus Mining-aware ore, stone and smelting actions.
- Kept optional TradeSkillMaster pricing with Auctionator fallback as a route
  tie-breaker, without making either addon or an opened profession pane a
  requirement.

## 0.6.0 - 2026-11-27

- Added a OneCast-derived, attributed fishing-threshold table with documented
  Forever measurements separated from Classic baselines.
- Added a current-zone recommendation for effective Fishing skill, including
  the live profession bonus and the remaining gap to the no-getaway threshold.
- Added local, account-wide observation of fishing and skinning loot with
  per-zone item totals and explicit loot-window sample sizes.
- Kept unmeasured fishing thresholds unknown and declined to ship an Everloot
  observation pack while its public bulk corpus remains a pre-launch empty
  snapshot and its live profession pages have no confirmed gathering zones.

## 0.5.0 - 2026-11-27

- Added an attributed, build-stamped catalogue of 2,090 Forever recipes from
  Dwarf Explorer's Bible's MIT-licensed generated data for client build
  1.60.1.71037 plus the documented 70959 hotfix overlay.
- Added a coroutine-batched QuestieDB recipe-item index and runtime vendor,
  appropriate-level mob-drop, object-loot and currently eligible quest-reward
  source overlay without displaying coordinates.
- Added one best attainable unlearned recipe recommendation per profession and
  a per-character expansion row for every additional reasonable worldwide
  option.
- Added unlearned crafted-upgrade scoring against equipped gear and
  cross-profession reagent recommendations when both profession recipe caches
  have been opened.
- Kept unavailable, hidden and unknown-source recipes out of recommendations
  instead of guessing acquisition paths.

## 0.4.0 - 2026-11-27

- Added live Legacy Challenge discovery through the client's
  achievement-to-Legacy-currency relationship, ranked by current zone,
  instance, level, class, professions and existing criteria progress.
- Added a current-zone missing-quest provider backed by QuestieDB. It excludes
  completed, accepted, repeatable, prerequisite-blocked and unverifiable
  quests, and shows only an NPC giver or an item plus its dropping mobs.
- Kept the highest-ranked zone quest visible and put the complete eligible list
  behind a per-character expansion row so large zones do not overwhelm the
  tracker.
- Added automatic TradeSkillMaster price scoring with an Auctionator fallback
  for otherwise comparable profession plans. Recommendations continue normally
  when neither price API has data.
- Added dedicated Quests settings and replaced the Legacy provider placeholder
  text with controls for live contextual challenge recommendations.

## 0.3.20 - 2026-11-27

- Combined specialization and class into one compact context segment, such as
  `Prot Paladin` or `Ret Paladin`.
- Added familiar short names for longer talent trees, including BM, MM, Prot,
  Ret, Disc, Sub, Ele, Enh, Resto, Aff, Demo and Destro.

## 0.3.19 - 2026-11-27

- Fixed the missing specialization in the context row by resolving Forever's
  dominant active talent tree instead of relying on the retail specialization
  globals that do not describe a Forever build.
- Separated the context into explicit Zone, Class, Spec and selected Role
  segments and reused the same spec resolver for preferred class-buff choices.
- Clarified that `Solo` is the character's manually selected activity role and
  does not automatically change on joining a group.

## 0.3.18 - 2026-11-27

- Added a Tracker Text dropdown that aligns the complete fixed status row to
  the left, center or right without changing readiness-icon alignment.

## 0.3.17 - 2026-11-27

- Added Readiness settings for icon size, horizontal and vertical spacing,
  border style and border size.
- Added independent border colors for ready, warning, missing, unavailable,
  unknown and informational icon states.
- Moved readiness count typography into the Readiness page and added stack font
  size, Class/Accent/Custom color, nine-point anchoring and X/Y offsets.
- Centered the icon strip and allowed customized icons to wrap into additional
  rows instead of overflowing the tracker pane.

## 0.3.16 - 2026-11-26

- Simplified the Well-Rested icon badge from `X/3` to the current stack count.
- Kept the title bar when enabled, the status row and the readiness buff row
  visible when the main pane is collapsed, while hiding its recommendation
  sections and entries.

## 0.3.15 - 2026-11-26

- Replaced the five Tracker Text color-mode dropdowns and separate custom-color
  rows with compact, adjacent Class, Accent and Custom color swatches.
- Kept class and accent colors live from EllesmereUI while preserving the
  existing custom colors and alpha picker.

## 0.3.14 - 2026-11-26

- Renamed the tracker section heading from `Legacy` to `Legacy Progress` so its
  purpose is clearer at a glance.

## 0.3.13 - 2026-11-26

- Added reusable nested-row indentation to the tracker renderer.
- Inset expanded class-trainer skills and profession-trainer recipes by 18
  pixels, including their stripe, icon, background and click surface, so they
  read clearly as children of the collapsible summary entry.

## 0.3.12 - 2026-11-26

- Kept the compact status-row text stable while its session or gold hyperlink
  is hovered, preventing once-per-second timer updates from invalidating WoW's
  hyperlink hover and immediately dismissing the tooltip.
- Continued refreshing the active tooltip's session or money details while the
  row is frozen, then caught the visible status text up as soon as the cursor
  actually leaves the hyperlink.

## 0.3.11 - 2026-11-26

- Bundled project-local gold, silver and copper coin textures after confirming
  that both direct MoneyFrame paths and Forever's client coin formatter omit
  the latter two textures inside the tracker status hyperlink.
- Removed the status row's dependency on client coin artwork. The bundled
  textures are reproducibly generated by the included PowerShell asset script
  and carry no external artwork or licensing dependency.

## 0.3.10 - 2026-11-26

- Replaced the tracker's hand-built MoneyFrame texture tags with Forever's
  client-native coin formatter so the silver and copper denomination icons are
  emitted through the same working path used by EllesmereUI bags and loot text.
- Added localized, denomination-colored letter markers as a compatibility
  fallback when the client currency-formatting API is unavailable.

## 0.3.9 - 2026-11-26

- Removed the `Session` prefix from the compact session timer while retaining
  the verbose playtime explanation in its hover tooltip.
- Gave the gold, silver and copper inline textures explicit dimensions so all
  three denomination icons render inside the wrapped, hyperlinked status row.

## 0.3.8 - 2026-11-26

- Added an optional Pane Height Limit with Automatic, Viewport Percent and UI
  Pixels modes, including independent percentage and absolute-value controls.
- Kept custom limits subordinate to the pane's actual anchored viewport span,
  so a requested cap can shorten the pane but can never push it through its
  dynamic anchor or beyond the screen edge.

## 0.3.7 - 2026-11-26

- Made a vertical EllesmereUI dynamic anchor authoritative over the tracker's
  separate growth-direction setting, preventing a tracker anchored beneath the
  Damage Meter from growing upward through its anchor.
- Let dynamically anchored panes use the entire safe span from their fixed edge
  to the viewport even when Full Viewport Height is disabled, removing the
  arbitrary 75% screen-height gap while preserving scrolling and the bottom
  viewport gutter.
- Reapplied size-aware legacy anchors after tracker-height changes so their
  linked edge stays fixed as content appears or collapses.

## 0.3.6 - 2026-11-26

- Added a Main Pane Strata picker with every standard WoW frame-strata level,
  defaulting to Medium to preserve the existing stacking behavior.
- Kept the secure food and class-buff click surfaces on the same selected
  strata as the tracker whenever protected frames can safely be updated.

## 0.3.5 - 2026-11-26

- Fixed class-trainer skill hovers so the scanned ability description is
  prioritized and retained after leaving the trainer, while Blizzard's full
  native trainer tooltip remains available when that trainer is open.
- Moved the session clock into the main status row immediately after Resting,
  removed the leading zero-hour field and moved the verbose character
  `/played` total into the clock's hover tooltip.
- Added carried gold with denomination icons to the status row. Its tooltip
  includes session money changes, the character's lifetime-gold statistic when
  the client exposes it, and known character and Warband balances from
  EllesmereUI's shared gold ledger.
- Added Class, Accent and Custom color modes to context/status text, section
  titles, entry labels, entry details, readiness badges, and both flight-timer
  text fields. The existing title and minimize color modes remain unchanged.

## 0.3.4 - 2026-11-26

- Fixed learned Cooking recipes leaking into Blacksmithing and First Aid
  skill-up recommendations because the scanner used the wrong profession-info
  field and merged new scans into existing recipe caches.
- Versioned and invalidated older learned-recipe caches. Open each crafting
  profession once after updating to rebuild a clean profession-owned snapshot.
- Changed learned-recipe scans to replace the open profession's snapshot rather
  than merging it with stale recipes.

## 0.3.3 - 2026-11-26

- Kept the context/status lines and readiness buff icons fixed at the top of the
  expanded pane while recommendation sections and entries scroll below them.
- Hid the profession trainer-recipe row when the last scan contains no
  currently available unlearned recipes.

## 0.3.2 - 2026-11-26

- Replaced the blocked direct food-use API call with out-of-combat secure item
  actions over both the Well Fed icon and its recommendation row.
- Generalized the existing secure spell overlay so item and spell actions share
  the same combat-safe synchronization and state-driver behavior.
- Added `docs/API_RESTRICTIONS.md` to record protected actions, combat-sensitive
  reads, safe alternatives and the required in-game test checklist.

## 0.3.1 - 2026-11-26

- Added an option that lets the tracker use all safe viewport height available
  from its current fixed edge instead of the normal 75% screen-height limit.
- Added explicit upward or downward pane growth. Down keeps the top edge fixed;
  up keeps the bottom edge fixed, including when the pane is dynamically
  anchored through EllesmereUI unlock mode.

## 0.3.0 - 2026-11-26

- Added a compact flight-master timer inside the tracker with destination,
  elapsed/remaining/total time options and a live progress bar.
- Added an independent rolling-median route history. Adventure Tracker does not
  read or modify the native EllesmereUI or Custom Tweaks flight-timer settings
  and learned times.
- Added independent flight icon, texture, fill mode, background, border, font,
  outline, text-size and text-color controls under Travel & Status.
- Added contextual In Flight, In Combat, Resting, Mounted, instance-type,
  Dead/Ghost and AFK/DND statuses beside the zone and character context.
- Added a second context line with a live current-session duration and the
  character's shared, live `/played` total.
- Extended tracker rows with optional independently styled progress bars and
  per-row typography while preserving the existing global entry appearance.

## 0.2.0 - 2026-11-26

- Added an instance run timer with per-character, per-difficulty personal bests
  recorded only when a final-boss or dungeon-completion signal is detected.
- Added boss encounter timers and per-boss personal bests. Active boss timers
  remain visible even when the general Hide in Combat option is enabled.
- Added an Instances settings group with independent timer, quest and loot
  controls plus compact display limits.
- Added an optional QuestieDB runtime integration for known instance quests
  that are eligible, incomplete and absent from the quest log. It shows only
  the quest giver or starting item and its dropping mobs—never routes, pins,
  coordinates or objectives.
- Added live Encounter Journal suggestions for class/spec-filtered equippable
  drops that improve item level over the relevant equipped slot.
- Preserved the combat-safe aura snapshot while allowing the explicitly marked
  instance timer provider to update during encounters.

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
