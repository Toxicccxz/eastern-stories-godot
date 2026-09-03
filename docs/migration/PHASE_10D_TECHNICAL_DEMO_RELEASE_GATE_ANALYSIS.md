# Phase 10D — Technical Demo Release Gate Analysis

**ANALYSIS COMPLETE — proposal for approval; 10D1 NOT STARTED.** Date: 2026-09-03.

## 1. Baseline, authority and product boundary

Integrated main is `ae381bf3f3e5f4a28a417295eea680d023cc428c`: Phase10C2 PR #6 plus
resident-map contact stabilization PR #7. Independently verified remote main and
[post-merge workflow 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002):
push event, exact SHA, completed/success, all four required jobs successful.
The clean planning branch `phase/10d-technical-demo-release-gate` starts at that commit.
One major-phase branch, subordinate slices/audits on it, one final integration PR later.
This task creates no PR and runs no gameplay tests, builds or new device acceptance.

Phase10C2 is **FULLY INTEGRATED**; its unresolved physical-device qualification is not
an unfinished code integration. The former Area flake was a production world-runtime
notification defect, not demonstrated mobile lifecycle/input leakage. The integrated
guard checks current shape contact before accepting a zone update. Reuse that fix and
its regression; do not reopen the closed migration or rescan LPC for this release analysis.

Recommend a **private/internal, bounded Windows + named Android-device Technical Demo**:
the existing Old Pine slice can be installed, understood, played, manually saved and
continued after process death on the declared hardware. This is not ES2 completion,
full combat parity, all maps, final balance/art/audio/UI, final accessibility/localization,
or permission to publish on Steam, Google Play, App Store or public TestFlight.
No public distribution is implied by an engineering PASS.

Consume, do not replace, the durable [Shell](../production/contracts/APPLICATION_SHELL_CONTRACT.md),
[Native Save](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md) and
[Mobile](../production/contracts/MOBILE_APPLICATION_CONTRACT.md) contracts. In particular:

- ApplicationShell -> one persistent Runtime Host -> zero or one committed Session;
  the Host alone owns the current pointer. Candidate staging is temporary, not a second owner.
- One shared gameplay implementation; platform adapters provide input/presentation/activity.
- Manual gameplay Save and independent application Settings remain separate systems.
- No implicit recovery, autosave, in-game Load, additional slot, renderer fork or new mobile rules.

## 2. Evidence inspected and how to interpret it

Current durable evidence: [STATUS](../production/STATUS.md), [ROADMAP](../production/ROADMAP.md),
[BUILD](../production/BUILD.md), [repository policy](../production/REPOSITORY_POLICY.md),
[provenance ledger](../production/LICENSE_PROVENANCE.md), [third-party notices](../../THIRD_PARTY_NOTICES.md),
and the three contracts above. The qualification/evidence sections of the
[10C2 final audit](PHASE_10C2_FINAL_AUDIT.md) were read selectively; its historical pending-PR
wording is not a current-status authority and is not rewritten.

Direct native-source checks, not a new implementation audit:

