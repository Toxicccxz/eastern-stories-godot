# CXR6 Entry Context — Combat Experience Redesign

Documentation-only handoff, inspected 2026-09-04. **CXR6 is not implemented or started by this task.**
This document replaces reliance on the old conversation, not source inspection for future changes.

## 1. Repository snapshot

- Repository: `Toxicccxz/eastern-stories-godot`.
- Branch: `phase/combat-experience-redesign`; upstream is the same branch on `origin`.
- Inspected implementation HEAD: `0e5d052f8e500341bf189e9f0da0e4d7a33b822d`
  (`Implement tactical action queue`). Local/upstream matched after non-destructive fetch, 0/0.
- Initial working tree and index were clean. This handoff adds only this document and small
  README/AGENTS corrections; its subsequent documentation commit is not a gameplay successor.
- Local `main`, fetched `origin/main`, and merge-base all matched
  `ae381bf3f3e5f4a28a417295eea680d023cc428c`. Main remains the stable integration line.
- GitHub search found no open PR from this branch to main. No PR/merge is part of this task.
  The recorded green main gate is [run 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002)
  in [STATUS](../production/STATUS.md); no new CXR integration CI result is claimed.

Recheck git and remote state when resuming. Never reset newer legitimate work to this snapshot.

## 2. Current milestone

Phase10D is **PARKED / FROZEN**: Phase10D3 normal-player acceptance exposed an unsuitable combat
experience. Phase10D1 bounded Android evidence and Phase10D2 packaging remain historical, not a
passed Phase10D3 or reusable post-redesign candidate. Phase10D Final Audit was not started.

The six branch commits after main establish the current sequence:

| Slice | Commit | Completed work |
|---|---|---|
| CXR0 | `96dc923` | Source/current-system analysis |
| CXR1 | `5c99398` | Active Semi-Auto V1 design |
| CXR2 | `cca1ccd` | Typed encounter/participants/sides/modes/results |
| CXR3 | `b57c0e0` | Session-owned controlled encounter and world freeze/return |
| CXR4 | `4a0c6cc` | Encounter-local ordinary-opportunity scheduler |
| CXR5 | `0e5d052` | Tactical request, two validations, one pending slot, typed execution/events |

CXR0-CXR5 are complete on the development branch, **not fully integrated on main**. CXR6 is next
because presentation can now consume real orchestration facts. CXR7 is multi-opponent/mode
completeness; CXR8 terminal/lifecycle/Save/cutover integration; CXR9 proven playability stabilization;
CXR10 final audit/integration. One milestone = this branch = one final PR after CXR10 readiness.

## 3. Current architecture

Intended flow: exploration -> typed `CombatTrigger` -> `CombatEncounter` -> scheduler -> existing
combat authorities/services -> typed results/events -> non-authoritative presentation.

| Owner | Actual responsibility / source |
|---|---|
| Game Core | Existing character/resources/skills/equipment/armor, combat math/resolution/progression/busy authorities; `game/core/` |
| Encounter | Participants, directed hostility, semantic current targets, lifecycle/results and one pending tactical slot; `game/core/combat/encounter/combat_encounter.gd` |
| Coordinator | Session authority resolution, establishment/completion, 0..1 encounter/scheduler, explicit policy registry; `game/runtime/combat_encounter/combat_encounter_coordinator.gd` |
| Scheduler | Injected foreground delta, ordinary opportunities, tactical command boundary and shared event ordering; `game/runtime/combat_encounter/combat_encounter_scheduler.gd` |
| Tactical Runtime | Submit/cancel validation, stored-target checks, execute-once policy dispatch and tactical events; `game/runtime/combat_encounter/combat_tactical_runtime.gd` |
| WorldSimulationGate | One encounter freeze owner; physical world is suspended while encounter processing may continue; `game/runtime/combat_encounter/world_simulation_gate.gd` |
| Session | Exact player/NPC/item authorities, resident maps, RNG sources, coordinator and gate; `game/runtime/world/oldpine_world_session_controller.gd` |
| Presentation | Future projection/intent producer, never a second character, Session, clock, target-validity or damage authority |

