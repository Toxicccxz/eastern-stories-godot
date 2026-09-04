# Phase 10D1 — Physical Device Qualification

Status: **PHYSICAL ANDROID QUALIFICATION PASSED** for the revised, bounded private/internal
Technical Demo gate described below. This is not general Android support, tablet/store
certification, long-duration certification, public-release clearance, or Phase 10D completion.

Parking note: Phase 10D is now frozen pending Combat Experience Redesign. This qualification
remains historical/conditionally reusable evidence for the tested platform interaction layer, but
does not qualify a future redesigned battle presentation. If that redesign materially changes
mobile battle input, lifecycle behavior, renderer, or SafeArea/layout, repeat only the affected
physical qualification rather than automatically invalidating all 10D1 evidence.

## Owner-approved scope revision

The original Phase 10D1 proposal deliberately combined physical Android interaction proof
with a full normal-player journey, Save durability/process-death checks, an unsafe-Save
case, a representative 30-minute soak, detailed performance/memory/thermal profiling and
final candidate log acceptance. On 2026-09-03 the owner explicitly narrowed Phase 10D1 to
answer one question:

> Can the existing Android Technical Demo build run correctly on real ARM64 Android
> hardware using the production rendering, input and application path?

Under that approved boundary, Phase 10D1 requires successful installed launch on named
real ARM64 hardware, the production Android renderer/backend, physical directional touch
and multitouch, usable SafeArea/layout in both supported landscape orientations, real
Android Back, basic Home/foreground lifecycle behavior, and no generalized production
defect found during those tests.

The following were **not executed as completed 10D1 gates and are not represented as
executed**:

- the full unassisted normal-player critical journey, including combat, loot, Inventory,
  equipment and the Vine's natural authored branch;
- manual Save A, an unsaved change B, app-process termination and explicit Continue;
- a representative real unsafe-Save blocker;
- final full-candidate runtime/log acceptance.

Those application/demo acceptance concerns now belong to **Phase 10D3 — Technical Demo
Acceptance**. A long soak and comprehensive frame-time, memory and thermal profiling are
risk-triggered or final-audit work rather than mandatory for the current private/internal
demo. They become required if normal use shows sustained poor performance, throttling,
runaway memory, repeated crash, cumulative degradation, lifecycle leak or Session/map leak.
No numerical performance threshold is invented here.

## Frozen candidate and scope

- Branch: `phase/10d-technical-demo-release-gate`.
- Candidate source: `d08ce8fa1fae354b96760fd75707a63063ee1530`, clean (`dirty=false`).
- Integrated baseline: `ae381bf3f3e5f4a28a417295eea680d023cc428c`; existing four-job
  green main run `33714114002` is retained, not rerun for hardware discovery.
- Godot: `4.7.2.stable.official.ed1daf0bf`; matching official standard templates.
- APK: `build/phase10d1/candidate/android/Eastern-Stories-Godot-android-arm64.apk`.
- Size: **27,762,842 bytes**.
- SHA-256: `81ae081fd0c47e674b88148ecbf0045f2b01bc00bd23fecfa3fabfe98eff4393`.
- Manifest: `build/phase10d1/candidate/android/build-manifest.json`, UTC build time
  `2026-09-03T14:24:31+00:00`.
- Package `com.example.easternstoriesgodot`; version `0.0.0-dev`, code `1`;
  APK reports minimum SDK 24, target/compile SDK 36. Installed SDK prerequisites include
  Platform 35/Build-Tools 35.0.1; this does not mean the template targets SDK 35.
- `aapt2` and ZIP contents independently confirm only `arm64-v8a` native libraries.
- `apksigner verify`: one signer, v2/v3 verification PASS.
- Public certificate SHA-256:
  `4c5db99f36c8cab50074e62d94d87736731293c87a426456de897099b37c60ff`.
- RSA 2048 / SHA256withRSA certificate valid **2026-09-03 14:24:31 UTC through
  2026-09-05 14:24:31 UTC**. Existing ephemeral QA signing; private keystore/editor
  settings removed by the build's cleanup boundary. No reusable key or update promise.

