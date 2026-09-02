# Phase 10C2A — Mobile Presentation Foundation

## Status and scope

Implementation ready for formal audit; not formally closed or integrated. Work remains on
`phase/10c2-mobile-input-layout-lifecycle`, after analysis commit `5508e59` and integrated main
`3a1f993`. No PR, merge, CI-policy change, or 10C2B implementation is part of this slice.

Authority: [10C2 analysis](PHASE_10C2_MOBILE_INPUT_LAYOUT_LIFECYCLE_ANALYSIS.md), the closed
[Application Shell contract](../production/contracts/APPLICATION_SHELL_CONTRACT.md), and
[Native Save/Load contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md).
This is native presentation work, not a migrated mechanic: no new LPC inspection or gameplay
compatibility decision was needed. `reference/es2` and `DECISIONS.md` are unchanged.

## Safe-area authority and coordinates

- `game/presentation/layout/safe_area_metrics.gd`: typed, instance-local logical viewport/safe
  rectangles, fallback indication, breakpoint/qualification and layout-only reservations.
- `safe_area_capability.gd`: narrow injectable measurement boundary; pure tests use
  `game/tests/presentation/fake_safe_area_capability.gd`, not global DisplayServer state.
- `game/runtime/application/godot_safe_area_capability.gd`: the only native safe-area API reader.
  Desktop/headless use the complete logical viewport. Android/iOS query display safe bounds.
- `safe_area_presenter.gd`: one Shell-owned presentation sampler. Shell, resident Outdoor HUD and
  its panels share the same metrics object. A standalone map gets a local provider through the
  same boundary; no Autoload, Session pointer, or gameplay state is introduced.

Normalization takes logical viewport `V`, its logical-to-screen transform `T`, physical content
rectangle `C = T * V`, and native physical safe rectangle `S`:

`logical_safe = inverse(T) * intersection(C, S)`, clipped to `V`.

It accounts for scale and window/content offsets, and does not subtract insets a second time when
the drawable content is already inset. It never uses a world/camera transform. Invalid, empty,
non-finite, disjoint bounds or singular transforms fall back deterministically to the logical
viewport; an invalid viewport itself receives a finite positive 1x1 emergency rectangle. Valid
out-of-range native rectangles are intersected/clamped. Fallback is exposed, not presented as
confirmed device-safe measurements.

Viewport `size_changed` causes immediate measurement; a 0.25-second presentation sample also
catches content-transform or display/orientation metric changes without a resize. Equivalent
metrics do not emit another reflow. This is not lifecycle, input cancellation, or game scheduling.

## Sizing and orientation

`game/project.godot` explicitly preserves desktop 1152x648 and adds `.mobile` 960x540, with the
existing `canvas_items` / `expand`. `window/handheld/orientation=4` selects Godot's sensor-landscape
policy for both landscape directions; Android/iOS use this common project configuration, with no
conflicting portrait export override. Physical rotation/device qualification remains deferred.

- Compact: safe width <1100 **or** safe height <640; exact 1100x640 is wide.
- Qualification: safe rectangle >=800x480 **before** the inner content padding. Smaller areas
  remain bounded/scrollable but are not claimed fully gameplay-qualified.
- Content padding:16; action spacing:8; compact/mobile buttons >=64x64; body/action text >=20
  while existing larger headings are retained. Desktop font/minimum sizing is restored on reflow.
- Width mode and mobile target sizing are distinct: a wide mobile viewport still needs 64-high
  targets and sufficient action-panel height. Desktop is not forced into compact presentation.
- For exceptionally tiny valid rectangles, padding is limited to one quarter of each extent to
  avoid negative geometry. No device-name tables or phone-specific camera zoom are used.

## Responsive consumers

`responsive_panel_layout.gd` wraps existing content in bounded vertical ScrollContainers, removes
rigid minimum widths, wraps text, and uses preferred widths. Native `follow_focus` plus post-reflow
reveal keeps the **existing** focus owner reachable; this layer never selects a new focus owner or
changes cancel policy. Per-panel original typography/minimum caches restore desktop styling and
discard freed dynamic row controls. Deferred reveal safely handles removal from the SceneTree.

`application_shell_layout.gd` adapts Main Menu, Pause, Settings, Recovery, Result and Busy in the
same `application_shell.tscn`. Full-viewport modal barriers remain full-viewport; only visible
content uses safe bounds. Existing buttons, unique names, connections, typed state, focus cycles,
unsupported Window Mode hiding and modal precedence remain authoritative. Settings/Result rows
flow when width is insufficient. A presentation-only hint explains platform-managed window mode.
Busy text is safe-bounded without reducing its input-blocking overlay. No Shell controller change.

`oldpine_hud_layout.gd` reparents the existing controls rather than adding alternative gameplay
actions. Wide mode keeps a left information/action/detail column. Compact mode uses two flexible
vital columns, a right two-column action grid, and bounded Details disclosure for the original
inspection and six-line combat log. Inspect, Attack, Traverse, Open Loot and Inventory keep their
signals and eligibility. Details/Close details are presentation-only controls.

Qualified compact geometry leaves the bottom-left 192x192 movement reservation and top-right
64x64 Pause reservation clear. These are rectangles only: no fake pad, touch Pause or input action.
Below qualification, bounded scrolling and an overlaid details panel prioritize readable controls;
future-pad gameplay qualification is explicitly not promised there. Cave receives no Outdoor HUD.

