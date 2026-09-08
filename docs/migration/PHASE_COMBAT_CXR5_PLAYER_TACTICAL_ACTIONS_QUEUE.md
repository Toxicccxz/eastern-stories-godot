# CXR5 — Player Tactical Actions + One-Slot Queue

## 1. Scope

CXR5 extends the accepted [CXR4 scheduler](PHASE_COMBAT_CXR4_ACTIVE_SEMI_AUTO_SCHEDULER.md)
with player requests, a single Encounter-owned pending action, two validation boundaries, and
typed tactical execution/events. It implements orchestration, not new ES2 techniques or balance.
Work remains on `phase/combat-experience-redesign`, starting from `4a0c6cc`.

## 2. Tactical request model

`CombatTacticalRequest` is a read-only value with request/correlation ID, encounter ID, actor ID,
registered action ID, category, and optional semantic target ID. The queue takes a defensive copy.
There is no generic payload, callback, Node, asset, inventory item clone, or copied CharacterState.

## 3. Categories

The closed category discriminator contains MARTIAL_SPECIAL, INTERNAL_FORCE, SPELL,
TACTICAL_DEFENSE, ITEM, and FLEE. A request's category must match its registered policy. These
values classify intent; none selects a formula, cost, cooldown, or damage implementation.

## 4. Registry / policy boundary

`CombatTacticalActionRegistry` explicitly registers `CombatTacticalActionPolicy` instances by
stable ID and rejects duplicate registrations. No file-path/service-locator/Callable dispatch exists.
The base policy fails unsupported. Policies expose read-only ID/category/target-rule/busy metadata,
independent `validate_request` / `validate_execution` methods, and typed `execute`.

Policies are trusted, stateless code: validation must not mutate authorities or consume RNG.
`CombatTacticalContext` exposes only exact Core actor/optional target authority wrappers, retaining
CharacterState, relationships, ActionBusyState, and ArmorState. Skill and equipment truth remains
inside the same CharacterState. The execution method alone receives the Session CombatRandomSource.

## 5. Evidence-backed production action status

**Production registry is empty. No production tactical action was invented or wired.** The native
Core/runtime scan found no migrated perform/exert/cast/conjure service. Direct inspection of
`game/core/combat/force/standard_force_hit_policy.gd` confirms it is an ordinary-hit integration,
not an active exert action. Skill improvement effects are level-up callbacks, not active skills;
Cultivation is training, not an in-Encounter action.

`game/tests/support/cxr5_probe_policy.gd` is deliberately synthetic and excluded with all tests by
the existing release sanitizer. Its QA prerequisite checks force >= 1, a QA raw skill and enabled
mapping, and a currently wielded sword. Its QA execution draws below 7, deducts one force, and
adds one target atman. These values are test probes, NOT LPC-derived gameplay formulas or content.
Other test-only policies independently reject execution or set existing busy for commitment proof.

Inspected native authorities include CharacterState/CharacterInternalResourceState,
CharacterSkillState, EquipmentState, ActionBusyState, CombatRelationshipState, authority and slice
bindings, ordinary scheduler/executor/selection/results, StandardForceHitPolicy,
SkillImprovementEffectRegistry, Session/coordinator/gate, and existing CXR2-CXR4 fixtures.
No new legacy mechanic or unresolved formula was migrated, so no LPC source re-scan was necessary.
`reference/es2/` remains entirely unchanged.

## 6. Request IDs / monotonic sequence

Correlation IDs are caller-supplied semantic IDs, separate from the monotonically increasing
runtime sequence. Every structurally valid unseen request gets a sequence, including a subsequently
rejected request. Duplicate IDs fail without allocating another sequence. Encounter-local
tombstones retain rejected, replaced, cancelled, and attempted IDs; they are not pending actions.
An exhausted signed 64-bit sequence fails before incrementing. No timestamp, frame, ObjectID, or RNG
defines identity/order. A new Encounter runtime owns a new correlation namespace.

## 7. Request-time validation

Submission checks the active encounter/ID, application foreground permission, matching world gate,
current Session player ID, exact live authority identity, actor presence/ACTIVE/availability,
registration/category, target rule/current availability/location/relationship/hostility, and policy
prerequisites. Invalid replacement never changes the existing slot. Submission is RNG-free and
mutation-free with respect to gameplay authorities; only transient request/queue/event state changes.

## 8. Execution-time validation

