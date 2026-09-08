# CXR10 — Combat Experience Redesign Final Audit

Local audit completed: 2026-09-07 (workstation local date; some build timestamps are
2026-09-08 UTC). **FINAL_LOCAL_AUDIT=PASS; ANDROID_AFFECTED_PATH_GATE=PASS.**
Ready for the final integration PR, not merged or fully integrated.

## 1. Scope

Final milestone audit of CXR0-CXR9, not a gameplay implementation slice. Review
covered source/architecture, focused and canonical tests, repository/release
boundaries, real desktop input and the physical Android prerequisite. No gameplay,
test, build, project configuration or migration-decision changes were made.
This document records local evidence; subsequent PR/CI results belong in the owner
report. It is not final integration closure.

## 2. Starting source / git

- Branch: `phase/combat-experience-redesign`.
- Starting and tested gameplay HEAD: `cc42b89334b3e03495caf3e8a4e4eb1b736276fb`.
- CXR9 Part 1: `f22fc7fb9dfcb00a75917112f16ba0e840875e35`.
- Local/upstream ahead/behind before documentation commit: **0/0**.
- Final audit successor changes only this document and STATUS/ROADMAP; gameplay,
  tests, project/build inputs and Android APK source are unchanged. The final commit
  SHA and remote verification are reported externally to avoid a self-referential hash.
- Index initially empty. No merge performed or authorized by this audit.

## 3. Owner local work preservation

The starting dirty/untracked set contained **120 paths**, all in
`game/addons/godot_ai/**` or `game/project.godot`. SHA256/deletion-state comparison
after tests, builds and live validation found **0 changed owner paths**. No reset,
clean, restore, overwrite, staging or normalization of these paths occurred.

The owner worktree and tracked source are deliberately distinct validation inputs:
Python remains 45/46 in the owner configuration and passes 46/46 in an exact
`git archive HEAD` extraction. This is not a clean-worktree claim.

## 4. Main baseline / merge-base

Non-destructive fetch confirmed `origin/main` and merge-base both at
`ae381bf3f3e5f4a28a417295eea680d023cc428c`; main...phase is **0/17**.
No synchronization was required at this inspection. Recheck remote state before a
future PR; this checkpoint does not authorize silently merging/rebasing new main work.

## 5. Full milestone diff inventory

All 17 commits and the complete main...HEAD diff were reviewed, not just CXR9.
There are **217 paths, 13,793 additions, 102 deletions** before this document:

| Category | Paths | Reviewed purpose |
| --- | ---: | --- |
| Production scripts/scenes | 74 | 72 GDScript files and 2 scenes |
| Production UID sidecars | 54 | Matching source identity |
| Tests/QA including UID sidecars | 73 | 46 scripts/scenes plus 27 UIDs |
| Documentation | 14 | CXR analysis/design/evidence, decisions and status |
| Root policy/README | 2 | One-slice verification and historical status correction |

Production review included every file in `game/core/combat/encounter/`,
`game/runtime/combat_encounter/`, `game/presentation/battle/`, and all modified
relationship/resolution, combat-slice, Session/map/body/HUD, Shell/touch,
Save-eligibility and presentation-blocker seams. Existing dependencies were read
where needed; no second character/inventory/equipment implementation was found.

Branch changes in `reference/es2`, `game/addons`, `game/project.godot`, `.github`,
`tools`, and existing character/skill/equipment/armor/content production: **0**.
DECISIONS has **61 added lines** from the already-authorized SPAR/Flee/zero-base
choices; CXR10 adds none. No unrelated authored skills, map content, store/release
work or Phase10D resumption was found. No introduced large binary, build artifact,
temporary log, screenshot or credential file was found in the branch inventory.

## 6. CXR0-CXR9 closure matrix

