# Phase 10C2B — Touch Input + Android Back

Status: implementation evidence for **READY FOR FORMAL AUDIT**, not formal closure.
Subsequent audit corrections/closure are recorded in
[PHASE_10C2B_FORMAL_AUDIT.md](PHASE_10C2B_FORMAL_AUDIT.md); the original implementation counts
and runtime evidence below remain historical.
Branch: `phase/10c2-mobile-input-layout-lifecycle`; baseline: Phase10C2A
`968abbea4edda5ab2a7856e8afee98ebe0c0a1f6`. No PR, integration, or 10C2C work.

## Ownership and scope

The Phase10C2 Analysis remains the design authority. ApplicationShell still owns one persistent
Runtime Host, which alone owns 0..1 committed Session. No character, combat, inventory, save,
traversal, speed, physics, RNG, or authored-content authority changed. No LPC files were inspected
or changed for this presentation/input slice. `DECISIONS.md` is unchanged.

Production additions:

- `game/application/input/mobile_touch_capability.gd`: narrow injectable capability, enabled only
  by Android/iOS runtime features; ordinary desktop remains disabled.
- `game/application/input/touch_capture_state.gd`: typed per-contact PAD/POINTER/IGNORED ownership.
- `game/runtime/application/mobile_touch_adapter.gd`: one Shell-lived Control under TouchCanvas,
  not a HUD/Session child; no cached Session or gameplay method calls.
- `game/runtime/application/android_back_adapter.gd`: native Back notification to semantic event.
- `game/runtime/application/application_exit_capability.gd`: narrow testable quit boundary.

Integration changes are limited to the Shell controller/scene, project input/Back settings, and
`oldpine_hud_layout.gd` / `responsive_panel_layout.gd` presentation blockers. Build and sanitizer
changes are in `tools/build/build.py` and `prepare_release_project.py`.

## Pad, pointer, and clearing rules

The reserved safe-area pad is exactly 192x192 logical units: nine 64x64 cells, neutral center,
eight digital directions. It emits only `move_left/right/up/down`; existing CharacterBody
`Input.get_vector()` continues to normalize diagonals and control movement. No analog strength,
repeat-per-frame, pathfinding, or alternative locomotion exists.

Movement edges use fresh `InputEventAction` objects through `Input.parse_input_event()` with
device 10202. Godot 4.7.2 source-separated actions preserve held keyboard state when touch releases
and held touch state when keyboard releases; opposite directions use the existing vector result.
The adapter does not use `Input.action_press/release` as its ownership mechanism.

One contact beginning inside the pad owns movement; another non-pad contact owns the pointer,
in either acquisition order. Leaving the pad yields zero without losing ownership; re-entry
resumes. Extra contacts remain ignored until actual release. Cancellation quarantines held
indices rather than promoting them; a fresh press after release may reuse an index.

The adapter saves/disables automatic touch-to-mouse emulation once and restores it on teardown.
Audit correction: reentry now reattaches subscriptions and reacquires emulation independently of
one-time `_ready()` control construction; rapid repeated reentries are idempotent.
Pointer motion/buttons use the normal root `Viewport.push_input(event, true)` path, local
coordinates, button masks, and paired release. Raw touch is consumed, not delivered a second time
to Controls. This is an implementation refinement of the Analysis's native-GUI intent: inspected
Godot 4.7.2 BaseButton also handles raw ScreenTouch; raw plus synthesized mouse double-activates.
Native ScrollContainer uses the mouse gesture on a touchscreen-capable display. The adapter
temporarily permits event bubbling from the hovered descendant to that native ScrollContainer;
native deadzone, scrolling, inertia, and scroll notifications cancel row activation. Original
mouse filters are restored after the gesture. No custom scrolling algorithm was added.