The scheduler first validates ACTIVE phase, application permission, world gate, finite nonnegative
delta, RNG/effect dependencies, and the complete exact binding projection. In that same synchronous
boundary the tactical runtime rechecks actor/registration/category and, when not busy, the stored
target and independent execution prerequisites. There is no persistent validated bit.
Failure clears the pending action and emits EXECUTION_REJECTED plus CANCELLED, without spending cost,
drawing action RNG, retargeting, or substituting ordinary combat. Ordinary cadence may independently
progress afterward. Invalid scheduler gates are not command boundaries and preserve the queue.

## 9. Target snapshot semantics

Minimum rules are NONE, SELF, CURRENT_HOSTILE, and SINGLE_HOSTILE. NONE rejects a supplied target;
SELF resolves the actor; CURRENT_HOSTILE resolves the Encounter's current target at acceptance;
SINGLE_HOSTILE requires an explicit eligible hostile. An explicitly conflicting SELF/current target
is rejected. `CombatQueuedAction.resolved_target_id` preserves the concrete semantic ID. Later
current-target changes cannot redirect a queued action; loss of eligibility cancels it.

## 10. One-slot queue ownership

`CombatEncounter._queued_player_action` is the only pending-action authority: null or one typed
action. Narrow Core APIs expose defensive snapshots, replacement, expected-ID clearing, and queue
invariants. The Encounter contains no policy execution, RNG, or scheduler. Runtime event history
contains historical snapshots, not executable pending entries. There is no Array queue or second
ready slot. The existing resolving transition clears the transient slot.

## 11. READY versus WAITING_FOR_BUSY

`CombatTacticalRuntime.queue_status()` derives EMPTY/READY/WAITING_FOR_BUSY from the slot, registered
policy, and exact ActionBusyState. Status is not a second busy authority. READY can become WAITING
if busy changes after acceptance. All non-ITEM categories block while busy. ITEM has an explicit
policy-level busy setting; only test fixtures exercise its bypass, and no battle item is authorized.

## 12. Replacement

A valid new request replaces the existing READY or WAITING slot. REPLACED identifies the old
request, new request ID, and new sequence; ACCEPTED and QUEUED identify the replacement. The old
request is tombstoned and cannot later execute. Invalid new input preserves the previous request,
sequence, target, and busy state exactly.

## 13. Cancellation / stale cancellation safety

Cancellation names the expected request ID, checks active/application/gate permission, and clears
only that current slot. Cancelling A after B replaced it returns STALE_CANCEL and leaves B intact.
READY and WAITING cancellation are supported; no resource, busy, or RNG mutation occurs.

## 14. Scheduler command boundary

At the beginning of each valid foreground `advance`, before CXR4 delta accumulation or ordinary
cycles, snapshot the one slot. A still-busy action remains queued. A ready action is execution-time
validated, then cancelled or consumed and executed once. A valid zero-delta advance is also a
command boundary, but does not manufacture an ordinary opportunity. At most one tactical attempt
occurs per boundary; no loop drains requests or creates a tactical clock.

## 15. Input versus scheduler ordering

An input receipt means READY for the NEXT valid boundary, never execution inside the input callback.
Input accepted before a boundary is considered there; input accepted after it waits for the next.
This explicit total ordering, not an assumed `_input`/`_process` callback order or shared frame
number, defines the result. CXR4's interval, remainder, participant order, and target logic are intact.

## 16. Busy progression

With busy=2, the first boundary waits and the ordinary opportunity performs 2->1. The second waits
and the consumed ordinary opportunity performs 1->0. The action stays queued throughout that
opportunity and executes at the following valid boundary. Other participants retain their ordinary
opportunities. A test policy's exact busy=2 commitment is likewise consumed by the unchanged
ordinary busy gate; no universal skip/cooldown rule is added.

## 17. Tactical execution

The runtime clears the expected slot before EXECUTION_STARTED and the typed policy call. Results
distinguish UNSUPPORTED/APPLIED/FAILED and carry a semantic effect ID, not localized strings or
presentation assets. A null policy result becomes a typed FAILED result. Execution failure is not
validation failure: there is no generic rollback, repeat, requeue, or fallback action. Actual
authored services must later retain their own honest mutation/result semantics.

## 18. RNG rules

Only policy execution receives the injected CombatRandomSource. Validation, submit, replacement,
cancel, waiting, invalid advancement, and pause consume zero tactical draws. Independent ordinary
opportunities retain their own original draws. Tests compare exact requested bounds/order as well
as counts and state. No tactical RNG or global random API exists.

## 19. Tactical event ordering

