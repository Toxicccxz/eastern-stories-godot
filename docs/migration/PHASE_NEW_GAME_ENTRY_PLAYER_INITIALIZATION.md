# NGE1 — Source-valid Player Initialization Foundation

## Status / scope

**PASS — IMPLEMENTATION COMPLETE / AWAIT OWNER REVIEW.** Same major branch
`phase/source-valid-new-game-entry`, starting at approved NGE0
`e44b00e2287c4548cb3058429fc5454849c460f5`, based on green main
`d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab`. No PR, merge or new CI claim.
NGE2 is not started. Current ApplicationShell New Game is still the Old Pine technical session.

## Source and approved differences

Inspected source paths below are relative to `reference/es2/mudlib/`:

- `adm/daemons/logind.c`: init_new_player attributes/title/potential, cloth move/wear,
  food/water-before-setup, enter_world delayed gift.
- `obj/user.c`: update_age before parent setup; initial age14. No account/login runtime port.
- `std/char.c`, `adm/daemons/chard.c`: setup delegation, current/effective defaults,
  str*5000 encumbrance and corpse copying victim name/age/gender/body facts.
- `adm/daemons/race/human.c`: Human defaults, age/resource formulas and
  `40000 + (str - 10) * 2000` own weight.
- `feature/move.c`, `feature/damage.c`: initial weight0, food/water capacity `weight / 200`.
- `feature/attribute.c`, `feature/dbase.c`: base/adjustment semantics; absent force_factor and
  bellicosity yield effective zero. Existing native typed fields represent these zeros.
- `feature/skill.c`: raw/learned/skill_map start absent, not zero-valued skill records.
- `obj/cloth.c`, `std/armor/cloth.c`, `std/equip.c`, `feature/equip.c`, `include/armor.h`:
  cloth3000, armor+1, cloth slot, direct-owner wear; derived cloth.setup overrides generic
  equip.setup and checks **weight > 3000**, so this cloth has **dodge0**, not-1.

Owner decisions in [DECISIONS](DECISIONS.md): gift **B**, food/water **B**, old saves **A**.
Gift cancellation is a compatibility substitution: no tag, RNG, pending state or age15 callback;
future aging cannot restore it without new analysis/owner authorization. Other normal growth is allowed.
Food correction is explicitly **source execution0/0 vs native compatibility400/400**. It is not a
claim that LPC execution filled food, and is not a general healing/restore policy.

## Typed boundaries / field mapping

| Source fact | Native authority / fresh value |
| --- | --- |
| name / title / age / race | `PlayerIdentityFacts`: caller name, 普通百姓,14, fixed Human identity |
| gender | Existing `CharacterState.gender`; only male/female accepted at this birth boundary |
| str/cor/int/spi/cps/per/con/kar | Existing `CharacterBaseAttributes`, eight30 |
| force_factor / bellicosity | Existing adjustment fields,0/0 |
| combat_exp / potential / learned_points | Existing progression,0/99/0 |
| gin / kee / sen (current/effective/max) | Existing three tracks,100/100/100 each |
| force/max_force, mana/max_mana, atman/max_atman | Existing recovery internal resources,0/0 each |
| body weight / max_encumbrance | Birth output80000/150000 via unchanged CharacterDerivedValues |
| food / water | After body setup, existing recovery fields400/400 |
| skills / learned / skill_map | Existing absent raw/learned mappings and empty enabled uses |
| family / master | Existing empty family/apprenticeship |
| cloth / worn | One real ItemInstance, direct Player child, ArmorState cloth-slot reference |

`NewPlayerInitializationPolicy.create(gender, name)` is Node-free and always creates new state;
it cannot accept/reset an existing Player. It reuses CharacterDerivedValues and CharacterRecovery
capacity helpers, not copied formulas. `NewPlayerInitialization` is a fresh composition, NOT a save
DTO or new long-lived owner of changing body formulas. No gender copy exists in identity facts.
Title is held as a typed fact without manufacturing a HUD consumer; Human identity is deliberately
fixed, not a generic race string input, registry or inheritance framework.

`NewPlayerInventoryComposition.initialize(...)` creates the isolated future-birth item graph using
the caller's existing SessionItemIdAllocator. A successful composition cannot initialize twice.
It creates an ItemDefinition/ItemInstance, registers own weight and the existing derived index,
uses InventoryTransferService to direct character ownership, then ArmorService.wear. No direct
armor-stat increment, invented money/weapon or second Inventory model. It publishes the graph only
on success; invalid input/allocator overflow publishes none. Allocation uses the existing monotonic
allocator (no RNG, no rollback/reuse); no shared mutable defaults.

`SourcePlayerCloth` holds stable `es2:obj/cloth`, metadata `obj/cloth.c`, display布衣, weight3000,
and Item/Armor definition projections. Material has no required native consumer here and is deferred
with tear/bandage crafting. Hands are empty. No sword, dagger, bamboo sword or money exists in the graph.

## Legacy profile / death / save boundary

`WorldPlayerRuntimeState` holds one facts reference; its optional constructor defaults to explicit
`PlayerIdentityFacts.legacy_technical()` (Player, empty unimplemented title,20, Human).
Technical New Game remains eight20, exp600, gin/kee220, sen100, old skills and starting long sword,
Old Pine location and twelve bootstrap items. No source cloth or food refill is added there.