| Capability | Local audit outcome / boundary |
| --- | --- |
| Ordinary automatic attacks/defense | PASS; existing Core chain remains authoritative |
| Encounter/Session/world lifecycle | PASS; exact live state bindings, one coordinator/gate |
| Scheduler/order/busy | PASS; one opportunity clock, no UI clock or parallel legacy cadence |
| Current target and multi-opponent model | PASS deterministic coverage; ordinary desktop target tap |
| One pending tactical slot | PASS; replacement/cancel/revalidation/execute-once |
| Actual player agency | PASS; target selection and real production Flee |
| Martial/Internal/Spell/Item techniques | Deferred authored content; extension seams only |
| Flee | PASS local; deterministic, busy-blocked, no cost or gameplay RNG |
| Enemy telegraph | CONDITIONALLY SATISFIED / DORMANT; no qualifying producer |
| SPAR | PASS; explicitly unarmed-only, no automatic unwield or resource patching |
| LETHAL / SCRIPTED | PASS; SCRIPTED does not implicitly receive Flee |
| Battle feedback/log, world return | PASS local; actual Flee and natural Victory |
| Corpse/loot and Save | PASS local; real take and fresh-Session Continue |
| Application pause/mobile integration contracts | PASS automated and bounded physical qualification |
| Physical Android affected paths | PASS on OnePlus 8T / exact APK below |

These outcomes are bounded audit evidence, not fully integrated main status.

## 7. Architecture audit

`ApplicationShell -> persistent Runtime Host -> 0..1 Session` remains unchanged.
Session owns the exact live character/item authorities, one `WorldSimulationGate`
and one `CombatEncounterCoordinator`; the coordinator owns 0..1 active Encounter
and scheduler. `CombatEncounterAuthorityBinding` refers to live state, not a giant
combat clone. Encounter owns semantic participants/hostilities/current targets and
one pending player action; Core retains damage/resources/busy/progression.

The Battle layer projects typed values and emits typed intent through
`battle_intent_adapter.gd`. Its controls do not apply damage/costs, consume RNG,
advance or complete combat, publish corpses/loot, force Save or thaw the world.
Projection copies are presentation values, not replacement authoritative state.
The Flee policy is a narrow stateless typed policy, not a Session/service locator.
No added unrestricted apply dictionary, Callable combat dispatcher, global RNG or
parallel Node/Timer scheduler was found in the new orchestration layers.

## 8. Production cutover proof

`oldpine_outdoor_controller.gd` routes real Attack and authored aggression through
the coordinator's production establishment path. Normal relationships still use
existing services. `oldpine_world_session_controller.gd::_process` is the production
advance owner. The map timeout stops the old OpportunityTimer; it does not run a
second attack chain. Explicit cadence helpers and the separate historical combat
slice scene remain compatibility/test paths, not canonical Session scheduling.

World bodies, resident maps, passage/handoff and interaction adapters respect the
same world gate. Freeze closes exploration overlays and pending aggression and
quarantines held input; thaw preserves physical position and requires fresh input.
No reset/teleport/new Session substitutes for returning from Battle.

## 9. Scheduler/lifecycle proof

`combat_encounter_scheduler.gd` checks active phase, application permission, gate,
finite nonnegative delta and exact bindings before work. It inspects lifecycle,
processes one tactical boundary, and only then accumulates permitted delta.
DISENGAGED returns before accumulation or another ordinary opportunity.

The existing opportunity executor runs the complete forward/reverse attack chain
before the outer lifecycle boundary. Each emitted opportunity is followed by
inspection; terminal/failure stops the rest of a large-delta batch. Paused elapsed
time is not caught up on resume. Ordering is semantic progression order, not an ATB
gauge, animation clock or resurrected LPC heartbeat.

## 10. Tactical/Flee proof

Production registration exposes only the intended Flee content; no fictional
technique was added for UI demonstration. Request and execution eligibility are
separate. Invalid replacement preserves the prior pending slot; valid replacement
supersedes it, stale cancel cannot remove its successor, and execution clears the
slot before dispatch. Busy-blocked Flee waits rather than bypassing busy.

`combat_flee_tactical_policy.gd` returns DISENGAGED without resource/RNG/world or
relationship mutation. Resolution/coordinator performs the ordered reconciliation
and authoritative completion. Failure cannot be replaced by an Escaped success.
Flee produces no corpse/reward, destination move, stat restoration or pursuit system.
Other surviving participants' busy is not silently cleared: normal Save eligibility
can still reject such a state, as the existing tests explicitly require.

