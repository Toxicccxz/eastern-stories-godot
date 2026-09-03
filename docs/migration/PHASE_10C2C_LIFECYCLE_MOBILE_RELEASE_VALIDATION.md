# Phase 10C2C — Mobile Lifecycle + Resume Gate + Mobile Release Validation

Implementation evidence, 2026-09-02. **READY FOR FORMAL AUDIT**, not formally closed.

Historical implementation record below. The subsequent
[Phase10C2C Formal Audit](PHASE_10C2C_FORMAL_AUDIT.md) closes this slice with four concrete
corrections: revision-bound presentation completion, synchronous focus before publishing
interaction, safe presenter detach/reentry, and inactive hardware action-cache clearing.
Audit validation is **527** C assertions / **12,012** focused invocation assertions,
**14,886** historical assertions on one complete attempt, Python **46**, sanitized smoke
**19**, plus independently rebuilt/installed Android and native desktop rechecks. These
supersede the gate status, not the historical implementation counts/artifact below.

Branch: `phase/10c2-mobile-input-layout-lifecycle`.
Parent: closed 10C2B `b622d7833917b6ac08a54d0f57ee1856fcb1742c`;
integrated main baseline: `3a1f993a4258ed246ce820c7a4dc8d2563994aaf`.
No PR/merge, final Phase10C2 contract, or Phase10D work belongs to this slice.
The Phase10C2 Analysis and existing Application Shell / Native Save Load contracts
remain authoritative. No LPC source was scanned or changed; no gameplay migration
decision or `DECISIONS.md` change was needed.

## Ownership and implementation

`ApplicationShell -> one persistent Runtime Host -> 0..1 committed Session` is unchanged.
Host is still the sole current-Session authority. No Host, Session, save repository,
GameSave schema, world authority, combat rule, or production renderer changed.

Production changes:

- `game/application/lifecycle/application_activity.gd`: Shell-owned typed activity facts,
  transition result, and resume gate. Foreground and focus are independent; interaction
  additionally waits for the existing presentation measurement/reflow boundary.
- `game/application/lifecycle/mobile_lifecycle_capability.gd`: Android **or** iOS capability;
  never inferred from window dimensions. Desktop behavior remains unchanged.
- `game/runtime/application/mobile_lifecycle_adapter.gd`: one ALWAYS-processing Node,
  translating Godot application PAUSED/RESUMED/FOCUS_OUT/FOCUS_IN notifications into typed
  events. No pause policy, Save, Session ownership, timer, or polling in the adapter.
- `game/runtime/application/application_shell_controller.gd`: activity ownership,
  immediate lifecycle freeze, inactive input guards, gated Host completion, and focus reset.
- `game/runtime/application/mobile_touch_adapter.gd`: current activity gate, inactive-contact
  quarantine, one connect/disconnect pair for Shell interaction changes. The adapter and
  its existing mouse-emulation ownership are retained across lifecycle changes.
- `game/presentation/layout/safe_area_presenter.gd`: stop observation while inactive;
  reset observation elapsed time and measure on reactivation using the existing capability.
- `game/scenes/application/application_shell.tscn`: one declaratively connected lifecycle
  adapter and a quiet wrapping informational label on the existing Pause surface.
- `tools/build/prepare_release_project.py`: require the three new production lifecycle
  scripts in the sanitized project.

Associated `.uid` files, focused tests/runner, historical-runner registration, sanitizer
unit tests, and this document complete the change. Registering the C test in the historical
runner does not mean the historical suite was executed during implementation.

## Transition and input policy

`ApplicationActivity.Change` is `NONE`, `INTERACTION_LOST`, or `REACTIVATING`.
`ResumeGate` is `NORMAL` or `EXPLICIT_AFTER_LIFECYCLE`. No additional generic operation
result hierarchy or scattered mobile navigation booleans were added.

On the first effective loss: update the typed facts; emit input-context cancellation
(paired PAD/POINTER releases); release/quarantine held transition actions; immediately
pause the SceneTree; stop safe-area observation; preserve modal state or change PLAYING
to PAUSED; publish the changed interaction gate. Duplicate notifications only update facts
and do not repeat the effective transition. Inactive touch, keyboard, Back, popup, and
public Shell navigation paths cannot act. Host and Shell remain ALWAYS operational;
the ordinary PAUSABLE SessionSlot remains the simulation boundary, not staging DISABLED.

