# CXR9 — Old Pine Playability + Narrow Balance Stabilization

Status: **CXR9 implementation COMPLETE; CXR10 READINESS = READY / NOT STARTED.**
V1 Closure Continuation below supersedes the historical Part 1 blockers with the
owner-approved Flee/unarmed-SPAR/zero-base decisions and final 2026-09-07 evidence.
Physical Android affected-path gate remains PENDING for CXR10 final audit/merge;
this is not cross-platform qualification or integration on main. The original
baseline/matrix and interrupted checkpoint remain historical evidence. This is a
distinct slice self-audit, not CXR10.

## Scope / starting source

Same `phase/combat-experience-redesign`, starting HEAD/upstream
`d98849ff7cc98708cc75b5ee062ae1cfe3a7db69`, ahead/behind 0/0. The 120 existing
owner plugin/project dirty paths were enumerated and hashed before work; exclude
them from this slice. Legacy source stays read-only. No PR, merge or Phase 10D work.

## Prior acceptance evidence

Read the parked branch's `PHASE_10D3_COMBAT_PLAYABILITY_STABILIZATION.md` using
`git show origin/phase/10d-technical-demo-release-gate:docs/migration/...`.
That record identifies the symmetric Phase 6 prototype's experience 10 versus
ordinary Old Pine bandit 600 and records an owner-approved Old Pine New Game-only
600 bootstrap. That fix was NOT in the starting HEAD. Its earlier tests are not
fresh acceptance evidence, and Phase 10D acceptance never passed.

## Unmodified Fresh New Game baseline

Canonical ApplicationShell, real New Game/confirmation buttons, actual movement,
NPC clicks and Attack, no altered stats, teleport, injected RNG, direct combat
calls or probe registration. Helper live/session active/capture ready all true;
non-stale frames 14881 (menu), 27722 (south slope), 46513 (post-defeat Pause).
Observer-only metadata retained the existing scheduler reference to read its
events after normal completion clears coordinator references; it changes no rule.

| Route / cause | Cycles | Player final current/effective kee | Enemy final kee | Outcome |
| --- | ---: | --- | ---: | --- |
| Walk south to (450,710.67), select visible scout 3, real Attack | 17 | -1/-1 | 200 | DEFEAT/dead |
| Fresh game, walk south into scout 2 aggression at (450,751) | 11 | -1/-1 | 200 | DEFEAT/dead |
| Fresh game, walk west to (-107.33,300), fat bandit aggression | 14 | -1/-1 | 220 | DEFEAT/dead |

Every player starts gin 220/220/220, kee 220/220/220, sen 100/100/100,
experience 10, all eight base attributes 20, raw sword/dodge/parry/unarmed 10,
force/perception 0, no enabled mappings, long sword wielded, zero internal force.
Scouts: experience 600, kee 200, raw sword/parry/dodge 10, short sword.
Fat: experience 500, kee 220, sword 20, parry/dodge 10, short sword + leather.
Tall is present: experience 900, kee 220, sword/parry 15, dodge 10, long sword;
this initial physical route encountered Fat first, not a claimed Tall fight.

Manual scout: 11 player forward attacks, all dodged; 10 enemy ripostes, all hit.
Natural scout: 6 player forward dodges; 2 enemy forward + 6 riposte hits.
Fat: 5 player forward dodges; 8 enemy forward + 1 riposte hits.
All observed busy-after values 0; guard/no-action opportunities present. Nominal
active time is 17/11/14 seconds (one-second cycles); wall time including tool
latency and Pause is not combat duration. Manual encounter was paused at cycle 0,
held while inspected, then resumed with real Escape. No scheduler softlock seen.
No victory occurred, so baseline victory/loot/safe post-victory Save is NOT PASS.

## Findings and pre-implementation V1 closure matrix

- **BALANCE / PLAYABILITY:** reused prototype experience creates pathological
  mismatch, repeated above and independently justified by LPC staged integer math.
- **PLAYABILITY:** no real tactical intervention or flee; a doomed encounter can
  only run to defeat or be abandoned through Main Menu. This is not scheduler hang.
- **PLAYABILITY:** Battle vanishes on completion; world log still says only
  `attacks on sight` / initiation. Death is inferable from corpse/negative HP, but
  no explicit result is retained visibly. Add only read-only authoritative feedback.
- **V1 GAP:** real actions, flee, telegraph producer, armed mortal SPAR unresolved.
- **DEFERRED:** final visuals/audio/localization/accessibility polish, broad balance.