Tactical history uses typed REQUESTED, ACCEPTED, QUEUED, REPLACED, CANCELLED, REJECTED,
EXECUTION_STARTED, EXECUTION_REJECTED, and RESOLVED snapshots. Each carries request/actor/action/
category/target/sequence through the typed action record and an explicit reason/result.

One scheduler-owned `CombatProgressionOrder` supplies `progression_order` to both tactical and
ordinary events. Future presentation may merge those two streams by this integer, without wall
time. Existing ordinary `sequence`, logical cycle/time, and result remain unchanged. With no
tactical events, the new order matches ordinary sequence. This is an event counter, not a second
clock or queue; CXR2 lifecycle history remains separate.

## 20. Ordinary auto-combat interaction

The queue never globally stops ordinary attacks/automatic defense. Tactical work precedes the
same-call ordinary cycles; policy-authored busy is naturally handled by the existing executor.
No blanket ordinary-opportunity skip, tactical-defense numeric effect, or passive hit-hook reuse
was introduced. Empty-queue equivalence is tested with and without tactical configuration.

## 21. Multi-participant target safety

The fixture has Player, Enemy1, and Enemy2 with independent exact state objects. Player explicitly
queues Enemy2 while ordinary current target is Enemy1: only Enemy2 gets the probe mutation. A
CURRENT_HOSTILE request queued for Enemy1 still targets Enemy1 after current target becomes Enemy2.
Unavailable targets cancel; no two-actor/global-enemy assumption exists.

## 22. Application lifecycle

Existing Session/application permission remains authoritative. SceneTree pause preserves queue,
busy, elapsed remainder, and RNG. Resume uses only new foreground delta and the next command
boundary; there is no catch-up. Focus/Back/held-input and Shell code are unchanged. Pure and real
Session integration tests cover pause; the existing Phase10C2C regression covers the unchanged
Shell/mobile lifecycle paths.

## 23. World freeze

Session still drives the scheduler while the matching Encounter owns WorldSimulationGate. Resident
world movement and the old OpportunityTimer stay frozen. Completion clears the slot, emits a
typed cancellation if needed, releases the scheduler/Encounter, and thaws the same resident world.
NPC-only scripted encounters retain CXR3 behavior without creating a player tactical interface.

## 24. Save boundary

Queue, requests, sequence tombstones, policies, and events are transient. No Save snapshot, version,
eligibility, schema, repository, restoration, or autosave code changed. Active-Encounter persistence
and eligibility integration remain CXR8 work.

## 25. Production cutover status

Coordinator establishment remains SCRIPTED/SCRIPTED only. Normal Attack/aggression/fight/kill and
ordinary player gameplay remain on the existing playable slice. No production UI/button/trigger,
BattleScene, enemy tactical AI, or active technique has been introduced.

## 26. Focused test and self-audit evidence

Godot 4.7.2 results:

| Runner | Passing assertions |
|---|---:|
| `run_cxr5_tests.gd` | 240 |
| `run_cxr4_tests.gd` | 791 |
| `run_cxr3_tests.gd` | 719 |
| `run_cxr2_tests.gd` | 736 |
| `run_phase_6b2_tests.gd` | 1,153 |
| `run_phase_10c2c_tests.gd` | 533 |

The 4,172 executed assertions include overlapping regressions, not 4,172 unique tests. New coverage
includes both validators, all categories, empty/unknown/deferred/duplicate/stale input, sequence
exhaustion, exact authority, shared stateless policy independence, queue immutability, resource/
mapping/raw-skill/weapon/life/relationship/target invalidation, three participants, busy commitments,
replacement/cancellation ordering, execute failure without retry, no action substitution, exact RNG,
completion, and pause. `60 * 1/60` and `10 * 0.1` agree under equivalent request schedules; remainder
comparison respects CXR4 floating-point precision. The first test attempt used exact float equality
for remainder; it was corrected to approximate comparison, without changing scheduler arithmetic.

The new test is registered in the canonical runner for future integration. That runner passed
parse-only validation; the full historical suite was intentionally NOT executed per CXR5 scope.
Development editor import and bounded canonical main headless load passed. Initial sandbox-only
certificate/user-directory/ADB/editor-settings errors were resolved by rerunning the same Godot
checks in the normal workstation context; no project/debug configuration changed.
Repository/static checks, documentation placement/relative links, `git diff --check`, and trailing
whitespace checks passed. Forbidden production dependency scans found no tactical Node/Timer,
Callable/generic Dictionary, global RNG, or test-resource reference.

