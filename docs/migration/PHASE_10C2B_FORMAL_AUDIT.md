# Phase 10C2B — Formal Audit: Touch Input + Android Back

Audit date: 2026-09-02. Implementation baseline:
`856eae35e02b33138dc2ace5d104faa8e8c8476d`; closed 10C2A baseline:
`968abbea4edda5ab2a7856e8afee98ebe0c0a1f6`.
Branch: `phase/10c2-mobile-input-layout-lifecycle`.

**Result: FORMALLY CLOSED for the B slice. 10C2C is safe to begin, not implemented.**
This is local/formal closure, not integration on main. No PR or merge is part of this audit.
The Phase10C2 Analysis and existing Shell/Save contracts remain authoritative.

## Concrete findings and narrow corrections

Only `game/runtime/application/mobile_touch_adapter.gd` changed in production during this audit.

1. **Reentry did not reacquire runtime ownership.** `_exit_tree()` restored mouse emulation but
   `_ready()` alone installed listeners and enabled the adapter. Godot does not call `_ready()`
   again on an ordinary remove/add. Reentry consequently left emulation/subscriptions wrong,
   and later teardown attempted nonexistent disconnections. The adapter now separates one-time
   control construction from idempotent tree attachment. It disconnects Shell/popup/metrics/map
   listeners, resets activation, and reconnects existing panel listeners on reentry. An attachment
   guard covers two rapid reentries before deferred attachment, and off-tree configuration does
   not acquire global emulation state. Lift events while disabled release quarantined indices.
2. **Cancelled world touch had already selected a target.** World Areas consume mouse-down,
   so sending it at touch-down cannot be undone by a cancelled mouse-up. Only a world-origin
   pointer now delays mouse-down until an uncancelled lift, then delivers the ordinary paired
   click through root Viewport picking. GUI gestures retain down/motion/up for native scrolling.
   A world-origin contact released over GUI cannot become a GUI activation. No world consumer,
   gameplay rule, selection method, or physics implementation changed.
3. **Physical mouse takeover assumed a device-number exclusion.** Hardware is not guaranteed
   never to use 10202. Own synchronous synthetic pointer dispatch is already guarded by
   `_routing`; physical mouse takeover therefore no longer excludes that arbitrary label.
   The pad source remains held, while the synthetic pointer is cancelled/quarantined.

The initial reproducer failed 5 of 116 assertions (one secondary world-count failure); the
three fixes made all 116 pass. Expanded diagnosis then found two *test-fixture* mistakes:
physical-keycode-only input did not match this project's keycode binding, and a root-only
observer could not see a press routed to the native popup Viewport. Correcting those observers
made 203 pass. Further handoff/stretch/Inspect tests produced the final **221** passing B assertions.
These diagnosis runs were focused, not complete historical suite attempts.

## Independent engine and source audit

All Phase10C2B implementation changes were reviewed: capability/capture/exit/Back types,
adapter, Shell controller/scene, project input settings, responsive/HUD layout integration,
build entrypoint, sanitizer, and their tests. Existing CharacterBody, world Area, inventory/loot,
Shell state, safe-metrics, and Host consumers were followed to prove the boundaries. No LPC
source was scanned; no migration formula changed.

Pinned **Godot 4.7.2-stable** source checks:

- [Input](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input.cpp) and
  [InputMap](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input_map.cpp):
  action cache entries are separated by device and event index. InputEventAction uses the index
  after configured bindings, distinct from keyboard/controller binding indexes even when device
  numbers coincide. Pressed state aggregates the entries. Tests exercise both release orders,
  same numeric device labels, opposing directions and final zero; no global action-release is
  introduced by the touch adapter. 10202 and 10203 are stable adapter labels, not claims about
  impossible hardware numbers, and are not extra physical InputMap bindings.
- [BaseButton](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/base_button.cpp):
  raw ScreenTouch and mouse are both activation paths; consuming raw touch before GUI prevents
  double activation. Its mouse release path does not make `canceled` alone sufficient; moving
  outside before release prevents an abandoned GUI press from activating.
