# Phase 10C2A — Formal Audit

## Verdict and baseline

**PHASE 10C2A — FORMALLY CLOSED. PHASE 10C2B — SAFE TO BEGIN; NOT STARTED.**

Audit date: 2026-09-02. Reviewed implementation `7c3fd5e44ac06680f2987c9a25302947c9c3be0b`,
analysis `5508e59`, and integrated main `3a1f993a4258ed246ce820c7a4dc8d2563994aaf`.
All corrections remain on `phase/10c2-mobile-input-layout-lifecycle`. This is a local subphase
closure, not completion/integration of major Phase10C2. No PR, merge, or remote CI claim.

Authorities read: root/docs AGENTS, [10C2 analysis](PHASE_10C2_MOBILE_INPUT_LAYOUT_LIFECYCLE_ANALYSIS.md),
[implementation record](PHASE_10C2A_MOBILE_PRESENTATION_FOUNDATION.md),
[Shell contract](../production/contracts/APPLICATION_SHELL_CONTRACT.md),
[Save contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md), and repository policy.
Inspected the complete implementation diff, production adapters/consumers, focused tests,
affected historical tests, sanitizer and its tests. No LPC/reference scan was performed.

## Concrete findings and corrections

| Finding | Narrow correction and regression evidence |
|---|---|
| Finite Rect2 components can still produce an infinite or unrepresentable endpoint; direct construction bypassed normalization. | `safe_area_metrics.gd` now validates endpoints/representable positive extents, defensively clips constructor input, and exposes fallback. Adversarial finite-extreme, NaN/INF and invalid-constructor checks pass. |
| The absolute determinant epsilon rejected a valid small-scale transform and silently discarded actual insets. | Reject zero/nonfinite determinant and nonfinite inverse/transformed bounds, not an arbitrary small nonzero determinant. Scale 0.0001 with translation correctly recovers independently specified inset bounds. |
| Reparenting authored Controls through unowned runtime wrappers cleared scene ownership/unique-name lookup. Existing controller pointers happened to survive. | `ResponsivePanelLayout.reparent_content()` captures/restores existing owners across the same-scene move; Shell/HUD wrappers and HUD action/info moves use it. Original action/info object, unique-name lookup and signal counts survive repeated reflow. No duplicate authored controls or scene owner is invented. |
| Closing/removing dynamic rows left freed Control keys in typography/minimum caches until another metrics update. | Prune removed/freed controls on restyling and deferred layout; visibility changes restyle. Deferred pruning is required because panel hide precedes row removal. Repeated 12-row open/update/close cycles leave no freed keys or live old row instances. |
| Resident Outdoor HUD stayed subscribed while detached in Cave; a detached standalone Presenter retained the Viewport subscription. | HUD explicitly disconnects/nulls its provider on tree exit, reconnects once and consumes current metrics on reentry. Presenter connects/measures on entry and disconnects on exit. Repeated handoff and standalone detach/reentry tests pass. |

Only four production files changed in this audit: `safe_area_metrics.gd`,
`safe_area_presenter.gd`, `responsive_panel_layout.gd`, and `oldpine_hud_layout.gd`, all under
`game/presentation/layout/`. Added `game/tests/presentation/mobile_presentation_audit_test.gd`
(and UID), registered it in the focused/canonical runners, and updated these two phase records.
No Shell navigation, gameplay authority, scene configuration, settings/save behavior or physics fix.

## Safe-area and pinned engine findings

`GodotSafeAreaCapability` remains the only production native safe-area reader. Desktop/headless
uses the logical viewport; Android/iOS uses native safe bounds and the root Viewport screen
transform. Consumers only receive typed metrics. No Autoload, Session reference or global cache.
Metrics expose value-copy Rect2 getters, no collection/setter; private-by-convention backing fields
are not written by consumers. Direct construction is now defensive as well as normalization.

The production relationship is still `inverse(T) * intersection(C, S)`, then intersection with V.
Uniform scale, translated/letterboxed content, already-inset content, asymmetric/clipped/disjoint
bounds and invalid transforms were checked. Endpoints as well as components remain finite and
inside the validated viewport. Invalid viewport falls back to positive 1x1; invalid measurement
falls back to full V with a fallback indicator, **not** a claim of proven native-safe bounds.
The current production window transform is axis-aligned content/stretch; this is not an arbitrary
rotated UI/Camera2D safe-polygon implementation.

