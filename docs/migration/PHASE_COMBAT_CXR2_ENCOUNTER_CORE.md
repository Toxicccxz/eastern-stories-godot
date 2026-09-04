# CXR2 — Combat Encounter Core

## 1. Scope

CXR2 adds the typed, transient, Node-free encounter domain required by the
[Active Semi-Auto V1 design](PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md). It defines establishment
facts, participants, encounter-local sides and hostility, current targets, monotonic lifecycle,
structural events, and a terminal result. It does not run or present combat.

This slice relies on the completed CXR0/CXR1 analysis and did not rescan `reference/es2/`.

## 2. Implemented Types

Production types live in `game/core/combat/encounter/`:

- closed discriminators: `CombatTriggerCause`, `CombatEncounterMode`,
  `CombatEncounterLifecycle`, `CombatEncounterResultKind`, and `CombatEncounterEventKind`;
- read-only values: `CombatTriggerCandidate`, `CombatTrigger`, `CombatDirectedHostility`,
  `CombatTargetAssignment`, `CombatEncounterResult`, and `CombatEncounterEvent`;
- authority records: `CombatEncounterAuthorityBinding` and `CombatParticipant`;
- mutable aggregate: `CombatEncounter`.

Stable semantic identity follows the existing `StringName` convention. No runtime `ObjectID` is
used as encounter, trigger, participant, side, policy, or location identity.

## 3. Dependency Direction

`CombatEncounter` depends inward on existing Node-free Core authorities and semantic world-location
state. It has no dependency on runtime/world controllers, scenes, UI, presentation resources,
Save DTOs, scheduling, or platform lifecycle. Runtime adapters in later slices may consume the
encounter; the encounter must not depend back on them.

## 4. CombatTrigger Contract

`CombatTrigger` is an immutable establishment request/fact containing a correlation ID, a closed
cause, requested mode, initiator ID, typed candidate/side facts, a copied semantic
`WorldLocationState`, and an optional authored policy ID. Candidate IDs must be unique and the
initiator must be present. Scripted mode requires a non-empty authored policy ID. The trigger
contains no character snapshot, Node, scene, callback, or generic payload map.

## 5. Participant Binding

`CombatEncounterAuthorityBinding` retains the exact supplied `CharacterState`,
`CombatRelationshipState`, `ActionBusyState`, and `ArmorState` objects. `CharacterState` already
owns the exact skill and equipment authorities, so the binding does not duplicate them and does not
introduce an unused `InventoryState` dependency. Copying a participant or binding copies only the
wrapper; authority references remain exact.

The existing `combat_slice_character_binding.gd` remains untouched. CXR3 or a later deliberate
adapter slice can migrate runtime consumers without changing current gameplay first.

## 6. Participant / Side Model

`CombatParticipant` binds one non-empty semantic participant ID to one non-empty encounter-local
side ID and one matching authority binding. The encounter stores a participant collection with
unique IDs. Side IDs are open `StringName` values derived from that collection, not a binary
player/enemy enum. Every accepted participant must match a candidate and proposed side in the
accepted trigger.

## 7. Directed Hostility

`CombatDirectedHostility` is a directed side-to-side fact. Both sides must exist in the encounter,
must differ, and duplicate directions are invalid. `A -> B` does not imply `B -> A`; symmetric
hostility is represented by two explicit facts. This is encounter topology only and does not mutate
`CombatRelationshipState`.

## 8. Target Assignment

`CombatTargetAssignment` maps an actor participant ID to one current target participant ID.
Assignments are accepted only while ACTIVE, only for existing distinct participants, and only when
the actor's side is directed-hostile to the target's side. Each actor has at most one assignment.
Changing or clearing a target is explicit, emits a typed event, and invalid input preserves the
previous target; no automatic retargeting exists.

## 9. Encounter Lifecycle

The closed lifecycle is:

`ESTABLISHING -> ACTIVE -> RESOLVING -> COMPLETED`

or:

`ESTABLISHING -> FAILED_TO_ESTABLISH`

`activate()`, `begin_resolving()`, `complete()`, and `fail_to_establish()` enforce those transitions.
Terminal encounters reject further active mutation and cannot reopen.

## 10. Encounter Result

`CombatEncounterResult` reports semantic outcome facts: encounter ID, mode, closed result kind,
winner/loser side IDs, relevant participant IDs, and an optional stable scripted-result ID. IDs are
non-empty and unique within each collection; winning and losing side sets cannot overlap. Scripted
results require scripted mode and an authored result ID. The aggregate additionally validates that
all referenced sides/participants belong to the encounter and that the mode and encounter ID match.
It grants no rewards and performs no world, death, corpse, inventory, or Save mutation.