| Evidence | Facts relevant to the gate |
| --- | --- |
| [project.godot](../../game/project.godot), [export presets](../../game/export_presets.cfg) | Canonical Shell; Mobile rendering, Windows D3D12; desktop/mobile logical dimensions; sensor landscape; ARM64 Android; provisional ID/versions and unsigned iOS project export. Development helper/QA/debug configuration exists and must be sanitized, not reset locally. |
| [application_shell.tscn](../../game/scenes/application/application_shell.tscn), [Runtime Host](../../game/runtime/persistence/oldpine_game_runtime_host.gd) | Shared mobile nodes; MANUAL startup; typed New/Continue/recovery/Save operations; committed Session invariant. |
| [activity state](../../game/application/lifecycle/application_activity.gd), [LifecycleAdapter](../../game/runtime/application/mobile_lifecycle_adapter.gd), [safe-area capability](../../game/runtime/application/godot_safe_area_capability.gd) | Separate foreground/focus/readiness facts; revision-gated reactivation; current viewport/screen measurements rather than device tables. |
| [Session](../../game/runtime/world/oldpine_world_session_controller.gd), [Vine adapter](../../game/runtime/world/oldpine_vine_traversal_adapter.gd), [Cave](../../game/runtime/world/oldpine_cave_passage_controller.gd), [Outdoor](../../game/runtime/world/oldpine_outdoor_controller.gd) | Resident maps, authoritative player location, deferred SouthExit and exact handoff, current-contact guard; no world rebuild on each traversal. |
| [demo factory](../../game/runtime/combat_slice/combat_slice_demo_factory.gd), [Vine policy](../../game/core/world/vine_traversal_policy.gd), [skills](../../game/core/skills/character_skill_state.gd), [combat progression](../../game/core/combat/completion/combat_progression_service.gd) | Starting dodge, effective-level calculation and conditional Cave reachability; combat progression is conditional, not a guaranteed route unlock. |
| [CharacterState](../../game/core/characters/character_state.gd), [Practice](../../game/core/training/practice_service.gd), [Selflearn](../../game/core/training/self_learning_service.gd) | Typed core foundations are present; runtime/UI searches found no direct Practice/Selflearn service consumers, so no training-menu claim. |
| [item content](../../game/data/oldpine/oldpine_item_content_definitions.gd), [restore projections](../../game/data/oldpine/oldpine_native_item_definition_projections.gd), [spawn definitions](../../game/data/oldpine/oldpine_spawn_definitions.gd) | Bounded Old Pine content/loadouts and restore definition coverage, not a full item catalogue. |
| [save root](../../game/core/persistence/game_save_snapshot.gd), [item snapshot](../../game/core/persistence/native_item_state_snapshot.gd), [storage profile](../../game/runtime/persistence/game_save_storage_profile.gd), [eligibility](../../game/runtime/persistence/oldpine_save_eligibility.gd), [coordinator](../../game/runtime/persistence/oldpine_session_load_coordinator.gd) | Existing save composition, fixed release path, restart-unsafe blockers and transaction; no alternative persistence design needed. |
| [build.py](../../tools/build/build.py), [sanitizer](../../tools/build/prepare_release_project.py), [CI](../../.github/workflows/ci.yml), [static checker](../../tools/ci/repository_checks.py) | Actual packaging, manifests, ephemeral signing, release exclusions and four-job integration policy. |
| [Vine regression](../../game/tests/runtime/oldpine_vine_cross_map_traversal_test.gd), [Session regression](../../game/tests/runtime/oldpine_world_session_test.gd), [lifecycle regression](../../game/tests/application/mobile_lifecycle_audit_test.gd) | Existing regression anchors, including 12 bootstrap items and stale-input/contact cases; not new test execution here. |

Evidence levels must remain separate:

- **IMPLEMENTED**: source/configuration provides the bounded capability.
- **INTEGRATED**: capability is on the exact green main baseline.
- **RUNTIME PROVEN**: a stated route ran in a stated environment/artifact; not every combination.
- **HARDWARE QUALIFIED**: a recorded acceptance matrix passed on named physical hardware with
  the actual candidate artifact/renderer. Running the development project on a PC is narrower.
- **STORE QUALIFIED**: separate ownership, distribution, signing, metadata and platform gates;
  nothing here currently has this status.

## 3. Current capability inventory

All implemented rows below are integrated at the baseline; no row is store-qualified.
`Desktop` means historical development/pristine-smoke evidence where recorded, not a new
complete packaged Windows acceptance run. `AVD` means the explicitly instrumented x86_64
Pixel_9_API_35 / host OpenGL / disposable gl_compatibility evidence, not ARM64 or Vulkan.

| Capability | IMPLEMENTED | INTEGRATED | RUNTIME PROVEN | HARDWARE QUALIFIED | STORE QUALIFIED |
| --- | --- | --- | --- | --- | --- |
| Character/resources, recovery, condition/life foundations | Yes, bounded typed rules | Yes | Automated rules; character state exercised in desktop/AVD slice | No complete demo matrix | No |
| Skills/progression/training foundations | Yes, closed domain scope | Yes | Rules and combat progression; no general training UX proof | No | No |
| Inventory, stacks, weapons, armor | Yes, current item set | Yes | Desktop/AVD loot/Inventory/equipment routes | No | No |
| Death/corpse/loot | Yes, bounded lifecycle/content | Yes | Desktop/AVD route evidence; exact persistence automated | No | No |
| Ordinary combat | Yes, supported slice, not full parity | Yes | Desktop cadence/selection and AVD interaction evidence | No | No |
| NPC/world/spawn | Yes, authored bandits/loadouts | Yes | Desktop Old Pine plus shared AVD runtime | No broad NPC/content qualification | No |
| Resident Session, Outdoor/Cave handoff | Yes | Yes, including #7 | Desktop and AVD roundtrip; #7 current-contact regression/live route | No current packaged physical matrix | No |
| Vine/Waterfall/River/Cliff/Pine | Yes, bounded routes | Yes | Desktop routes; AVD Cave evidence; conditional/setup distinctions below | No | No |
| Native Save/Load/recovery | Yes, fixed slot and fresh graph | Yes | Automated, desktop process restart and AVD durability evidence | No current physical-phone matrix | No |
| Main Menu/New Game/Continue | Yes, explicit entry | Yes | Desktop and AVD | No complete target matrix | No |
| Pause/Resume/manual Save | Yes | Yes | Desktop and AVD; pause is not Save eligibility | No | No |
| Explicit BACKUP/TEMP, Return to Menu | Yes | Yes | Desktop and relevant AVD/automated routes | No complete physical matrix | No |
| Independent Settings/Windowed/Fullscreen | Yes, desktop capability | Yes | Desktop settings/fresh process; mobile mode control intentionally hidden | No packaged Windows matrix for this gate | No |
| Responsive/SafeArea/sensor landscape | Yes | Yes | Simulated sizes and AVD rotation; not real cutout measurement proof | No physical phone/tablet qualification | No |
| Touch/Android Back | Yes, fixed digital pad and semantic Back | Yes | AVD actual OS contacts, scrolling, simultaneous contacts | No physical multitouch | No |
| Mobile freeze/explicit Resume/manual-only durability | Yes | Yes | AVD Home/foreground/kill; automated ordering/echo regressions | No physical lifecycle/ARM64 evidence | No |
| Sanitizer | Yes | Yes | Pristine-stage load/rendered smoke; separation from instrumented AVD | Not a device certificate | No |
| Windows release ZIP | Yes, unsigned x86_64 | Yes, current CI green | Historical export/rendered evidence; final candidate full ZIP journey pending | Pending named Windows matrix | No |
| Android technical APK | Yes, normal ARM64 | Yes, current CI green | Normal build is proven; runtime AVD artifact uses different ABI/renderer | ARM64/Mobile-Vulkan pending | No |
| iOS export/unsigned Xcode compile | Yes, shared source | Yes, current CI green | Build only; no simulator/iPhone/iPad runtime proof | Hardware gated | No |

