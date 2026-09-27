# Shared Gameplay UI — runtime implementation

## Disposition and identities

Branch: `phase/shared-gameplay-ui`; integrated base:
`f421ed106a7fd38455790729a5d6dd89a72133da` (Lake PR #24,
[push/main run 36288212245](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36288212245),
four required jobs success, checked before branching).

**SHARED GAMEPLAY UI — IMPLEMENTED / TARGETED VALIDATION COMPLETE.**
**INTERNAL POWER — PAUSED. FINAL AUDIT / PR / MERGE — NOT STARTED.**

This is implementation and bounded self-verification, not a Final Audit or full-suite acceptance.
Actual-device touch qualification is **PENDING** for owner disposition. Lake's bounded exception
does not automatically waive this phase. Complete canonical closure and remote integration gates
remain outstanding. The one discovery run below failed; it must not be cited as a green suite.

Work used an isolated checkout to preserve the owner's existing `project.godot` working change.
Temporary isolated debug-port/editor settings were removed from this checkout before delivery.
No normal Save was modified. Runtime evidence and test logs remain ignored local build artifacts;
only the selected real PNGs below are checked in. No implementation was performed on main.

## Ownership and bounded design

| Category | Before | Implemented boundary |
|---|---|---|
| Player information | Outdoor HUD plus separate map/supply surfaces | One Session-owned `SharedGameplayUI`, compact location/resources and explicit Character entry |
| Portable inventory/equipment | Outdoor HUD/controller ownership; source cloth absent from that narrow content projection | Session composition invokes existing item/equipment/armor services; existing source cloth/food/liquid/currency definitions supply display facts |
| Supplies | Permanently appearing food/wineskin windows | Explicit shared Supplies frame, same held-item/service/source-water validation |
| Local business | Resident work/bank/inn/hockshop/school forms | Existing form components reparent into one frame; current map/range validators and original execution services remain authoritative |
| Field targets | Outdoor selection/details/actions | Map still owns NPC/corpse/landmark/range; shared contextual actions and explicit details/loot frame |
| Battle | Session BattlePresentation plus Outdoor HUD coordination | Existing BattlePresentation yields/restores the same Session UI; no duplicate exploration combat controls |
| Feedback/debug | Large always-visible details/log and technical labels | Small result feedback; explicit Messages, maximum 60 entries, nonpersistent; internal IDs/coordinates omitted from compact HUD |

`oldpine_world_session.tscn` owns the single CanvasLayer; no generic HUD remains in Outdoor,
Snow, Inn or Cave. Host remains the sole committed-Session authority. UI keeps references/projections,
not cloned Player, inventory or Save authority. Existing business components retain their validators
and services. The shared container is not a new plugin or arbitrary scripting framework.

On map change, the frame and old selection close before current-map context is projected.
Invalid business context closes; stale item submissions still revalidate live authority. Dead/missing
targets and obsolete source/range contexts lose actions. Opening a frame quarantines held movement
and blocks underlying picking; it never pauses the scheduler or changes Save eligibility. Closing
releases focus and consumes one cancel. Hockshop Back first cancels sale confirmation, then closes.

Shared UI does lightweight refreshes rather than rebuilding the entire hierarchy every frame.
Dynamic inventory/business rows continue using existing change-based refresh. The frame reuses
SafeAreaPresenter and ResponsivePanelLayout, including scrolling and touch-sized controls.
Continue staging is hidden/noninteractive; successful replacement creates new UI and releases old
bindings, rollback retains old Session, and menu return releases all player windows.

## Preserved rules and scope review

No Game Core formulas, combat scheduler/RNG, birth policy, Learn/Enable/trade outcomes, population,
map geometry, Save schema/content revision, plugin, dependency, CI or Migration Tooling changes.
Outdoor scene deletions are its UI subtree/resources/connections, not physical geometry.
CURRENT WORLD ONLY / SOURCE_ENTRY_LAKE_V1 remain unchanged.

The item display catalog composes existing authoritative definitions. LPC descriptions consulted:
`reference/es2/mudlib/obj/cloth.c`, `reference/es2/mudlib/obj/example/dumpling.c` and
`reference/es2/mudlib/obj/example/wineskin.c` (see exact source constants in the existing definitions).
No new inventory capability, item value, weight, reward or source mechanic was designed.

Focused self-review checked Session/Host separation, portable operations without inactive Outdoor,
staging visibility, context invalidation, single cancel, bounded messages, Flee UI restoration,
shared safe-area subscriptions and disposal. Tests continue asserting identity, business results,
failure protection and physical behavior; old `%HUD`/private-layout expectations were updated to
the new ownership boundary, not preserved with a dummy legacy HUD.