Normal build used `tools/build/build.py --target android --require-clean`, scoped
`--staging build/phase10d1/release-project --dist build/phase10d1/candidate`, pinned
Godot/templates, local Android SDK and Temurin `17.0.18+8`. No technical ABI/package,
renderer, observer, startup fixture, remote-debug or gameplay overrides were passed.
Sanitizer validation passed **before** template-path injection and headless export.
Re-running the sanitizer's pre-export checker *after* the builder injects the documented
absolute custom-template path reports `local absolute path in export_presets.cfg`;
that is the wrong validation boundary, not evidence of a shipped developer path.
No stage edit or candidate rebuild was performed to conceal that diagnostic.

Retained local evidence lives under ignored `build/phase10d1/evidence/`; APKs,
recordings, logs and public-certificate inspection are not shipped or published. After
the second-device comparison, redundant Xiaomi W/SW diagnostic bundles and their
disposable analysis scripts were removed; the frozen candidate and evidence supporting
the completed bounded qualification were preserved. Do not overwrite/rebuild this
candidate casually during qualification.

## Secondary device — Xiaomi 13 Pro

| Fact | Observed value |
| --- | --- |
| Hardware | Xiaomi 13 Pro, model `2210132G`, codename `nuwa`, product `nuwa_global` |
| ADB target | `48ffa836`, authorized physical USB device; `emulator-5554` explicitly excluded |
| OS | Android 15, API 35, security patch `2025-11-01` |
| Build | `Xiaomi/nuwa_global/nuwa:15/AQ3A.240912.001/OS2.0.205.0.VMBMIXM:user/release-keys` |
| CPU / ABI | QTI SM8550, `aarch64`; `arm64-v8a,armeabi-v7a,armeabi` |
| Screen | Physical 1440x3200 / 560 dpi; user override 1080x2400 / 420 dpi |
| Refresh | Physical modes include 120, 60, 40, 30, 24 Hz; initial OS render mode 120 Hz |
| Navigation | `navigation_mode=2`; real Back/Home gesture behavior still requires checkpoint evidence |
| Orientation | Initial OS portrait; game later observed at `ROTATION_90`, 2400x1080 framebuffer |
| Cutout | Physical top-center bounds `(678,0)-(762,122)`, top inset 122; rounded corners radius 105 physical px |
| Touch | Direct `fts` device `/dev/input/event7`, MT slots 0..9 / tracking IDs exposed |
| Power | USB charging; low-power setting `0`; prelaunch battery 78%, 37.3 C |
| Thermal | `thermalservice` HAL available, status 0; current HAL battery 37.3 C. Cached temperature entries are not current measurements. |

Target package was absent at discovery **and immediately before installation**.
Fresh installation succeeded without uninstall, replacement, data clear or save deletion.
Every ADB operation explicitly selected the physical serial, never the attached AVD.

### Xiaomi renderer proof

Cold `am start -W` at device log time `09-03 10:26:24` reports `LaunchState: COLD`,
`Status: ok`, initial PID **883**, TotalTime 508 ms / WaitTime 512 ms. These Android
activity timings are not yet measurements of Menu readiness or Continue latency.

