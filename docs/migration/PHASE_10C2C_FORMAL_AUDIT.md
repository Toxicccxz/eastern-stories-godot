# Phase 10C2C — Formal Audit

Date: 2026-09-02. **FORMALLY CLOSED** after the corrections and validation below.
Branch: `phase/10c2-mobile-input-layout-lifecycle`.
Implementation audited: `3dcd96830ed8719e8f52833b97b2c1ad2159e6d2`;
closed B: `b622d7833917b6ac08a54d0f57ee1856fcb1742c`;
integrated main: `3a1f993a4258ed246ce820c7a4dc8d2563994aaf`.

Phase10C2 is ready for its **final major-phase audit**, not yet integrated on main.
No PR, merge, final mobile contract, or Phase10D implementation was created. Design authority
remains the Phase10C2 Analysis and the existing Application Shell / Native Save Load contracts.
No LPC/reference source was read or scanned for this application-policy audit.

## Concrete defects reproduced and corrected

| Defect | Independent failing probe | Narrow correction |
| --- | --- | --- |
| Stale deferred reactivation could publish input before the latest layout | Loss/gain with unchanged metrics queues completion; another loss/new-metrics/gain queues new reflow behind it. The published panel rectangle differed from the settled rectangle. | `ApplicationActivity` tags effective activity edges with a presentation revision. Shell completion rejects stale revisions; duplicates do not create new revisions. |
| Focus was still deferred when active interaction was published | At the successful `interaction_changed` observation, the highest surface did not yet own valid focus. | Shell reactivation renders/focuses the current surface synchronously before publishing. Ordinary state rendering retains deferred focus. |
| Detached safe-area presenter caused a null call and could leave reactivation stuck | Detach after loss, regain foreground/focus, then reenter without another OS event. Original code errored and did not restore observation/permission correctly. | Null-safe lookup keeps interaction blocked; the existing child's tree-entry signal retries measurement. No polling, new Timer, or independent lifecycle authority. |
| Inactive TouchAdapter consumed physical keys before Shell cleared the Input action cache | With mobile touch enabled, real `InputEventKey` RIGHT/ENTER/ESC left movement/accept/cancel/pause actions pressed while inactive. | TouchAdapter quarantines only raw inactive contacts; hardware events reach the existing Shell clearing/quarantine path. They remain blocked from UI/gameplay. |

Production edits are limited to `game/application/lifecycle/application_activity.gd`,
`game/runtime/application/application_shell_controller.gd`, and
`game/runtime/application/mobile_touch_adapter.gd`.
`game/tests/application/mobile_lifecycle_audit_test.gd` adds 14 adversarial assertions;
the existing 513 assertions remain. Existing model tests pass the explicit revision token;
both the C runner and canonical historical runner include the new probes.

Diagnosis used focused runs only. An initial audit test named the wrong layout child
(`ResponsiveLayout`, corrected to the actual `PresentationLayout`); that harness mistake
was not treated as a production defect. The four production failures above were then
isolated and verified before the single complete-suite attempt.

## Audit matrix and ownership conclusions

The numbers below correspond to the formal-audit request, not new requirements.

