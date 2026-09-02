# Phase 10C1B — Pause, Save, Recovery, and Return to Main Menu

## Scope and result

Phase 10C1B completes the manual in-game shell lifecycle that began in Phase 10C1A. It adds application Pause/Resume, paused Save UX, explicit recovery-source selection, and confirmed return to the Main Menu. It does not add Settings, in-game Load, multiple slots, autosave, mobile lifecycle, or any gameplay rule.

The native Phase 10B save snapshot, transactional restore, save eligibility, and zero-or-one current-Session authority remain unchanged. `OldPineGameRuntimeHost` is still the only owner of the current Session; the shell stores only typed UI/navigation state and narrow slot metadata.

No LPC gameplay source was consulted because this phase is Godot application/runtime composition rather than an ES2 mechanic migration. `reference/es2/` is unchanged.

## Pause process policy

The production hierarchy uses these process modes:

- `ApplicationShellController`: `PROCESS_MODE_ALWAYS`;
- `OldPineGameRuntimeHost`: `PROCESS_MODE_ALWAYS`;
- Host `SessionSlot` and `StagingSlot`: `PROCESS_MODE_PAUSABLE`;
- committed and staged Session roots: inherited pausable behavior.

Entering Pause sets `SceneTree.paused = true`; it does not consult `OldPineSaveEligibilityResult`. This keeps application Pause available during combat and other unstable gameplay while freezing Session physics, timers, cadence, aggression, movement, RNG consumption, and item-ID allocation. Shell and Host deferred operations remain available. Resume changes the typed state back to `PLAYING` and then clears the tree pause.

`ApplicationShellState` now models `PAUSED`, `SAVING`, and `RECOVERY_CHOICE`, plus a typed `ResultOrigin` of `MAIN_MENU` or `PAUSED`. Result dismissal therefore returns to the correct surface without parallel navigation booleans.

## Save UX and result mapping

Save is offered only from Pause. The sequence is:

```text
PAUSED -> SAVING -> RESULT(origin=PAUSED) -> PAUSED
```

The existing Host capture/repository transaction remains authoritative. A successful Save displays `Your journey was saved.` and never resumes gameplay automatically. Existing typed eligibility failures are grouped only for product presentation:

- opponent, lethal marker, guarding, busy, interrupt threshold, aggression, or cadence -> combat/unfinished action;
- map handoff or cave exit -> world transition;
- lifecycle inconsistency -> lifecycle change;
- unrepresented attribute modifier -> temporary effect;
- missing/not-ready runtime -> runtime not ready;
- capture and repository failures -> distinct preparation/write messages.

The mapper does not expose diagnostic paths or internal error text. A blocked Save performs no repository mutation and does not alter the blocking gameplay state.

## Recovery boundary and UI policy

`GameSaveRecoverySource` is the closed typed source domain: `BACKUP` and `TEMP`. `GameSaveSlotInspectionResult` exposes only the canonical repository outcome and a defensive list of validated fixed sources. It contains no path, snapshot, or mutable repository data. `ApplicationSlotInspection` carries the same narrow source identities into presentation.

`GameSaveRepository.inspect_slot()` validates candidates in deterministic `BACKUP`, then `TEMP` order. `load_recovery(source)` re-reads and revalidates exactly the player-selected fixed candidate. `OldPineSessionLoadCoordinator.load_recovery_replacing()` then uses the already-closed transactional candidate restore path. It neither falls back to another source nor renames, copies, promotes, deletes, or rewrites any save file.

When canonical Continue is unavailable but a candidate is valid, the Main Menu enables Recovery and disables Continue. Recovery opens an explicit choice screen: previous completed save, interrupted save candidate when present, New Game, or Cancel. No source is preselected or auto-loaded. A failed selected recovery returns a typed Main Menu result and leaves Host, SessionSlot, and StagingSlot empty.

## Return-to-menu teardown