The existing outdoor Player death branch delegates to `WorldPlayerRuntimeState.death_context`,
reading this identity authority and the same existing gameplay/body/equipment sources. Technical
death stays Player/20; a source fixture produces its chosen name/14 through that **same production
projection and outdoor delegation**. NPC and corpse mechanics are unchanged.

Native schema1 contains no Player age/name/title/race fields. Its restore explicitly supplies the
legacy metadata, including independent validation of age20 Player corpse fixtures, without applying
birth or recomputing saved values. The v1 writer rejects a non-legacy facts record as
`UNREPRESENTED_CHARACTER_STATE` at `player.facts` instead of silently losing identity. This is a
narrow representability guard, NOT schema2 or a save migration. New source fixtures cannot yet be
saved by the current Old Pine writer; that is an explicit later dependency before New Game cutover.

## Validation / distinct self-review

- Godot **4.7.2.stable.steam.ed1daf0bf**.
- `run_nge1_tests.gd`: **270 assertions PASS**. Both genders, exact LPC-derived literals,
  capacity-order correction, unknown/blank input rejection, skill absence, real cloth weight and
  wear, empty hands/no money, independent state, one-shot birth and allocator overflow. Structural
  assertions check no gift field or RNG call/source dependency in the new birth files; no production
  property-bag API is introduced. This static RNG check is complemented by dependency self-review,
  not presented as a complete arbitrary-code RNG tracer.
- Old technical fixture checks exact combat facts, startup location/count, death delegation,
  schema1 metadata absence and writer fail-closed guard. Production JSON capture/decode/restore of
  wielded and unwielded old Player fixtures preserves exp731 or0, food-7, water923, str27,
  max_kee357, every semantic item ID and allocator, with no cloth or body recalculation.
- `run_phase_10b3_tests.gd`: **4,230 assertions PASS**. Character, skill, conditions, native item
  save/restore, Inventory, Equipment, Armor, Combined, NPC/loadout, death/corpse, runtime lifecycle,
  resident-map and traversal regressions. Includes dead NPC tombstones, Player corpses and zero-draw
  restored RNG/allocator identity checks.
- `run_phase_10c1a_tests.gd`: **1,039 assertions PASS**. ApplicationShell/New Game, repository,
  transactional Save/Continue and Old Pine. Aggregate executed assertions: **5,539** (overlapping
  regression coverage, not a unique-test count). New tests are registered in the canonical runner;
  the complete historical suite was **not** run in this implementation slice.
- Godot headless editor parsing **PASS**; canonical runner `--check-only` **PASS** (no historical
  tests executed). Repository/static, changed-file trailing whitespace and `git diff --check`
  **PASS**; 57 local Markdown link targets checked. `reference/es2`, scenes, project.godot,
  codec/schema, build/CI/export: **zero delta**. DECISIONS changes are only the three approved choices.

Self-review separates authored identity from CharacterState gender, birth-only values from restored
state, body helper reuse from gameplay redesign, actual cloth authority from fake modifiers, and
LPC execution from owner-approved substitutions. No generic query/set/Dictionary payload, global
state, time, RNG, Node or scheduling dependency in the new initialization foundation. The initial
old-save test had str27 with stale max_encumbrance100000: corrected the **fixture** to135000 to meet
the unchanged validator; production semantics were not weakened.

Live player proof is **not run / not required for this NGE1 boundary**: no scene, input, movement,
UI, combat cadence or entry path is changed; source-player death proof is explicitly authorized as
Node-free/focused. Headless Session regressions are not claimed as screenshot/real-input evidence.
No physical mobile or source-player live death acceptance is claimed. A sandbox-only editor run
reported user-directory/certificate/editor-data access errors; normal-user validation is used for
the final gate, not those environmental diagnostics.

## Deferred / next boundary

No Snow/Inn/Square/route/portal, character creation UI, shops, food interaction, training/economy,
aging/gift RNG, natural recovery schedule, Lake/serpents, Phase5B4, schema2 or world-content revision.
No source initializer is connected to production New Game, Continue, map change, revive or recovery.
Future source-entry runtime and persistence must consume the same facts/equipment/armor authorities;
do not regenerate them independently. NGE2 can be reviewed next only under explicit owner direction.

**STOP — AWAIT OWNER REVIEW. No PR / no merge.**

## Changed files

- New production: `game/core/characters/player_identity_facts.gd`,
  `new_player_initialization.gd`, `new_player_initialization_policy.gd`;
  `game/application/new_game/new_player_inventory_composition.gd`;
  `game/data/items/source_player_cloth.gd`.
- Narrow existing seams: `game/runtime/characters/world_player_runtime_state.gd`,
  `game/runtime/world/oldpine_outdoor_controller.gd`,
  `game/runtime/persistence/oldpine_world_restore_composition.gd`,
  `game/runtime/persistence/oldpine_world_save_capture.gd`.
- Tests: `game/tests/core/new_player_initialization_test.gd`,
  `game/tests/runtime/new_player_legacy_integration_test.gd`,
  `game/tests/run_nge1_tests.gd`, canonical registration in `game/tests/run_tests.gd`.
- Godot-generated `.uid` files for the eight new scripts.
- This document, the NGE0 compatibility contract, DECISIONS, STATUS and ROADMAP.