| V1 capability | Current status | Fresh-game impact | CXR9 action |
| --- | --- | --- | --- |
| Ordinary auto combat | Production scheduler/Core | Runs; exp mismatch dominates | Narrow New Game content adjustment |
| Automatic defense | Core dodge/parry/guard | Observed; not player-timed | Preserve formulas |
| Current target | Semantic target authority/UI | One hostile makes switching trivial | Recheck actual input |
| Multi-opponent model | CXR7 supported, pair entry here | No invented group aggro | Regression only |
| Tactical queue | Infrastructure only | No real action to queue | Preserve, NOT gameplay PASS |
| Real production tactical action | Zero | No meaningful action intervention | Explicit V1 blocker; inspect dependencies |
| Flee | No production policy | Cannot disengage | Blocked: physical destination/pursuit not decided |
| Enemy telegraph | No commitment producer | No special warning | V1 gap; no fake ordinary-attack bar |
| SPAR | Armed mortal wound fail-closed | Not exposed by normal Old Pine Attack | Integration blocker, no clamp/revive |
| LETHAL | Production | Defeat/corpse observed | Preserve and reaccept |
| Battle feedback/log | Ordinary feedback exists | Results disappear abruptly | Narrow result projection |
| Result comprehension | Weak | World only shows initiation | Authoritative receipt -> HUD text |
| World return | Same Session, successful thaw | Post-defeat Pause/Menu usable | Regression + fresh acceptance |
| Corpse/loot | Existing pipeline | No baseline victory | Only claim after natural victory |
| Save/lifecycle | Closed Shell/Save boundary | Pause works; active save forbidden | Focused + actual safe path |
| Mobile semantics | Prior bounded evidence | Changed balance/feedback invalidates reuse | Check device; new affected-path evidence |

## Source decisions before implementation

`adm/daemons/combatd.c::skill_power`: effective raw-10 skill is 5;
`(5*5*5)/3/100*100` is 0, then experience is added. Non-busy armed hit probability
against two 600 defenses is `(10/610)^2`, versus `(600/610)^2` in reverse. Do not
change these formulas. Reapply only the already approved product New Game
experience **10 -> 600**, not generic prototype, restore, NPCs, skills, HP or RNG.

`cmds/std/perform.c` and `exert.c` require enabled mappings; Fresh New Game has
none. `d/force/recover.c` could heal current kee by min(deficit, effective force/3
+10) for 20 force and busy 1 in combat, but this player has 0 force and no force
mapping. `refresh.c` / `regenerate.c` also have a non-min ternary legacy oddity.
Do not grant skills/force, invent Power Attack, or register a QA heal for agency.

`cmds/std/go.c`: encumbrance -> busy -> real exit -> valid_leave -> move ->
remove_all_enemy. `do_flee` randomly chooses an existing exit, not a success roll.
`feature/attack.c::remove_all_enemy` leaves killer identity; `std/char.c` reads
`env/wimpy` while `cmds/usr/wimpy.c` writes `wimpy`. Frozen RPG encounter has source
location, not an approved escape destination. No fake teleport/chance/cost.

`d/oldpine/npc/{bandit,tall_bandit,fat_bandit}.c` confirm stats/loadouts; Fat's
call-for-help is not an authored committed attack/telegraph. Current SPAR mortality
failure in `CombatEncounterResolution.inspect` remains explicit. Resolving it needs
a compatibility decision, not silently changing damage/death rules.

## Implemented fixes / numeric diff audit

1. `OldPineWorldSessionController.NEW_GAME_COMBAT_EXPERIENCE = 600`, assigned only
   in `_initialize_authorities`. This is the only gameplay numeric change: 10 ->
   600, revalidating the historical owner-approved product entry configuration.
   `_initialize_restore_authorities` never runs that initializer; saved experience
   10 remains 10. Generic Phase 6 player remains 10. No NPC/skill/HP/equipment,
   damage, wound, hit, dodge, parry, RNG, cadence or progression-formula change.
2. `BattleFeedbackReader.completion_text` reads successful completion receipts;
   `BattlePresentationController` reports each receipt ID once to the current
   typed `OldPineOutdoorHud`. Victory/Defeat/Spar-concluded text is downstream of
   committed result AND successful world return. Failed/absent receipts display
   no success. HUD's existing heading exposes `Victory/Defeat — see Details`,
   with full message in the existing log. No result screen, reward, Timer or gate.

An initial implementation auto-opened compact Details, breaking CXR6's restored
touch-pad expectation. That **new implementation regression** was corrected by
using the existing always-visible heading without opening any panel. CXR6 was
rerun unchanged and passed; CXR9 locks non-modal behavior and idempotent feedback.

## Tactical agency / flee / telegraph / SPAR final decisions

- **Real production tactics: BLOCKED.** Base sword daemon only inherits SKILL;
  no starter special mapping exists. Basic force recover is small but requires
  a mapping and 20 force, neither currently owned. Existing typed resource/busy
  authorities could implement its mechanics, but granting a new skill/loadout or
  progression route is not justified by this encounter evidence. Registry remains
  empty, queue infrastructure is not marked meaningful player agency.
- **Flee: BLOCKED.** Lack of escape is an actual playability limitation against
  stronger foes. Native `WorldLocationState` identifies map/zone/combat location;
  encounter trigger captures that location, while physical bodies freeze at entry.
  Neither is a validated alternate landing, exit selection or pursuit contract.
  Existing portal gates cannot be replaced with spawn/menu teleport. Owner must
  settle the smallest world escape/destination and vendetta semantics first.
