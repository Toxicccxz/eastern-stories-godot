# Phase 10C1A — Application Shell, Main Menu, and Continue

## Scope and result

Phase 10C1A replaces implicit New Game startup with a production application shell. The native save
contract and snapshot schemas are unchanged. The canonical hierarchy is:

```text
ApplicationShell (PROCESS_MODE_ALWAYS)
├── RuntimeHostSlot
│   └── OldPineGameRuntimeHost (PROCESS_MODE_ALWAYS; persistent)
│       ├── SessionSlot (PROCESS_MODE_PAUSABLE)
│       │   └── zero or one OldPineWorldSessionController (INHERIT)
│       └── StagingSlot (PROCESS_MODE_PAUSABLE; restore candidate only)
└── ShellCanvas
    ├── MainMenuPanel
    ├── BusyOverlay
    └── ResultOverlay
```

`OldPineGameRuntimeHost` remains the sole current-Session authority. `ApplicationShellController` stores
the Host reference, typed navigation state, slot availability metadata, and product result only. It never
stores a `GameSaveSnapshot` or a second current-Session pointer.

## Typed application state and result boundary

The implemented state subset is `BOOT`, `MAIN_MENU`, `STARTING_SESSION`, `PLAYING`, and `RESULT`.
`STARTING_SESSION` is valid only with `NEW_GAME` or `CONTINUE`; the other reachable modes accept no active
operation except BOOT slot inspection. Invalid mode/operation combinations reject through
`ApplicationShellState.is_valid()`.

`ApplicationSlotInspection` maps repository results to `NO_SAVE`, `CONTINUE_AVAILABLE`,
`RECOVERY_REQUIRED`, `SAVE_UNUSABLE`, `UNSUPPORTED_SAVE`, or `STORAGE_FAILURE`. The shell retains only
this metadata. Continue always asks the Host to call `OldPineSessionLoadCoordinator.load_replacing()`,
which re-reads and revalidates the canonical file.

`ApplicationOperationResult` and `ApplicationProductResultMapper` convert repository/runtime outcomes to
stable product outcomes and message keys. Presentation uses `ApplicationMessageCatalog`; it does not
parse diagnostic detail, inspect paths, or perform file operations.

## Host lifecycle

The existing `configure_before_start()` behavior remains available for closed Phase 10B bare-Host
regressions. The new `configure_manual_before_start()` mode enters the SceneTree with no Session and no
staging child. Explicit deferred requests now cover slot inspection, New Game, canonical Continue, and
end Session. They share the existing Host request gate with Save/Load.

New Game initializes after explicit intent, validates the complete Session and one active map, and sets
the authoritative pointer only after validation. Failure detaches the partial graph and leaves an empty
Host. Continue reuses the closed Phase 10B A/B restore composition. `session_invariant_holds()` proves
zero or one committed child, exact pointer/parent agreement, an initialized active map, and no staging
leak after each new lifecycle operation.

## Menu policies

- No save: New Game enabled; Continue disabled.
- Valid canonical save: both actions enabled; no automatic Continue.
- Recovery, invalid, unsupported, or storage failure: Continue disabled and a typed status is shown.
- New Game with possible save material requires confirmation. Confirming starts a new runtime Session but
  does not write, remove, rename, or overwrite save files.
- Failed Continue returns a typed Result over Main Menu with an empty Host. It never falls back to New
  Game.
- Busy and Result overlays stop mouse input and disable underlying menu actions. The first enabled New
  Game button receives deterministic focus, and normal `ui_accept` activates it.

## Reset removal and QA profile ownership

The Outdoor Reset button, signal, handler, Session connection, and `reload_current_scene()` seam were
removed. The standalone historical combat-slice Reset is outside this application-shell path and was not
expanded or redesigned.

The development QA bridge now configures `ApplicationShellController` before Shell `_ready()`. The Shell
then configures the Host exactly once before adding it to the SceneTree. Already-configured direct bare
Hosts remain supported for Phase 10B tests. QA-only F6 Save and F7 corrupt-canonical fixture inputs support
live acceptance testing and are removed with the entire bridge by the release sanitizer. Production Shell
defaults independently to the release storage profile.

## Automated verification

`res://tests/run_phase_10c1a_tests.gd` runs the new shell/state suite plus the targeted repository,
Phase 10B Host/transaction, resident-Session, and Outdoor smoke regressions. It passed **776 assertions**. Coverage
includes state validity, every menu availability category, absence of snapshot authority, product
mapping, manual empty startup, request serialization, New Game success/failure, twelve bootstrap items,
end/restart cycles, canonical Continue, read-after-inspection failure, zero/one ownership, staging cleanup,
development profile propagation, filesystem non-mutation, focus/overlay behavior, and Reset absence.

The full historical suite was registered but deliberately not run during implementation. Its runner
passed Godot `--check-only` parsing. Godot 4.7.2 development editor load and a fresh-process canonical
main-scene smoke exited zero. The latter logged `BOOT/INSPECT_SLOT -> MAIN_MENU` with development profile,
`SessionSlot=0`, and `StagingSlot=0`.

The sanitizer Python suite passed 9 tests. A fresh sanitized project retained ApplicationShell and all
production Save/Load systems, removed tests, QA, Godot AI, and remote-debug configuration, validated its
canonical main scene, passed Godot 4.7.2 editor import, and completed a 60-frame sanitized main-scene
smoke with exit 0.

## Live runtime evidence

Godot AI 3.2.4 with Godot 4.7.2 reported `helper_live=true`, `session_active=true`, no current-run errors,
current non-stale captures, and advancing frames.

- Cold no-save process: root `ApplicationShell`; one Host; `SessionSlot=0`; `StagingSlot=0`; Main Menu
  visibly showed “No saved journey was found”, New Game enabled, Continue disabled.
- New Game: keyboard `ui_accept` on focused New Game created exactly one Session, no staging candidate,
  revealed Outdoor gameplay, and real movement changed Player position from `(450, 300)` to approximately
  `(450, 252.33)`.
- Canonical Continue: a fresh process displayed enabled Continue; real mouse activation restored exactly
  one Cave Session through the production path; movement changed Player position from `(0, 120)` to
  approximately `(58.67, 120)`.
- Failed Continue: after valid advisory inspection, the QA fixture corrupted canonical bytes. Real mouse
  Continue re-read storage, displayed the typed recovery-required result, and left both SessionSlot and
  StagingSlot empty with no New Game flash.
- Four separate shell process starts retained one Shell, one Host, and no duplicated Session children or
  signal-visible behavior. The pre-existing development save directory was preserved during the no-save
  test and restored afterward; the QA-corrupted canonical was restored from its original valid backup.

The already-open editor retained its pre-change in-memory main-scene setting, so interactive runs selected
the exact new Shell scene explicitly. A separate fresh headless process read `project.godot` from disk and
proved the canonical ApplicationShell main path and empty-host boot independently.

## Explicit deferrals

Phase 10C1B retains Pause/Resume, Save UI, recovery candidate selection, and Return-to-Main-Menu UI.
Phase 10C1C retains Settings, controller/focus hardening, Android Back, touch/safe-area work, and final
cross-platform shell integration. In-game Load, multiple slots, autosave, dirty tracking, mobile
lifecycle, cloud/platform saves, and Phase 10C2 remain out of scope.