Cancellation moves the pointer outside before sending a cancelled release because BaseButton's
mouse handling does not itself make the cancelled flag sufficient to suppress every click. A
fresh physical mouse press first cancels/quarantines only the synthetic pointer; pad movement
remains independent. Mouse-to-touch emulation events are not accepted as fresh mobile contacts.
Audit correction: world Areas act on mouse-down, so a world-origin touch delays that press until
uncancelled lift and then delivers the ordinary Viewport click. Cancelled world gestures therefore
never select first; GUI down/drag/up remains unchanged. Physical mouse takeover uses the synchronous
reentrancy guard, not an assumption that hardware cannot share numeric source label 10202.

The shared 64x64 Pause button emits paired `pause_game` action events, not a Shell callback.
Inventory/Loot and compact Details expose narrow presentation blockers/dismiss signals. They
block touch movement and outside-world selection without pausing gameplay or changing save
eligibility. Pause stays available above them; their mobile geometry reserves its top-right area.
Wide mobile Details also leaves the pad reservation clear. Desktop geometry is unchanged.

Effective priority: busy > native popup > Result > Settings/Recovery > Pause/Menu > item/detail
panel > HUD > world. Shell input-context transitions, safe-metric changes, panel ownership changes,
and resident-map detach/attach cancel both contacts. Held contacts cannot press a newly exposed
surface. Map observation keeps no HUD reference; visibility listeners are disconnected/reconnected
safely when a resident map returns (a duplicate-connection error found during implementation was
fixed). Outdoor/Cave retain exactly one Shell adapter, and Cave has no Outdoor HUD.

## Android Back

`NOTIFICATION_WM_GO_BACK_REQUEST` emits a fresh pressed/released `system_back` action pair with
device 10203. `application/config/quit_on_go_back=false`; the action has no key bindings and is
not an alias for Escape, `ui_cancel`, or `pause_game`. Shell owns the following single outcome:

| Current owner | One Back request |
| --- | --- |
| Boot / Starting / Saving / Host request pending | Consume, no destructive operation |
| Native Window Mode popup | Close popup only, do not apply/cancel Settings |
| Result / confirmation | Dismiss/cancel to its existing typed origin |
| Settings | Cancel to Main Menu or Pause origin |
| Recovery | Cancel to Main Menu |
| Pause | Normal Resume |
| Playing with item/detail blocker | Dismiss that panel only |
| Bare Playing | Normal Pause |
| Normal Main Menu with exactly empty Host | Request application quit once |

Native popup visibility is queried directly; no duplicate popup-state flag. A later fresh Back
may act on the newly exposed surface. Generic desktop cancel does not gain quit behavior.

## Focused verification

Godot executable: official **4.7.2**, isolated build-tool environment. Commands use `--headless
--path game --script` followed by the runner below. The consumers selection additionally uses
`-- --consumers`. The canonical complete historical suite was registered for the later audit
but **not run** during implementation.

| Validation | Result |
| --- | --- |
| `tests/run_phase_10c2b_tests.gd` | 95 assertions, 0 failures |
| `tests/run_phase_10c2a_tests.gd` (layout) | 3,597 assertions, 0 failures |
| Same 10C2A runner, consumers | 1,260 assertions, 0 failures |
| `tests/run_phase_10c1c_tests.gd` | 1,267 assertions, 0 failures |
| Focused invocation total | **6,219 assertions PASS** |
| `python -m unittest discover -s tools/tests` | **45 tests PASS** |
| Fresh sanitized canonical-main smoke | **16 checks PASS** |
| Development and fresh sanitized headless editor import | PASS |
| Sanitizer preparation and validate-only | PASS |
| `python tools/ci/repository_checks.py` | PASS |
| `git diff --check` / changed-file trailing whitespace | PASS / 0 findings |
| Changes to `reference/es2` / `DECISIONS.md` | 0 / 0 |