Return is always confirmed with `Progress since the last successful save may be lost.` It does not infer dirty state. Confirmation requests Host teardown while the SceneTree remains paused. Host validates the current Session invariant before removing the exact committed Session; a validation failure retains the same Session and paused state. On success the shell observes zero committed/staged Sessions, clears pause, and performs a fresh repository inspection before showing Main Menu. Continue therefore reflects storage after the completed teardown.

## Input precedence

Desktop `pause_game` maps Escape. In `PLAYING` it requests Pause; in `PAUSED` it resumes; in a paused-origin Result it dismisses back to Pause; in `RECOVERY_CHOICE` it cancels to Main Menu. Busy, recovery, pause, and result overlays stop mouse input, and the typed mode permits only the active modal action. Gameplay input remains below these application overlays. Full controller focus hardening and Android Back mapping remain deferred.

## Automated verification

`res://tests/run_phase_10c1b_tests.gd` covers Phase 10C1A/10C1B shell behavior and targeted repository, transaction, Session, and Outdoor regressions. The stabilized focused run passed **987 assertions**. New coverage includes:

- valid/invalid state and Result-origin combinations;
- every Save blocker product category;
- deterministic, defensive recovery inspection;
- exact-source re-read, candidate change after inspection, and no fallback/promotion;
- paused Player/Timer/RNG/allocator freeze;
- stable paused Save and blocked paused Save with zero mutation;
- failed end preserving the exact paused Session;
- teardown-before-unpause and refreshed Continue;
- return/Continue roundtrip with fresh runtime identity;
- explicit backup/temp content selection and zero staging leak.

The complete historical suite is intentionally reserved for Formal Audit and was not run during implementation.

## Live Godot evidence

Godot 4.7.2 and Godot AI 3.2.4 reported `helper_live=true`, `session_active=true`, current non-stale captures, advancing frames, and no current-run errors.

- Real Continue restored one Cave Session. Real movement changed Player position before application Pause.
- With Pause visible, framebuffer frames advanced while Player position, all five NPC positions, combat/NPC/world RNG states, relationship state, cadence/aggression state, and allocator sequence remained identical.
- Real paused Save displayed the success message, stayed paused, and required explicit Resume.
- In an authored combat relationship, real paused Save displayed the combat/unfinished-action blocker; position, relationship, cadence, RNG, and allocator evidence did not change. Resume continued gameplay.
- Real Return displayed the unconditional loss warning, tore down to `SessionSlot=0` and `StagingSlot=0`, unpaused only afterward, refreshed Main Menu, and real Continue restored exactly one fresh Session.
- After canonical corruption with a valid backup, Main Menu disabled Continue and offered Recovery. The recovery screen stated that nothing was selected automatically and exposed only `Previous completed save`. Selecting it restored one Cave Session and real movement changed `x=0` to approximately `58.67`.
- Before and after recovery, canonical remained the same one-byte invalid file and backup retained SHA-256 `1B7FA61BC691AE4FBBE900B01B0A126F69A552CCF7AF26B2038ED3E2C2FD25A0`, proving no promotion or rewrite. Returning without Save still exposed Recovery.
- Final captures had `stale_frame=false`; frame count advanced from 116437 to 116711. The pre-test development save was restored byte-for-byte afterward.

## Release sanitizer

A fresh sanitizer run and `--validate-only` both passed. The output retained the production Shell, Pause/Save/Recovery UI, typed recovery API, repository/coordinator/Host restore path, and return-to-menu lifecycle. It removed the complete tests directory, QA bridge and corruption fixture, Godot AI, remote-debug arguments, and QA settings. Its canonical main scene remained `res://scenes/application/application_shell.tscn`; Godot 4.7.2 headless editor loading and a 60-frame sanitized main-scene smoke both exited zero.

## Explicit deferrals

Phase 10C1C retains Settings, window mode, full controller focus/input hardening, sanitizer integration refinements, and final shell validation. Phase 10C2 retains Android Back, touch controls, safe-area/notch handling, orientation, and mobile lifecycle. In-game Load, multiple slots, autosave, dirty-state tracking, cloud/platform saves, and later gameplay/content remain deferred.
