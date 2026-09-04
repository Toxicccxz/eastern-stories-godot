# CXR3 — World / Encounter Lifecycle Foundation

## 1. Scope

CXR3 connects the Node-free CXR2 encounter model to the existing Old Pine runtime Session. It adds
one Session-owned encounter coordinator, exact live-authority resolution, transactional controlled
establishment, an encounter-owned world simulation gate, deterministic completion, and input
quarantine. It does not add combat scheduling, combat actions, combat formulas, presentation, or a
production trigger cutover.

## 2. Runtime ownership

The existing ownership chain remains `ApplicationShell -> OldPineGameRuntimeHost -> 0..1
OldPineWorldSessionController`. `OldPineWorldSessionController` constructs exactly one
`WorldSimulationGate` and one `CombatEncounterCoordinator`. `CombatEncounter` is transient state in
that same Session; no BattleSession, second world, copied character, autoload, or global manager was
introduced.

## 3. CombatEncounterCoordinator

`game/runtime/combat_encounter/combat_encounter_coordinator.gd` owns zero or one active encounter.
It accepts a typed `CombatTrigger`, resolves Session authorities, constructs and activates the CXR2
encounter, commits world freeze, exposes the active encounter as the future presentation handoff,
and accepts a typed terminal result. Typed start and completion results report exact rejection
boundaries without `Dictionary` payloads.

## 4. Authority resolution

The Session resolves each participant to `CombatEncounterAuthorityBinding` containing the exact
current `CharacterState`, `CombatRelationshipState`, `ActionBusyState`, and `ArmorState`. Player
resolution uses `WorldPlayerRuntimeState`; NPC resolution uses the resident `NpcRuntimeState`.
Tests compare object identity, not copied values.

## 5. Trigger revalidation

Immediately before construction, the coordinator verifies trigger validity, supported cause and
mode, initialized current Session, open gate/no active encounter, active source map, participant
existence, active/living/combat-available status, initiator's exact source location, other
participants' region/map/combat-location coherence, binding validity, and existing relationship
topology. Node presence alone is not permission.

## 6. Establishment policy

CXR3 supports only `SCRIPTED` cause with `SCRIPTED` mode. This is an honest controlled lifecycle
proof and requires a nonempty authored policy ID plus already-valid participant relationship facts.
`PLAYER_LETHAL_ATTACK`, `PLAYER_SPAR`, `NPC_AGGRESSION`, `VENDETTA_HOSTILITY`, and `QUEST` return a
typed unsupported result. They remain structurally representable by CXR2 but are deferred until a
coherent production cutover can progress and exit combat.

## 7. Directed hostility vs CombatRelationshipState

The coordinator derives unique directed side hostility only when an exact participant's existing
`CombatRelationshipState` names an opponent on the target side. It does not mutate relationships,
make them reciprocal, or create lethal markers. Side hostility controls encounter target
eligibility; participant relationship state remains the authority for fight/lethal intent.

## 8. Transactional start

Validation and encounter construction occur before world mutation. The encounter activates locally,
then its ID acquires the gate and the active resident map commits freeze; only then is it published
as active. Freeze failure releases the acquired gate. Every tested failure leaves no active
encounter, the same Session, and an open world gate.

## 9. World simulation gate

`WorldSimulationGate` is a Session-owned `RefCounted` authority with `open` or `frozen for
<encounter_id>` state. Empty acquisition, duplicate acquisition, and release by the wrong ID fail.
It has no Node, Timer, RNG, wall-clock, event queue, or global state.

## 10. What world freeze blocks

The open gate is injected into both resident map controllers and every current
`WorldCharacterBody2D`. While frozen it blocks exploration movement and selection, Outdoor
selection/inspect/loot/inventory/equipment/armor/attack/traversal APIs, Vine and portal traversal,
Session map handoff, Cave SouthExit, zone/location commits, bandit aggression presence/resolution,
corpse range refresh commits, and the existing world `OpportunityTimer` cadence. No NPC roaming
system exists, so none was invented.

## 11. Physics and late-contact safety

Zone, direct cliff-portal, aggression-presence, Cave passage, and Cave exit callbacks check the gate
at their semantic commit boundaries. A queued callback received while frozen is discarded, not
buffered. The existing current-shape `_has_current_zone_contact` validation remains unchanged and
still applies to fresh callbacks after thaw.

## 12. Same-Session invariant

Focused and rendered proofs retain the exact Session, resident Outdoor map, player body,
`WorldPlayerRuntimeState`, and player `CharacterState` identities across start and completion. The
resident map is neither detached nor reconstructed for encounter entry/exit.

## 13. Location preservation

Encounter start and completion do not write `WorldLocationState` or body transform. Focused tests
prove both remain equal across the lifecycle. The rendered proof likewise reports an unchanged
start position while frozen and unchanged semantic location on return.

## 14. Encounter presentation handoff boundary

`CombatEncounterCoordinator.has_active_encounter()` and `active_encounter()` are the sole runtime
handoff fact for a future battle presentation. CXR3 adds no second `battle_active` authority and no
BattleScene, HUD, button, production cheat, or player-visible trigger.

## 15. Completion and return lifecycle