## Real runtime evidence

Official Godot 4.7.2 (`ed1daf0bf`), canonical ApplicationShell, isolated user-data profile.
Computer Use supplied actual text/mouse/key input; Godot's frame input interface supplied ordinary
movement/action edges and framebuffer mouse input. Minimal read-only `game_eval` observed identity,
state and receipts. No evaluator gameplay calls, injected Player stats, fixtures, teleports, forced
RNG, death setters or prepared progression Save were used for this claimed route.

1. Real Public New Game: `UI Review`, male. Inn showed compact HUD with large panels closed.
   Real Character and Inventory clicks opened the common frame; source cloth appeared. Escape
   closed it, with `paused=false` and frame closed afterward.
2. Walked to the Inn waiter, opened the shared business frame and clicked Buy Dumpling. Existing
   service returned `钱不够。`, retained in shared feedback. This is a real business interaction,
   not a claim of successful purchase without money.
3. Physically walked Inn → Snow → Old Pine. In Snow, real Remove/Wear operated the same source
   cloth while the Outdoor map was outside SceneTree. The same operation worked in Old Pine.
   No old Status/Details/Actions wall appeared on entry.
4. Real Pause → Save at Snow, Return to Menu and confirmation. Session became null; old UI
   instance `951402367591` ceased to exist. Stopped the game, started another process and clicked
   public Continue. New Session `865821789492` / UI `865872120711` restored cloth and location.
   That UI instance remained identical on the later Snow → Pine handoff. This is UI binding
   acceptance, not a repeat claim of Lake's complete persisted-graph equality qualification.
5. Selected the actual Ancient Pine and clicked View: authored description used the same frame.
   Runtime inspection exposed an irrelevant empty target-health bar for landmarks; it was removed
   without changing landmark behavior. No field callback substituted for the actual click path.
6. Physical Bandit03 aggression produced normal combat. Exploration UI yielded to BattlePresentation.
   Real Escape paused; real Resume and Flee mouse click produced retained Queued/Execution Started/
   Resolved: Disengaged receipts. Player remained ACTIVE, encounter ended, same UI restored.
   Walked away from aggression. Low health from ordinary combat recovered naturally; no repair
   of Player resources was performed. This proves UI/Flee switching, not balance or survivability.
7. Final new-process Continue smoke showed the current Character fields and scroll container.
   Real native Escape again observed `[paused=false, shared_frame_visible=false]`.
   This smoke supplements, rather than falsely reruns, the earlier route after final context fixes.

Helper observations were `helper_live=true`, `session_active=true`, `game_capture_ready=true`.
Run 5 launch reported `current_run_errors=[]`; no debugger break occurred on the acceptance route.
Final owned game/editor were stopped. The owner briefly pressed Escape to stop Computer Use;
input resumed only after the explicit continuation instruction.

Cave coverage is the actual resident scene in bounded SceneTree integration: three repeated
Snow/Cave handoffs preserve UI identity, clear contexts/frame and keep one action subscription.
Existing Vine/Cave physical transition tests also pass. No complete Cave adventure, packaged build
or real touch-device run is claimed.

## Actual before/after screenshots

All images are real 1152×648 game framebuffers, not mockups. Baseline is the integrated base before
edits; after images are this implementation. Corresponding Snow/Pine positions differ by only a few
walking pixels, not viewport scale. Inventory pairs use the same Pine view.

| View | Before | After |
|---|---|---|
| Snow exploration | [Before](evidence/shared-gameplay-ui/before-snow.png) | [After](evidence/shared-gameplay-ui/after-snow.png) |
| Old Pine exploration | [Before](evidence/shared-gameplay-ui/before-oldpine.png) | [After](evidence/shared-gameplay-ui/after-oldpine.png) |
| Inventory opened | [Before](evidence/shared-gameplay-ui/before-inventory.png) | [After](evidence/shared-gameplay-ui/after-inventory.png) |

Additional [Character](evidence/shared-gameplay-ui/after-character.png) and
[post-Flee exploration](evidence/shared-gameplay-ui/after-flee.png) captures.
Before Snow/Pine/inventory frames: 7905 / 13293 / 17242. After: 6852 / 12360 / 17311;
Flee 46016; final Character 9606 in its new process. Every cited capture had `stale_frame=false`.
Different process counters are not a single continuous frame sequence; within each run frames advanced.

## Targeted verification and discovery failures

Commands use the pinned official Godot executable as `<godot>`:

```text
<godot> --headless --path game --editor --quit
<godot> --headless --path game --script res://tests/run_shared_gameplay_ui_tests.gd -- <consumer paths>
python tools/ci/repository_checks.py --repository .
git diff --check
```

