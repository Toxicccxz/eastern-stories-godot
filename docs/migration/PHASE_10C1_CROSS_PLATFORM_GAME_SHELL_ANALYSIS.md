# Phase 10C1 Cross-Platform Game Shell Analysis

## 1. Scope and conclusion

Phase 10C1 should add one platform-neutral application shell around the closed Phase 10B Runtime Host.
It must not put navigation into Game Core, duplicate the Host's current-Session authority, or change the
native save schema. The selected ownership hierarchy is:

```text
ApplicationShell (application navigation; survives every Session)
├── RuntimeHostSlot
│   └── OldPineGameRuntimeHost (sole current-Session authority; survives menu return)
│       ├── SessionSlot
│       │   └── OldPineWorldSessionController (zero or one playable Session)
│       │       └── ActiveMapSlot
│       │           └── one attached Outdoor or Cave resident map
│       └── StagingSlot
│           └── restore candidate only during a Load transaction
└── ShellCanvas (application presentation; always above map-owned HUD)
    ├── MainMenu
    ├── PauseMenu
    ├── SettingsPanel
    └── one confirmation/result/recovery modal layer
```

The canonical main scene should become an `ApplicationShell` scene. The shell creates/configures one
Runtime Host in an empty/manual startup mode before adding it to the SceneTree. The Host continues to own
the current Session pointer, creation, replacement, and destruction. The shell may query the Host but must
not cache a second authoritative current-Session reference.

This analysis consumes `docs/production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md`. It found no contradiction
requiring the Phase 10B history or LPC gameplay source to be reopened.

## 2. Current runtime inventory

### 2.1 Current hierarchy and lifecycle

The current main scene is `res://scenes/runtime/oldpine_game_runtime_host.tscn`, selected by
`game/project.godot`. It contains only `SessionSlot` and `StagingSlot`. In
`game/runtime/persistence/oldpine_game_runtime_host.gd`, `_ready()` currently does one of two things:

- explicit startup Load, exposing no New Game on failure; or
- immediate New Game creation.

There is no empty/menu startup mode. Consequently, merely overlaying a Main Menu would create a hidden
New Game and could expose it briefly on a failed Continue. Phase 10C1 needs a narrow manual-start Host
mode plus explicit typed New Game and end-Session operations. This extends application lifecycle without
changing Phase 10B save or restore semantics.

The Host exposes deferred `request_save()` and `request_load()` calls and typed completion signals. It
serializes requests with `_request_pending`. `OldPineSessionLoadCoordinator` owns the repository-facing
Save/Load operation and the A/B replacement transaction. `OldPineRuntimeSaveLoadResult` carries typed
eligibility, capture, repository, and restore results, but there is no product-facing message mapping.

`OldPineWorldSessionController` owns Player, Inventory, stacks, item index, the item-ID allocator, three
RNG streams, resident maps, and the authoritative active-map relationship. Exactly one resident map is
attached beneath `ActiveMapSlot`; the other is retained detached. Restore candidates and Session-swap
suspension deliberately use `PROCESS_MODE_DISABLED`.

### 2.2 Current gameplay UI and input

The Outdoor map owns `OldPineOutdoorHud`, a `CanvasLayer` containing status, combat actions, loot, and
inventory panels. These controls are map/session presentation and must remain inside the replaceable
Session. They must not own application navigation, Save/Continue, settings, or recovery.

Player movement is polled in `WorldCharacterBody2D._physics_process()` through `Input.get_vector()` using
the four movement actions. NPC/landmark/corpse selection and HUD actions use mouse/Control signals. There
is no application pause action, `ui_cancel` routing, shell focus policy, controller navigation policy, or
modal input owner.

The Outdoor HUD still includes a Reset button. Its path emits `reset_requested`, and the Session calls
`get_tree().reload_current_scene()`. Once the main scene is the shell, this would bypass confirmation and
Session ownership rules. Phase 10C1 must remove this obsolete runtime-reset entry rather than retain an
alternate New Game/navigation authority. This is narrow shell integration cleanup, not a gameplay-HUD
redesign.

### 2.3 Current processing and pause mechanisms

There is no application pause. Existing processing controls have narrower meanings:

- restore staging disables the candidate Session/map and Area input;
- Session-swap suspension disables current Session processing and stops/records combat cadence;
- inactive resident maps are detached from the SceneTree;
- the Outdoor controller uses `_process()` for pending aggression and a child `Timer` for combat cadence;
- Player movement and collisions run through `CharacterBody2D` physics.

`OldPineSaveEligibility` correctly rejects disabled/staged/transitioning owners. Those rules must remain
unchanged.

### 2.4 Current persistence/result surfaces

- `GameSaveSnapshot` and embedded `NativeItemStateSnapshot` remain closed authorities.
- `GameSaveRepository.load()` decodes and validates without constructing runtime state, so it is a sound
  basis for menu availability inspection.
- Repository results distinguish no save, malformed/invalid/unsupported data, storage failures,
  operation conflicts, and `BACKUP_AVAILABLE`.
- `BACKUP_AVAILABLE` currently proves only that a validated `.bak` or `.tmp` candidate exists. The
  repository does not expose a product-safe explicit candidate selection/load method.
- Save eligibility has typed blockers for runtime readiness, transitions, lifecycle, combat/cadence,
  busy/guarding, and unrepresented modifiers.

The missing recovery-selection API is the only persistence capability gap identified for 10C1. Filling
it must be a narrow typed extension; it must not add a schema, slot, automatic fallback, or UI filesystem
access.

### 2.5 Current settings and release boundary

No production `ConfigFile`, settings service, audio player, audio bus control, volume option, fullscreen
option, remapping UI, localization setting, or other user preference was found. The only relevant project
configuration is canvas-item stretch/aspect. Therefore 10C1 must not invent volume, graphics-quality,
language, accessibility, or control settings that have no present effect.

The sanitizer currently retains `core`, `data`, `runtime`, scenes, and production UI while removing
tests, the Phase 10B QA bridge, Godot AI, remote-debug text, and generated caches. Implementation will
need to change the expected main scene and require the new shell scene, while preserving every existing
removal rule.

## 3. Application-shell ownership

`ApplicationShellController` should be the one application-navigation authority. It owns:

- the typed shell state;
- which shell panel/modal is visible;
- pause/resume policy;
- menu focus and input precedence;
- application-result interpretation;
- settings loading/application;
- requests sent to the Host.

`OldPineGameRuntimeHost` remains the one current-Session authority. It owns:

- zero or one committed Session under `SessionSlot`;
- restore candidates under `StagingSlot`;
- New Game construction and validation;
- Continue/recovery candidate construction and replacement;
- Save capture/repository coordination;
- explicit end-Session cleanup;
- request serialization and typed runtime results.

The Host, Shell controller, Shell UI, and application settings survive Session replacement and Return to
Main Menu. Gameplay HUD, selection, combat presentation, Areas, timers, Player body, maps, NPC bodies,
and all other runtime embodiment stay inside the replaceable Session.

Temporary presentation state—focused button, open confirmation, progress indicator, last toast, and the
settings editor's uncommitted values—is never gameplay save state.

## 4. Typed shell state model

Use one validated `ApplicationShellState` value, not independent booleans. Its minimum fields are:

- `mode: ShellMode`;
- `operation: ShellOperation` when a transition is active;
- `return_mode: ShellReturnMode` only for Settings or Result presentation;
- one typed product result/slot inspection where the current mode requires it.

Suggested modes and invariants:

| Mode | Visible UI | Session/process/input | Operations and legal exits |
|---|---|---|---|
| `BOOT` | boot/progress | Host exists empty; tree unpaused; no gameplay input | load/apply settings and inspect slot → menu, recovery, or menu-result |
| `MAIN_MENU` | New Game, conditional Continue/Recover, Settings | no Session; tree unpaused | New Game → starting; Continue → starting; Recovery → recovery; Settings → settings(menu) |
| `STARTING_SESSION` | blocking progress over menu | no playable Session is exposed; Host may own an inert candidate | New Game/Continue/Recover success → playing; failure → result(menu) |
| `PLAYING` | Session and map HUD | exactly one live Session; tree unpaused; gameplay input accepted | pause action → paused |
| `PAUSED` | dim layer and Pause menu | exactly one Session; `SceneTree.paused=true`; gameplay input stopped | Resume → playing; Save → saving; Settings → settings(paused); Return → confirmation/result |
| `SAVING` | Pause menu plus blocking progress | same paused Session; Host/Shell still process | success/block/failure → result(paused) |
| `SETTINGS` | Settings panel | origin is typed as menu (no Session) or paused (one frozen Session) | Apply/Cancel → recorded origin; failure → result with same origin |
| `RECOVERY_CHOICE` | explicit candidate/choice dialog over menu | no Session | Recover → starting; New Game → confirmation/starting; Cancel → menu |
| `RESULT` | one typed message/confirmation modal | origin is typed as menu or paused | acknowledge/confirm/cancel → the result's declared legal continuation |

