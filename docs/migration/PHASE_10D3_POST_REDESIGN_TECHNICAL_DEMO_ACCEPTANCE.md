# Phase 10D3 — Post-Redesign Technical Demo Acceptance

## 1. Scope

Release-candidate acceptance, 2026-09-08.
**PASS — POST-REDESIGN TECHNICAL DEMO CRITICAL JOURNEY ACCEPTED.**
Evidence-review closeout under the owner's explicit scope decisions; not Phase10D Final Audit,
whole-project completion, public release, or store qualification.
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
but that click's exclusive causal attribution is not claimed. Windows walking uses owner
assistance because the current Computer Use API supports instantaneous key chords, not sustained
key holds. Subsequent actual combat, loot and cold Continue evidence is recorded below; a missing
tool-generated long-held input is not a gameplay defect.
Windows Escape/Pause -> Settings -> Fullscreen -> Apply was subsequently exercised using real
keyboard/mouse input. `windows-fullscreen-paused.png` shows the actual fullscreen packaged
window; isolated `settings/application-v1.cfg` contains `window_mode="fullscreen"`.
Cold process 21700 subsequently reopened fullscreen without applying Settings again; independent
application Settings persistence is now demonstrated together with the saved configuration.

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

Windows continuation: owner physically walked south and paused the natural scout encounter.
`windows-battle-paused.png`: player 200/200/220, scout 200/200/200, current target shown;
the visible log includes the scout's dodge/riposte for 20 damage. Actual Save was rejected
(`windows-unsafe-save.png`). Resume -> real Flee button returned to the world with `Escaped`
and the queued/started/resolved-disengaged feedback (`windows-flee.png`), player 200/200/220.
The owner confirmed walking away and returning. `windows-reentered-paused.png` independently
shows the re-entered paused encounter (player 178/178/220, scout 171/171/200). Resume allowed
automatic combat to reach natural **Victory**, player **127/127/220** (`windows-victory.png`).
Real mouse selection identified the corpse with **2 items**. Open Loot was disabled at the
initial distance; the owner physically approached and it became enabled, without bypassing range.

## 10. Corpse / Loot

Android `android-corpse-near.png` and `android-corpse-selected.png`: physically approached the
scout corpse, two items. `android-loot.png`: Open Loot exposes short sword and Take.
`android-taken.png`: short sword taken, one item remains (silver x3).
`android-loot-empty.png`: silver taken, corpse count zero. Inventory is genuinely opened and
scrolled; `android-inventory-scroll.png` shows silver x3 in player inventory.
Individual row scrolling/partial text clipping exists, but Take and Inventory remained usable;
not elevated to a gameplay blocker merely for presentation polish.

Windows: owner approach -> `windows-corpse-near.png`, Open Loot now enabled. Real Open Loot/Take
buttons transfer the short sword, then silver x3 (`windows-loot.png`, `windows-loot-empty.png`).
`windows-inventory-loot.png` simultaneously shows short sword, silver x3 and the existing primary
long sword. Actual Inspect opens the short sword's description/category/equipped/skill details.
No equipment was changed to manufacture the victory or loot evidence.

## 11. Save / Menu / Continue

Android: `android-safe-pause.png` -> actual Save -> `android-saved.png` (`Your journey was saved.`)
-> Return confirmation -> `android-saved-menu.png`. After real process death/cold launch,
`android-restored-world.png`: same corpse-relative position, vitality 200/200/220, no Battle
transient/selection. `android-restored-silver.png`: silver x3 retained. Normal movement works.
Windows: safe Pause -> Save displays `Your journey was saved.` (`windows-saved-a.png`) ->
confirmed Return to Main Menu (`windows-saved-menu.png`) -> normal Alt+F4 exit. Old PID56620 was
confirmed absent before launching the same EXE using the same isolated profile. New PID21700:
cold fullscreen Main Menu -> actual Continue -> same corpse-relative position and vitality
127/127/220, no Battle/selection/log transient (`windows-restored-a-p21700.png`). Actual Inventory
shows the same short sword, silver x3 and primary long sword (`windows-restored-inventory-p21700.png`).
No prepared/edited save or game/controller call was used. The owner subsequently walked north
to an independently observed, clearly different position B without saving; see process-death
evidence below. Thus post-restore physical movement is also demonstrated.

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

Additional Windows evidence was collected before the owner ended repeated traversal:
real Vine selection/Inspect/Hold -> Waterfall, owner walking along the east river bank ->
mountain-wall selection -> actual Climb cliff -> **Cliff 1**, vitality still 127/127/220.
Screens: `windows-vine-inspect-p49204.png`, `windows-vine-waterfall-p49204.png`,
`windows-mountain-wall-p49204.png`, `windows-cliff1-p49204.png`. The game was paused there.
No later Windows Climb Up/Pine completion is claimed or required merely for platform symmetry.

