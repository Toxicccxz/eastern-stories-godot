# Snow Martial Progression II — P2R1 Source Cloth Death Facts

## Scope and owner gate

P2R1 repairs **BLK-SMP2-01**, the confirmed production lifecycle blocker discovered
by [changed-path live acceptance](PHASE_SNOW_MARTIAL_PROGRESSION_II_CHANGED_PATH_LIVE_ACCEPTANCE.md).
The owner authorized only the missing source-cloth death-facts projection and its
regressions. P2 Liuh-Ken implementation remains conceptually owner-approved.
This repair is a candidate executable freeze pending owner review; live acceptance
remains OPEN / BLOCKED and was not retried. This is not a milestone Final Audit.

| Identity | Value |
| --- | --- |
| Branch | `phase/snow-martial-progression-liuh-ken` |
| Pre-repair local/remote HEAD | `c31d915c6b09f00c412800f7025ac2c9054b2dc0` |
| Original P2 implementation | `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401` |
| Previous executable/test freeze | `81d0cb63da15f9e384392de98cbaa3fd21475a51` |
| Integrated base | `36a26b13e2bdebeb44c14c0a013d509000c29476` |

Fresh fetch matched these identities, worktree/index were clean, and the any-state
phase PR query returned no results. All changes from the previous executable freeze
to the pre-repair HEAD were documentation only (seven paths). The commit containing
this report and repair is the new candidate SHA; the delivery response records its
full SHA and matching remote HEAD without requiring a self-referential commit hash.

## Root cause and pre-existing proof

The production
[`_death_item_facts_for()`](../../game/runtime/world/oldpine_outdoor_controller.gd)
resolved every direct item only through OldPineItemContentDefinitions. Source birth
cloth `es2:obj/cloth` is authored separately in
[SourcePlayerCloth](../../game/data/items/source_player_cloth.gd), so it received
`DeathItemFacts(cloth, null)` despite occupying the Player's live `cloth` slot.
DeathInventoryService correctly requires the worn item's armor definition identity
and slot to align. Missing armor facts produced `INVALID_ITEM_FACTS`, then
`DEATH_INVENTORY_BLOCKED`, then `LIFECYCLE_FAILED`, leaving the encounter RESOLVING.

Independent `git diff` between integrated base and the previous executable freeze
was empty for all four root-cause files:

- `game/runtime/world/oldpine_outdoor_controller.gd`
- `game/core/death/death_inventory_service.gd`
- `game/data/items/source_player_cloth.gd`
- `game/data/oldpine/oldpine_item_content_definitions.gd`

The matching Git blob identities at both revisions are, respectively,
`84ac7a9ca2f8bcd38292bf8b27670272b94c323c`,
`969771bf65b3ac08c486ff4e93725522b0e37e39`,
`5c9f87a0f387dcee39b18ac3aa947c3b3e831dff` and
`d6e56e7c4e401bc3579ccaae7c3f62a22ec04782`.

Classification: **PRE-EXISTING SOURCE-ENTRY / PLAYER-DEATH INTEGRATION DEFECT
DISCOVERED BY P2 LIVE ACCEPTANCE**, not a P2 / Liuh-Ken regression. This does not
change the historical report's observations or its original attribution boundary.

## Source semantics and exact repair

Re-read source authority:

- [obj/cloth.c](../../reference/es2/mudlib/obj/cloth.c): birth cloth, weight 3000,
  authored armor +1, inheriting CLOTH.
- [std/armor/cloth.c](../../reference/es2/mudlib/std/armor/cloth.c): `cloth` armor
  type, inherited EQUIP; no weight-over-3000 dodge penalty for this birth cloth.
- [std/equip.c](../../reference/es2/mudlib/std/equip.c) and
  [feature/equip.c](../../reference/es2/mudlib/feature/equip.c): inherited equipment
  and generic wear behavior.
- [chard.c make_corpse](../../reference/es2/mudlib/adm/daemons/chard.c): for normal
  Player worn direct inventory, move to corpse, attempt wear, then move to victim
  environment only if wear fails.

Only the existing production composition boundary changes: exact
`SourcePlayerCloth.DEFINITION_ID` receives `SourcePlayerCloth.armor_definition()`;
all other items retain the existing Old Pine lookup. The resulting DeathItemFacts
retains the original instance ID and `es2:obj/cloth`, with aligned armor definition,
armor type `cloth` and numeric armor `1`.

The source cloth is not added to Old Pine's catalogue. No generic catalogue,
registry or service locator is introduced. DeathItemFacts, DeathInventoryService,
DeathRewearPolicyRegistry, corpse ordering, retry policy, thresholds and encounter
completion policy are unchanged. Generic base rewear handles the known cloth.

## Regression gap and production-boundary evidence

Historical public New Game coverage checked cloth birth, armor +1 and DeathContext
construction without executing source Player death. Outdoor lifecycle coverage
primarily killed NPCs. Existing combat-slice Player terminal fixtures used technical
inventory/facts. None covered the combined SOURCE_ENTRY Player, worn birth cloth
and production death-facts/lifecycle boundary.