`ApplicationShell -> one persistent OldPineGameRuntimeHost -> 0..1 current Session` remains intact.
Encounter bindings reference the **same** CharacterState, relationships, busy and ArmorState;
skills/equipment remain in that CharacterState. No battle clone or second inventory is created.
Session `_process` calls the scheduler; scheduler/tactical classes are RefCounted, without Node/Timer.
Session CombatRandomSource is passed to existing execution services, never replaced by UI RNG.

World freeze is real but conditional on an established encounter: coordinator/gate/map methods
stop the old OpportunityTimer, gate movement, interaction, aggression and traversal, preserve
resident maps/location, then thaw the same world with fresh-input quarantine. Application pause
also blocks encounter advancement: no paused-time accumulation or resume catch-up.

**Cutover is not done.** Coordinator accepts SCRIPTED cause + SCRIPTED mode only. Production
Attack/aggression still use the existing `oldpine_outdoor_controller.gd` playable combat slice,
relationship services and map cadence. There is no dedicated production Battle Presentation.
Do not describe the intended end-to-end redesign as an already deployed player path.

## 4. Tactical request/execution contract

Checked directly in the Encounter, scheduler, tactical runtime, policy and coordinator sources:

1. Input constructs immutable-style `CombatTacticalRequest` metadata: request/encounter/actor/action
   IDs, category and optional target ID. Submission does **not** execute gameplay or receive RNG.
2. Structurally valid unseen requests receive an encounter-local increasing sequence (also when
   subsequently rejected). Duplicate IDs fail; exhaustion fails before signed-64-bit wrap.
   Tombstones/event history are not a second executable queue.
3. Request checks cover ACTIVE/matching encounter, application permission, matching world gate,
   actual Session player ID, exact live authorities, actor availability, registered policy/category,
   target eligibility and `validate_request`. Trusted policy validation must be read-only/RNG-free.
4. `CombatEncounter._queued_player_action` is null or **one** defensive snapshot. Invalid replacement
   preserves the previous slot; valid replacement supersedes it and identifies both sequences/IDs.
   Cancel names the expected current request ID: stale cancellation cannot erase its replacement.
5. NONE/SELF/CURRENT_HOSTILE/SINGLE_HOSTILE are current target rules. Accepted current/explicit hostile
   resolves to a concrete ID. Later current-target changes do not redirect the queued action.
6. At the next **valid scheduler command boundary**, before delta accumulation and ordinary cycles,
   inspect one slot. Zero delta can be a valid boundary. Invalid application/gate/delta/binding checks
   are not boundaries and preserve the slot. At most one tactical attempt occurs, not a queue loop.
7. Recheck live actor/registration; busy-blocked actions wait. Once not busy, recheck stored target
   and independent `validate_execution`. Invalid execution eligibility cancels without cost/action
   RNG, retargeting or substitute attack. Ordinary cadence may independently advance afterward.
8. Clear the slot **before** EXECUTION_STARTED and typed `policy.execute(context, Session RNG)`.
   Result is UNSUPPORTED/APPLIED/FAILED with semantic effect metadata. Null becomes FAILED;
   no implicit retry, requeue or generic rollback is promised for a failed execution.

EMPTY/READY/WAITING_FOR_BUSY is derived, not another busy authority. All non-ITEM categories block
while busy; ITEM has an explicit policy busy flag but no authorized production item behavior.
Busy completes through unchanged ordinary opportunities: busy 2->1->0 consumes those opportunities;
the queued action executes at the following valid boundary, not inside the 1->0 opportunity.