- [ScrollContainer](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/scroll_container.cpp):
  touchscreen mouse drag, native deadzone, scroll-begin notifications and inertia remain the
  scrolling implementation. Temporarily PASSing descendant filters lets that native route run;
  no custom scrolling algorithm was added.
- [Viewport](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/viewport.cpp):
  normal GUI and queued physics picking remain authoritative. The adapter receives viewport-local
  coordinates, then uses `push_input(event, true)`. Actual 2x root stretch is tested with physical
  input coordinates. Safe-area layout is still produced solely by the 10C2A metrics/presenter.

## Acceptance coverage / ownership

Numbers below correspond to the formal-audit request; evidence is code inspection plus the
original `mobile_touch_test.gd`, new `mobile_touch_audit_test.gd`, consumer regressions and live
routes below. Typed setup of busy windows, display-only long rows, deterministic RNG, proximity,
or a handoff boundary is not labelled player-input proof.

| Audit areas | Finding / evidence |
| --- | --- |
| 1–3: ownership, capability, pad | One Shell -> persistent Host -> 0..1 Session remains unchanged. Adapter stores Shell/presenter/capture/GUI routing state, not Session/Player/map/gameplay authority. Android/iOS feature capability only; desktop disabled. Exactly 192x192, nine 64x64 cells, neutral center, four existing digital actions only. CharacterBody unchanged. |
| 4–9: capture, edges, sources, emulation | One PAD + one POINTER in both orders; ignored held third never promoted; outside neutral retains pad; lift/fresh reused nonsequential indexes work. Exact incremental edges and all cells tested. Original true/false emulation restored; repeated enable/disable, exit/reentry/rapid reentry and Shell disposal tested. |
| 10–14: pointer/scroll/cancel/mouse | All synthesized input goes through Viewport, not product callbacks. 2x stretch and safe offsets tested. Native scroll repeated three times, row nonactivation, next fresh tap, original filters, cancel/reflow/removal and pressed visuals tested. Cancelled world and Save/Inspect gestures do nothing; equal-number physical mouse takeover works. |
| 15–19: blockers/precedence/transitions | Busy > popup > Result > Settings/Recovery > Pause/Menu > item/detail blocker > HUD > world. Inventory/Loot and compact Details block input, not gameplay time or SaveEligibility. Wide/compact geometry, two-owner safe reflow, held fingers across Pause/Resume/Settings/Result, and fresh-only recapture covered. Invisible/disabled overlay does not intercept desktop mouse/keyboard. |
| 20–21, 31: map/lifetime/Pause | Boundary tests hold pad + pointer + ignored third through both handoffs. Same adapter, zero stale input, fresh index reacquisition. New Game -> Return -> Continue -> Return -> New Game keeps one adapter and one semantic Pause pair. Live Vine/Cave/SouthExit route separately proved. |
| 22–29: Back/exit | Actual notification emits exactly one pressed/released system_back pair. Action unbound; effective quit_on_go_back false. Busy and Host-pending consumed. Popup-only first Back then fresh Settings cancel; all typed origins preserve one outcome. Back never confirms destructive Return/New Game. Only exactly empty idle Main Menu requests quit, once; fake counter and Android process exit verify. |
| 30, 42–43: desktop/exclusions/save | Existing mouse/keyboard/controller and Shell consumer suites pass; desktop semantic cancel unchanged. Existing Settings/window capability unchanged. Touch Save is the existing button -> Shell -> Host transaction, exact-once and cancelled-zero tested. No autosave, extra slot, mobile preflight, new pause/focus lifecycle or Session authority. |
| 32–35, 44–45: build/sanitizer | Technical ABI restricted to Android and disposable preset; normal ARM64 preset/CI/rendering/signing/identity unchanged. Production types/main retained, tests/QA/helper/debug removed. Actual rendered sanitized desktop smoke passes. See technical staging qualification below. |
| 36–41: installed / exact-once | Installed Android OS route independently repeated. Both landscape presentations and movement/Pause verified. Menu, Pause, Save, Take, Inspect and notification pair counts are asserted. Android simultaneous OS contacts and Android Cave remain explicit C qualifications, not fabricated B evidence. |
| 46–51: quality/final gate | New adversarial tests registered in focused and canonical runners. No new ObjectDB/resource/input-lifetime warning in passing engine runs. Complete suite once, no Vine failure, no weakened expectation; remaining evidence below. |