| Checks | Result and inspected boundary |
| --- | --- |
| 1–3: activity, adapter, notification ordering | PASS. One Shell-owned typed `ApplicationActivity`; foreground/focus facts derive one interaction permission. Android/iOS capability is explicit. `MobileLifecycleAdapter` translates the four notifications only. Both loss orders, both gain orders and duplicate notifications are tested; one effective loss/reactivation, no competing pause/resume booleans. |
| 4–6: immediate/exact freeze, no catch-up | PASS. Shell uses `SceneTree.paused` and the existing PAUSABLE Session boundary even when a normal Pause request would be rejected. Host/Shell stay ALWAYS. No staging DISABLED, destruction, eligibility manipulation or elapsed-wall-time simulation. |
| 7–9, 27–28: input and presentation | PASS after corrections. Loss cancels PAD/POINTER and quarantines held/new inactive contacts and hardware actions. Back/accept/cancel/pause/navigation cannot act. Current foreground/focus revision must finish fresh measurement/reflow, clear contacts, establish valid focus, then publish interaction. Unchanged metrics, rapid double gain/loss, newer loss and presenter detach/reentry are covered. |
| 10–14, 26: resume gate and surfaces | PASS. Interrupted PLAYING/start requires fresh explicit Resume; foreground alone leaves PAUSED. Gate is application coordination, not Session/save data. Already-paused contexts retain their normal Resume. Settings draft/origin, Result, confirmation and recovery selection are preserved; empty-Host menu surfaces stay empty. Quiet Pause information never claims a Save. |
| 15–18: pending Host work | PASS. New, Continue, BACKUP and TEMP independently cover completion-before-foreground and foreground-before-completion; one committed graph, empty staging and zero pre-gate physics frames. Failure uses existing Result, with no fallback New Game. Recovery keeps selected-source re-read semantics with no promotion. End tears down once and clears the now-meaningless gate. |
| 19–24: manual-save-only | PASS. Lifecycle has no Save request, eligibility, capture, repository call, retry or Save product mapping. An already-requested manual Save completes once; success, normal combat/action blocker and injected write failure retain existing outcomes/rollback in both orderings. No combat/busy cleanup manufactures eligibility. Actual Android canonical/bak/tmp bytes supplement coordinator/fake-file assertions. |
| 25, 35–36: durability | PASS on independent installed Android route below: save, move unsaved, background, force-stop, fresh empty Menu, Continue. Only the last completed manual Save is durable; no termination callback guarantee. |
| 29–30, 45: lifetimes | PASS. Existing 22-cycle tests retain touch/lifecycle identity and one listener; 22 adapter tree exit/reentries deliver once and ignore off-tree notifications. Added presenter reentry test confirms one viewport subscription and restarted observation. No retained Session, stuck actions, emulation drift or ObjectDB/resource warning in final Godot tests. |
| 31–37: Android runtime paths | PASS under the technical environment below, including Home, Cave/SouthExit, real simultaneous kernel contacts and held-PAD reverse landscape. Inactive Back delivery is tested deterministically; Back on the launcher is not falsely counted as delivery to the background app. |
| 38–40: artifact/evidence hygiene | PASS. Fresh pristine sanitizer validation is separate from an explicitly instrumented x86_64/gl_compatibility APK. Production package/ARM64/Mobile renderer/CI remain unchanged. No Vulkan or physical-device certification claim. |
| 41: iOS | Shared source/config PASS only. Capability includes iOS, Apple safe-area remains shared, sensor-landscape export retains both orientations, no Android gameplay fork. iOS runtime unavailable; unsigned Xcode build remains a final-PR CI gate, not claimed here. |
| 42–44: desktop/Shell/save contracts | PASS. Actual desktop test below plus targeted regressions. Host remains sole current Session pointer, explicit New/Continue/Recovery, paused manual Save, normal Return ordering and separate Settings. No GameSave/item/RNG schema, repository, eligibility or restore-transaction production edits. |
| 46–50: suite, scope, documents, qualification | PASS with the explicitly permitted hardware gaps. Full historical suite passed on its sole attempt; no Vine failure or assertion weakening. Only phase docs updated; no final mobile contract. Protected paths unchanged. |

Freeze assertions compare Session/map/camera identity, player/NPC positions and velocities,
life/resource state, combat relationships/guarding, busy state, item IDs, authoritative
Equipment/Armor identities and slots, allocator sequence, all three gameplay RNG seed/state
pairs, cadence and Timer time remaining. They run while movement/unsafe combat facts and
timers exist, not only in an empty Menu. Thirty-five inactive frames and repeated returns
preserve the measured facts; fresh Resume advances simulation without wall-clock catch-up.
These integration tests use explicit typed coordination timing and are not substituted for
the OS/player paths below.

## Independent runtime evidence

### Installed Android technical APK

Fresh export and install from the corrected tree. Pixel_9_API_35 AVD, x86_64/API35,
host GPU/OpenGL, disposable `--rendering-method gl_compatibility` override and ephemeral QA
signing. Package: `com.example.easternstoriesgodot.c2caudit`. Neither the original package
nor the preceding implementation's `.c2cvalidation` package was replaced/uninstalled.