Previous successful tests remain valid within these limits. They need not all be repeated now.
Neither a large assertion count nor a green compile supplies the missing physical evidence.

## 4. Important route and packaging findings

### Fresh New Game does not guarantee Passage Cave

The Session uses `CombatSliceDemoFactory.create_player()`: raw dodge is 10, with no mapped
dodge skill or starting armor modifier. `CharacterSkillState.effective_level()` gives 5.
`VineTraversalPolicy` draws below that bound; every possible draw 0..4 selects Waterfall.
Passage requires a draw >=5, hence effective dodge at least 6. An unmapped, unmodified raw
level of 12 meets that bound; wearing dodge-reducing armor can change it again.

Existing QA's raw dodge 12 / draw 5 demonstrates the branch, not an unassisted New Game
route. Combat progression can improve dodge only when its conditions and rolls permit;
there is no proof here of a short, repeatable natural route to sufficient dodge. Searches
found no current Practice/Selflearn UI call path. Do not promise farming, silently increase
starting stats, remove an armor penalty, reroll until a test passes, or expose a debug button.

Retain two acceptance tracks: unassisted default-game journey, and explicit conditional
Cave coverage. 10D3 must first demonstrate the natural prerequisite route or obtain an
owner decision to use a clearly labelled, validated demo save for this supplemental route.
A prepared save is not New Game proof. If neither is approved/proven, Cave remains a
blocked advertised demo-route claim even if its instrumented branch test passes.

### Artifact identity is not yet complete release reproducibility

`build.py` already records commit/dirty flag, engine, toolchain, target, signing mode,
timestamp and mobile package ID. It does not record final artifact hashes in that manifest.
The Android QA key is freshly generated, has a two-day certificate validity setting and is
deleted after export. Timestamps and fresh signing also mean byte-identical rebuilds are
not a current promise. 10D should require traceable repeatable builds, not pretend they are
bit-for-bit reproducible. Record candidate hash, certificate fingerprint/validity and
installation window before using an APK as a retained demonstration artifact.

## 5. Proposed internal slices and entry dependencies

Keep the requested structure; packaging decisions can be scoped in 10D0 before device work,
without a separate branch or an early store-identity commitment.

| Slice | Minimum work / exit evidence | Nature |
| --- | --- | --- |
| 10D0 — Scope / Release Analysis | This proposal; audience/platform boundary, device availability and owner questions recorded | Analysis only; current task |
| 10D1 — Physical Device Qualification | Named primary phone, normal ARM64/Mobile-Vulkan artifact, physical input/layout/lifecycle matrix, measured performance baseline; clear blockers rather than assumed PASS | Primarily validation; only proven release-blocking fixes after authorization |
| 10D2 — Packaging / Identity Boundary | Clean candidate ZIP/APK and evidence manifest/checksums/notices; explicit provisional identity, signing/disposal or upgrade policy; no installer by default | Minimal packaging/docs; code only for a demonstrated gap |
| 10D3 — Acceptance / Critical Journey | Final-artifact Windows/Android journey, conditional Cave coverage, process restart/recovery, repeated lifetime/input stress; understandable interaction | Validation and narrowly justified blockers |
| 10D Final Audit | Scope/contract/provenance gates, frozen-candidate evidence and focused/full verification at final gate, one ready PR then authorized merge and exact post-main four-job CI | Audit/integration; not a public release action |

If 10D2 changes the artifact's renderer, ABI, input/lifecycle code or packaging behavior,
repeat affected 10D1 evidence on the final candidate. Do not accept qualification of an
earlier artifact as interchangeable. No implementation or final audit runs in this task.

