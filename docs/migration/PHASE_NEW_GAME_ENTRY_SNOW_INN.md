# NGE2 — Snow Inn Physical Entry + Shared Resident Map Foundation

## RESULT

**PASS — implementation and bounded self-verification complete; AWAIT OWNER REVIEW.**
Branch: `phase/source-valid-new-game-entry`; starting approved NGE1:
`4edcfc3a494409ab1ad50a262ea5dfbb66bd50d9`.
No PR/merge, no New Game cutover, no NGE3 implementation.

Support is deliberately limited: Snow Inn Physical Foundation **YES**; authored NPC population,
services and exit network **NO**. This is not a complete migration of 饮风客栈.

## SOURCE CONTRACT

Rechecked `reference/es2/mudlib/d/snow/inn.c` in full, `include/room.h`, and the directly relevant
`std/room.c::create_door()` construction: `DOOR_CLOSED = 1`, supplied status stored in door data.

- `short`: 饮风客栈; a small inn south of 雪亭镇.
- `valid_startroom = 1`: recorded legacy startroom permission, not a native save-point feature.
- East -> `/d/snow/square`; up -> `/d/snow/inn_2f`; northwest -> `/d/wiz/entrance`.
- Traveller x2 and waiter x1; no runtime NPCs in this slice.
- Northwest 木门 (red wood in prose), initially CLOSED; not a normal-player runtime exit here.
- Ordinary sign reads 饮风客栈. Wizard-only attribution, sign interaction and door behavior deferred.
- Commented bulletin-board call is not active population.

No new birth formula: existing NGE1 `NewPlayerInitializationPolicy` and
`NewPlayerInventoryComposition` remain the authority; see the
[NGE1 source/compatibility record](PHASE_NEW_GAME_ENTRY_PLAYER_INITIALIZATION.md).

## MAP ARCHITECTURE

One compact interior contains a walkable main floor, boundary walls, zone, marker and existing
`WorldCharacterBody2D`. This is a native clustering decision for the currently supported floor,
**not** a general one-LPC-room/one-Godot-scene conversion rule.

ApplicationShell -> persistent Runtime Host -> 0..1 existing Session remains unchanged.
No SnowSession/InnSession, global authority or duplicate inventory/combat system was introduced.
The isolated `tests/qa/nge2_snow_entry.tscn` is a QA fixture, not a second production Session.

## SHARED RESIDENT MAP SEAM

`runtime/world/world_resident_map_controller.gd` extracts the existing neutral physical-map
contract: map/body/location/spawn, initialize/activation/deactivation, resident/encounter-facing
hooks, freeze/thaw and restore staging. It preserves the existing default unsupported outcomes;
there is no new runtime scheduler or speculative world service API.

`configure_world_authorities()` accepts nine explicit typed references: Player, Inventory, stacks,
item index, NPC RNG, combat RNG, world-interaction RNG, item allocator and WorldSimulationGate.
These references are retained, not copied or allocated. Equipment is still on CharacterState;
Armor is still on WorldPlayerRuntimeState. No Dictionary/Callable authority bag or service locator.

`OldPineResidentMapController` is a thin compatibility subclass. Its original configure signature
is retained and forwards the shared references. Only it stores the concrete Old Pine Session and
item scope. Outdoor/Cave no longer duplicate shared field/configuration definitions. Their
initialization requires that specialized Session as before, including when someone attempts
neutral-only injection. The distinct self-review added tests for that fail-closed boundary.

Concrete Session needs stay local: bootstrap/restore modes, restored Player/NPC/corpse data,
encounter coordinator, Cave transition requests and active-map observations. No renaming of
Session, Host, save classes or Old Pine IDs. The current production Session registry is still
Old Pine-specific: the seam is ready for future integration, **not** a claim that Snow is already
registered in a multi-region production Session. No second combat coordinator exists.

## SNOW IDS

| Meaning | Stable ID |
| --- | --- |
| Region | `snow` |
| Map | `snow.inn` |
| Zone | `snow.inn.main_floor` |
| Combat location | `snow.inn.main_floor` |
| Birth spawn | `snow.inn.main_floor.player_birth` |
| Legacy trace | `/d/snow/inn` |

