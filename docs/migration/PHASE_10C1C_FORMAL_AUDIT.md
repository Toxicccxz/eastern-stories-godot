# Phase 10C1C — Formal Audit

## Verdict and scope

**PHASE 10C1C — FORMALLY CLOSED.**
**PHASE 10C1 — READY FOR FINAL MAJOR-PHASE AUDIT.**

Audited implementation `00b89c0` on `phase/10c1-cross-platform-game-shell` against the
Phase 10C1 analysis (`37ada9b`), closed 10C1A (`073887e`) and 10C1B (`3a449be`), and
`docs/production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md`. No LPC scan was needed.
This is local subphase closure, not major-phase integration on `main`.

## Concrete corrections

1. Held-action clearing existed only on Pause/Resume and handled cancel input, not
   every Shell transition. New Game/Recovery completion and button-driven
   Settings/Result return could retain movement/accept/cancel/pause state. Clearing
   now occurs at the validated `_set_state` boundary, before exposing the new mode.
2. Clearing polling state alone did not suppress a subsequent OS keyboard repeat.
   An adversarial native `KEY_D` echo moved the new Player from `(450, 300)` to
   `(457.3333, 300)` without a new press. The Shell now remembers only actions held
   across a transition and suppresses their echoes until a release or fresh press.
   Ordinary continuous gameplay movement and fresh menu input are not suppressed.
3. Busy states rejected commands through their state guards but did not consume
   input before GUI dispatch. BOOT/STARTING_SESSION/SAVING now consume input and
   clear transition actions; deferred completion clears any intervening held state.
4. Opening this workstation's editor expanded the omitted keyboard device fields
   to `device=16`. The four accept/cancel keyboard entries now explicitly use
   portable all-device `-1`, as the other committed keyboard bindings already did.
   Editor-normalized serialization is retained; no local device ID is committed.
   Keys, controller A/B/Start mappings, and remote-debug 6107 are unchanged.

Production changes are limited to `application_shell_controller.gd` and
`project.godot`. No Host, save schema/repository, Session, world, character, item,
NPC, combat, or settings formula/authority was redesigned.

## Settings contract

- Snapshot v1 contains only Windowed/Fullscreen. Repository accepts exactly one
  `[application]` section with `schema_version` (integer 1) and `window_mode`
  (recognized string); malformed/extra/missing/wrong-type data is rejected.
  Unsupported versions and I/O failures have separate typed results.
- The fixed path is `user://settings/application-v1.cfg`. Gameplay remains under
  `user://save-data/<profile>/default-v1.json`. Neither schema includes the other.
  Sharing the narrow file-operation interface does not share persistence authority.
- `_ready()` loads/defaults and applies settings before constructing the manual Host,
  inspecting the game slot, or exposing Menu. Loading Settings creates no Session.
- Window APIs remain exclusively in `GodotWindowModeCapability`. Native desktop is
  editable; headless/embedded/platform-managed environments expose no fake control.
- Selection is uncommitted. Cancel does not apply/write. Failed runtime apply does
  not write. Successful apply plus failed write retains the effective runtime mode,
  keeps Settings open, and displays the explicit unsaved warning.
- Tests cover unsupported/corrupt settings with valid Continue, valid settings with
  corrupt canonical and valid Recovery, failed settings writes, and successful game
  Save preserving settings bytes exactly. The real Save route also compared bytes.

## State, focus, and input ownership

SETTINGS carries MAIN_MENU or PAUSED origin only. Pause-origin Apply and Cancel
return to PAUSED without unpausing. Tests compare the complete captured durable
Player/NPC/item/world/three-RNG snapshot, exact Session/allocator, a pausable Timer,
eligibility, and absence of new cadence/lifecycle work.

Each interactive surface has one deterministic primary and a closed focus cycle.
Hidden controls lose focus eligibility; disabled Continue/Recovery and unavailable
recovery sources are excluded. Settings tab navigation remains inside the modal.
Busy has no interactive focus; completion focuses the destination surface.
Result > Settings > Recovery > bare Pause precedence remains single-owner.
Generic cancel does not pause PLAYING, and Start cannot dismiss a higher modal.

Added adversarial tests cover all seven held actions at RESULT -> PAUSED,
SETTINGS -> PAUSED, PAUSED -> PLAYING, MAIN_MENU -> PLAYING, and RECOVERY -> PLAYING,
including input held during deferred Host work. Native keyboard-repeat tests prove
both suppression after transition and normal continuous movement after a fresh press.
Native D-pad/A/B/Start tests and portable config checks pass. Default D-pad/stick
directional bindings remain present. No physical gamepad hardware test is claimed.