Inventory/Loot use bounded centered panels in compact mode and right-side panels in wide mode.
Dynamic rows use a reflowable BoxContainer, retaining item IDs and original action connections.
Inventory retains Inspect and all Wield/Unwield/Wear/Remove semantics; nested list scrolling and
inspection remain accessible. Loot adds inline wrapped descriptions instead of depending solely
on hover. Panels are opaque so world/HUD text cannot show through their occupied area. They do not
pause combat or change processing/SaveEligibility. Touch ownership/leak prevention is not added.

## Verification

Focused commands use Godot 4.7.2 and isolated test user data:

| Validation | Result |
|---|---|
| `--headless --path game --script res://tests/run_phase_10c2a_tests.gd` | 2609 assertions PASS |
| Same runner with `-- --consumers` | 1260 assertions PASS; selected 10C1B, inventory/loot, armor and authored-map consumers |
| `res://tests/run_phase_10c1c_tests.gd` | 1267 assertions PASS (includes 10C1A/10C1C, repository/transaction/Session/Outdoor consumers) |
| `python -m unittest tools.tests.test_prepare_release_project` | 11 tests PASS |

Total: 5136 Godot assertions across these focused commands, with no runtime/script errors in
their final logs. These are targeted suites, not a claim about the full historical runner.

The matrix covers 1152x648, 1920x1080, 960x540, 1212x540 wide-phone-like geometry, left inset48,
right inset48, bottom inset24, 1024x768 tablet, minimum800x480, below-minimum480x320, and an
additional wide-mobile1280x720 case. Assertions check finite safe panel bounds, target sizes,
non-overlap, focus/scroll reachability, disabled/hidden exclusions, unchanged Shell/Session
identity, future reservations, inline descriptions and no panel-induced gameplay pause. Pure
tests cover scaling/translation, invalid/disjoint/non-finite inputs, clipping and exact thresholds.

Existing dynamic-row tests now accept BoxContainer rather than assuming HBoxContainer. Five
old total-node-count assertions (`225`) now directly assert absence of the obsolete ResetButton;
layout wrappers legitimately change node counts. Their gameplay assertions are unchanged. The
new test is registered in the canonical runner **without running the complete historical suite**;
that gate remains for Formal Audit. No Vine-region flake assertion was weakened.

`prepare_release_project.py` explicitly requires all seven production safe-area/layout scripts.
The narrow sanitizer test checks their retention, fake/test removal, and preservation of mobile
dimensions, canvas stretch and sensor landscape. Fresh staging, validate-only and development /
sanitized headless editor checks PASS. `git diff --check` and changed-text trailing whitespace
checks also PASS. Local logs are under ignored `build/phase10c2a-*.log`.

## Actual runtime evidence

Canonical ApplicationShell was run in Godot 4.7.2. Healthy observations had `helper_live=true`,
`session_active=true`, `game_capture_ready=true`, advancing frames and `stale_frame=false`.
Inputs used native keyboard, joypad and framebuffer mouse events (MCP input tools or equivalent
InputEvent injection through `Input.parse_input_event`), not button callbacks or Shell methods.

- 1152x648 desktop Main Menu -> New Game confirmation -> Outdoor, real HUD/Inventory controls.
- Logical960x540 and injected safe(48,0,912,516): Settings hint/Cancel, New Game, compact HUD,
  Inventory -> Inspect, Pause -> Settings -> Cancel, Return confirmation. Same Session ID
  `369467853035` before/during paused Settings; `paused=true`, `session.can_process=false`.
- Actual Loot fixture: the existing test helper prepared a corpse and placed the player before
  the claimed UI route. Real corpse picking -> Open Loot -> Take changed remaining rows2->1 and
  player direct items1->2; `paused=false`. Real wheel scrolling revealed the inline silver
  description. This is loot-presentation evidence, **not** an end-to-end combat/death claim.
- Logical1920x1080 wide reflow retained HUD/log/loot. A separate standalone desktop process was
  also operated through native Windows mouse/keyboard: actual1152x648 Windowed -> Settings ->
  Fullscreen; fresh process preserved Fullscreen; real Settings restored Windowed at1920x1080;
  New Game and wide Inventory remained usable. The original Windowed preference was restored.
- A clean final helper run injected safe480x320: Main Menu scroll/focus and real joypad
  Down/Down/Accept reached Settings, with Cancel visible and focused. No qualification claim.
  Healthy run frames2137->4845, no current runtime errors.
- Final multi-row check: two short-sword instances were prepared through existing typed item
  test helpers before opening Inventory. Real mouse Inspect, Tab/Tab and Enter scrolled to the
  second row and displayed its short-sword details (NONE, sword, damage15). Frames1184->3475
  advanced, non-stale; final `current_run_errors=[]`. All QA games were stopped afterward.

One prior scratch eval failed compilation. After loot proof, a subsequent Pause attempt hit the
old QA recorder's assumption that an injected counting CombatRandomSource implements
`capture_random_state()`. That test double does not; the resulting debugger break/stale frame
was excluded. No production fix or blanket suppression was applied. Clean subsequent processes
used normal RNG and the final helper run reported `current_run_errors=[]`.

Standalone games register the helper but Godot AI's editor-run gate does not identify them as its
current launched run. Computer-use Windows capture/input supplied standalone window-mode proof;
it is not mislabeled helper-based proof. No Android/iOS runtime claim is made.

## Deferred

10C2B owns virtual-pad behavior, touch capture/synthesis, multitouch ownership and touch Pause.
10C2C owns Android Back, system_back, lifecycle notifications/resume gates/input clearing,
installed APK and physical orientation qualification. No `quit_on_go_back` change, autosave,
in-game Load, new slot, mobile Settings preference, iOS runtime/store signing or gameplay change.
The permanent 10C2 contract and full audit/PR/integration gate remain later work.
