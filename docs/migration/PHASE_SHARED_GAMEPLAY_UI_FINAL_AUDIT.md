# Shared Gameplay UI — bounded Final Audit

## Disposition and frozen identities

Date: 2026-09-27. Branch: `phase/shared-gameplay-ui`.

**SHARED GAMEPLAY UI — ENGINEERING ACCEPTANCE COMPLETE.**
**FINAL AUDIT — PASS / READY FOR OWNER PR AUTHORIZATION.**
No unresolved material blockers. This is phase-branch engineering acceptance under the explicit
Owner touch-device deferral, not integration on main or actual-device/mobile release qualification.
The content/architecture review and complete execution results are separately recorded below.

| Identity | Commit |
|---|---|
| Integrated stage baseline / main / merge base | `f421ed106a7fd38455790729a5d6dd89a72133da` |
| Delivered implementation and original runtime evidence | `e61ddc5c5ab5b7f1433659023952798468adc93a` |
| Closure code/test freeze | `4219a0e2f8e5eba72ec2eb23e4fbb6bad8f02876` |

Fresh fetch confirmed the delivered local/remote phase identity and baseline. Work continues in
the same isolated checkout. Closure adds one teaching-panel regression correction (`6800ae5`)
and a release required-path list correction with its focused regression (`4219a0e`). Production
`game` excluding `game/tests`, `.github` and `reference` remain identical to the delivered version.
The only tooling change is the sanitizer's required UI paths, not its algorithm or CI workflow.
Final documentation must leave all executable/test files identical to the closure freeze. No phase PR exists.

Read authority: root and docs AGENTS, the [runtime report](PHASE_SHARED_GAMEPLAY_UI_RUNTIME.md),
[Application Shell contract](../production/contracts/APPLICATION_SHELL_CONTRACT.md),
[Mobile contract](../production/contracts/MOBILE_APPLICATION_CONTRACT.md), and the complete
baseline-to-stage content diff, including changed consumer tests and the eight recorded PNGs.
This is one review of this stage, not a reopening of historical Core, Lake or Migration Tooling.

## Stage increment and scope

| Functional group | Reviewed changes and retained boundary |
|---|---|
| Session ownership | `oldpine_world_session.tscn` owns one `SharedGameplayUI`; Outdoor retains only a reference. Host remains the sole committed-Session authority. |
| Shared presentation | Compact exploration entries, explicit Character/Inventory/Supplies/Messages, one dismissible business frame, bounded nonpersistent feedback; existing safe-area and scrolling infrastructure. |
| Portable composition | Session routes held-item/equipment/armor operations through existing services. Existing source item definitions supply display data. Inactive Outdoor is not a portable-operation owner. |
| Business context | Inn, work, bank, school and hockshop keep their services and execution validators. Existing forms mount/return through the shared frame. |
| Combat handoff | Existing BattlePresentation yields/restores the Session UI and forwards completion feedback. No encounter, scheduler, hit, damage, Flee or RNG rule changes. |
| Regression consumers | Canonical shared-UI registration plus updated ownership/layout consumers. Identity, transaction, resource, permission, lifecycle and physical-input assertions remain. |
| Release validation | Required release paths follow the replacement SharedGameplayLayout and SharedGameplayUI. Removal of either is still rejected; no workflow, sanitizer algorithm, forbidden-reference policy or skip change. |
| Documentation/evidence | Current ownership contracts, current phase position and eight real framebuffer images; historical implementation failures remain disclosed. |

Content review of the Outdoor scene confirms removal of UI nodes/resources/signal connections only;
physical geometry, spawn/portal/Area definitions and population were not changed. No increment under
Game Core, persistence implementation, source mudlib, addons, project configuration or CI workflow.
The narrow release-list correction is explicitly included in this audit, not hidden as documentation.
CURRENT WORLD ONLY, SOURCE_ENTRY_LAKE_V1, root schema2/item schema3 and ten production slots remain.
No Internal Power, new gameplay, plugin/dependency change, production QA fixture or outcome forcing.