The existing test observer was copied/autoloaded **after** fresh pristine sanitization and
validation. F9 observes identities/counters/file hashes; F8 supplies only the disclosed
pre-route Vine fixture. No Godot AI helper in this APK; runtime evidence is Android OS
delivery, current-PID observer logs and actual framebuffer screenshots, not a helper claim.

Artifact:
`build/phase10c2c-audit-technical-artifacts/android-technical-x86_64/Eastern-Stories-Godot-android-technical-x86_64.apk`.
Size **29,126,973 bytes**; SHA-256
`93d3c118a65a30fa47151a80ef27222a393f2c95c2a64fc96079cb77c2187695`.

| Real route | Independent audit observation |
| --- | --- |
| Touch New Game, PAD movement, OS Home, foreground, explicit Resume | PID **10264**, Session **161682032743**; position `(582.0002,300)` remains exact, same map/camera/items/allocator/RNGs/adapters. Returned PAUSED/gated, owners `-1`, movement zero. No save files or Save request/completion. Fresh Resume/movement works. |
| Already-paused Home; paused Settings and Return confirmation Home/Back | Same typed surface and Session; Settings Back returns Pause without Apply/Resume; confirmation Back cancels without teardown. No extra lifecycle Result. |
| Real Pause Save tap immediately followed by Home | Exactly one manual request/completion and honest success Result; remains paused. This does not force OS timing inside synchronous I/O; deterministic tests prove pending-operation boundaries separately. |
| Move unsaved, background, kill, new process, Continue | Manual position `(648.0006,300)`, later unsaved `(714.001,300)`. New PID **10753** first shows empty Menu, then Session **362119432641** restores the saved position. New-process Save counters zero; semantic IDs preserved. |
| Vine, Hold Vine, Cave movement, Home/foreground, explicit Resume, physical SouthExit | Pre-route F8 sets raw dodge100 and proximity only; no traversal/lifecycle callback or RNG replacement. Real touch selection/HUD enters Cave `(0,120)`, PAD moves to `(0,153)`; Home return freezes there. Fresh Resume and PAD into SouthExit returns Outdoor `(1200,780)`. One active map, correct camera, no Outdoor HUD in Cave. |
| Genuine simultaneous contacts, both orders | Emulator console emits `ABS_MT_SLOT`, `ABS_MT_TRACKING_ID`, position and SYN events; `getevent` confirms kernel delivery into Android/Godot. PAD-first owners **0/1**, POINTER-first **1/0**, both in PLAYING. Lifting the Pause contact cancels held PAD; final owners `-1`. Not a single swipe or direct callback. |
| Held PAD, Home, reverse-landscape sensor, foreground, fresh Resume/touch | Same Session/map/camera and inactive position `(1482.993,780)`; safe content `(87,16,1109,508)` changes to `(16,16,1109,508)`. Returned PAUSED with contacts empty; fresh Back/Resume and touch Pause work. Original orientation restored. |

Canonical SHA-256 after the only manual Save, through unsaved background and restart:
`e89db33843fc11afba6aed372cc81d24233d37a00dd402d7a37f6c3b5a15be50`.
`.bak`/`.tmp` remain absent. Cave/rotation keep Session **362119432641**, TouchAdapter
**154803373551** and LifecycleAdapter **154753041829**. Normal Vine changes world RNG from
`-7989997465983452938` to `1520011597774507997`; away time does not advance it.

Local ignored evidence: `build/phase10c2c-audit-android-evidence.jsonl`, corresponding
screenshots, `phase10c2c-audit-android-logcat.log`, `phase10c2c-audit-android-kernel-touch.log`,
and `phase10c2c-audit-android-{home,modal-save,restart,cave,multitouch,rotation}.log`.
The isolated audit app was force-stopped after validation; its data was retained.

### Pristine sanitized desktop and artifact separation

Fresh `build/verify-release-project` contains no observer, tests, QA, helper or remote-debug
configuration. It retains lifecycle/touch/SafeArea/canonical Shell. All **352** staged
production GDScripts byte-match the current source, both here and in the instrumented
Android stage. Only the latter adds the declared observer and technical export overrides.

Rendered canonical-main smoke passes **19** checks: real Viewport mouse/keyboard events
exercise Settings/Cancel/New Game/movement/Pause/Save/acknowledge/Resume, one Session and
normal desktop policy. An external driver in ignored build storage is not shipped.

