# Phase 9B3B1 — Old Pine World Session and Resident Map Lifetime

## Scope and status

Phase 9B3B1 introduces the smallest runtime boundary needed to keep one player and one set of
inventory/combat authorities while moving between two in-memory Old Pine maps. It adds no
Vine interaction, world-interaction RNG, waterfall/river/cliff content, cave maze, secret-passage
traversal, NPC AI, persistence, global world manager, or off-screen simulation.

Phase 9B3B1 is formally closed. The resident multi-map/session-lifetime foundation is also
formally closed. The project main scene is now
`res://scenes/world/oldpine/oldpine_world_session.tscn`.

## Authoritative LPC sources rechecked

- `reference/es2/mudlib/d/oldpine/passage.c`: the minimal Cave representation is the waterfall
  passage only; its authored north/south exits are traceability facts, not both implemented routes.
- `reference/es2/mudlib/feature/move.c`: successful containment/location movement and ordered
  mutation informed the explicit validation/preparation/commit boundary.
- `reference/es2/mudlib/cmds/std/go.c`: ordinary LPC movement clears enemies after a successful
  move. Native cross-map movement translates that intent through current-location availability
  reconciliation rather than embedding `remove_all_enemy()` in a portal callback.

The non-positive `random(bound)` decision also retains the Phase 9B3A evidence from
`reference/es2/mudlib/d/oldpine/epath2.c` and `reference/es2/mudlib/doc/efuns/random`; Phase 9B3B1
does not execute that random stage.

## Session authority

`OldPineWorldSessionController` is the sole owner for one playable session of:

- one `WorldPlayerRuntimeState` and its `CharacterState`, relationship, busy and armor state;
- one `InventoryState`, `CombinedStackCollection`, and `WorldItemInstanceIndex`;
- one combat RNG and one NPC-initialization RNG;
- one session-scoped item-instance ID prefix;
- the prototype player's long-sword instance, created and placed exactly once;
- the resident-map registry and the currently active map ID.

Outdoor and Cave receive these objects through `configure_session_authorities()` before their first
`_ready()`. They never construct fallback player, inventory, index, stack, or RNG authorities.
Map-local authored state remains map-local: Outdoor owns its NPC runtimes, bodies, corpses, loot
views, aggression adapter, HUD, and opportunity timer.

This is runtime composition, not a second save DTO or a global service. Destroying/reloading the
session explicitly frees a detached resident map and recursively frees the active child map. Weak-reference
tests prove that the old Session, Outdoor, Cave, both player bodies, both cameras, Outdoor timer, and a
runtime corpse view are invalid afterward. A fresh session creates a new ID scope and fresh authorities.

## Resident map lifetime

The session instantiates Outdoor and the minimal Cave once. Both perform ready-time binding once;
only one is then attached below `ActiveMapSlot`.

An inactive map is removed from the SceneTree without `queue_free()`, retained by a strong session
reference, and has its player body/camera disabled. Outdoor also suspends its timer and clears
map-presence aggression observations before detachment. Therefore an inactive map receives no
physics, Area overlap, input, `_process()`, `_physics_process()`, timer timeout, combat opportunity,
recovery, condition, or aggression progression. NPC, corpse, loot, signal, node, and physical state
remain in memory and the same map Node is reattached on return.

Before a reactivated map may resume cadence or authored aggression, the session reconciles the
relationships of the player and that map's resident NPCs against current typed location facts.

## Typed map handoff

`handoff_to()` accepts only stable typed IDs:

- destination map ID;
- destination zone ID;
- destination combat-location ID;
- destination spawn-point ID.

It accepts no `Vector2`, `NodePath`, `Callable`, scene callback, or generic Dictionary. The ordered
transition is:

1. validate session/player, destination map, exact zone/combat mapping, and spawn marker;
2. prepare the inactive destination body at its named marker;
3. suspend and detach the source map;
4. commit the player's `WorldLocationState`;
5. attach and activate the destination map;
6. run `CombatOpponentSelectionService.prepare()` with availability facts;
7. allow the active map to resume cadence if a valid relationship remains.

`OldPineMapHandoffResult` records the outcome, failure stage, IDs, and whether preparation,
source detachment, location commit, destination attachment, and reconciliation occurred. A failure
after location commit is explicitly observable as a committed partial transition; the implementation
does not claim full transition atomicity. Its public evidence is read-only and retains no Node, runtime,
inventory, RNG, position, or map-controller reference.

If destination preparation fails, the source remains attached and controllable. If the already validated
logical-location write is rejected by a substitute runtime, the session reattaches and reactivates the
source, reconciles it, and records `source_restored`. If destination activation or reconciliation fails
after logical commit, the committed destination remains the recovery target while both map player bodies
and the destination camera are made non-controllable. No player, inventory, or item authority is rebuilt.

Validation failures mutate neither active-map ownership nor player location. The transition gate
also rejects a concurrent handoff.

## Relationship semantics