`data/snow/snow_world_definitions.gd` supplies typed MapDefinition, ZoneDefinition and WorldLocation.
Its portal list is empty. No definitions for other Snow rooms or target placeholder maps.

## SOURCE PLAYER RUNTIME

`application/new_game/new_player_runtime_composition.gd` composes an existing birth result with a
typed entry location and fresh relationship/busy state. It retains the exact birth CharacterState,
Equipment, Armor and Player facts; it does not rerun birth, refill or allocate items.
Map code only binds the supplied Player body and simulation gate.

QA uses NGE1 composition: age14, 普通百姓, human, attributes30, exp0, gin/kee/sen100,
food/water400 (approved NGE1 post-body fill), capacity150000, cloth worn/armor1 and empty hands.
Name/age/title/race use the same Player facts, gender stays on CharacterState. Body weight80000
remains in birth initialization; no persistence field is added.

The same Inventory/stacks/index/allocator reach the map; exactly one birth cloth and no additional
items are allocated. Cloth keeps its exact semantic ItemInstanceId. The existing index deliberately
returns immutable identity copies; this is not a new clone of an authoritative inventory item.
QA deterministic seeds21/22/23 are setup only; map initialization consumes zero gameplay RNG draws.

## PHYSICAL INN

`scenes/world/snow/snow_inn.tscn`: placeholder floor960x600, inner boundaries x=+-480/y=+-300,
four StaticBody collision shapes, main-floor Area2D, named WorldSpawnMarker2D at (0,0), existing
34x34 Player body/input stack and Camera2D. No decorative asset migration.

Spawn derives from the marker, checked against the physical rectangular zone shape. Unknown
spawn/location is rejected. Initialization is once-only. Activation does not rebirth/refill;
deactivation disables input/camera. Freeze/thaw respects the injected gate owner and existing
held-input quarantine. Staging uses the inherited runtime Area restoration behavior.

## EXIT BOUNDARIES

All three source exits are known metadata only. No portal/traverse handler, target map, fake
message, Old Pine fallback, wizard access or open/close interaction. Walls remain closed.
`valid_startroom` does not create home/fast-travel/save-point behavior; existing native saves
continue to use exact supported location/position.

## NPC POPULATION DEFERRED

Traveller x2 and waiter x1 are explicitly recorded/tested but not published as NPCs. Scene has
exactly one CharacterBody (Player), no dummy bodies, vendor, food/wine or interaction services.

## SAVE BOUNDARY

Source Snow Player schema1 capture remains **BLOCKED / FAIL-CLOSED** at `player.facts` with
`UNREPRESENTED_CHARACTER_STATE`. A focused test supplies the actual NGE1/Snow Player to the existing
capture boundary as QA only; no Snow save adapter or sidecar is added. Technical Old Pine v1
capture and existing Save/Continue regressions pass. No schema change; formal source save/cutover
remains later-slice work.

## OLDPINE REGRESSION

Outdoor/Cave still have two residents, one active map, shared Player/Inventory/Equipment/Armor,
RNG and gate identities. Existing handoff/failed rollback, freeze, restored placement, NPC/loadout,
corpse, inventory and CXR tests pass. No old route logic was changed by the extraction.
These handoff results are targeted integration evidence, not a new manual Cave traversal claim.

Current ApplicationShell New Game still creates Old Pine, technical Player/20, exp600, starting
long sword, twelve items and the existing five human NPCs. No factory, Session/Host or main-scene
configuration changes. A fresh real UI run separately confirms this path below.

## DESKTOP RUNTIME EVIDENCE

Godot4.7.2; actual game window via Godot AI. Final Inn QA run token2, start33290752:
helper_live/session_active/game_capture_ready all true; startup current_run_errors empty.
Tree: Nge2SnowEntryQA -> SnowInn -> floor/walls, MainFloor, PlayerBirth, Player/Camera.
Read-only probes confirm same Player/Character/Inventory/Armor/allocator, source facts and Snow IDs.