A separate actual Windows-input run uses the computer-use skill against the pristine
sanitized project and isolated user storage. Mouse Settings changes Windowed **1152x648**
to visibly applied Fullscreen **2560x1440**; keyboard starts New Game. Native Alt-Tab emits
window focus-out/in with Session **192233343124**, PLAYING, tree unpaused, gate NORMAL and
touch hidden. A test-only external F8 injects a standard `InputEventJoypadButton` Start
press/release into normal input (not physical-controller qualification), which opens Pause.
Real mouse Save displays “Your journey was saved.”; keyboard acknowledgement and fresh
Resume return PLAYING with the same Session and NORMAL gate. Closed normally with Alt-F4.
Logs: `phase10c2c-audit-sanitized-smoke.log`, `phase10c2c-audit-desktop.log`.

An attempted Explorer activation timed out at the computer-use app approval boundary and
was not counted. Subsequent native Alt-Tab on the approved game supplied the focus evidence.
Neither sanitized run has Godot AI; helper health/stale-frame fields are not applicable.
The implementation's historical helper run is not misrepresented as a new audit run.

## Validation results

Pinned engine: **Godot 4.7.2.stable.official.ed1daf0bf**. Final production corrections
precede the focused, complete, Android and desktop passing runs.

| Invocation | Assertions/checks |
| --- | ---: |
| Phase10C2C | **527 PASS** (513 existing + 14 audit) |
| Phase10C2B | **221 PASS** |
| Phase10C2A | **3,597 PASS** |
| Phase10C2A consumers | **1,260 PASS** |
| Phase10C1C Shell | **1,267 PASS** |
| Phase10B4 Save | **1,091 PASS** |
| Phase9B3B1 Session | **4,049 PASS** |
| Focused invocation total (overlapping consumers, not unique cases) | **12,012 PASS** |
| Canonical complete historical suite, attempt 1 / only attempt | **14,886 PASS** |
| Python tooling | **46 PASS** |
| Rendered pristine sanitized smoke | **19 PASS** |

Canonical command:
`python tools/ci/verify.py --godot build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe`.
Exit **0**, final `Phase 10A verification PASS`, log
`build/phase10c2c-audit-complete-attempt1.log`. It includes repository/static checks,
development editor headless, fresh sanitizer, validate-only and sanitized editor headless.
No historical Vine flake occurred; no complete-suite rerun was needed. Focused logs use
`build/phase10c2c-audit-{focused,touch,layout,consumers,shell,save,session}.log`.

Final Godot tests/rendered desktop logs have no script errors or ObjectDB/resource/input
lifetime warnings. Android has one **“Failed to load cached shader, recompiling”** warning
followed by successful rendering/routes, and the exporter retains its themed-icon warning;
neither is classified as lifecycle/input leakage or ignored as a Godot AI vendor issue.
No Android script error/fatal was found. No production renderer change was justified.

`git diff --check` and changed-file trailing whitespace checks PASS. `reference/es2` and
`docs/migration/DECISIONS.md` modifications are **0**, relative to both the C baseline and
integrated main. No persistence production changes in C or this audit. Evidence, packages,
local SDK/signing paths and isolated user storage remain ignored/uncommitted.

## Remaining gates and final disposition

No open implementation blocker remains. Physical Android multitouch, ARM64 physical
runtime, production Android Vulkan runtime, and iPhone/iPad simulator/device runtime are
**not qualified** by this audit. The emulator OpenGL technical success establishes neither
Vulkan certification nor general Vulkan incompatibility. Those hardware gates remain for
later qualification; Phase10D itself was not started.

Commit/push stays on the same Phase10C2 branch. No PR or merge; no remote CI success claimed.
Final major-phase audit must own the lasting mobile contract, then final PR four-job CI,
authorized merge and post-merge main CI. No autosave, background-task reservation,
termination Save, dirty tracking, portrait gameplay, cloud/multiple slots, store signing,
permanent platform identity or unrelated gameplay work was introduced.

**PHASE 10C2C — FORMALLY CLOSED**

**PHASE 10C2 — READY FOR FINAL MAJOR-PHASE AUDIT**

**PHASE 10D — NOT STARTED**
