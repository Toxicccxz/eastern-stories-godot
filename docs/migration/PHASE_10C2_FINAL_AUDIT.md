# Phase 10C2 — Final Major-Phase Audit

**FINAL AUDIT PASSED — READY FOR FINAL PR.** Date: 2026-09-02.
Branch: `phase/10c2-mobile-input-layout-lifecycle`. Phase10D **NOT STARTED**.
This is local integration readiness, not PR CI, merge, post-merge CI or store readiness.

## Baselines and scope

| Authority / closed slice | Commit |
| --- | --- |
| Integrated main / Phase10C1 | `3a1f993a4258ed246ce820c7a4dc8d2563994aaf` |
| [Analysis](PHASE_10C2_MOBILE_INPUT_LAYOUT_LIFECYCLE_ANALYSIS.md) | `5508e59` |
| [10C2A formal audit](PHASE_10C2A_FORMAL_AUDIT.md) | `968abbea4edda5ab2a7856e8afee98ebe0c0a1f6` |
| [10C2B formal audit](PHASE_10C2B_FORMAL_AUDIT.md) | `b622d7833917b6ac08a54d0f57ee1856fcb1742c` |
| [10C2C formal audit](PHASE_10C2C_FORMAL_AUDIT.md) / audited production HEAD | `ab04b5b6490fd1cf01a188408ff19c6089552576` |

Reviewed the complete main-to-closed-C scope architecturally: 78 paths (36 production,
31 tests, 2 build-tool files and 9 documents, including UIDs). No new line-by-line slice
audit or LPC/reference scan. No cross-slice production defect or unresolved implementation
requirement was found. **This final audit changes documents/contracts only.**

Remote main still equals the integrated baseline; local merge-base equals it and the phase
branch contains the closed A/B/C commits in order. No synchronization is required. Remote
phase HEAD matched closed C before this documentation commit; GitHub search found no open
PR for the branch. No new branch, PR, merge or Phase10D work was performed.

## Cross-slice consistency and Analysis traceability

| Material Analysis decision / seam | Final classification and evidence |
| --- | --- |
| One Shell -> Host -> 0..1 Session | Implemented/proven A/B/C. Shell scene has one metrics presenter, one touch adapter and one lifecycle adapter. No mobile Session/Player/snapshot/repository authority. Host and Session production persistence/ownership files are unchanged from main. |
| Responsive hierarchy, logical sizing and landscape | Implemented/proven A, retained B/C. Desktop1152x648, mobile960x540, canvas_items/expand, both sensor-landscape directions. Qualified safe size >=800x480; smaller areas bounded but not gameplay-qualified. Target sizing/scrolling, existing item/HUD actions and non-hover descriptions remain presentation-only. |
| Single safe-area normalization, no device table | Implemented/proven A/C. GodotSafeAreaCapability -> SafeAreaMetrics -> shared presenter. Touch consumes these metrics; active Outdoor layout subscribes to the same provider. Current root-window transform/fallback boundaries remain explicit. |
| Fixed digital movement, normal action/pointer route | Implemented/proven B/C. Existing four movement actions; one PAD + one POINTER, native GUI/scroll/world picking, no action callbacks or alternative movement authority. Same-direction keyboard independence and cancelled-world click behavior remain covered. |
| Cancellation and input precedence | Implemented/proven A/B/C. Busy/modal/panel precedence, metric changes, handoff, Session replacement and lifecycle cancel stale contacts. Touch Pause emits pause_game; Android Back emits system_back. C suppresses input via the same Shell boundary, not a competing touch state. |
| Android Back and platform exit | Implemented/proven B/C. One notification-to-intent route; modal cancel first, bare Playing pauses, bare Pause explicitly resumes, only empty idle Menu exits. Inactive Back is inert; desktop Escape is not rebound. |
| Immediate lifecycle freeze and explicit Resume | Implemented/proven C. Typed activity facts close input, cancel captures/actions and pause PAUSABLE Session while Host/Shell stay ALWAYS. Foreground refreshes metrics/reflow, rejects stale revisions, clears input and focuses before publication. Same Session remains gated until fresh Resume; no catch-up. |
| Existing modal origins and pending Host transactions | Implemented/proven C. Menu/Settings/Recovery/Result preserve typed state; both completion orders for New/Continue/BACKUP/TEMP commit one graph PAUSED with zero tick. End completes to empty Host. No restarted/cancelled/duplicated work or source substitution. |
| Manual-save-only durability | Implemented/proven C. Lifecycle causes zero requests/writes/preflight. Existing requested manual Save retains success/blocker/failure and rollback. Canonical/bak/tmp evidence and real process restart restore the last completed manual state. Recovery retains explicit source re-read/no promotion. |
| Map/HUD/adapter lifetime | Implemented/proven A/B/C. Same Session and touch/lifecycle adapters across Outdoor/Cave/Outdoor, one active resident map, fresh safe metrics on rebind, no Outdoor HUD in Cave or stale map pointer in mobile adapters. B's pending Android Cave/multitouch rows were completed by C. |
| Settings and desktop coexistence | Implemented/proven A/B/C and 10C1 consumers. Independent ConfigFile/window capability preserved; mobile hides unsupported window controls and adds no preferences. Ordinary desktop alt-tab does not activate mobile lifecycle gating. |
| Sanitizer and explicit technical Android ABI | Implemented/proven B/C; freshly checked here. Shared canonical production retained, tests/observer/QA/helper/debug stripped. Explicit Android-only x86_64 staging is not normal ARM64/renderer/package/CI configuration. |
| Installed Android acceptance | Implemented/proven within the documented emulator tier. A/B/C combined evidence covers responsive UI, touch/Back, lifecycle, manual durability, Cave/SouthExit, simultaneous kernel contacts and reverse landscape. Typed/fault-injected recovery/pending-operation tests are not mislabelled OS player-route proof. |
| iOS shared source/export requirements | Implemented/shared-path checks retained; unsigned Xcode compile is explicitly pending final PR/main CI. Android runtime is not iOS runtime evidence. Simulator/device runtime remains hardware-gated. |
| Deliberate product/hardware exclusions | Explicitly deferred: physical Android multitouch/ARM64/production Vulkan, iPhone/iPad runtime, portrait/split-screen/multiwindow qualification, analog/tap-to-move/controller locomotion expansion, autosave/background tasks/termination Save, dirty tracking, new settings, in-game Load/multiple slots/cloud saves, store IDs/signing/uploads, accessibility/localization/art overhaul, gameplay/content expansion and Phase10D. |