## Validation results

Official Godot executable: `build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe`.
Each CLI invocation used the existing build helper's isolated Godot environment.

| Validation | Result |
| --- | --- |
| `--headless --path game --script res://tests/run_phase_10c2b_tests.gd` | **221 assertions PASS** (95 original + 126 audit) |
| `run_phase_10c2a_tests.gd` | **3,597 PASS** |
| Same runner with `-- --consumers` (HUD/item/layout consumers) | **1,260 PASS** |
| `run_phase_10c1c_tests.gd` (Shell A/B/C consumers) | **1,267 PASS** |
| Focused invocation total | **6,345 assertions PASS** |
| `python tools/ci/verify.py --godot <above executable>` | PASS; complete historical suite **14,359 assertions** |
| Complete-suite attempts in this audit | **Exactly 1**, after fixes stabilized; no Vine failure |
| Python tooling suite | **45 tests PASS** |
| Repository/static checks, development editor import | PASS |
| Fresh normal sanitizer, validate-only, sanitized editor import | PASS |
| Rendered sanitized canonical Shell, no helper/QA | **20 smoke checks PASS**; native mouse Settings/Cancel, keyboard New Game/movement, desktop overlay hidden |
| Fresh technical ABI pre-export stage validation | PASS; production script byte mismatches against installed audit APK staging = **0** |
| `git diff --check` / changed-file trailing whitespace | PASS / 0 findings |
| `reference/es2` / `DECISIONS.md` changes | **0 / 0** |

Ignored local evidence: `build/phase10c2b-audit-{focused,layout,consumers,shell,complete,
sanitized-smoke,android-build,android-logcat}.log`, diagnosis1–4 logs and
`phase10c2b-audit-android-*.png`. Complete verification includes Python, static, development and
fresh sanitized headless checks. The additional rendered smoke uses the canonical sanitized
scene, with an external ignored input/check driver; it is not a shipped QA/helper scene.

## Real desktop evidence

Canonical ApplicationShell was run with mobile capability/safe metrics injected only for QA;
touch/drag events entered actual Godot input and physics picking. No desired callback was invoked.
Two-contact viewport tests prove both acquisition orders; live input also exercised movement and
Pause without leaving a held direction. A measured diagonal displacement was
`(114.0793, -114.0798)` before Pause cleared movement.

Run 17 independently proved the corrected world cancel and actual cross-map route:

1. Before-route fixture: raw dodge 12, world roll 5, Player near Vine, mobile safe metrics.
2. Touch-down/wait/cancel on Vine left selection empty. Fresh touch selected Vine and enabled
   the existing **Hold vine** HUD button.
3. Real button touch entered Passage Cave. Original world RNG was restored after entry;
   no production formula or save was changed.
4. Cave touch Pause -> semantic Back Resume -> down pad -> physical SouthExit -> Outdoor
   Waterfall Basin `(1200, 780)`. No traversal callback or position assignment replaced this route.
5. Session ID `311670344018`, adapter ID `162923546252`, one TouchCanvas child throughout;
   Cave Outdoor-HUD count 0; final movement vector zero.

At successful route inspection: `helper_live=true`, `session_active=true`,
`game_capture_ready=true`, `current_run_errors=[]`. Non-stale framebuffer frames advanced
**11323 -> 17959**, showing Cave then Waterfall Basin.

Tool-only discarded probes are not hidden: a disabled WindowMode OptionButton in embedded desktop
mode did not open a popup, so subsequent Back legitimately cancelled Settings then exited the empty
Menu. Two later inspection probes used wrong property names (`runtime_character`, `traverse_button`)
and paused debugging; another optional multi-line eval was rejected during compilation. These were
QA-code errors, not shipped-source errors. The required cross-map run above was independently
completed with clean runtime evidence before the optional probe. Native popup semantics are proven
by actual popup Viewport tests with an editable capability, not by the disabled desktop control.