Tactical events include REQUESTED/ACCEPTED/QUEUED/REPLACED/CANCELLED/REJECTED/EXECUTION_STARTED/
EXECUTION_REJECTED/RESOLVED. One scheduler `CombatProgressionOrder` orders tactical and ordinary
streams; existing ordinary sequence/cycle/logical-time remain. Lifecycle history is separate.
The counter is not ATB, readiness, a clock or a global participant turn order.

UI may request, project and format these facts, never deduct resources, resolve hits/death, advance
busy or consume gameplay RNG. This is the tactical boundary, not a claim that all old world HUD
callbacks are already pure requests: existing Attack/equipment paths still delegate to their
existing gameplay services. Policy read-only/statelessness remains a review contract, not deep-const
enforcement by GDScript.

## 5. Production tactical-action inventory

Current native `.gd` inspection across Core/runtime, registration callers and test implementations
found **no production-capable active perform/exert/cast/conjure, tactical-defense, battle-item-use
or encounter-flee policy/service**. Coordinator's production tactical registry is empty.

| Present code | Why it is not a production active technique |
|---|---|
| `game/core/combat/force/standard_force_hit_policy.gd` | Ordinary-hit force integration, not active exert |
| Ordinary action selectors/content profile and `game/runtime/combat_slice/` | Existing ordinary resolution/guard/reverse/progression, not special-action tables |
| `game/core/cultivation/cultivation_service.gd` | Exercise/meditate/respirate training, not an Encounter action |
| Practice/Selflearn/Learn and `game/core/skills/improvement_effects/skill_improvement_effect_registry.gd` | Progression and authored level-up callbacks, not combat commands |
| World inventory/equipment/traversal | Existing interactions, not battle consumables or flee resolution |
| `game/tests/support/cxr5_probe_policy.gd` and test subclasses | Synthetic QA validation/execution, excluded from release with tests |

The probe requires QA skill/mapping, wielded sword and force >= 1; execution draws below 7, spends
one force and adds one target atman. These are **not LPC formulas or authored content**. Busy/reject
variants are also test-only. Never register them in production to make buttons appear functional.

CXR0 inspected legacy perform/exert/cast semantics; legacy existence is not native migration.
Future real techniques require owner-selected scope, direct LPC/dependency inspection and independent
cost/target/busy/RNG tests before typed policy adaptation. This handoff changes no legacy mechanics
and does not re-port or modify `reference/es2/`.

## 6. CXR6 scope to plan next

Dedicated, composable Battle Presentation attached to existing encounter lifecycle: participant and
resource/status views, current/selected/queued-target distinction, Quick Actions/categories, one-slot
queue indicator and cancellation/rejection feedback, readable direct outcome feedback and supplemental
combat log. Categories are intent classifications, not proof all six have usable actions.

Presentation consumes typed facts through a narrow adapter. Use replaceable Theme/visual resources,
semantic presentation metadata and container-driven responsive layout; assets do not determine
gameplay geometry/timing. Preserve shared desktop keyboard/mouse/controller and mobile touch,
SafeArea, modal/Back, focus and lifecycle input semantics.

Telegraph **presentation** is planned, but CXR5 events do not implement an enemy commitment/telegraph
producer. Do not turn a progress bar into gameplay timing. Determine which actual facts can be
rendered now; any unavailable semantic producer or functioning authored action is an explicit
dependency/owner scope decision, not permission to invent a timer or fake successful technique.

## 7. CXR6 non-goals

No combat formula/balance change for UI; invented actions; duplicate authority/queue; animation or
collision deciding results; ATB/readiness/global turn order; generic payload/Callable dispatch;
or UI-owned busy, targeting validity, RNG or cadence. Do not assume full CXR1 planned event coverage
already exists. Do not perform CXR7 multi-opponent/mode completeness, CXR8 terminal/death/corpse/loot/
Save/cutover or CXR9 playability balance early. Do not resume Phase10D or publish a new candidate.

## 8. Open owner decisions

