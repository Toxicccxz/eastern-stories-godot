# CXR7 — Multi-Opponent Targeting + Encounter Mode Completeness

Implementation and desktop runtime validation complete, 2026-09-07.
Branch: `phase/combat-experience-redesign`; starting HEAD:
`935da01329f3e8dcebda98abe87947491476ce9a`. This is a slice, not major-phase integration.
No PR, merge, CXR8, or Phase 10D continuation. Physical mobile requalification remains pending.
Implementation commit: `7a248b676c825efa2914f7d1e4bfcc2b232a0787` (34 files, including UID metadata).

Changed groups: existing Encounter latest-event read; coordinator/scheduler/start result and four
new typed target/mode/event classes; six existing Battle presentation scripts; new CXR7 runner,
test and QA fixture/harness; canonical runner; CXR3/4 and mobile-layout expectation corrections;
this phase record and STATUS/ROADMAP. Exact file inventory: `git show --stat 7a248b6`.

## Discovery and plan

Reviewed root/docs AGENTS, STATUS/ROADMAP, repository/tooling policy, CXR0/CXR1 design and
CXR2–6 ownership/contracts against the current Encounter, coordinator, scheduler, tactical runtime,
Battle projection/intent/UI, Session bindings, shared Shell/input/layout and existing world entry.
No unfinished previous phase was discarded. Thirteen preexisting local changes (twelve Godot AI
plugin files and `game/project.godot`) belong to the owner, were SHA-256 checked before/after,
and are excluded from the CXR7 commit. The plugin upgrade is not a migration decision.

Inspected authoritative LPC:

- `reference/es2/mudlib/cmds/std/fight.c`: accepted speaking-target fight establishes reciprocal
  `fight_ob`; the non-speaking branch instead produces reverse `kill_ob`. Thus a fight command
  name alone is insufficient evidence for SPAR.
- `reference/es2/mudlib/cmds/std/kill.c`: initiator kills; NPC reciprocates kill, player target
  reciprocates fight. Directed lethal intent must not be coerced into symmetric lethal intent.
- `reference/es2/mudlib/feature/attack.c`: separate enemy/killer collections, fight/kill mutation,
  cleanup, legacy random opponent selection, encounter-entry hatred/vendetta/aggression detection.
- `reference/es2/mudlib/adm/daemons/combatd.c`: `auto_fight` excludes NPC-to-NPC initiation;
  `start_aggressive` and `start_vendetta` recheck availability/location/no_fight and invoke
  initiator `kill_ob`. Their discovery/permission policies are not reimplemented here.

Relevant native seams include `core/combat/relationship/combat_relationship_state.gd`,
`runtime/combat_slice/combat_slice_opportunity_executor.gd`,
`runtime/world/oldpine_bandit_aggression_adapter.gd`, and
`runtime/world/oldpine_outdoor_controller.gd::attack_selected`. Normal Attack still calls the
existing lethal-combat slice; aggression and its established relationship mutations remain intact.

Plan implemented: narrow typed target intent/result; share existing target eligibility and stable
selection; bridge existing target events into ordered feedback; validate mode/relationship facts;
make participant cards native input controls; focused tests, distinct self-audit, then actual UI.

## Target authority and event path

`BattleParticipantCard` emits only a semantic participant ID. Controller forwards displayed
encounter ID and target through `BattleIntentAdapter` → `CombatTargetRequest` →
`CombatEncounterCoordinator.change_player_target` → the existing `CombatEncounter` target slot.

Receipt checks active identity/phase, Session application permission (including detached/suspended
Session), gate owner, exact player membership, full current binding identity, actor availability,
target availability/life/location, directed side hostility AND the actor's actual opponent fact.
Busy does not reject target selection. Invalid requests preserve the old target and queue; they
do not select a fallback, execute a policy, spend resources, advance time, or consume RNG.
Selecting an already-current valid target returns typed UNCHANGED and emits no duplicate event.