The small display catalog reuses `SourcePlayerCloth`, `SourceDumpling`, `SourceWineskin` and currency
constants/definitions. Descriptions were checked against
[cloth](../../reference/es2/mudlib/obj/cloth.c),
[dumpling](../../reference/es2/mudlib/obj/example/dumpling.c) and
[wineskin](../../reference/es2/mudlib/obj/example/wineskin.c).
No new source-rule translation or reward/value/weight policy was introduced.

## Historical discovery failures and closure repair

The implementation discovery log remains a **failed** run: 301 failed assertions, 21,195 assertions.
Fresh reading found 212 `SCRIPT ERROR` emissions in 18 site groups; repeated emissions are not 212
independent defects. The enclosing shell's earlier zero exit is not acceptance evidence.

| Root family | Disposition and evidence |
|---|---|
| Old HUD ownership/private paths and result title | Consumers now read the Session UI, explicit shared frame and compact result message. Canonical registrations remain; target IDs, terminal results and zero-presentation-RNG assertions remain. |
| Actual business initialization/close defects | Hockshop's visibility listener now attaches after confirmation controls exist; the shared close clears references before hiding/reparenting, avoiding reentry. The old log's 171 null `hide` emissions belong here. Hockshop/corpse/first-progression follow-ups pass. |
| Deactivated/unconfigured/freed maps | Session UI checks active child availability; standalone/unconfigured Outdoor guards its Session reference. Old freed-map reads and interrupted tests could leave Sessions/input blockers alive. Shell transactional, cutover and lifecycle follow-ups pass. |
| Changed explicit-opening and single-frame contract | Supply/bank tests open the actual requested form; Inspect and Loot no longer assert simultaneous independent windows. Existing field traversal permission remains with the map service; inappropriate portable-operation gating was removed during implementation. |
| Portable result ownership | Full-loot stale-row checks read Session receipts, preserving exact ownership refusal and equipment transitions. Water, food, bank, restore and playability follow-ups retain business assertions. |
| Invalid diagnostic command | The nonexistent hockshop test path is invalid evidence, not a product failure or pass. The correct `runtime/hockshop_runtime_test` ran successfully. |
| Remaining closure omission | Fresh complete run 1 reached a stale `school.ui._reflow` call in `snow_martial_progression_test.gd`, before that function's Session cleanup. It emitted a script error; the later Liuh-Ken full-state equality assertion also failed. Neither is dismissed as a successful run. |
| Sanitized release inventory | Complete run 2 passed canonical gameplay without script errors, then failed because `REQUIRED_PATHS` still demanded deleted `oldpine_hud_layout.gd`. Replaced that obsolete requirement with both actual shared layout/UI paths, preserving fail-closed required-file validation. |

The historical mixed logs are not retroactively marked green: `shared-ui-remaining.log` contains
water/bank passes and 20 then-unfixed playability assertions; later playability evidence is separately
identified in the runtime report. The complete follow-up batches `shared-ui-lifecycle-followup.log`,
`shared-ui-close-final.log` and `shared-ui-final-lifecycle.log` were read and contain no script errors.
Their targeted successes alone were not used to close possible same-process interference.

Closure repair `6800ae5` changes only `game/tests/runtime/snow_martial_progression_test.gd`:
reflow and focus-scroll checks now use the shared frame, and a new assertion requires the teaching
form to be mounted in that visible frame. Safe bounds and minimum touch targets remain checked at
1152x648, 960x540, 800x480 and the existing small-area fallback 480x320. No assertion about Learn,
Enable, resource cost, equipment, Save equality or RNG was removed or weakened. No production
callback, lifecycle or Save behavior was altered.