The existing
[Old Pine smoke suite](../../game/tests/runtime/oldpine_outdoor_smoke_test.gd) now
creates a SOURCE_ENTRY Session through existing composition, checks its sole direct
cloth item and live armor slot, and calls the exact production facts projection.
It then uses the Session's production map handoff, lethal encounter entry and
coordinator scheduler with a test-set death threshold. This is a controlled
integration regression, not physical travel, natural combat or live EXP6 evidence.
No new QA scene, helper or test framework was added.

The new assertions verify:

- Exact cloth instance/definition, non-null aligned armor, `cloth` slot and armor 1.
- Normal death inventory COMPLETED, lifecycle DEATH_COMPLETE, world Player DEAD,
  encounter COMPLETED with DEFEAT and active encounter released.
- Exactly one corpse; the original live cloth becomes its direct content and its
  worn `cloth` projection; Player ArmorState detaches it. The complete registered
  item set gains only the corpse; no cloth/item is duplicated, replaced or lost.
- A later scheduler request creates no second corpse or lifecycle execution.
- Real NPC loadout death facts still cover long sword, short sword, silver and
  leather. Weapons/currency have no armor definition; leather keeps aligned
  `cloth`, armor 5 and dodge -2.
- Existing uncovered direct-item regression still returns INVALID_ITEM_FACTS /
  DEATH_INVENTORY_BLOCKED and does not retry or duplicate corpses. Existing NPC
  death and lifecycle regressions remain in the focused and canonical runners.

Before the production repair, the final regression reproduced 13 expected failures
over 2,278 executed assertions, including the exact typed failure chain and retained
Player cloth. An initial test-only collection comparison used StringName ordering;
it was corrected to compare the inventory's stable order after removing only the
new corpse ID, then the red run was repeated before changing production. After the
narrow repair, the unchanged final regression passes. The green run executes four
additional guarded assertions because armor facts and rewear results now exist.

## Fresh validation

| Gate | Result |
| --- | --- |
| Existing Phase 8B1 focused runner | PASS, 2,282 assertions, zero failures |
| Complete canonical gameplay runner | PASS, 20,608 assertions (20,544 previous + 64 new), zero failures |
| Full Python tooling suite | PASS, 656 tests, zero failures/errors/skips |
| Repository/static checks | PASS |
| Development Godot headless/editor validation | PASS, exit0 |
| Actual release sanitizer and sanitized-project headless/editor validation | PASS, exit0 |
| Complete verify.py command | PASS, exit0, all five stages completed without skips |
| Changed documentation relative links/anchors | PASS, 212 checked |
| Historical Attempt1/2/3 and changed-path report raw bytes | Identical to pre-repair HEAD |
| Whitespace | git diff --check PASS |

Focused command: Godot 4.7.2, `--headless --path game --script
res://tests/run_phase_8b1_tests.gd`. Full gate: `python tools/ci/verify.py --godot
build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe`, without skip flags.
Evidence logs remain ignored under `build/p2r1-*`. Headless runtime integration is
reported as such; no fresh interactive Player or live acceptance attempt occurred.
The full verify log contains no SCRIPT ERROR, ERROR or FAIL result. All existing
Flee, lifecycle failure/no-retry, NPC death, inventory, Liuh and persistence suites
remain included. No executable/test edits followed these successful gates.

## Exact changed files and self-review

- `game/runtime/world/oldpine_outdoor_controller.gd`: known source-cloth facts branch.
- `game/tests/runtime/oldpine_outdoor_smoke_test.gd`: source Player death regression,
  existing item facts checks and explicit unknown-item INVALID_ITEM_FACTS assertion.
- `docs/migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md`:
  this repair report.
- `docs/migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_RUNTIME.md`: current repair gate.
- `docs/production/STATUS.md`: current owner-review disposition.
- `docs/production/ROADMAP.md`: current owner-review disposition.

Distinct self-review inspected the complete production/test diff and the existing
service's fact-coverage, worn-slot alignment and generic rewear paths. The new
branch resolves by immutable definition ID, retains current direct-inventory
enumeration and leaves unknown-index handling untouched. No Player-only bypass,
new item, cached loadout facts or mutation is introduced by fact projection.

## Preserved boundaries and disposition

Production changes are confined to one death-facts composition branch. Source,
DeathInventoryService validation, old item definitions, exceptional rewear policies,
Liuh/Learn/Enable, combat math/actions/feedback/RNG, Flee, EXP, balance and recovery
are unchanged. No persistence change: root schema2, item schema3 and SOURCE_ENTRY_V1
remain exact. DECISIONS is unchanged; no new semantic substitution is needed.

Historical Attempt1/2/3 and the changed-path live acceptance report remain unchanged.
No PR, merge, Final Audit, P3 or Migration Tooling P3. No remote CI was requested.
After local gates and normal push, stop for owner review before any resumed live
acceptance or adoption of the new candidate executable freeze.

**P2R1 BLOCKER REPAIR COMPLETE — AWAIT OWNER REVIEW**