Process-scoped startup log contains:

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf
Vulkan 1.3.128 - Forward Mobile - Using Device #0: Qualcomm - Adreno (TM) 740
AdrenoVK-0: Driver Path : /vendor/lib64/hw/vulkan.adreno.so
AdrenoVK-0: Driver Version : 0676.69
```

Qualcomm driver build `1e9d6bfa18, Ia9449ce5a8`, build date `03/06/25`.
This proves this APK actually selected Mobile/Vulkan on this phone. Android's outer
Skia/GLES window diagnostics do not contradict the Godot Vulkan rendering line.
There is no release Godot AI/MCP helper, so helper health is not a release criterion.

## Primary qualification device — OnePlus 8T

The same frozen APK was freshly installed on a second physical device without replacing
an existing package or save:

| Fact | Observed value |
| --- | --- |
| Hardware | OnePlus 8T, model `KB2005`, product/device `OnePlus8T` |
| ADB target | `8795f723`, authorized physical USB device |
| OS | Android 14, API 34, security patch `2024-03-05` |
| Build | `OnePlus/OnePlus8T/OnePlus8T:14/UKQ1.230924.001/R.171e77d-c19c-4fe22:user/release-keys` |
| CPU / ABI | `arm64-v8a,armeabi-v7a,armeabi` |
| Screen / touch | 1080x2400 / 480 dpi; direct `touchpanel` device `/dev/input/event1` |
| Refresh | Physical modes include 60 and 120 Hz |
| Navigation | Initially `navigation_mode=2` (gesture); final lifecycle repeat used fixed `navigation_mode=0` (three-button) |
| Cutout | Portrait top inset 103 px; both supported landscape orientations tested |
| Renderer | Godot 4.7.2, Vulkan 1.1.128, Forward Mobile, Qualcomm Adreno 650 |

Cold activity launch succeeded (`LaunchState: COLD`, TotalTime 415 ms / WaitTime
438 ms). A later 2400x1080 screenshot proves the real Main Menu was ready and focused;
the process-scoped log contains no Godot script/fatal/resource-load error. Vendor
permission and unsupported 4x4 buffer-format messages were observed but did not prevent
startup.

The installed `base.apk` was pulled from the device and its SHA-256 matched the frozen
candidate exactly. The production startup log identifies Godot 4.7.2, Vulkan 1.1.128,
Forward Mobile, Qualcomm Adreno 650, driver path `/vendor/lib64/hw/vulkan.adreno.so`,
driver build `b213cd5627, I42f35bf1e0` dated 2023-06-11.

The owner tested all eight pad directions with real finger input and reported every
direction responsive, including W and SW. The owner then completed the physical
multitouch acquisition/release sequence: PAD-first and pointer-first both worked, a third
contact did not steal direction ownership, release did not promote an ignored contact,
all contacts could be released, and fresh touch worked. The bounded kernel repeat records
21 contact starts, 21 releases, a maximum of three simultaneous contacts and zero active
contacts at completion.

Real rotation covered both `ROTATION_90` and `ROTATION_270` while a Session remained
active. Playing/HUD/touch pad, Inventory, Settings and confirmation presentation remained
reachable and readable; Inventory scrolling and equipment actions were usable. Real
Android Back covered the current top presentation, bare Playing, bare Pause, Settings,
confirmation and idle Main Menu behavior without double action, accidental confirmation,
input leakage or unexpected exit.

Home/Recents was physically exercised for normal Playing, held movement/multiple contacts,
already-Paused and Inventory-open states. An owner-initiated Android navigation-mode change
caused the expected Activity/process recreation, so that confounded segment was not used as
ordinary lifecycle proof. With navigation then fixed at three-button mode, the minimal
four-path repeat kept task `#150` and PID `21945`, required explicit Resume for interrupted
Playing, cleared held input, preserved paused/Inventory semantics and accepted fresh input.
No lifecycle-generated Save, duplicate Session, map loss, camera/body loss or visible
runtime failure was observed.

The directional sluggishness observed on the tested Xiaomi 13 Pro configuration did not
reproduce with the same frozen APK on OnePlus 8T. Current evidence is insufficient to
classify it as a generalized game-input defect. Xiaomi is not marked unsupported, and the
evidence does not establish a Xiaomi hardware fault. No production input code changed.

Local cleanup removed 161 redundant diagnostic files (81,583,868 bytes): repeated
`sw-delay`, `sw-timestamp`, `authorized-shortpress`, `edge-only-shortpress` and
`synthetic-shortpress` bundles, the unused OnePlus splash frame, and four disposable
touch-analysis scripts. The exact frozen APK, build/signature/manifest evidence, cold
launch and renderer evidence, formal checkpoints, multitouch evidence, performance
samples and the OnePlus ready-Menu screenshot remain available locally.

## Manual checkpoints and evidence limits

ADB performs install/launch, read-only touchscreen capture, screenshots/video, logs,
platform metrics and explicitly checkpointed process termination only. Qualification
gestures must be the owner physically touching the phone; no synthetic touch, controller
calls, teleports, stat/RNG edits, prepared save, or input helper is used.

The first screenshot (historically named `menu.png`) actually shows combat/details,
not Menu; likewise `menu-meminfo.txt` is an uncontrolled early gameplay sample. The owner
confirmed they had paused and observed no sticking. Do **not** count those filenames as
proof of cold Menu, a completed journey, or a controlled Menu performance workload.

