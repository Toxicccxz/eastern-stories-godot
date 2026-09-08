# Phase 10D3 — Post-Redesign Technical Demo Acceptance

## 1. Scope

Release-candidate acceptance, 2026-09-08. **IN PROGRESS; not acceptance PASS or Final Audit.**
No gameplay, balance, UI, world, progression, RNG or save implementation changes are authorized
by this record. Evidence below is from the immutable release artifacts, not an editor/QA scene.
Screenshots, logs, builds and disposable profiles remain ignored under `build/phase10d3-post/`.

## 2. Starting main / branch

- Starting green main: `0a5f0b49b6797c2a1280ef4198c2060b3cc61e34`.
- Fresh branch: `phase/10d-post-redesign-release-validation`.
- The old `phase/10d-technical-demo-release-gate` remains frozen historical evidence.
- Only pre-existing owner modification: `game/project.godot`, SHA-256
  `EFAEA1FA56EC0F6A7B391856C9EA7D5DBAA3CBA72348D7C53D5A3C55291CA16C`.
  It is preserved, not staged, and excluded from candidate construction.
- STATUS and ROADMAP current-state corrections are committed at `000d7b3`.

## 3. Prior failed candidate history

The historical Phase10D3 normal-player failure remains a failure. Historical 10D1 bounded device
qualification and 10D2 private packaging are not rewritten. Their records were inspected on the
frozen old branch, including `PHASE_10D_TECHNICAL_DEMO_RELEASE_GATE_ANALYSIS.md`,
`PHASE_10D1_PHYSICAL_DEVICE_QUALIFICATION.md`, `PHASE_10D2_TECHNICAL_DEMO_PACKAGING.md` and
`PHASE_10D3_COMBAT_PLAYABILITY_STABILIZATION.md`. This is a new post-redesign candidate.

## 4. Combat redesign integration baseline

CXR PR #8 merged at `7372d9d2ca3d796236ad64c2c6ad817a2508cb91`, all four main jobs passed in
[run 34186684857](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34186684857).
Independent Godot AI 4.0.1 tooling PR #9 subsequently merged at starting main above, all four jobs
passed in [run 34187852614](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34187852614).
The latter does not change the gameplay milestone. No PR or integration CI is claimed for this
new acceptance branch.

## 5. Candidate source SHA

**`000d7b383f1d508aab56e9dcd90273d4a9dd5b85`**. Production code is identical to starting main;
this commit only corrects STATUS/ROADMAP. Clean isolated local clone:
`build/phase10d3-post/source`. Both build manifests report this exact SHA and `dirty: false`.
Engine: **4.7.2.stable.official.ed1daf0bf**. No owner dirty configuration is part of the candidate.
Subsequent acceptance-document commits do not relabel these artifact hashes as a later source.

## 6. Windows artifact

Built with existing `tools/build/build.py --target windows --require-clean`, Windows release
export/template `windows_release_x86_64.exe`; timestamp `2026-09-08T05:09:35+00:00`.
Root of paths below: `build/phase10d3-post/`.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `candidate/Eastern-Stories-Godot-windows-x86_64.zip` | 39102004 | `40006E9FE96D847EFE6FE204945793EB8E09E7250B4BE95307921228444120A1` |
| `windows-extracted/Eastern-Stories-Godot.exe` | 109168640 | `3D19EE4A764E8BB153BFA7F811F98E0DFB0139C9E0C8BC6B76B93D3ED09185BF` |
| `windows-extracted/Eastern-Stories-Godot.pck` | 1275124 | `25384785653FDAA0B5791B113D24868E691313AC25F281091D11AACB7F1D8D08` |
| `windows-extracted/build-manifest.json` | 407 | `B146EEA9BE880C8B30440ADC2C142F23AD9A32797834590EDBF7CF3D0DCF19D8` |

Unsigned private technical candidate, not public/store release. Actual ZIP-extracted executable
launched as PID **56620**, without QA/debug arguments, using an initially absent isolated
`profile/Roaming` and `profile/Local` child-process environment. Owner daily saves are untouched.

## 7. Android artifact / device evidence

`candidate/android/Eastern-Stories-Godot-android-arm64.apk`, **27930518 bytes**, SHA-256
**`DDCE2E2229C9B08786F33826CF8CCDA03917EFC1A47913AC7ABAFEAF46FC9BD2`**.
Manifest SHA-256 `601761CED1AEF16F54E8E1DB7692D17D0FDFB71E1A563E7768188765FFD944B5`,
timestamp `2026-09-08T05:10:11+00:00`; release/ARM64, package
`com.example.easternstoriesgodot`, ephemeral QA signature, not production signing.

