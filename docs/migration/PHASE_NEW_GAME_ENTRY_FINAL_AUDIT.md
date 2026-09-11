# NGE6 — Source-valid New Game Entry Final Audit

## EXECUTIVE RESULT

NGE0/NGE1/NGE2/NGE3/NGE4/NGE5A0/NGE5A/NGE5A1/NGE5B are owner-approved.
NGE6 audits the complete milestone, not merely the public-menu commit.
Final integration remains gated on the committed-HEAD canonical run and four same-HEAD PR jobs.
No merge is authorized. This document does not claim integration on main.

One confirmed public-entry defect was corrected: the manual Host previously allowed a valid
schema2 technical profile through Continue/Recovery. Public Host now uses
`SourceEntrySaveRepository`, a narrow profile filter over the existing repository, codec,
transactions and candidate restorer. It rejects technical canonical/BACKUP/TEMP files without
writes or candidate construction. Explicit internal fixture coordinators retain technical coverage.
No second serializer, inventory persistence model, slot or fallback was introduced.

A second confirmed defect concerned exact Snow street joins: runtime half-open zone ownership
accepted (0,250), (500,550), (900,550), while restore's strict-interior check rejected all three.
Three failing restore cases reproduced this before the fix. Snow restore now reuses the existing
WorldPhysicalZoneArea2D.contains_center rule; wall/footprint validation and Old Pine rules remain.
Six assertions prove live-zone ownership and exact fresh restoration. No geometry or walking change.

Stale comments calling public source entry “future”/technical were corrected. Public Shell save
fixtures now use captured source snapshots; armed-combat/lifecycle fixtures explicitly request their
technical graph and repository. These are fixture corrections, not reduced gameplay expectations.

## MILESTONE RANGE

- Branch: `phase/source-valid-new-game-entry`.
- Integrated base: `d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab`.
- Approved starting HEAD: `413b62ae701d612cdec152699e58b85ca5e17f9e`.
- Nine approved commits before the NGE6 final audit commit:

```text
e44b00e Define source-valid New Game compatibility contract
4edcfc3 Add source-valid player initialization foundation
b13241b Add Snow Inn physical entry foundation
cbccf98 Add Snow outdoor entry route
6e73cf8 Connect Snow entry route to Old Pine
bab5ee4 Establish Player body facts authority
9a05082 Add versioned source save and continue
3eb83ba Drop pre-cutover save compatibility
413b62a Cut public New Game over to Snow
```

The final PR and owner report identify the immutable final audit SHA and its CI run.

## SOURCE CONTRACT

Authoritative files rechecked (all paths below are under `reference/es2/mudlib/`):

- `adm/daemons/logind.c`: init_new_player, get_name/check_legal_name, enter_world, gift and cloth.
- `obj/user.c`: age14 initialization before character setup; save and full-login context.
- `std/char.c`: composition/setup; heartbeat is not migrated by this milestone.
- `adm/daemons/chard.c`: undefined resource fill, zero-only capacity setup and corpse body copying.
- `adm/daemons/race/human.c`: age14 maxima100 and zero-only Human weight.
- `feature/attribute.c`, `feature/damage.c`, `feature/move.c`, `feature/skill.c`,
  `feature/equip.c`: raw/applied facts, weight/200 capacities, static body/capacity,
  improvement dispatch and equipment modifier lifecycle.
- `daemon/skill/unarmed.c`: new raw level modulo10=9 and str<level/4 -> str+=2;
  this does not call setup or rebuild the body.
- `obj/cloth.c`, `std/armor/cloth.c`: weight3000, cloth slot, armor1;
  the strict weight>3000 dodge clause does not apply.
- `include/globals.h`, `include/login.h`: USER_OB and START_ROOM=/d/snow/inn.
- `d/snow/inn.c`, `square.c`, `sroad1.c`, `eroad1.c`, `eroad2.c`, `eroad3.c`:
  Inn/square exits and five-zone corridor; actual eroad2 exit mapping wins over directional prose.
- `d/oldpine/npath1.c`, `npath2.c`, `npath3.c`, `clearing.c`:
  reciprocal north connection and existing North Approach clustering.

The mudlib remains read-only. No external port was used.

## OWNER DECISIONS

