# CXR8 — Production Combat Cutover and Resolution

## Status and delivery

Implementation and bounded desktop/Android runtime validation complete (2026-09-07).
Ready for owner review, not a major-phase formal closure or integration into main.
CXR9 has NOT STARTED; Phase10D remains parked/frozen.

- Branch: `phase/combat-experience-redesign`.
- Starting HEAD/upstream: `98e8bef3992c8083098d174c3850afef4781e440`, initially 0/0 after fetch.
- Implementation SHA: `9e00c37f0e1f4621cc86296ad87a9dd7bd8a0268`.
- No new branch, PR, merge, CI claim, balance change, or real tactical action catalog.
- Owner's 12 Godot AI plugin edits and `game/project.godot` were preserved byte-for-byte
  against the preflight SHA256 inventory; excluded from CXR8 commits.
- `reference/es2` and `docs/migration/DECISIONS.md`: zero changes.

## Source recheck and selected semantics

All paths below are relative to `reference/es2/mudlib/`; LPC remains read-only.

| Inspected source | Evidence used |
|---|---|
| `std/char.c`, lifecycle/attack section | Effective gin/kee/sen < 0 means death; otherwise current < 0 means unconscious, or death if already not living. Zero is not the threshold. Lifecycle precedes the next ordinary opportunity. |
| `feature/damage.c`, unconscious/death/revive sections | Existing relationship cleanup, disable/current-resource zeroing, corpse delegation; no invented revival/penalty/teleport. |
| `feature/attack.c`, complete | Opponents versus lethal targets, living/availability cleanup, guarding, target selection, continued lethal attacks against an unconscious opponent. |
| `adm/daemons/combatd.c`, damage/friendly/post-action/reverse paths | Damage and wound are different; weapon OR lethal attack can wound. Positive friendly damage clears reciprocal enemy relations. Post-action/reverse attack belongs to the same complete opportunity before outer lifecycle. |
| `cmds/std/fight.c`, complete | Accepted friendly relationship establishment, not an arbitrary HP-percentage contest. Non-speaking reverse-kill branch is not SPAR. |
| `cmds/std/kill.c`, complete | Source lethal initiation rules; retain the existing audited playable relationship adapter, not a new command implementation. |
| `adm/daemons/chard.c`, complete | Direct inventory death transfer, owner hook, corpse and rewear orchestration. |
| `obj/corpse.c`, complete | Corpse containment/lifetime reference; reuse existing native corpse authority, no new decay clock. |

Dependencies rechecked in native code include `CombatSliceOpportunityExecutor`, the full forward/
reverse executor composition and relationship service, `CombatSliceLifecycleAdapter`,
`CombatSliceDeathAdapter`, `DeathInventoryService`, current Inventory/ItemIndex/Corpse adapters,
Session binding/freeze/thaw, native Save capture/restore, Shell activity and Battle projection.
The damage, force, skill/progression, equipment and armor formulas were not rewritten.

The production entry keeps the already-audited playable adapter's reciprocal lethal relation
behavior. This is not a claim that every original `kill()` call establishes symmetric kill lists.

### Resolution policy

- **LETHAL:** inspect all exact participant bindings after each complete opportunity, not after a
  whole large-delta batch. A dead hostile is unavailable; other valid hostiles keep the encounter
  active. An unconscious lethal NPC may still be attacked through the existing source-backed path.
  Player-side victory is derived only after no relevant hostile remains. Sides/subjects are arrays;
  the three-side test kills one NPC, continues against another, then completes.
- **Player defeat:** existing unconscious/death lifecycle produces DEFEAT. A defeated player remains
  unconscious/dead and may be intentionally non-playable. No respawn, checkpoint, ghost, recovery,
  XP/gold penalty, or teleport was invented. Death has a corpse; unconsciousness alone does not.
- **SPAR:** positive friendly damage clears reciprocal enemies in `combatd.c:433-441`, so the normal
  result is SPAR_CONCLUDED from relationships, often with both characters still conscious.
  Existing nonlethal unconscious lifecycle may also conclude it. No winner score, HP percentage,
  round count, or timer was introduced.