OnePlus 8T, Android 14; observed native **Vulkan 1.1.128 / Forward Mobile / Adreno 650**.
Owner explicitly authorized uninstall/replacement and clearing only this test package's saves.
Uninstall/install succeeded. Inputs below are Android OS touch/key injection on this physical
device, not direct game methods or evidence of new human multi-touch/comfort qualification.
No prepared saves, stat changes, teleports, deterministic RNG or QA hooks were used.

## 8. Fresh New Game journey

Android: `android-menu.png` proves cold Main Menu/no save; `android-world-ready.png` shows fresh
Old Pine, vitality 220/220/220. Actual direction-pad movement reaches scout aggression.
Windows: actual packaged Main Menu/no save and fresh world were observed through Computer Use.
The New Game click reported concurrent user input; the following world observation is valid,
but that click's exclusive causal attribution is not claimed. Windows full walking/combat route
remains pending: current Computer Use API supports instantaneous key chords, not sustained key
holds. Owner assistance was requested; a missing long-held input is not a gameplay defect.
Windows Escape/Pause -> Settings -> Fullscreen -> Apply was subsequently exercised using real
keyboard/mouse input. `windows-fullscreen-paused.png` shows the actual fullscreen packaged
window; isolated `settings/application-v1.cfg` contains `window_mode="fullscreen"`.
Fresh-process Settings persistence has not yet been claimed.

## 9. Combat / Flee / Victory

Android evidence, all normal production rules:

- `android-battle.png`: natural scout encounter, Flee visible, player 220/220/220.
- `android-flee.png`: normal Flee, `Escaped — see Details`; `android-away.png`: real movement away.
- Re-entry, automatic targeting/combat, Back/Pause: `android-pause.png`.
- `android-save-blocked.png`: combat Save correctly rejected.
- Home/background then launcher resume: `android-resume-gate.png`, explicit resume required;
  enemy 102/102/200 and player 220/220/220 remain unchanged across that paused observation.
- `android-natural.png`, `android-terminal.png`, `android-result.png`: automatic combat proceeds
  to natural **Victory**, player **200/200/220**. The intermediate enemy 0/0/200 is not itself
  classified as death; the later terminal result and corpse are the proof.
- Exact cycle count was not exposed/captured by these release observations. Wall-clock waits
  include pauses and are not substituted for cycles or old CXR observer counts.
- A stronger 220-vitality bandit encounter was reached naturally after the cliff-to-pine route;
  `android-pine-entry.png` and `android-strong-progress.png`. It also ended in natural **Victory**,
  player **89/89/220**, a new bandit corpse visible (`android-strong-result.png`). No healing,
  stat/equipment adjustment, action injection or balance edit preceded this result. The world
  was paused afterward (`android-strong-victory-paused.png`); that later victory is not Save A.

Windows battle/flee/victory still require the packaged-player route; Android does not substitute.

## 10. Corpse / Loot

Android `android-corpse-near.png` and `android-corpse-selected.png`: physically approached the
scout corpse, two items. `android-loot.png`: Open Loot exposes short sword and Take.
`android-taken.png`: short sword taken, one item remains (silver x3).
`android-loot-empty.png`: silver taken, corpse count zero. Inventory is genuinely opened and
scrolled; `android-inventory-scroll.png` shows silver x3 in player inventory.
Individual row scrolling/partial text clipping exists, but Take and Inventory remained usable;
not elevated to a gameplay blocker merely for presentation polish.

## 11. Save / Menu / Continue

Android: `android-safe-pause.png` -> actual Save -> `android-saved.png` (`Your journey was saved.`)
-> Return confirmation -> `android-saved-menu.png`. After real process death/cold launch,
`android-restored-world.png`: same corpse-relative position, vitality 200/200/220, no Battle
transient/selection. `android-restored-silver.png`: silver x3 retained. Normal movement works.
Windows full save journey pending; no Android claim is presented as Windows proof.

## 12. World traversal

