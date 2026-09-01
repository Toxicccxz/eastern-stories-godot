# Phase 10C1B — Formal Audit

## Verdict

Phase 10C1B passes formal audit. The application can pause, attempt a Save, explicitly recover from a selected fixed source, and return to the Main Menu without weakening the Phase 10B persistence contract or creating a second Session authority.

The audit found no production correctness defect. It added test-only coverage for previously under-proved boundaries. No gameplay formula, content, LPC source, production GDScript, scene, or project setting changed during the audit.

Audit baseline: Phase 10C1B implementation commit `c40b03f` on `phase/10c1-cross-platform-game-shell`.

## Authority and inspected scope

The audit re-read:

- `AGENTS.md` and `docs/AGENTS.md`;
- `docs/production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md`;
- `docs/migration/PHASE_10C1_CROSS_PLATFORM_GAME_SHELL_ANALYSIS.md`;
- `docs/migration/PHASE_10C1A_SHELL_MAIN_MENU_CONTINUE.md`;
- `docs/migration/PHASE_10C1A_FORMAL_AUDIT.md`;
- `docs/migration/PHASE_10C1B_PAUSE_SAVE_RECOVERY_RETURN.md`;
- the complete `073887e..c40b03f` implementation diff and every changed Phase 10C1B source/test file;
- the existing Phase 10B repository, coordinator, restore, eligibility, Session, item, RNG, and file-operation authorities referenced by those changes.

No LPC file was consulted because this is application/runtime composition, not a migrated ES2 gameplay mechanic. `reference/es2/` remains unchanged.

## Process-mode and pause audit

The runtime hierarchy is coherent:

- `ApplicationShell` is `PROCESS_MODE_ALWAYS`;
- `OldPineGameRuntimeHost` is `PROCESS_MODE_ALWAYS`;
- Host `SessionSlot` and `StagingSlot` are `PROCESS_MODE_PAUSABLE`;
- committed/staged Sessions inherit the pausable boundary.

Pause admission checks only that the Shell is playing and the Host owns a coherent, non-pending Session. It deliberately does not call `OldPineSaveEligibility`, so combat or another unstable save state cannot prevent the player from opening Pause. Save remains a separate Host request and reuses the Phase 10B eligibility authority.

The strengthened focused test freezes a real Session for multiple frames and verifies unchanged Player/NPC positions and velocities, Timer time, all three RNG streams, item-ID allocator sequence, lifecycle/existence, combat relationships, guarding, registered item identities, wielded equipment, and worn armor. Shell and Host deferred work remain live above that boundary. No second pause authority or local save-eligibility clone exists.

## Save and product-result audit

Save is reachable only from `PAUSED` and follows:

```text
PAUSED -> SAVING -> RESULT(origin=PAUSED) -> PAUSED
```

Success stays paused. Capture and repository failures remain distinct. The audit expanded typed mapping tests across every blocked `OldPineSaveEligibilityResult` outcome: runtime readiness, world transition, lifecycle, temporary effect, and combat/action categories. No mapper parses `detail`, path text, or other diagnostics.

Repeated Save intent is rejected once the typed state leaves `PAUSED`. A blocked Save preserves the blocker, consumes no RNG or item ID, and performs no repository write.

## Recovery audit

Recovery state is narrow and defensive:

- source identity is the closed `BACKUP` / `TEMP` domain;
- inspection results contain no path, snapshot, repository object, or runtime Session;
- returned source arrays are defensive copies;
- candidate discovery is deterministic in `BACKUP`, then `TEMP` order;
- corrupt candidates are excluded;
- a valid canonical remains the default Continue path even when valid recovery files also exist;
- the Application exposes recovery choices only when canonical Continue is unavailable.

Selection causes `GameSaveRepository.load_recovery(source)` to re-read exactly the chosen fixed file. Restore then uses the Phase 10B transactional candidate path. A changed/corrupt selected candidate fails with an empty Host and cannot fall back to the other valid candidate. No inspection or recovery path copies, renames, promotes, deletes, or rewrites save files.

The Shell does not instantiate a repository and does not perform file I/O. Its existing injected `SaveFileOperations` seam is only forwarded during Host construction for deterministic tests; Host/coordinator/repository retain persistence authority. The Shell stores no `GameSaveSnapshot` and no current Session pointer.

## Return-to-menu and modal audit

Return always presents the unconditional progress-loss warning. Confirmation is single-shot: repeated Return or confirm intent cannot queue another operation. Host validates the exact committed invariant before mutation, removes that Session, clears its sole pointer, and queues the detached graph for deletion. The Shell keeps the tree paused until successful empty-Host confirmation, then unpauses and requests a fresh slot inspection before exposing Main Menu.