Passage Cave/SouthExit: **CONDITIONAL CAPABILITY — NOT PART OF CURRENT FRESH NEW GAME
TECHNICAL DEMO CRITICAL JOURNEY**. Not a blocker and not a fresh-player packaged Cave PASS.
Read-only source confirmation: `game/core/world/vine_traversal_policy.gd` draws below effective
dodge, Waterfall for draw < 5. CXR9's default raw dodge 10 gives effective 5; a Cave route needs
natural progression beyond that boundary. There is no established short, reliable normal-player
prerequisite path in this demo. The owner explicitly excludes it from the advertised route.
Implementation and existing automated/historical conditional evidence remain valid within their
original setup limits; future progression/content may expose it naturally. No starting-stat change,
guaranteed RNG, reroll-until-Cave or prepared-save workaround was used. Android's representative
world traversal and Windows' completed critical journey suffice under the closeout decision.

## 13. Fresh-process evidence

Android PID **8154**: fresh New Game -> natural Victory -> loot -> Save A -> Menu.
Force-stop verified no remaining package PID; launcher reports **COLD**, new PID **13744**.
`android-cold-ready.png` -> Continue restores A. Then real north movement to visibly different
unsaved position B (`android-unsaved-b.png`); no Save. Force-stop -> COLD PID **16777** -> Continue
restores A again (`android-restored-a.png`, same corpse-relative position and 200/200/220).
Thus unsaved B did not replace A. Neither process restart cleared package data.
Windows PID **56620**: fresh New Game -> owner walking -> Flee -> owner walk away/re-entry ->
natural Victory -> owner corpse approach -> real UI loot/Save A/Menu -> normal process exit.
Old PID absent -> cold process **21700** (2026-09-08 08:44:15 workstation local time) -> Main Menu
-> Continue -> A, inventory and fullscreen settings preserved.

Windows forced-process-death check: after the owner's unsaved northward walk,
`windows-unsaved-b-p21700.png` shows a different ancient-pine-relative position, not the saved
corpse position. The capture showed world rather than Pause, so an explicit real Escape input
established Pause before termination; the owner's reported paused state is not substituted for
the observation. The exact executable path of PID21700 was checked, then that process alone was
force-terminated and confirmed absent. Cold PID **49204** (08:57:01 workstation local time) ->
Main Menu -> real Continue restores the original corpse-relative A and vitality 127/127/220
(`windows-restored-a-after-kill-p49204.png`), not B. Save SHA-256 before/after termination remains
`330B8DBBED384C8CD79F0A611832E29350381D76FF58164C34873F739AD58310`.
This is process-death evidence, not a device power-loss/disk-durability claim.

## 14. Runtime errors

Android process-filtered Godot/AndroidRuntime log at PID13744 showed official engine/renderer
startup, no emitted error/crash in that inspected interval. A later PID16777 log query returned
no retained messages (recorded at the checkpoint as `android-process3-runtime.log`); do not interpret an empty log ring as
proof that every historical frame was error-free. The observed journeys did not crash.
At closeout that standalone Android log file is not present locally; the previously committed
process-filtered observation is retained as the evidence record, not claimed re-read from disk.
Windows PID56620's flushed log on normal exit contained official engine startup and
**D3D12 12_0 / Forward Mobile / NVIDIA GeForce RTX 4070 SUPER**, no emitted error. Current-process
log can be buffered/empty; that alone does not prove every path error-free. Completed Windows
combat/loot/Save/Menu/cold Continue observations did not crash or show a gameplay softlock.
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
Independent `apksigner` verification: one RSA-2048 signer, v2/v3 PASS; certificate SHA-256
`a7b09570126fc8ca8e6a2381877bf394db8d18c8cee1c779aa6f4877ecce0c4e`.
`aapt2`: only arm64-v8a, technical version 0.0.0-dev/code 1, minimum/target SDK 24/36.
It warns about an absent themed-icon resource; the application uses the existing icon.xml
and the exact APK installed/launched successfully. No new icon scope or public signing claim.

ZIP inventory is exactly EXE/PCK/manifest. APK paths contain no tests/QA/Godot AI/reference,
export presets, settings save or keystore; Windows PCK raw path-marker scan finds none of
Godot AI/reference/export presets/C:/Projects/C:/Users. This scan is not an exhaustive binary
security audit. Both artifact digests remain unchanged.