`ShellOperation` distinguishes inspection, New Game, canonical Continue, selected recovery, Save, end
Session, and settings write. Invalid combinations—for example `SAVING` with no Session, or
`SETTINGS(paused)` while the tree is unpaused—must fail validation in tests.

The state controller should be a small typed reducer/transition policy. Scene scripts render state and
forward intent; they do not independently decide navigation.

## 5. Cold-start policy

Cold start always reaches a Main Menu decision surface. It never automatically constructs or loads a
gameplay Session merely because a file exists.

Slot inspection decodes/validates files only. It does not build a restore candidate. Continue click is
the first point at which runtime reconstruction begins.

| Storage condition | Menu behavior |
|---|---|
| No canonical or recovery save | Continue disabled; New Game enabled |
| Valid canonical save | Continue enabled; no automatic Load |
| Invalid/missing canonical plus valid recovery candidate(s) | show explicit Recovery Choice; Continue canonical disabled |
| Invalid canonical and no valid recovery | show typed unusable-save result; Continue disabled; New Game remains possible |
| Unsupported schema/version | show a specific unsupported-save result; offer recovery only if separately validated |
| Repository/storage error | show storage error; Continue disabled; New Game may start, with a warning that later Save may also fail |

A failed Continue returns to menu/result with zero playable Sessions. It must not call or reveal New Game
as a fallback.

## 6. New Game policy

New Game is available only from Main Menu. In-game replacement is deliberately excluded.

- If no canonical/recovery material exists, New Game starts directly.
- If any canonical save, invalid canonical, or recovery candidate exists, show a confirmation explaining
  that New Game does not immediately delete it, but the next explicit successful Save will replace the
  fixed slot.
- Starting New Game performs no filesystem mutation.
- Returning to menu or exiting before Save leaves the previous canonical/recovery files unchanged.
- The first successful Save uses the existing repository transaction and becomes the new canonical save.
- Host creation must expose the Session only after the authored scene initializes successfully and the
  Host proves one committed child. Failure leaves the Host empty and returns a typed result.

No multiple slots, profile selection, character picker, autosave, or delete-save workflow belongs here.

## 7. Continue and Load policy

The selected product flow is:

```text
BOOT inspection
→ MAIN_MENU with Continue enabled
→ player activates Continue
→ STARTING_SESSION(canonical Continue)
→ Host uses the existing repository + restore candidate + coordinator path
→ success: exactly one playable Session, PLAYING
→ failure: zero playable Sessions, typed RESULT over MAIN_MENU
```

The menu availability result is advisory. Continue reads and validates the canonical file again so a
file changed after inspection fails safely rather than using stale snapshot data.

Phase 10C1 does **not** add an in-game Load button. The player can Return to Main Menu and Continue after
confirmation. This avoids a second confirmation/rollback UX while retaining Phase 10B's closed A/B
transaction internally for all restore composition. There is one Load implementation only.

## 8. Player-facing Save policy

Save appears in the Pause menu. It is not a gameplay-HUD button.

- Selecting Save enters `SAVING` while gameplay remains paused.
- Host request serialization disables conflicting shell actions until the result arrives.
- Success leaves the game paused and shows a concise inline/result confirmation. The player explicitly
  resumes.
- `SAVE_BLOCKED` stays paused and maps the typed blocker to understandable language.
- Repository/capture failures stay paused and show a blocking typed error with Retry/Back as appropriate.
- The UI never clears relationships, cadence, busy state, guarding, transitions, modifiers, or lifecycle
  work to make Save succeed.