## Independent live evidence

Godot `4.7.2.stable.steam.ed1daf0bf`, Godot AI `3.2.4`; isolated `APPDATA` under
`build/phase10c1c-audit-live-user` protected the developer's saves. Native game runs
reported `helper_live=true`, `session_active=true`, `game_capture_ready=true`, and
`current_run_errors=[]`. Captures were `stale_frame=false`, including native-window
frames 3801 and 12486 in their respective processes. In the recovery process,
consecutive observations advanced from frame 1381 to frame 7581.

### Window mode and capability

Real keyboard UI opened Settings and selected/applied Fullscreen. PID **40840**
reported DisplayServer mode **3**, size **2560x1440**, and persisted `fullscreen`.
Fresh PID **19748** reached Main Menu already fullscreen with committed setting 1,
one Host, zero Session, and zero staging. Real UI restored Windowed (mode 0).
An additional embedded run confirmed `editable=false`, hidden WindowModeRow/Apply,
and Cancel as primary focus.

### Coherent player route

- Cold Menu -> keyboard New Game: one Session, **12** bootstrap items; movement
  changed `(450, 300)` to approximately `(486.66656, 300)`.
- Escape -> Pause -> Settings -> Cancel -> Settings -> Apply -> Pause preserved
  exact Session and complete snapshot; QA evidence before/after was equal.
- Pause/Save succeeded, remained paused, and did not change Settings bytes.
  Resume/movement/second Save stored `(464.66663, 300)` with the first save as backup.
- Real `KEY_S` movement reached `(464.66663, 776.66754)` and authored bandit
  aggression. Pause/Save displayed the typed combat/action blocker (outcome 10).
  Canonical and backup SHA-256 were unchanged.
- Confirmed Return left one Host, zero Session/staging, and refreshed Continue.
  Real Continue restored one fresh Session (`1510654085421`, versus original
  `166446762128`) at the saved position; movement still worked.
- After another real walk into aggression, paused Settings Cancel/Apply preserved
  active cadence, exact QA state, and SaveEligibility. The running gameplay Timer
  remained exactly **0.693333333333334** seconds throughout.
- Native injected controller Start/D-pad/A/B/B produced modes
  `[PAUSED, PAUSED, PAUSED, SETTINGS, PAUSED, PLAYING]`. Held `D` across Settings
  dismissal/Resume followed by a native echo caused no movement for ten physics frames.

### Explicit recovery and repeated lifecycle

QA setup, before the claimed recovery path: copied the current valid canonical to
the fixed TEMP file and used the existing QA-only F7 corruption fixture. No
production callback or state jump was used to select a recovery outcome.

Fresh PID **41832** showed Continue disabled, Recovery enabled, zero Session.
Real UI exposed both candidates without selecting one. A framebuffer mouse click
selected BACKUP and restored `(486.66656, 300)`; a later Return/Menu/Recovery keyboard
route selected TEMP and restored `(464.66663, 300)`. The respective Session IDs were
`474526779908` and `760058219373`.

Hashes before/after both recoveries were identical:

| File | SHA-256 |
|---|---|
| corrupt canonical | `021FB596DB81E6D02BF3D2586EE3981FE519F275C0AC9CA76BBCF2EBB4097D96` |
| BACKUP | `ADC76B9FC7A547DFB9BF42FF50822BDA8B9B26FC207670D9C306F2EFC8040744` |
| TEMP | `D2C47F79282E3898386A53AB5F5254717B66EC216F3E5D47397479CF8B1B5BCF` |

No recovery promoted, rewrote, or deleted a file. Repetition retained one Shell,
one Host, 0..1 committed Session, empty staging outside restore, six shell surfaces,
one Settings button handler, and one Shell recovery handler. Save had the expected
two listeners (Shell plus existing development QA observer), not a duplicate Shell.

One initial QA `game_eval` snippet used space indentation conflicting with the
helper wrapper, causing a compile-error debugger stop. That process was discarded;
subsequent native and embedded runs reported no current-run errors. This was not a
production failure and is excluded from acceptance evidence.

## Release validation

