# NGE3 — Snow Outdoor Corridor + Inn ↔ Square Handoff

## RESULT

**PASS — implementation, self-review, complete canonical and desktop route verification complete;
AWAIT OWNER REVIEW.** Same major branch `phase/source-valid-new-game-entry`, starting approved NGE2
`b13241b3a96955e9422ba30b8a956b5aa1bc8144`. No PR or merge; no NGE4/cutover.

Snow Outdoor Physical Route = **YES**; Snow Outdoor NPC Population = **NO**.
ApplicationShell still starts the technical Old Pine New Game, not this QA entry.

## SOURCE CONTRACT

Fully reread these authoritative files under `reference/es2/mudlib/`:

- `d/snow/inn.c`
- `d/snow/square.c`
- `d/snow/sroad1.c`
- `d/snow/eroad1.c`
- `d/snow/eroad2.c`
- `d/snow/eroad3.c`
- `d/oldpine/npath1.c` — destination evidence only; not implemented.

Inn facts remain those recorded by [NGE2](PHASE_NEW_GAME_ENTRY_SNOW_INN.md): 饮风客栈,
south of Snow town, valid_startroom1, three exits, closed northwest 木门, ordinary sign name,
traveller x2/waiter x1 deferred. NGE3 opens only the authored east route.
Square short is 广场; all five outdoor sources set `outdoors = snow`.
Square's commented worker entry is not active population. Eroad3 `no_clean_up = 0` is not a
native unload scheduler. Eroad2/3 prose direction differs from executable exits: the inspected
exit table controls connectivity, without rewriting the prose or adding a compatibility decision.

## SNOW OUTDOOR TOPOLOGY

One continuous `snow.outdoor` map contains Square -> south to sroad1 -> east through
eroad1 -> eroad2 -> eroad3. No scene load, teleport or Player reconstruction between these zones.
Inn is one separate interior map. Only its east/Square west doorway pair changes physical maps.
This is native map clustering, not one LPC room per scene.

## ZONE MAPPING

| LPC reference | Native zone / combat-location ID | Map |
| --- | --- | --- |
| `/d/snow/inn` | `snow.inn.main_floor` | `snow.inn` |
| `/d/snow/square` | `snow.square` | `snow.outdoor` |
| `/d/snow/sroad1` | `snow.sroad1` | `snow.outdoor` |
| `/d/snow/eroad1` | `snow.eroad1` | `snow.outdoor` |
| `/d/snow/eroad2` | `snow.eroad2` | `snow.outdoor` |
| `/d/snow/eroad3` | `snow.eroad3` | `snow.outdoor` |

`SnowWorldDefinitions` supplies typed map/zone/portal definitions. Combat-location IDs are stable
and nonempty; no combat is introduced. `WorldPhysicalZoneArea2D` supplies rectangular physical
membership, not a second authoritative location. Physics body-enter/exit events track overlapping
candidate Areas. Only while contact needs resolution does the map check those candidates against
the character center; this is not a coordinate-room switch or an all-world per-frame room guess.

Adjacent rectangles are half-open: a center on a shared edge belongs to exactly one rectangle.
The single typed Player WorldLocation is retained on exit until a valid adjacent center owner is
accepted. It is never cleared to an empty zone or replaced by a set of simultaneous zones.
Nonadjacent, foreign-map, unknown or nonphysical candidates are rejected. Physical test routing
checks valid location/single active map and records the exact forward/reverse zone history.

## DEFERRED EXITS

All sixteen outdoor exits are explicit traceability metadata; metadata does not execute travel.

| Source | Implemented connectivity | Known, nonexecutable boundaries |
| --- | --- | --- |
| Square | west Inn; south sroad1 | north mstreet1; east Snow temple |
| sroad1 | north Square; east eroad1 | west sroad2; south `/u/cloud/dragonhill/nroad` |
| eroad1 | west sroad1; east eroad2 | north Snow temple |
| eroad2 | west eroad1; east eroad3 | none |
| eroad3 | west eroad2 | east `/d/temple/sroad`; south `/d/oldpine/npath1` |

Inn up/inn_2f and northwest/wizard reception remain deferred. No fake target, fallback teleport,
loopback or travel-message substitute. Eroad3's south wall blocks movement: npath1's north exit
back to eroad3 is future source evidence only. No Old Pine connection in this slice.

## DEFERRED NPC POPULATION

Square trav_blade x3 and eroad2 dog x2 are recorded, tested and intentionally absent. No dummy
bodies, waiter/traveller, shops, vendor, food/wine or unrelated Snow content. Each map contains only
its physical Player body, both bound to the same gameplay Player.

## SHARED HANDOFF