Logs: ignored `build/phase10c2b-{focused,layout,consumers,shell}.log`,
`phase10c2b-{development-editor,sanitized-editor,sanitized-smoke}.log`.
The pre-B 10C2A assertion forbidding any `system_back` action was updated to require its new
semantic-only empty binding; its assertion count did not change. No prior gameplay test was weakened.

Tests exercise all pad cells, edges, source independence, cancellation/index reuse, third contacts,
physical mouse takeover, both contact orders, native scroll/no row activation, Shell busy and Back
origins, real OptionButton popup, Save exactly once, native corpse selection/Open Loot/Take exactly
once/Inventory/Inspect/Close, metric changes, and held-contact transitions. Deterministic tests use
typed fixtures for brief busy states, long display-only rows, corpse setup, and the map-handoff
boundary; those setup calls are not claimed as player traversal/combat proof.

## Actual desktop viewport evidence

Canonical ApplicationShell ran through Godot AI with injected mobile capability/safe metrics and
real `InputEventScreenTouch/ScreenDrag` events. Desktop touchscreen capability was enabled for
native ScrollContainer testing; no production project override was saved. No desired button,
combat, selection, or traversal callback substituted for route input.

- Menu Settings/Cancel, New Game (existing development-save warning confirmed without overwriting
  that slot), two-finger movement/Pause in both acquisition orders, Resume, paused Settings/Back.
- Actual diagonal CharacterBody displacement `(129.6356, -129.6361)` over 40 physics frames;
  release/transition produced no held direction.
- Corpse/proximity fixture prepared before the claimed route and original combat RNG restored:
  touch world corpse -> Open Loot -> Take changes two rows to one -> Close -> Inventory two rows
  -> Inspect. The preparation is not a claim of touch-driven combat.
- A separate pre-route fixture set raw dodge 12, one scripted world roll 5, and proximity to Vine.
  Actual Vine Area selection -> Hold Vine button -> Passage Cave, then original world RNG restored.
  Actual Cave touch Pause -> semantic Back Resume -> down pad/physical SouthExit -> Outdoor
  Waterfall Basin. Session identity `311972334086` and touch-adapter identity `162923546252`
  persisted; one touch child, no Cave Outdoor HUD, movement released at handoff.
- Run 13 evidence: `helper_live=true`, `session_active=true`, `game_capture_ready=true`;
  successful final run error inspection `current_run_errors=[]`. Non-stale framebuffer frames
  advanced from 36839 (Cave) to 51727 (Outdoor). One tool request timed out despite the route
  executing; subsequent tree/identity/frame evidence, not that timeout, establishes the result.
  Earlier QA-only inspection typo in a discarded run was not a production failure. Game stopped
  normally after acceptance.

This is desktop engine input-delivery evidence, **not Android OS multitouch evidence**.

## Android technical build and runtime qualification

The checked-in build entry point accepts only `--target android --android-technical-abi x86_64`.
It changes boolean ABI options only in the disposable sanitized staging preset, emits explicitly
labelled `android-technical-x86_64` artifacts/manifest metadata, and retains the same production
source, package ID, and existing ephemeral QA signing procedure. No normal ARM64 source preset,
CI target, store signing, package identifier, or production rendering method changed.

Example (supply locally discovered SDK/JDK/editor/template paths):

```text
python tools/build/build.py --target android --android-technical-abi x86_64
  --godot <4.7.2> --templates <4.7.2.stable>
  --android-sdk <SDK> --java-sdk <JDK17>
  --staging build/phase10c2b-android/project --dist build/phase10c2b-artifacts
```

Verified Pixel_9_API_35 boots, only intended `emulator-5554` is selected, ABI x86_64, APK installs,
and exported `com.godot.game.GodotAppLauncher` starts package `com.example.easternstoriesgodot`.
The other pre-existing emulator app was left untouched. Only this task's newly installed test
package was replaced when an independently signed technical artifact required reinstallation.

