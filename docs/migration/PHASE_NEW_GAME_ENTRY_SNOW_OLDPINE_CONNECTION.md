# NGE4 — Snow / Old Pine North Connection

## RESULT

**PASS — implementation, self-review, complete canonical and real desktop route complete;
AWAIT OWNER REVIEW.** Same milestone branch `phase/source-valid-new-game-entry`, starting at
`cbccf98318620394fb7f5109384e2da36cdda981`. No PR, merge, NGE5 or public New Game cutover.

## SOURCE CONTRACT

Fully rechecked these authoritative files under `reference/es2/mudlib/`:

| File | Executable connection retained |
| --- | --- |
| `d/snow/eroad3.c` | south -> oldpine/npath1; west -> eroad2; east -> temple/sroad |
| `d/oldpine/npath1.c` | north -> snow/eroad3; south -> npath2 |
| `d/oldpine/npath2.c` | north -> npath1; southeast -> npath3 |
| `d/oldpine/npath3.c` | northwest -> npath2; east -> clearing |
| `d/oldpine/clearing.c` | west -> npath3; existing climb-pine behavior unchanged |

The eroad3/npath2 descriptions are not substituted for their executable exit directions.
Birth values/formulas are not reimplemented: this slice calls the closed NGE1/NGE2 compositions.
No new compatibility substitution or DECISIONS entry.

## EXISTING NORTH APPROACH REUSE

`oldpine.outdoor.north_approach` still clusters npath1+npath2+npath3. Existing geometry,
zone and source references are reused; no new npath scenes/zones or room-by-room teleports.
The physical North Approach / Clearing arrangement remains the approved native clustering,
not a claim that the original npath3 east exit is literally south.

## CROSS-REGION PORTALS

`game/data/snow/snow_oldpine_connection_definitions.gd` owns only the two typed cross-region
portals and their stable target marker IDs. Neither region definition imports the other.

| Portal | Source / direction | Destination / marker |
| --- | --- | --- |
| `snow.eroad3.south` | Snow outdoor, eroad3 / south | Old Pine North Approach / `oldpine.outdoor.north_approach.snow_entry` |
| `oldpine.npath1.north` | Old Pine North Approach, npath1 / north | Snow eroad3 / `snow.eroad3.oldpine_return` |

`WorldPassageArea2D` carries a stable portal ID and binds a typed PortalDefinition plus owning
map. Each passage tracks its own Player contact/pending request. It requires the current body
center inside the real rectangle, active Player control, correct source map/zone and an open gate.
This retains NGE3's protection against stale Area contacts after resident reattachment.
The deferred coordinator rechecks the passage and source, then validates destination location,
marker/zone membership and gate using the existing handoff implementation.

Snow outdoor now supports its local Inn passage and the separately configured Old Pine passage.
There is no node-name parsing, Variant payload dispatcher or new world graph service.
The source-entry composition alone enables the cross-region pair. Without configuration their
blocking collision segments remain closed, including in technical NEW_GAME and legacy RESTORE.
Physical backstops prevent leaving the map when a passage cannot execute.

Existing pre-commit failure and explicit post-commit partial-failure semantics remain unchanged.
No new blanket rollback promise: this slice does not redesign NGE3/Old Pine transactions.

## SOURCE-ENTRY SESSION PROFILE

The existing `OldPineWorldSessionController` gains one explicit pre-tree `SOURCE_ENTRY` profile.
`configure_source_entry(name, gender)` rejects late/repeated configuration and invalid selections.
The default remains technical `NEW_GAME`; `RESTORE` is separate and unchanged.

The source branch calls `NewPlayerInventoryComposition.initialize()` (which calls the birth policy)
and `NewPlayerRuntimeComposition.create()`. It adopts their exact inventory/stacks/index, Character,
Equipment, Armor and Player facts. It never calls the technical Player factory or copies birth values.
One Session owns all RNGs, allocator, gate and CombatEncounterCoordinator.

Snow receives neutral `configure_world_authorities()`; Old Pine maps retain specialized
`configure_session_authorities()`. Active-map lookup, cleanup and existing map-delegated operations
use the neutral resident type; detached Snow maps are freed with the Session. No Host rewrite,
Session swap, second gameplay Session or serialization-copy transfer.
Only name presentation now resolves PlayerIdentityFacts instead of the literal "Player".