- **Telegraph: V1 GAP / integration blocker.** No special commitment producer
  exists for these sword-only NPCs. Fat's combat chat/help request is not one.
  Do not label ordinary autonomous attacks as countdown specials. Authoring a
  real producer is further implementation, not a final-audit chore.
- **Armed SPAR: integration blocker, not current Old Pine entry blocker.**
  Both normal Attack/aggression request LETHAL. `combatd.c` applies weapon wounds
  before friendly relationship removal; `std/char.c` checks mortal effective
  resource first. CXR8 `SPAR_MORTAL_WOUND` remains fail-closed, covered by its
  unchanged 158-assertion regression. No invented HP clamp, revive or mode switch.

## Deterministic authored-state matrix

Godot 4.7.2 PCG production adapter; combat seeds 103/211/509, NPC initialization
seed 7021 held equal before/after. Three actual authored NPCs, all original
attributes/resources/raw skills/equipment/content profiles; one-second scheduler
cycles through production entry, Core and lifecycle. Isolated boundary tests place
the player's logical location alongside the chosen NPC, then call typed entry;
this is NOT physical acceptance. Only the before comparator sets experience 10.
Tests print observations, not a required win-rate; 300 cycles is a test timeout,
not gameplay tuning. W/L means authoritative Victory/Defeat, including unconscious
defeat. Values are current/effective kee observed immediately after resolution.

| Seed | NPC | Before: result/cycles/player/enemy | After: result/cycles/player/enemy |
| ---: | --- | --- | --- |
| 103 | scout | L/13/-1,-1/200,200 | W/17/220,220/-1,-1 |
| 211 | scout | L/18/-1,-1/200,200 | W/33/143,143/-1,-1 |
| 509 | scout | L/12/-1,-1/200,200 | W/41/42,42/-1,-1 |
| 103 | tall | L/15/0,0/220,220 | L/32/-1,-1/163,163 |
| 211 | tall | L/15/-1,-1/220,220 | L/42/0,13/148,148 |
| 509 | tall | L/19/-1,-1/220,220 | L/57/-1,-1/120,120 |
| 103 | fat | L/26/-1,-1/220,220 | W/53/52,52/-1,26 |
| 211 | fat | L/22/-1,-1/220,220 | W/47/86,98/-1,24 |
| 509 | fat | L/15/-1,-1/220,220 | L/48/0,4/30,60 |

Before 0/9 wins, all enemies unhurt; after 5/9, with scout 3/3, tall 0/3 and
fat 2/3. This is a small comparison, **not an estimated population win-rate**.
Longer after fights (17–57 cycles) retain danger/difficulty; no runaway 300-cycle
outlier or resolution failure. Character/current-resource zero after unconscious
Defeat and dead NPC positive effective kee are existing lifecycle behavior, not
new death thresholds. No further tuning was inferred from the losses.

## Final Fresh New Game acceptance — NO QA STATS / TELEPORT / GUARANTEED RNG

All live routes used canonical ApplicationShell New Game, defaults with randomized
production sources, real input events/physics and actual UI. No injected policy,
stat/HP/skill adjustment, direct attack/completion/death/traversal or QA seed.
Observer metadata retains only a scheduler reference; observations do not advance
it. Read-only checks are not claimed as the cause of player actions.

| Final route | Cycles | Player current/effective kee | Result / follow-up |
| --- | ---: | --- | --- |
| Fresh southward natural scout 2 aggression | 39 | 89/103 | Victory, same Session thaw |
| Clean-process Fresh scout 3 selection + Attack | 27 | 169/197 | Victory, real corpse/loot/Save below |
| Fresh westward Fat aggression | 30 | 77/77 | Victory, continued physical movement |
| Same wounded character walks farther west into Tall | 21 | -1/-1 | Defeat/dead; Tall 220/220; explicit result + corpse |

The last row is intentionally **not** a fresh full-health Tall comparison; the
matrix above supplies that controlled comparison. A prior post-balance manual
scout run also won in 30 cycles (62/95) before the non-modal heading correction.

The first final run had 47 forward and 15 reverse attacks (aggregate outcomes:
29 dodges, 19 parries, 14 hits), 25 guarding opportunities and one nonzero-busy
observation; the clean manual run had 23 forward + 10 reverse (16 dodges,
9 parries, 8 hits), 18 guards, no nonzero busy-after. Fat had 33 + 8 attacks,
20 dodges/8 parries/13 hits and one nonzero-busy observation. Tall had 17 + 8,
16 dodges/6 parries/3 hits. These include both sides, not just player attacks.

Battle was held at cycle 5 / player 220 across Pause observations, then real
Escape resumed it. Active Save eligibility = 17 (ACTIVE_COMBAT_ENCOUNTER).
Clean manual battle clicked the actual enemy card: `Target: Changed`, projected
semantic ID `oldpine.outdoor.south_slope.spath1.bandit.3.character`. The single
hostile makes the control usable but strategically trivial; no multi-target or
real-action/queue gameplay claim is made.

