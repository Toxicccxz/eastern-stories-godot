# CXR6 — Battle Presentation

## Status and source boundary

Implementation and desktop runtime validation complete; affected physical mobile
requalification **PENDING**. This is a slice completion, not major-milestone
integration. CXR7 has not started. Phase 10D remains PARKED / FROZEN.

- Branch: `phase/combat-experience-redesign`.
- Starting HEAD: `6cd4283effe8671620437d6a963579a0f8a6a9fb` (CXR6 handoff).
- Prior gameplay HEAD: `0e5d052f8e500341bf189e9f0da0e4d7a33b822d` (CXR5).
- Integrated main baseline: `ae381bf3f3e5f4a28a417295eea680d023cc428c`.
- Upstream: `origin/phase/combat-experience-redesign`; initial tree clean.
- Ending implementation commit: `70d778bac7041b9a4a429246e2155ae55fbe2ea5`.
  This documentation-only finalization is a separate successor; the final pushed
  HEAD is reported in the delivery message. No implementation changes follow that SHA.
- No new branch, PR, merge, force push, release, or Phase 10D work.

Authority is the owner-resolved CXR6 instruction and the
[CXR1 design](PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md), building on
[CXR2](PHASE_COMBAT_CXR2_ENCOUNTER_CORE.md),
[CXR3](PHASE_COMBAT_CXR3_WORLD_ENCOUNTER_LIFECYCLE.md),
[CXR4](PHASE_COMBAT_CXR4_ACTIVE_SEMI_AUTO_SCHEDULER.md), and
[CXR5](PHASE_COMBAT_CXR5_PLAYER_TACTICAL_ACTIONS_QUEUE.md).
The earlier CXR6 handoff is historical preparation, not authority to add actions.
No LPC mechanic was migrated or reinterpreted; no new LPC inspection was needed.
`reference/es2/`, `DECISIONS.md`, and local `game/project.godot` are unchanged.

## Resolved presentation choices

- Same frozen world, with a strong Session-owned overlay; no BattleSession or
  duplicated combat state. No normal-player Attack/aggression cutover.
- Replaceable dark teal/gold Theme and native panels; not final art.
- Production action registry **0**; Quick Actions stays visible and explicitly
  says `No tactical actions are currently available.` No disabled fake categories.
- Quick Slots **0**. No six-category placeholder buttons, invented techniques,
  battle items, defense effects, spells, force actions, or flee.
- No semantic enemy commitment producer exists, so **no telegraph UI** exists,
  including no misleading empty telegraph placeholder or timing estimate.
- Latest three semantic feedback entries stay visible; full incremental Combat
  Log is scrollable. No UI timer, ATB, readiness bar, or gameplay countdown.
- Current Target and accepted Queued Target are independently projected. Cards
  are a participant collection, not a hardcoded pair; no player target selector.

## Ownership and components

```text
ApplicationShell / one persistent Runtime Host
  -> current OldPineWorldSession (same exact authoritative state)
     -> ActiveMapSlot / frozen resident world
     -> BattlePresentationLayer (CanvasLayer 50)
        -> BattleSurface / BattlePresentationController
           -> participant cards / Quick Actions / queue / latest 3
           -> CombatLog (dismissable child, not a second battle)
           -> ExplorationPresentationBlocker (generic input context only)
```

The Shell's shared touch Pause (layer 90) and Shell surfaces (layer 100) stay above
Battle. The existing world HUD yields while Battle is active and its previous
visibility/focus is restored on completion. World freezing remains exclusively
the CXR3 world gate; UI visibility is not gameplay authority.

`BattleProjectionBuilder` reads the current coordinator, participant bindings and
exact CharacterState resources, busy, availability, lifecycle and current targets.
It copies these into typed value projections; child controls never receive Session,
CharacterState, policy, scheduler, or RNG objects. Resource numbers are not
normalized: gin/kee/sen show current/effective/maximum; force/mana/atman show
current/maximum, including over-cap values. The vitality bar's minimum visual scale
of 1 is presentation only; numeric text retains authoritative values.

`CombatTacticalActionInfo` exposes only registered action ID, category, target rule
and busy behavior. Registry/coordinator enumeration returns these values, not
policies. `BattleActionPresentationCatalog` can rename a registered action for
presentation but cannot register or enable it. Missing metadata falls back to the
registered semantic ID. Production catalog/registry remain empty. Preconditions
are not predicted or duplicated by UI; authoritative request rejection is shown.

