# Phase 10C1C — Settings, Focus, and Release Validation

Status: **FORMALLY CLOSED** after the [formal audit](PHASE_10C1C_FORMAL_AUDIT.md),
on `phase/10c1-cross-platform-game-shell`.

The record below preserves implementation-gate evidence. The subsequent formal audit corrected
transition input clearing, keyboard-repeat bleed, busy-input consumption, and explicit portable
keyboard device bindings. Its final focused suite passed 1,267 assertions; the complete historical
suite passed 10,541 assertions in one run. Phase 10C1 still requires its final major-phase audit.

## Shutdown recovery

Recovery began on `phase/10c1-cross-platform-game-shell` at closed baseline `3a449be`, with no staged
changes. Six tracked files already contained Phase 10C1C edits: shell state/controller/scene,
`project.godot`, sanitizer, and its Python tests. Untracked work already contained the seven typed
settings scripts, desktop window adapter, new shell tests, focused runner, and their Godot UIDs.

Every changed/new source was inspected before testing; no truncated or half-written file was found.
The interrupted implementation still needed input-test timing fixes, native window verification,
full real shell acceptance, sanitizer hardening/release smoke, documentation, and final commit.
All valid pre-shutdown work was retained; no reset, restore, clean, or replacement of that work occurred.

Recovery corrections included one old test-only repository/files reentry reference cycle (explicitly
released at teardown), two deferred-input observation timings, the editor-embedded window capability
guard, fixed native controller accept/cancel bindings, and strict sanitizer QA/path checks. No closed
gameplay or save-transaction production semantics were redesigned.

## Settings authority

Application settings are a separate typed boundary:

- `ApplicationSettingsSnapshot` schema v1 contains only `WINDOWED | FULLSCREEN`;
- `ApplicationSettingsRepository` owns the strict ConfigFile at
  `user://settings/application-v1.cfg`;
- `ApplicationSettingsService` applies through `ApplicationWindowModeCapability` and then persists;
- `GodotWindowModeCapability` is the desktop DisplayServer adapter.

Missing, malformed, unsupported, and unreadable settings default safely to Windowed without blocking
the game menu. Strict loading rejects additional sections/keys and wrong types. Runtime application
failure never writes the selected value. If runtime application succeeds but writing fails, the mode
remains effective for this run, Settings remains open, and the user sees an explicit unsaved warning.
This authority never enters GameSaveSnapshot or `user://save-data/`.