## 11. Target/multi-opponent proof

Directed hostility and participant ordering are explicit. Current-target changes
are typed requests; the queued request keeps its originally accepted target.
Execution rechecks that stored target rather than silently redirecting to current.
`combat_opponent_selection_service.gd::prepare_specific` preserves cleanup/current
target semantics without drawing the old random-opponent choice. The existing
random path remains for its historical callers.

Multi-opponent deterministic tests cover stable order, invalid/dead targets and
terminal derivation only after all required lifecycle processing. The real desktop
path exercised a participant-card tap; it is not presented as a physical
multi-opponent or Android target-switch qualification.

## 12. SPAR/zero-base compatibility proof

Equipment rejection precedes freeze/activation. SPAR requires empty primary hands;
there is no forced unwield, hidden armor/resource clamp or revive. Mortal SPAR
boundaries fail closed instead of inventing a friendly-death rescue.

The resolver's approved exception is exactly unarmed zero base damage: zero is
accepted without a random draw. Negative base damage and armed zero retain failure;
the rest of ordinary formulas/RNG ordering is unchanged. Sources directly checked
under `reference/es2/mudlib/`: `adm/daemons/combatd.c` damage/friendly/reverse and
skill-power sections; `adm/daemons/race/human.c` actions/defaults;
`adm/daemons/chard.c` setup/corpse; `feature/damage.c` resource mutations;
`feature/attack.c` relationships/opponents; `std/char.c` heartbeat lifecycle;
`cmds/std/fight.c`, `cmds/std/kill.c`, `cmds/std/go.c`; `doc/efuns/random`;
`d/oldpine/npc/bandit.c`, `tall_bandit.c`, `fat_bandit.c`.
This explicitly approved RPG substitution is not represented as literal LPC runtime
parity. No external port was consulted.

## 13. Telegraph dormant proof

No qualifying authored enemy special or meaningful wind-up producer exists in
current production. Source scan found no production TELEGRAPH_STARTED,
ACTION_COMMITTED or ACTION_RESOLVED producer. Therefore **producer=0, visible=0**;
tests enforce the absence rather than supplying dummy events. Ordinary attacks,
guard messages and Flee feedback are not rebranded telegraphs. Future real producer
integration remains a separate source-backed slice.

## 14. Death/corpse/loot proof

`combat_encounter_resolution.gd` delegates outer lifecycle to the existing slice
adapter and production map publication. It inspects all required participants;
first-opponent death is not an early Victory while another hostile remains active.
Death facts resolve current direct inventory through the item index, not obsolete
bootstrap-only item lists. Missing item facts or failed publication is typed failure.
Partial death cannot expose successful loot, Save or world thaw.

Fresh normal desktop combat naturally produced Victory, one corpse and its two
direct items. After physical approach, corpse selection and Open Loot, an actual
Take button moved the short sword: corpse remaining item count became one and
survived Save/Continue. No direct death/loot invocation or QA stats were used.

## 15. Save/lifecycle proof

`oldpine_save_eligibility.gd` remains the sole Save policy. Active Encounter and
RESOLVING/failure/world gate block Save. Successful FLED uses normal eligibility,
not an unconditional Save override. No snapshot/schema field stores Encounter,
scheduler, queue, telegraph, Battle UI, gate or combat-timer transient state.

Actual natural Victory -> successful Save was observed. Following a documented QA
inspection typo/restart, the saved state restored; a complete additional
Save -> Return to Main Menu -> confirmation -> Continue route passed using buttons.
Main Menu had no Session; Continue created a new runtime Session while retaining
semantic state. Neither restore reconstructed an active Encounter/Battle.
Automated regressions independently cover failures, pause and mobile Resume gates.

## 16. Failure monotonicity

The first completion receipt owns the outcome. Core stays RESOLVING during
synchronous return; world thaw, gate release and terminal transition are checked in
order. A failed thaw/release cannot be retried into success by Flee. Resolution
failure stops later ordinary work/terminal derivation, keeps Save blocked, and does
not promise generic rollback. Tests explicitly cover partial lifecycle publication,
multiple deaths, reverse-attack lethal results and both world-return failure seams.