`BattleIntentAdapter` submits a typed `CombatTacticalRequest` or exact cancellation
to the coordinator. Correlation IDs are local `battle-ui:<encounter-id>:<counter>`,
monotonic within the Session's displayed encounter, guarded against overflow.
They do not replace Encounter's sequence authority. UI submits the displayed
current target as declared intent where the registered target rule requires it;
validation and accepted-target snapshotting remain CXR5 responsibilities.

There is exactly **one executable pending slot**, owned by `CombatEncounter`.
The UI's copied queue/request data cannot execute or replace authoritative state.
READY / WAITING_FOR_BUSY / EMPTY come from the existing typed queue status. Failed
replacement leaves the prior queue displayed; cancellation uses the request ID
actually displayed, so stale cancellation cannot erase a replacement.

`events_after(progression_order)` on scheduler/tactical runtime walks and copies
only the new suffix. `BattleFeedbackReader` merges both streams by shared
`progression_order`, advances one cursor and keeps three recent entries. The log
appends new entries without rebuilding complete history every frame. Feedback
formats actual opportunity/hit/dodge/parry/riposte/tactical outcomes; it does not
reuse the old vertical-slice controller or invent a default slash action.

## Input, layout, lifecycle and restore

The generic `ExplorationPresentationBlocker` has no combat dependency and is not a
dismissable panel. MobileTouchAdapter observes it, cancels existing captures, hides
the direction pad and retains shared Pause. Battle's full-rect Control consumes
world pointer input. Existing native buttons receive routed touches. Keyboard /
controller focus enters Battle, child Log focuses Close, and hidden world controls
do not retain focus. Back/Escape closes Log first; root Battle delegates to existing
Shell Pause, never dismissing the encounter.

Existing SafeAreaPresenter remains the sole measurement source. New controls use
64-pixel minimum touch targets and 8-pixel gaps; existing content padding is 16.
Tests cover desktop, minimum 800x480 safe rectangles and asymmetric/reversed
insets. Participant cards scroll horizontally when necessary. Latest three rows
cannot push one another off-screen through wrapping; full text remains in the log.
Native minimum-size changes refit the content to the same safe rectangle after
initial layout converges, without another timer/sampler.

Pause and mobile lifecycle still belong to Shell/ApplicationActivity. Projection
does not advance time or replay requests. Foreground alone does not Resume; the
existing explicit Resume gate preserves the exact queued request and busy/RNG.
Continue's existing staging-to-current Session reparent is supported: Battle
reconnects its shared SafeArea subscription and its generic blocker resets leaving
state on reentry. No persistence/coordinator algorithm was changed for this.

## Changed source inventory

- `game/presentation/battle/`: `battle_presentation_controller.gd`,
  `battle_projection_builder.gd`, `battle_presentation_projection.gd`,
  `battle_participant_projection.gd`, `battle_resource_projection.gd`,
  `battle_feedback_projection.gd`, `battle_feedback_reader.gd`,
  `battle_intent_adapter.gd`, `battle_action_presentation_catalog.gd`,
  `battle_participant_card.gd`, `battle_action_panel.gd`, `battle_log_panel.gd`,
  `battle_visual_theme.gd`, and their Godot UIDs.
- `game/scenes/battle/battle_presentation.tscn`; Session scene embeds it.
- `game/presentation/layout/exploration_presentation_blocker.gd` and UID.
- `game/runtime/combat_encounter/combat_tactical_action_info.gd` and UID;
  coordinator/registry read-only metadata and scheduler/tactical event-suffix APIs.
- `game/runtime/world/oldpine_world_session_controller.gd`: display-name lookup only.
- `game/runtime/application/application_shell_controller.gd` and
  `mobile_touch_adapter.gd`: generic presentation-context integration only.
- `game/tests/runtime/battle_presentation_test.gd`,
  `game/tests/support/cxr6_session_fixture.gd`, `game/tests/run_cxr6_tests.gd`,
  QA-only `game/tests/runtime/cxr6_runtime_harness.gd/.tscn`, relevant UIDs;
  canonical `game/tests/run_tests.gd` registers the new suite.
- This phase document and production STATUS / ROADMAP.