- **Explicit SPAR blocker:** the same LPC file allows weapon-based mortal wounds in a friendly
  fight. If a SPAR participant requires DEATH, resolution holds with `SPAR_MORTAL_WOUND`; no corpse,
  clamp, automatic cure, or false completion. This conflict is deliberately unresolved, not silently
  fixed. No new compatibility choice has been locked into DECISIONS.
- **SCRIPTED:** no automatic Victory/Defeat; retains the existing controlled typed completion.
  Existing typed FLED completion remains available, but there is no production flee action/formula.

## Integration and ownership

`OldPine Attack / authored aggression -> CombatEncounterCoordinator.start_production -> existing
lethal initiation -> one CombatEncounter + Scheduler -> existing opportunity chain -> typed
CombatOpportunityBoundary -> CombatEncounterResolution -> existing lifecycle/death -> completion`.

Production entry rejects invalid/stale authority, invalid source/location, unavailable participants,
application blocking, duplicate encounter, and unrelated existing third-party opponents. A failed
start restores the prior ordered opponent/lethal collections. It consumes no combat RNG. The local
entry sequence is only an encounter identity, not a replacement for durable item identity.

`CombatOpportunityBoundary` is a narrow synchronous typed barrier, not Callable, a scheduler, a
generic callback registry, or a second CombatResolver. The resolution object holds the existing
Session/Encounter references, typed failure/result and lifecycle receipts. The Scheduler checks it
before commands, after a tactical boundary, and after every ordinary participant opportunity.
Full forward/reverse results have already returned when the barrier observes them. A terminal result
or partial failure stops the current batch before another actor/cycle/RNG draw.

`CombatEncounter.accepts_completion_result()` exposes its existing read-only result membership
validation so a foreign result cannot first enter RESOLVING and erase the queue. On valid completion,
the existing queue authority cancels once, the same world prepares thaw and releases its gate,
then the typed result becomes terminal and the coordinator releases active encounter/scheduler
references (post-review ordering below). Failure holds RESOLVING, clears
the queue once, never retries partially mutated lifecycle, and cannot be bypassed by external FLED.

Completion reconciles only the included encounter relationships and guarding; it does not clear
busy/resource/condition state to force Save eligibility. This is encounter-boundary cleanup, not
Save-side cleanup and not a new LPC `remove_all_enemy()` implementation.

The canonical Old Pine Timer is never started by Attack, aggression, thaw, or rollback; its timeout
only stops it. Its explicit manual `process_cadence_tick()` remains for historical tests. The old
noncanonical Phase6 arena controller is retained, not instantiated by ApplicationShell/Session.
There is no parallel old/new engine in the canonical production game.

### Death / corpse / inventory publication

- Existing lifecycle and death inventory services remain authoritative; the outdoor adapter supplies
  physical location, existing allocator, item facts, and corpse presentation.
- Death item facts now enumerate **current direct inventory**, not only original NPC loadout or the
  player's wielded sword. Exact ItemInstanceIds, stack quantities, equipment/armor and native corpse
  transfer remain owned by their existing systems.
- The existing adapter allocates a lifecycle ID even for an unconscious transition. CXR8 preserves
  this pre-existing continuation behavior rather than silently changing allocator semantics.
- A failed corpse ItemIndex registration or view configuration is now a typed
  `WORLD_PUBLICATION_FAILED`, not a successful death receipt for an unlootable corpse.
- Partial corpse evidence can remain, but it is not registered as an ordinary loot interaction.
  The world remains frozen and Save remains blocked. No re-run or duplicate corpse is attempted.
- Live validation found the returned exploration HUD showing pre-battle health. Completion now
  refreshes that existing read-only projection; the authority itself was already correct.

### Save and application lifecycle

`ACTIVE_COMBAT_ENCOUNTER` is an explicit eligibility outcome for an active encounter OR a non-open
world gate, independent of legacy `is_fighting`. The Shell maps it to the existing combat Save-block
message. No encounter/scheduler/queue/target field was added to any Save DTO/codec.

After successful resolution, ordinary eligibility still applies (including player life/busy state).
Native capture/restore continues completed NPC/corpse/item facts into a fresh graph. Settings remain
separate. Pause/background pass no logical time to the scheduler; Resume has no catch-up/autosave.
Host remains the sole current-Session authority. Battle is a read projection and input adapter,
never the owner of Character, resources, inventory, corpse, result or lifecycle.