After fresh test execution the coordinator, scheduler, resolution and Session
ownership seams were separately re-inspected; passing assertions were not used as
a substitute for the architecture review. No new gameplay defect was found.

## 17. Desktop runtime

Canonical `res://scenes/application/application_shell.tscn`, actual New Game;
Godot `4.7.2.stable.steam.ed1daf0bf`, owner development configuration. No stat,
position, RNG seed, direct-start or direct-complete injection. Frame-timed project
movement actions and actual InputEvent mouse/key events drove normal controls.

- Start `(450,300)`, **12** items. Move down 165 frames: physical aggression at
  `(450,751.000732)`, `encounter:production:1`.
- Escape/Pause: logical cycle **4 -> 4** across observations; actual Resume and
  participant-card/Flee clicks. After 120 physics frames Battle inactive, exact
  position unchanged and Escaped feedback present.
- Move up 45 frames then down 50: `encounter:production:2` after real Area exit/entry.
  Resume and allow unmodified combat/RNG to resolve naturally.
- Victory, player vitality **46/46/220**, one corpse. Walk down 18 frames to
  `(450,802.334351)`, select corpse/Open Loot/Take short sword/Close.
- Save outcome **0**, “Your journey was saved.” Continue retains vitality,
  position, 13 total registered items (including corpse), one corpse/one remaining
  corpse child, no opponents/lethal targets/busy, stopped old cadence.
- Subsequent complete Save/Menu/Continue changes Session ObjectID
  `464712108776 -> 1190544805217`, preserves semantic item scope/allocator sequence
  1 and saved RNG states, active Encounter=false, Battle visible=false.

Helper run `r34092407-10`: launch current_run_errors empty; helper_live,
session_active and game_capture_ready true. Non-stale framebuffer observations at
frames **4,131 / 9,197 / 17,580 / 29,429** show menu, paused Battle, live Battle and
Victory/world. A later read-only QA eval incorrectly referenced `InventoryEndpoint`
instead of `ContainmentEndpoint`, producing a parser/debugger break. It was not
production code and no gameplay was changed. Restarted normally, then used Continue.

Fresh run `r34716310-11`: launch current_run_errors empty, all three helper readiness
flags true, non-stale restored-world screenshot frame **6,327**, all 17 current-run
log entries inspected with **0 runtime errors**. Historical editor dock errors are
not relabeled as current-run failures. The game was stopped after evidence collection.

## 18. Physical Android evidence

**ANDROID_AFFECTED_PATH_GATE=PASS.** `adb devices -l` found physical
OnePlus 8T / **KB2005**, serial `8795f723`, Android **14**, online; an offline
emulator is not qualification evidence.

Exact tracked-source build from `git archive cc42b89334b3e03495caf3e8a4e4eb1b736276fb`:

- Official pinned Godot 4.7.2, normal ARM64 technical QA build, no renderer change.
- Package `com.example.easternstoriesgodot`.
- Ignored artifact `build/cxr10-artifacts/android/Eastern-Stories-Godot-android-arm64.apk`.
- **27,930,299 bytes**.
- SHA256 `6CD9B9C984FFFBD781144094F56170D2E17223CDC27DAB1DBA9395BA18EF19C7`.
- Build manifest records exact source commit. Its dirty flag reflects the outer
  owner worktree; source input was the exact tracked archive, not owner plugin/config.

Initial non-destructive `adb install -r` failed with
**INSTALL_FAILED_UPDATE_INCOMPATIBLE**. Work stopped for permission; the owner then
explicitly authorized replacing the old test application. Only this device/package
was uninstalled (its local data cleared) and the verified APK installed successfully.
No old one-time permission was reused, unrelated app touched, global device setting
changed or reset performed. No backup/recoverability of the cleared test save is claimed.