The existing [decision ledger](DECISIONS.md) is unchanged by NGE6.
The milestone adds only the previously approved entries: no delayed age15 gift reroll;
fresh food/water filled AFTER body initialization; independent body exact native continuation;
pre-cutover saves unsupported; native Han name/explicit gender instead of MUD accounts.
Food/water400 is an approved correction, NOT a claim that LPC initialized them to400:
legacy pre-body capacity queries produce0/0. Explicit Save remains policy even though LPC
init_new_player saved immediately. No aging, heartbeat or supply economy is added.

## PUBLIC NEW GAME

Canonical ApplicationShell -> optional overwrite confirmation -> New Journey -> validated
name/gender -> manual Host.request_new_game(name, gender) -> pre-tree SOURCE_ENTRY -> Snow Inn.
There is no public no-argument technical fallback. The Host validates again and only publishes
one successfully initialized Session. Double submit is blocked while STARTING/pending.
Birth itself performs no Save. Existing files survive confirmation, draft and cancellation.

## CHARACTER ENTRY

`NewPlayerNamePolicy`: 1–6 Unicode Han code points, fully anchored; reject empty/whitespace,
Latin/digits/emoji/control/>6 without trimming or replacing. Supplementary Han is tested.
Gender starts unselected and must be male/female. CharacterId remains independent of display name.
Cancel/Escape/Android Back return to menu with no Session/RNG/item allocation or save write.
Recovery's Start New Game uses this same flow; Continue/recovery restore bypass setup.

## PLAYER PROFILE

Human; chosen name/gender; age14; title普通百姓; all eight base attributes30; potential99;
combat_exp0; gin/kee/sen each current=effective=maximum100; food/water400; body80000;
maximum encumbrance150000; one worn `es2:obj/cloth` (weight3000, armor+1);
empty hands; no money; no initial skills.

`NewPlayerInitializationPolicy` owns deterministic birth, `NewPlayerInventoryComposition`
uses existing transfer/wear authority, and `NewPlayerRuntimeComposition` binds that exact result.
Maps and presentation never reinitialize the Player.

## SNOW ENTRY

First authoritative location: snow / snow.inn / snow.inn.main_floor.
First physical position: Inn birth marker (0,0). No intermediate technical Clearing birth.
Inn second floor/wizard doorway/population are traceability/deferred content, not working exits.

## SNOW → OLD PINE ROUTE

Inn <-> Square -> sroad1 -> eroad1 -> eroad2 -> eroad3 <-> Old Pine North Approach -> Clearing.
Snow's five outside rooms form one physical map, not five loading scenes. Local zones use physical
Areas and center ownership; real cross-map passages use named destination spawns.
`SnowOldPineConnectionDefinitions` owns cross-region wiring, avoiding mutual region imports.
NGE6 reruns route regression and real forward/reverse movement between Inn and North Approach;
the unchanged NGE4 Clearing traversal remains supporting evidence. No extra route, Lake portal
or Snow services are claimed.

## SESSION / MAP ARCHITECTURE

ApplicationShell -> one persistent Host -> zero or one current Session.
Public source Session has exactly four residents: Snow Inn, Snow Outdoor, Old Pine Outdoor,
Old Pine Cave. Exactly one is physically attached/active. Others are detached, input-disabled,
camera-disabled and do not simulate. This was read back from the live cold-restored graph.

`WorldResidentMapController` provides binding/activation, not another birth/save owner.
`WorldResidentMapCoordinator` revalidates current passage/contact and commits shared location.
One Player, Inventory, Equipment, Armor, allocator, NPC RNG, Combat RNG, World Interaction RNG,
simulation gate and encounter coordinator persist across maps. Snow has no independent Session.
NGE6 does not alter handoff ordering, geometry, combat cadence or NPC loadouts.

## SAVE / CONTINUE

Root schema2 carries explicit SOURCE_ENTRY_V1, identity/body/CharacterState, Phase4 item snapshot,
equipment/armor, NPC ledger, corpse graph, three RNGs, allocator and map/zone/physical position.
The item schema remains independently v1. Restore builds a fresh hidden graph, injects the exact
restored Equipment/Armor objects, validates placement, and commits through the existing transaction.
It does not rerun fresh birth, grant cloth, fill resources, respawn tombstones or consume new RNG/IDs.