Revalidating post-export work directories reports absolute template paths in export_presets.cfg.
Source `tools/build/build.py` confirms sanitizer validation precedes intentional injection of
the local official template path; that configuration is not shipped. The unmodified sanitizer
evidence directory `source/build/verify-release-project` independently passes `--validate-only`,
digest `78f1365b409f2dca7c0f129bdd808a31e11a3dd80f199c6a7879568ac939e342` (existing digest helper,
excluding generated .godot only). No source or candidate repair was needed.

External companions now exist beside the artifacts: THIRD_PARTY_NOTICES.md,
LICENSE_PROVENANCE.md and technical-demo-candidate.json binding all sizes/digests/signing facts.
The stale root notice heading was corrected from Godot AI 3.2.4 to the verified 4.0.1. This
documentation-only correction does not change candidate bytes or claim public licensing clearance.
Native root license and ES2 attribution remain unresolved; private handoff requires the companions.

## 17. User-experience blockers

**NONE observed in the accepted critical journeys.** Neither completing the Android route again
on Windows nor exposing conditional Cave/SouthExit to a default player is a required gate under
the owner's closeout decision. No artifact identity mismatch, broken startup/movement/Flee,
combat softlock, inaccessible corpse/loot, failed Save/Continue, saved-data corruption or
release-blocking crash was found in the reviewed evidence. This is a bounded observation,
not proof of all possible frames, warnings, opponents or device combinations.

## 18. Deferred non-blockers

No iOS runtime claim (build CI is not device evidence). Public/store signing, releases, legal
clearance, final art/audio/VFX/localization/accessibility and expanded tutorial/content remain
deferred. Do not repeat all historical device tests or redesign inventory presentation.

## 19. Acceptance result

**PASS — POST-REDESIGN TECHNICAL DEMO CRITICAL JOURNEY ACCEPTED.**
The 2026-09-08 owner-approved closeout resolves the earlier checkpoint's pending scope questions;
it does not rewrite the old pre-redesign failure or invent unexecuted tests. Windows/Android
matrices below are an evidence review, not a new playthrough. Preserve the frozen artifacts.

## 20. Phase10D Final Audit readiness

**READY / NOT STARTED.** No final PR, merge, public release or next content phase.

## Acceptance closeout decision

- No additional owner manual interaction required; no game launch, replay, rebuild or full-suite
  rerun in this closeout. Existing observations in sections 8–14 support the accepted journey.
- Windows critical journey is sufficient: fresh play, natural combat/Flee/re-entry/Victory,
  corpse range, loot, Save/Menu/cold Continue and post-restore process-death recovery.
- Android physical OnePlus 8T / Android 14 / Vulkan / Forward Mobile / Adreno 650 evidence
  supplies representative world traversal and stronger natural combat. Its OS-injected inputs
  are not relabeled as new human multitouch qualification; historical bounded 10D1 remains separate.
- Cave/SouthExit is conditional/not advertised, not a blocker. No fresh-player Cave PASS claimed.
- Immutable source remains `000d7b383f1d508aab56e9dcd90273d4a9dd5b85`. Read-only closeout hashes
  match every Windows ZIP/EXE/PCK and Android APK value in sections 6–7. Both manifests still
  identify that clean source. All 53 screenshot filenames referenced by the prior checkpoint
  remain present; the four additional Windows route captures above are retained locally too.
- No production code changed during acceptance. Committed branch changes after the candidate
  are documentation/notices only; no candidate production/test/build source delta requires rerun.
  The owner-local Godot AI 4.0.2 upgrade (`plugin.cfg`, `utils/update_manager.gd`) and original
  `project.godot` are separately dirty, preserved and excluded from the candidate and this commit.
  This PASS neither qualifies that local plugin upgrade nor calls the entire working tree clean.
- Existing flushed Windows log was re-read: engine/renderer startup, no emitted production error.
  Android interval evidence is retained as described in section 14. No observed release-blocking
  defect/crash/softlock; exhaustive historical zero-warning proof is not required.
- **POST_REDESIGN_CANDIDATE_REFRESH = SATISFIED** by sections 5–7 and 15–16: clean-source builds,
  identity, manifests, sanitizer, inventory, signing facts and notices/provenance companions.
  Historical Phase10D2 remains historical PASS; no additional 10D2 slice or rebuild is needed.
- The external `technical-demo-candidate.json` was created at the earlier in-progress checkpoint;
  its scope text records that time, not a new source identity or today's closeout verdict.
  This committed document is the acceptance-status authority. Its artifact facts remain unchanged.
- The notice's 3.2.4 -> 4.0.1 heading correction matches integrated PR #9/candidate source.
  Local uncommitted 4.0.2 does not relabel candidate provenance. Root license/ES2 attribution remain
  unresolved publication boundaries, not a clearance claim or private engineering blocker.
