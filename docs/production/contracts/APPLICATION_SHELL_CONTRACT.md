# Application Shell Contract

## Ownership and entry point

The canonical production main scene is `res://scenes/application/application_shell.tscn`.
One ApplicationShell owns one persistent OldPineGameRuntimeHost. Only the Host owns the current
Session pointer: zero or one committed Session under SessionSlot, with StagingSlot empty outside
the existing restore transaction. The Shell configures MANUAL startup before attaching the Host.

The Shell owns typed navigation state, product messages, focus/input, pause policy, and settings
coordination. It may query the Host; it must not retain a second current-Session authority or a
GameSaveSnapshot. Gameplay, map HUD, bodies, cameras, timers, and resident maps belong to the
replaceable Session. Shell UI and settings survive Session replacement and menu return.

## Navigation and lifecycle

ApplicationShellState validates mode/operation/origin combinations. SettingsOrigin and ResultOrigin
are closed MAIN_MENU/PAUSED choices, absent outside their corresponding mode.

| Mode | Consumer invariant |
|---|---|
| BOOT / MAIN_MENU | No committed Session; tree unpaused; inspection is metadata only. |
| STARTING_SESSION | Blocking Host operation; no input. New/Continue/Recover publish only a validated Session; END_SESSION retains pause until teardown completes. |
| PLAYING | Exactly one committed Session; tree unpaused. |
| PAUSED / SAVING | Same committed Session, frozen; Shell/Host remain operational. |
| SETTINGS | MAIN_MENU origin has no Session; PAUSED origin retains the same frozen Session. |
| RECOVERY_CHOICE | No Session; explicit candidate selection, never automatic recovery. |
| RESULT | Typed message/confirmation; menu origin remains empty, pause origin remains frozen. |

Cold start inspects storage but never starts or loads gameplay automatically. New Game is menu-only;
existing save/recovery material requires confirmation, and starting it writes/deletes no save file.
Continue availability is advisory: activation re-reads the canonical slot through the Host. Failure
leaves the Host empty, with no New Game fallback. Host operations are serialized.

Return to Main Menu always confirms possible loss of progress; there is no dirty-state detector.
The paused Host detaches the exact Session, clears its pointer, and queues the graph for freeing.
Only after typed completion and an empty Host invariant may the Shell unpause, re-inspect, and show
Menu. There is no alternate Old Pine Reset/reload path or in-game Load UI.

## Pause, Save, and recovery

Application pause uses SceneTree.paused. Shell and Host process ALWAYS; SessionSlot is explicitly
PAUSABLE and committed Session/maps inherit that boundary. Application pause must not reuse restore
staging/swap DISABLED mode or stop/clear gameplay work to manufacture Save eligibility.

Pause-menu Save uses the unchanged [native Save/Load contract](NATIVE_SAVE_LOAD_CONTRACT.md).
Success, blockers, and storage failures remain paused until explicit Resume. Typed product mapping
never parses diagnostic strings and never clears relationships, cadence, busy state, or lifecycle work.

Recovery accepts only explicit BACKUP or TEMP selection. The repository re-reads the chosen fixed
candidate and the coordinator uses the same restore transaction as canonical Continue. No automatic
fallback, copying, renaming, deletion, or promotion occurs; only a later explicit Save can make the
recovered gameplay state canonical. Controls never receive file-operation authority or gameplay snapshots.

## Independent application settings

ApplicationSettingsSnapshot v1 owns only Windowed/Fullscreen. ApplicationSettingsRepository validates
ConfigFile data at `user://settings/application-v1.cfg`: the application section, integer schema_version,
and recognized window_mode. This is not GameSaveSnapshot, not a save-data profile, and not gameplay
recovery. Settings and gameplay have independent schema, paths, failures, and authority.

Settings load/default and apply before Host startup and menu inspection. Missing/unusable settings
use the safe Windowed request on editable desktop and report a typed result without blocking Continue.
Uneditable environments leave window management to the platform. DisplayServer calls belong only to
GodotWindowModeCapability; native desktop can edit, headless/embedded/platform-managed environments
cannot. Unsupported controls are hidden, not placebo preferences or gameplay forks.

Main Menu and Pause share Settings. Selection is uncommitted; Cancel neither applies nor writes.
Apply failure does not write. Successful runtime apply plus failed persistence keeps the effective
window mode and Settings open with an unsaved warning. Pause-origin Apply/Cancel never resumes gameplay.

## Input and presentation boundary

One shared shell consumes semantic ui_accept, ui_cancel, pause_game, and directional focus input.
Bindings are portable all-device mappings; keyboard/mouse and controller A/B/Start use the same flow.
Blocking operations precede Result, Settings/Recovery, bare Pause, Menu, and gameplay. Generic cancel
does not pause PLAYING, and pause input cannot dismiss a higher modal.

Visible enabled controls form a closed focus cycle with a deterministic primary; hidden/disabled
controls are excluded. Full-screen modal controls block mouse propagation. Every validated transition
clears held movement/accept/cancel/pause actions; held-action echoes are quarantined until release or
fresh press. Busy modes consume input before GUI dispatch. Normal fresh gameplay input remains intact.

## Release and extension boundary

Sanitized builds retain this canonical Shell, settings, capability adapter, Host, and native Save/Load
runtime. They remove tests/fakes, QA bridges/fixtures/startup flags, Godot AI, remote-debug arguments,
and developer-local paths. Development debugging remains separate from shipping configuration.

Future mobile adapters must feed semantic intents/capabilities without replacing Shell or Host
authority. Android Back, touch controls, safe areas, orientation, mobile lifecycle/autosave, physical
device qualification, and store packaging/signing remain separate work. In-game Load, multiple slots,
dirty tracking, cloud saves, localization, remapping, and audio/quality settings are not provided.