Final clean run 18 separately repeated **POINTER-first and PAD-first** actual ScreenTouch
acquisition: both reported two owners, Pause-cleared movement and quarantined held fingers.
Final helper/session/capture health was true and `current_run_errors=[]`. Games were stopped
after validation; no development save was overwritten. Window-tool focus inspection did not
alter any gameplay or lifecycle policy.

## Android audit and build qualification

Rebuilt and installed the audit-fixed sanitized scripts, package
`com.example.easternstoriesgodot`, on existing Pixel_9_API_35 `emulator-5554`, x86_64. The user
explicitly approved replacing that test package (its local test data was cleared); other apps
were untouched. Temporary signing remains ephemeral; no signing material was committed.

This evidence is **Android OS touch/Back on a technical x86_64 AVD with host OpenGL compatibility**.
The ignored exporter adds `--rendering-method gl_compatibility`; actual process log confirms it.
The APK and manifest explicitly label technical ABI/workstation override. Normal checked-in
ARM64-only export preset, Mobile renderer, package identity and CI commands did not change.

The clean sanitizer and clean technical-ABI stage both pass validate-only. As expected, applying
that validator *after* export-tool setup rejects the temporary absolute custom-template path in
the disposable exporter preset. That configured tool workspace is not the pristine sanitizer
output. A fresh pre-export technical stage passes, and all its production `.gd` files match the
installed audit artifact's staging files byte-for-byte. No validator or production gate was weakened.

Independent actual OS tap/swipe/keyevent route (PID **5769**):

- Fresh launch -> Main Menu Settings -> Back -> New Game.
- Cardinal and diagonal pad holds visibly moved the Player/camera. Touch Pause/Resume, Back from
  Playing -> Pause and Back from Pause -> Playing worked.
- Paused Settings -> Back returned to Pause only. Return confirmation -> Back cancelled and kept
  Session; a fresh Resume returned to gameplay.
- World touch selected the big-pine Area. HUD Inventory opened; pad hidden, Pause available.
  Drag beginning on Inspect scrolled to Unwield without inspecting; a fresh tap displayed sword
  details; actual Close restored gameplay controls.
- Android orientation 3 used the reverse safe layout; fresh pad movement and Pause succeeded.
  Original acceleration `9.81:-1.90735e-06:0` was restored, orientation returned to 1.
- Explicit Return/Confirm -> empty Main Menu; Back exited. Subsequent `pidof` was empty.

Inspected audit-process log contains no Godot script error or AndroidRuntime fatal exception.
The prior implementation's Vulkan queue error 5 / software-GL uniform limitation remains a
reported emulator/rendering-environment restriction, not evidence of a gameplay defect. Those
failures were not deliberately re-provoked; the earlier raw logcat transcript was not found among
retained local log files. This audit neither certifies Vulkan/ARM64 hardware nor claims Android
Vulkan is unsupported. No renderer workaround entered production.

## Explicit deferrals / closure boundary

- **Android OS simultaneous multitouch: PENDING for 10C2C/device qualification.** Available ADB
  tap/swipe is single-contact; it is not mislabelled multitouch. B closure is justified by actual
  Godot multi-contact viewport proof in both orders, platform-neutral capture code and independent
  installed Android pointer/pad/Back proof.
- **Android Cave route: PENDING for 10C2C.** B has strong deterministic both-owner handoff tests,
  real desktop touch Vine/Cave/SouthExit evidence, installed Android movement proof, and no
  platform-specific handoff branch.
- Broad device/ARM64/iOS qualification, lifecycle, background/focus freeze/resume policy,
  Home/Recents and autosave are not implemented or certified here. Reverse-landscape fresh input
  is not complete rotation-lifecycle qualification.
- Passing final test/import/smoke runs have no ObjectDB/resource leak or unexplained stuck input.
  Existing editor analyzer warnings (including inherited shadow-name warnings) are distinct from
  leaks or runtime failures; no new game-lifetime warning is hidden behind the editor plugin.

No source-compatibility decision or final long-lived 10C2 contract was created. Commit/push remain
on the same phase branch; GitHub query found no open PR. Main/PR/post-merge CI are not claimed for
this local B closure, and 10C2C implementation has not started.