Before committing the first CXR6 implementation scope, settle or explicitly bound presentation
choices: exact initial layout/visual direction, Quick Slot count/configurability, category behavior
with no registered actions, combat-log placement, transition visual and telegraph visual language.
Final art/audio/character-rendering technology can remain replaceable; no lost conversation style
preference should be presumed. CXR6 planning must distinguish a functional input adapter from a
claim of functioning authored techniques.

**Initial authored tactical actions remain unselected.** If the owner requires real action effects
in CXR6, agree a separately bounded source-backed dependency first; otherwise document honest
unavailable controls and isolated QA proof. Neither option has been silently chosen here.

Gameplay decisions still deferred to their owning slice include exact cadence (current scheduler
inherits map interval, not final balance), busy/commitment durations, telegraph duration/enemy action
frequency, tactical-defense effect/opportunity interaction, battle item/equipment permission,
flee cost/formula/destination/consequences, SPAR ending/armed-friendly wounds, and encounter
condition/recovery advancement. Active-Encounter Save is excluded from V1; eligibility/lifecycle
integration is later work. Presentation must not settle these by implementation convenience.

## 9. Verification baseline

Installed engine version re-read for this handoff: **4.7.2.stable.steam.ed1daf0bf**. Historical
[CXR5 evidence](PHASE_COMBAT_CXR5_PLAYER_TACTICAL_ACTIONS_QUEUE.md) at `0e5d052` records:

| Focused runner under `game/tests/` | Passing assertions |
|---|---:|
| `run_cxr5_tests.gd` | 240 |
| `run_cxr4_tests.gd` | 791 |
| `run_cxr3_tests.gd` | 719 |
| `run_cxr2_tests.gd` | 736 |
| `run_phase_6b2_tests.gd` | 1,153 |
| `run_phase_10c2c_tests.gd` | 533 |

Total **4,172 executed assertions**, including overlapping regressions, not unique tests. These are
recorded implementation results, **not newly rerun by the handoff**. Editor import, bounded canonical
main headless load and canonical runner parse checks passed then. Full historical execution was
intentionally **NOT RUN** at this HEAD. `run_tests.gd` invokes CXR2 and CXR5; it does not independently
invoke the complete CXR3 lifecycle/CXR4 scheduler suites. CXR5 reuses a CXR4 fixture, not its full
`run_all`. Retain explicit focused runners and review coverage at final integration; no test code
is changed here and no complete-suite PASS is inferred.

Recorded real CXR5 QA harness embedded the production Session/Outdoor, with declared pre-route
typed setup and deterministic RNG. Real keys proved submit without cost/draw at receipt, one next-
boundary execution, replacement, cancellation, frozen movement with continuing ordinary events,
and same-world completion/fresh movement. Godot AI 3.2.4 run `r108125278-8`: helper_live,
session_active, game_capture_ready all true; current_run_errors empty; non-stale advancing frames
6,166 / 6,944 / 7,465. This proves bounded orchestration, **not a production tactical UI or technique**.

Normal verification commands (from repo root; resolve local executables, do not commit local paths):

```text
godot --version
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/run_cxr5_tests.gd
godot --headless --path game --script res://tests/run_cxr4_tests.gd
godot --headless --path game --script res://tests/run_cxr3_tests.gd
python tools/ci/repository_checks.py
git diff --check
```

Use the other focused runners above as relevant. Full canonical `res://tests/run_tests.gd` belongs
to the appropriate integration/audit gate, not an automatic expensive rerun for this handoff.
See [BUILD](../production/BUILD.md) and [Godot AI development](../production/GODOT_AI_DEVELOPMENT.md).
Canonical main in `game/project.godot` is `res://scenes/application/application_shell.tscn`; normal
player proof starts there. Controlled CXR harnesses are criterion-specific QA exceptions, not a
replacement for real CXR6 UI proof. Verify helper health/errors, non-stale advancing captures and
real input. Diagnose connectivity (validated workstation debug port 6107), never infer gameplay
failure from helper timeout alone. Do not overwrite local debug settings to match another machine.

