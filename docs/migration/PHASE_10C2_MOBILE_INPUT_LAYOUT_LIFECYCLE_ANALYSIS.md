# Phase 10C2 — Mobile Input / Layout / Lifecycle Analysis

## Status and authority

ANALYSIS COMPLETE; 10C2A READY TO BEGIN. No Phase 10C2 production behavior is implemented by this
document. All designs below are proposed implementation requirements, not completed runtime evidence.

Baseline: integrated `main` at `3a1f993a4258ed246ce820c7a4dc8d2563994aaf` (PR #5).
Local `main`, `origin/main`, and the starting analysis HEAD were checked equal; the working tree was
clean. Work stays on `phase/10c2-mobile-input-layout-lifecycle`, not the retained 10C1 branch.
No 10C2 PR exists. Post-merge [workflow 33643056093, attempt 2](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33643056093)
passed all four required jobs on that exact baseline.

Primary closed consumer contracts:

- [Application Shell](../production/contracts/APPLICATION_SHELL_CONTRACT.md): navigation, input,
  pause, independent settings, and Shell/Host ownership.
- [Native Save/Load](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md): eligibility, fixed slot,
  transactional writes/restores, identity and RNG continuation.
- [Repository policy](../production/REPOSITORY_POLICY.md), [BUILD](../production/BUILD.md),
  [Godot AI validation](../production/GODOT_AI_DEVELOPMENT.md), root `AGENTS.md`, and `docs/AGENTS.md`.

No LPC/reference scan, gameplay compatibility decision, or historical 10C1 re-audit is needed.
`DECISIONS.md` and the closed contracts are unchanged in this analysis commit. Implementation will
extend the Shell contract only when the corresponding mobile behavior is actually verified.

## 1. Decisions

| Question | Selected Phase 10C2 policy |
|---|---|
| Application ownership | Same ApplicationShell -> one persistent Runtime Host -> 0..1 committed Session. No mobile fork or second current-Session pointer. |
| Movement | Fixed eight-direction virtual pad; emit existing four movement actions. No analog speed, point navigation, or new movement rules. |
| Other gameplay actions | Use the existing HUD buttons and world picking path. Add a touch Pause affordance, not a parallel combat/interact command system. |
| Orientation | Sensor landscape, both landscape directions; no portrait gameplay qualification. |
| Layout | One responsive hierarchy; safe-area margins, bounded/scrollable dialogs, compact HUD, adequately sized existing buttons. |
| Android Back | One platform notification -> Shell-owned contextual semantic policy. Modal cancel first; playing pauses; bare Pause resumes; empty Main Menu exits. |
| Background | Clear input immediately; freeze Session through the existing application-pause boundary. Keep Host and Session identity. |
| Foreground | Never automatically resume interrupted gameplay; restore modal context/focus and require explicit Resume. |
| Lifecycle Save | **Manual-save-only. No automatic background Save in 10C2.** Existing pending manual Save remains the only possible in-flight write. |
| Settings | No new preference. Windowed/Fullscreen remains hidden where capability is unavailable. |
| Evidence | Android installed technical-build runtime required; Windows viewport tests supplement it. iOS shared-path/static/export/compile required, actual iOS runtime deferred if no hardware environment. |

## 2. Inspected architecture and actual surfaces

Sources inspected directly, beyond the contracts:

- `game/project.godot`, `game/export_presets.cfg`.
- `game/application/application_shell_state.gd`;
  `game/runtime/application/application_shell_controller.gd`;
  `game/runtime/application/godot_window_mode_capability.gd`;
  `game/scenes/application/application_shell.tscn`.
- `game/runtime/persistence/oldpine_game_runtime_host.gd` and
  `oldpine_session_load_coordinator.gd`;
  `game/scenes/runtime/oldpine_game_runtime_host.tscn`.
- `game/scenes/world/oldpine/{oldpine_world_session,oldpine_outdoor,oldpine_cave}.tscn`;
  relevant activation/processing code in `game/runtime/world/oldpine_world_session_controller.gd`
  and `oldpine_outdoor_controller.gd`.
- `game/runtime/world/{oldpine_outdoor_hud,world_character_body_2d,world_landmark_area_2d}.gd`;
  `game/runtime/combat_slice/combat_slice_corpse_view.gd`;
  `game/ui/world/{player_inventory_panel,oldpine_loot_panel}.gd`.
- `tools/build/{prepare_release_project,build}.py`, `.github/workflows/ci.yml`, `.gitignore`.

Shell and Host process ALWAYS. SessionSlot is PAUSABLE; resident maps/bodies/cadence inherit Session
processing. Staging/activation DISABLED state is a different mechanism and must not become a mobile
pause flag. Map HUD remains Session-owned. The Cave scene has no Outdoor HUD: movement/Pause touch
affordances must survive handoff at Shell presentation lifetime, without transplanting Outdoor
combat/inventory features into Cave or retaining a stale map reference.

### Shell inventory

All six surfaces are full-rect Controls under `ShellCanvas` (layer 100), with a full-screen input
barrier. CenterContainer/PanelContainer/MarginContainer/VBoxContainer arrange content. They do not
currently have a safe-area root or bounded scrolling. The following are authored logical pixels,
not measurements of rendered phone usability or complete calculated container minimum sizes.

| Surface | Current authored assumptions | Input/focus and necessary adaptation |
|---|---|---|
| Main Menu | Panel min width 520; margins 42 horizontal/36 vertical; title 34; status min height 54; four buttons min height 52; separation 18 | New Game/Continue/Recovery/Settings are real Buttons; visible enabled cycle starts at New Game. Bound panel to safe rectangle, wrap status, scroll long content. |
| Pause | Panel min width 460; margins 36/32; title 30; four buttons height 52; separation 16 | Resume/Save/Settings/Return; Resume initially focused. Preserve pause while scrolling/settings. |
| Settings | Panel min width 520; margins 36/32; window OptionButton 220x48; Apply/Cancel 140x48; status min height 54 | Same scene for both typed origins. Option popup/cancel must own input before the underlying dialog. Mobile hides unsupported window row/Apply; retain explanatory status and Cancel, not placeholder settings. |
| Recovery | Panel min width 580; margins 36/32; wrapped description; four buttons height 52 | BACKUP/TEMP/New Game/Cancel; first available candidate receives focus. Long failure/candidate text needs bounded scrolling; no new recovery authority. |
| Result/confirmation | Panel min width 560; margins 32/28; wrapped message min height 76; horizontal action row, no explicit button minimum height | Confirm/Cancel or acknowledgement; keep typed result/origin and focus selection. Size all buttons, wrap/stack action row when necessary. |
| Busy | Centered label at font size 24; no explicit wrapping or safe inset | No actionable/focusable gameplay/UI input. Wrap message; maintain full-viewport blocking even outside safe content. |

Shell focus is explicitly rebuilt from visible enabled controls; hidden surfaces have focus disabled.
Busy consumes input before GUI dispatch. State transitions release movement/accept/cancel/pause and
quarantine key echoes. This is navigation hardening, **not an existing application-background policy**:
the controller has no mobile notification handler. No touch control may bypass this precedence.

### Gameplay inventory

| Surface | Actual hierarchy/geometry | Mobile consequence |
|---|---|---|
| Outdoor status/actions | Outdoor `HUD` CanvasLayer -> full Overlay (mouse IGNORE) -> StatusPanel at (16,16)..(530,625), margin 12/10, VBox spacing 7 | Fixed 514x609 block dominates phones; no inset handling. Keep the current data projections, reflow presentation. |
| Vitals/target | Player and target bars min 340x20; selected target font 18; labels/title | Informational; make width flexible, retain readable values, no authoritative state in HUD. |
| Current actions | One HBox: Inspect, Attack, Traverse, Open Loot, Inventory; no explicit touch heights | Real Buttons already wired to existing controller operations. Reflow to touch-sized rows/grid, retain disabled/eligibility rules. No attack/interact InputMap action currently exists. |
| Inspection/log | RichTextLabels min 340x86 / 340x165; scrolling disabled; HUD retains up to six combat-log lines | Bound details space and allow presentation scrolling/disclosure in compact mode. No new combat history/save state. |
| Loot | Right anchored offsets -384..-24, top 24..264; min 360x240; rows ScrollContainer min 320x150; dynamic HBox label + Take | Keep current selection/projection and single-Take behavior. Wrap names, enlarge Take/Close, permit finger scrolling without activating a row. Description currently tooltip-only here: show existing description inline/disclosure, not only hover. |
| Inventory/inspect | Right offsets -464..-24, top 24..544; min 440x520; rows min 400x250; inspect min 400x140 | Dynamic HBox label + Inspect + applicable Wield/Unwield/Wear/Remove; theme-sized buttons. Reflow rows, bound both list/inspection, retain current typed item signals. |
| World selection | Character body, landmark Area and corpse picking accept left `InputEventMouseButton.pressed`, not ScreenTouch | Route touch through the normal viewport pointer/picking path. Do not directly select targets/call combat. Corpses have 96x48 picking rectangle; world geometry/range remain unchanged. |
| World traversal/rendering | CharacterBody2D movement; Camera2D per map activated by Session; physical Areas/portals; Cave terrain labels | Preserve speed/collision/camera ownership/trigger rules. Do not use finger position as world destination or replace Area entry with a callback. |

At 1152x648 the authored inventory left edge is 688, safely beyond StatusPanel's right edge 530.
At width 960 it is 496, overlapping by 34; inventory bottom 544 also exceeds height 540. Status bottom
625 leaves only 23 at the current default height. This is source-derived layout reasoning, not a new
live test claim. Tablet/wide layouts do not inherently repair the fixed vertical block.

## 3. Existing actions and touch ownership

`move_left/right/up/down` are WASD/arrows, action deadzone 0.5. `WorldCharacterBody2D` reads
`Input.get_vector()` and multiplies by movement_speed 220 before `move_and_slide()`.
`pause_game` is Escape/controller Start; `ui_cancel` is Escape/controller B; `ui_accept` is
Enter/keypad Enter/Space/controller A. Current movement actions have no joypad bindings: preserve
existing controller Shell navigation without claiming full controller locomotion qualification.
HUD actions and item verbs remain ordinary Control signals; no speculative action names for them.

| Movement option | Fit to current game | Decision |
|---|---|---|
| Eight-way fixed pad | Same digital vector, predictable corridor/cliff alignment; no new acceleration/speed/routing | Select. |
| Analog stick | Requires additional deadzone/strength tuning without an existing analog product requirement | Defer. |
| Tap-to-move | Needs pathfinding, destination/collision/selection arbitration and another movement intent | Out of scope. |
| Independent TouchScreenButtons | Native multi-touch, but Node2D layout and separate buttons do not solve shared GUI pointer ownership | Do not use as the ownership layer. |

Use one Shell-lifetime **Control-based touch adapter** with a small typed capture state; the visual
root is mouse-ignore except actual control regions. It has no Session pointer, movement method,
combat hook or navigation callback. Input availability comes from Shell mode/activity and current
visible presentation blockers. The pad/Pause affordance is shown on Android/iOS while PLAYING, in
both maps; desktop remains hidden (test capability injection can expose it). External keyboard/mouse
use on mobile does not create another Shell or automatically hide the pad.

### Pad and action output

- Fixed lower-left 192x192 logical pad, nine 64x64 cells. Center cell is neutral/deadzone; eight outer
  cells yield cardinal/diagonal digital actions. No added analog strength or speed formula.
- A press beginning inside the pad captures one finger index. Other fingers cannot steal it. Drag
  changes cells; leaving the pad yields zero but retains capture until lift/cancel; dragging back
  resumes direction. A finger starting elsewhere never becomes the movement owner mid-drag.
- Emit press/release edges as fresh `InputEventAction`s through `Input.parse_input_event`, with a
  dedicated synthetic source device ID and the existing action names. Do not continuously re-press.
  Use paired source-specific releases for ordinary touch release, not global `Input.action_release`.
- Godot 4.7.2 tracks mapped events per device/event; an InputEventAction has a separate action event
  entry. Global `action_release()` clears device state. Its default touch-to-mouse implementation
  selects just one finger, so pad ownership can starve a second finger's GUI click.
  These distinctions were checked in [pinned Input source](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input.cpp).
  A local 4.7.2 probe additionally passed both keyboard-held/touch-release and touch-held/keyboard-release
  checks (including final releases), four assertions. No custom keyboard state aggregator is needed.
- Shell transitions/lifecycle intentionally cancel **all** held gameplay input through the existing
  clear/quarantine boundary, after cancelling captures. No old contact is recaptured until a fresh
  press. Same-direction keyboard+touch stays held until both sources release; opposite directions use
  the existing `get_vector()` cancellation. Do not add controller bindings/remapping in this phase.

### GUI, multi-touch and leak prevention

Retain one pointer owner in addition to the pad owner, so holding movement and pressing Pause or an
existing HUD button with a second finger works in either finger order. Ignore additional contacts
until they lift; never promote an already-held contact after another releases. A normal Button is
not a multi-touch control ([Godot TouchScreenButton documentation](https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html)).

While this adapter is active, disable engine automatic touch-to-mouse emulation in one place; restore
the previous value on teardown. The selected non-pad finger supplies normal mouse motion/button
events to the root viewport (`push_input` with viewport-local coordinates), including button mask,
window, and cancellation. GUI-owned raw touch/drag remains available to the native ScrollContainer;
pad/ignored contacts are consumed. Never forward a second copy of an emulated mouse event. Do not
call `_gui_input`, `Button.pressed`, target-selection, movement, traversal or Shell methods directly.

The normal Control/picking route therefore still decides the clicked target and performs all existing
validation. A cancelled finger emits cancelled pointer release, never a click; drag-scroll cancels
the pending row activation. Physical mouse events retain the desktop path: a fresh physical pointer
press cancels/quarantines an outstanding synthetic GUI gesture before taking pointer ownership.
The pad can coexist with that pointer. Tests must prove no duplicate selection/Take/Save.

Precedence is Busy -> top popup/Result -> Settings/Recovery -> Pause/Menu -> open item/detail panel
-> gameplay controls -> world. Item panels block touches through their occupied/backdrop area and
clear pad movement while open, but **do not pause combat or alter save eligibility**. Pause remains
accessible. Touches elsewhere cannot accidentally select a world target beneath a panel. Closing
a panel/modal never transfers its held finger to the pad/world. Keyboard/controller focus remains
the existing semantic path, with native scroll-to-focused-control support.

Cancel all captures/actions on Shell transition, focus loss, application pause, orientation/metrics
change, active-map handoff, Session replacement/teardown, and overlay disable/tree exit. Observe
presentation/Host notifications only; do not introduce mobile traversal authority. Drop queued pointer
gestures belonging to an earlier presentation generation. `Input.action_press()` alone does not
deliver Shell `_input` events, so the visible Pause button emits a paired `pause_game` action event,
not a direct `request_pause()` call ([Input API](https://docs.godotengine.org/en/stable/classes/class_input.html)).

## 4. Android Back

Use `Node.NOTIFICATION_WM_GO_BACK_REQUEST` (1007), not a polling key or a second Escape binding.
Set `application/config/quit_on_go_back=false` during implementation; the current effective default
is true. The notification adapter emits a single semantic `system_back` InputEventAction. This is
an application intent, not a new gameplay command. Shell alone maps it by current state through its
existing cancel/pause handlers. It is distinct from `ui_cancel` (which does not pause PLAYING) and
`pause_game` (which cannot dismiss higher modals). Do not process both a platform Back key and its
notification, or let a single press both cancel a modal and resume/exit beneath it.

| Highest owner/state | One system Back result |
|---|---|
| BOOT / STARTING_SESSION / SAVING or pending blocking operation | Consume; no conflicting request, cancellation of transaction, or exit. |
| Native settings popup | Close popup only, preserving Settings. |
| RESULT / confirmation | Existing dismiss/cancel to typed origin; never confirm destructively. |
| SETTINGS | Existing Cancel, returning to MAIN_MENU or PAUSED origin; no Apply. |
| RECOVERY_CHOICE | Existing Cancel to Main Menu; no candidate selected. |
| PAUSED with no higher modal | Existing Resume, only when lifecycle activity allows interaction. |
| PLAYING with open item/detail overlay | Close top presentation overlay only. |
| Bare PLAYING | Existing pause intent; same Session frozen. |
| MAIN_MENU, Host exactly empty and idle | Exit application through Shell's narrow platform-exit boundary; no confirmation needed because no running Session exists. No Save or hidden recovery. |

Desktop Escape/controller behavior is preserved. iOS has no Android system Back and receives no
fake Back button for application exit; visible controls cover every navigation path. Background
notifications and Android Back are different inputs. The [official quit guide](https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html)
documents the default quit behavior and that suspended apps can be terminated without another exit
callback. No exit hook is a reliable Save guarantee.

## 5. Safe area, orientation and responsive layout

### Capabilities and coordinates

Add a narrow injectable `SafeAreaCapability` returning typed display/content/safe rectangles and
the transform needed to express them in the UI viewport. Its Godot adapter owns
`DisplayServer.get_display_safe_area()` and platform detection. Normalize once to logical left/top/
right/bottom insets, then feed Shell content, Outdoor HUD and the shared touch overlay. Full-screen
modal input barriers/backgrounds still cover the **entire** viewport. World rendering may bleed
behind cutouts; important HUD text and controls must not.

The [DisplayServer API](https://docs.godotengine.org/en/stable/classes/class_displayserver.html)
provides mobile safe area; its desktop fallback is monitor usable space, not mobile window padding.
Use zero insets for desktop/headless unless a test supplies metrics. On mobile intersect the physical
safe rectangle with the application's physical content rectangle, transform that intersection back
through the viewport's screen transform, intersect with logical viewport bounds, then derive margins.
Do not subtract a phone's physical pixels directly from scaled Control coordinates, double-apply
system bars already outside the content surface, or use a Camera/world transform.

Invalid/unavailable metrics produce full-content fallback plus a typed diagnostic; valid extreme
insets are not silently discarded. React to root viewport size change and foreground, with one
coalesced remeasurement after layout settles. For a 180-degree change that keeps viewport dimensions,
the single active mobile metrics adapter also observes changes in the safe rectangle; bounded sampling
only while foreground is acceptable, not per-Control polling. Emit only changed metrics and stop
sampling when hidden/backgrounded. Insets cover left/right notches and bottom home/system areas;
tests inject asymmetric and rotated rectangles. No device-model pixel table or Android cutout-list
dependency is necessary for the common iOS/Android path.

### Orientation decision

Set `display/window/handheld/orientation=4` (`SCREEN_SENSOR_LANDSCAPE`) in the shared project.
Both landscape orientations are supported; portrait gameplay and split-screen qualification are
not promised. Old Pine's lateral movement/corridors, simultaneous pad/action regions and information
density make a second portrait composition unnecessary for this technical demo.

The pinned [Android exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp)
derives manifest orientation from that project setting; the [Apple exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform_apple_embedded.cpp)
emits both landscape orientations for iPhone and iPad. The iOS preset's family value 2 means
iPhone **and** iPad, not iPad-only ([iOS exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/ios/export/export_plugin.cpp)).
Validate exported manifest/plist during implementation rather than manually maintaining conflicting
orientation lists. No Orientation service/preference or native plugin is justified.

Rotation cancels active contacts before recomposition, recomputes safe margins, and preserves Session,
map, position, camera ownership and gameplay state. It must not invoke save/load, reset RNG or spawn.
If a platform forces an unsupported portrait/narrow window, dialogs remain bounded/scrollable and
Pause remains reachable; this fallback is not portrait gameplay acceptance. iPad windowing/OS override
behavior remains a real-device qualification risk, not a reason to alter gameplay or claim support.

### Concrete sizing policy for 10C2A

- Keep one scene hierarchy and `canvas_items`/`expand`. Explicitly retain desktop base 1152x648;
  use mobile project feature overrides for a 960x540 logical base. World physics/speed/camera logic
  are unchanged; viewport visibility can change naturally. No per-phone scene or camera zoom policy.
- Minimum qualified **usable safe** landscape area is 800x480 logical units. Smaller valid areas get
  bounded scrolling/fallback, not a false full-playability claim. Test both base size and safe size.
- Touch interactive targets: minimum 64x64 logical units (text buttons may be wider), spacing at
  least 8, safe-content padding 16. Pad is 192x192. Body/action text target 20; headings 28 or more.
  These are project logical units, **not** a claim that pixels equal Android dp/iOS points. Measure
  physical readability/target size on the actual runtime before accepting a device; do not shrink
  controls below the logical minimum just to pass a fit test.
- Shell panels use a preferred maximum width, not an uncancellable min-width 580. Clamp available
  width to safe width minus padding; bound height likewise. Put long message/candidate content in a
  vertical ScrollContainer; keep primary action/Cancel accessible. Stack action rows when required.
  Result/Busy strings must wrap. Keep all native Buttons, typed signals/origins and focus order.
- Outdoor wide layout may retain a side information column when it fits. Compact mode applies when
  safe width <1100 or safe height <640: flexible top vitals/target strip, touch action grid on the
  right, pad reservation lower left, bounded optional inspection/log detail area. Disclosure is
  presentation only; preserve all current information/actions, not a HUD art redesign.
- Loot/inventory become one bounded panel at a time (as now), centered within safe content when
  compact; scroll list and inspection as needed, keep Close reachable. Reflow dynamic rows into
  label plus wrapped/stacked action row; do not require hover for description or equipment state.
  Opening a panel covers world interaction locally, not a new game pause. Preserve keyboard focus.
- Reserve space for the shared Pause affordance in both maps. No interactive overlap with the pad,
  item panels or system gesture regions. Cave gets shared movement/Pause, not a new gameplay HUD.

| Qualification case | Current risk / future layout obligation |
|---|---|
| Desktop 1152x648 and 1920x1080, 16:9 | Preserve existing Shell/focus/window settings; desktop scaling must not hide current item actions. |
| 960x540 logical phone baseline | Current status and inventory collide/clip; compact layout must fit all critical controls. |
| 2160x1080, 2:1 and Pixel 9 2424x1080 landscape | Safe inset normalization and two-finger pad+HUD/Pause; no assumption that extra width solves height. |
| 2400x1080 very wide with asymmetric left/right/bottom safe bounds | Both landscape directions, no controls under notch/home region, enough free world space. |
| 1024x768 and 2048x1536 tablet landscape, 4:3 | Shared layout; increased height, not a phone scene scaled offscreen. |
| Injected usable-safe 800x480, then smaller extreme case | Minimum qualified layout passes; below-minimum gracefully scrolls without claiming supported gameplay. |

No new mobile setting is warranted. Existing independent ConfigFile settings and unsupported desktop
window-mode behavior remain unchanged; no orientation, sensitivity, quality, audio or vibration slider.

## 6. Lifecycle and Save policy

### Evidence and policy selection

Godot exposes `NOTIFICATION_APPLICATION_PAUSED` (2015), `RESUMED` (2014), `FOCUS_OUT` (2017),
and `FOCUS_IN` (2016). Pause/resume are mobile notifications; focus is separate and can precede/follow
them. OS termination while suspended may provide no further callback. The documented limited iOS
background budget is not a guarantee that a deferred application operation will finish
([MainLoop lifecycle API](https://docs.godotengine.org/en/stable/classes/class_mainloop.html)).

Host `request_save()` serializes a request then uses `call_deferred` before execution. The coordinator
performs eligibility -> capture -> canonical repository transaction synchronously when that execution
actually occurs. A notification-time request can remain queued until foreground or process death.
Changing it to a special synchronous mobile bypass, reserving background OS time, or declaring Save
success when only queued would exceed the current closed boundary.

**Choose manual-save-only for 10C2.** Background triggers zero new Save requests, no preflight capture,
no slot/candidate mutation and no new autosave result/format. Players must explicitly Pause -> Save
before leaving if they need durability. Resuming the same process retains unsaved in-memory progress;
after OS kill, cold start remains Main Menu and Continue reads the last completed manual Save.
Do not add dirty tracking, manufacture eligibility, promote BACKUP/TEMP, or promise a termination Save.

An already-requested manual Save is not cancelled, repeated or mislabelled as lifecycle Save. If its
normal transaction completes, retain its real typed result; if suspended first, allow the existing
operation to continue on foreground. Never claim saved until completion. Existing repository failure/
rollback and explicit recovery rules are unchanged. No background Save polling/retry/timer is added.

### Minimal state extension and execution order

One Shell-owned typed activity model records foreground/background and focused/unfocused facts from
the adapter. These facts are independent (ordering varies), but they produce one derived interaction
permission; no scattered `mobile_paused` / `touch_disabled` / `resume_pending` authorities. Policy
activates on Android/iOS; desktop window/navigation behavior remains the closed 10C1 policy.

Add a narrow typed resume gate `NORMAL` / `EXPLICIT_AFTER_LIFECYCLE` to Shell coordination. It is
necessary because background can interrupt NEW_GAME/CONTINUE/RECOVER **before** a Session exists,
and foreground can return before Host completion. It is not a saved gameplay field or a duplicate
Session pointer. No separate PauseReason enum is needed: this gate also supplies the one optional
Pause information message. Keep SettingsOrigin/ResultOrigin unchanged.

On mobile focus loss or application pause, idempotently:

1. Cancel pad and pointer captures; quarantine held contacts, movement and activation actions. Reject
   further application input until foreground/focus permission returns.
2. Freeze through `SceneTree.paused` / PAUSABLE SessionSlot, never through staging DISABLED mode.
   Do this even when a Host request is pending; current `request_pause()` alone is insufficient because
   it rejects pending requests. Shell/Host remain ALWAYS so completion/transaction coordination works.
3. If PLAYING, enter existing PAUSED with explicit-resume gate. If already paused or in its modal,
   retain mode/origin. If a start/load request is pending, retain Busy and set the gate for completion.
   Do not cancel a map handoff, cadence, busy state or unfinished character lifecycle work.
4. No new persistence operation. No Session creation/destruction simply due to lifecycle.

The existing successful New/Continue/Recover handlers currently select PLAYING unconditionally.
10C2C must route their final UI/processing decision through the activity/resume gate: a Session
committed during or after an interrupted operation starts PAUSED, with no intervening gameplay tick.
Likewise END_SESSION completion cannot unfreeze an interrupted live Session prematurely. Clear the
resume gate on confirmed explicit Resume or completed transition to an empty Host, not just on focus
gain. Preserve invariant failure/rollback reporting and single-operation serialization.

On foreground, clear contacts again, refresh safe area/layout and restore focus to the highest
retained modal's valid primary control. Both activity and focus must allow interaction; duplicate or
reordered events do not resume. If Host is empty, restore the normal unpaused Menu/Recovery/Settings
contract. If a Session remains, require a fresh explicit Resume after returning through any modal.
No queued gesture may activate Resume. Temporary inactive tree pause with no Session is a planned
extension to the foreground-only Menu/BOOT invariant, not a change to Host ownership or persistence.

### UX and outcome matrix

| Interrupted context | Foreground behavior / message |
|---|---|
| PLAYING | Same Session PAUSED. A quiet Pause info line: paused while away; save manually before leaving. No automatic Result dialog. |
| Already PAUSED | Remain PAUSED; no repeated notification dialog. |
| Menu, empty Host | Same Menu; no save attempt or warning modal. |
| Settings / Recovery / Result | Preserve typed origin, settings draft/candidate context and result. Regain focus without applying/confirming. Pause-origin gameplay stays frozen. |
| Start/Continue/Recover pending | Busy until real completion; successful interrupted start presents PAUSED even if foreground returned first. Failure remains existing menu-origin Result. |
| End Session pending | Finish normal teardown; empty Host returns through inspection to Menu. Never recreate Session on foreground. |
| Manual Save completed successfully while interrupted | Existing Save-success result, pause origin; do not say automatic background Save succeeded. |
| Manual Save blocked by eligibility | Existing typed blocker result, still paused, no gameplay mutation. Background alone does not run eligibility or generate this message. |
| Manual Save storage failure | Existing product-safe failure Result; no paths/debug exceptions in UI, no hidden retry. |
| Manual Save pending / completion unavailable | Existing SAVING/Busy until completion, or cold Menu after OS kill. No optimistic saved indicator. |

Lifecycle-generated outcomes are only NONE / PAUSED_FOR_LIFECYCLE / HOST_COMPLETION_GATED; they can be
typed transition results, not a second persistence result model. Save success/block/failure continues
to use ApplicationOperationResult and the existing product mapper. A single quiet info line is enough.

## 7. Smallest implementation boundaries

| Boundary | Owner and permitted implementation |
|---|---|
| SafeAreaCapability + typed metrics | Injectable presentation port; one Godot DisplayServer/viewport adapter, zero-inset fallback and pure normalization tests. |
| Touch capability | A typed fact at application composition (`mobile touch UI enabled`), injectable for tests. No separate service hierarchy solely to wrap a boolean. |
| Touch capture/action adapter | One Shell-owned runtime Node plus typed capture state; normal viewport input only. It can use Godot Input APIs directly at this boundary. |
| Lifecycle adapter | One ALWAYS runtime Node translates mobile notifications into typed activity events; Shell owns navigation/pause decisions. No timer/Host/Save authority in adapter. |
| Orientation | Shared project/export configuration, plus existing metrics invalidation. No OrientationCapability class required. |
| Existing WindowModeCapability | Remains separate; its desktop window-management calls do not become a generic mobile service locator. |

No MobileApplicationShell, MobileRuntimeHost, MobileSession, global mobile Autoload, generic callback
registry, snapshot of all runtime state, native Android/iOS plugin or second save/settings repository.
New typed policy/fake files should follow `game/application/`, `game/runtime/application/`, shared
presentation/UI and `game/tests/` boundaries, not enter Game Core. Names above describe boundaries,
not a requirement for one class per noun.

Obvious processing hazards are bounded: Outdoor `_process` may process aggression/refresh selected
corpse, bodies run physics and cadence uses timers while PLAYING. They must stop under SessionSlot
pause and resume without catch-up work derived from wall-clock absence. Keep Shell/Host operational;
hidden touch UI must not poll movement or synthesize repeated actions. Safe-metrics observation stops
while backgrounded. No global FPS, renderer, battery profiler or combat optimization work is included.

## 8. Tooling, exports and real evidence

### Workstation observation, 2026-09-02

- Windows; pinned local editor `build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe` verified
  as official 4.7.2. Local JDK under `build/toolchain/jdk17/jdk-17.0.18+8` reports Temurin 17.0.18+8.
- SDK at `C:/Users/Toxic/AppData/Local/Android/Sdk`: platform-tools 37.0.1; API 35; build-tools 35.0.1;
  command-line tools 20.0; CMake 3.10.2.4988404; NDK 28.1.13356709 metadata present and matching pins.
  These paths are workstation observations, not production configuration to commit into game files.
- `adb devices -l` returned **no devices**. Neither physical-device nor running-emulator proof exists.
- Emulator 36.6.11 installed; `emulator -list-avds` returns `Pixel_9_API_35`. Its installed API35
  Google Play x86_64 image/config is present: 1080x2424, density 420, sensor orientation, portrait initial.
  It was not booted in analysis; acceleration/graphics and application launch remain runtime checks.
- No macOS/Xcode/iOS runtime available on this Windows workstation. The existing macOS CI compile
  path is not an interactive simulator or device session.

Initial sandbox SDK access was denied; scoped read-only escalation established the above facts.
Absence from PATH or sandbox access failure must not be reported as an absent SDK/device capability.

### Android evidence plan

Use the same sanitized project and canonical Shell main scene. Existing
`tools/build/build.py --target android` produces ARM64-only
`dist/android/Eastern-Stories-Godot-android-arm64.apk`; install with the discovered adb when a matching
device is available. **Do not assume that ARM64 APK runs on the installed x86_64 AVD.** Preferred
currently feasible plan: boot that AVD and export a clearly labelled x86_64 technical-validation APK
from the same sanitized tree, with a narrowly scoped temporary export-preset ABI override. Keep the
normal ARM64 release/CI gate unchanged; record ABI/build hash and mark evidence as emulator, not ARM64
hardware. If graphics/ABI prevents launch, diagnose it; report BLOCKED rather than desktop-as-Android.

Use one installed APK for fresh-process, Save and lifecycle repetitions. The build tool currently
creates a new ephemeral QA signing key per build: do not automatically uninstall an existing app to
solve signature mismatch, since that can destroy saves. Use an isolated test AVD/profile, preserve
needed artifacts, and obtain permission before deleting app data. Stable QA signing across rebuilt
test APKs is a separate narrow tooling need if iteration requires it, not store signing.

Final Android route: fresh launch -> touch Menu/Settings/Cancel -> New Game -> actual movement through
CharacterBody/Area paths -> select via viewport and current HUD actions -> Pause -> Settings -> Save
when eligible -> Resume -> Return confirmation -> Continue; include explicit recovery candidates
using isolated pre-route QA fixtures. Traverse Outdoor/Cave and back through normal input to prove
pad/Pause lifetime; do not substitute direct traversal calls. Cover Back in every context, 180-degree
rotation/notches, multitouch pad+Pause/HUD in either finger order, drag-scroll and cancel.

Use actual emulator touch UI or Android input injection; single `adb input swipe` is not multi-touch
proof. A simultaneous-contact input facility through Android/viewport is required for that row;
desktop injected ScreenTouch is supplementary, not proof of Android event delivery. If physical
hardware remains unavailable, report emulator-only qualification explicitly.

Use Android Home/Recents/foreground actions, not controller lifecycle calls, for the final lifecycle
path. Capture before/after Session/Host counts, positions/resources, map/camera, timers/cadence and RNG
state through test-only observation; assert frozen while away and until explicit Resume. Kill/relaunch
an isolated test process after completed manual Save to prove last-save continuation. Use no callbacks
or teleports as final player-route evidence. Recheck logs for runtime errors and use fresh advancing
frames; helper-based desktop evidence must meet the existing helper-live/session-active/capture-ready/
non-stale rules. A sanitized APK has no Godot AI helper: use Android captures/logs and test evidence,
not a fictional helper connection.

### iOS and sanitizer

iOS required in 10C2: shared mobile code/static capability tests, sensor-landscape iPhone/iPad plist,
safe-area fixtures for notch/home indicator, sanitizer retention, unsigned export/Xcode compile green
on the final PR/main. Actual iPhone/iPad multitouch, system gestures, rotation/windowing and lifecycle
runtime qualification requires a Mac/simulator/device and is deferred to 10D or an explicit later
hardware gate if still unavailable. Android runtime is not iOS runtime proof.

`prepare_release_project.py` already copies production application/runtime/scenes and strips tests,
Godot AI, QA autoload and remote-debug settings. No source-tree fork or broad sanitizer rewrite is
needed. During implementation add explicit required mobile paths/config assertions and tests so
production touch/safe-area/lifecycle/orientation cannot disappear, while fakes/instrumentation remain
under stripped test paths. Verify both Android and iOS consume this same stage. Preserve canonical
Save/Settings and existing editor-only 6107 configuration sanitation. BUILD is not stale and is
unchanged by this analysis; document actual new validation commands when implemented.

## 9. Deterministic tests and acceptance gates

The table defines future acceptance, **not tests already run**. Use existing test conventions and
isolated settings/save profiles. Expectation values come from the decisions and closed contracts,
not generated from the implementation under test.

| Area | Deterministic checks | Required runtime evidence / slice |
|---|---|---|
| Display/safe area | Zero, left/right notch, bottom inset, invalid fallback, extreme valid inset, scaled/offset content transform, changed and unchanged dimensions | Actual Shell/HUD bounds at matrix sizes; notch/180-degree rotation on Android; A then C. |
| Shell layout | Every visible action inside safe bounds; no overlapping primary targets; min touch size; long text/candidates, bounded scrolling, native popup within safe area | Touch or real viewport UI for Menu/Pause/Settings/Recovery/Result, with keyboard/controller semantic regressions; A/B. |
| HUD | Compact/wide reflow, inventory/loot row actions and descriptions, scroll cancellation, Cave absence handled, Pause accessible | Actual world selection, item actions and normal map roundtrip; A/B/C. |
| Input | Press/release/cancel, center/edge/diagonal/outside pad; owner release, index reuse, both finger orders; ignored third finger; physical mouse takeover; held keyboard+touch independence | Real/injected viewport touch plus Android multitouch; no direct player method; B/C. |
| Input barriers | Busy/modal ordering; touch started before modal never activates behind it; one Save/Take per tap; transition/lifecycle/handoff/rotation clears owners and stale generations | Press then modal/Back/background while held, return without movement/click leak; B/C. |
| Back | All Shell modes and pending operations; popup first; confirmation never confirms; empty menu exits only; one notification -> one intent | Actual Android Back, including gesture/navigation-button delivery as available; B/C. |
| Lifecycle | Both pause/focus event orders and duplicates; playing/menu/paused/settings/recovery/result; pending New/Continue/Recover/Save/End; foreground before completion | Android Home/Recents/return; no hidden gameplay tick or second Host/Session; C. |
| Resume gate | Interrupted operation finishes PAUSED even after foreground; explicit Resume only; empty teardown clears gate; Settings/result origin unchanged | Repeated interruptions during real UI operations, same identity and frozen state; C. |
| Lifecycle Save policy | Eligible, blocked, no Session, pending Host and storage-failure setup all cause **zero automatic writes**; no gameplay mutation to gain eligibility | Background alone leaves canonical/bak/tmp unchanged. Separate explicit manual Save tests below; C. |
| Manual Save interrupted | Eligible success; eligibility blocker/no mutation; write failure/rollback; existing pending request exactly once; no premature success | Player Save -> background/foreground; real completion or honest pending result; completed Save then fresh-process Continue; C. |
| Release | Mobile production retained, fakes/QA/debug stripped, same canonical main, sensor-landscape config, no Android gameplay fork | Sanitized desktop smoke plus installed Android technical APK; iOS compile tier, C/final. |

Do not invent a passing "lifecycle Save success" test for the selected no-autosave policy. Prove no
automatic request, then exercise the existing manual-save success/block/failure path under interruption.
Fault injection and prepared recovery fixtures are valid in integration tests and pre-route QA setup;
disclose them, retain normal actual input for the claimed player path.

## 10. Slices, risks and scope control

| Slice | Implementation boundary and closure requirements |
|---|---|
| 10C2A — Mobile Presentation Foundation | Typed metrics/capability composition, safe-area provider, responsive shared Shell/HUD/item panels, touch target sizing, orientation/base-size configuration. Reserve pad/Pause regions but no pretend working touch controls. Focused layout/capability/sanitizer + 10C1 UI regressions and real resized UI evidence; formal audit. |
| 10C2B — Touch + Android Back | One capture/pointer adapter, digital pad and semantic Pause, context-aware Back in Shell, native GUI/world input, contact cancellation and desktop coexistence. Focused ownership/Back/UI tests plus actual viewport touch and installed Android Back/input proof; formal audit. |
| 10C2C — Lifecycle + Mobile Release Validation | Typed activity/resume gate, no-autosave behavior and in-flight Host completion gating, lifecycle UX, complete installed Android route and packaged/sanitized validation. Focused lifecycle/Save/Session regressions; formal audit. |

Start Android technical-package/ABI setup in B, not on the final day of C. A may use actual desktop
viewport/synthetic safe bounds for its local evidence, but must not label that Android qualification.
All slices and audit corrections stay on this phase branch. Focused tests during implementation;
complete historical suite and integration evidence at the final major audit, then one ready PR,
four same-HEAD green jobs, explicit merge authorization, and green four-job post-merge main CI.
Analysis push is backup only and does not open a PR or run the expensive workflow.

Principal risks and containment:

- Engine GUI emulation and scroll/picking order: verify the first-finger/second-finger and cancelled
  gesture cases early in B; do not fix them by bypassing Control/physics input or widening core APIs.
- Safe-area coordinate spaces/OS rotation without resize: test transformed rectangles and real Android
  frames. Do not patch with per-model offsets or claim real iOS notch evidence from fixtures.
- Mobile timing interrupts queued Host work: C must cover completion both before and after foreground,
  zero extra gameplay frames, and pause without erasing restart-unsafe work. Never force Save eligible.
- Unsaved progress can be lost on OS kill under manual-only policy: explain it quietly in Pause;
  reliable autosave/background-task infrastructure remains a separate product decision.
- Current x86_64 emulator versus ARM64 release, graphics support and no attached hardware: qualify
  technical ABI explicitly and keep missing runtime rows pending. No fabricated mobile PASS.
- Touch layout minimums are a starting product policy, not full accessibility/physical-device proof.
  Adjust only presentation sizing when actual readability fails, not gameplay/camera rules.
- Baseline CI observation only: attempt 1 of 10C1 post-merge CI had the historical Vine-region
  expected-WaterfallBasin/actual-south_slope assertion failure; attempt 2 passed unchanged, including
  the 10,541-assertion suite. Do not alter that test now. If it recurs, investigate separately and
  narrowly; do not weaken its assertion or mix stabilization with mobile semantics.

Explicit deferrals: analog/tap-to-move, controller locomotion/remapping expansion, portrait gameplay,
split-screen qualification, lifecycle autosave, native background tasks, dirty tracking, new settings,
audio/graphics/vibration preferences, cloud/multislot/in-game Load, store signing/permanent IDs/uploads,
Steam packaging, full accessibility/localization, HUD art overhaul, combat parity, content/world
expansion, mobile gameplay forks, and Phase 10D implementation. iOS runtime qualification remains
hardware-gated as described above. No gameplay formulas or legacy sources change.

## 11. Analysis verification and handoff

Completed only repository/config/source inspection, public Godot 4.7.2 API/source verification,
SDK/AVD/adb inventory, and an ignored scratch headless API probe. The probe confirmed effective
defaults (1152x648, landscape=0, quit-on-back=true, mouse-from-touch=true), notification/method
availability, sensor-landscape=4 and four source-isolation assertions. First sandbox execution had
log/certificate permission diagnostics; scoped rerun with a workspace log exited 0 without those
errors. This is not a whole-project headless/editor or mobile gameplay PASS.

Documentation consistency, nine local Markdown links, trailing whitespace, and `git diff --check`
passed before commit. Remote main still matched the exact baseline and the 10C1 branch was retained.
Only this document and minimal STATUS/ROADMAP factual updates belong in this commit. Production,
`reference/es2`, `DECISIONS.md`, BUILD and closed contracts remain unchanged. No full historical
suite, Android/iOS rebuild, live gameplay acceptance, PR or 10C2A implementation was performed.

Handoff: **PHASE 10C2 ANALYSIS COMPLETE — PHASE 10C2A READY TO BEGIN**. This is a design/analysis
completion, not Phase 10C2 implementation closure or integration on main.
