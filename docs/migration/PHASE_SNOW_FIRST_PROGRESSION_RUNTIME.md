# Snow First Progression Loop / 淳风武馆 — P2 implementation

## Outcome and authority

**P2 COMPLETE — LIVE ACCEPTANCE PASS; AWAIT OWNER FINAL-AUDIT AUTHORIZATION.**
The evidence-only rerun on frozen ZE1 `315d3863a5b72fbbb3f84006440d7b9e796bf512`
completed natural E2, physical return/Learn, Save, whole-process termination and exact
cold state/RNG restoration. See [the fresh acceptance record](#fresh-live-acceptance-2026-09-15-utc).
The original implementation evidence and superseded blocker below remain historical.
This is not Final Audit, PR readiness authorization or integration on main.

P1 `5780139b82fad932f6bc7786ea295c20602ae0a5` is OWNER APPROVED / CLOSED.
Owner authorized P2 A–F and this bounded implementation on the existing
`phase/snow-first-progression-loop` branch. Preflight found clean worktree/index,
HEAD and origin phase both at that P1 SHA; origin/main remained
`88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e`. No branch rewrite or new branch.
One P2 commit/push is authorized; no PR, merge, cleanup or next slice.

## Source and classification

Freshly inspected source under read-only `reference/es2/mudlib/`:

| Responsibility | Source |
|---|---|
| Executable topology and gate | `d/snow/{mstreet1,school1,school2,schoolhall}.c`, ROOM door behavior |
| Liu identity, 11 skills, effective qualification, class | `daemon/class/swordsman/master.c` |
| Pending, cancel, existing master, recruitment result | `cmds/std/{apprentice,recruit}.c`, `feature/apprentice.c` |
| Learn order, cost, gates and mutation | `cmds/std/learn.c`, `std/char/master.c`, `daemon/skill/unarmed.c`, `feature/skill.c` |
| Effective attributes and NPC spirit | `feature/attribute.c`, `std/char.c`, human/chard initialization |
| Combat consumption and persistence context | `adm/daemons/combatd.c`, player/save/damage dependencies traced in P1 |

Type A retains qualification, first recruitment facts, Learn integer formulas,
failure ordering, explicit raw0, spent potential, one source RNG draw and existing
combat projection. Teacher data retains all eleven source skill levels; only
basic **unarmed** is exposed. No experience gifts, rewards, balance changes,
combat modifiers, automatic skill grant or artificial raw cap.

Owner-approved Type B: one continuous physical three-zone cluster; local transient
two-sided gate; teaching contact rather than persistent NPC; active Session/map,
zone, placement, proximity, active life, noncombat/nonbusy and UI quarantine gates.
Busy prohibition is native contact staging, not a claimed LPC Learn rule.
Type C: none. The contact is explicitly **not full 柳 NPC parity**.

## Implementation and boundaries

- `SwordsmanApprenticeship` owns the narrow typed first recruitment chain. Failed
  effective cor/cps below20 leaves pending intent; repeated pending requests do
  not auto-retry. Cancel clears it and permits a new attempt. Fresh30/30 succeeds;
  exactly20 succeeds. Existing master acknowledgement preserves first time and
  betrayer count. Other-family switching remains unavailable.
- Recruitment records family `family.fonxan`, generation14, master
  `teacher.liu_chunfeng`, legacy name 柳淳风, family title 弟子, privileges0,
  class `swordsman`, recorded UTC seconds and 封山剑派第十四代弟子 display title.
  `WorldPlayerRuntimeState.request_school_apprenticeship()` is the controlled
  identity-title seam; existing CharacterState/body/allocator identity stays intact.
- `SnowSchoolTeacher` retains source knowledge, male/age44/int24/generation13 and
  sen170 projection. F_MASTER and known unarmed policy feed existing LearnService.
  No teacher NPC slot, combat target, spawn, death, corpse or respawn is added.
- LearnService's optional runtime RNG parameter draws only after spent increments
  and the source bound is evaluated. Runtime supplies the existing persisted
  world-interaction stream, shared with player/world interactions. No fourth RNG,
  pre-roll, UI RNG, retries or automatic learning loop. Earlier deterministic
  context behavior remains usable by established tests.
- Source cost is `150/24 + 150/30 = 11`, doubled to22 at raw0. `gin > cost` is
  strict. Raw0 creation precedes the potential gate; late failures retain source
  mutations. At E0 raw0/1/2 can progress; raw3 needs E2 and still spends gin on
  experience rejection. One UI activation issues one request using current facts.
- Snow outdoor adds school1→school2→schoolhall east of mstreet1. The cluster uses
  real Area zones, CharacterBody walking, collisions and a teacher marker. Gate at
  `(400,-400)` supports Open/Close on either side; closed footprint is always
  save-invalid. The teacher is near `(1080,-400)`. Storage/inner-yard directions
  are explicitly unavailable. `school.c` academy is not substituted.
- Core has no scene/position authority. Resident runtime owns physical/contact
  availability. Presentation displays structured outcomes and quarantines input.
  Requests re-check live authority instead of trusting an open panel.

## Persistence compatibility

Root **2**, item **3**, `SOURCE_ENTRY_V1` remain unchanged. Character saves add a
strict optional `affiliation` block with internal `schema_version:1`, class,
family-rank known flag/title/privileges, entry-time status and int64 UTC seconds.
New saves emit it; the old exact character shape remains readable. Present but
malformed blocks and unknown versions are rejected, never silently treated as old.

Old no-family/no-master saves retain no class or entry time. Old nonempty
relationships missing time use typed **UNKNOWN** with no fabricated class/rank or
load timestamp. `has_family_rank=false` distinguishes unrecorded rank from the
actual source privileges0. ABSENT/UNKNOWN cannot carry a timestamp value.

Pending intent, contact panels and gate state are transient. Cold Continue closes
the gate and preserves valid saved physical position. Existing body, inventory,
equipment, money, food/liquid, allocators and three RNG streams retain their codecs.

Four checked-in fixtures were generated by the actual frozen P1 executable,
including Snow, Hockshop, Old Pine and a legitimate nonempty relationship. See
[fixture provenance and hashes](../../game/tests/fixtures/snow_progression/README.md).
Each decodes, restores and recaptures through the existing all-state comparison.
Additional new school, raw0 failure and partial-progress saves round-trip; a real
separate-process Host Continue compares the complete snapshot exactly and verifies
the same next world RNG draw.

## Local verification

| Check | Result |
|---|---|
| `run_snow_progression_tests.gd` | **247 assertions, 0 failures** |
| `run_tests.gd` complete canonical suite | **20,179 assertions, 0 failures** |
| Python tooling tests | **46 passed** |
| Repository/static checks | PASS |
| Development headless editor | PASS |
| Repository-content release sanitizer | PASS; 1,712 executable/test files copied at validation time, zero sanitizer errors |
| Sanitized headless editor / main120 frames | PASS / PASS; no packaged artifact claim |
| Frozen P1 writer and old fixture compatibility | PASS |

Tests cover effective19/20, full relation/idempotency, pending/cancel, gin22/23 and
11/12, teacher sen5/6 and3/4, raw0 ordering, exp0/2 gates, rolls0/1/29/invalid30,
spent/late failures, no pre-gate draws, no presentation draws, cold RNG continuation,
AP at E0/E1/E2 and raw0/1/2, physical door traversal, invalid doorway saves, remote/
wrong-zone/too-far/busy/fighting/paused contact, input quarantine and no NPC slot.
The E2/raw2 case yields AP2 through existing projection; E2/raw0/1 yields AP1.
Those constructed domain states are not natural live experience evidence.

The first full run found four obsolete pre-school assertions: mstreet1's old east
wall, north-spine school boundary pair and total Snow zone count. They were updated
to test the remaining wall, actual closed school gate and new exact count. No test
was skipped or weakened to mask an unrelated failure. Final full run passes.
The initial focused failure was a test string search matching `door` in `outdoor`;
the check now searches field prefixes. Final scope has no unrelated production fix.

Validation follows all five established verify stages separately. The sanitizer
uses tracked plus nonignored new repository content, preserving ignored owner-local
Godot AI backup/update files. It does not claim the direct worktree sanitizer passed.
Windows headless logs retain the known root-certificate-store diagnostic; editor
loading and tests complete successfully. No remote CI is inferred from these runs.

## Actual main-scene / real-input evidence

The canonical application main scene ran in Godot4.7.2 with the existing Godot AI
helper. APPDATA was isolated under ignored build output to protect the owner's
normal save. LOCALAPPDATA stayed unchanged so the existing helper could connect.
This changed no gameplay state. TCP6107 was available on this workstation.

New Game used real Unicode key events for 林清 and real gender/start buttons.
All claimed walking used input actions, and all school/learn/save/combat actions
used actual framebuffer UI clicks. No direct traversal, position writes, state/EXP
injection, RNG replacement, callbacks or altered enemies in this live journey.

| Actual observation | Evidence |
|---|---|
| Inn→Square→mstreet1→school1 | Real input; closed gate stops west x≈371 |
| Both-side Open/Close | Real buttons; crosses open gate, east closed collision, reverse crossing and west Close |
| schoolhall / Liu | Real walking to `(1008.9955,-399.6664)`, real conversation/apprentice |
| Five individual Learn activations | raw0/progress1→raw1→raw1 partial→raw2→raw3; spent5, E0 |
| Further raw3 Learn | Real UI reports experience insufficient; source gin cost remains, no level increase |
| True Save checkpoint | Hall position; raw3/progress0/spent5/E0/gin43; entry time1789423931 |
| Real Old Pine attempt | Physical south/east route, enemy selected and Attack clicked; blocker below |
| Process termination→cold Continue | Live process25696 terminated; successful new process71800 loaded saved checkpoint |
| Exact cold state comparison | Entire Character object, items and all three RNG streams equal the saved JSON; title/time/position unchanged |
| Cold runtime authority | One active map child; active Camera2D belongs to Snow Player; gate closed/collision active |
| Cold door route | Actual westward movement blocked from inside; real Open then physical crossing and Close |

Successful run health: `helper_live=true`, `session_active=true`,
`game_capture_ready=true`; successful cold launch `current_run_errors=[]`.
Screenshots had `stale_frame=false`, including frames3231→8387→10795→13157 in
the new-game school run; cold frames101→2842 show advancing fresh frames.
Final current-run game logs have no gameplay script errors. Existing editor
warnings about integer division/shadowed locals remain; not all warnings were
claimed absent. Three discarded QA probes had a malformed Unicode loop, a too-early
read during New Game initialization and a wrong JSON key. These were tooling
mistakes, not production errors; each affected run was stopped before successful
replacement evidence. No error-buffer clearing was used to manufacture a clean run.

Local detailed evidence is retained in ignored `build/p2-live-events.jsonl`,
`p2-live-{school,learn1,learn2,save-school,combat-diagnosis,cold-compare2,cold-door,health-final}.log`,
`p2-frame-*.png`, `p2-focused-final.log`, `p2-canonical-final.log`, and sanitizer logs.

## Historical P2 blocker: natural experience / uninterrupted return

The unmodified fresh character actually selected existing spath1 bandit3 and
clicked Attack. The lethal encounter produced three scheduler events, then at
logical cycle2 the player's attack was dodged and its riposte chain failed:

- `CombatEncounterResolution.Failure.INCOMPLETE_ATTACK_CHAIN` (1).
- `CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE` (13).
- Chain `REVERSE_ORDINARY_FAILED` (6), stage `REVERSE_ORDINARY` (6).
- Reverse ordinary `BASE_ATTACK_INCOMPLETE` (1), stage `BASE_ATTACK` (9).
- Base attack `INVALID_SOURCE_STATE` (3).
- Natural EXP remained **0**; player vitality100/100, enemy vitality200/200.
- Twelve additional real seconds made no progress; a real Flee click did not end
  the failed encounter. The scoped observation does not identify a deeper root cause.

At that original checkpoint, natural E≥2, a live numerical skill benefit after that
threshold, and physical return/save after that encounter were **BLOCKED**, not PASS. The cold proof loads
the real pre-combat school Save checkpoint; it is not falsely described as a
post-victory save or uninterrupted completed journey. Existing combat code is
unchanged. No EXP, enemy tuning, damage/flee/recovery/reward adjustment or dummy was
introduced. This warrants separate owner triage; P2 does not broaden into combat
stabilization or claim the game is progression-complete.

## Self-review, residual risk and stopping boundary

Reviewed the complete P1 working diff and new files separately from test execution:
source topology, source rule ordering, Core/runtime/UI authority, duplicate system
avoidance, strict old/new codec, pending/door transience, one RNG draw and scope.
`reference/es2` delta0; project settings/editor churn restored to delta0. No owner
backup/config removed, no generic NPC/trainer/door engine or migration tool added.

At the original P2 checkpoint, implementation was complete with the disclosed live
progression blocker, awaiting owner review. The major milestone is not fully integrated: no PR, merge or P2 remote
integration CI. Original main is unchanged. No P3 or Final Audit started.

Deferred: advanced ten-skill interactions, liuh-ken/force/sword/chaos/spider usage,
enable/mappings/practice/exercise/selflearn/study/exert/perform/formations; complete
Liu combat/equipment/death/respawn; guards/trainers/trainees/population; inner yard,
storage/puzzles/board/academy; generic frameworks, migration tooling and balancing.
Mobile-device/package qualification was not part of this P2 desktop proof.

## Fresh live acceptance (2026-09-15 UTC)

**SNOW FIRST PROGRESSION P2 LIVE ACCEPTANCE PASS.** Owner authorized evidence only,
on existing `phase/snow-first-progression-loop`. Starting HEAD and origin phase both
matched `315d3863a5b72fbbb3f84006440d7b9e796bf512`, parent
`affbe5030a5a2f03c2bff2ab14195f9f86c5f53c`; origin/main remained
`88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e`. Worktree/index were clean.
P1, P2 implementation, P2B and ZE1 are owner approved; the old zero-EXP failure is resolved.

Godot 4.7.2 ran the canonical application main scene with the existing helper and
an isolated APPDATA under ignored `build/p2r-live-env`. One fresh New Game used real
Unicode input for 林清, male. There was no discarded gameplay attempt, checkpoint
retry, EXP grant, state/position injection, enemy/armor tuning or RNG replacement/reset.
All gameplay used real buttons, input actions, physical traversal and normal cadence.

| Step | Actual evidence from this one timeline |
| --- | --- |
| New Game | E0, no family/master, no learned skills; `snow.inn` |
| School route | Inn→Square→mstreet1→school1; closed collision stopped x370.993; real Open and walking through school2→schoolhall |
| Apprentice | Real Liu UI: `family.fonxan`, generation14, `teacher.liu_chunfeng` / 柳淳风, swordsman, rank弟子, privileges0, RECORDED entry1789446817, betrayer0, title封山剑派第十四代弟子 |
| Individual Learn | Three clicks naturally reached raw1/0→raw2/0→raw3/0; spent3. Fourth click at E0 was rejected for EXP, gin76→65, raw/progress/spent unchanged |
| Old Pine | Actual Snow south/east route and production portal; existing spath1 Bandit03 only |
| Survival control | Short movement bursts near aggression; normal Escape pauses between observations; real Flee immediately after each observed hit, then physical retreat and natural recovery |
| Return | After E2, physical north route→Snow eroad3→street spine→schoolhall; school gate remained open within the same resident session |
| Same authority | Character instance `-9223371763470038350` and apprenticeship instance `-9223371763235157312` unchanged; all relationship fields retained |
| Post-E2 Learn | One real click: success / LEVEL_INCREASED, failure NONE, raw3→4, learned0→0, spent3→4, gin100→89; required E2, natural roll21 below30 |
| Save | Real pause-menu Save reported “Your journey was saved.”; complete encoded capture exactly equalled the real saved checkpoint |
| Whole-process restart | Game PID57284 ended, verified absent; new PID63804 used real Continue, then normal Escape pause |
| Cold authority | New Session460165483425 and Character `-9223371597929247873`; one active `snow.outdoor` map; correct Player Camera2D; ACTIVE, no encounter, teaching panel hidden, gate closed with collision |

Nine separate production encounters ended with successful real Flee and
`resolution.failure=NONE`; none ended in unconsciousness/death. The observed hit
and EXP sequence was:

| Encounter | Player damage | EXP before→after | Exit vitality current/effective |
| --- | --- | --- | --- |
| 1 | 31, ordinary NPC hit | 0→0 | 69/70 |
| 2 | 25, riposte | 0→0 | 46/48 |
| 3 | 26, riposte | 0→0 | 44/46 |
| 4 | 29, riposte | 0→0 | 32/34 |
| 5 | 20, ordinary NPC hit | 0→0 | 45/47 |
| 6 | 26, ordinary NPC hit | 0→0 | 39/41 |
| 7 | 32, riposte | 0→1 | 32/34 |
| 8 | 28, ordinary NPC hit | 1→1 | 38/40 |
| 9 | 22, riposte | 1→2 | 43/45 |

The E1→E2 completed progression result retained its actual bound143/draw16; the
earlier encounter4 retained bound132/draw116 with no EXP gain. These were reads of
already completed results, not test draws. Real ordinary hits and completed reverse
chains crossed the former E0 boundary without `DEFENSE_FACTOR_RANDOM_BOUND`.
This run required lengthy natural wound recovery between encounters; it proves the
bounded journey can complete, not that fresh progression is fast or balance-qualified.

Production skill evidence: the actual player attack records consumed `unarmed`,
raw3/effective1, with AP1 at E0/E1. After the real Learn, the existing encounter
authority lookup referenced the exact same CharacterState and CharacterSkillState
(`combat_state_same=true`, `combat_skills_same=true`), now explicit raw4/effective2/E2.
`WorldCombatBindingAdapter.from_player` passes that state to the existing production
projection, which reads `state.skills.effective_level`. No alternate calculation,
bonus or extra post-Learn attack was manufactured; no new post-Learn AP is claimed.

Cold comparison used the established `OldPineWorldSaveCapture` and `GameSaveJsonCodec`
mechanism. Reusing the saved metadata for the read-only capture, the **entire encoded
snapshot** matched before shutdown and after Continue. This includes player identity,
all relationship/progression/skill mappings/resources, inventory/equipment/money,
food/liquid records, allocator, world position, NPC states, corpses and all RNG streams.
Checkpoint: E2, explicit unarmed4/progress0, potential101/spent4, gin100/100/100,
kee51/52/100, sen100/100/100, food211/water211, empty skill mappings, schoolhall
position `(1008.33404541016,-399.333709716797)`. The only player item was the original
equipped cloth; no player weapon/money/food-item/liquid-item was added. All12 item
records and allocator scope/next sequence1 matched exactly.

| Persisted RNG | Exact saved and cold-restored state |
| --- | --- |
| Combat | `4754167863713160086` |
| NPC initialization | `440029765285268016` |
| World interaction | `-4028637667228911038` |

Adapter IDs and seeds also matched as part of the complete encoded comparison.
No arbitrary next RNG draw was consumed. Natural post-gate Learn reached raw4 while
E remained2, below the next Learn requirement E6; consequently this run claims exact
persisted RNG round-trip, not an additional next-operation continuation experiment.
Transient recovery cadence is outside the persisted RNG contract.

Helper/session/capture were live/active/ready. Captures were never stale: first-run
frames18→387098(E2 exit)→410264(Save result); cold frames7→2538→5531→11199.
Both launches reported `current_run_errors=[]`; retained first-run game logs contained
only the desktop virtual-keyboard warning, and cold game logs had no errors/warnings.
No error buffers were cleared. A redundant `project_run` during play was rejected by
the helper without changing PID/session; the following read-only health check confirmed
the original process and advancing frame. One movement burst while normally paused
was ignored and then performed after Resume. Neither interrupted or rewound gameplay.
Cold startup initially exceeded the helper's3-second window, then became fully live;
no retry/restart was used to change an outcome and no QA debugger break occurred.

Ignored local evidence: `build/p2r-live-events.jsonl`, `p2r-frame-*.png`,
`p2r-post-gate-learn.log`, `p2r-checkpoint.json`, `p2r-cold-checkpoint.json`,
`p2r-cold-compare.log`, `p2r-pre-cold-stop.log`, `p2r-final-health.log`.
Both game processes and the temporary editor were stopped after proof. Only the
editor's own omitted viewport lines were restored; production/test/source/config/CI
delta from ZE1 is zero. This acceptance update changes only the four authorized docs.
Documentation links/static checks and `git diff --check` pass; no canonical rerun or
remote CI is claimed. No Final Audit, PR, merge, P3 or Migration Tooling was started.

**P2 COMPLETE — AWAIT OWNER FINAL-AUDIT AUTHORIZATION.**