Existing dependencies independently inspected include coordinator start/complete,
scheduler events/opportunities, tactical registry/runtime/request/queue/result,
exact Session bindings, Shell input/pause, MobileTouchAdapter, SafeAreaPresenter,
ResponsivePanelLayout, MobileLifecycleAdapter, native restore staging promotion,
and the CXR5 test-only probe. No vertical-slice scene/controller was made a Battle
authority. No production Character/Skill/Equipment/Armor rules were changed.

## Focused verification — this execution

Godot: `4.7.2.stable.steam.ed1daf0bf`; Godot AI 3.2.4, existing development port 6107.
Commands use the workstation's installed Godot/Python executables (not checked-in
machine paths):

```text
godot --version
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/run_<suite>_tests.gd
python tools/ci/repository_checks.py
git diff --check
```

| Focused suite | Passing assertions |
|---|---:|
| cxr6 | 146 |
| cxr5 | 240 |
| cxr4 | 791 |
| cxr3 | 719 |
| phase_10c2c | 533 |
| phase_10c2b | 221 |
| phase_10b4 (restore/reparent affected boundary) | 1,091 |
| Sum of these runner totals (not unique historical tests) | **3,741** |

All passed, zero failures. Editor/import and repository/static checks passed.
Canonical suite registration was added, but **`run_tests.gd` was not executed**.
No complete historical-suite, cross-platform build, packaged-release, or CI PASS
is claimed. No production/build setting was changed to run validation.

Distinct post-test audit searched production Battle code for resource/busy writes,
RNG, policy execution, ordinary executor ownership, scheduler advancement, target
mutation, completion calls, gameplay Timer, fake telegraph/ATB/cooldown and the
vertical-slice controller: none found. Production registration search finds only
the coordinator API declaration, no action registration call. Manual inspection
confirmed copied snapshots, one queue authority, suffix reads, UI-only catalog,
and no target/cost/eligibility formula duplication.

### Findings and corrections during this slice

1. Dense mobile QA layout initially exceeded the minimum safe rectangle. Compact
   resource/status rows and three non-wrapping recent lines corrected overflow.
2. Real first-population layout temporarily retained a 1516-pixel content height
   on a 648-pixel viewport. Minimum-size convergence now refits the shared safe
   bounds; first-population and queue-reflow regression checks were added.
3. Separate audit reproduced three Continue/reparent failures: disconnected
   SafeArea, stale leaving blocker, and subsequent inset updates not applied.
   Reentry support in the two new components fixed all three (145 assertions
   then PASS; final world-picking assertion brings the suite to 146).
4. QA CountingRandom lacked the capture method used by existing Shell diagnostics;
   added an explicitly non-restorable QA snapshot, not a production RNG change.
5. QA profile names containing dots were invalid. Harness now uses `cxr6-live`
   and asserts configuration success; restore test uses `cxr6-restore`. Earlier
   live runs therefore used development storage configuration, not memory storage
   as intended. They performed no Save. The final QA run verified isolated
   in-memory configuration. The new restore test also explicitly neutralizes
   viewport scaling for synthetic touch coordinates, as the existing touch tests do.
6. Four ad-hoc inspection mistakes used nonexistent API/property names and paused
   the debugger (including `_log` instead of `log_panel`, and `world_gate` instead
   of `world_simulation_gate`). Those stale/broken runs are not clean-runtime PASS
   evidence. Stopped and relaunched; final successful runs below had no run errors.
   One transient UID-cache fallback warning disappeared after editor import;
   no historical scene/UID was rewritten to suppress it.

## Real runtime evidence

Canonical `ApplicationShell` main-scene run 16: actual mouse New Game plus its
confirmation, exact Host/Session path, default registry 0, Battle hidden, normal
world HUD and frame-timed movement. Non-stale frames **2058 -> 5433**. No Save.
After reentry fix, canonical run 18 used actual Continue and restored the existing
`oldpine.cave` save, with initialized current Session and shared SafeArea connection
true, no active encounter. Frame **3232**, non-stale. An earlier Outdoor-specific
QA encounter setup was not applicable to that Cave save and was not accepted as
Battle proof; no gameplay fix or forced map transition was made for it.