**Default Mobile/Vulkan runtime is not qualified on this AVD.** Host Vulkan and software Vulkan
produced `Couldn't present to Vulkan queue (VkResult error 5)` and a black game surface. Software
OpenGL then hit a SwiftShader fragment-uniform limit. The strongest working environment was AVD
`-gpu host` plus an ignored, disposable technical export with
`command_line/extra_args="--rendering-method gl_compatibility"`. This uses the same current sanitized
production scripts; the rendering override is not a checked-in shipping/CI setting or a new game
tree. Its artifact is under `build/phase10c2b-gl-artifacts/android-technical-x86_64/` with explicit
workstation-override manifest metadata. It proves the following **Android OS input paths under
this technical compatibility configuration**, not Vulkan, ARM64, physical device, or store readiness:

- Fresh process -> touch Main Menu Settings -> Cancel -> New Game.
- Single-contact pad right and diagonal movement visibly move the Player/world view.
- Touch Pause -> touch Resume; OS Back from gameplay pauses, from Pause resumes.
- Settings from Pause -> OS Back returns to Pause only; another fresh Back resumes.
- World touch selects the actual big-pine Area; existing HUD Inventory opens. Pad hides while
  Pause remains available. Drag beginning on Inspect scrolls the native item list to reveal
  Unwield without inspection/activation; a fresh tap then displays the equipped sword details.
  Actual Close restores the pad without changing the selected world target.
- Return confirmation -> OS Back cancels and stays Paused; fresh Return/Confirm -> Main Menu.
  Main Menu Settings -> OS Back returns to Menu, not exit. A subsequent fresh Back from that empty
  Menu exits (PID 3407 disappears; `pidof` returns 1).
- No Godot script errors or AndroidRuntime fatal errors in the inspected process log. Platform
  SurfaceSyncGroup startup timeouts and one eglCodecCommon VAO cleanup error were present and are
  retained as graphics-environment limitations, not silently reported as a completely clean log.
- A fresh process additionally used emulator acceleration `-9.81:0:0`; Android reported rotation
  3. Main Menu/New Game, pad movement, and touch Pause worked at their reverse-landscape safe-area
  positions. The original acceleration was restored afterward. This proves both landscape
  presentations and fresh input, not Android held-multitouch cancellation during rotation.

Captured Android screenshots are ignored local `build/phase10c2b-android-*.png`, including
`world-selection`, `inventory`, `inventory-scroll`, `item-inspect`, `close-inventory`,
`back-settings`, `back-confirm`, `return-menu`, and `before-exit`.

ADB tap/swipe/keyevent supplied actual Android OS events; a single swipe is **not** multitouch.
The available `input` command exposes single-contact motion, not simultaneous pointer indices;
`adbd` cannot run as root on this production AVD image. Android simultaneous movement+Pause/HUD
in both orders remains **PENDING for 10C2C/device qualification**, with deterministic and actual
desktop two-contact proof already passing. Android Cave route and broad physical-device coverage
are also pending; desktop Cave traversal is independently proven above.

## Sanitization and deferrals

Sanitizer explicitly requires the five new production input/Back files, retains canonical Shell,
pad/Pause and safe-area infrastructure, and retains `quit_on_go_back=false` / unbound `system_back`.
It removes tests/fakes, QA, Godot AI, remote-debug settings and SDK/editor-local paths. Development
remote-debug port 6107 remains local development configuration. Fresh sanitized main smoke verifies
desktop overlay hidden, empty Host at Menu, and normal semantic New Game with the existing HUD.

No lifecycle notification, focus-loss policy, background freeze/resume gate, Home/Recents
acceptance, autosave, lifecycle Host-completion gating, mobile inventory/combat model, or new
gameplay action was introduced. These remain explicitly outside B. No long-lived final 10C2
contract was created. Formal Audit must run the full historical suite; implementation evidence
does not claim remote CI or main integration.

The branch has no open PR at implementation completion (GitHub query checked). Commit/push stay
on the same phase branch. No merge or post-merge CI occurred for this slice.