| Required gate | Current evidence / status |
| --- | --- |
| ARM64 install and actual production Mobile/Vulkan | **PASS** for the frozen APK on the named OnePlus 8T and Xiaomi 13 Pro configurations |
| Real physical directional touch | **PASS** on the primary OnePlus 8T: all eight directions responsive; neutral/outside release stops movement and fresh touch works |
| West/southwest comparative observation | **BOUNDED DEVICE-SPECIFIC OBSERVATION**: sluggishness reported on Xiaomi did not reproduce with the same APK on OnePlus; insufficient evidence for a generalized production defect |
| Real physical multitouch | **PASS** on OnePlus: both acquisition orders, third-contact non-steal, independent release semantics, full release and fresh acquisition; repeat capture 21 starts/21 releases/max 3/final 0 |
| Both supported landscapes and SafeArea/layout | **PASS** on OnePlus for Playing/HUD/pad, Inventory, Settings and confirmation; real `ROTATION_90`/`ROTATION_270` reflow retained the live Session |
| Real Android Back | **PASS** for current top presentation, Playing, Pause, Settings, confirmation and idle Main Menu behavior |
| Basic Home/foreground lifecycle | **PASS** after an uncontaminated fixed-navigation repeat: explicit Resume, held-input clearing, paused/Inventory coherence, same task/process and fresh input |
| Generalized production defect in tested boundary | **NOT FOUND**; no production correction or candidate rebuild justified |

The first Xiaomi multitouch checkpoint (`checkpoint3-multitouch.txt` /
`checkpoint3.mp4`) ended before every represented slot was released and remains only
historical partial evidence. It is not used to manufacture a complete release claim.
The later OnePlus repeat (`oneplus-multitouch-repeat-20260903-141832.txt`) is the bounded
full-release evidence used above.

### Explicitly deferred from Phase 10D1

| Concern | Revised ownership |
| --- | --- |
| Full unassisted normal-player journey: combat, death/loot, Inventory/equipment and Vine natural branch | Phase 10D3 — Technical Demo Acceptance |
| Save A -> unsaved B -> process termination -> explicit Continue A | Phase 10D3 — Technical Demo Acceptance |
| Representative unsafe-Save blocker and preservation of the last completed Save | Phase 10D3 — Technical Demo Acceptance |
| Final full-candidate runtime/log acceptance | Phase 10D3 — Technical Demo Acceptance |
| Representative >=30-minute active soak and comprehensive frame/memory/thermal profiling | Risk-triggered/final audit; not mandatory absent observed degradation, leak, throttling or repeated failure |

No row in this deferred table is claimed as executed or passed by Phase 10D1.

## Initial performance observations — not acceptance thresholds

- Early gameplay/details process sample: PSS 451,318 KiB, RSS 566,336 KiB;
  later initial collection sample PSS 430,025 KiB, RSS 546,900 KiB. Different/uncontrolled
  contexts; not a leak trend or comparable teardown checkpoints.
- Android `gfxinfo` exposes only 24 outer Skia-window frames in the initial capture;
  its 5/17/73 ms p50/p95/p99 values are **not Godot gameplay frame times**.
- Godot SurfaceView's SurfaceFlinger presentation timestamps are readable. One
  126-presentation / 2.062-second uncontrolled window reports about 60.63 deliveries/s,
  interval median 16.493 ms, p95 16.495 ms, maximum 16.496 ms. This short ring-buffer
  sample is not sustained FPS, GPU execution time or a complete long-stall census.
- Read-only sampling began `2026-09-03T14:30:21.6473758Z`, approximately every 15 seconds:
  game PSS/RSS/CPU, SurfaceView timestamps and thermal/battery evidence. Gaps between
  ring-buffer samples must remain explicit; recording overhead and USB charging apply.
- The bounded collector completed at `2026-09-03T15:00:33.5128698Z` with 113 memory
  samples. That elapsed 30-minute window includes waiting/unscripted activity and is not
  represented as a completed active soak.
  Android `dumpsys cpuinfo` reports a historical averaging window, not instantaneous
  background CPU. Per-process `/proc/883/stat` is readable for later timed comparisons.
- Controlled journey/Save/Continue and final candidate runtime acceptance remain Phase 10D3
  work. Extended soak/profiling is risk-triggered. No numerical acceptance budget is
  invented or retroactively declared PASS.

## Diagnostics requiring honest classification