Only Core owns current targets. `CombatTargetResult` has a closed result code, not arbitrary data.
The scheduler's advisory `can_target` and exact-binding check are reused for projection and receipt;
projection is not permission authority. No second target cache controls gameplay.

A successful change emits the existing `CombatEncounterEvent.TARGET_CHANGED`. The narrow
`CombatOrderedTargetEvent` wrapper gives that defensive Core event a position in the existing
shared tactical/ordinary `CombatProgressionOrder`. It neither duplicates target state nor owns
execution. Incremental suffix reads do not replay old events or clone entire history each frame.
Core `latest_event()` provides one defensive event snapshot for this bridge.

## Ordinary target selection and accepted queue

CXR1 §15 explicitly requires a valid current hostile or another permitted hostile. CXR4 selected
the first eligible participant only when no target existed and otherwise skipped stale targets.
CXR7 extends that SAME stable-order selection to invalid targets: the first eligible participant
in Encounter insertion order is chosen; if none exists the old target is cleared and the ordinary
opportunity is skipped. Both changes emit the normal Core event. Busy advancement remains before
selection and the ordinary executor/forward-reverse pipeline is unchanged.

This is the approved CXR1 deterministic orchestration policy, NOT a claim that LPC
`select_opponent()` was deterministic (it uses `random(MAX_OPPONENT)`). There is no new random draw,
distance/threat/aggro weighting, or damage formula. CXR4's old no-fallback test expectation is updated
explicitly; its historical phase document remains historical.

The executable one-slot tactical queue remains owned by Encounter. Its accepted `resolved_target_id`
does not change when current target changes. Existing tactical execution revalidation may reject
an unavailable queued target; it never redirects that accepted action to the new ordinary target.
Replacement, sequence/correlation and stale cancel behavior remain CXR5 behavior.

## Supported establishment matrix

| Cause | Supported mode | Required existing facts |
|---|---|---|
| PLAYER_SPAR | SPAR | Initiator is current player; initiator has a cross-side opponent; included fights are reciprocal, with no included lethal markers. |
| PLAYER_LETHAL_ATTACK | LETHAL | Initiator is current player and has an included cross-side opponent plus its directed lethal marker. |
| NPC_AGGRESSION | LETHAL | Non-player initiator has the current player as opponent and lethal target. |
| VENDETTA_HOSTILITY | LETHAL | Initiator has an included opponent/lethal target; the initiating pair includes the player, consistent with `auto_fight`. |
| SCRIPTED | SCRIPTED | Existing CXR3 authored-policy ID/topology checks unchanged, including NPC-only controlled encounters. |
| QUEST | none | Typed unsupported; no current quest establishment policy. |

Every other cause/mode combination is rejected. Contradictory same-side fight/lethal declarations
are rejected for the new non-scripted policies. Different sides alone never manufacture hostility.
LETHAL does not require reciprocal lethal marks or mark all members of a side lethal.

This boundary consumes **already authorized/established facts**. It does not replace command consent,
NPC `accept_fight`, aggression capability discovery, vendetta/faction discovery or no-fight detection.
Those callers remain responsible before a future production trigger is submitted. The current
controlled triggers exercise the typed entry; no world button or normal aggression was cut over.

SPAR is a nonlethal-intent mode, not a new damage engine or a clamp. The armed-friendly wound
inconsistency and exact spar conclusion threshold remain deliberately unresolved. LETHAL uses the
same scheduler/Core and does not infer victory/death. Existing mode/result compatibility is retained:
SCRIPTED/SCRIPTED result, SPAR/SPAR_CONCLUDED or FLED, LETHAL/VICTORY, DEFEAT or FLED. No result is
automatically generated in CXR7. Test FLED results are controlled cleanup, not implemented fleeing.

## Presentation and input