Recommended product mappings group internal outcomes without parsing `detail` strings:

- Session/map staged, disabled, or transitioning: “The world is changing; try again in a moment.”
- Combat cadence, opponent/lethal relation, busy, interrupt, guarding, or pending aggression: “You
  cannot save during combat or an unfinished action.”
- Incomplete lifecycle or FINAL corpse: “A character or corpse transition is still resolving.”
- Unrepresented temporary modifier: “A temporary effect must finish before saving.”
- Capture/repository failure: “The save could not be written.” with a stable reason category.

Internal paths, enum names, IDs, and debug details remain available for diagnostics, not player text.

## 9. Pause semantics

Application Pause should use `SceneTree.paused`, not Phase 10B Session-swap suspension.

Required process policy:

- `ApplicationShell`, Shell input/UI, and `OldPineGameRuntimeHost` use `PROCESS_MODE_ALWAYS`;
- the Host's `SessionSlot` is explicitly `PROCESS_MODE_PAUSABLE` so it does not inherit the Host's ALWAYS
  mode;
- the committed Session and its map remain `PROCESS_MODE_INHERIT`, inheriting PAUSABLE from that slot;
- entering Pause sets `SceneTree.paused=true` only after the Session is stable;
- resume sets it to false without changing any Session/gameplay field;
- menu and boot always run with `SceneTree.paused=false`.

If `SessionSlot` were left as INHERIT, the Session would inherit ALWAYS from the Host and keep simulating;
the explicit PAUSABLE boundary is therefore mandatory. It freezes physics, Player movement, Areas,
Outdoor `_process()`, and the combat Timer while keeping the shell and deferred Host operation path
alive. It does not make the Session or active map
`PROCESS_MODE_DISABLED`, so an otherwise stable paused game remains eligible for Save. If combat cadence
was already running, the paused Timer remains logically running rather than stopped; the existing
eligibility rule therefore continues to block Save, as required.

The implementation must prove that Timer remaining time, positions, relationships, RNG, and other runtime
state do not change while paused and resume exactly. It must also prove that deferred Save completion
runs while the tree is paused. `SESSION_NOT_READY` must not be weakened.

## 10. Settings authority and storage

No currently authored audio or other cross-platform setting has a player-observable effect. Do not add
placebo volume, quality, language, remapping, UI-scale, or accessibility controls in 10C1.

One defensible Phase 10C1 setting is desktop window mode (`WINDOWED`/`FULLSCREEN`): its effect is immediate
and visible on desktop. The shell remains shared across platforms by querying a narrow presentation
capability adapter; on Android/iOS, where window mode is platform-managed, no interactive window-mode
control is shown. This is presentation capability handling, not a gameplay fork.

Use a separate typed application-settings authority:

```text
ApplicationSettingsSnapshot v1
└── window_mode: WINDOWED | FULLSCREEN

ApplicationSettingsRepository
└── user://settings/application-v1.cfg
```

The repository may use `ConfigFile` internally but must validate version, section, key, and value into a
typed snapshot. `ApplicationSettingsService` applies the snapshot through a narrow window-mode port so
pure tests can use a fake instead of changing the test runner's real window.

Settings never enter `GameSaveSnapshot` or `user://save-data`. Corrupt/missing settings fall back to the
current safe default (`WINDOWED` on desktop, platform-managed mode elsewhere) with a typed warning; they
must not affect Continue availability. A failed settings write reports that the preference was not
persisted. Audio settings remain deferred until actual audio exists.

## 11. Explicit recovery UX

The repository currently detects valid recovery evidence but cannot explicitly select it. Phase 10C1
needs a narrow typed addition:

- `SaveSlotInspectionResult` with canonical availability and validated recovery sources;
- a closed `RecoverySource` enum for the fixed `.bak` and `.tmp` candidates;
- repository/coordinator methods that re-read and validate the selected fixed candidate, then feed its
  snapshot into the existing restore/A-B composition path.

The UI receives source kinds and product outcomes, never paths or file operations. If both candidates are
valid, the Recovery dialog lists both with clear meanings (“previous completed save” for `.bak`,
“interrupted replacement candidate” for `.tmp`) and requires a player selection. No candidate is chosen
automatically.