## RESIDENT MAP SET

- Technical NEW_GAME / legacy RESTORE: **2**, Old Pine Outdoor + Cave. No Snow registration.
- Source-entry: **4**, Snow Inn + Snow Outdoor + Old Pine Outdoor + Cave.
- Exactly **1** active map child. All four initialize once; inactive maps are staged/detached,
  with Player input/camera disabled.

Cave remains because the existing Old Pine outdoor vine traversal depends on it. No Cave content
or additional acceptance route was introduced. Removing it would change already reachable gameplay.

## PLAYER AUTHORITY CONTINUITY

Tests and real route compare 14 exact objects: Player, Character, Equipment, Armor, PlayerIdentityFacts,
Inventory, CombinedStackCollection, WorldItemInstanceIndex, allocator, NPC/combat/world RNGs, gate,
and CombatEncounterCoordinator. All map bodies bind the same Player; no Player is born during travel.
The source profile remains age14, eight attributes30, exp0, food/water400/400, one worn cloth and
empty hands. Total Session items are12 (one source cloth plus the existing11 NPC loadout items),
not12 Player items. Allocator dynamic sequence remains1.

## OLD PINE NPC CONTINUITY

Existing three ordinary bandits, tall bandit and fat bandit initialize using the unchanged production
definitions/loadout paths and Session NPC RNG. Source birth consumes no NPC RNG: same-seed technical
and source bootstraps finish at the same NPC RNG state. Leaving/re-entering Old Pine preserves all
five runtime objects and initialization count1; no reroll, duplicate graph, replacement ledger or serpent.
Source exp0/empty hands successfully bind the existing combat projection; victory is not required.

## NORTH APPROACH

New entry marker is **(450, -380)**, physically inside the existing North Approach Area.
`spawn_matches_zone()` checks the marker against that rectangle, not just its name.
The existing technical PlayerStart is unchanged. Initializing the inactive Outdoor binds its physical
body but does not overwrite the authoritative Snow birth location. Actual cross-region handoff
prepares the new north marker before committing the first Old Pine location as North Approach.
Clearing is reached by continuous movement within the same map.

## SNOW RETURN

North passage returns to eroad3 marker **(1100, 730)**, never Square/Inn. Walking back through
eroad2/eroad1/sroad1/Square uses the existing Inn west passage and east-side Inn return marker.
No rebirth/refill, cloth grant, skill reset or allocation occurs.

## SAVE BOUNDARY

Actual source-entry Session capture fails closed at `player.facts` with
`UNREPRESENTED_CHARACTER_STATE`. No schema2, sidecar, discarded identity or legacy impersonation.
Technical v1 capture and existing encode/decode/restore/Continue regressions pass in canonical.
Source Save/Continue and public cutover remain NGE5, not supported by this slice.

## CURRENT NEW GAME

ApplicationShell defaults remain unchanged. Real main-menu New Game and its normal confirmation
create Old Pine Player/20, exp600, starting long sword,12 bootstrap items and2 resident maps.
Snow is not silently registered; the technical north passage stays blocked. No UI profile selector.

## LIVE DESKTOP

Godot4.7.2; QA run token12 / `r39822168-12`, production Session/maps beneath
`Nge4SourceEntryQA -> OldPineWorldSession -> ActiveMapSlot`.
The launcher selects "Snow Player", male and deterministic existing RNG seeds.
Before the route, QA sets `Engine.max_fps=60` solely for reproducible frame-timed input.
All acceptance movement then uses normal movement input actions and physical Areas; no position
assignment, zone setter, direct handoff, signal emission or combat-state boost.
Read-only probes observe the route; they do not execute it.

Observed sequence:
Inn -> Square -> sroad1 -> eroad1 -> eroad2 -> eroad3 -> North Approach -> Clearing ->
North Approach -> eroad3 -> North Approach (extra re-entry) -> eroad3 -> eroad2 -> eroad1 ->
sroad1 -> Square -> Inn.