Participant cards use native Buttons over existing value displays, not callbacks into Core.
Gold denotes authoritative current target; cyan denotes keyboard/joypad focus. A separate
QUEUED TARGET label identifies accepted target even when the authored NPC display names match.
Unavailable/nonhostile/self targets are disabled. Native horizontal scrolling/follow-focus handles
3+ participants at narrow widths; no hardcoded player/enemy pair or two-side restriction.
Mode labels come from Encounter. Production Quick Actions remain empty; probes are tests only.

Shared `ExplorationPresentationBlocker`, SafeArea, child-first Log dismissal, non-dismissable
Battle root, Shell Pause/Resume, held-input quarantine and restore/reparent support remain in place.
No new UI timing, second scheduler, resource authority, generic callback registry, or presentation RNG.

## Automated validation and separate self-audit

Godot 4.7.2 stable Steam (`ed1daf0bf`). Final focused results:

| Runner under `game/tests/` | Passing assertions |
|---|---:|
| run_cxr7_tests.gd | 149 |
| run_cxr6_tests.gd | 148 |
| run_cxr5_tests.gd | 240 |
| run_cxr4_tests.gd | 791 |
| run_cxr3_tests.gd | 719 |
| run_cxr2_tests.gd | 736 |
| run_phase_10c2a_tests.gd | 3,597 |
| run_phase_10c2b_tests.gd | 221 |
| run_phase_10c2c_tests.gd | 533 |
| Total executed focused assertions (overlapping regressions) | 7,134 |

CXR4/3 runners include existing ordinary opportunity, Session/resident-map and portal/aggression
regressions. CXR2 includes character, combat foundation and relationship regression. CXR6 covers
restored Session reparent/Continue, input quarantine, queue replacement and lifecycle. These are
focused run counts, not unique tests or a complete historical-suite claim. Canonical runner includes CXR7.

New tests cover invalid/self/nonhostile/same-side/missing/unavailable/stale targets; exact binding,
gate and suspended-Session rejection; busy selection; receipt invariants; event ordering/idempotence;
accepted A executing while current B; stable fallback/clear; three sides; cause/mode matrix; exact
mode bindings/gate; UI touch/keyboard, queue highlight, Back/Resume and compact focus scrolling.

One existing layout regression assumed Session added only one SafeArea consumer. CXR6 already adds
the persistent Battle consumer as well as the current Outdoor HUD. The test now accounts explicitly
for Battle identity/subscription: Outdoor detach leaves Battle; Session teardown removes both. No
layout production behavior was changed to satisfy this historical count. Early new-fixture API and
typed-array mistakes were corrected; only clean final runs above count as passing evidence.

Separate production diff/source searches confirmed: no presentation resource/relationship/busy
mutation, policy execution, opportunity/advance call, direct target mutation, completion call, Timer,
gameplay RNG, generic Dictionary hook or test-policy dependency. No changes to Combat resolution,
Character/Skill/Equipment/Armor authorities, world/application production entry, death/corpse/loot,
Save, Phase10D or CXR8. `repository_checks.py`, headless editor, whitespace and `git diff --check` pass.
`reference/es2` and `DECISIONS.md` have zero changes.

## Actual runtime evidence

Initial connection was blocked by a 3.2.4 client against the owner's 3.2.5 backend
(`NEW_CLIENT_SESSION_REQUIRED`). The owner refreshed the connection; no plugin downgrade, source
workaround or gameplay change was made. Subsequent actual runs were live on Godot 4.7.2.

- Canonical ApplicationShell run `r116855-1`: actual mouse Continue restored `oldpine.cave`,
  Session `453622368956`, no active encounter. Non-stale frames 778 → 4048. No Save was written.
- Controlled production-UI harness `res://tests/runtime/cxr7_runtime_harness.tscn`, successful run
  `r385387-4`: real Enter on New Game created Session `203910285699`; original CharacterState
  identity remained equal across all mode transitions (exact ID is in the game log, avoiding
  float precision loss in tool JSON). One player + two NPCs on open sides A/B/C.