Recovery loads the selected snapshot into a fresh runtime Session without copying, renaming, deleting, or
promoting files. The recovered state becomes canonical only after the player later chooses Save through
the normal repository transaction. Exiting before Save causes the same recovery choice on next launch.

Recovery choices are Recover, Start New Game, and Cancel/remain at Main Menu. Any failure returns to menu
with no fake Session.

## 12. Return to Main Menu

Pause → Return to Main Menu is in Phase 10C1.

There is no authoritative dirty-state/version comparison, so the shell must not pretend to know whether
progress is unsaved. It always asks for confirmation: “Progress since the last successful save may be
lost.” Save is a separate Pause-menu action, not an implicit prerequisite.

After confirmation:

1. reject the action if another Host operation is active;
2. while the tree remains paused, ask the ALWAYS-processing Host to detach/end the current Session and
   wait for typed completion, preventing one resumed gameplay frame during teardown;
3. after the Host proves its authority is null and the Session has exited, set `SceneTree.paused=false`;
4. clear shell-only transient result/focus state;
5. re-inspect the fixed slot;
6. show Main Menu with refreshed Continue/Recovery availability.

A blocked Save does not trap the player in gameplay. The player may still explicitly discard the current
Session after the unconditional warning. The old Outdoor Reset/reload path must be removed so it cannot
bypass this policy.

## 13. Product operation and error model

Introduce one narrow typed application interpretation boundary, for example:

```text
ApplicationOperationResult
├── operation: INSPECT | NEW_GAME | CONTINUE | RECOVER | SAVE | END_SESSION | SETTINGS
├── outcome: SUCCESS | NO_SAVE | RECOVERY_AVAILABLE | SAVE_BLOCKED |
│            INVALID_SAVE | UNSUPPORTED_SAVE | STORAGE_FAILURE |
│            RESTORE_FAILURE | SESSION_FAILURE | REQUEST_BUSY | SETTINGS_FAILURE
├── message_key: stable product message identifier
└── optional typed recovery sources / blocker category
```

Adapters map `OldPineRuntimeSaveLoadResult`, `GameSaveResult`,
`OldPineSaveEligibilityResult`, restore results, and settings results into this type. The mapping is
exhaustive and tested. The shell state controller consumes only this product result. Controls never parse
logs, paths, `detail`, or enum names.

The first implementation may contain English display strings in one message catalog; localization
infrastructure is not required. Keeping stable message keys prevents strings from becoming control flow.

## 14. UI scene and focus structure

Use Godot `Control`/`CanvasLayer`, not web UI. The minimum useful structure is:

```text
ApplicationShell (Node, PROCESS_MODE_ALWAYS)
├── RuntimeHostSlot (Node)
└── ShellCanvas (CanvasLayer, high layer)
    └── FullRectRoot (Control)
        ├── MainMenuPanel
        ├── PausePanel
        ├── SettingsPanel
        ├── BusyOverlay
        └── ModalLayer (one reusable confirmation/result surface)
```

Do not create separate scenes for every one-line message. Main Menu, Pause, Settings, and one reusable
modal are sufficient. The Canvas layer is shell-owned and survives Session replacement.

Every mode transition explicitly focuses the first enabled primary button. Disabled Continue is skipped.
Settings/Result return restores a stable primary button rather than holding a reference to a freed
control. Modal/fullscreen overlays use mouse-stop behavior, consume handled input, and prevent clicks from
reaching map HUD/Areas. Standard Godot Button focus supports keyboard and controller navigation without a
controller-specific shell.

## 15. Input ownership and precedence

Add one semantic `pause_game` action with desktop keyboard and standard controller-menu bindings. Touch
and Android Back mappings are deferred. `ui_accept` and `ui_cancel` remain semantic menu actions.

Precedence is:

1. blocking operation/modal;
2. Settings or Recovery dialog;
3. Pause menu;
4. Main Menu;
5. gameplay.

The shell handles and consumes the event whenever levels 1–4 own it. `ui_cancel` closes Result/Settings,
cancels Recovery to menu, or resumes from Pause only when no higher-priority modal is active.
`pause_game` enters Pause only from `PLAYING`; it cannot interrupt map/Session operations.