Editor-embedded games cannot change window mode; Godot exposes this through
`Engine.is_embedded_in_editor()`. That environment is treated as a non-editable capability, while a
native desktop game exposes the control.
See the [Godot Engine API](https://docs.godotengine.org/en/4.6/classes/class_engine.html#class-engine-method-is-embedded-in-editor)
for the engine-owned embedding capability limitation; it is not an LPC gameplay decision.

## Shell, focus, and input

`ApplicationShellState.SETTINGS` carries exactly one typed origin: Main Menu or Paused. Paused-origin
Settings preserves `SceneTree.paused`, the exact Session, physical position, and RNG state. Apply and
Cancel both return to the typed origin.

Every interactive shell surface owns an explicit closed focus cycle. Disabled Continue/Recovery and
unavailable recovery sources cannot receive effective focus. Result, Recovery, Settings, Pause, and
Main Menu assign deterministic primary focus. The highest modal owns `ui_cancel`; PLAYING does not
interpret generic cancel. Shell transitions release held movement/accept/cancel/pause actions, and the
full-screen overlays stop mouse input from reaching the gameplay HUD/world.

Keyboard, mouse, and Godot-native controller events were exercised through the actual Viewport/UI
path. Static semantic bindings include controller A=`ui_accept`, B=`ui_cancel`, D-pad/stick native UI
navigation, and Start=`pause_game`. This is not a remapping system.

## Real runtime evidence

Validation used a dedicated `APPDATA` under `build/phase10c1c-live-user`; developer saves were not
touched. Godot AI 3.2.4 reported `helper_live=true`, `session_active=true`,
`game_capture_ready=true`, no launch errors, and advancing non-stale frames.

- Native Main Menu Settings changed the real DisplayServer state from Windowed to Fullscreen
  (`mode=3`, 2560x1440), wrote `window_mode="fullscreen"`, and visibly changed the desktop window.
- A fresh process (different PID) booted directly in that persisted Fullscreen state. QA then restored
  Windowed (`mode=0`) through the real Settings UI.
- Cold boot had one ApplicationShell, one Host, zero Session, and deterministic New Game focus.
- Real New Game created one Session with 12 bootstrap items; real movement changed the player position.
- Real Pause froze the tree. Settings Apply/Cancel returned to Pause while Session identity, position,
  and all three RNG states remained unchanged. Resume restored movement.
- Stable Pause/Save succeeded and remained paused. Walking into authored bandit aggression made Save
  return the typed combat blocker; canonical and backup hashes did not change.
- Return confirmation ended the exact Session before returning to one Host/zero Session. Continue
  restored one fresh Session and movement still worked.
- QA setup copied existing valid save bytes to `.tmp` and corrupted canonical before the claimed
  Recovery path. The real menu exposed both explicit candidates and selected neither automatically.
  Selecting “previous completed save” restored the backup position, kept canonical corrupt, and did
  not promote either candidate. A later repeated flow selected the interrupted candidate.
- Repeated Return/Continue/Recovery/Settings cycles retained one Shell, one Host, one active Session,
  zero staging candidates, one Settings button handler, and the expected production plus QA Host
  listeners only.
- A held movement key during paused Settings was released by Cancel/Resume; ten following physics
  frames left the player position unchanged.

One QA inspection typo queried a nonexistent presentation property and parked that debug process.
It was stopped and relaunched. It was not a product runtime failure and was excluded from acceptance
evidence; all final runs had `current_run_errors=[]`.

## Settings/save separation and failures

Focused tests independently inject settings and gameplay file operations. They prove separate paths,
schemas, versions, failure outcomes, and repositories. Corrupt/unsupported settings do not disable a
valid Continue or Recovery candidate. Corrupt gameplay save does not reset valid settings. Settings
failures neither create nor destroy a Session and never mutate gameplay save bytes.

## Sanitizer and release

The release sanitizer retains ApplicationShell, all production settings types, the native window
capability, Host, Save/Continue/Recovery, and world/session code. It removes tests, QA bridge/startup
settings, Godot AI, and remote-debug 6107, and rejects local absolute paths in shipped source. The
engine-generated `.godot` cache is removed during preparation; its subsequently generated editor
executable metadata is not shipped source. Existing forbidden-reference checks still cover that cache.
The fresh sanitized project passed
validate-only, Godot 4.7.2 editor parsing, and an external canonical-main smoke with no QA/Godot AI:
14 assertions proved release profile, the fixed production settings path, one Host, zero hidden
Session, Main Menu focus, real `ui_accept`, and exactly one New Game Session.

A separate visible process launched the sanitized project's canonical main scene normally, without
an external smoke script, QA bridge, or Godot AI. Real desktop mouse input activated New Game from
the production Main Menu, then Escape opened the production Pause overlay. This is a sanitized-project
smoke, not a claim of an exported store build.

## Focused verification

- Phase 10C1C plus targeted 10C1A/10C1B/10B runtime regressions: **1,175 assertions PASS**.
- Python tooling: **41 tests PASS**.
- Repository/static checks: PASS.
- Development and sanitized Godot 4.7.2 headless editor validation: PASS.
- Sanitizer prepare plus validate-only: PASS.
- Sanitized canonical-main smoke: **14 assertions PASS**.
- `git diff --check` and trailing-whitespace check: PASS.

The canonical historical Godot suite was deliberately not run during implementation. Phase 10C1C
is registered in that runner for the formal audit.
No LPC mechanics were migrated or altered in this application-only slice. `reference/es2` and
`DECISIONS.md` have zero changes. No PR was created and no CI, merge, or post-merge result is claimed.

## Deferred

Phase 10C2 retains Android Back mapping, touch controls, safe areas, orientation, and mobile lifecycle.
Autosave, in-game Load, multiple slots, cloud/platform saves, localization, audio/graphics settings,
and key remapping remain later work. No Phase 10C2 behavior was implemented here.