Gap ownership is deliberately not an implementation backlog:

| Gap group | Primary disposition |
| --- | --- |
| Physical Android, ARM64, production renderer, multitouch, native SafeArea/orientation | Hardware access + validation; change code only for a demonstrated product defect |
| Home/Recents, process kill/Continue, input/cadence/lifetime | Validation of integrated behavior, with narrow stabilization if evidence fails |
| Fresh install/upgrade/uninstall | Owner-approved data/signing policy + validation; no automatic updater requirement |
| Windows ZIP, manifests/checksums/notices, retained artifacts | Reuse tooling; minimal packaging/evidence gap, not installer architecture |
| Provisional/permanent identity, signing custody, distribution audience | Owner decision; permanent store policy can remain later |
| iOS runtime/device access | Explicit hardware/signing-access gate, not missing shared gameplay implementation |
| Public provenance, store submission | Owner/legal release-process decision and later commercial gates |
| Errors, performance, long-run stability, essential usability | Measured validation; only release-blocking fixes in scope |

## 6. Platform and physical qualification matrix

Recommend **one named physical ARM64 Android phone as the minimum internal-demo gate**,
not generic Android support. Record model, OS/build, SoC/GPU/driver, RAM, refresh rate,
resolution, physical safe-area/cutout, navigation mode, thermal/power state, artifact hash,
package/version, ABI, signing fingerprint and actual renderer/backend at launch.
Availability is unconfirmed by this planning task; do not infer ownership of a device or
request purchases. A second phone with a different GPU/vendor/layout is recommended if
available, and required before broadening claims beyond the named qualified configuration
when the extra risk is material. This is not an Android certification fleet.

| Environment | Required Phase10D evidence | Scope when unavailable |
| --- | --- | --- |
| Named Windows x86_64 PC | Pristine extracted ZIP, production Mobile/D3D12 configuration, keyboard/mouse, critical journey, settings, restart and logs | Windows demo gate blocked; development scene proof is insufficient |
| Primary physical ARM64 Android phone | Normal APK and actual Mobile/Vulkan; full physical matrix below | Android demo gate blocked; owner may explicitly narrow to Windows-only, never report Windows/Android complete |
| Second Android GPU/layout | Focused renderer/touch/safe-area/lifecycle and shortened journey | Optional for named single-phone internal demo; qualification statement remains narrow |
| Existing x86_64 AVD | Retain diagnostic/input-order regression evidence, labelled disposable GL/instrumentation | Does not substitute for primary phone or pristine artifact |
| iPhone/iPad | Shared implementation complete within existing scope; CI build validated; runtime hardware gated | Recommend option B: permit qualified Windows/Android demo, explicitly exclude iOS runtime/distribution |

Physical Android acceptance, on the installed final candidate:

1. Fresh install on an approved test package/data scope; cold launch reaches Menu, no hidden Session.
2. Real one-finger movement and two simultaneous fingers (PAD plus POINTER), extra contact
   rejection, drag-out/lift, scroll/selection, fresh input after modal/map/orientation changes.
3. Both landscape directions, actual cutout/system bars/gesture edge, readable UI and reachable
   critical controls. Test the contracted >=800x480 usable logical area; smaller configurations
   cannot inherit full gameplay qualification from fallback layout alone.
4. Android Back at item panel, Pause, Settings/confirmation and empty Menu; no unintended quit,
   double action or destructive confirmation. Test actual configured gesture/button Back mode.
5. Home and Recents while moving, two fingers held, paused, and a modal open; frozen gameplay,
   no stale action after foreground, freshly measured safe area, explicit Resume and new input.
6. Actual combat/loot/equipment; scroll populated Inventory; Vine and conditional Cave route;
   no inaccessible route button or touch pad covering essential gameplay.
7. Successful manual Save, observable unsaved change, OS process termination without uninstall,
   fresh Menu and Continue; last completed Save restored. Repeat same-process background return
   separately: unsaved memory remains and gameplay is gated until Resume.
8. Performance/thermal soak and lifecycle cadence, package-scoped logcat: no fatal/native/script
   errors, stuck input, corrupt save, lost camera or unrecoverable active-map state.

Qualification concerns the exact installed binary, not a desktop run or AVD screenshot.
Uninstall is destructive and requires approval; do not use it to simulate process death.

## 7. Production renderer rule and iOS boundary

Android qualification MUST use production Mobile with the actual Vulkan backend, not merely
a Mobile setting in source. Capture runtime renderer/driver evidence; a silent fallback or
external staging override is not Vulkan PASS. Windows uses its current D3D12 driver; do not
unnecessarily force Vulkan on Windows. Godot distinguishes rendering method from backend,
and fallback can change the method/appearance ([Godot 4.7 renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html)).

