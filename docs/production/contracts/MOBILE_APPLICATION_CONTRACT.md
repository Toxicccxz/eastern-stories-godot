# Mobile Application Contract

This contract extends the [Application Shell contract](APPLICATION_SHELL_CONTRACT.md),
not its ownership model. The [Native Save/Load contract](NATIVE_SAVE_LOAD_CONTRACT.md)
remains authoritative for eligibility, storage, recovery and restore transactions.

## Ownership

- The canonical shared ApplicationShell owns one persistent Runtime Host; only the Host
  owns zero or one committed Session. No separate mobile Shell, Host, Session or save repository exists.
- One Shell-lived TouchAdapter and one Shell-lived LifecycleAdapter survive map handoff,
  Session replacement and Return to Menu. Neither owns Player/gameplay state, snapshots,
  movement rules, navigation decisions or persistence operations.
- Shell owns semantic navigation, application pause/activity and the explicit Resume gate.
  Session owns gameplay, resident maps, bodies, cameras, timers and map HUD.

## Shared presentation and safe area

Use one responsive hierarchy with `canvas_items` / `expand`: desktop logical base 1152x648,
mobile feature override 960x540. Sensor landscape supports both landscape directions;
portrait gameplay, split-screen and platform multiwindow qualification are not promised.

`GodotSafeAreaCapability` is the production native measurement boundary; `SafeAreaMetrics`
normalizes physical content/safe bounds through the root viewport screen transform into
logical safe bounds. Shell layout, touch geometry and the active Outdoor HUD consume the
same Shell-lived SafeAreaPresenter. No device-offset table, per-control native safe-area
reader or Camera/world transform participates. Invalid measurement exposes a full-content
fallback, not a claim of verified native-safe bounds.

Qualified usable safe landscape size is at least 800x480 logical units. Smaller areas use
bounded scrolling/fallback without claiming full gameplay usability. Standard safe-content
padding is 16; touch-sized buttons are at least 64x64 with spacing at least 8, except the contiguous
pad cells. These logical units are not physical Android dp/iOS-point certification.
Dialogs, HUD and Inventory/Loot retain existing actions and typed signals; long content
wraps/scrolls and does not require hover. Modal barriers still cover the entire viewport.

Outdoor HUD belongs to the resident Outdoor map and disconnects/rebinds presentation on
handoff. Cave has shared movement/Pause controls but no transplanted Outdoor gameplay HUD.
Opening an item/detail panel blocks underlying input, not simulation or Save eligibility.

## Touch and desktop coexistence

- A fixed 192x192 pad has eight digital directions and a neutral center. It emits paired
  source-specific edges for the existing four movement actions; CharacterBody movement,
  speed, collision and action validation are unchanged. No analog speed or tap-to-move.
- One PAD owner and one POINTER owner may coexist. Extra held contacts are ignored until
  lift; owners cannot be stolen or promoted mid-gesture. Leaving the pad is neutral while
  retaining capture; only a fresh press can acquire a released/quarantined owner.
- Pointer input follows the normal Viewport/Control/world-picking route. GUI scrolling is
  native; cancelled/scrolling gestures cannot activate rows. World clicks commit only on
  uncancelled lift. No direct Button, traversal, combat or selection callback substitutes.
- TouchAdapter owns touch-to-mouse emulation only while enabled, restoring the previous
  setting on teardown. Physical mouse takeover cancels its synthetic pointer gesture;
  source-specific ordinary pad release does not release an independently held keyboard key.
- Shell transitions, metrics/reflow changes, map handoff, Session replacement, lifecycle
  interruption and adapter disable/exit cancel stale captures. Transition-wide cancellation
  intentionally clears/quarantines held movement and activation actions.
- Touch Pause emits `pause_game`. Existing keyboard/mouse/controller Shell semantics remain
  shared; touch UI is hidden on ordinary desktop. This does not add controller locomotion,
  remapping or physical-controller qualification.

## Android Back

One platform go-back notification emits the unbound semantic `system_back` intent. The
project disables automatic quit-on-back; no second key/polling path or desktop Escape
binding is added. Shell interprets the highest current owner:

| Context | One Back intent |
| --- | --- |
| Lifecycle inactive, blocking operation or pending Host request | Consume only; no quit, Resume, cancellation or new request. |
| Native popup | Close popup only. |
| Result/confirmation | Existing dismiss/cancel to typed origin; never confirm destructively. |
| Settings / Recovery choice | Existing Cancel; no Apply or source selection. |
| Bare Pause | Existing explicit Resume when interaction is allowed. |
| Playing with item/detail overlay | Close the top presentation overlay only. |
| Bare Playing | Pause the same Session. |
| Empty, idle Main Menu | Request application exit once. |