The focused runner accepts existing consumer paths below `game/tests` without `.gd`. It adds no
production test dependency. The new shared-UI lifecycle group is also registered in canonical tests.

One broad `run_tests.gd` discovery was justified by many historical HUD consumers. It reported
**301 failures / 21195 assertions**, including script errors and cascade failures from unreleased
test Sessions. It was NOT a pass (the enclosing shell's zero exit was not accepted as evidence).
It exposed old HUD/private-layout reads, narrow item-result ownership, business close initialization
and reentry, wrong completion-title assumptions, and modal movement expectations. A later local
command also used a nonexistent hockshop test path; that command is invalid evidence. Correct paths
were rerun. No canonical registration was removed, and no business assertion was discarded.

Corrections included: unconfigured/deactivated map guards; staged UI hiding; container-owned child
geometry; hockshop confirmation cleanup and reentrant close; movement quarantine on opening;
service result receipts moved to Session; removal of an inappropriate portable-item guard from
existing field traversal/loot requests; explicit opening of now-closed supply/bank forms in tests.
Inspect and Loot now occupy one frame, so the loot test explicitly returns from Inspect before
asserting refreshed rows. Existing source item IDs, transfer results and combat/restore rules remain.

Final individual affected results, not a claim that each mixed earlier batch was wholly green:

| Coverage | Latest evidence / result |
|---|---|
| Shared lifecycle; staged restore; full loot; Outdoor smoke | `shared-ui-final-consumers.log`: 30 / 251 / 136 / 307 checks, each PASS |
| Shell transactional failure/swap and combat cutover | `shared-ui-lifecycle-followup.log`: Shell phase10c1b 191, phase10c1c 230, Session 225, cutover169; batch PASS |
| Pine maze, Cave/Vine, Snow connection/north spine | `shared-ui-route-followup.log`: 238 / 256 / 128 / 188, each PASS; its corpse/river failures were subsequently resolved |
| River/cliff route including existing busy/fighting traversal boundary | `shared-ui-context-final.log`: 225 PASS |
| Corpse, hockshop, Lake Fill, first progression, touch routing, presentation lifecycle | `shared-ui-close-final.log`: 276 / 107 / 91 / 247 / 92 / 1021; whole batch exit0, **93.80 seconds**, no script errors |
| Liuh-Ken automated existing consumer | `shared-ui-final-consumers.log`: 110 PASS |
| Supplies/bank | `shared-ui-remaining.log`: water118 / bank81 PASS |
| Existing playability/Flee | `shared-ui-world-followup.log`: playability369 PASS before that command's invalid next path |
| Responsive content and safe-area matrix | `shared-ui-final-targeted.log`: mobile presentation2806 PASS |
| Food/Battle presentation | `shared-ui-refined.log`: dumpling104 / Battle149 PASS |

Measured mixed diagnostic batches were 50.82s, 108.13s and 52.54s; their failures are disclosed above.
Earlier iterative commands did not retain reliable whole-command timings; no duration is invented.
Local logs stay ignored. Final editor import/load passed (exit0, 7.92s). Final shared lifecycle + staged restore follow-up
(`shared-ui-final-lifecycle.log`) passed exit0 in 3.90s after the final close changes.
Changed-document links/anchors: 315 checked, zero errors; repository/static and diff whitespace PASS.
Final game-file manifest SHA-256 (sorted tracked/unignored game paths, path/NUL/raw SHA/newline):
`f1c9afb5c6b35a0d7b53b4226eff5eb80750a84c43f853eca08b27154c5a475c`. No new `verify.py`, repeated complete canonical run, remote CI or packaged
validation is claimed. Final complete canonical verification remains a phase-closure gate; targeted
retests are not substituted for it.

## Remaining qualifications and owner gate

- Actual-device touch qualification remains PENDING: representative movement/navigation, scrolling,
  common-frame cancel, safe area and applicable lifecycle behavior. Existing synthetic coverage is
  evidence of wiring/layout only, not device PASS. No device/emulator search or plugin upgrade.
- Final canonical closure and separately authorized Final Audit / ready PR / exact-head and
  exact-merge CI remain outstanding. No automatic authorization arises from this implementation.
- This is functional UI consolidation, not final art, all locales/accessibility, complete ES2 or release
  readiness. Internal Power and unrelated roadmap work remain paused/not started.
- The owner's original checkout, personal configuration, ordinary saves and previous evidence remain
  untouched. No Save/screenshot containing real personal data is added; the UI test character is synthetic.

Await owner review on this phase branch; no PR or merge is created by this task.