An interrupted PLAYING or Session-start operation requires explicit Resume. Returning
both foreground and focus starts existing safe-area measurement/reflow, then a deferred
presentation completion resets contacts again and restores focus to the highest valid
surface. It does **not** unpause a gated Session. A fresh Resume, including the existing
fresh Back-to-Resume behavior on Pause, clears the gate. Stale contacts/actions cannot.

Already-paused Settings, Result, confirmation, drafts and origins retain their exact state;
no extra pause stack or blocking lifecycle Result is introduced. Already-paused contexts
need only their existing Resume. Empty Main Menu and menu-origin Settings/Result/Recovery
stay empty; successful foreground return restores their normal unpaused Menu contract.
An empty Host without a pending Session-start operation clears a meaningless gate.

Pause information, only while the explicit lifecycle gate applies:
“Paused while the app was away. Save manually before leaving to keep recent progress.”
It does not claim a Save occurred or repeatedly open a modal.

## Serialized operations and durability

| Existing operation | Lifecycle behavior / focused evidence |
| --- | --- |
| New Game | Deferred Host work continues; successful commit is PAUSED/gated; child physics probe sees zero ticks; failure preserves the normal Result and no phantom Session. |
| Continue, explicit BACKUP, explicit TEMP | Same transaction and selected source; no fallback, promotion, or restart. Both foreground-before-completion and completion-before-foreground commit one graph with empty staging and zero gameplay ticks. Re-read failures preserve normal failure semantics. |
| End Session | Removes the graph once; empty Host clears the gate, remains input-blocked while inactive, then returns to normal Menu. Both orderings tested. |
| Already-requested manual Save | Completes once through existing Host; success, combat/action blocker and injected write failure preserve existing typed outcomes and rollback. Both orderings tested; no optimistic success, cancellation, retry, or additional Save. |

The existing guarded user `request_pause()` still rejects pending Host requests.
Lifecycle freeze is a narrow internal path that pauses immediately even under that guard.
No production Save/capture/result-mapping code changed. Lifecycle does not request eligibility,
capture, repository work, backup rotation, temp creation, or retry. Background alone has
zero Save coordinator calls and zero file writes in focused tests. Existing actual file
hashes and absence of `.bak`/`.tmp` also remain unchanged in the Android route below.

No elapsed wall-clock absence is applied as simulation time. Tests retain player and NPC
positions/velocity/resources/life/busy state, relationships/guarding, item IDs, authoritative
Equipment/Armor objects, occupied armor slots, allocator sequence, all three RNG states,
active map, camera owner, cadence and Timer remaining time. Twenty-two lifecycle cycles
retain one adapter/subscription, stable emulation state, and no stuck input; twenty-two
adapter tree exit/reentries deliver once and ignore off-tree notifications. Recovery choice
and its unselected candidate bytes survive without hidden restore work.

## Focused validation

Godot **4.7.2.stable.official.ed1daf0bf**, isolated test storage. Final invocations:

| Runner / check | Result |
| --- | --- |
| `run_phase_10c2c_tests.gd` | **513 assertions PASS** |
| `run_phase_10c2b_tests.gd` | **221 assertions PASS** |
| `run_phase_10c2a_tests.gd` | **3,597 assertions PASS** |
| `run_phase_10c2a_tests.gd -- --consumers` | **1,260 assertions PASS** |
| `run_phase_10c1c_tests.gd` | **1,267 assertions PASS** |
| `run_phase_10b4_tests.gd` | **1,091 assertions PASS** |
| `run_phase_9b3b1_tests.gd` | **4,049 assertions PASS** |
| Focused invocation total (overlapping consumer coverage, not unique cases) | **11,998 assertions PASS** |
| Python tooling unit tests | **46 PASS** |
| Repository/static checks | PASS |
| Development editor headless; fresh sanitizer; validate-only; sanitized editor headless | PASS |
| Non-headless sanitized canonical-main desktop smoke | **19 checks PASS** |

The complete historical suite was deliberately **not run**; it belongs to Formal Audit.
The focused pending-operation tests explicitly control coordination timing, and the Cave
unit test calls the typed handoff boundary. Neither is presented as Android player-path proof.

Local ignored evidence: `build/phase10c2c-{lifecycle,touch,layout,consumers,shell,save,session}.log`,
`build/phase10c2c-tooling.log`, and `build/phase10c2c-rendered.log`. Tooling used
`tools/ci/verify.py --godot <4.7.2 executable> --skip-gameplay-tests`; the focused runners
were invoked separately. Sanitized rendered smoke used the actual ApplicationShell, native
mouse Settings/Cancel/New Game, keyboard movement, Pause, manual Save/acknowledgement/Resume;
same Session, normal desktop focus policy, touch hidden, no helper/tests in the stage.