After the clean manual win, the player physically walked to (538,747.334), clicked
the corpse and Open Loot, then real Take. The scout's exact short-sword instance
became a direct player child alongside the starting long sword. Silver x3 stayed
in the corpse. Closed Loot, real Pause -> Save -> `Your journey was saved.` /
outcome SUCCESS. Development profile; native repository performed normal slot
replacement/backup. Session identity `315831093886` was unchanged across entry,
return and successful Save; 13 registered items = original 12 + one corpse.

## Desktop liveness / limitations

Final clean run `r17654777-5`: helper_live/session_active/game_capture_ready true;
launch `current_run_errors=[]`; game log inspected after all routes, no errors.
Non-stale framebuffer 9251 shows Victory + actually looted corpse; frame 25817
shows Defeat/dead result and world corpse. Previous final-run frame 8730 captured
live LETHAL participants, resources, current target, ordinary feedback and honestly
empty Quick Actions. Frame counters are only compared within the same process.

One earlier observer mistakenly called nonexistent `InventoryState.direct_item_ids`
instead of `direct_children`; this triggered a debugger break, not a production
fault. It occurred after real Take input but that route's transfer/Save evidence
was discarded and repeated successfully in the clean process above. No gameplay
code was changed to cure the debugger error. Failed initial click on scout 1 was
occluded by the desktop HUD; selecting visible scout 3 worked normally. Broad HUD
occlusion redesign remains outside this slice, not a combat authority defect.

Bounded desktop paths PASS; full V1 playability does **not** PASS. A 30–60 second
autonomous fight is legible, but much of it remains passive waiting. No softlock
occurred in these normal LETHAL paths; armed-SPAR fail-closed is a separate risk.

## Mobile affected-path evidence

`adb devices -l` returned only `emulator-5568 offline`; no online physical device.
Changed balance and result heading Android requalification is **PENDING**, not
inherited from CXR8. No APK installed or package/save cleared this slice. No iOS
runtime PASS claim. Touch/layout/lifecycle automated tests below pass but are not
device proof. Real queue and flee mobile paths remain unavailable with no policy.

## Focused and complete automated verification

All counts below are assertions; every final runner has **0 failures**. Runners
overlap; do not add them as a unique total. Logs are local ignored `build/cxr9-*`.

| Runner (`game/tests/run_..._tests.gd`) | Assertions |
| --- | ---: |
| cxr9 | 234 |
| cxr8 | 158 |
| cxr7 | 149 |
| cxr6 | 148 |
| cxr5 | 240 |
| cxr4 | 791 |
| cxr3 | 719 |
| cxr2 | 736 |
| phase_10b4 | 1091 |
| phase_10c2a | 3597 |
| phase_10c2b | 221 |
| phase_10c2c | 533 |
| phase_9b3b3 | 2467 |
| phase_8b1 | 2218 |
| phase_8b2 | 3948 |
| phase_5b3b2b | 888 |

- Full canonical `godot --headless --path game --script res://tests/run_tests.gd`:
  **RUN / PASS, 15,994 assertions**, exit 0; includes CXR9 and all historical
  Character/Skill/Combat/Equipment/Armor/NPC/world/death/Save/Shell coverage.
- Godot version `4.7.2.stable.official.ed1daf0bf`; headless editor PASS after final
  code correction. Steam editor live game also reports 4.7.2. Repository/static
  checks PASS; `git diff --check` PASS.
- Extra Python tooling check on owner-dirty tree: **45/46**, one existing config
  assertion fails because owner's `project.godot` removed explicit desktop viewport
  1152x648 entries. Original hash matches preflight: not caused/fixed by CXR9.
  Clean HEAD archive plus exact CXR9 code overlay (tracked project config intact):
  **46/46 PASS**. Initial archive omitted `.github`; its four missing-file errors
  were corrected by copying the unchanged workflow into that disposable archive.
  No test weakened and no owner config overwritten. This distinction must remain
  visible; do not report the dirty tree as 46/46 PASS.

CXR9 tests lock exact product/NPC state, twelve items, no special mappings or
force grants, generic prototype 10, saved 10 restore unchanged, source-derived
power literals, no false result on each failure outcome, SPAR message, repeated
and independent-session result idempotence, no input overlay, no presentation
resource/progression/RNG mutation, and termination through actual authority.

## Distinct architecture self-audit

Reviewed production diff independently after focused validation. Only four
production scripts changed (48 additive lines): New Game content assignment and
three presentation/HUD scripts. Existing coordinator, scheduler, Core, queue,
target, lifecycle, items, NPC definitions, Save/restore and random adapters are
unchanged. Presentation ID tracking is local, non-persisted deduplication, not a
second encounter/result owner. Its only mutation is text in existing HUD widgets.