- Pre-route QA setup: isolated in-memory Save/settings, counting zero-return Combat RNG, aligned
  typed combat-location facts without teleporting bodies. Mode keys 1/3/4 establish SCRIPTED/SPAR/
  LETHAL; 2 supplies typed cleanup. This is not normal production entry or CXR8 outcome proof.
- Empty production registry: actual mouse switched A→B at cycle 59, RNG **826→826**, force **0→0**;
  keyboard Left/Enter returned to A at cycle 92, RNG **1288→1288**. Player position stayed `(450,300)`
  and world selection stayed null while ordinary cycles continued. Real joypad navigation/accept
  later switched B→A with RNG **4758→4758**, cycle **186→186**.
- SPAR `.live.2` at cycle 8, lethal list empty; LETHAL `.live.3` at cycle 9, player lethal list only
  NPC A, NPC reverse lethal list empty. Same Session and CharacterState, matching gate IDs, registry
  0 and no terminal result. Screens showed the authoritative mode labels, with live ordinary feedback.
- QA-only `.live.4` registers existing CXR5 Probe/Alternate and starts busy 30 before the route.
  Real viewport ScreenTouch events selected A, pressed Probe, selected B. All three steps observed
  busy16; queue retained A. Receipt RNG **2800→2800**, force **10→10**, cycle **14→14**, resolved0.
  Natural scheduler execution later yielded resolved1, force9, **A atman1 / B atman0**, current B,
  busy0, cycle44. No direct policy/callback/scheduler invocation was used as live execution proof.
- A second declared busy60 QA setup captured the visible WAITING_FOR_BUSY queue: current B gold,
  A QUEUED TARGET. Actual Pause held request `.live.4:2`, busy48, cycle108, RNG3951 unchanged across
  observations; real joypad Resume retained the same Session and queue. This request also later
  executed once (force8, A atman2, B0).
- Desktop-injected lifecycle loss/gain held cycle194/RNG4870 and required explicit Resume. Actual
  desktop focus notifications during QA left Resume disabled until gain was reissued; restored the
  desktop capability after that notification fixture, then real touch on the currently observed
  Resume rect resumed. This is notification-boundary integration, NOT device/OS lifecycle proof.
- Actual touch opened Combat Log, Escape closed only Log (Battle visible, unpaused); root Escape
  had already proven Shell Pause. No callback shortcut dismissed the Battle.
- Embedded viewport did not resize from 1152x648 on a requested Window resize; no physical-resize
  claim is made. Instead a declared QA SafeArea capability injected 800x480: content was exactly
  `(16,16,768,448)`. Real joypad navigation scrolled horizontally138 and selected the third card,
  whose button `(504,91,280,163)` was wholly visible. Receipt cycle319/RNG6620 unchanged.
- Typed cleanup restored world HUD on the SAME Session203910285699, map `oldpine.outdoor`, position
  `(450,300)`, gate open, no active encounter, Battle hidden. Game stopped after validation.

Successful run 4 had helper_live/session_active/game_capture_ready all true; no current-run errors
appeared in its game log. Non-stale screenshots include frames8663,13145,15925,21719,27113,55116,
60656. Two earlier QA read-only eval errors (mixed indentation, then reading an absent Session)
paused runs2/3; those runs were stopped, and their stale frames explicitly excluded from acceptance.
No production defect or rule change was inferred from those debugger mistakes.

## Deferred / next boundary

ADB listed no Android device or emulator. Physical Android target/multitouch/Back/SafeArea qualification
remains PENDING; iPhone/iPad evidence also pending. Desktop injected touch/joypad is not physical
hardware qualification, and historical Phase10D1 evidence does not cover this changed Battle UI.

No production tactical techniques, Quick Slots, telegraph/ATB/cooldown/preview, combat items, flee
execution, reinforcements, quest/faction discovery or balance work. CXR8 owns normal Attack/aggression
cutover, final resolution, death/corpse/loot and Save/lifecycle integration. Active Encounter Save
remains excluded. CXR7 readiness does not authorize CXR8; wait for the owner's next instruction.