The production Launcher `com.godot.game.GodotAppLauncher` started PID **17571**.
An initial attempt to launch the non-exported GodotApp activity was rejected by
Android before launch; using the package resolver's Launcher corrected the tooling
invocation, not application code. Log records official Godot 4.7.2, **Vulkan 1.1.128 /
Forward Mobile / Qualcomm Adreno 650**. No compatibility renderer fallback.

All interaction below used `adb shell input` touchscreen taps/holds and Android
Back/Home on the physical device, not direct controller calls, QA stats, teleport,
seeded RNG or state injection. This proves the OS touch path, not ergonomic hand-
comfort, physical multi-finger or all-device qualification.

| Path | Fresh physical evidence |
| --- | --- |
| A. New Game/movement | Empty-save menu, touch New Game, normal world 220/220/220; hold down pad 2,800 ms physically enters authored scout aggression |
| B. Natural Battle | LETHAL Battle renders normal scout/player, not a QA encounter |
| C. Target/Flee | Target tap reports `Target: Unchanged` for current scout; visible Flee button receives touch; Battle closes with Escaped feedback, same player/world landmarks and no corpse |
| D. Rearm | Separate later screenshot remains Escaped without instant retrigger; up-pad 800 ms visibly leaves Area, down-pad 900 ms creates a fresh Battle |
| E. Back/log | Back during Battle produces Shell Pause, not Flee; Resume -> Combat Log -> Back closes only log, leaving Battle active |
| F. Home/Resume | Home during the fresh second Battle; same PID survives; return brings existing task forward with explicit `Paused while the app was away` gate; unchanged 200/200/200 scout, 220/220/220 player, empty queue and initial feedback remain until Resume |
| G. Landscape | 2400x1080 landscape; target/Flee/Log/Resume are visible and usable within current safe-area layout; transient OS rotation on task return settles to landscape without changing settings |
| H. Natural terminal | Touch Resume, no further combat manipulation; natural Victory, world/HUD restored, player 220/220/220 and one scout corpse |
| I. Loot | Down-pad 320 ms approaches corpse, touch corpse/Open Loot/Take short sword; corpse count visibly changes 2 -> 1, remaining silver x3; close and Pause |

Exact world coordinates, Encounter ID and reward counters are not exposed by the
sanitized Android build. Same-position/continued-Encounter evidence here is visual
landmark/state continuity and same process; precise semantic identity, no reward/
RNG and authoritative execution order are independently proved by desktop/domain
tests and source audit, not claimed as Android debugger reads. The sanitized build
has no helper, so helper readiness/stale-frame fields are not applicable: fresh ADB
framebuffer captures show successive actual input/result states.

Ignored evidence files: `build/cxr10-android-{menu,world,battle,back-pause,log,log-back,
fled,fled-idle,left-area,reentered,resume-gate,resume-stable,resumed-battle,
natural-progress,corpse-near,loot,taken}.png`. Initial and post-path Godot/AndroidRuntime
log checks found no GDScript/fatal application error; vendor Adreno/AHardwareBuffer
startup diagnostics were observed but did not prevent rendering or these paths.
Only this device/build's changed paths are qualified; no iOS, tablet, portrait,
physical controller, accessibility or store-readiness claim follows.

## 19. Test evidence

Fresh pinned official Godot **4.7.2.stable.official.ed1daf0bf** runs, each exit 0,
no GDScript errors. Logs are ignored `build/cxr10-<runner suffix>.log` files.
Counts overlap and are not unique tests or additions to the canonical total.

| Runner suffix | Assertions | Failures |
| --- | ---: | ---: |
| cxr9 | 368 | 0 |
| cxr8 | 159 | 0 |
| cxr7 | 149 | 0 |
| cxr6 | 148 | 0 |
| cxr5 | 240 | 0 |
| cxr4 | 791 | 0 |
| cxr3 | 719 | 0 |
| cxr2 | 736 | 0 |
| phase_5b2a | 664 | 0 |
| phase_5b3b2b | 888 | 0 |
| phase_8b1 | 2,218 | 0 |
| phase_8b2 | 3,951 | 0 |
| phase_9b3b3 | 2,467 | 0 |
| phase_10b4 | 1,091 | 0 |
| phase_10c1a | 1,039 | 0 |
| phase_10c1b | 1,039 | 0 |
| phase_10c1c | 1,267 | 0 |
| phase_10c2a | 3,597 | 0 |
| phase_10c2b | 221 | 0 |
| phase_10c2c | 533 | 0 |