`SceneTree.paused` prevents the polling Player physics loop from moving while a pause/modal is open, and
the shell overlay blocks mouse input to gameplay Controls/Areas. This dual boundary is required because
button focus alone cannot stop `Input.get_vector()` polling.

Phase 10C2 can later map touch and Android Back to these semantic intents without replacing the shell.

## 16. Release/sanitizer boundary

Implementation must update the sanitizer to:

- expect the new `ApplicationShell` as canonical main scene;
- require the shell scene and its production scripts/UI;
- continue retaining Runtime Host, codec, repository, allocator, capture, eligibility, restore,
  coordinator, recovery adapter, and settings authority;
- continue removing the QA bridge, all tests, Godot AI, remote-debug arguments, and any QA startup-load
  configuration;
- scan the sanitized project for forbidden test/QA references;
- run sanitized editor validation and production-main-scene smoke.

The shell and settings code belong in production directories, not under `tests` or an Autoload. A global
Autoload is unnecessary because the shell main scene already has the required lifetime.

## 17. Cross-platform and file separation

There is one shell scene/state machine for Windows, Android, and iOS. Platform-neutral work in 10C1
includes menu navigation, session operations, pause intent, typed results, recovery, focus semantics, and
settings persistence. A narrow capability adapter may report that desktop window mode is or is not
editable; it must not branch gameplay.

Persistent files remain separate:

| Concern | Authority/path | Phase 10C1 rule |
|---|---|---|
| Gameplay save | closed Phase 10B repository; `user://save-data/release/default-v1.json` | fixed one slot; schema unchanged |
| Application settings | typed settings repository; `user://settings/application-v1.cfg` | independent version and failure handling |
| Future mobile lifecycle data | not defined | Phase 10C2 |
| Logs/cache | engine/tooling concern | never gameplay or settings authority |

Settings corruption cannot version-lock or mutate the gameplay save. Gameplay recovery never reads the
settings file.

Explicit Phase 10C2 deferrals are virtual controls, touch HUD/layout, safe areas/notches, Android Back
mapping, orientation, background/foreground policy, mobile autosave, and lifecycle-triggered Save.
Phase 10D retains permanent IDs/signing, package/store UX, device/release gates, cloud/platform saves,
encryption, and release distribution policy.

## 18. Future real-runtime acceptance matrix

Implementation acceptance must use the real shell UI and real input, not direct controller callbacks:

| Scenario | Required player-visible evidence |
|---|---|
| Cold start | canonical main opens Main Menu; Host has zero Sessions; Continue state matches real slot inspection |
| New Game | keyboard/mouse activates New Game; exactly one initialized Session appears; gameplay becomes controllable |
| Pause/resume | real pause input freezes Player, physics/Areas, aggression, and Timer progress; shell focus remains live; resume continues exact state |
| Save success | Pause → Save through UI; typed success shown; gameplay remains paused until Resume |
| Save blocked | enter a real unstable combat/action state; Pause → Save shows understandable blocker; no gameplay state is cleared |
| Return/menu/Continue | Pause → confirmed Return leaves zero Sessions; menu re-inspects; real Continue creates exactly one restored Session |
| Fresh-process Continue | process A Save/exit; process B starts at menu and loads only after real Continue input; semantic state matches, runtime identities are fresh |
| Recovery | corrupt canonical plus valid backup opens explicit Recovery choice; player selects candidate; no automatic choice/promotion occurs |
| Failed Continue | corrupt/unsupported/read failure leaves menu visible and Host empty; no New Game flashes or becomes playable |
| Settings | desktop window-mode change visibly applies and persists across a fresh process; unsupported mobile capability does not expose a fake control |
| Input/focus | keyboard, mouse, and controller focus work; modal clicks/keys never move, attack, select, or activate underlying gameplay |
| Repetition | repeated New Game → menu → Continue/recovery cycles never leave duplicate Session/map/UI nodes |

Live validation should confirm helper liveness, advancing non-stale frames, current runtime tree, and no
runtime errors in accordance with root `AGENTS.md`.

## 19. Focused test strategy

### Pure application/state tests

- all legal state transitions and rejection of invalid mode/operation/origin combinations;
- startup availability mapping for no-save, valid, recovery, corrupt, unsupported, and storage errors;
- New Game and Return confirmations;
- exhaustive runtime/repository/eligibility-to-product result mapping;
- recovery-source selection with no automatic fallback;
- settings snapshot validation, defaults, capability mapping, and persistence failure.