Contract correction only: the closed Shell mode table described foreground-ready Menu as
unpaused without naming the later mobile inactive exception. A small qualification and
cross-reference now cover temporary empty-Host pause; ownership and foreground behavior are
unchanged. Stale STATUS/ROADMAP/BUILD claims that no mobile implementation existed were
updated without rewriting historical A/B/C evidence.

## Durable documentation

- New [Mobile Application contract](../production/contracts/MOBILE_APPLICATION_CONTRACT.md)
  defines ownership, responsive/safe-area boundaries, touch/Back, lifecycle/Resume,
  manual-save durability and release/qualification boundaries. It contains no audit counters,
  commit/PID/hash history or QA procedures.
- [Application Shell contract](../production/contracts/APPLICATION_SHELL_CONTRACT.md) gains
  only the minimal mobile extension links/foreground qualification. The
  [Native Save contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md) is unchanged;
  the mobile contract extends application policy, not schema/eligibility/repository semantics.
- [STATUS](../production/STATUS.md) and [ROADMAP](../production/ROADMAP.md) distinguish local
  completion from pending integration and keep Phase10D unstarted until integration is green.
- [BUILD](../production/BUILD.md) documents production mobile retention, manual-only saving,
  explicit Android technical-ABI usage and separation from normal releases/hardware proof.

## Reused evidence versus new checks

The exact closed-C production/test/build tree is unchanged. Reused its **12,012 focused
invocation assertions** (overlapping consumers), **14,886 canonical historical assertions**
from one complete attempt, **46 Python tests**, **19 pristine rendered smoke checks**,
development/sanitized headless results, Android technical runtime and native desktop
non-regression. Original logs remain under `build/phase10c2c-audit-*`; the complete log's
terminal PASS/count and rendered smoke result were rechecked. This audit did **not** rerun
the historical suite, Python suite, headless engine, Android matrix or live desktop path.
Historical helper health belongs to the cited runs, not a new live claim.

New lightweight validation:

- Repository/static checks PASS.
- Fresh `prepare_release_project.py --source game --output build/phase10c2-final-release-project`,
  then `--validate-only`: PASS. All 352 staged production GDScripts match current source.
  Required mobile/Shell/save/settings paths and shared landscape/mobile-size settings remain;
  no observer/autoload/test/helper/QA/debug or technical package/renderer override survives.
- Project/export/build/CI inspection: normal ARM64 and Mobile renderer unchanged; iOS source
  path shared; explicit technical ABI remains Android-only/disposable. Source's pre-existing
  development helper/QA autoloads and local debug argument are preserved, not shipped.
- Local documentation links, three-contract consistency, branch ancestry/scope,
  `git diff --check` and changed-file trailing whitespace: PASS.
- No production/build/test changes relative to closed C; no generated APK/log/screenshot
  paths in the main-to-phase diff. `reference/es2` and `DECISIONS.md` changed paths: **0**.

## Qualification and integration gates

Runtime proof is Pixel_9_API_35 **x86_64 AVD / host OpenGL / disposable gl_compatibility**
with an isolated, explicitly instrumented technical package. It proves the observed
Android OS routes, not physical Android, ARM64, production Vulkan, general compatibility
or store certification. The distinct pristine sanitized checks do not turn the observer
APK into an uninstrumented release.

iOS shares touch/lifecycle/Apple safe-area/sensor-landscape code and sanitizer retention;
no iPhone/iPad simulator/device runtime is available. Carry physical multitouch, ARM64/Vulkan,
iOS runtime and permanent identity/signing/package qualification into later release gates.
These explicitly permitted gaps do not block architecture integration. No new qualification
work or Phase10D implementation was started here.

Commit/push remains on the same branch, with a clean worktree and **no PR**. Next is the
single authorized final PR: Godot Verify, Windows Release Build, Android Release Build and
iOS Build Validation must pass on the same final PR HEAD; then explicit merge authorization
and four green post-merge main jobs are required. No remote CI success is claimed by this audit.

**PHASE 10C2 — FINAL AUDIT PASSED**

**PHASE 10C2 — READY FOR FINAL PR**

**PHASE 10D — NOT STARTED**