An invariant failure is mutation-free: the same Session remains under `SessionSlot`, the tree remains paused, and the result returns to Pause. Success leaves `SessionSlot = 0`, `StagingSlot = 0`, no hidden Session, and refreshed Continue metadata.

Typed mode owns modal precedence. Busy, Pause, Recovery, and Result overlays stop mouse input; Escape has one mode-specific meaning and is ignored by busy states. Underlying gameplay cannot consume the accepted pause/menu input path.

## Live Godot audit

Godot `4.7.2.stable.steam.ed1daf0bf` with Godot AI `3.2.4` reported `helper_live=true`, `session_active=true`, `game_capture_ready=true`, and no current-run errors. Captures were current (`stale_frame=false`) and frame counts advanced.

The mandatory TEMP path used only real player input after setup:

1. real Main Menu `Continue` restored the existing Cave save;
2. real movement changed Player `x` from `0` to approximately `131.99997`;
3. real Escape opened Pause;
4. the real `Save` button wrote that position and displayed the success result while the tree remained paused;
5. QA setup copied that valid canonical to the fixed TEMP path, then the existing QA-only F7 fixture corrupted canonical; BACKUP retained the original `x=0` save;
6. after a fresh main-scene launch, the real Main Menu disabled Continue and enabled Recovery;
7. the real Recovery dialog displayed both choices and stated that nothing was selected automatically;
8. a real mouse click chose `Interrupted save candidate`;
9. gameplay restored the TEMP-only Cave position near `x=131.99997`, not BACKUP's `x=0` position.

Before and after recovery, hashes were unchanged:

- corrupt canonical: one byte, SHA-256 `021FB596DB81E6D02BF3D2586EE3981FE519F275C0AC9CA76BBCF2EBB4097D96`;
- BACKUP: 23093 bytes, SHA-256 `1B7FA61BC691AE4FBBE900B01B0A126F69A552CCF7AF26B2038ED3E2C2FD25A0`;
- TEMP: 23106 bytes, SHA-256 `362497F7CF3E2B27EBC9D038F9C646F04DC1A6B69C4327152EC3B81BAD8EB26E`.

The restored runtime tree contained exactly one `OldPineWorldSession` under `SessionSlot` and zero children under `StagingSlot`. The pre-audit development canonical and backup were restored byte-for-byte afterward, and the QA TEMP file was removed.

## Object/resource lifetime investigation

The reported `10 ObjectDB instances / 4 resources` warning is not reproducible on a passing audit run. An initial sandbox-restricted attempt denied Godot `user://` writes, produced eight repository-test failures, and then emitted that exact early-failure cleanup warning. Re-running the same focused suite with valid `user://` access passed under `--verbose` with no leaked-instance or retained-resource warning. The final complete suite also exited without either warning.

No production lifetime fix was justified. This is a failed-test/harness cleanup artifact, not evidence of a production Shell/Session leak.

## Test additions

Only `game/tests/application/application_shell_phase10c1b_test.gd` changed during the audit. Added assertions cover:

- every typed SaveEligibility blocker mapping;
- defensive repository/application recovery-source arrays;
- canonical priority when recovery files coexist;
- invalid recovery-candidate exclusion;
- broader exact paused-state freeze;
- repeated Save, Return, and confirmation rejection.

Focused Phase 10C1B validation passed **1039 assertions**. The complete historical suite was run exactly once after the test changes stabilized and passed **10313 assertions**.

## Verification

- Phase 10C1B focused suite: 1039 assertions, PASS;
- complete historical Godot suite: 10313 assertions, PASS;
- Phase 10A Python tooling: 40 tests, PASS;
- repository/static checks: PASS;
- Godot 4.7.2 development headless editor validation: PASS;
- fresh release sanitizer and explicit `--validate-only`: PASS;
- sanitized-project headless editor validation: PASS;
- sanitized canonical main-scene 60-frame smoke: PASS;
- `git diff --check` and trailing-whitespace scan: PASS;
- `reference/es2/` modifications: zero;
- `docs/migration/DECISIONS.md` modifications: zero.

## Deferrals and closure

This audit did not start Phase 10C1C. Settings, window mode, final controller/focus hardening, Android Back, touch/safe-area/mobile lifecycle, multiple slots, autosave, in-game Load, dirty-state tracking, and cloud/platform saves remain deferred exactly as planned.

Phase 10C1B is formally closed. Phase 10C1C is safe to begin after this audit commit; the major Phase 10C1 branch still requires its later final integration PR, PR CI, merge to `main`, and green post-merge CI before the major phase is fully integrated.