The session locates character runtime facts across its resident maps, compares stable
`WorldLocationState` combat IDs, and supplies exact `CombatOpponentAvailabilityFacts` to the closed
opponent-selection service. Cross-map ordinary opponents are removed as unavailable. Independent
lethal-target markers survive the cleanup. If cleanup leaves no opponent, the existing service
performs no RNG draw. Handoff neither advances busy nor executes an attack.

This is the native translation of the gameplay intent in `cmds/std/go.c`; the map/session layer does
not directly mutate relationship arrays and does not recreate directional-command movement.

## Minimal Passage Cave

`res://scenes/world/oldpine/oldpine_cave.tscn` contains only:

- placeholder passage terrain;
- one `PassageZone` for `oldpine.cave.waterfall_passage`;
- a blocked north-passage presentation boundary;
- the exact named marker `oldpine.cave.waterfall_passage.vine_landing`;
- one session-bound player body and camera.

It contains no NPC, corpse, loot, timer, HUD, portal button, river, waterfall traversal, secret
passage, cave maze, serpent, study interaction, or authored random behavior. Phase 9B3B1 exposes
only the lower typed handoff to tests; Outdoor has no player-visible shortcut to the Cave.

## Decisions

`docs/migration/DECISIONS.md` records three explicit compatibility decisions made before production
implementation:

- detached resident maps freeze rather than receive unproven off-screen simulation;
- future non-positive authored world random bounds return an ordered typed ambiguity without an RNG
  draw, clamp, or invented branch;
- cross-map ordinary exits use post-commit typed availability reconciliation rather than immediate
  `remove_all_enemy()` mutation in map code.

## Verification coverage

`game/tests/runtime/oldpine_world_session_test.gd` proves:

- one player and one set of session authorities;
- two retained maps but exactly one active map child/body/camera;
- exact destination validation and zero mutation on invalid handoff;
- inert direct-map loading with no fallback player/inventory/stack/index/RNG authority;
- concurrent transition rejection, destination-preparation failure, pre-commit source restoration, and
  post-commit safe partial failure;
- exact Cave map/zone/combat/spawn commit;
- ordered handoff evidence;
- ordinary-opponent cleanup, lethal-marker retention, no busy advance, no attack, and zero RNG draw
  after cleanup to empty;
- inactive-map freezing across frames;
- stable Outdoor/Cave/NPC/corpse-layer/player-item identity over a round trip;
- one initialization per resident map;
- repeated roundtrips without duplicated Reset/corpse signals;
- explicit destruction of both active and detached resident Nodes and their child bodies/cameras/timer/
  corpse view at the whole-session boundary;
- fresh item scope and item identity in a new session.

The focused runner also covers the closed 9B2, 9B1, 8B2, 8B1, 7B3, 7B2, 6B1, 6B2, and 6B3
runtime slices plus relationship, inventory transfer, equipment, armor, stack/currency, death/corpse,
and NPC foundation regressions. The formal-audit focused run passed **4,019 assertions**. The Phase 9B3B1
test and every converted Outdoor test are registered in the complete runner; the complete project suite
passed **8,180 assertions** in its single post-fix run.

## Formal audit corrections

The audit found and fixed five concrete Phase 9B3B1 problems:

1. `oldpine_world_session_test.gd` was present only in the focused runner. It is now loaded, parsed, run,
   counted, and failure-aggregated by `game/tests/run_tests.gd`.
2. Directly loading an unconfigured Outdoor retained its scene-authored controllable player and enabled
   camera; Cave also had an enabled camera before its controller could disable it. Both scenes now serialize
   an inert body/camera state, and only successful `complete_activation()` enables the active map.
3. A rejected logical-location commit could leave the source detached despite no logical commit. The source
   is now restored through the same activation/reconciliation/cadence boundary, with ordered result evidence.
4. A post-commit activation/reconciliation failure could leave destination control enabled. The destination
   is now explicitly safed while remaining the truthful committed recovery target.
5. Handoff result evidence was publicly writable. It now uses read-only public properties backed by internal
   value fields and still retains no mutable runtime authority.

Godot 4.7.2 MCP save/force-reload inspection confirmed the two-node Session scene, the unchanged 180-node
Outdoor scene, and the 19-node Cave scene with one persisted PassageZone connection. MCP launched the real
main project into playing state, although its game-helper did not reconnect within the inspection window;
independent headless main, direct Outdoor, and direct Cave launches all exited successfully. Headless editor
validation also completed successfully, with only host `user://`/certificate/editor-settings permission
diagnostics and no project parse error.

## Deliberately deferred

- Vine eligibility, ordering, authored RNG, fall/damage, and presentation;
- any player-visible Outdoor-to-Cave portal or return route;
- waterfall, river, cliff, secret-passage, cave-maze, serpent, keep, study, and authored Cave content;
- persistent saves, global world/session management, or off-screen elapsed-time simulation;
- generic portal/transition frameworks and universal map repositories;
- recovery/condition scheduling, NPC heartbeat, autonomous AI, and Combat Phase 5B4 work.