No new combat engine/scheduler, second queue/target, UI damage/resource/RNG/
lifecycle/completion authority, gameplay Timer, ATB/readiness/cooldown, active
Encounter Save, fake telegraph, QA registration, generic invented skill, flee
teleport, mass rebalance, CXR10 work or Phase10D work. Numeric production change
is solely the separately justified 600 entry value. Semantic states still decide
results before presentation; no animation or acknowledgment delays completion.

Exact LPC paths inspected for the decisions (under `reference/es2/mudlib/`):
`adm/daemons/combatd.c`, `feature/skill.c`,
`feature/damage.c`, `feature/attack.c`, `std/char.c`, `std/skill.c`, `std/force.c`,
`daemon/skill/force.c`, `daemon/skill/sword.c`, `cmds/std/perform.c`,
`cmds/std/exert.c`, `cmds/std/go.c`, `cmds/usr/wimpy.c`,
`d/force/recover.c`, `d/force/refresh.c`, `d/force/regenerate.c`,
`d/oldpine/npc/bandit.c`, `d/oldpine/npc/tall_bandit.c`,
`d/oldpine/npc/fat_bandit.c`, `d/oldpine/pine1.c` (valid_leave).
No imported active skill or new legacy formula. Legacy oddities are not corrected.

## Part 1 historical blockers / CXR10 entry criteria

**CXR9 BLOCKED / PARTIAL; CXR10_READINESS = BLOCKED.** Narrow bootstrap/result
fixes are implementation-tested, not complete Active Semi-Auto V1. Need owner
direction and another explicitly authorized implementation slice for real starter
tactical content/availability, physical flee destination and vendetta behavior,
a real telegraph producer, and armed-SPAR mortality compatibility. Then qualify
affected Android paths and rerun normal-player acceptance. Final audit must not
secretly implement these features. No permission to silently drop required V1 scope.

Final art/VFX/audio, broad balance, accessibility/localization, CXR10 integration
and Phase10D resumption remain deferred. Same major branch only; no PR/merge or
CI/release flow started. Owner's 120 original dirty paths rehashed unchanged;
`reference/es2` and `DECISIONS.md` have zero modifications. Delivery commit is
recorded in git/final report, without embedding a self-referential SHA here.

# V1 Closure Continuation

## Owner decisions and current implementation checkpoint

The owner authorized continuation on the same branch from Part 1
`f22fc7fb9dfcb00a75917112f16ba0e840875e35`, without CXR10, PR, merge or Phase10D
work. Preflight fetch confirms upstream 0/0. All 120 owner-dirty plugin/project
paths were enumerated with SHA256/deletion states; none is part of these edits.

The following supersede the unresolved decisions in the historical Part 1 text:

- Current tactical floor is target selection plus real production Flee through
  the existing queue. No starter martial/force/spell/item content is required.
- Legal Flee executes deterministically at the command boundary, blocked by busy
  at execution but not request time. No cost, gameplay RNG, exit lottery or teleport.
- Return in place through the same Session; reconcile included opponent/lethal
  relations without persistent pursuit/vendetta in V1. No reward/heal/corpse.
- Aggression must require physical leave/reenter, never a timer immunity window.
- Telegraph is conditionally satisfied/dormant: current ordinary-sword content
  has no qualifying producer. Empty technique categories are extension seams.
- Supported SPAR must reject any primary weapon before establishment; keep mortal
  wound fail-closed as defense-in-depth, with no clamp/revive/automatic unwield.
- Unavailable physical Android may remain an explicit CXR10 final-audit/merge
  gate, not an implementation-completion blocker; no device PASS is inferred.

Partial working-tree implementation registers `combat.flee`, SELF/FLEE metadata,
mode validation (LETHAL/SPAR only), catalog label, typed DISENGAGED execution
outcome, synchronous command-result return to resolution, immediate ordinary-batch
stop, FLED subject/player result without winner/loser, existing relationship/thaw
composition, and successful Escaped feedback. Direct completion without a derived
non-scripted result is rejected. These are not yet complete acceptance claims.
SPAR establishment now returns `SPAR_WEAPON_NOT_ALLOWED` before world freeze.

## Interrupted checkpoint — unarmed zero apply-damage (subsequently resolved)

The approved unarmed-only decision exposed a separate, previously masked conflict:

1. `CombatSliceContentProfile.projected_apply_damage(null)` returns **0**.
2. LPC `adm/daemons/combatd.c::do_attack` unconditionally computes
   `(damage + random(damage)) / 2` before the separate strength bonus.
3. `adm/daemons/race/human.c` default unarmed action and `chard.c::setup_char`
   provide no positive `apply/damage` floor. Neither authorizes gifting damage.
4. The already-closed `CombatAttackResolver` rejects `damage <= 0` at
   `APPLY_DAMAGE_RANDOM_BOUND`, per the existing DECISIONS entry for non-positive
   random bounds. The local MudOS `doc/efuns/random` specifies only `[0,n-1]`;
   it does not prove the historical driver's zero-bound behavior.
