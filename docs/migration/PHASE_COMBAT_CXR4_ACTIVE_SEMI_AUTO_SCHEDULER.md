# CXR4 — Active Semi-Auto Scheduler

## Scope

CXR4 adds encounter-local ordinary-combat cadence to the CXR3 controlled encounter path. A
`SCRIPTED` encounter can now keep the resident world frozen while the encounter advances the
existing ordinary attack/defense pipeline. This slice adds no ATB/readiness/turn system, tactical
action, queue, BattleScene/UI, production trigger cutover, terminal lifecycle, Save field, or
balance change.

## Ownership

`OldPineWorldSessionController` remains the runtime frame boundary. It passes frame `delta` to its
single `CombatEncounterCoordinator`, which owns zero or one `CombatEncounterScheduler` beside the
active `CombatEncounter`. The scheduler is a pure `RefCounted`; it has no `Node`, `Timer`,
`SceneTree`, wall clock, global service, or presentation dependency. Resident maps only project the
current live bindings, skill-effect registry, and current legacy cadence interval; they do not own
or advance the scheduler.

## State and logical time model

`CombatSchedulerConfig` injects one finite positive opportunity interval. CXR4 uses the existing
Old Pine `OpportunityTimer.wait_time` (currently the Godot default of 1 second) as the configuration
value so this orchestration replacement does not introduce a new balance value. CXR1 deliberately
leaves final cadence tuning open; this value is not a new design lock.

`CombatEncounterScheduler` stores accumulated foreground input seconds, completed logical cycles,
the next monotonic event sequence, and typed event snapshots. A due cycle is
`floor((accumulated + 1e-9) / interval)`. Remainder is retained. Logical event time is derived from
`cycle * interval`, never from OS time. Tests prove that `60 * 1/60` and `10 * 0.1` produce the same
cycle, event signatures, RNG bounds, and character state.

## Deterministic ordering

Every due logical cycle visits the immutable stable participant order accepted by
`CombatEncounter`. It does not iterate a `Dictionary`, SceneTree children, runtime object IDs, or
allocation order. This is a cycle of semantic opportunities, not an initiative or ATB queue.

## Participant eligibility

At each visit, the scheduler re-reads the current live binding. A missing, absent,
non-combat-available, or non-`ACTIVE` participant emits a typed skip. An actor whose relationship is
no longer fighting likewise skips. The complete ordered binding projection must still reference
the exact CXR3 `CharacterState`, `CombatRelationshipState`, `ActionBusyState`, and `ArmorState` for
every participant; an incomplete or shadow projection fails closed before time accumulation or RNG.

## Target boundary

`CombatEncounter` owns the semantic current target. On an actor's first eligible opportunity, the
scheduler selects the first currently eligible hostile in encounter participant order and commits
it through `CombatEncounter.set_current_target()`. A stored target must remain present, active,
combat-available, same-location, directed-hostile, and present in the actor's existing relationship.
A stale target fails closed and is not silently redirected.

The ordinary executor gained a narrow optional required-target input. Its default legacy path is
unchanged. The required-target path uses `CombatOpponentSelectionService.prepare_specific()`, which
retains the existing availability validation, cleanup, and `last_opponent` mutation but consumes no
random opponent-selection draw because the encounter already owns the selected target. This avoids
an authored-ID switch and does not duplicate hit, defense, damage, or progression math.

## Busy semantics

`ActionBusyState` remains the sole busy authority. A busy actor still receives its ordered semantic
opportunity; the unchanged ordinary executor advances busy exactly once and returns
`BUSY_ADVANCED`, without executing an attack. A later opportunity proceeds normally after busy
clears. No seconds-based cooldown, animation busy, or scheduler-local busy state exists.

## Existing Combat Core integration

Resolved opportunities call `CombatSliceOpportunityExecutor`, which continues through the closed
fight/guard, action selection, ordinary hit/dodge/parry, force policy, damage/wound, progression,
busy, and synchronous reverse-attack pipeline. Mutations occur on the exact encounter-bound live
`CharacterState` and relationship/busy authorities. CXR4 changes no combat formula, stat, authored
weapon/armor fact, or player/NPC balance.

## Combat RNG

The coordinator supplies the Session-owned `CombatRandomSource`. The scheduler creates no RNG and
uses none for timing, skipped participants, invalid authorities, pause, sub-interval advances, or
completion. Only the existing combat pipeline consumes draws for a resolved opportunity. Typed
ordinary results retain the draw evidence. Equal logical inputs with different delta partitions
consume the same bounds in the same order.

## Typed progression events

Each visited participant produces a `CombatSchedulerEvent` with monotonic sequence, logical cycle,
logical time, actor ID, target ID, and either a narrow typed skip reason or a defensive snapshot of
`CombatSliceOpportunityResult`. `CombatSchedulerAdvanceResult` distinguishes inert, paused, gate
mismatch, invalid delta/authority, accumulated-without-opportunity, and progressed outcomes. These
are future CXR6 presentation inputs; UI strings, animation timing, and display logs are not
authority.

## World freeze and application lifecycle

CXR3 world freeze remains independent of `SceneTree.paused`. While the encounter owns
`WorldSimulationGate`, movement, interaction, portals, aggression, map handoff, and the legacy map
`OpportunityTimer` stay frozen, but the Session continues to pass foreground frame delta to the
encounter scheduler. The old timer never runs beside the scheduler.