- Closeout-only checks: `git diff --check` PASS; three edited documents have zero trailing-
  whitespace findings; all 57 referenced screenshots exist; both notice companion hashes match
  the candidate record; isolated candidate clone remains clean at the exact source above.
  Committed branch delta against main contains no game/test/build/CI changes; `reference/es2`
  and `DECISIONS.md` changes remain zero. The prior canonical 16,152 / Python 46 PASS is retained,
  not counted as a new run. Only this record, STATUS and ROADMAP are changed by closeout.

## Windows critical-journey review matrix

| Capability | Conclusion | Existing evidence |
| --- | --- | --- |
| Cold packaged startup | PASS | ZIP-extracted PID56620; cold PID21700/49204, sections 6/13 |
| Main Menu | PASS | No-save and saved/cold Menu observations, sections 8/11 |
| Fresh New Game | PASS | Fresh world observed; concurrent-input attribution limit retained, section 8 |
| Real physical movement | PASS | Owner walking into/out of aggression and to corpse, sections 9/10 |
| Natural Battle | PASS | `windows-battle-paused.png` |
| Save blocked during Battle | PASS | `windows-unsafe-save.png` |
| Real Flee | PASS | `windows-flee.png`, queued/started/resolved feedback |
| Return to same world | PASS | Flee returns to world; real walk away/re-entry, section 9 |
| Leave/re-enter aggression | PASS | `windows-reentered-paused.png` |
| Natural Victory | PASS | `windows-victory.png`, player 127/127/220 |
| Corpse range requirement | PASS | Disabled out of range; enabled after physical approach |
| Open Loot | PASS | `windows-loot.png` |
| Take short sword | PASS | Real Take, then one remaining item, section 10 |
| Take silver | PASS | Silver x3 taken, `windows-loot-empty.png` |
| Inventory retained | PASS | `windows-restored-inventory-p21700.png` |
| Save | PASS | `windows-saved-a.png` |
| Return Menu | PASS | `windows-saved-menu.png` |
| Cold Continue | PASS | `windows-restored-a-p21700.png` |
| No Battle transient after restore | PASS | No Battle/selection/log transient, section 11 |
| Settings fullscreen persistence | PASS | Fullscreen apply then fresh-process fullscreen, section 8 |
| Post-restore movement | PASS | Distinct unsaved B, `windows-unsaved-b-p21700.png` |
| Unsaved movement not persisted | PASS | `windows-restored-a-after-kill-p49204.png` |
| Forced process death recovery | PASS | PID21700 absent -> PID49204; unchanged Save A hash, section 13 |
| Runtime crash/softlock | NONE OBSERVED | Completed journeys and flushed log, section 14 |

## Android physical-journey review matrix

| Capability | Conclusion | Existing evidence |
| --- | --- | --- |
| Cold install/start | PASS | Approved physical APK install/cold Menu, sections 7/8 |
| Fresh New Game | PASS | `android-world-ready.png`, 220/220/220 |
| Physical touch movement | PASS | OS-injected touch on the named physical phone, sections 7–9 |
| Natural aggression | PASS | `android-battle.png` |
| Flee | PASS | `android-flee.png` |
| Real movement away | PASS | `android-away.png` |
| Re-entry | PASS | Re-entered encounter, `android-pause.png` |
| Back/Pause | PASS | Real Android Back, section 9 |
| Save blocked in combat | PASS | `android-save-blocked.png` |
| Home/background freeze | PASS | Unchanged observed combat values, `android-resume-gate.png` |
| Explicit Resume | PASS | Resume gate followed by natural combat continuation |
| Natural Victory | PASS | `android-result.png`, player 200/200/220 |
| Corpse | PASS | `android-corpse-near.png`, `android-corpse-selected.png` |
| Loot | PASS | Short sword/silver Take -> `android-loot-empty.png` |
| Inventory | PASS | Real open/scroll, `android-inventory-scroll.png` |
| Save/Menu | PASS | `android-saved.png`, `android-saved-menu.png` |
| Cold process Continue | PASS | COLD PID13744, `android-restored-world.png` |
| Unsaved movement discarded after process death | PASS | B -> COLD PID16777 -> A, section 13 |
| Vine | PASS | `android-vine-inspect.png`, actual Hold |
| Waterfall | PASS | `android-vine-waterfall.png` |
| River | PASS | Water collision/east-bank walking, `android-river-east.png` |
| Cliff | PASS | `android-cliff1.png`, `android-cliffside.png` |
| Pine | PASS | Physical north exit, `android-pine-entry.png` |
| Stronger natural combat | PASS | `android-strong-result.png`, Victory at 89/89/220 |
| Runtime crash | NONE OBSERVED | Completed physical journeys/process-filtered observation, section 14 |