## Tests and independent verification

Final focused CXR8: **71 assertions, 0 failures**. Tests cover production entry/rollback, causes,
active Save rejection independent of relations, pause, invalid completion membership, three-side
death/retarget/continued combat, large-delta early stop, exact corpse sword ID, native fresh restore,
failed death/no retry/no false victory, queue cancellation once, positive-hit SPAR, armed-SPAR
blocker, unconscious/death thresholds, and returned HUD state. The reverse-chain test reuses the
audited LPC-derived 15-draw sequence: current 20 receives 21 reverse damage -> -1; the boundary sees
REVERSE_COMPLETE before unconscious requirement and prevents any next actor/draw.

| Runner (`game/tests/`) | Assertions | Failures |
|---|---:|---:|
| `run_cxr8_tests.gd` | 71 | 0 |
| `run_cxr7_tests.gd` | 149 | 0 |
| `run_cxr6_tests.gd` | 148 | 0 |
| `run_cxr5_tests.gd` | 240 | 0 |
| `run_cxr4_tests.gd` | 791 | 0 |
| `run_cxr3_tests.gd` | 719 | 0 |
| `run_cxr2_tests.gd` | 736 | 0 |
| `run_phase_6b2_tests.gd` | 1,153 | 0 |
| `run_phase_6b3_tests.gd` | 2,112 | 0 |
| `run_phase_8b1_tests.gd` | 2,218 | 0 |
| `run_phase_9b3b3_tests.gd` | 2,467 | 0 |
| `run_phase_10b4_tests.gd` | 1,091 | 0 |
| `run_phase_10c2a_tests.gd` | 3,597 | 0 |
| `run_phase_10c2b_tests.gd` | 221 | 0 |
| `run_phase_10c2c_tests.gd` | 533 | 0 |
| **`run_tests.gd` — final canonical suite RUN** | **15,673** | **0** |

Counts overlap; do not sum runners. First canonical run passed 15,668; the real-runtime HUD finding
then justified the final rerun above, with five extra assertions including failure queue coverage.
The final canonical run includes the prior suites on the final production tree.

Historical pre-CXR8 map/loot tests explicitly install `tests/support/historical_world_combat_fixture.gd`
to retain their manual-cadence test subject. Their production coordinator is NOT this fixture.
They do not prove the new production route; the CXR8 tests and actual paths below do. Old expectations
that thaw/rollback restart the timer were corrected, as was the formerly-successful partial corpse
publication receipt. No prior assertion was simply deleted to hide a failure. Sanitization excludes
this fixture, QA harnesses, tests and Godot AI; production contains no registration of test policies.

Separate source/diff review confirmed one Session/Encounter/Scheduler/queue/target authority, no
new damage formulas, no generic apply Dictionary/Callable hook/global RNG, and exact state binding.
Godot 4.7.2 editor import, repository/static checks, changed-file trailing whitespace and
`git diff --check` pass.

## Actual desktop runtime evidence

Successful runs used Godot AI 3.2.5, helper_live/session_active/game_capture_ready true. Game captures
were non-stale with advancing frame numbers. Three mistyped QA inspection expressions in earlier
runs referenced nonexistent `result`, `write_count`, and `inventory()`; those debugger breaks were
stopped/restarted, not counted as production failures or successful evidence. Final runs 8-11 launched
with `current_run_errors=[]`; no gameplay errors were observed on their successful paths.

- **A, canonical main, run 5:** real New Game confirmation, real NPC selection and Attack. Pre-route
  QA only moved scout 0 near the player/aligned its typed location and disabled its aggression Area
  so the manual entry could be observed; no attack callback. Cause PLAYER_LETHAL_ATTACK, LETHAL,
  Session `320260278910`, cycle 3. Pause held cycle/RNG/HP 196 unchanged across observations;
  legacy Timer stopped and world position stayed `(450,300)`. Resume continued actual combat.