After QA composition, actual keyboard press/release W/A/S/D drove CharacterBody movement. No
position assignment, movement callback, teleport or signal injection substituted for player input:

| Input | Observed stopped position | Evidence |
| --- | --- | --- |
| W | (0, -282.99319) | north wall collision |
| A | (-462.92517, -282.92517) | west wall collision |
| S | (-462.92404, 282.98773) | south wall collision |
| D | (462.92520, 282.92526) | east wall collision; released velocity zero |

Camera center tracked the body. Limits agree with wall interior minus body half-size17.
Final-geometry screenshots frames3262 ->16602, both stale_frame=false, show the floor/walls and
Player. No NPC/combat acceptance claimed. Screenshots are tool conversation evidence, not checked-in
image artifacts. Game stopped after verification.

Canonical fresh main run token5: real mouse New Game -> existing-save confirmation -> Start New
Game. Tree remained ApplicationShell/RuntimeHostSlot/OldPineGameRuntimeHost/SessionSlot/
OldPineWorldSession. Read-only observations: age20, exp600, sword, twelve items, residents2/active1.
Frames2218 ->5675, stale_frame=false; all three helper-health flags true, startup errors empty,
current game log has no runtime error. No Save was performed or existing save replaced.

Evidence hygiene: an earlier main-run probe accessed an empty Session array before confirmation;
another ad-hoc probe failed compilation. Those QA probe attempts and their stale frames are not
accepted evidence. A fresh process and corrected read-only probes produced the final token5 proof.
Six retained editor log entries predated final runs (NGE1 constructor reload and intermediate
base-field extraction reloads); no new logger entries after cursor6. Fresh headless loads and final
live launches are clean. Existing editor static warnings are not claimed eliminated.

## TESTS

Focused commands use Godot4.7.2 `--headless --path game --script res://tests/<runner>`:

| Runner | Passing assertions |
| --- | ---: |
| run_nge2_tests.gd | 70 |
| run_nge1_tests.gd | 270 |
| run_cxr3_tests.gd | 719 |
| run_phase_10b3_tests.gd | 4230 |
| run_phase_10c1a_tests.gd | 1039 |
| Total runner assertions (includes overlapping regression coverage) | 6328 |

Zero failures. NGE2 is registered in run_tests.gd; canonical runner `--check-only` PASS, complete
historical execution deliberately reserved for major audit. The extraction is narrow enough that
resident/CXR/restore/application targeted coverage is appropriate.

Development `--headless --editor --quit`, repository/static checks, diff/whitespace checks PASS.
NGE2 fixture initially retained script resources at exit when eagerly preloading the old Session;
loading that scene at its test step removed warnings with all assertions retained. No production
lifecycle fix was used to mask a test-load issue.

Sanitizer distinction: direct local-worktree preparation fails on ignored
`game/addons/.godot_ai_update/backup/4.0.2` tooling residue (permission first, then forbidden plugin
references). It is not NGE2 content and was not deleted/modified. A clean input copied from
`git ls-files game` plus nonignored NGE2 additions passes the unchanged sanitizer, validate-only,
sanitized headless editor and short canonical startup. QA/tests absent; production Snow map,
definitions, composition and shared seam retained. This proves repository-content release safety,
not success sanitizing the dirty owner-local plugin backup. No packaged/mobile claim.

## OUT OF SCOPE

No NPC/services/sign/door interaction, upstairs/Square/sroads/east roads, Snow handoff, wizard rules,
combat additions, source v1 saving/schema2, character-creation UI, New Game cutover, Lake or Phase5B4.
No legacy source, DECISIONS, build/CI/export/package identity, project.godot or owner-local tooling
configuration changes. No second authoritative Session and no new compatibility substitution.

## NGE3 READINESS

NGE2 provides the typed physical-map seam, source Player composition and valid Inn entry needed
for subsequent planning. Future Session registration and Inn/Square transitions still require their
own authorized implementation and evidence; they are not silently implemented here.
**AWAIT OWNER REVIEW.** No automatic next slice or integration PR.