5. The CXR8 normal-SPAR fixture previously wielded swords. With both participants
   explicitly unwielded before establishment, its first reached hit produces
   `INVALID_SOURCE_STATE / APPLY_DAMAGE_RANDOM_BOUND`, then encounter resolution
   `INCOMPLETE_ATTACK_CHAIN`, not `SPAR_CONCLUDED`.

Reproduction: pinned Godot 4.7.2, `run_cxr8_tests.gd`:
**158 assertions, 2 failures** (normal friendly conclusion and completion receipt).
All other assertions pass, including the retained mortal-wound defense and the
updated controlled cleanup through production queued Flee. Diagnostic log:
`build/cxr9-closure-cxr8.log` (local ignored artifact). The test guards the absent
receipt instead of throwing a secondary Nil-method error; it still fails honestly.

This is not a request to reconsider owner decisions A–H. Completing normal unarmed
SPAR requires a new narrow zero-base-damage compatibility choice outside those
decisions and conflicting with a locked Combat Core invariant. No Core formula,
RNG adapter, positive minimum, HP clamp, fake damage fixture or test weakening has
been applied. Work pauses for that choice. Remaining focused/full validation,
new closure coverage, real Fresh New Game Flee/Area rearm/input/Save proof,
physical Android check, final architecture audit, commit and push are unfinished.
No COMPLETE/READY claim is made and CXR10 has not started.

## Authorized zero-base resolution

The owner subsequently answered **授权** to the specifically proposed exception:
empty-primary-hand base damage exactly zero contributes a zero base random term,
without a draw, then runs all remaining original calculations. Armed zero and
negative damage still reject; there is no positive floor or general RNG change.
This is recorded separately in DECISIONS, not asserted as known MudOS behavior.
The previous 158/2 CXR8 result is historical reproduction, not the final result.

## Flee architecture and queue/busy behavior

Production registers exactly `combat.flee` in each coordinator's existing typed
registry. `CombatFleeTacticalPolicy` supplies FLEE/SELF/busy metadata, read-only
request/execution validation, and only a `DISENGAGED` execution result. It receives
no Session, world, movement or completion authority. `supports_mode` exposes the
action only in LETHAL/SPAR; SCRIPTED remains controlled and rejects this request.
The presentation catalog supplies only the label; its entries cannot enable actions.

The existing path is:

`Battle input -> CombatTacticalRequest -> existing one slot -> command boundary
-> DISENGAGED -> CombatEncounterResolution.FLED -> existing coordinator completion`.

Validation checks current encounter/player, exact Character/Relationship/Busy/Armor
authorities, life/availability, gate, category and SELF identity. Binding wrappers
are copied, so comparing wrapper object identity would be incorrect; their actual
authorities must match. Queue consumption precedes execution. Replace/cancel and
duplicate-request rules remain unchanged. Busy 2 -> 1 -> 0 consumes the original
ordinary busy opportunities; the **next command boundary** executes Flee, not the
middle of the busy-decrement opportunity. Pause/background retain the exact request;
foreground still requires explicit Resume and does not accumulate catch-up time.

After DISENGAGED the scheduler returns before adding delta, any ordinary opportunity,
RNG, damage or progression. The resolution supplies FLED with no winner/loser and
the player as subject. Direct caller-injected FLED without a derived result is
rejected. No second queue/scheduler or effect-ID-based command dispatch was added.

## Relationship/world return and aggression re-arm

Existing resolution reconciliation visits **every included pair**, removes both
opponent/lethal relations, and clears guarding only if no fight remains. Busy,
resources, progression and unrelated authorities are untouched. Save still asks
`OldPineSaveEligibility`; FLED is not a Save exception. A fixture with remaining
NPC busy correctly remains ineligible, while a safe fixture and actual player Save
succeed. Thaw/gate-release failures retain the prior one-way RESOLVING receipt:
no retry, false Escaped message, new encounter, or cadence restart.

The frozen player's exact transform is retained, not reapplied/teleported. After
completion the same Session/body resumes and the old OpportunityTimer stays stopped.
No corpse, loot, reward, heal or resurrection is produced. Multi-opponent coverage
uses player+A+B and verifies all pairs, not just the current target.

Physical validation proved the existing aggression presence-clear behavior sufficient:
120 physics frames at the same overlap do not retrigger; actual exit and reentry
create the next encounter. **No new aggression latch, timer immunity or world code**
was needed. Persistent pursuit/vendetta fidelity remains explicitly outside V1.

## SPAR compatibility and telegraph closure

SPAR checks every resolved participant's authoritative primary-hand absence before
relationship validation/freeze; each armed participant yields
`SPAR_WEAPON_NOT_ALLOWED` without auto-unwield. Tests explicitly prepare empty hands,
then run the real ordinary unarmed resolver to positive friendly damage,
relationship removal, `SPAR_CONCLUDED`, no corpse and unchanged physical transform.
The old controlled fixture's large skill/experience/health values are test setup,
not production/New Game grants. The existing `SPAR_MORTAL_WOUND` test remains.