The teaching and immediately following Liuh-Ken acceptance groups were run in one process using
`run_shared_gameplay_ui_tests.gd -- runtime/snow_martial_progression_test runtime/snow_martial_progression_acceptance_test`.
Result: exit0, 7.172 seconds, no script/engine errors; teaching 287 and acceptance 110 assertions passed.
This confirms that the repaired function reaches its cleanup and the following equality succeeds
in that sequence. Complete run 2 subsequently confirmed canonical coexistence: both teaching and
Liuh-Ken groups completed, 21,579 assertions passed and no script errors remained. It still failed
its later sanitizer gate, so it is not a complete verification PASS.

Release-list repair `4219a0e` changes only `tools/build/prepare_release_project.py` and its existing
test module. The old deleted layout requirement is replaced with
`presentation/layout/shared_gameplay_layout.gd` and `ui/world/shared_gameplay_ui.gd`.
A regression checks actual repository file presence and independently removes each required file
from a disposable test output to prove rejection. Existing forbidden helper/test/path checks,
source immutability, current main scene and copy/sanitize logic are untouched.
The release-preparation module passed all 14 tests in 1.527s. A real sanitized project was prepared,
validated and loaded with the official headless editor: exit0 in 14.407s, post-import validation `[]`,
no script/engine errors. These are focused diagnostic checks; the final complete run below independently passed all five stages.
No gameplay, input or presentation bytes changed, so this packaging-list correction needs no new
physical UI route or screenshots and does not claim a packaged executable startup test.

## Complete local execution

Command (official Godot 4.7.2 stable, build `ed1daf0bf`):

```text
python tools/ci/verify.py --godot <pinned-official-Godot_v4.7.2-stable_win64_console.exe>
```

No skip flags. The Python wrapper captures stdout/stderr, records monotonic elapsed time and exits
with the actual `verify.py` subprocess return code. `verify.py` checks each subprocess exit and
stops on failure. The complete log is also inspected for script errors, not merely assertion totals.
The existing verifier uses its isolated `build/verify-godot-environment`; normal Owner saves are not
used. Tests' declared QA fixtures remain automated test evidence, not natural live progression.

| Run | Exact code/test version | Result |
|---|---|---|
| Fresh complete run 1 | `e61ddc5c5ab5b7f1433659023952798468adc93a` | FAIL, actual exit1, 635.109s; Python/static/editor passed, canonical reported one failed equality assertion plus one script error; sanitizer not reached. |
| Complete run 2 | `6800ae5bd766fa1d413895dcb310bd06ed6b6564` | FAIL, actual exit1, 664.391s; Python/static/editor and canonical gameplay passed without script errors; sanitizer rejected obsolete required layout path. |
| Final complete run 3 | `4219a0e2f8e5eba72ec2eb23e4fbb6bad8f02876` | PASS, actual exit0, 649.719s; all five stages completed. |

Final run 3 completed Python tooling (657 tests), repository/static checks, development headless
editor load, the complete canonical gameplay suite (21,579 assertions), and actual release sanitizing
plus sanitized-project headless editor validation. All subprocesses succeeded; the full log contains
zero `SCRIPT ERROR`, `ERROR` or `FAIL` emissions. Teaching and the following Liuh-Ken group completed
in the canonical process without weakening exact-state equality. This is a fresh complete run on
`4219a0e2f8e5eba72ec2eb23e4fbb6bad8f02876`, not an aggregate of targeted successes.
Log SHA-256: `f655482a614ae9b93b79dacae6fa12645b2ab8d5623efa29dde646261ddfd205`.

Both earlier failed runs remain failed evidence. No skip option, canonical registration removal,
exception swallowing or current Save relaxation was used. Subsequent audit/status changes are
documentation-only; executable/test identity is checked against this freeze instead of repeating
the completed suite.

Local evidence remains ignored: `shared-ui-final-verify-1.log/.json`,
`shared-ui-final-verify-2.log/.json`, `shared-ui-final-verify-3.log/.json`,
`shared-ui-final-martial-targeted.log/.json` and `shared-ui-final-sanitizer-targeted.log/.json` in the owner's
existing build evidence area. No raw Save, temporary script/log or personal configuration is committed.