`WorldResidentMapCoordinator` is a narrow Node base extracted from the existing Session's
physical residency/handoff implementation. `OldPineWorldSessionController` inherits it;
the isolated Snow QA root inherits the same implementation. No copied Snow handoff algorithm,
SnowSession, global singleton or new authority graph.

Extracted ownership: resident registry, active-map ID, transitioning flag, active physical slot,
last handoff result, Player/gate references and physical transition methods. The existing
`OldPineMapHandoffResult` public name is retained deliberately to avoid unrelated consumer churn;
it contains typed transition facts, not an Old Pine service dependency.

Old Pine retains birth/restore construction, inventory/RNG authorities, NPC/corpse lifetime,
combat coordination, relationship reconciliation, application swap and save behavior. Its existing
reconciliation override is called at the same point. The base's no-content reconciliation is only
used by the empty Snow fixture; this does not implement Snow combat/relationship processing.

Actual inherited ordering: validate -> destination prepare -> unstage destination -> source
deactivate/detach -> location commit -> destination attach/activate -> relationship reconciliation
-> resume. Preparing destination before detaching source preserves the existing failure behavior.
Source location is additionally checked against the source map's typed location resolver.

Unknown destination, invalid marker/zone/source, frozen gate and preparation failure leave source
and location intact. Existing commit-rejection restoration remains shared. Existing *post-commit*
activation/reconciliation failure remains an explicitly reported partial transition with controls
safed, not falsely advertised as atomic rollback; the historical tests for this still pass.
This slice does not redesign that established failure policy.

Inactive maps are detached from SceneTree: no process/input/physics Area monitoring occurs in-world.
Only the active body controls input and camera. Restored staging semantics remain unchanged.

## INN ↔ SQUARE

- Inn fresh spawn: `snow.inn.main_floor.player_birth`, (0,0).
- Square arrival: `snow.square.inn_entry`, (-200,0).
- Inn return: `snow.inn.main_floor.square_return`, (350,0), deliberately not fresh spawn.
- Executable portal IDs: `snow.inn.east`, `snow.square.west` only.

Inn east wall now has a genuine doorway and physical trigger; Square west has the return opening.
Collision backstops prevent escaping the corridor if travel is unavailable. Maps emit a typed
PortalDefinition request; the shared coordinator defers detachment outside the physics query flush.
It rechecks active source, location and current physical passage membership before executing.

Implementation verification found and fixed reattachment replay: stale Area contacts initially
caused extra Inn/Square bounces. Contact now only arms a physical-center check; the deferred request
also checks current physical membership. The exact eleven-entry route-history test detects any
recurrence. This is runtime contact hardening, not a change to LPC topology.

Distinct self-review also restored pre-initialization guards in prepare/complete activation before
accessing scene/Player references. Two tests verify an unconfigured controller refuses both calls.
This preserves NGE2 failure behavior; it does not alter the initialized physical route.

## AUTHORITY CONTINUITY

NGE1 `NewPlayerInventoryComposition` + NGE2 `NewPlayerRuntimeComposition` create one source Player
before map binding. No birth values are duplicated in map code. Both maps retain the same Player,
CharacterState, Equipment, Armor, Inventory, CombinedStackCollection, item index, allocator,
combat/NPC/world RNGs and WorldSimulationGate.

Return does not refill, grant cloth, allocate IDs, replace state or reset skills/progression.
Tests mutate food/water/experience before a boundary round trip and confirm preservation, while
the separate fresh physical route keeps400/400, exp0 and one cloth. Same semantic cloth ID persists;
existing item-index immutable identity projections remain unchanged. No invented recovery clock.

## PHYSICAL ROUTE

Placeholder ground and static collision form an L-shaped continuous route: wide Square, narrow
south road, east corridor and eroad3 southern end. Physical zone extents are authored in the scene,
not encoded as world-room conditionals. Interior/exterior reuse the existing CharacterBody2D/input
and Camera stack through `SnowResidentMapController`, with no final art/audio or new movement rule.

## SAVE BOUNDARY

Source Snow Player remains schema1 **FAIL-CLOSED** (`player.facts`), covered by the preserved NGE1/2
tests in canonical. No schema2, sidecar, identity discard or technical-Player impersonation.
Technical Old Pine v1 capture/restore/Continue and their exact state/position contracts pass.
This is not a Snow save/load implementation.

## CURRENT NEW GAME

**UNCHANGED.** Real ApplicationShell New Game still enters `oldpine.outdoor`: Player/20, exp600,
`es2:d/oldpine/obj/long_sword`, twelve bootstrap items, residents2/active1. The bounded Snow fixture
lives under tests/qa and is absent from sanitized output. No Host, factory or project.godot cutover.

## OLDPINE REGRESSION