Controlled runs use `res://tests/runtime/cxr6_runtime_harness.tscn`, containing the
actual Shell -> Host -> Session -> production Battle scene. QA setup establishes
SCRIPTED/SCRIPTED encounters and directed relations at typed boundaries without
moving physical bodies. Ordinary randomness is a declared counting-zero QA source.
Keys 1/2 establish/complete controlled encounters; key 4 registers only the existing
test probe and an alternate ID. These are **not normal production Attack inputs**.
After setup, UI paths use actual mouse motion/press/release, keyboard Escape,
joypad button events, viewport ScreenTouch events and ordinary input-action movement,
not controller/button callbacks or direct tactical execution.

Run 15 (before the QA storage correction, but with actual production UI):

- Empty registry: frozen position `(450,300)` despite movement input; ordinary
  cycles/events advanced; HUD/pad hidden; Quick Actions honest empty; no telegraph.
- Log opened through its real button. Escape closed Log, then paused root Battle.
  Paused cycle **45**, events **90**, RNG **405** stayed unchanged across observations.
- Three-participant QA: first receipt force **10->10**, RNG **770->770**, resolved
  **0->0**. Subsequent normal Session processing produced force **9**, resolved **1**.
- Busy observation used explicit QA setup (60, then 600 to allow manual operations),
  not production timing. Request suffix `:2` retained target bandit 1 after QA-only
  authoritative current-target change to bandit 2. UI displayed both separately.
- Valid replacement became `:3`; failed replacement code 12 preserved `:3`,
  force **0->0**, RNG **1555->1555**; real Cancel returned code 1 / EMPTY,
  RNG **1611->1611**. All receipts left execution count unchanged.
- Actual shared Pause retained queue `:3`, cycle **127**, RNG **1523**. Resume did
  not resubmit. Desktop-injected platform loss/gain retained queue `:5`, cycle
  **318**, RNG **3051**, until the actual explicit Resume button was touched.
  This is notification-boundary integration, **not OS/device lifecycle evidence**.
- Log mouse-wheel input changed scroll **20274 -> 19974**; joypad accept closed
  the focused Log. Non-stale frames **9242 -> 25088 -> 31234 -> 47208**.
- Controlled completion restored HUD/pad on the same Session ID **329638742658**;
  CharacterState identity was unchanged. Fresh movement reached approximately
  `(483,300)` without replaying the old input. No Session replacement or cloned state.

Final isolated QA run 19 (after reentry/configuration corrections):

- No saved journey in memory profile; real New Game input. Registry 0 encounter,
  frozen backdrop and three feedback rows, no actions/telegraph, HUD/pad hidden.
- Touch at the covered world-landmark position left world selection null; movement
  input left the physical position `(450,300)`. Non-stale frames **593 -> 3964**.
- Then QA-only registry 2. Real touch receipt force **10->10**, RNG **563->563**,
  resolved **0->0**. Replacement RNG **819->819**, Cancel **1139->1139**, next
  submission **1211->1211**, with one slot and distinct request IDs.
- This final smoke did not wait out its long busy setup; ordinary-boundary execution
  proof is the successful run-15 observation above and deterministic focused tests,
  not an invented final-run execution claim. `start_busy(0)` does not clear existing
  busy state; no production semantics were altered to make the QA route faster.

Successful runs 15/16/18/19 reported `helper_live=true`, `session_active=true`,
`game_capture_ready=true`, and current-run errors empty (run IDs respectively
`r118125712-15`, `r118859281-16`, `r119398530-18`, `r119474545-19`). No stale capture
was used as liveness proof. Game stopped cleanly after validation.

## Mobile evidence and deferrals

`adb devices -l` returned no devices, both initially and at final check. No physical
Android or emulator CXR6 run occurred. Affected Battle SafeArea/reverse landscape,
touch/multitouch cancellation, pad suppression, Back and lifecycle require bounded
device requalification. Desktop viewport touch/joypad injection and inset/lifecycle
tests are accurately separate evidence. iPhone/iPad remain unqualified. Phase 10D1
historical physical results do not cover these changed paths.

Deferred: all real martial/force/spell actions, tactical defense effects, battle
items, flee, Quick Slots, semantic enemy commitments, player target switching and
CXR7 multi-opponent/mode completeness. Terminal/death/corpse/loot/Save/cutover is
CXR8; active Encounter Save remains excluded. Playability/balance is CXR9; final
major-phase audit/PR/CI/merge is CXR10. Normal production Attack/aggression stays
on the existing playable slice; coordinator start scope stays SCRIPTED/SCRIPTED.
No CXR7, Phase 10D continuation, or final integration PR was started.