If a real device fails: preserve logs/driver/artifact facts, distinguish missing capability,
driver/engine fault and project defect, reproduce narrowly, then propose the minimum fix or
an explicitly narrowed supported-device claim. Do not change product renderer for emulator
convenience. Any proposed renderer/engine change needs owner scope approval, a dedicated
impact audit and affected visual/input/build/performance requalification on the final artifact.
Do not hide a supported target's crash behind repeated retries or broad compatibility claims.

No macOS/iPhone/iPad availability is established here. Unsigned generic-iOS compilation stays
a required CI job even if iOS runtime is excluded from the demo. Signed device installation,
safe-area/touch/lifecycle/Metal proof and iOS distribution await hardware and owner-provided
identity/capabilities. Do not invent simulator evidence or introduce a mobile gameplay fork.

## 8. Packaging, identity, signing and install behavior

**Windows ZIP is sufficient** for this internal Technical Demo. Use the existing clean sanitized
export, preserve required adjacent PCK/resources, include matching manifest and appropriate
notices, record final hashes outside the hashed archive, and verify a fresh extraction without
editor/cache/developer paths. Launch without Godot AI/QA/tests/debug arguments and with an
approved isolated user-data scenario. Then test the journey and Windowed/Fullscreen persistence
across a fresh process. A portable ZIP is not a claim that saves live next to the executable.
Installer/updater, paid code-signing and storefront packaging are not automatically required.
Unknown-publisher/security warnings must be documented, not bypassed by disabling protection.

**Android**: retain `com.example.easternstoriesgodot` as the recommended provisional internal
identity until the owner chooses otherwise. This recommendation grants no domain/name ownership
and makes no permanent store choice. Existing version `0.0.0-dev` / code `1` remain unchanged now.
Record each artifact by commit/hash, not just that reused technical version label.

Two distinct distribution options require an explicit owner choice before 10D2:

- One-off controlled qualification: existing ephemeral QA signing, approved disposable data,
  bounded certificate/install window, no cross-build upgrade guarantee. Freeze the exact tested APK.
- Retained/repeated internal distribution or promised upgrade durability: owner-approved reusable
  **technical**, not necessarily store, signing identity and version policy, custody/backups outside
  Git and a same-key upgrade test. Implement that only in a separately authorized slice; no secrets
  or repository settings are created by this analysis.