- First Old Pine position exactly(450,-380), first marker `north_approach.snow_entry`.
  After the remaining held movement it is(450,-372.6667); this is not a spawn discrepancy.
- Clearing reached physically at(450,151.6665); reverse return observed in eroad3 at(1100,726.3333)
  after one further held movement step from its730 marker.
- Final Inn return marker is `snow.inn.main_floor.square_return`; observation(346.3333,0)
  after one additional held step from350, not the birth center.
- All14 authority IDs were captured as strings (no JSON integer precision loss) and compared equal.
  Player ID: `-9223371844772427547`.
- Same cloth: `oldpine-session-d2454a2ea23f7552ffb4e90d691310b0.dynamic.0`;
  all8 attributes30, exp0, food/water400/400, empty hands, sequence1 throughout.
- All5 NPC IDs equal before/after re-entry; initialization1. Final NPC RNG state
  `-1136062569884875933`, combat `-7542915721565470398`, world
  `-6705295025768092158`, each equal to its initial state.
- Final4 map bodies bind that same Player; only Inn is attached, controlled and camera-enabled;
  every map initialization count1.
- Helper live/session active/capture ready true; current run errors empty, game log only helper
  registration, editor cursor9 has no new entries.
- Non-stale screenshots with advancing frames: Inn2362, North Approach12117, Clearing13780,
  Snow return15682, final Inn27970. These are live tool evidence, not claimed committed image files.

Canonical ApplicationShell is separately launched as run token13 / `r40359948-13`.
Real framebuffer clicks on New Game and Start New Game confirm profile0, Player/20, exp600,
`es2:d/oldpine/obj/long_sword`,12 items,2 residents,1 active child, no Snow registration and
the north blocker still enabled. Screenshot8263 is non-stale; helper healthy, no current errors
or new editor-cursor entries. No Save was requested and existing user save files were not replaced.

## TESTS

- NGE4 focused: **123 assertions,0 failures,exit0**, no error/warning at exit.
- NGE2 focused regression: **70 assertions,0 failures,exit0**.
- NGE3, CXR/encounter/aggression/freeze/Flee/death/corpse/inventory/map transitions, restore and
  ApplicationShell regressions are included in the complete canonical execution below.
- Invalid destination, missing marker, mismatched zone, invalid source, frozen gate and preparation
  failure are tested separately from physical input acceptance; source remains valid/attached.
- All four resident nodes are invalid after Session disposal, including detached Snow nodes.
- Initial focused-run test errors were corrected against existing API names. A subsequent eager
  runner load retained27 GDScript/native-class objects (no live gameplay nodes); a short production
  QA startup and NGE2 comparison exited cleanly. Loading the NGE4 test at runtime removed the
  warning with all assertions intact. No production lifecycle change masks this test-load issue.

## COMPLETE CANONICAL

`--headless --path game --script res://tests/run_tests.gd`:
**17,500 assertions PASS;0 failures;exit0**. Actual complete suite, not check-only.
Log: `build/nge4-canonical.log`; no ERROR/SCRIPT ERROR/WARNING/FAIL lines.
No complete-suite repeat was needed.

Development headless editor, repository/static, diff/whitespace/link checks, repository-content
sanitizer, sanitized headless editor and canonical short startup PASS.
As in NGE2/3, input is tracked game files plus nonignored additions, excluding ignored owner-local
Godot AI upgrade backups. Those backups/configuration are untouched. The unchanged sanitizer removes
tests/QA and retains production Snow scenes, cross-region definitions, passage and Session code.
No APK/mobile or packaged artifact playability claim.

## OUT OF SCOPE

No source Save/Continue, schema2/world-content-revision persistence, public cutover, character creation,
Snow NPCs/supply/shops/training, mstreet1/temple/sroad2/dragonhill, Inn2F/wizard reception, Lake,
five serpents, Phase5B4, final art or large Session rename. Reference/es2, DECISIONS,
build/CI/export/project configuration remain unchanged; no PR/merge.

## NGE5 READINESS

The source Player can reach existing Old Pine gameplay from the source path within one Session,
and physically return. Full Snow/population and source Save/Continue are not claimed.
NGE5 may be considered next only after owner review and explicit authorization.
**AWAIT OWNER REVIEW.**