- **Historical Xiaomi input-latency observation:** after checkpoint 4 the owner reported the southwest
  cell seems to take roughly half a second before movement. Follow-up explicitly confirms
  this is **only southwest, every fresh press, including after reopening the game**, not
  the entire pad or just the first press following a presentation transition. A later
  read observes PID 25411 instead of 883; this is not the planned Save A/B restart proof.
  At that point the report required investigation and was neither a PASS nor a measured
  500 ms delay. The inspected production path claims PAD and
  emits direction actions in `MobileTouchAdapter._touch()` immediately; the player polls
  those actions each physics tick in `WorldCharacterBody2D._physics_process()` with no
  hold timer. All nine cells share the arithmetic direction mapping; southwest has no
  dedicated time gate. The authored Camera2D does have smoothing, but it does not by
  itself explain a southwest-only report. Initial physical contact, app delivery, first
  visible character displacement and collision context still need a paired comparison;
  the mere presence of OS gesture monitors is not proof of OS interception. No code changed.
  The retained checkpoint, display/input dumps and scoped log preserve the useful part
  of this observation. The previous
  three-minute event window is empty and cannot measure the reported delay; coordinate
  readiness before another bounded capture rather than claiming it covered later actions.
  The later OnePlus physical comparison bounds this as a Xiaomi-configuration observation,
  not a generalized 10D1 production-input blocker.
- **Follow-up physical comparison:** owner confirmed readiness, then completion of the
  bounded capture `sw-delay-20260903-115311` (host start
  `2026-09-03T15:53:11.4274194Z`, physical serial `48ffa836`, PID 25411). Its raw
  touch/log/video bundle was inspected before being removed as redundant after the
  second-device comparison. Three direct SW contacts
  are tracking IDs `77a`, `77c`, `77d`, at approximately framebuffer `(168,992)`,
  `(177,993)`, `(169,1002)` in the actual 2400x1080 landscape. Kernel down/up intervals
  are **547.114 / 326.483 / 343.447 ms**. Matching MIUI application-window log timestamps
  follow their `phoneEventTime` by **1 / 3 / 5 ms**, respectively; this is application
  log delivery evidence, not Godot physics timing or physical finger-to-pixel latency.
  Local browser decoding of the saved video (no browser input to the phone) observes
  SW movement onset in sampled video intervals **(30.65,30.70]**, **(37.775,37.80]**,
  **(39.15,39.175]** seconds. The neighboring SE onset is **(32.80,32.85]**;
  kernel SE-minus-first-SW down time is 2.105294 s, consistent with those video onset
  intervals and not an additional approximately 0.5 s SW-only delay after delivery.
  Both shorter SW contacts visibly produce left/down movement. Tracking the blue player
  against the same static clearing boundary gives approximately **170 / 104 / 103 px**
  leftward relative displacement, respectively; camera smoothing is not mistaken for
  authoritative continued movement. These are compressed-video observations, not a
  gameplay unit test or sub-frame benchmark. The disposable pixel scan can select the
  player edge instead of the ground while they overlap; only unobstructed before/after
  samples are used for these approximate displacements.
  **Limits:** video time zero is not the host capture-launch timestamp; there is no
  calibrated common physical finger/contact-to-video clock or external view of the
  finger first touching glass. Relative event spacing is usable, but absolute input
  latency and any delay before the first kernel contact are not established. The result
  narrows the investigation; it does not invalidate the owner's earlier repeated report,
  prove a fix or establish the requested drag path merely from completion. The subsequent
  owner/device comparison supplied the qualification decision. No production change, OS
  touch setting change, synthetic input or candidate rebuild.