### Runtime integration tests

- manual/empty Host startup and explicit New Game;
- failed New Game/Continue leaves Host empty;
- exactly one Session across creation, restore, failure, and end-Session;
- Pause freezes Session while Host/Shell remain operational;
- paused stable Save succeeds; active cadence/relationship Save remains blocked;
- Return to menu frees Session and refreshes slot availability;
- canonical and selected recovery Loads reuse one restore composition path;
- settings and gameplay repositories never share paths or schemas.

### UI tests

- panel visibility matches the typed state;
- first enabled control receives focus;
- disabled Continue is skipped;
- modal mouse/input stops underlying controls;
- result/Settings cancel returns to the correct typed origin;
- repeated transitions do not duplicate signals or controls.

### Live Godot tests

Run every scenario in the acceptance matrix with real UI/input. Retain only targeted Phase 10B
regressions for Host/repository/transaction seams; do not rerun or recreate the entire Phase 10B matrix in
each implementation slice.

## 20. Risk register

| Rank | Risk | Severity | Likelihood | Control |
|---:|---|---|---|---|
| 1 | Shell and Host both own “current Session” | Critical | Medium | Host is sole owner; shell stores only typed navigation state |
| 2 | Overlay menu allows hidden default New Game before Continue | High | High | manual/empty Host startup; no Session until explicit action succeeds |
| 3 | Pause either reuses Session-swap disable or lets Session inherit Host ALWAYS | High | High | `SceneTree.paused`, ALWAYS Shell/Host, explicit PAUSABLE SessionSlot, INHERIT Session; integration/live tests |
| 4 | Modal input leaks into movement, Areas, or HUD | High | High | paused physics, high Canvas layer, mouse stop, handled input, real-input tests |
| 5 | Recovery auto-selects/promotes files or UI manipulates paths | High | Medium | typed fixed-source repository API; explicit player choice; no promotion |
| 6 | Repeated transitions leak or duplicate Sessions | High | Medium | Host-owned zero/one invariant and child-count assertions at every transition |
| 7 | UI calls repository/file operations directly | High | Medium | Host/application adapter boundary and typed product result |
| 8 | Existing Reset/reload bypasses confirmation and Host cleanup | High | High | remove the obsolete HUD action during shell integration |
| 9 | Save blocker text depends on debug strings | Medium | Medium | exhaustive enum mapping to stable message keys |
| 10 | Settings enter `GameSaveSnapshot` or become placebo controls | High | Low | separate typed repository; only capability-backed window mode now |
| 11 | Return-to-menu claims reliable dirty detection | Medium | High | always confirm; no invented dirty tracker |
| 12 | Early mobile-specific shell fork | Medium | Medium | semantic input/capability ports; all 10C2 behavior remains deferred |

## 21. Proposed implementation slices

All slices stay on `phase/10c1-cross-platform-game-shell` and culminate in one final PR.

### 10C1A — Shell state, manual Host lifecycle, Main Menu and canonical Continue

Goal:

- add the typed state/result/slot-availability layer;
- make the new Application Shell the main scene;
- add manual/empty Host startup, explicit validated New Game, canonical Continue, and end-Session seams;
- implement Main Menu, blocking progress/result presentation, and zero/one Session ownership;
- remove the obsolete runtime Reset/reload entry.

Likely production areas:

- new `game/application/` typed state/policy classes;
- new `game/runtime/application/` shell controller/product adapter;
- new `game/scenes/application/` shell scene and minimal Controls;
- narrow updates to Runtime Host/coordinator, `project.godot`, and sanitizer expectations.

Tests/live validation:

- pure state/availability/result mapping;
- Host empty/New Game/Continue/failure/Session-count integration;
- cold Main Menu, real New Game, failed Continue, and fresh-process canonical Continue.

Deferrals: Pause Save, recovery selection, settings, mobile behavior.

### 10C1B — Pause, Save UX, explicit recovery, and Return to Main Menu

Goal:

- implement `SceneTree.paused` policy with ALWAYS Shell/Host;
- add Pause/Resume, player-facing Save, typed blocker messages, and unconditional Return confirmation;
- add typed recovery inspection/source selection and reuse the existing restore transaction;
- refresh menu availability after end-Session.

Likely production areas:

- Shell state/controller and Pause/Recovery/Result Controls;
- narrow repository/coordinator/Host recovery APIs;
- semantic pause input in `project.godot`;
- no save-schema or gameplay-state changes.

Tests/live validation:

- pause freeze/resume, paused Save success/block/failure, explicit recovery candidates, no promotion,
  Return cleanup, repeated cycles, modal input blocking;
- real combat-blocked Save, Return/Continue, and corrupt-canonical recovery flow.

Deferrals: in-game Load, autosave, dirty tracking, mobile lifecycle.

### 10C1C — Settings, focus hardening, release integration, and full shell validation

Goal:

- add typed separate settings persistence and desktop window-mode capability;
- finish keyboard/mouse/controller focus and cancel precedence;
- update sanitizer/build main-scene requirements;
- complete targeted regressions, sanitized smoke, and the full real-runtime acceptance matrix.

Likely production areas:

- settings snapshot/repository/service and capability port;
- Settings panel and shell focus/input code;
- sanitizer tests and durable production documentation after implementation closes.

Tests/live validation:

- settings parse/write/default/failure and fake capability tests;
- real visible desktop mode change and fresh-process persistence;
- all acceptance scenarios, repeated transition leak checks, sanitized production main-scene smoke.

Deferrals: all 10C2/10D items listed above.

## 22. Unresolved decisions

None. The analysis selects:

- Shell over persistent Host over replaceable Session;
- one typed shell-state authority;
- explicit menu choice, never automatic Continue;
- New Game only from menu and no overwrite until Save;
- startup/menu Continue only, no in-game Load;
- Save from Pause and remain paused after every result;
- `SceneTree.paused` with ALWAYS Shell/Host;
- separate settings persistence with only capability-backed desktop window mode;
- explicit typed recovery-source selection without promotion;
- unconditional Return-to-menu confirmation because no dirty-state authority exists;
- three implementation slices on one phase branch and one final PR.

## 23. Source inventory

Current production and contract files inspected directly:

- `docs/production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md`;
- `docs/production/ROADMAP.md`;
- `docs/production/STATUS.md`;
- `game/project.godot`;
- `game/scenes/runtime/oldpine_game_runtime_host.tscn`;
- `game/scenes/world/oldpine/oldpine_world_session.tscn`;
- `game/scenes/world/oldpine/oldpine_outdoor.tscn`;
- `game/scenes/world/oldpine/oldpine_cave.tscn`;
- `game/runtime/persistence/oldpine_game_runtime_host.gd`;
- `game/runtime/persistence/oldpine_session_load_coordinator.gd`;
- `game/runtime/persistence/oldpine_runtime_save_load_result.gd`;
- `game/runtime/persistence/oldpine_save_eligibility.gd`;
- `game/runtime/persistence/oldpine_save_eligibility_result.gd`;
- `game/runtime/persistence/oldpine_world_capture_result.gd`;
- `game/runtime/persistence/oldpine_world_restore_result.gd`;
- `game/runtime/persistence/game_save_repository.gd`;
- `game/runtime/persistence/game_save_storage_profile.gd`;
- `game/runtime/persistence/save_file_operations.gd`;
- `game/runtime/persistence/godot_save_file_operations.gd`;
- `game/core/persistence/game_save_result.gd`;
- `game/runtime/world/oldpine_world_session_controller.gd`;
- `game/runtime/world/oldpine_resident_map_controller.gd`;
- `game/runtime/world/oldpine_outdoor_controller.gd`;
- `game/runtime/world/oldpine_cave_passage_controller.gd`;
- `game/runtime/world/world_character_body_2d.gd`;
- `game/runtime/world/oldpine_outdoor_hud.gd`;
- `game/runtime/combat_slice/combat_slice_hud.gd`;
- `game/ui/world/player_inventory_panel.gd`;
- `game/ui/world/oldpine_loot_panel.gd`;
- `tools/build/prepare_release_project.py`.

No LPC source was needed or scanned. This phase defines application/product behavior and does not alter a
legacy gameplay rule.