Same shared handoff executes Outdoor/Cave forward/return, preserves identities and spawn/location,
reconciles relationships at the original point, respects freeze and failure stages, and supports
restore staging/position plus NPC/corpse/item continuity. CXR3 focused719 PASS; complete canonical
includes the old Session, Save/Continue, application, combat, source birth and item regressions.
No new manual Cave traversal claim is made; its evidence here is the complete regression suite.

## LIVE DESKTOP

Godot4.7.2, final Snow run token9 (`r36647333-9`), real game window. Setup only: isolated fresh
birth, deterministic QA RNG seeds21/22/23, rendering capped at60 FPS for frame-timed input. No
production timing/configuration or movement speed changed. After setup, all traversal used normal
WASD-mapped `move_*` input press/release events via Godot AI input_sequence. No position setter,
direct handoff, zone setter or synthetic Area signal was used for acceptance.

| Observation | Active zone | Actual position, rounded |
| --- | --- | --- |
| Birth | Inn main floor | (0,0) |
| East doorway -> Square | Square | (-9.33,0) |
| South | sroad1 | (-9.33,550) |
| East | eroad1 | (284,550) |
| East | eroad2 | (687.33,550) |
| East | eroad3 | (1090.67,550) |
| South wall collision | eroad3 | (1090.67,821.00), collision count1 |
| Return west | eroad2 | (687.33,549.59) |
| Return west | eroad1 | (284,549.59) |
| Return west | sroad1 | (-9.33,549.59) |
| Return north | Square | (-9.33,-0.41) |
| West doorway -> Inn | Inn main floor | (346.33,0), after one further held-input step |

Last handoff names the square_return marker; both maps initialized once. Exact history contains
those eleven zones in order (south-wall observation does not add another zone). Same twelve
authority ObjectIDs compared as strings before/after: all equal. Player ID
`-9223371846701807500`; cloth `nge3-fixture.dynamic.0`; allocator sequence1; one item; food/water400;
exp0. Both bodies bind the same Player; only returned Inn control/camera enabled, Outdoor detached.
Camera center equals final Player position. No source Player mutation or extra items.

Helper_live/session_active/game_capture_ready all true. Screenshots frames772 ->8845 ->16944,
all stale_frame=false, show Inn birth, eroad3 closed south boundary and Inn return. Startup
current_run_errors empty; final current-run log only helper registration, no runtime errors.
Evidence is in tool conversation captures, not fabricated checked-in screenshots.

Fresh canonical main run token10: actual New Game button -> Start New Game confirmation;
read-only facts match the technical baseline above. Frame8201 nonstale; helper healthy; no game
errors. No Save or overwrite was performed. Earlier intermediate editor reload errors remain
historical; final runs started after cursor9 and the subsequent editor logger has no new entries.
The later pre-initialization guard correction leaves this initialized route unchanged; its evidence
is retained, with focused and complete canonical rerun against the corrected final code.

## TESTS

- `run_nge3_tests.gd`: **142 assertions, 0 failures, exit0** after contact and initialization guards.
- `run_nge2_tests.gd`: **70 assertions, 0 failures, exit0**; only east-portal expectation updated
  for this authorized slice, other birth/identity/save boundaries retained.
- `run_cxr3_tests.gd`: **719 assertions PASS, exit0** immediately after shared extraction.
- **Complete** `--headless --path game --script res://tests/run_tests.gd`:
  **17,377 assertions PASS, 0 failures, exit0**, including NGE3. Not check-only.
  Generated local log: `build/nge3-canonical-final.log`; no ERROR/SCRIPT ERROR/WARNING/FAIL lines.
- Development and sanitized Godot4.7.2 headless editor validation PASS.
- Repository/static, diff and changed-file whitespace checks PASS.

Sanitizer input is a clean copy of tracked game files plus nonignored NGE3 additions. As documented
in NGE2, ignored owner-local Godot AI update backups break direct-worktree sanitization; they were
not modified/deleted. The unchanged sanitizer passes on repository content, removes all tests/QA,
and retains Snow definitions/maps/shared runtime. No build/CI gate weakening or packaged/mobile
validation claim.

## OUT OF SCOPE

No npath1/Snow–Old Pine link, mstreet/temple/sroad2/dragonhill, NPC population, shops, other doors,
upstairs/wizard reception, character creation, age/recovery clock, schema/world-content revision,
New Game cutover, Lake, serpents or Phase5B4. Reference/es2, DECISIONS, build/CI/export/package
identity, project.godot and owner-local tooling unchanged.

## NGE4 READINESS

The continuous source-valid route reaches eroad3 and the authoritative future npath1 boundary.
The shared residency seam and same-authority round trip are proven. NGE4 still requires explicit
owner authorization; no connection, save change or next-slice implementation is implied.
**AWAIT OWNER REVIEW.**