- **Timestamp-overlay repeat on Xiaomi:** the owner explicitly reiterated that
  the delay is obvious and requested another trial. Capture `sw-timestamp-20260903-122922`
  started `2026-09-03T16:29:22.4474149Z` on the same APK/PID/device. Android's documented
  `screenrecord --bugreport` adds a capture-only wall-clock/frame overlay; `show_touches`
  remained `0` and `pointer_location` remained unset. No OS input settings were modified.
  Recorder completed 180 seconds / 10,914 encoded frames; the pulled MP4 is 19,085,405
  bytes. The raw touch/logcat/video bundle was inspected before the later cleanup.
  There were 13 contact starts and 13
  releases, including two overlapping-contact intervals.
  For direct SW contact `78d`, kernel down is `41808.355547`, application
  `phoneEventTime=12:30:11.622`, and app-window log arrival is `12:30:11.624`.
  The sampled video frame `f=2897` / `12:30:11.654` still shows the resting blue player;
  `f=2899` / `12:30:11.686` shows left/down displacement. Thus recorded movement is
  visible 62 ms after app log arrival (64 ms after the event's wall-clock timestamp),
  not approximately 500 ms later for this particular contact. Neighboring SE contact
  `78b` arrives at `12:30:05.396`, with displacement visible at frame `f=2520` /
  `12:30:05.436` (40 ms). This timestamped screen-capture comparison is not a calibrated
  physical finger-to-photon measurement and cannot exclude pre-kernel contact latency.
  The owner reported an obstacle during the sequence; the final screenshot
  `sw-obstacle-current.png` shows Paused, nearby bandits and vitality 189/189/220,
  versus 220/220/220 at the sampled directional starts. Do not claim a completed,
  isolated obstacle-free sequence or infer the exact collision from this screenshot.
  At that checkpoint it was unclear whether "obstacle in the middle" referred to the map
  or the pad's neutral center. The later purported slide step records simultaneous
  contacts `78f`/`790`, then `793`/`794`, so it is not yet evidence for a single-contact
  left-to-SW drag. Current `TouchCaptureState.press()` deliberately does not let a
  second PAD contact steal ownership; do not misclassify this expected rule as latency
  or assume how many physical fingers were used from the instruction alone.
  This capture did not resolve the Xiaomi-specific subjective report. The later OnePlus
  physical result did not reproduce it and established the bounded cross-device conclusion;
  no production correction is justified and Xiaomi is not marked unsupported.
- **Rapid-tap refinement / authorized synthetic diagnosis:** owner started another New
  Game, moved to an open area and identified brief taps as the revealing case: **W and
  SW feel sluggish, SW more strongly**, whereas other cells produce short bursts. This
  supersedes the earlier "SW only" characterization; long-hold motion evidence does
  not settle short-tap responsiveness. The owner explicitly authorized ADB testing.
  These synthetic diagnostic inputs remain separate from required human physical-touch
  qualification. Precheck screenshot `shortpress-before.png` shows North Approach,
  full 220/220/220, no selected target, same process 25411; New Game is not a process restart.
  A proposed eight-direction immediate-tap / 80 ms same-point-swipe comparison aborted
  at its first E tap: Android returned `SecurityException: Injecting input events
  requires ... INJECT_EVENTS permission`. One exact retry reproduced that permission
  failure. The historical `synthetic-shortpress-20260903-124558-results.json` contained
  **only the before
  frame**, not any successful movement trial. Do not infer a directional/gameplay failure
  from this environment restriction. Capture/diagnostic scripts are disposable ignored
  tooling; production code, phone security settings and the frozen APK remain unchanged.
  ADB control needs the owner's phone-side security authorization before continuation;
  no bypass, permission grant or alternative injection route is attempted.
- **Authorized ADB comparison after owner enabled security setting:** owner confirmed
  the phone-side setting was enabled. ADB control then succeeded on the same APK and
  PID 25411. The initial screen showed the explicit app-away Resume gate; automation
  pressed its real Resume button, never a controller method. The inspected result files were
  `synthetic-shortpress-20260903-125623-results.json` (8 immediate taps + 8 requested
  80 ms same-point swipes), `synthetic-shortpress-20260903-125803-results.json` (8
  directions x requested 20/40/80 ms x 3 repetitions), and
  `synthetic-shortpress-20260903-130038-results.json` (8 separate DOWN/UP pairs without
  MOVE). Per-input PNGs and before/paused PNGs originally accompanied them. Capture bundles were
  `authorized-shortpress-20260903-125623` and `edge-only-shortpress-20260903-130037`;
  pulled MP4 sizes were 20,499,479 and 14,837,192 bytes. These redundant raw files were
  removed after the cross-device conclusion. The first video's time limit preceded
  the final few repeat trials, so no claim of full-video coverage is made.
  **Results:** all **72/72** repeat trials produced displacement in the expected
  direction, measured relative to the static road/clearing boundaries, not camera
  recentering. All **8/8** no-MOVE DOWN/UP trials also produced the expected displacement.
  These are diagnostic samples, not unit-test assertions or physical qualification.
  In the requested 20 ms rows, E/W are +15/-15 horizontal framebuffer pixels in all
  three repeats; SW is (-11,+10), (-10,+10), (-10,+10). No-MOVE W is (-7,0) and SW
  (-5,+5). Small per-trial differences are retained: for requested 80 ms, W is
  -44/-43/-43 versus E +37/+36/+36; SW is approximately (-21,+21), (-20,+20),
  (-25,+26), while NE is (+26,-26), (+25,-26), (+30,-31). Do not describe samples as
  exactly equal or infer a direction-independent latency guarantee from them.
  Command durations are requests, not exact physical holds: the 92 complete app-log
  DOWN/UP pairs align with Resume, test sequence and Pause; repeat event-time durations
  are 20-35 / 41-55 / 80-99 ms for the three groups. Separate no-MOVE DOWN/UP events
  are 22-30 ms apart and report `moveCount:0`. All eight immediate `input tap` trials
  have equal DOWN/UP eventTime and no measured movement; zero-duration synthetic taps
  must not stand in for the owner's human quick presses or be silently "fixed" with
  a new minimum movement impulse. Both kernel `getevent` captures are empty as expected
  for these framework-injected inputs; they provide **no physical-contact proof**.
  The final real UI is Paused, vitality 220/220/220, no selected target. Scoped logs
  contain no matched script/fatal/ANR/resource-load failure. No Save, New Game, package
  restart, gameplay edit, physics/touch setting change, or binary rebuild was performed
  by the diagnostic. ADB did not reproduce the owner's W/SW-specific sluggish response,
  and the later physical OnePlus comparison also did not reproduce it. Treat it as an
  bounded Xiaomi-specific observation, not a demonstrated general application defect.
- The owner reported awkward Inventory scrolling. The physical screenshot confirms a
  short list with the sword's `Inspect` visible and `Unwield` below its viewport, while
  the empty detail area takes substantial space. Current `player_inventory_panel.gd`
  creates ordinary BoxContainer rows, not per-item scroll views. `responsive_panel_layout.gd`
  stacks touch row buttons (minimum height 64 each) but caps the authored list minimum
  height to 120; `oldpine_outdoor.tscn` reserves 140 for inspection separately. This
  explains the observed layout. The owner physically confirmed both `Unwield -> Wield`
  and `Wield -> Unwield` work without accidental activation. Retain this as an ergonomic
  issue, not a demonstrated unreachable-action blocker; no production change. The bounded
  checkpoint-2 recording must not be assumed to cover actions performed after its expiry.
- On OnePlus, transitioning from the landscape game Surface to portrait Home logged
  `Couldn't present to Vulkan queue (VkResult error -1000000000)` during Surface teardown.
  It reproduced on an ordinary Home transition, while the same PID/task recovered through
  the explicit Resume gate with no crash, black screen, state loss or visible malfunction.
  Record this exact Adreno/Godot teardown warning; do not call it error-free and do not
  treat it as a demonstrated production failure. A final full-candidate log decision is
  deferred to 10D3.
- `aapt2` warns that the APK resource table retains `mipmap/themed_icon` referring to
  absent `res/mipmap-anydpi-v26/themed_icon.xml`. The actual application manifest uses
  `mipmap/icon` (`0x7f0a0000`), whose adaptive XML and foreground/background are present;
  no consumer of the themed entry was found in the inspected manifest/resource table.
  Installation and Vulkan startup succeed. This is a retained packaging warning, not
  a demonstrated gameplay resource-load failure; launcher/theme consequences are not
  silently claimed qualified. No exporter/renderer change made to suppress it.
- Initial process log includes Xiaomi `FileUtils` permission errors for
  `/dev/mi_exception_log`, vendor-property SELinux denials and informational Adreno
  unsupported-feature-structure messages. These are not GDScript exceptions and did not
  prevent the tested production launch/interaction path.

## Change, validation and release boundary

Production/gameplay/build/CI changes: **0**. `reference/es2` and `DECISIONS.md`: **0**.
No LPC reread, new gameplay, permanent signing/store setup, public upload, PR or merge.
Sanitized pre-export validation, sanitized Godot headless editor check, normal Android
export, independent APK verification and lightweight repository/static checks passed.
The full historical suite is deliberately not rerun for this validation-only slice.

**PHASE 10D1 — PHYSICAL ANDROID QUALIFICATION PASSED.**

This pass is bounded to the tested private/internal Technical Demo interaction layer on
the named ARM64 configurations. Evidence covers production renderer startup, real
touch/multitouch, supported landscape/SafeArea, Android Back and basic lifecycle behavior.
It is not general Android, tablet, store, final gameplay/durability or long-duration
certification. **PHASE 10D2 — TECHNICAL DEMO PACKAGING PASSED. PHASE 10D3 — BLOCKED /
SUSPENDED; ACCEPTANCE NEVER PASSED.** Windows pristine-ZIP and the deferred Technical
Demo acceptance journey require a new post-redesign candidate; iOS remains
integrated/unsigned-build-validated but iPhone/iPad runtime hardware-gated.