Pinned Godot **4.7.2-stable** sources independently checked:

- [Android GodotIO.getDisplaySafeArea](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/GodotIO.java#L203)
  selects the decor/render view and accounts for immersive/edge-to-edge versus already-padded
  content. Insets are relative to that drawable window; already applied padding is not subtracted
  again. Missing inset data can yield an empty measurement, handled by fallback. The Android
  display adapter uses one main window/screen with zero origin.
- [Apple embedded display adapter](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/apple_embedded/display_server_apple_embedded.mm#L449)
  scales UIKit safeAreaInsets and rendering-layer bounds into display pixels; screen origin is
  zero. The current root-window adapter assumption matches this implementation. Multiwindow,
  arbitrary embedded SubViewport and physical Stage Manager qualification are not claimed.
- [Window transforms](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/window.cpp#L3004)
  compose window/stretch/global-canvas transforms and screen placement. Camera2D's per-world
  canvas transform is separate; the production layout does not consult the world camera.
- [ProjectSettings feature resolution](https://github.com/godotengine/godot/blob/4.7.2-stable/core/config/project_settings.cpp#L297)
  and actual `get_setting_with_override_and_custom_features()` tests confirm Android+mobile,
  iOS+mobile and mobile resolve 960x540; Windows+pc/actual desktop retain 1152x648. This is an
  engine resolver test, not textual inference from plausible `.mobile` keys.
  [Android](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/os_android.cpp#L838)
  and [Apple embedded](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/apple_embedded/os_apple_embedded.mm#L701)
  advertise the mobile feature; startup uses the override-aware settings.
- Native `DisplayServer.SCREEN_SENSOR_LANDSCAPE == 4` is asserted. The shared project keeps
  canvas_items/expand and orientation 4. The
  [Android exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp#L1161)
  consumes that orientation setting; the
  [Apple exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform_apple_embedded.cpp#L511)
  emits both landscape directions for iPhone/iPad. No conflicting portrait export override was
  found. No installed Android, iOS device, rotation or portrait gameplay acceptance is claimed.

These engine observations describe platform presentation, not LPC gameplay policy.

## Architecture, lifetime and presentation matrix

| Audit area | Result |
|---|---|
| Authority | ApplicationShell -> one persistent Runtime Host -> 0..1 Session unchanged. Layout stores Controls/metrics only. No gameplay/persistence/selection authority moves. |
| Sampling | Entry and Viewport resize measure immediately; 0.249 then 0.002 test crosses the 0.25-second interval. Equivalent metrics do not emit/reflow. No Timer. One pending layout is coalesced; deferred reveal checks current live panel/current focus. |
| Pause/Settings | PROCESS_MODE_ALWAYS observes presentation while gameplay remains paused. It does not add background/foreground policy, change SaveEligibility, synthesize input or advance the Session. OS lifecycle remains 10C2C. |
| Six Shell surfaces | Main Menu, Pause, Settings, Recovery, Result/confirmation and Busy preserve full-viewport barriers. Safe inner panels wrap/scroll; visible primary/Cancel remain reachable. Hidden/disabled Continue/Recovery/Window Mode remain excluded by existing Shell focus policy. Busy has no invented action. |
| Reflow and focus | Wide/compact/wide, modal metrics updates and repeated rows preserve state/origin/Session and existing focus. Owner restoration preserves unique names; controller references, metadata/IDs and signals stay on original objects. Current scenes have no custom ancestor theme lost through the wrappers. Visibility, process mode and mouse barriers stay authoritative at existing controls. |
| Breakpoints | Width <1100 OR height <640 is compact; exact1100x640 is wide. Qualification is separately >=800x480. Fractional values just below all four boundaries are tested. |
| Targets | Normal padding16, gap8, mobile/compact targets >=64x64, body/actions >=20; desktop originals are restored. Tiny rectangles reduce padding without negative/inverted bounds, remain unqualified and scroll rather than shrink mobile targets to force qualification. |
| Wide HUD | 1152x648/1920x1080 retain Player/Target, Inspect, Attack, Traverse, Open Loot, Inventory, inspection/log and item panels. Existing button instances and handler counts remain unchanged. |
| Compact HUD | 960x540 and qualified800x480 keep two vitals columns, every existing action, Details with inspection/log, lower-left192x192 and top-right64x64 reservations. Reservations are geometry only. |
| Inventory/Loot | Current projections, item IDs, Inspect/Wield/Unwield/Wear/Remove and Take/Close remain owned by existing systems. Long labels/descriptions, 12 rows, repeated close/open/update, Take removal and resize are covered. Inline loot description is not hover-only. Opaque panels do not pause Session. Touch ownership is not implemented. |
| Map lifetime | Three typed Outdoor/Cave roundtrips preserve HUD identity, remove/re-add one current subscriber, use latest metrics and keep Cave HUD-free. Session teardown returns to only Shell consumers. An additional actual-input roundtrip passed (below). |
| World boundary | No movement speed, CharacterBody, Camera ownership, authored geometry, Areas, portal semantics, combat or RNG implementation changed. |

No unbounded wrapper/ScrollContainer growth, duplicate signal, freed-control access or unexplained
ObjectDB/resource warning occurred in the final passing automated/sanitized runs. The pre-existing
Godot AI editor-only 5-object/2-resource exception is not used to excuse any presentation leak.

## Test-quality and historical corrections

The original 2609 layout assertions are retained. The additional **988** check adversarial
normalization, real feature resolution, sampler timing, API value isolation, per-surface state/
focus/identity, exact once-only metrics emission, stable node/scroll counts across reflows,
dynamic row cleanup, authored action-label bounds and resident lifetime. Geometry checks favor
enclosure, finite endpoints, minimum sizing and reachability; exact values are used for the
specified breakpoints, reservations and independently computed intersections.

The five historical `225` checks were broader aggregate hierarchy guards, not literally tests
only of ResetButton removal: earlier scene additions changed their expected counts, and 10C1A
subtracted Reset. Their replacement correctly preserves Reset absence but alone does not preserve
the entire graph guard. This audit adds semantic coverage for the changed graph: one current HUD
subscriber, original action/info identities, one handler per dynamic action, stable node/scroll
counts through repeated reflow, exact row counts, and no Cave HUD. Existing world tests continue
checking specific map/spawn/collision/portal structures. A brittle frozen total is not restored.
No historical Vine assertion was changed; it did not fail in the complete run.

## Actual runtime evidence

All player-visible paths below use actual Controls/native InputEvents via
`Input.parse_input_event`, framebuffer mouse input or Windows computer-use. No direct layout,
button callback, traversal method or manually emitted Area signal substitutes for player proof.
Injected safe metrics are **presentation QA inputs**, not real mobile device measurements.

1. Canonical helper run #8: desktop1152x648 Main Menu -> New Game -> Outdoor/all HUD actions;
   real corpse selection -> Open Loot -> Take (rows2->1) -> Close -> Inventory -> Inspect.
   A test fixture prepared the corpse/player proximity before the claimed UI route and restored
   the normal combat RNG before input. This proves loot UI, not an end-to-end combat/death route.
2. The same live route used logical960x540 and asymmetric safe(48,0,912,516). Real keyboard
   Pause -> Settings preserved Session `293181852126`, tree paused and Session not processing.
   Metrics changed while Settings/confirmation remained open: safe800x480 qualified, safe480x320
   unqualified; visible Confirm/Cancel and wrapped scroll content remained usable. Actual Confirm
   returned to Menu; actual keyboard navigation opened menu Settings with no Session.
   Healthy captures advanced through frames4974,8408,16410,20299,23630 with stale_frame=false.
3. Final clean helper run #10 (`r36523262-10`): QA setup supplied raw dodge12, typed scripted
   World RNG draw5 and a position near Vine **before** the route. Actual Vine click -> Hold vine
   entered Cave, then actual move_down drove CharacterBody through SouthExit back to Outdoor.
   Original World RNG was restored after the branch. Session `290950482398` remained identical;
   active-map child count stayed1; consumers went2->1->2; Cave HUD count0. Healthy captures
   frames2144->3394->4778->6244 advanced, all non-stale. Final helper_live/session_active/
   game_capture_ready=true, current_run_errors=[]. Games were stopped after validation.
4. Fresh **sanitized** project, no QA/helper/debug, isolated application data: Windows input
   opened Main Menu Settings at actual1152x648, selected Fullscreen and Apply. A fresh process
   visibly preserved Fullscreen (2560x1440 display) and showed Fullscreen in Settings. Real UI
   restored Windowed at actual1920x1080, then Enter started New Game and mouse opened Inventory.
   All existing wide HUD actions and opaque item panel/Close were visible and usable. Both
   standalone process logs contain no errors or leak warnings. The isolated preference was
   restored to Windowed; the user's normal settings were not overwritten.

Historical implementation scratch compile/CountingCombatRandomSource recorder failures were
confirmed QA-only, not production defects. This audit also had discarded scratch errors: mixed
indentation, using nonexistent `corpse_id()` / `set_skill()` names, and passing an untyped Array
to a typed test RNG constructor. A later optional scratch failure in run#8 does not invalidate its
earlier healthy recorded UI segment, but its broken/stale frames are excluded. Corrected final
run#10 has no runtime errors. No QA suppression/infrastructure fix was made to erase this history.

## Verification ledger

Pinned local Godot4.7.2; isolated user data. Local logs/artifacts are ignored under `build/`.

| Command / evidence | Final result |
|---|---|
| `res://tests/run_phase_10c2a_tests.gd` | **3597 PASS** (2609 original +988 audit) |
| Same runner `-- --consumers` | **1260 PASS**, 10C1B + Inventory/Loot/equipment/authored consumers |
| `res://tests/run_phase_10c1c_tests.gd` | **1267 PASS**, includes 10C1A/10C1C consumers |
| Focused aggregate | **6124 assertions PASS** |
| Canonical `res://tests/run_tests.gd` | **14138 assertions PASS**, exactly one complete attempt after fixes stabilized |
| Python tools unittest discovery | **42 tests PASS**, including 11 sanitizer tests |
| `tools/ci/repository_checks.py` | PASS |
| Development Godot4.7.2 headless editor | PASS |
| Fresh `prepare_release_project.py`, then `--validate-only` | PASS |
| Sanitized Godot4.7.2 headless editor | PASS |
| External sanitized canonical-main smoke driver | **12 checks PASS**; not part of the historical count |
| Real sanitized canonical UI | PASS, Windows input/window capture described above |
| `git diff --check`, changed-text trailing whitespace | PASS |
| `reference/es2`, `docs/migration/DECISIONS.md` | **0 changed paths**, compared with integrated main and audit start |

Complete-run evidence: `build/phase10c2a-audit-complete-attempt1.log` ends
`PASS: 14138 assertions`; no ERROR/SCRIPT ERROR/FAIL/leak lines. It was **not rerun**. Focused
diagnosis first exposed the listed defects; the intermediate cache-only run explained the hide/
remove ordering, then final focused and complete runs passed without warnings.

Sanitizer preserves all seven production safe/layout paths, Shell/HUD changes, mobile dimensions,
canvas_items/expand and landscape configuration. Tests/fake capability, QA, Godot AI, remote-debug
arguments and local paths are removed. The external smoke driver (outside staged res://) loads
the configured canonical main, confirms one empty menu Host, production metrics, absent tests/
helper/debug, and native Enter New Game -> attached Outdoor HUD/layout/original action identity.
It supplements, not replaces, the actual sanitized Windows route. This is not an exported APK/
IPA or installed-device claim.

## Remaining boundaries

No outstanding 10C2A blocker. 10C2B touch ownership/multitouch/D-pad/touch Pause and 10C2C Android
Back/lifecycle/resume gates/installed-runtime orientation remain unimplemented. No autosave,
background Save, new permanent identifier, iOS runtime/signing or Phase10D work. Below800x480
is graceful degradation, not gameplay/touch qualification. Multiwindow platform qualification
remains outside the current root-window design.

No permanent 10C2 production contract or ROADMAP advance is made here. Major Phase10C2 still
requires its remaining slices, final integration audit, one PR, four green PR jobs, authorized
merge and green post-merge main CI.