## Bounded ownership, context and input review

The following is content/architecture review in addition to the execution evidence, not a claim
that test execution itself constitutes the audit.

- **One Session / one UI:** the sole production instantiation is the Session scene. Signal bindings
  are established once in SharedGameplayUI readiness; layout subscribes once and disconnects on
  tree exit. Three repeated Snow/Cave handoffs and responsive lifecycle checks retain exact UI and
  connection identity. No map creates a duplicate generic player HUD.
- **Staging / commit / rollback:** the CanvasLayer begins hidden. UI processing checks initialized
  Session, active-map child, staged/suspended state, `can_process` and Shell gameplay permission.
  Portable actions repeat authoritative availability checks. Host ownership and restore transaction
  code did not change; staged-restore and Shell failure/swap coverage remain. UI is a Session child,
  so menu disposal releases it and a successful Continue binds a new instance.
- **Current context:** map change closes the frame and clears selection before binding the new map.
  Shared business frames hold the existing validator, and original request methods recheck active
  map, physical placement/range, lifecycle, fighting/busy and service-specific requirements.
  Hockshop confirmation is consumed once and rejects changed location/item state. Invalid context
  cannot turn a stale displayed quote or item row into mutation permission.
- **Original services:** bank/work/Inn and Liu operations still call existing Money/Work/Purchase,
  apprenticeship/Learn/Enable services. Held food/liquid still use actual inventory and source-water
  availability. Session equipment composition preserves direct ownership, life and equipment/armor
  checks; source cloth uses its existing armor definition. There is no new economy/combat policy.
- **Close and reentry:** forms no longer auto-show every frame. Shared close releases focused child,
  clears current content before visibility callbacks, hides barrier, and returns the form to its
  owner. School/hockshop close the containing frame; hockshop Back still cancels confirmation first.
  Freed row caches are handled by the unchanged responsive-layout lifecycle.
- **Input / simulation:** the full viewport barrier and existing presentation blocker own panel
  input. Opening/closing quarantines held movement; the existing Shell consumes one cancel before
  Pause, and touch routing uses the same top interaction panel. No UI code pauses the scheduler,
  changes Save eligibility, draws RNG or changes resources during projection.
- **Battle / feedback:** exploration yields while an encounter exists; BattlePresentation remains
  the existing combat surface. Completion text reaches bounded Messages/recent feedback and the
  shared UI returns. Existing form feedback remains visible in its mounted component and is copied
  to the bounded message view. No second combat action surface or permanent modal layer is added.
- **Display / scope:** large windows start closed across maps. Shared safe bounds, clipping-aware
  visible rectangles, dynamic row sizes, focus scrolling, synthetic touch and lifecycle tests
  exercise the new frame. Updating legacy surface assertions to the enclosing scroll frame does
  not waive button visibility, size, action ownership or underlying gameplay blocking.

The two concrete integration omissions (teaching test ownership and release required paths) are
closed by the narrow commits and complete verification. The separate bounded review, finalized
after that complete result and rereading both closure diffs, found no unresolved correctness,
input, context, ownership, restore or scope blocker. No gameplay or UI implementation change
was needed during closure.

## Reused real runtime and image evidence