**20 runners, 22,285 executed overlapping assertions.** Tests were unchanged.
Source expectations in `combat_flee_test.gd`, `combat_resolution_cutover_test.gd`
and `oldpine_playability_test.gd` were rechecked against formulas, ordering and
explicitly authorized compatibility boundaries, including no-positive-damage floor,
12-item bootstrap, zero RNG Flee, stored-target rules and failure receipts.

## 20. Full canonical suite

Fresh complete `godot --headless --path game --script res://tests/run_tests.gd`:
**16,132 assertions PASS, 0 failures, exit 0**. Log
`build/cxr10-full-canonical.log`. Run once; the original running process was awaited
to a reliable completion, not replaced by repeated full-suite retries.

## 21. Static/repository/build validation

- Development headless editor PASS; `tools/ci/repository_checks.py` PASS.
- Current and main...HEAD `git diff --check` PASS; changed-file trailing whitespace 0.
- All **81** introduced UID sidecars have source files/valid IDs; tracked UID
  collision groups **0**. No legacy-source modifications.
- Owner-worktree Python **45/46**: unchanged
  `test_mobile_presentation_survives_sanitizing_without_fakes` expects the missing
  owner-config viewport-width field. Exact tracked archive Python **46/46 PASS**.
  Logs `build/cxr10-python-owner.log` and `build/cxr10-python-tracked.log`.
- Normal existing Windows and Android build entry points PASS from that exact
  archive, including sanitized headless editor. Windows ZIP **39,099,303 bytes**;
  logs `build/cxr10-windows-build.log`, `build/cxr10-android-build.log`.
- Sanitizer removes QA/tests/plugin/debug and retains production Shell/Settings/
  Battle. Fresh pre-export `build/cxr10-sanitizer-check` validates PASS.
  Re-validating already-configured export stages initially rejected their local
  template paths: `build.py` intentionally inserts those paths AFTER sanitation
  validation. This is not a distributable project-config change or a masked test;
  the separate untouched sanitizer output was used for the correct invariant.
- Android exporter warned about a template themed-icon path; export/package
  validation returned success. This is not physical startup evidence.
- Windows artifact gameplay was not separately exercised; desktop proof above is
  the editor project. The exact Android artifact was installed and exercised as above.
- iOS validation not run on Windows; required future CI compile/export validation
  does not establish physical iOS qualification. No CI result is inferred.

## 22. Current deferred scope

Authored martial/internal/spell/item techniques; meaningful enemy specials and
telegraphs; pursuit/vendetta fidelity; armed/practice-weapon SPAR; final art/VFX/audio;
broad balance; accessibility/localization; physical iOS; broader Android/tablet
qualification. Phase10D remains PARKED/FROZEN. No new demo/store/release phase began.

## 23. Integration readiness

- FINAL_LOCAL_AUDIT: **PASS within the explicitly separated owner-config boundary**.
- ANDROID_AFFECTED_PATH_GATE: **PASS — bounded physical OnePlus 8T evidence above**.
- CXR10: **FINAL LOCAL AUDIT COMPLETE; READY FOR FINAL INTEGRATION PR**.
- Final audit successor is documentation-only, preserving the exact tested gameplay.
- STATUS/ROADMAP: updated after both local and physical gates passed.
- Final PR: pending creation when this document is committed; remote PR HEAD/run/job
  evidence is reported externally after creation, not predicted here.
- Godot Verify / Windows Release Build / Android Release Build / iOS Build Validation:
  **NOT RUN for a CXR10 final PR**, no successful conclusions claimed.
- Merge: **NOT MERGED**. READY_TO_MERGE: **NO**.

The four required PR jobs must pass on the same final HEAD before READY_TO_MERGE
can become YES. No documentation-only commit should be added merely to record those
CI IDs after green CI; use the owner report. Stop for separate merge authorization.