### Real desktop injected mobile path

Godot AI canonical run **19**: `helper_live=true`, `session_active=true`,
`game_capture_ready=true`, `current_run_errors=[]`; non-stale captured frames advanced
**4304 -> 10122**. Real Viewport ScreenTouch drove New Game, PAD, paused Settings,
Cancel, Resume and subsequent movement. Mobile capability and notifications were injected
as an explicitly labelled desktop test fixture, not Android OS proof.
Session `312626645329` remained identical at `(486.666565, 300)` while away and returned
PAUSED with owners cleared; after fresh Resume/movement it reached `(523.333252, 300)`.
The real development run was stopped normally. No development Save was overwritten.

## Installed Android evidence

Environment: Pixel_9_API_35 AVD, API35 x86_64, host GPU; explicitly disposable
`gl_compatibility` technical release APK, not production ARM64/Vulkan qualification.
No Godot AI helper exists in this APK. A test-only observer from
`game/tests/application/mobile_lifecycle_observer.gd` was explicitly copied and autoloaded
**after** pristine stage sanitization/validation. F9 reports typed/runtime identities and
hashes; F8 is the disclosed pre-route Vine fixture below. The production scripts are unchanged.
Long evidence JSON is chunked to avoid Android logger truncation.

An isolated disposable package `com.example.easternstoriesgodot.c2cvalidation` protected the
existing `com.example.easternstoriesgodot` package and its data; the original package was
neither replaced nor removed. Temporary package/exporter expectations and QA signing were
only in ignored build tooling; no product package ID, signing material or paths were committed.

Artifact: `build/phase10c2c-technical-artifacts/android-technical-x86_64/Eastern-Stories-Godot-android-technical-x86_64.apk`.
Size **29,122,877 bytes**; SHA-256
`7f9243f961a30d5d8c377bf8b0b6bc68d87a352352cb2cfa295e6e5263965af5`.
This is an explicitly instrumented technical artifact, **not** a pristine production release.

| Actual input route | Observed result |
| --- | --- |
| Fresh launch -> touch New Game -> PAD -> Android Home -> wait -> foreground | Same PID **8147**, Session **161765918822**, map/camera/adapters/items/allocator/three RNG states and position `(582.0002, 300)`. Returned PAUSED, gate explicit, PAD/POINTER owners `-1`, movement zero. Canonical/bak/tmp all absent; zero Save requests/completions. |
| Fresh touch Resume -> movement -> Pause -> Home/foreground | Movement works after explicit Resume; already-paused return remains Pause without an extra lifecycle dialog/gate. |
| Paused Settings -> Home/foreground -> Android Back | Same Settings and frozen Session; Back returns to Pause, no Apply or Resume. Return-to-Menu confirmation also survives Home/foreground and Back cancels it without ending Session. |
| Real Pause Save tap immediately followed by Android Home | Exactly one manual request and completion; actual success Result “Your journey was saved.” on return; same paused Session. No scheduling manipulation forced pending timing; deterministic tests cover that boundary. |
| Move after Save -> Home/foreground without another Save | Unsaved position `(714.001, 300)` retained in memory, canonical bytes unchanged, no bak/tmp, count still one. |
| Force-stop isolated test app -> fresh launch -> real Continue | New PID **8617**, empty Menu before Continue; new Session **365407766977** restores last manual position `(648.0006, 300)`, **not** unsaved `(714.001, 300)`. Same semantic item IDs and canonical bytes; new-process Save counters zero. No termination-callback guarantee claimed. |

Canonical SHA-256 after the sole manual Save and through these lifecycle/kill/restore steps:
`46a573ac4346a05b9f2c25b6ca9bc6b619c91fdaaa40af59e56e62933ddb532e`.
`.bak` and `.tmp` remained absent. Actual OS notifications included FOCUS_OUT then PAUSED,
and FOCUS_IN then RESUMED. Tests separately cover both orders and duplicates.
Inactive Back is proved deterministically; OS Back while the launcher owns focus is not
claimed as delivery into the background game. Fresh foreground Back is exercised normally.

### Cave and physical SouthExit — PASS

Disclosed setup **before** the route: test observer sets player raw dodge to 100 and places
the player near the Vine. No traversal/lifecycle callback, successful result, RNG replacement,
or Save was injected. From there: actual touch Vine selection -> real Hold Vine HUD -> Cave
-> PAD movement `(0, 120)` to `(0, 153)` -> Home/foreground -> explicit touch Resume -> PAD
into the physical SouthExit Area -> Outdoor `(1200, 780)`.