A fresh `build/phase10c1c-audit-release-project` was prepared and scanned directly.
It contains all seven production settings scripts, native capability, Shell and its
six surfaces, Host, and production Save/Continue/Recovery paths. It contains no tests,
fake capability, QA bridge/fixture/startup configuration, Godot AI, remote-debug 6107,
or local absolute path in shipped source. Existing `.godot` editor-cache metadata
exemption remains limited to engine-generated non-shipped cache.

Sanitized headless editor and external canonical-main smoke passed. The external
smoke's **14 assertions** proved release profile, fixed Settings path, canonical
Shell, one Host/zero hidden Session, focus, native accept, and one New Game Session.
That test script is outside, never copied into, the sanitized project.

A separate normal process **31256**, with neither QA nor Godot AI, launched the
sanitized canonical main. Real Windows mouse input selected New Game; real Escape
opened Pause. Its stdout contained only normal engine/renderer startup and stderr
was empty, including shutdown. This is not a signed, exported, or store-build claim.

The original development editor environment and embedded-game option were restored.
The workstation's 6107 run argument was preserved, not reset or removed from source.

## Editor-only lifetime warning (explained, not hidden)

The interactive development **editor's** shutdown reported five leaked ObjectDB
instances and two retained resources. A fresh verbose editor (`41432`) repeated a
successful real Menu/Settings/New Game/Pause/Settings/Return route without any bad
QA eval, and reproduced the warning on editor exit. It is therefore not attributed
to the earlier QA compile mistake.

Verbose output identified exactly the two retained scripts:

- `res://addons/godot_ai/utils/server_version_check.gd`;
- `res://addons/godot_ai/utils/server_lifecycle.gd`.

The five objects are two RefCounted instances, their two GDScript resources, and one
GDScriptNativeClass. Read-only source inspection confirms the tool-side cycle:
`McpServerLifecycleManager._version_check = McpServerVersionCheckScript.new(self)`
and `McpServerVersionCheck._manager = manager`; `disarm()` clears `_connection` but
not `_manager`. No Shell, Settings, Host or Session resource was listed.

This is a specifically identified development-plugin lifetime defect, excluded
from the sanitized tree. It remains unfixed because changing the vendor plugin is
outside this audit. Focused/full gameplay tests, headless editors, sanitized smoke,
and the separate no-plugin real game all have empty stderr and no lifetime warning.
It does not mask a production Shell leak or require rerunning the historical suite.

## Automated validation and attempts

- Final focused 10C1C + consumer 10C1A/10C1B/10B/Session/Outdoor regressions:
  **1,267 assertions PASS**, including **228** 10C1C assertions.
- Canonical `res://tests/run_tests.gd`: **10,541 assertions PASS**, run **exactly once**
  after fixes stabilized. No complete-suite rerun was necessary.
- Python tooling: **41 tests PASS**; repository/static checks PASS.
- Development and sanitized Godot 4.7.2 headless editor: exit 0, empty stderr.
- Fresh sanitizer plus explicit validate-only before and after editor/smoke: PASS.
- Sanitized canonical-main smoke: **14 assertions PASS**.
- All final passing automated/gameplay runs had no ObjectDB leak or retained-resource
  warning. The interactive editor-only plugin exception is identified above.
  The prior test-only repository reentry cycle remains explicitly broken at teardown.
- `git diff --check` and changed-text trailing-whitespace checks: PASS.
- `reference/es2/` modifications: **0**; `DECISIONS.md` modifications: **0**.

Diagnosis used only focused runs: initial 32 failures comprised 28 missing transition
clears and four assertions assuming the engine's default device was 0 (on this build
it is 16). Tests were corrected to distinguish engine defaults from serialized IDs.
The next run isolated two real keyboard-echo failures, then passed 1,250 assertions.
Expanded freeze/busy coverage produced 1,267 assertions; one run correctly caught the
editor's reintroduced explicit device 16. Explicit portable -1 bindings resolved it.
The final focused and complete runs were clean. Failed diagnostic logs were not
misrepresented as acceptance passes.

## Closure boundary

No LPC, `DECISIONS.md`, STATUS/ROADMAP, or permanent Shell contract changed. GitHub's
open-PR search for this exact head branch returned zero matches; no PR was created.
No CI/merge/post-merge result is claimed. Phase 10C1 still needs its final
major-phase audit and later integration PR/CI/merge/post-merge gates.
Android Back, touch, safe areas, orientation, mobile lifecycle/autosave, in-game Load,
multiple slots, cloud save, localization, audio/quality settings, remapping, 10C2 and
10D remain deferred. No valid pre-existing work was discarded.