- **B, clean production world, run 11:** real New Game and 190-frame `move_down` input, no QA stat or
  position adjustment. Physical aggression entered cause **2 = NPC_AGGRESSION** at `(450,751.0007)`.
  Session `200085080458`, cycle 5, HP122, Save outcome17, legacy Timer off, world frozen. Pause held
  those facts; RNG state observed `1870381447626811211`.
- **C/D/E, isolated Shell run 8:** memory-backed isolated profile, otherwise production Shell/Host/UI.
  Declared setup: scout near player, deterministic production PCG seed88, courage/skill/experience
  elevated for reproducibility, player HP10000, NPC current/effective positive 1. Actual mouse
  selection/Attack and natural scheduler caused death (no direct damage/death/complete call).
  Session `198659017089`, Character `-9223371836232824324`, Victory, one corpse, world open.
  Real corpse selection/Open Loot/Take transferred the exact scout short-sword ID to direct player
  inventory, leaving only silver x3 in the corpse. Real Pause/Save showed “Your journey was saved”,
  storage 0 -> 1 file. Real Return confirmation -> Main Menu -> Continue created Session
  `1375362615899`, Character `-9223370682463679397`, same corpse and semantic item IDs, no active
  encounter/scheduler. Reopening Loot showed only silver x3: no duplicated sword.
  Scope for these IDs: `oldpine-session-83903d087d9585c9963c229718235bdd`.
- **E/F, run 7 before its later QA inspection error:** actual Pause/Save during active combat showed
  “Saving is unavailable during combat or an unfinished action”; cycle0 and storage0 remained.
  Clean run8 post-combat Save above is independent of that aborted diagnostic run.
- **G, run 9:** key3 declared controlled source-backed SPAR establishment (no production SPAR UI).
  Actual scheduler concluded SPAR, result2, both alive, corpse0, storage0. No forced completion.
- **H, runs 9/10:** declared positive player current/effective1, busy3, strong NPC, then real
  selection/Attack. Ordinary combat caused DEAD, DEFEAT, corpse1, inventory emptied, Save blocked
  by existing player-life eligibility. No revive. Final run10 also showed refreshed HUD
  `-1 / -1 / 10000`, equal to authoritative post-lifecycle state.

Representative non-stale frames: run7 5638 -> 7405; run8 10501 -> 12957 -> 14896 -> 19871.
QA setup and real-input paths are deliberately distinguished. No controller method was substituted
for normal Attack, physical aggression, corpse selection, Take, Save or Continue.

## Physical Android evidence — bounded affected paths PASS

OnePlus8T / KB2005, Adreno650, Vulkan1.1.128 / Forward Mobile, 2400x1080 landscape. The owner explicitly
authorized replacing `com.example.easternstoriesgodot` and clearing only its test saves. Other apps
were not changed. No new package identity, renderer fallback or permanent signing was introduced.

The first Steam-executable export exited1 without useful export output. The repository's pinned
official Godot4.7.2 console toolchain exported successfully without code/config changes. Final
sanitized ARM64 APK: 27,921,884 bytes, SHA256
`7f6a196b1f0582abaf3802cbdc5ff0e3a57192f3a4b17128ae676bc95f25849e`.
Local artifact: `build/cxr8-android-final-artifacts/android/Eastern-Stories-Godot-android-arm64.apk`.

Actual installed-package touch New Game -> direction-pad movement into scout aggression -> LETHAL
Battle -> Android Back Pause passed. Touch Resume and target selection worked; the current target
highlight and guard feedback appeared. Home during active battle -> same-process return held combat
behind the explicit “Paused while the app was away” Resume gate, with no automatic progression.
Final APK repeated entry/Back/Home/Resume evidence, not just an earlier build. Natural unmodified
player combat then ended with the player's corpse and returned world HUD `-1 / -1 / 220`, proving
the final HUD refresh in the actual package as well. No QA state adjustment was used on Android.
Logs showed no observed game runtime errors. Screenshots are local QA evidence under
`build/cxr8-mobile-*.png`, not shipped
content. This is ADB-injected real Android touch/OS input, not human multi-finger qualification.

This bounded CXR8 pass does NOT retroactively qualify all earlier CXR6/7 multi-target/queued-action
device combinations, physical controller behavior, iOS, balance, accessibility or final demo quality.
The production tactical registry remains zero, so no real tactical action is claimed on mobile.