Session **365407766977**, touch adapter **154803373551**, lifecycle adapter **154753041829**
persisted, with one active map and no Outdoor HUD in Cave. Cave position/camera/RNG/files
froze across background. Normal Vine world RNG changed once from `2385889627312465145`
to `5174851111437437284`, then remained unchanged while away. This closes the B slice's
pending **emulator** Cave player-route evidence, not a physical-device qualification gate.

### Android simultaneous contact delivery — PASS on this emulator

The strongest available input facility was Android emulator console `event send` with real
kernel `ABS_MT_SLOT`, `ABS_MT_TRACKING_ID`, position and SYN events, confirmed by `getevent`.
This is not a single adb swipe, direct Godot touch-handler call, or direct Pause activation.

- PAD first, Pause pointer second: simultaneous owners **PAD 0 / POINTER 1**.
- Pause pointer first, PAD second: simultaneous owners **PAD 1 / POINTER 0**.
- Release the Pause contact while PAD remains down: real Pause opens, PAD is cancelled;
  after lifts both owners are `-1`. Each final trial began in PLAYING.

Both orders pass Android OS-to-Godot delivery on the technical emulator; physical multitouch
hardware remains unqualified. The earlier B pending emulator-delivery row is now covered.

### Reverse landscape with held PAD — PASS on this emulator

Final trial verifies PLAYING and a live PAD owner, sends actual Home, releases contact,
changes the AVD acceleration sensor to reverse landscape, and foregrounds the app.
Session/map/camera/position `(1482.993, 780)` stay identical to the inactive observation;
returned PAUSED with owners cleared. Safe content changes from `(87,16,1109,508)` to
`(16,16,1109,508)`. Fresh Back/Resume and touch Pause work in the reversed layout.
The original sensor orientation and normal landscape safe content were restored afterward.
No physical sensor/device qualification is implied.

Android evidence lives in ignored `build/phase10c2c-android-evidence.jsonl`, screenshots,
`phase10c2c-android-logcat.log`, `phase10c2c-android-kernel-touch.log`, and the final route logs:
`phase10c2c-android-modal-save.log`, `phase10c2c-android-restart-final.log`,
`phase10c2c-android-cave.log`, `phase10c2c-android-multitouch-final.log`,
`phase10c2c-android-rotation-final.log`. No script error or AndroidRuntime fatal was found
in the final collected runtime log.

## Evidence hygiene, release boundary and deferrals

Intermediate harness problems were not accepted as production proof: an initial test preload
syntax error, comparing fresh read-only weapon projections by Object identity instead of
semantic ID/authoritative Equipment identity, truncated Android JSON, and an expected
isolated-package validation mismatch were corrected. A stale previous-PID restart observation
was rejected; final evidence requires the current PID and an observed empty fresh Menu.
An exploratory second multitouch trial and an early rotation trial started PAUSED and were
not counted for PLAYING/held-contact claims; the final trials check those preconditions.

Fresh sanitized production retains activity/capability/adapter, Shell, touch, Android Back,
SafeArea, native Save/Continue/Recovery, canonical ApplicationShell and sensor landscape.
It removes all tests (including the observer), QA, Godot AI, remote-debug and local tooling
material. The pristine sanitized rendered smoke is separate from the instrumented APK.
Normal ARM64, Mobile renderer, Windows export, iOS export and CI configuration are unchanged.
Existing iOS landscape-left/right export checks passed with the Python tooling tests.

iOS shares the Android/iOS lifecycle capability and existing Apple safe-area path; there is
no Android-only gameplay fork. This Windows workstation provides **no iOS simulator/device
runtime evidence**. Unsigned iOS export/Xcode compile and all four normal platform CI jobs
remain required at the final PR gate; no remote CI success is claimed for this unmerged slice.
Production ARM64/Vulkan and physical Android/iOS touch/lifecycle qualification remain future
hardware gates. The known AVD Vulkan limitation did not justify changing product rendering.

Implementation completion checks: focused validation above, `git diff --check` and changed-file
trailing whitespace PASS; `reference/es2` changes **0**, `DECISIONS.md` changes **0**.
Commit/push is confined to this major-phase branch. No PR or merge; not integrated on main.

Deferred: C Formal Audit with the complete historical suite; final Phase10C2 integration audit,
contract, PR/CI/merge/post-merge gate; hardware qualification. No autosave, background task
reservation, termination Save, dirty tracking, additional slots, in-game Load, cloud save,
portrait gameplay, store IDs/signing/upload, analog locomotion, gameplay/content changes,
or Phase10D implementation was introduced.