The coordinator validates the external result, commits `ACTIVE -> RESOLVING -> COMPLETED`, captures
the typed terminal result, prepares the resident map for thaw, releases its active encounter
reference, and releases the matching gate owner. Previously running world cadence resumes only when
existing relationships still require it. Fresh world interaction works on the same map afterward.

## 16. Result acceptance boundary

Encounter ID and mode must match; CXR2 validates every referenced side and participant. CXR3 also
restricts result kinds by mode: the currently reachable scripted encounter accepts only a valid
`SCRIPTED` result. `FAILED_TO_ESTABLISH` and lethal/spar shortcuts cannot complete it. Final
victory/defeat generation remains deferred to the owning combat-resolution phase.

## 17. Input quarantine

Freeze immediately zeros movement and quarantines the current exploration action state. Thaw keeps
that quarantine until all movement actions are observed released; only a subsequent fresh press can
move. Inputs and physics contacts rejected during freeze are not replayed.

## 18. Application lifecycle separation

Encounter freeze never writes `SceneTree.paused` and adds no always-processing Node or Timer.
Existing Shell/mobile lifecycle pause remains independent. Focused coverage proves pause/foreground
state changes do not end the encounter or release the world gate. CXR3 has no elapsed encounter time
and therefore no catch-up behavior.

## 19. Save boundary

No save snapshot, schema version, repository, restore, eligibility, or autosave behavior changed.
Active encounter persistence remains deferred to CXR8. Because no production trigger is cut over,
ordinary players cannot enter an unsaved CXR3 encounter state.

## 20. Existing player-visible path and cutover status

With the gate open, existing movement, traversal, aggression, old combat cadence, corpse/loot, Save,
and lifecycle paths remain active. Player Attack and authored aggression still use the existing
playable combat slice. CXR3 deliberately does not route them into the scheduler-less encounter.

## 21. Focused test evidence

`game/tests/run_cxr3_tests.gd` runs the CXR3 lifecycle suite plus CXR2 Core, Session/resident-map,
and portal/aggression regressions. Godot 4.7.2 passed **719 assertions**. Coverage includes invalid,
missing, stale-location, unavailable, unsupported, freeze-failure, concurrent-start and wrong-result
boundaries; exact authority references; asymmetric hostility; gate ownership; cadence/RNG/resource
inertness; handoff/contact/interaction blocking; same-object/location/transform return; application
pause separation; and held-input quarantine.

Additional focused compatibility runners passed unchanged: Phase 6B2 current combat slice and
movement (**1,153 assertions**), Phase 9B3B3 traversal/Vine/Passage/contact and resident-world paths
(**2,467 assertions**), and Phase 10C2B touch/held-input/application lifecycle (**221 assertions**).
The complete historical suite was intentionally not run because these focused runners directly
cover every shared runtime boundary changed by CXR3.

## 22. Rendered runtime evidence

The test-only `cxr3_runtime_harness.tscn` embeds the real production Session and resident Outdoor.
Godot AI 3.2.4 with Godot 4.7.2 reported `helper_live=true`, `session_active=true`, and no run errors.
Real action input moved the body from `(450, 300)` to `(483, 300)` before start. A real key invoked
the production coordinator; the overlay reported `ACTIVE`, gate owner
`encounter:cxr3.rendered_proof`, and position stayed `(483, 300)` during a 20-frame real movement
attempt. A real key-triggered handoff attempt returned `WORLD_SIMULATION_FROZEN` (enum value 2) and
did not change map/location. Completion used a typed scripted result. Held movement across thaw left
the body at `(483, 300)` with quarantine active; release plus a fresh real action moved it to
`(446.3, 300)`. The overlay continued to report the same Session/world and semantic location.
Active, held-after-thaw, and fresh-input captures were current (`stale_frame=false`, frames 6180,
10085, and 11687), and the current game log contained no script/fatal errors.

## 23. Explicitly deferred to CXR4

Encounter-local scheduler, automatic ordinary attack/defense cadence, deterministic delta
accumulation, action opportunity timing, and any encounter progression.

## 24. Explicitly deferred to CXR5/CXR6+

Tactical actions and one-slot queue (CXR5); BattleScene/presentation/telegraphs/feedback (CXR6);
multi-opponent mode completeness (CXR7); death/corpse/loot/Save/lifecycle cutover (CXR8); playability
and narrow balance stabilization (CXR9); final integration (CXR10).

## 25. Risks and follow-up

The production cutover must not occur until CXR4 and a coherent completion path exist. CXR4 must use
the same active encounter and allow its scheduler to run while this world gate is frozen. Future
transition/interactable systems must check the same gate at semantic commits. The map-local freeze
owner is transition bookkeeping that prevents duplicate suspend/resume; the coordinator encounter
and Session gate remain the authoritative active/frozen facts.

## 26. CXR4 entry criteria

CXR4 may begin from this Session-owned coordinator and gate only if it preserves exact participant
authorities, runs independently of frozen world cadence, adds no SceneTree-pause coupling, consumes
deterministic injected combat RNG, produces typed events/results, and keeps current production
combat uncut until the replacement can progress and terminate coherently.