Android updates depend on compatible package identity, signing certificate and version code;
uninstalling an incompatible package removes its app data
([Android platform update rules](https://developer.android.com/google/play/app-updates)).
Therefore distinguish: clean install, same-binary restart, same-key update, incompatible-signature
replacement, and uninstall/reinstall. Process durability must pass without reinstall. If the owner
selects disposable signing, cross-build save retention is explicitly unsupported, not a PASS.
Do not add save export/cloud backup to work around signing; protect existing data and obtain consent.

Permanent product/developer/publisher names, owned domain, store strategy, final package/bundle ID,
Play signing, Apple distribution/provisioning and commercial certificate procurement are later
owner decisions. Unsigned iOS compile is sufficient for the retained build gate, not an installable
IPA. External public distribution requires an explicit release/provenance decision even outside stores.

10D2 should bind clean Git SHA, toolchain/template checksums, sanitized content digest, packaging
configuration, output hashes and signing evidence to the tested candidate. Existing manifests are
a base, not a second repository/service architecture. A small external evidence record suffices
where tooling changes add no value. Rebuild reproducibility means documented inputs and equivalent
behavior; do not claim identical APK/ZIP bytes despite timestamps and ephemeral certificates.

## 9. Legal/provenance release-process gate

The [ledger](../production/LICENSE_PROVENANCE.md) and [notices](../../THIRD_PARTY_NOTICES.md)
still identify no native project root license and an unresolved ES2 README/license-holder
discrepancy (Raymond Xie attribution versus Wekan copyright text). No reconciliation was performed.
Excluding raw LPC from the export does not resolve rights/provenance for migrated material.

Recommended process boundary, **not a legal conclusion**:

- Private/internal engineering validation may continue within existing owner authorization,
  recording these unresolved items; this is not a grant of rights or a legal clearance opinion.
- Before any public binary/demo publication, the owner must explicitly resolve/document the
  native-code license, ES2 attribution/permission basis, asset provenance and required notices,
  with appropriate legal review where needed. Engineering cannot silently mark the discrepancy fixed.
- Godot runtime notice delivery must be checked in the actual candidate package, not just in the
  repository. The development-only Godot AI addon stays excluded. No new root license is chosen here.

No release upload, store submission or public distribution is authorized by 10D analysis or CI.

## 10. Critical journey and Save durability

The proposed journey covers the right systems, but split it at conditional/random prerequisites
and restart-unsafe states instead of requiring one lucky uninterrupted playthrough.

**J0 — unassisted default player:** clean launch -> Menu -> New Game -> walk/select/inspect ->
ordinary combat -> completed death/corpse -> Open Loot/Take -> Inventory inspect/wield/unwield/
wear/remove where applicable -> move to a genuinely safe state -> Vine/Waterfall default branch ->
Pause -> manual Save A -> Resume -> make an observable unsaved location/equipment change B ->
background/foreground and explicit Resume on mobile -> terminate process -> fresh launch/Menu ->
Continue -> restore A, not B -> move/interact successfully -> confirmed Return to Menu.
Include Main Menu and paused Settings on Windows, retaining freeze and independent storage.
Check effective dodge at the actual Vine step: the guaranteed Waterfall statement applies
to unchanged starting skills (or another positive bound <=5), not arbitrary post-combat
progression/equipment. If play changes the bound, record the valid authored branch and
continue its normal exit; do not force the initial expectation onto changed state.

**J1 — conditional branch:** establish/report valid live effective dodge and branch prerequisites ->
real approach/select/Hold vine -> Passage Cave -> physical SouthExit -> Waterfall -> fresh movement ->
manual Save/Continue, and a separate Cave Save/Continue then SouthExit. Natural RNG selecting
Waterfall is a valid branch, not a failed Cave attempt that may be hidden. For deterministic
branch regressions use disclosed setup/injected RNG before the route in nonshipping validation;
all subsequent steps use real input. Packaged acceptance must satisfy section 4's natural-route
or approved prepared-save boundary, without adding a QA dependency to the package.

**J2 — independent negative/durability cases:**

| Case | Packaged/device acceptance | Existing automated evidence retained |
| --- | --- | --- |
| Save while unsafe | Real combat Pause/Save blocker is honest; existing file unchanged; Resume still works. Do not clear relationships/timer/busy to force eligibility. | All restart-unsafe predicates: lethal markers, partial lifecycle/handoff, final corpse, staged graph, temporary modifiers, etc. |
| Corrupt canonical with valid BACKUP/TEMP | Approved isolated test data; real Menu/recovery selection, no silent fallback, cancel safe, chosen recovered state playable. Files not promoted until explicit Save. Verify on Windows; repeat representative platform-storage path on phone when fixture access is available. | Codec, candidate selection, re-read, rollback and malformed graph permutations. No requirement to bypass Android sandbox or root a phone. |
| Background before/after Save | Same-process unsaved memory vs fresh-process last completed Save; no new file writes/rotations caused by lifecycle. | Interleavings during pending Save/New/Continue/recovery and duplicate notifications. |
| Storage failure | Honest error, unchanged playable/paused state and recoverable prior data where the contract permits. | Fault-injected write/rename/rollback failures; do not fill a user's disk or sabotage permissions. |
| Settings | Window mode survives a fresh Windows process; independent settings failure must not invalidate gameplay save. | Settings schema/apply/write error permutations. |

The release path remains `user://save-data/release/default-v1.json`, with `.bak` and `.tmp`;
settings remain `user://settings/application-v1.cfg`. Restart must restore semantic IDs, item
placement/equipment/corpse/NPC tombstones, saved RNG continuation and location, with fresh runtime
objects and one active map. Exact identity/RNG checks belong in existing typed/observed tests;
a screenshot alone cannot prove them. End-to-end Save success requires an actual eligible state;
Pause alone is not eligibility. No persistence redesign, autosave, atomic-power-loss claim or
guarantee for an unfinished write is added.

## 11. Runtime stress design

Proposed finite gate, not statistical proof of zero flakes:

| Layer | Proposed repetitions | Purpose / evidence limit |
| --- | --- | --- |
| Deterministic runtime regression | 20 consecutive affected contact/input/handoff cycles at each 30/60/120 fixed-step render setting and default timing: 80 cycles | Warm real contacts, detach/reattach, preserve every transient zone violation, stale input/echo and fresh movement. Nonshipping harness may use disclosed setup. Not GPU/device performance proof. |
| Rendered Windows candidate | 5 complete J0/J1-qualified journeys at each 30/60/120 render cap and default: 20 total, each with fresh-process Continue | Physical movement/real UI plus timer/lifetime/save behavior at varied render/physics phase relationships; record achieved rate, not just requested cap. |
| Primary physical Android candidate | 5 full journeys split across both landscape directions, plus at least 20 total real handoffs and 20 Home/Recents/Resume transitions during a >=30-minute soak | Real multitouch, native safe area/lifecycle/driver and thermal behavior; count these as separate hardware evidence. Use native refresh and available 30/60 caps; 120 only where actually supported. |

These counts are proposed test design, not results already achieved. Freeze setup and the
iteration budget before execution. Any invariant failure is a failure: capture the first
trace, diagnose, fix narrowly, then rerun affected gates. Do not retry away failures or
report only successful branches. Every run records its RNG/setup and state/event ordering.

Do not conflate render rate with physics tick rate. Leave production physics rate and time
scale unchanged, record them, and vary rendering/phase relationships. Godot's `--max-fps`
caps rendering; `--fixed-fps` disables real-time synchronization and is appropriate for a
separate deterministic stress mode, not measured wall-clock/lifecycle/thermal claims
([Godot 4.7 command-line reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)).
Verify requested settings really apply to the executable; VSync/device limits can cap achieved FPS.

Use semantic intent and visible enabled controls, viewport-relative bounds and completion
conditions, not fixed screen pixels or arbitrary sleeps. Walk into the actual Area/collision;
do not call traversal/button handlers or assign positions after route start. Bounded waits
may wait for a precondition, never suppress a failed invariant. Keep deterministic branch setup
separate from pristine artifact proof. Development helper proof requires live/session/capture
health, no unexplained runtime errors and advancing non-stale frames. Packaged proof uses the
actual executable/APK and external capture/input/logging, not a shipped helper.

Observe: committed location vs current contacts; deferred SouthExit completion and duplicate
suppression; fresh input after every transition; unchanged paused cadence/timer remainder;
one Host/Session, one active map, correct camera/body binding; save candidate retirement and
semantic continuity; freed old Session graphs, bounded resident maps and no cumulative
ObjectDB/resource growth. Read-only instrumentation can aid diagnosis in a separately labelled
validation build; its measurements must not be misrepresented as pristine-package internals.

## 12. Lightweight performance and runtime error gates

No supported numerical frame/latency/memory budget has yet been measured on the target phone.
10D1 must record a warm baseline and propose explicit thresholds for owner approval **before**
10D3 acceptance, not select tolerances after seeing a failure. Proposed measurement workload:
idle Menu, ordinary movement, populated combat/loot, handoff, Save, Continue, repeated menu teardown,
and sustained background/foreground. No unrelated benchmark framework or AAA target is required.

| Measure | Record / acceptance intent |
| --- | --- |
| Frame delivery | Actual FPS, median/p95/p99 frame time and long-stall count on each workload/device; compare cold/warm/thermal-soaked windows. No sustained collapse or unreadable/unresponsive gameplay; turn this into device-specific limits after baseline. |
| Handoff / Save / Continue | Wall-clock request-to-ready time, median and tail, cold vs warm; no unexplained hang or permanently blocking UI. Preserve synchronous/asynchronous authority, not extra fake timers. |
| Memory / objects | Process RAM trend and available node/object/resource counts at the same post-teardown checkpoint after deferred frees; warming/caches may plateau, Session/map counts must return to expected ownership. No unbounded cycle-correlated growth. |
| Background | CPU/activity over a stable background window, gameplay timer/RNG/state not advancing, no lifecycle-initiated save I/O; a previously requested manual Save may finish. Do not assert zero process CPU because Shell/Host and the OS may still work. |
| Thermal / usability | Device temperature/throttling indicators where available, power mode and responsiveness during soak; report unavailable sensors rather than invent readings. |

Hard runtime rejection criteria already justified by the architecture: zero script errors,
fatal/native exceptions, corrupt completed saves, duplicate committed Sessions, invalid active-map
count, stuck input, unexplained surviving Session graphs or unrecoverable navigation. Shader/import
or resource-missing errors in a packaged candidate are product failures. A crash-free retry does
not erase a previous failure. Known editor/tool warnings require exact message, provenance and
evidence of non-product impact; do not blanket-whitelist ObjectDB leaks. QA mistakes invalidate
the affected proof and require a clean rerun, not a production workaround.

## 13. UX blockers, content freeze and next checkpoint

Technical-demo blockers: illegible essential text, clipped/unreachable Save/Resume/Back/loot
actions, broken focus, accidental destructive confirmation, stuck touch, unclear required action,
misleading save success, a core route available only via debugger, or debug/QA diagnostics exposed
as product instructions. A basic placeholder aesthetic is acceptable if critical interaction is
understandable and the incomplete scope is honestly labelled. Final art/animation/audio/music,
advanced accessibility/localization, broad balance and cosmetic polish remain later work.

Freeze authored content for Phase10D. Allow only a demonstrated release-blocking fix or a minimal
owner-approved fixture/content correction required for the existing journey, with focused audit
and affected requalification. Do not use the Cave prerequisite finding to silently broaden scope.
Keep/Lake/serpent, major Cave expansion, broad Phase5B4+ parity and bulk ES2 migration are deferred:
they would enlarge the behavior/device matrix before the current installable slice is reliable.

After 10D, hold a player-feedback planning checkpoint, not an automatic Phase11 content mandate.
Choose between more authored ES2 content and a bounded Old Pine experience/polish pass. Review
technical stability, players' unassisted route completion, combat/loot comprehension, friction,
art/UI/audio clarity and reported enjoyment. Prefer polishing existing confusion before extending
content; prefer a small content increment only if the reliable loop is understood/enjoyed and
lack of meaningful content is the demonstrated constraint. Implement neither in this task.

## 14. Ranked risk register

| Rank | Risk / current evidence | Gate / owner |
| --- | --- | --- |
| Critical for publication | Native root license absent; ES2 holder discrepancy unresolved | Owner/provenance decision before any public distribution; no engineering clearance claim |
| High for Android demo | No physical ARM64/Mobile-Vulkan/multitouch/cutout qualification | Named-device 10D1 matrix; hardware availability, not extra gameplay code |
| High for advertised journey | Fresh dodge 10 -> effective 5 cannot select Passage; natural progression route unproven | 10D3 prerequisite proof or explicit supplemental-save/scope decision; no formula change |
| High | Physics/deferred/input lifetime ordering already caused a main flake | Current-contact invariant plus repeated real runtime/candidate verification |
| High if iOS promised | No iPhone/iPad runtime despite green unsigned compile | Explicit iOS hardware gate; recommend exclude from initial demo claim |
| High if identity/updates promised | Provisional ID, fresh two-day QA certificate per build, no stable update key | Owner chooses disposable vs retained technical distribution; do not lock permanent store identity early |
| Medium | Build manifests lack final output hashes; ephemeral/timestamp rebuild variability | Bind frozen artifact hashes and signing/window evidence, not false byte-reproducibility |
| Medium | Unmeasured phone performance/thermal/memory lifetime | Baseline then predeclared thresholds/soak; no unsupported frame-time promises |
| Medium | Critical UI clarity/focus/touch overlap on real screen; incomplete art/audio | Block inaccessible/confusing essentials, defer cosmetic production |
| Medium | Single-device evidence may be overgeneralized | Name qualified configuration; expand small matrix only with supported-target claim |
| Lower for this gate | Small content quantity / incomplete full ES2 parity | Explicit scope freeze; evaluate after user feedback, not a release-gate expansion |

## 15. Decision-ready conclusion and implementation entry

**A. Exact scope:** qualify and package the current Old Pine slice as a private/internal
Windows plus named-Android-device Technical Demo; prove honest durability and runtime lifetime,
not overall RPG or store completion.

**B. Non-goals:** new gameplay/content systems, combat parity, renderer change, installer,
automatic/permanent identity/signing choices, store configuration/upload, autosave, additional save
slots, final art/audio/balance/localization/accessibility and public release.

**C. Slices:** keep 10D0 analysis -> 10D1 physical qualification -> 10D2 minimal packaging/identity
boundary -> 10D3 final-candidate journey -> Final Audit; one branch/final PR. Packaging-sensitive
changes require revalidation rather than a new phase branch.

**D. Journey:** J0 default New Game/normal play/loot/equipment/Vine-Waterfall/manual Save/restart/
Continue, plus J1 conditional Cave/SouthExit and J2 recovery/blocker tests. Resolve Cave prerequisites
before claiming a single unassisted itinerary. No debug route substitution.

**E. Platforms:** one named Windows PC and one real ARM64 Android phone minimum for the recommended
bounded demo. Second Android GPU/layout is risk-based; AVD remains supplemental. Recommend iOS option
B: implementation/build validated, runtime hardware gated and excluded from Windows/Android demo.

**F. Provenance:** existing private engineering workflow is not public-distribution permission.
Owner must resolve/document native license, ES2 discrepancy and notices before publication.

**G. Owner input:** audience and exact supported devices; phone access/test-data permission;
provisional demo ID retention vs separate technical identity; disposable signing vs a reusable
technical key/update promise and custody; acceptable Cave-route setup/scope; predeclared measured
performance limits. Permanent product/publisher/domain/store/signing decisions remain later.

**H. Performance/errors:** baseline and freeze measurable per-device limits, then run finite
stress/soak; zero product script/fatal/corruption/stuck-input/ownership failures or unexplained leaks.

**I. Content:** freeze broad migration; only approved critical-journey blockers/minimal corrections.

**J. Entry criteria:** integrated green main is VERIFIED. Before 10D1 execution obtain approval of
this bounded plan, name an available phone and Windows test environment, approve isolated app/data
handling and the candidate signing/install window, and make the production renderer evidence
collectable. Missing hardware blocks that qualification row, not authorization to invent PASS.
Before final-candidate acceptance additionally settle Cave-route claims, distribution/update policy
and measured budgets. Public legal clearance is a publication gate, not silently waived by testing.

**K. Later deferrals:** iOS runtime until hardware/signing access; general Android/tablet/portrait/
multiwindow support, permanent store identity/signing/uploads, installers/updaters, cloud/extra save
features, full content/combat and final presentation. Next planning direction follows actual feedback.

Analysis validation: exact green-main ancestry and four remote jobs verified; local documentation
links, stale durable wording, three-contract consistency, repository/static, diff and whitespace
checks only. Production/build/CI, `reference/es2` and `DECISIONS.md` changes: zero. No new runtime
qualification claimed. Phase10D1 remains **NOT STARTED**.