Telegraph is **CONDITIONALLY SATISFIED / DORMANT**. Current authored scouts/Tall/Fat
use ordinary sword behavior, not enemy tactical specials or committed heavy casts.
There is no TELEGRAPH_STARTED producer/event emission, UI or countdown. The 18-seed
ordinary-battle regression now explicitly checks that no tactical events are
manufactured. No fake enum/producer/skill was introduced to populate an empty UI.

## Fresh New Game live evidence

Canonical ApplicationShell; production experience 600, HP 220, normal equipment,
skills and random source. **NO QA STATS, NO QA TELEPORT, NO GUARANTEED RNG**.
No direct start/execute/complete calls. Native mouse/keyboard/action input performs
the routes; observation-only retained references/transform metadata do not mutate
game authority. Live input timing and exact busy/RNG ordering are separate evidence.

| Route | Observed result |
| --- | --- |
| A: Menu -> New Game -> walk -> click scout -> Attack -> Flee | PLAYER_LETHAL_ATTACK; FLED, unchanged transform/HP220, zero ordinary events in the observed encounter, Battle hidden, gate open, no corpse. |
| A: walk away -> Pause -> Save | Same Session `321149471371`; real Save success `Your journey was saved.` using normal eligibility. Non-stale frames 5510 and 9777. |
| B: fresh New Game -> walk south into Area -> mouse Flee | Natural NPC_AGGRESSION, no direct trigger. First run retained HP176/events62 across escape and 120 stationary physics frames. |
| B clean repeat after observer error | Fresh Session `319807293950`, HP220/exp600 at spawn450,300. Encounter1 at450,751.000732; mouse Flee retains HP197/events8/exact transform across 120 physics frames. |
| B: walk away -> physically reenter -> Enter | Walk to450,619 with no encounter/pending aggression, return into Area creates encounter2/NPC_AGGRESSION; default focused Flee accepted by actual Enter, FLED at same450,751.000732. |

Clean final run `r28367103-8`: helper_live/session_active/game_capture_ready true,
launch current_run_errors=[], no game errors; live frames **7229 -> 9124**, both
stale_frame=false. Screenshot shows two natural aggression/Escaped log pairs and
the restored world. Game stopped normally after evidence collection.

An earlier stale editor class cache caused a boot parse failure; stop/scan/relaunch
resolved it without code changes. Later a QA observer mistakenly read
`CharacterState.resources` instead of `vitality`, causing a debugger break; this was
not a gameplay failure. That route was rerun cleanly as above. Neither error is
silently counted as a clean run. Immediate native input dispatch is asynchronous;
the exact queued-before-execute assertion is proven in the controlled input tests,
not inferred from a race-prone live read in the same input call.

Busy timing is deterministic automated evidence (not claimed as naturally captured
busy input). Real mouse and keyboard Flee succeed. Controller A and Viewport touch,
64px minimum targets, no world click-through, Log Back before root Pause, and
Home/foreground explicit Resume are covered in the real Shell test fixture.

## Android status

Latest `adb devices -l` returns no online device (earlier only an offline emulator).
No final APK/physical touch PASS is claimed. `ANDROID_EMULATOR = PENDING`;
`ANDROID_AFFECTED_PATH_GATE = PENDING`. Under the explicit owner boundary this does
not block CXR9 implementation completion, but stays a **CXR10 final-audit/merge
gate** requiring affected-path physical evidence or an explicit owner waiver.

## Distinct architecture self-audit

After tests, independently reread the complete production diff and the existing
validation/completion/reconciliation bodies. PASS: the typed execution result,
not an effect ID, controls the command stop; only resolution/coordinator owns FLED
and thaw. The original lifecycle barrier runs before tactics and after ordinary
opportunities. Failed return stays fail-closed and success text requires a completed
receipt. No UI/policy completion, world mutation, RNG/cost/chance, second queue or
target authority, Timer grace, generic callback, starter force/mapping grant,
SPAR clamp/revival, active-Encounter serialization, or legacy cadence resurrection.
No CXR10 or Phase10D implementation. Per-instance catalogs/registries and stateless
Flee policies introduce no shared mutable gameplay state.

One mode-matrix fixture now uses one busy opportunity for each participant, avoiding
a random normal-SPAR conclusion inside an establishment-only assertion. This does
not change production timing or the separate real unarmed-SPAR conclusion test.
Earlier CXR7/CXR8 cleanup fixtures use the production queued Flee boundary rather
than injecting an artificial FLED result. Dedicated closure tests remain under the
existing CXR9 runner and canonical runner, not a new slice.

Additional LPC files read in this continuation, under `reference/es2/mudlib/`:
`cmds/std/go.c`, `cmds/std/fight.c`, `cmds/std/kill.c`, `cmds/std/perform.c`,
`cmds/std/exert.c`, `feature/attack.c`, `std/char.c`, `adm/daemons/combatd.c`,
`adm/daemons/chard.c`, `adm/daemons/race/human.c`, `d/force/recover.c`,
`doc/efuns/random`; targeted attribute/skill dependency searches established no
authored positive unarmed apply-damage floor. The Part 1 source list remains above.