Versioned-source regression covers all source map positions, body growth, altered food/water,
off-map five-NPC ledger, dead tombstones, corpses/nested items, exact recapture and rollback.
Public Shell tests cover fresh Continue plus explicit BACKUP/TEMP re-read, no silent promotion
and failure preserving files/current authority. Public technical files now fail before restoration.

## PLAYER BODY FACTS

`PlayerBodyFacts` is the one runtime authority for body_weight/maximum_encumbrance.
Fresh Human uses 40000+(str-10)*2000 and str*5000 once. Ordinary strength growth does not
refresh either; death/carry use stored facts. Schema2 restores exact stored values.
Tests apply the actual registered unarmed level129 effect (str30->32) while retaining80000/150000.
LPC full-login reconstruction is deliberately not emulated, per the approved decision.

## PRE-CUTOVER SAVE POLICY

UNSUPPORTED. Root schema1/unknown schemas and missing identity/body/revision are rejected;
no migration, fallback, old-field interpretation or automatic deletion. New Game retains explicit
overwrite confirmation and only explicit Save replaces a journey. No save-format version bump
was needed for the NGE6 public profile gate.

## TECHNICAL FIXTURE STATUS

Public reachable = **NO**. Internal regression fixture = **YES**. No compatibility promise.
LEGACY_OLDPINE_V1 and direct technical NEW_GAME remain to support compact Combat/CXR/Old Pine
fixtures. Removing them would broaden the final slice considerably. Their generic codec,
candidate builder and explicitly injected fixture coordinators are NOT public menu alternatives.
`TechnicalShellFixture` is test-only and absent from sanitized builds.
This supersedes earlier evidence of normal manual-Host Continue accepting current technical v2.

## COMBAT / BEAST REGRESSION

Focused CXR, battle presentation, multi-target, flee, resolution, lifecycle/corpse, Old Pine,
mobile presentation and touch regressions: **6,027 assertions / 0 failures / exit0**.
Source/Shell/body/persistence/mobile lifecycle focused: **1,658 / 0 / exit0**.
Physical Snow/Old Pine route focused: **128 / 0 / exit0**.
Source persistence/body focused after street-boundary correction: **332 / 0 / exit0**.
The complete canonical runner additionally includes Beast/serpent, core combat, inventory,
rollback and all prior regression suites. No combat formula or Beast gameplay change.

## DESKTOP ACCEPTANCE

Final canonical production run26 -> process stop -> fresh run27; isolated storage
`user://save-data/tests/nge6-final-public`. QA setup changed only the storage profile/repository
to the SAME public source-only boundary and capped FPS60. It did not call birth/traversal,
set Player position/location, grant state or use a QA source launcher.
Real framebuffer clicks and InputEventKey Unicode events entered 凌雪/female and Start.
Real move_right/down input crossed Inn, Square, sroad1, east corridor and North Approach.
Pause/Save used real input. Fresh process used the actual Continue button, bypassing setup.

- Birth Player object: `-9223371783569143193`; restored: `-9223371649703736522`.
- Cloth semantic ID: `oldpine-session-8ae171dd00f6f3236f9b288b2a101129.dynamic.0`.
- Scope exact; next sequence1 exact; total12 items (Player cloth +11 NPC items), five NPCs.
- Saved/restored position: (450, -332.333465576172), oldpine.outdoor.north_approach.
- RNG states (Combat/NPC/World): `-7183034548769951191`, `720207501874694655`,
  `-4189285052093413211`, exactly unchanged.
- Re-capturing the entire restored graph with the saved metadata produced identical encoded JSON.
- Host invariant true; four residents, one active; all three inactive maps detached,
  controls false and cameras off; shared Player/Inventory/RNG references verified.

Helper_live/session_active/game_capture_ready true; launch current_run_errors=[];
current run27 logs contained only helper/QA telemetry and no runtime errors.
Non-stale frames: setup3644, Inn7845, Old Pine12982 in run26; restored frame4672 in run27.
Frame count is per process, not compared across restart.

After the exact-street-join fix, run28 real Continue -> North Approach -> eroad3 -> east roads ->
Square -> Inn -> Pause/Save succeeded. No state/position injection was used. Inn saved at
(313.333435058594,0); run28 Player -9223371650274161866. Fresh run29 Continue restored
Player -9223371588584338634 at that exact Inn position, with entire encoded graph equality,
five off-map NPCs, four residents and one active map. Non-stale frames6849 (run28 Save) and3430
(run29 Inn); all helper readiness flags true and launch errors empty. Game stopped afterward.