Self-audit confirmed one pending slot, no synchronous input execution, separate validations,
defensive target snapshots, exact state ownership, shared typed event order, no global RNG/Timer,
no Node in tactical domain/policy, no universal cooldown/ATB, and unchanged ordinary math/cutover.

## 27. Real runtime evidence

The test-only `cxr5_runtime_harness.tscn` embeds the production OldPineWorldSession and real resident
Outdoor. It prepares QA skill/mapping/force and scripted relationship/location facts before the
claimed route, injects a deterministic zero-draw source into the Session, and registers only the
test probe. No production formula/default was changed. Real key input submits to the coordinator;
automatic Session `_process` advances the scheduler. No MCP direct policy/controller execution
substituted for the input route.

Godot AI 3.2.4 / Godot 4.7.2 reported helper_live=true, session_active=true,
game_capture_ready=true, current_run_errors=[], and no new editor errors. Run `r108125278-8`:

- Real movement moved the player from (450,300) to approximately (486.6666,300), then key 1
  established the controlled encounter. Frozen movement input left that position unchanged.
- Key 3 receipt recorded request `qa.input.1`, ACCEPTED, force 10->10, RNG 198->198, queue READY.
  The next scheduler boundary executed exactly once: force=9, NPC atman=1, resolved=1.
- Key 4 submitted two requests before the next boundary: the latter replaced the former. Result:
  resolved=2 total, replaced=1, force=8, NPC atman=2; only the replacement executed.
- Key 5 submitted/cancelled a request: force 8->8, RNG 641->641 at receipt, cancelled=1. It never
  executed. Ordinary events grew from 74 to 188 while world gate stayed frozen and legacy Timer
  stayed stopped.
- Non-stale captures at frames 6,166 and 6,944 showed continued live progression. Key 2 completed
  at cycle 100 / ordinary events 200. Fresh left input then moved the same body to (178.6671,300).
- A post-completion key 3 returned INACTIVE, force 8->8, RNG 902->902, queue EMPTY. Frame 7,465
  remained non-stale, tactical resolved stayed 2, scheduler INERT, and world gate open.

The helper was stopped cleanly after proof. These are bounded QA orchestration proofs, not a claim
that production tactical UI or playable authored techniques exist.

## 28. Deferred to CXR6

BattleScene, action buttons/Quick Slots, target visuals, telegraphs, combat log, animations, VFX,
audio, asset catalogs, and responsive presentation. CXR5 contains no production presentation assets.

## 29. Deferred to CXR7

Full multi-opponent interaction/policies, additional target rules, reinforcement/removal,
SPAR/LETHAL completeness, and enemy tactical selection. Three-participant semantic safety is
foundation evidence, not a claim of full multi-opponent gameplay.

## 30. Deferred to CXR8+

Terminal outcome generation, flee destination/consequences, unconscious/death/corpse/loot return,
Save/lifecycle integration and production cutover; later evidence-driven playability/balance and
major-phase audit/PR/CI integration. Exact defense, flee, item categories, active martial/internal/
spell effects and their costs/commitments still require authored evidence and owning-slice approval.

## 31. Risks / follow-up

Policies must continue to be trusted stateless typed implementations; GDScript has no deep-const
view of mutable character authorities. Future policies require independent source-derived tests,
not reuse of the synthetic probe as gameplay. Event/tombstone histories are Encounter-local and
transient; future presentation should use a read cursor rather than rebuilding UI from full history
every frame. Existing scheduler advance result describes ordinary progression; tactical outcomes
are read from their separate ordered stream, including zero-delta tactical-only boundaries.

No unrelated CXR2/CXR3 lifecycle or ordinary combat behavior was redesigned. No changes were made
to `reference/es2`, DECISIONS, Save, Phase10D, build/CI, production UI/world, or combat balance.

## 32. CXR6 entry criteria / status

Typed input can queue without executing, inspect defensive slot/status, replace/cancel safely,
consume typed rejection/result facts, and merge tactical/ordinary event order. Validation and
execution use current exact authorities and the Session RNG, with deterministic command boundaries
and no-action CXR4 equivalence proven. CXR6 may build presentation on these interfaces, but may not
invent production techniques merely to fill buttons.

- CXR0-CXR4 — COMPLETE
- CXR5 — PLAYER TACTICAL ACTIONS + ONE-SLOT QUEUE COMPLETE
- CXR6 — READY TO BEGIN (not implemented)
- Phase10D — PARKED / FROZEN

This is implementation completion on the redesign branch, not final major-phase integration.
No PR or merge is part of this slice.