## Final tests and verification

Pinned `4.7.2.stable.official.ed1daf0bf`; each listed runner exited 0 with no
GDScript errors. Counts overlap; do not add focused totals to the canonical count.

| Runner | Assertions | Failures |
| --- | ---: | ---: |
| run_cxr9_tests.gd | 368 | 0 |
| run_cxr8_tests.gd | 159 | 0 |
| run_cxr7_tests.gd | 149 | 0 |
| run_cxr6_tests.gd | 148 | 0 |
| run_cxr5_tests.gd | 240 | 0 |
| run_cxr4_tests.gd | 791 | 0 |
| run_cxr3_tests.gd (includes resident world/portal/aggression) | 719 | 0 |
| run_cxr2_tests.gd | 736 | 0 |
| run_phase_5b2a_tests.gd (zero-base compatibility) | 664 | 0 |
| run_phase_10b4_tests.gd (Save/restore/corpse/Session) | 1,091 | 0 |
| run_phase_10c2a_tests.gd | 3,597 | 0 |
| run_phase_10c2b_tests.gd | 221 | 0 |
| run_phase_10c2c_tests.gd | 533 | 0 |
| **run_tests.gd, complete canonical including relationships/Shell** | **16,132** | **0** |

Final logs: ignored `build/cxr9-closure-final-run_tests.log`,
`cxr9-closure-final-run_cxr9_tests.log`, `cxr9-closure-final-run_cxr8_tests.log`;
other focused logs share `cxr9-closure-` prefix. The earlier full 16,105 pass was
followed by final 16,132 after adding explicit negative-feedback/telegraph/transform
coverage; it was not a retry to conceal a failure.

- Headless editor PASS. Initial sandbox user-directory/certificate/ADB access
  failures were rechecked in the normal workstation context, without config changes.
- `tools/ci/repository_checks.py`: PASS.
- **OWNER WORKTREE CHECK:** Python 45/46, exactly the existing missing desktop
  viewport-width field in owner `project.godot`; not called PASS or silently fixed.
- **TRACKED CLEAN OVERLAY CHECK:** Python 46/46 using `git archive HEAD` plus only
  CXR9 changed/new files under ignored `build/cxr9-closure-clean-overlay`. Original
  tracked project/plugin settings are retained there; owner worktree is untouched.
- `git diff --check`: PASS; full changed CXR9-file trailing-whitespace scan: 0.
- `reference/es2` modifications: 0. Original owner dirty paths: 120, SHA256/deletion
  states unchanged. No owner project/plugin file staged. DECISIONS edits are only
  the explicitly authorized SPAR/Flee/zero-base compatibility choices.

## Final V1 closure matrix

| Capability | CXR9 closure |
| --- | --- |
| Ordinary auto combat / automatic defense | PASS; existing core and cadence retained |
| Target selection / multi-opponent model | PASS; exact current/queued distinction |
| One-slot queue / real production agency | PASS; target selection plus Flee |
| Martial/Internal/Spell/Item actions | Extension seams; no authored starter content |
| Flee | PASS; deterministic, busy-blocked, RNG/cost-free |
| Enemy telegraph | CONDITIONALLY SATISFIED / DORMANT; no qualifying producer |
| SPAR | PASS; unarmed-only with explicit zero-base exception |
| LETHAL / SCRIPTED | PASS; SCRIPTED does not gain Flee implicitly |
| Battle feedback/log / result feedback | PASS; Escaped only after successful completion |
| World return / aggression re-arm | PASS; same position, physical exit/reentry |
| Corpse/loot | PASS regression; Flee creates neither |
| Save/lifecycle | PASS; original eligibility and explicit Resume |
| Physical Android changed path | PENDING CXR10 final-audit/merge gate |

## Delivery boundary and deferrals

CXR9 implementation COMPLETE; CXR10 readiness READY. Part 1 SHA:
`f22fc7fb9dfcb00a75917112f16ba0e840875e35`. Closure implementation/final SHA is
reported with the git delivery to avoid a self-referential commit hash here.
Same `phase/combat-experience-redesign` only; no PR, merge, new CI qualification,
CXR10 execution or Phase10D resumption. This is implementation completion, not
fully integrated main. Owner files remain intentionally dirty after the commit.

The next CXR10 instruction may authorize **final audit / validation / PR / CI /
merge**, not additional gameplay implementation; readiness alone does not start it.
Authored techniques/internal/spell/item content, advanced enemies/real telegraphs,
pursuit/vendetta fidelity, armed/practice-weapon SPAR, final art/VFX/audio, broad
balance, accessibility/localization, and the physical Android gate remain deferred.
Phase10D remains PARKED / FROZEN. Stop and await owner review.