The Godot gameplay/presentation bytes are identical to `e61ddc5`; closure changes only tests and
the required release-file list. Therefore the
[implementation runtime evidence](PHASE_SHARED_GAMEPLAY_UI_RUNTIME.md#real-runtime-evidence)
is reused, not described as newly executed here:

- Real public New Game and physical Inn → Snow → Old Pine; explicit Character/Inventory and real
  source-cloth Remove/Wear while Outdoor is inactive.
- Real Inn supply interaction preserves the `钱不够。` service result; target View shows authored text.
- Real Pause Save, Menu disposal, new-process public Continue and subsequent map handoff retain
  the new Session/UI ownership boundary. This is UI binding evidence, not a repeat of Lake's exact
  full persisted-graph cold-restore qualification.
- Real aggression → Battle → Escape Pause → Resume → Flee mouse input produced queued/execution/
  disengaged receipts, ACTIVE Player and restored exploration UI. No resource injection or balance claim.
- Final real Character click and Escape closed only the panel with `paused=false`.

Recorded helper health was `helper_live=true`, `session_active=true`, `game_capture_ready=true`;
run5 reported `current_run_errors=[]`. Cited captures were non-stale and counters advanced within
runs. These are historical observations from the implementation task, not a new live connection.
The eight [before/after images](PHASE_SHARED_GAMEPLAY_UI_RUNTIME.md#actual-beforeafter-screenshots)
were visually inspected in this audit and agree with current code: matching 1152x648 views,
compact map HUD, explicit shared inventory/character frame and post-Flee return. No appearance
changed in either closure correction, so no replacement screenshot or repeated physical route was needed.
Cave evidence remains bounded resident integration/physical transition tests, not a new live adventure.

## Owner touch-device disposition

For **this Shared Gameplay UI stage only**, the 2026-09-27 closure instruction sets actual-device
qualification to **PENDING / DEFERRED — NON-BLOCKING FOR THIS SHARED-UI ENGINEERING INTEGRATION**.
This is an independent Owner decision, not inheritance of Lake's exception or a future blanket waiver.
It is not touch PASS, all-platform acceptance or release readiness. Concrete input/product defects
would still block; missing device qualification cannot conceal one.

The existing [PROJECT_SCOPE mobile entry](../production/PROJECT_SCOPE.md#presentation-platforms-tooling-and-release-boundaries)
retains the work: representative shared input/navigation, scrolling, cancel, focus, safe area and
applicable Pause/Back/background/resume lifecycle on actual then-target devices. Complete before
verified-touch claims or external long-term testing/formal release of related mobile versions.
Existing automated responsive/touch/lifecycle checks remain required. No device search, emulator,
plugin upgrade, new qualification system or separate prerequisite development phase was introduced.

## Documentation checks and owner gate

After the complete pass, repository/static checks and `git diff --check` passed. A local Markdown
link/anchor check covered all seven phase/current-contract documents: 331 references, zero errors.
The final audit delta contains only this report, STATUS, ROADMAP, PROJECT_SCOPE and the Mobile
contract. `git diff --quiet 4219a0e2f8e5eba72ec2eb23e4fbb6bad8f02876 -- game tools .github reference` returned0; audit documentation
changes do not invalidate the complete executable/test evidence.

The historical runtime report remains byte-identical, raw SHA-256
`cb52999879530a649c4b4db6158a83e60d1e65368235693d1dd0f4bdcc4520e3`.
The original Owner project configuration remains byte-identical to its preflight state, raw SHA-256
`efaea1fa56ec0f6a7b391856c9ea7d5dbaa3cba72348d7c53d5a3c55291ca16c`.
The delivery contains only the listed code/test corrections and five audit/current-state documents;
ignored logs, real isolated saves, ordinary saves and personal configuration are not included.

The original runtime report is preserved, including its then-PENDING status and failed discovery.
Original-checkout Owner `game/project.godot` configuration and ordinary saves remain untouched.
No history rewrite, branch deletion, new UI feature, PR, remote CI, merge or Internal Power work.

**SHARED GAMEPLAY UI — ENGINEERING ACCEPTANCE COMPLETE.**
**FINAL AUDIT — PASS / READY FOR OWNER PR AUTHORIZATION.**
**TOUCH DEVICE QUALIFICATION — PENDING / DEFERRED.**
**INTERNAL POWER — PAUSED. PR / MERGE — NOT STARTED.**

Normal push retains the current phase branch. No PR/remote CI/merge is created by this task;
exact-HEAD PR CI and exact-merge main CI remain future owner-authorized integration gates.
Readiness is not authorization for Internal Power or another milestone.