iOS gains no synthetic Android Back/exit button; visible controls remain available.

## Activity, freeze and explicit Resume

The LifecycleAdapter translates application pause/resume/focus-out/focus-in notifications
on Android/iOS only. A single Shell-owned `ApplicationActivity` records independent
foreground/focus facts plus presentation readiness and derives interaction permission.
Duplicates and either notification order must not duplicate effective transitions.

Effective loss blocks input, cancels PAD/POINTER, quarantines held actions and immediately
sets `SceneTree.paused`, even when ordinary user Pause is unavailable because Host work is
pending. Shell/Host remain ALWAYS; Session stays behind its existing PAUSABLE boundary.
Do not use restore-staging DISABLED, destroy Session, clear gameplay work or change
eligibility. The same graph/state/RNG/timer remainder remains frozen; no wall-clock catch-up.

Foreground and focus together initiate fresh safe-area measurement/reflow. Completion must
belong to the current activity revision; stale deferred work cannot reopen input. Clear
contacts/actions again, restore valid highest-surface focus, then publish interaction.
Missing presentation keeps input blocked until reentry can measure; unchanged metrics must
not deadlock. Inactive safe-area observation is suspended, not a second lifecycle policy.

**Foreground is not gameplay Resume.** Interrupted PLAYING or Session creation requires a
fresh explicit Resume, including normal fresh Back on bare Pause. Already-paused contexts
keep their existing semantics. Settings drafts, modal results and typed origins survive;
there is no repeated blocking lifecycle message. An empty Host may be temporarily tree-paused
while inactive; its ordinary foreground Menu contract returns without a meaningless Resume
gate. The gate is application coordination only and is never serialized or stored in Session.

Pending New Game, Continue and explicit BACKUP/TEMP recovery keep their existing transaction:
one successful interrupted commit is exposed PAUSED/gated with zero gameplay tick, whether
completion precedes or follows foreground. End Session may finish to exactly empty Host and
clear the gate. Lifecycle never restarts, cancels, duplicates or changes the source of Host work.

## Manual saves and independent settings

There is **no autosave**. Background/focus loss creates zero Save requests, eligibility
checks, captures, writes, backup rotations, temporary files or retries. Only an already-
requested Pause-menu Save may finish normally while interrupted; success/blocker/failure
keeps its existing honest typed result, never optimistic or relabelled as an autosave.

Same-process return retains unsaved memory. Cold start remains an empty Menu; explicit
Continue restores the last completed manual Save, not later unsaved progress. No termination
callback or reserved background time guarantees durability. BACKUP/TEMP remain explicit,
re-read selections with no automatic fallback/promotion or additional slot.

Application Settings remain separate at `user://settings/application-v1.cfg`. Windowed/
Fullscreen is desktop-capability-only and hidden on platform-managed mobile. No mobile
sensitivity, orientation, audio/graphics placeholder or autosave preference is introduced.

## Release and qualification boundary

Every target uses the shared sanitized production project, retaining Shell/Host, responsive
presentation, safe area, touch, Back/exit, lifecycle/gating, settings and native Save/Continue/
Recovery. Shipping output excludes tests/fakes/observers, QA, Godot AI, debug arguments,
developer paths and temporary emulator package/renderer/ABI overrides.

Normal Android remains ARM64 with the existing Mobile renderer and provisional signing/ID
policy; iOS uses the shared source/export path. Explicit Android-only x86_64 validation is
disposable staging, not a changed release default. See [BUILD](../BUILD.md).

Achieved runtime evidence is Android OS behavior on a Pixel_9_API_35 x86_64 AVD with host
OpenGL and a disposable `gl_compatibility`, isolated/instrumented technical package: touch,
Back, Home/foreground, explicit Resume, manual-save restart durability, Cave/SouthExit,
simultaneous kernel contacts and reverse landscape. Pristine sanitizer evidence is separate.

Physical Android multitouch, ARM64 device runtime, production Vulkan runtime and general
Android compatibility remain unqualified. iOS shares lifecycle/touch/Apple safe-area and
landscape source/configuration, but iPhone/iPad simulator/device runtime is unqualified.
Unsigned iOS Xcode compilation is a required integration CI gate, not iOS runtime proof.
Hardware qualification and permanent identity/store signing/packaging remain later release
gates; implemented mobile behavior is not hardware certification or store readiness.