Android genuine walking: restored scout area -> Central Clearing -> East Bridge -> select and
Inspect Vine -> close Details -> Hold vine -> **Waterfall**. Screens:
`android-east-bridge.png`, `android-vine-inspect.png`, `android-vine-waterfall.png`.
Pressing Hold while Details was open had no transition; closing the modal allowed the action.
From Waterfall, walking directly south meets the river water collision; walking around its east
edge reaches Riverbank 1. `android-river-gorge.png`, `android-river-east.png`, `android-cliff-entry.png`.
Normal Climb cliff -> Cliff1, physical approach -> Climb up -> Cliffside, physical north exit
entry -> Pine -> natural stronger NPC encounter (`android-cliff1.png`, `android-cliffside.png`,
`android-pine-entry.png`). No manually fired Area signal or location assignment.

Passage Cave/SouthExit remain **unproven**, not silently substituted by Waterfall/Cliff proof.
Read-only source confirmation: `game/core/world/vine_traversal_policy.gd` draws below effective
dodge, Waterfall for draw < 5. CXR9's default raw dodge 10 gives effective 5; a Cave route needs
natural progression beyond that boundary. No guaranteed RNG/prepared-save workaround is allowed
by this acceptance request. Windows representative traversal remains pending as well.

## 13. Fresh-process evidence

Android PID **8154**: fresh New Game -> natural Victory -> loot -> Save A -> Menu.
Force-stop verified no remaining package PID; launcher reports **COLD**, new PID **13744**.
`android-cold-ready.png` -> Continue restores A. Then real north movement to visibly different
unsaved position B (`android-unsaved-b.png`); no Save. Force-stop -> COLD PID **16777** -> Continue
restores A again (`android-restored-a.png`, same corpse-relative position and 200/200/220).
Thus unsaved B did not replace A. Neither process restart cleared package data.
Windows process-2 Continue remains pending.

## 14. Runtime errors

Android process-filtered Godot/AndroidRuntime log at PID13744 showed official engine/renderer
startup, no emitted error/crash in that inspected interval. A later PID16777 log query returned
no retained messages (`android-process3-runtime.log`); do not interpret an empty log ring as
proof that every historical frame was error-free. The observed journeys did not crash.
Windows packaged Godot log was empty; that alone does not prove every path error-free.
No game helper was expected in these sanitized release artifacts. Godot AI/helper health claims
from editor development are not used as packaged-game acceptance evidence.

## 15. Canonical tests

At the clean candidate clone, official Godot 4.7.2, existing `tools/ci/verify.py` completed once,
exit **0**. `build/phase10d3-post/verify.log`: **16152 assertions PASS, 0 failures**; Python
**46 tests PASS**. No rerun of the historical suite merely to accumulate green counts.

## 16. Repository/static/build validation

Same verify command: repository/static checks, development headless editor, release sanitizer
and sanitized headless project validation **PASS**. Windows and Android build commands using
`--require-clean` both exit **0**; logs `windows-build.log` and `android-build.log`.
Clean source remained clean; outer owner `project.godot` hash is unchanged. `git diff --check`
passes; `reference/es2` and `DECISIONS.md` change counts **0**. Production code changes **0**.
Final companion notice/manifest completeness and artifact exclusion inventory still to be
recorded. Root `THIRD_PARTY_NOTICES.md` retains an old Godot AI 3.2.4 heading although current
provenance correctly says 4.0.1; addon is excluded from both artifacts. Do not silently treat
the stale heading as current vendor version or claim public licensing clearance.

## 17. User-experience blockers

No confirmed new gameplay blocker in the paths completed so far. Required Windows sustained
input/journey evidence remains outstanding, separately from product correctness. Conditional
Cave/SouthExit qualification is unresolved under the no-cheat ordinary-player restriction.
If a genuine journey-blocking defect is demonstrated, stop and record
`PHASE10D3_GAMEPLAY_BLOCKER`; do not fix gameplay on this branch.

## 18. Deferred non-blockers

No iOS runtime claim (build CI is not device evidence). Public/store signing, releases, legal
clearance, final art/audio/VFX/localization/accessibility and expanded tutorial/content remain
deferred. Do not repeat all historical device tests or redesign inventory presentation.

## 19. Acceptance result

**IN PROGRESS — cannot claim PHASE10D3 PASS.** This is a resumable evidence checkpoint, not a
final acceptance decision. Remaining: Windows full packaged ordinary journey and restart,
required conditional traversal decision/evidence,
final package/notice/log checks. Preserve the candidate, screenshots and test profile for
continuation rather than rebuilding or restarting the successful Android journey.

## 20. Phase10D Final Audit readiness

**NOT READY / NOT STARTED.** No final PR, merge, public release or next content phase.