This task needs only repository/static, relative-link, whitespace and diff/manual checks; no new
gameplay runtime, historical suite or release-build execution is required for documentation.

## 10. One-slice development workflow

DISCOVER / SOURCE CHECK -> ANALYSIS / PLAN -> IMPLEMENT -> FOCUSED TESTS -> **DISTINCT VERIFICATION /
SELF-AUDIT** -> REAL RUNTIME VALIDATION when applicable -> DOCUMENT RESULT -> REPORT TO OWNER.
Only then proceed on the owner's next-slice instruction. Compile/test success alone is not slice
completion. Check boundaries and acceptance evidence independently; report blocked criteria rather
than silently reducing their standard. Do not chain CXR6 into CXR7.

All slices/audit fixes remain on `phase/combat-experience-redesign`; no per-slice branch or PR.
No automatic merge. CXR10 integration requires local/formal gates, one final PR, four green jobs
on the same HEAD, explicit merge authorization and green post-merge main CI. Branch backup push
is not integration. Follow [repository policy](../production/REPOSITORY_POLICY.md).

## 11. New-session resume path

1. Inspect status, branch, HEAD/upstream and recent diff; preserve newer/dirty work. Read root
   [AGENTS](../../AGENTS.md) and [docs instructions](../AGENTS.md), then this entry context.
2. Read [STATUS](../production/STATUS.md), [ROADMAP](../production/ROADMAP.md) and repository policy;
   use current code/git over historical future-tense status tables.
3. Read [CXR1 design](PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md), especially sections 17-35 and 43,
   then [CXR5](PHASE_COMBAT_CXR5_PLAYER_TACTICAL_ACTIONS_QUEUE.md).
4. Read the relevant [CXR2](PHASE_COMBAT_CXR2_ENCOUNTER_CORE.md),
   [CXR3](PHASE_COMBAT_CXR3_WORLD_ENCOUNTER_LIFECYCLE.md) and
   [CXR4](PHASE_COMBAT_CXR4_ACTIVE_SEMI_AUTO_SCHEDULER.md) contracts, implementation paths in
   sections 3-5, their tests/harnesses, and existing Shell/mobile presentation boundaries.
5. Consult [CXR0 source analysis](PHASE_COMBAT_EXPERIENCE_REDESIGN_ANALYSIS.md),
   [DECISIONS](DECISIONS.md), BUILD and Godot AI development for affected dependencies. Directly
   inspect LPC before any separately authorized technique migration; never use an external port.
6. Report current understanding, a bounded CXR6 plan and unresolved owner choices. Await the
   actual implementation instruction; this handoff is not authorization to implement CXR6.

## 12. Known uncertainties and documentation distinctions

- Any unrecorded conversation-only choice of techniques, layout, art, Quick Slot count, timings or
  further implementation authorization: **NEEDS OWNER CONFIRMATION**. Do not reconstruct it by guess.
- README's mobile-foundations-deferred claim was stale and corrected minimally. STATUS/ROADMAP
  already distinguish implemented mobile foundations, bounded Phase10D1 Android evidence and
  incomplete broad Android/iOS/store qualification; they need no wording churn.
- The mobile contract's qualification paragraph records the earlier Phase10C2 AVD-only boundary;
  read it together with current STATUS's later bounded physical evidence, not as a claim that
  Phase10D1 never occurred. Neither is proof of unbuilt mobile Battle Presentation.
- Older CXR documents list future work at their own slice boundary. CXR1's planned event inventory
  is not the current CXR5 event schema. Root AGENTS' Old Pine Session live-example is not a new
  canonical-main override: project.godot/Shell is current; specific QA scenes require disclosure.
- CXR policy stateless/read-only discipline needs continued audit; there is no deep-const enforcement.
  Transient event/tombstone histories are not a persistence contract. Production techniques,
  telegraph producers and final event projection may expose narrow dependencies to resolve before
  promising their UI. These are documented gaps, not silently completed CXR6 work.