## MOBILE EVIDENCE

Reuse owner-approved NGE5B OnePlus8T packaged startup/setup layout/native keyboard/text input/
invalid-name/gender/Back/Cancel smoke. APK SHA256:
`b18f2b2c302705da5b7f2b4e459d07bba3800d73815ebd487a99e27ece15b9e8`.
This is bounded evidence for that artifact and unchanged input paths, not a claim that NGE6's
new public persistence filter was tested on that old APK. Final PR Android build qualifies compilation.

## DEVICE QUALIFICATION LIMITS

Android Chinese-IME full successful birth was not performed and is deferred, nonblocking by
explicit owner instruction. No keyboard installation/configuration change or name-policy relaxation.
iOS is build validation only; no iOS device gameplay claim. No Android/iOS universal qualification.

## COMPLETE CANONICAL

Final gate: Godot4.7.2, `--headless --path game --script res://tests/run_tests.gd`.
Precommit broad regression passed **18,208 assertions / 0 failures / exit0**, before adding the
six independently reproduced street-boundary assertions. The final candidate therefore contains
**18,214 assertions**. A fresh run on the final committed HEAD is a mandatory pre-PR gate;
its actual exit/result and immutable SHA are recorded in the final PR/owner report, not inferred
from the earlier pass. No test failure, script error or partial run is accepted as PASS.
Any subsequent production/test correction requires another complete final-HEAD run.

## SANITIZER

Python **46 PASS**; repository/static checks PASS.
Development headless editor, sanitized headless editor and sanitized canonical main startup PASS.
Staging is made from Git-listed repository content (including the new source gate), not ignored
owner-local Godot AI backup directories. Owner backups remain untouched.
Sanitizer removes tests/QA/Godot AI and retains Shell/source persistence/Snow maps/route/combat.
No build scripts, CI, export preset, signing, package identity or project.godot change.

## BASE-TO-HEAD AUDIT

The approved starting range had9 commits /144 files /+5836 -613.
NGE6 adds only the audit report, source-only repository/UID, narrow Host selection,
comment corrections and explicit fixture/regression coverage; STATUS/ROADMAP track the gate.
Final statistics are taken directly from `git diff --stat d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab HEAD`
and reported with the immutable PR HEAD (the file inventory is below).
reference/es2=0; build/CI/export=0; project.godot=0.
DECISIONS milestone delta=+98/-0, all previously approved; NGE6 delta=0.
Deleted compatibility is root schema1 writer/reader/missing-field interpretation, not NativeItem v1.
No external ports, generic LPC API, additional global Session or new subsystem were introduced.

## SUPPORT MATRIX

| Capability | Support |
| --- | --- |
| Source-valid public New Game; native Han name/gender | YES |
| Snow Inn physical start; Snow outdoor corridor | YES |
| Snow <-> Old Pine; existing Old Pine gameplay reachable | YES |
| Source Save/cold Continue; identity/body exact persistence | YES |
| Pre-cutover schema1 / public technical save continuation | NO / UNSUPPORTED |
| Full Snow town / Snow NPC population / shops / training | NO |
| Player-reachable Lake / five production Lake serpents | NO |
| Full Beast parity / Phase5B4 | NO |
| Android packaged bounded smoke | YES, NGE5B artifact/limits above |
| Android Chinese-IME full-birth qualification | NOT PERFORMED / DEFERRED |
| iOS physical gameplay qualification | NO; CI build only |

## OUT OF SCOPE

No Snow population/waiter/traveller/dog/trav_blade, economy/supply/training, age progression,
gift reroll, recovery heartbeat, Lake/serpent rollout, Phase5B4, quests/tutorial or art redesign.
No merge, branch/worktree deletion, rebasing or next milestone.

## FINAL PR

Exactly one ready PR: main <- phase/source-valid-new-game-entry, title
**Source-valid New Game Entry**, only after final local gates pass.
Require Godot Verify, Windows Release Build, Android Release Build and iOS Build Validation
completed/success on the same final HEAD. Exact PR/run URLs and statuses belong to the final
owner report/PR record; workflow start is not success. Merge remains NOT AUTHORIZED.

## CHANGED FILE INVENTORY

Repository-relative, base -> final audited tree (including .uid metadata):