## 11. Structural Event Foundation

`CombatEncounterEvent` carries only typed structural facts: encounter ID, a monotonic sequence,
closed kind, phase transition, target transition, or typed terminal result. CXR2 emits establishment,
target-change, resolving-phase, completion, and failed-establishment events. Event values are copied
on entry and return, contain no prose or presentation asset IDs, and use no `Callable` or asynchronous
acknowledgement. Future event kinds can be added without replacing the sequence contract.

Participant-added/removed events are deliberately absent because CXR2 provides no operational
reinforcement/removal API.

## 12. Core Invariants

The aggregate validates non-empty semantic IDs, unique participants, candidate/participant side
agreement, presence of the initiator, matching binding identity, valid referenced sides,
non-duplicated directed hostility, valid unique actor targets, directed-hostile targeting,
monotonic lifecycle and event sequence, matching result identity/mode, and at-most-once terminal
result assignment. Validation returns deterministic failure; required correctness does not rely on
debug assertions.

## 13. Multi-Participant Proof

The focused fixture constructs one participant on side A and two independent participants on side B.
It proves construction, side membership, bidirectional topology through explicit facts, independent
per-actor targets, and non-shared `CharacterState` authorities. The model has no two-participant cap
or global enemy field.

The collection representation can hold later reinforcements without replacement, but CXR2 exposes
no participant-add/remove mutation. That policy remains deferred to avoid premature scheduler and
lifecycle decisions.

## 14. Existing Systems Left Unchanged

CXR2 does not wire the encounter into `OldPineOutdoorController`, the current combat slice,
world/NPC behavior, portals, corpse/loot flow, ApplicationShell, mobile lifecycle, or Save. No
existing production authority was refactored. Player-visible world combat therefore remains exactly
on the pre-CXR2 path.

## 15. Explicitly Deferred to CXR3

- encounter establishment orchestration from existing world triggers;
- world freeze and World-to-Battle transition;
- binding current Session authorities into the encounter;
- BattleScene lifecycle boundary and return to the resident world;
- active reinforcement/removal policy if CXR3 proves it necessary.

## 16. Explicitly Deferred to CXR4

- encounter-local semi-auto scheduler;
- ordinary attack/defense opportunities and cadence;
- timing, elapsed time, readiness policy, and runtime tick ownership;
- use of existing combat resolution services through encounter orchestration.

This design remains explicitly non-ATB and stores no readiness, initiative, turn index, action
points, Timer, or delta accumulator.

## 17. Explicitly Deferred to CXR5+

CXR5 owns tactical actions and the one-slot queue. Later slices own presentation, telegraphs,
combat log, multi-opponent interaction polish, encounter-mode completion, flee execution,
death/corpse/loot/Save/lifecycle consequences, Old Pine balance/playability, and final integration.

## 18. Test Evidence

`game/tests/core/combat_encounter_core_test.gd` contains 141 deterministic CXR2 assertions covering
trigger validation and immutability, exact authority identity, participant/side invariants,
asymmetric and symmetric hostility, valid/invalid target mutations, allowed/rejected lifecycle
transitions, single terminal result, typed monotonic events, and a three-participant encounter.

`game/tests/run_cxr2_tests.gd` combines those with the smallest shared-authority regressions for
Phase 1 CharacterState, Phase 5B1 combat foundation, and Phase 5B3A relationships: 736 assertions
pass. The canonical runner registers the new scripts and CXR2 test, but the complete historical suite
was intentionally not run because CXR2 adds isolated Core code and changes no shared production
authority.

## 19. Risks / Follow-Up

- `CombatEncounterResult` intentionally reports rather than derives an outcome; CXR3/CXR4 must keep
  completion policy outside the value/aggregate.
- Authority bindings are live references by design. Runtime orchestration must create them from the
  one current Session and must not retain them after encounter disposal.
- Side IDs are encounter-local, not faction diplomacy. Establishment policy must construct the
  correct directed topology rather than infer symmetry.
- Events are a read-only history snapshot, not a presentation queue with acknowledgement. Later
  adapters must track their own consumption cursor without mutating encounter truth.

## 20. CXR3 Entry Criteria

CXR3 may begin when this Core parses headlessly, the 736-assertion focused regression passes,
repository/static/document checks pass, and the CXR2 commit is pushed on the same redesign branch.
CXR3 must consume these typed contracts without adding scheduler timing, tactical execution, or
presentation authority to `CombatEncounter`.

Durable status after this slice:

- CXR0 — COMPLETE
- CXR1 — COMPLETE
- CXR2 — COMBAT ENCOUNTER CORE COMPLETE
- CXR3 — READY TO BEGIN
- Phase 10D — PARKED / FROZEN