## Deferred and review boundary

Armed-friendly mortal SPAR remains explicitly blocked; player unconscious/dead recovery is not
implemented. No final flee design, telegraph producer, real techniques/spells/defense/items, Quick
Slots, victory animation, result-screen polish, multi-enemy balance or full content parity.
CXR9 playability/narrow balance and CXR10 final audit/integration await separate owner authorization.
Phase10D artifacts and acceptance remain frozen historical evidence.

## Original delivery record (before post-review hardening)

Implementation: `9e00c37f0e1f4621cc86296ad87a9dd7bd8a0268` (38 files).
This delivery-record update is documentation-only; its commit is the final delivery HEAD reported
to the owner. No production change follows the final 15,673-assertion run or Android artifact.
Only the original 13 owner plugin/project files remain dirty. No PR or merge was created by CXR8;
there is no new integration-CI or post-merge-main claim. The same branch is pushed for continuation.

### Post-review completion failure hardening

2026-09-07 audit starting at `dff7b7625f545d6e84ee19dd14912ec4041e322f` (origin 0/0).
Original implementation remains `9e00c37f0e1f4621cc86296ad87a9dd7bd8a0268`.
Audit-fix implementation SHA is recorded in the following delivery-finalization commit.

**Finding:** the previous `complete()` committed COMPLETED before Session thaw. A thaw failure
therefore hid Battle's ACTIVE/RESOLVING-only projection; a gate release failure was worse because
the coordinator had already cleared both active references. A frozen gate alone is not a healthy
completion failure boundary, even when Save is blocked.

**Chosen Option A:** prevalidate result/membership/mode -> ACTIVE to RESOLVING and cancel the queue
once -> Session/local map thaw preparation -> same world gate release -> Core terminal commit ->
clear encounter/scheduler references. This is synchronous, with no await, deferred continuation or
runtime retry. Local map thaw quarantines input, stops the legacy Timer and refreshes the HUD; it
does not open the global gate. The Core remains RESOLVING, so both coordinator and retained scheduler
reject advancement before reading the lifecycle boundary or consuming RNG. Gate release itself is
a synchronous owner check/field clear, with no signals/callbacks. Between release and terminal commit
there is no executable scheduler frame; the unchanged, prevalidated Core owns the terminal event.
This is ordered orchestration, not rollback of the already committed death/inventory transition.

**Failure authority:** reuse `CombatEncounterCompletionResult` / coordinator `last_completion()`;
`WORLD_THAW_FAILED` and appended `WORLD_GATE_RELEASE_FAILED` distinguish the failed step. The first
attempt's receipt is retained, including a defensive snapshot of the proposed authoritative result.
It is not a second committed terminal result: Core terminal_result stays null. Do not additionally
set `CombatEncounterResolution.failure` for a world-return failure (its older enum member is retained
but no longer produced). Actual lifecycle failures keep their existing separate resolution behavior.
Only a successful new start resets the last receipt; retained active ownership prevents a new start
over a failed completion. Repeated complete/FLED returns failure without retrying thaw/release.

- Thaw failure: same encounter/scheduler/gate and owner retained, map remains locally frozen.
- Release failure: local map has prepared thaw, but the same global gate remains frozen with the
  encounter owner. Body movement, map interaction/traversal and Save stay blocked. Neither active
  reference is discarded. No second gate or artificial re-freeze/rollback is introduced.
- Both: Core stays RESOLVING; Battle remains visible and receives only a read-only completion outcome
  for the explicit `World return blocked` / `no automatic retry` header. UI owns no completion,
  thaw, release or recovery command. Completed death/corpse/inventory is never replayed. Safe failure
  recovery is not defined here; no retry button, resurrection or Session reset is invented.