Application pause/background remains Shell/SceneTree authority. The Session reports gameplay
inactive, causing scheduler advance to return `APPLICATION_PAUSED` before accumulating delta or
using RNG. Resume accepts only new foreground delta: there is no wall-clock read, catch-up, or
automatic encounter restart.

## Start, completion, and inertness

The coordinator constructs a valid scheduler before acquiring the CXR3 world gate. Invalid
configuration returns typed `SCHEDULER_PREPARATION_FAILED` with no published encounter or frozen
world. Scheduler progression is allowed only for an `ACTIVE` encounter whose ID owns the world
gate. Completion moves the encounter through its existing resolving/completed lifecycle, thaws the
same resident world, and releases both coordinator references. A completed scheduler or a
coordinator without an active scheduler performs no mutation, RNG draw, or event emission.

## Multi-participant structure

The scheduler uses `Array[CombatParticipant]`, open `side_id`, directed hostility, and per-actor
current targets. A three-participant test proves stable actor order and independent target choice
without `player/enemy` fields or a `participants.size() == 2` assumption. Full multi-enemy AI,
player target changes, and encounter-mode completeness remain CXR7 work.

## Production cutover

Normal player Attack, NPC aggression, `fight`, and `kill` still use the existing playable world
slice. Coordinator establishment remains restricted to controlled `SCRIPTED` cause and mode. CXR4
does not expose a production trigger, BattleScene, or new player command.

## Tests

Godot 4.7.2 focused validation passed:

- `run_cxr4_tests.gd`: **791 assertions** across scheduler behavior, CXR3 lifecycle, CXR2 encounter
  core, ordinary opportunity integration, and Session/resident-world authority;
- `run_cxr3_tests.gd`: **719 assertions**;
- `run_cxr2_tests.gd`: **736 assertions**;
- `run_phase_6b2_tests.gd`: **1,153 assertions**;
- `run_phase_10c2c_tests.gd`: **533 assertions**;
- `run_phase_9b3b3_tests.gd`: **2,467 assertions**.

Coverage includes no encounter, sub-interval, wrong gate, invalid delta/authority, exact live
mutation, deterministic delta partitions, busy recovery, application pause/no catch-up, stable
three-participant order, stale targets, completed inertness, frozen world, stopped legacy cadence,
and same-world thaw.

## Real runtime evidence

The QA-only `cxr4_runtime_harness.tscn` embeds the real Old Pine Session and starts only a controlled
`SCRIPTED` encounter through real key input. Godot AI 3.2.4 and Godot 4.7.2 reported
`helper_live=true`, `session_active=true`, `game_capture_ready=true`, and no current run errors.
Captures were live (`stale_frame=false`) with frames advancing from 6,782 to 11,099.

Before start, real `move_right` input moved the player from `(450, 300)` to `(538, 300)`. During the
frozen encounter, real `move_left` input left the body exactly at `(538, 300)`, while the overlay
showed `ACTIVE`, `FROZEN`, scheduler `RUNNING`, legacy timer stopped, cycle 12/events 24, and the
exact NPC vitality changed from 220 to 195 through the existing combat core. Later it showed cycle
46/events 92 without world motion. A real completion key produced `COMPLETED`, gate `OPEN`,
scheduler `INERT`; fresh `move_left` input then moved the body to approximately `(450, 300)`.

## Explicit deferrals

- CXR5: tactical action requests, validation, busy integration, and one-slot queue;
- CXR6: Battle Presentation, UI, telegraphs, feedback, animation, and combat log;
- CXR7: player target changes, full multi-opponent policies, SPAR/LETHAL completeness, and tactical
  NPC AI;
- CXR8: terminal lifecycle/result production, death/corpse/loot return, Save eligibility, and
  application-lifecycle integration beyond the current pause gate;
- CXR9: playability and only evidence-driven balance/cadence stabilization;
- CXR10: final audit, PR, CI, merge, and post-main integration.

## Risks and CXR5 entry criteria

The current 1-second interval is inherited from the playable timer rather than frozen as final
combat balance. Scheduler event history is transient and intentionally unsaved. Until CXR8 consumes
terminal outcomes, a threshold-crossed participant can yield the existing typed lifecycle-required
result but CXR4 does not commit unconscious/death. Until production cutover, the legacy world path
and new encounter path coexist only as mutually exclusive paths, never simultaneous cadence.

CXR5 may begin only by consuming the same active encounter, scheduler ordering, exact authorities,
busy state, target facts, typed events, and Session RNG. It must not add ATB/readiness, recompute
ordinary progression, use presentation callbacks as authority, or open production triggers.

## Sources inspected

No LPC source was re-opened because CXR1/CXR2/CXR3 and the already-audited combat pipeline resolve
the CXR4 semantics without a new legacy ambiguity. Directly inspected native sources included the
CXR1-CXR3 phase documents; `CombatEncounter`, `CombatParticipant`, authority bindings,
`CombatRelationshipState`, opponent selection, `ActionBusyState`, the ordinary opportunity
executor/projections/results, combat RNG, `CombatEncounterCoordinator`, `WorldSimulationGate`, the
Old Pine Session/resident controllers, and the legacy playable `OpportunityTimer` path.