```text
docs/migration/DECISIONS.md
docs/migration/PHASE_NEW_GAME_ENTRY_COMPATIBILITY_CONTRACT.md
docs/migration/PHASE_NEW_GAME_ENTRY_FINAL_AUDIT.md
docs/migration/PHASE_NEW_GAME_ENTRY_PLAYER_BODY_FACTS.md
docs/migration/PHASE_NEW_GAME_ENTRY_PLAYER_INITIALIZATION.md
docs/migration/PHASE_NEW_GAME_ENTRY_PUBLIC_CUTOVER.md
docs/migration/PHASE_NEW_GAME_ENTRY_SNOW_INN.md
docs/migration/PHASE_NEW_GAME_ENTRY_SNOW_OLDPINE_CONNECTION.md
docs/migration/PHASE_NEW_GAME_ENTRY_SNOW_OUTDOOR_ROUTE.md
docs/migration/PHASE_NEW_GAME_ENTRY_VERSIONED_SAVE_CONTINUE.md
docs/production/ROADMAP.md
docs/production/STATUS.md
game/application/application_shell_state.gd
game/application/new_game/new_player_inventory_composition.gd
game/application/new_game/new_player_inventory_composition.gd.uid
game/application/new_game/new_player_name_policy.gd
game/application/new_game/new_player_name_policy.gd.uid
game/application/new_game/new_player_runtime_composition.gd
game/application/new_game/new_player_runtime_composition.gd.uid
game/core/characters/new_player_initialization.gd
game/core/characters/new_player_initialization.gd.uid
game/core/characters/new_player_initialization_policy.gd
game/core/characters/new_player_initialization_policy.gd.uid
game/core/characters/player_body_facts.gd
game/core/characters/player_body_facts.gd.uid
game/core/characters/player_identity_facts.gd
game/core/characters/player_identity_facts.gd.uid
game/core/persistence/game_save_json_codec.gd
game/core/persistence/game_save_snapshot.gd
game/core/persistence/game_save_snapshot_validator.gd
game/core/persistence/game_save_value_types.gd
game/core/persistence/world_content_revision.gd
game/core/persistence/world_content_revision.gd.uid
game/data/items/source_player_cloth.gd
game/data/items/source_player_cloth.gd.uid
game/data/oldpine/oldpine_native_item_definition_projections.gd
game/data/snow/snow_oldpine_connection_definitions.gd
game/data/snow/snow_oldpine_connection_definitions.gd.uid
game/data/snow/snow_world_definitions.gd
game/data/snow/snow_world_definitions.gd.uid
game/presentation/layout/application_shell_layout.gd
game/runtime/application/application_shell_controller.gd
game/runtime/characters/world_player_runtime_state.gd
game/runtime/persistence/oldpine_game_runtime_host.gd
game/runtime/persistence/oldpine_map_placement_validator.gd
game/runtime/persistence/oldpine_world_restore_composition.gd
game/runtime/persistence/oldpine_world_restore_preparation.gd
game/runtime/persistence/oldpine_world_save_capture.gd
game/runtime/persistence/source_entry_save_repository.gd
game/runtime/persistence/source_entry_save_repository.gd.uid
game/runtime/world/oldpine_cave_passage_controller.gd
game/runtime/world/oldpine_outdoor_controller.gd
game/runtime/world/oldpine_resident_map_controller.gd
game/runtime/world/oldpine_world_session_controller.gd
game/runtime/world/snow_inn_controller.gd
game/runtime/world/snow_inn_controller.gd.uid
game/runtime/world/snow_outdoor_controller.gd
game/runtime/world/snow_outdoor_controller.gd.uid
game/runtime/world/snow_resident_map_controller.gd
game/runtime/world/snow_resident_map_controller.gd.uid
game/runtime/world/world_character_body_2d.gd
game/runtime/world/world_passage_area_2d.gd
game/runtime/world/world_passage_area_2d.gd.uid
game/runtime/world/world_physical_zone_area_2d.gd
game/runtime/world/world_physical_zone_area_2d.gd.uid
game/runtime/world/world_resident_map_controller.gd
game/runtime/world/world_resident_map_controller.gd.uid
game/runtime/world/world_resident_map_coordinator.gd
game/runtime/world/world_resident_map_coordinator.gd.uid
game/scenes/application/application_shell.tscn
game/scenes/world/oldpine/oldpine_outdoor.tscn
game/scenes/world/snow/snow_inn.tscn
game/scenes/world/snow/snow_outdoor.tscn
game/tests/application/application_shell_phase10c1b_test.gd
game/tests/application/application_shell_phase10c1c_test.gd
game/tests/application/application_shell_test.gd
game/tests/application/mobile_lifecycle_audit_test.gd
game/tests/application/mobile_lifecycle_test.gd
game/tests/application/mobile_touch_audit_test.gd
game/tests/application/mobile_touch_test.gd
game/tests/application/public_source_new_game_test.gd
game/tests/application/public_source_new_game_test.gd.uid
game/tests/core/game_save_json_codec_test.gd
game/tests/core/new_player_initialization_test.gd
game/tests/core/new_player_initialization_test.gd.uid
game/tests/presentation/mobile_presentation_audit_test.gd
game/tests/presentation/mobile_presentation_test.gd
game/tests/qa/nge2_snow_entry.gd
game/tests/qa/nge2_snow_entry.gd.uid
game/tests/qa/nge2_snow_entry.tscn
game/tests/qa/nge3_snow_route.gd
game/tests/qa/nge3_snow_route.gd.uid
game/tests/qa/nge3_snow_route.tscn
game/tests/qa/nge4_source_entry.gd
game/tests/qa/nge4_source_entry.gd.uid
game/tests/qa/nge4_source_entry.tscn
game/tests/qa/nge5a_cold_continue.gd
game/tests/qa/nge5a_cold_continue.gd.uid
game/tests/qa/nge5a_cold_continue.tscn
game/tests/qa/nge5a_source_save.gd
game/tests/qa/nge5a_source_save.gd.uid
game/tests/qa/nge5a_source_save.tscn
game/tests/run_nge1_tests.gd
game/tests/run_nge1_tests.gd.uid
game/tests/run_nge2_tests.gd
game/tests/run_nge2_tests.gd.uid
game/tests/run_nge3_tests.gd
game/tests/run_nge3_tests.gd.uid
game/tests/run_nge4_tests.gd
game/tests/run_nge4_tests.gd.uid
game/tests/run_nge5a0_tests.gd
game/tests/run_nge5a0_tests.gd.uid
game/tests/run_nge5a_tests.gd
game/tests/run_nge5a_tests.gd.uid
game/tests/run_nge5b_tests.gd
game/tests/run_nge5b_tests.gd.uid
game/tests/run_nge5b_ui_regression_tests.gd
game/tests/run_nge5b_ui_regression_tests.gd.uid
game/tests/run_tests.gd
game/tests/runtime/battle_presentation_test.gd
game/tests/runtime/combat_flee_test.gd
game/tests/runtime/combat_multi_target_test.gd
game/tests/runtime/new_player_legacy_integration_test.gd
game/tests/runtime/new_player_legacy_integration_test.gd.uid
game/tests/runtime/oldpine_corpse_loot_interaction_test.gd
game/tests/runtime/oldpine_portal_aggression_test.gd
game/tests/runtime/oldpine_world_restore_test.gd
game/tests/runtime/oldpine_world_session_test.gd
game/tests/runtime/player_armor_interaction_test.gd
game/tests/runtime/player_body_facts_test.gd
game/tests/runtime/player_body_facts_test.gd.uid
game/tests/runtime/player_inventory_equipment_test.gd
game/tests/runtime/snow_inn_foundation_test.gd
game/tests/runtime/snow_inn_foundation_test.gd.uid
game/tests/runtime/snow_oldpine_connection_test.gd
game/tests/runtime/snow_oldpine_connection_test.gd.uid
game/tests/runtime/snow_outdoor_route_test.gd
game/tests/runtime/snow_outdoor_route_test.gd.uid
game/tests/runtime/versioned_source_save_test.gd
game/tests/runtime/versioned_source_save_test.gd.uid
game/tests/support/beast_persistence_fixture.gd
game/tests/support/game_save_test_fixture.gd
game/tests/support/oldpine_world_save_fixture.gd
game/tests/support/public_new_game_test_fixture.gd
game/tests/support/public_new_game_test_fixture.gd.uid
game/tests/support/technical_shell_fixture.gd
game/tests/support/technical_shell_fixture.gd.uid
```