**Deterministic injected proof:** test-only Session and gate subclasses override the existing typed
boundaries, preserving the very same gate object already bound into the map/bodies. Each of thaw
failure, release failure and success begins with real production LETHAL entry and a positive-HP NPC;
ordinary combat produces death/corpse and a valid Victory. A busy-blocked synthetic queue survives
until completion and has exactly REQUESTED, ACCEPTED, QUEUED, CANCELLED once. The tests assert retained
identity, typed outcome, UI visibility, Save/traversal/new-start gates, physics movement, exact corpse
item parent, no later resources/progression/RNG/lifecycle/corpse mutation, no repeated cancellation,
and no FLED escape. Success commits monotonically, clears references, hides Battle and permits Save
and physical movement. Fault paths are deterministic injected test evidence, not natural device failures.

| Validation after correction | Assertions | Failures |
|---|---:|---:|
| `run_cxr8_tests.gd` | 158 | 0 |
| `run_cxr7_tests.gd` | 149 | 0 |
| `run_cxr6_tests.gd` | 148 | 0 |
| `run_cxr5_tests.gd` | 240 | 0 |
| `run_cxr4_tests.gd` | 791 | 0 |
| `run_cxr3_tests.gd` | 719 | 0 |
| `run_phase_10b4_tests.gd` | 1,091 | 0 |
| `run_phase_10c2c_tests.gd` | 533 | 0 |
| **Full canonical `run_tests.gd`: RUN once** | **15,760** | **0** |

Focused runners overlap and are not added together. CXR3/4 include Session/resident/gate regressions;
10B4 and the new failure tests cover Save eligibility. The first new-test run failed six expectations
because the test omitted the existing REQUESTED event from its expected count; correcting that
expectation to four events required no production change. The subsequent focused and full runs passed.
Godot `4.7.2.stable.steam.ed1daf0bf` version/editor headless PASS; repository/static Python checks PASS;
`git diff --check` PASS. Local logs: `build/cxr8-audit-*.log` (not shipped).

**Actual success runtime:** canonical ApplicationShell main, run `r2046064-1`, real New Game and
confirmation, framebuffer NPC selection and Attack. Declared pre-route QA: scout moved near the
player, aggression Area disabled for manual entry, production PCG seed88, strong player stats,
positive NPC current/effective1 and busy20 on both actors. No direct attack/death/complete callback.
The production scheduler showed ACTIVE/cycle13 with frozen world, then naturally produced Victory,
one corpse, no active encounter/scheduler, hidden Battle, open world and Save outcome0. Session
`320209947263` and Character `-9223371714681894357` stayed identical. Real 25-frame move_right input
moved `(450,300)` to `(523.3333,300)`, then velocity returned to zero. Old Timer stayed stopped.
Non-stale frames 15,353 (selected NPC), 17,307 (Battle), 22,332 (returned world/movement); helper_live,
session_active, game_capture_ready all true. Launch current_run_errors=[]; current game log had no
errors, full editor error read had zero errors and 40 existing warning rows (integer division,
shadowing/unused signal), not a warning-free claim. A later redundant project_run health call was
rejected as EDITOR_PLAYING by the updated plugin; it did not restart or alter the successful run.
Game stopped normally afterward. No Save button was used; the owner's existing save was not replaced.
No new Android/device evidence is claimed for this desktop audit.

**Distinct post-test source audit:** coordinator completion and phase barrier, Core lifecycle/event
validation, resolution/reconciliation, scheduler/tactical boundaries, Session/map/gate ownership,
WorldCharacterBody2D gate, Save eligibility, Battle projection/controller and the full diff were
reviewed separately after tests. No Battle authority/retry, duplicate failure/result authority,
second gate/scheduler, Timer retry, forced resource cleanup, corpse rollback, Save recovery or active
encounter serialization was added. Normal success still has one completion path. No Core formula,
balance, production tactical catalog, CXR9 or Phase10D implementation changed. No LPC mechanics were
re-ported; the source references above remain the original implementation's evidence.

Owner preflight now contains **120** plugin/project paths (including new/deleted plugin files), not
the original 13-path inventory. All 120 hashes/deletion states were preserved and excluded from this
audit's commits. `reference/es2` and `DECISIONS.md` remain unchanged. Same major-phase branch, no PR
or merge, no new remote CI claim. CXR6/7 device gaps, armed-SPAR blocker, real tactical actions and
flee/telegraph remain deferred. CXR9 NOT STARTED; CXR10 pending; Phase10D frozen.
