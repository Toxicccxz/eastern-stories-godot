# Snow Martial Progression II — P2 Runtime Implementation

## Status and frozen authority

P1 OWNER APPROVED / CLOSED at `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd`.
P2 implementation, P2R1 and P2R2 are OWNER APPROVED / CLOSED. Current starting freeze:
`96b92799b663adc76776be15f1f9f0e656a2d9c7`.
**P2 IMPLEMENTATION + AUTOMATED FUNCTIONAL ACCEPTANCE COMPLETE
— AWAIT OWNER FINAL-AUDIT AUTHORIZATION**, under the
[new owner decision](DECISIONS.md#snow-martial-progression-ii--automated-functional-acceptance).
The [new acceptance report](PHASE_SNOW_MARTIAL_PROGRESSION_II_AUTOMATED_ACCEPTANCE.md)
separates genuine historical live evidence from deterministic production-path tests.
Natural EXP6 session duration is deferred pacing/usability qualification; the test-only
EXP6 checkpoint changes no gameplay rule. The Godot AI update is retained, separate
from P2R2, for later owner-authorized Final Audit. No production or Save schema edits.
Fresh gates PASS: automated story110 / focused2,055 / canonical21,055 assertions,
0 failures; Python3.12 656 tests; static, Godot4.7.2 headless/editor,
sanitizer/sanitized import and changed-document validation.

The implementation identities and local counts below are historical checkpoints.
Phase: `phase/snow-martial-progression-liuh-ken`; integrated base
`36a26b13e2bdebeb44c14c0a013d509000c29476`.
Preflight fetched and matched local/remote P1 and base; tracked/index clean;
any-state phase PR search returned zero. No PR, merge, Final Audit or P3.
Previous owner-approved executable/test freeze: `81d0cb63da15f9e384392de98cbaa3fd21475a51`.
The narrow [P2R1 repair](PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md)
is OWNER APPROVED / CLOSED at the new executable/test freeze
`798842879ebea52b33e7e2136f606a3741659590`; the major milestone is not integrated.

[P2R2 generalized names](PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md) is the subsequent
owner-authorized Type B product adjustment, subsequently OWNER APPROVED / CLOSED
(2,303 focused / 20,945 canonical assertions; 656 Python tests; all five verify.py stages PASS). It preserves P2R1,
birth/combat/Liuh semantics and Save schemas. The owner accepted starting HEAD
`3cf9c67e4514e9131f1492a36454ebc625376608`, including the later Godot AI update;
the resulting P2R2 commit is now the approved starting freeze above. That repair task
did not resume live acceptance. Final Audit remains unauthorized.

Authority: [approved P1](PHASE_SNOW_MARTIAL_PROGRESSION_II_SOURCE_ANALYSIS.md)
and [D-SMP2-01–08](DECISIONS.md#snow-martial-progression-ii--owner-locked-p2-boundary).
The decisions are recorded with implementation, not a separate decision commit.
EXP >=6, basic unarmed >=4, liuh-ken >=5 and enabled remain the functional finish;
the subsequent owner acceptance decision permits test-only prerequisite construction.

## Source and bounded implementation

Reviewed LPC authority is the P1 trace: `daemon/skill/liuh-ken.c`, `std/skill.c`,
`feature/clean_up.c`, Liu's school NPC, `cmds/std/learn.c`, `cmds/std/enable.c`,
`feature/skill.c`, `feature/action.c`, `adm/daemons/combatd.c`, `std/char.c`,
and the referenced human/character resource derivation. `reference/es2` is unchanged.

`LiuhKenDefinition` declares exact specialized martial `liuh-ken` / 柳家拳,
valid only for unarmed. Its stable ID prefix is `es2:daemon/skill/liuh-ken/`:

| Suffix | Complete source text |
| --- | --- |
| `gu-song-gua-yue` | $N使一招「古松挂月」，对准$n的$l「呼」地一拳 |
| `ao-xue-dong-mei` | $N扬起拳头，一招「傲雪冬梅」便往$n的$l招呼过去 |
| `gu-ya-ting-tao` | $N左手虚晃，右拳「孤崖听涛」往$n的$l击出 |
| `huang-shan-hu-yin` | $N步履一沉，左拳拉开，右拳使出「荒山虎吟」击向$n$l |

All four are always available; damage/force percentages zero, canonical 瘀伤,
no post-action. Source dodge/parry values remain documentation evidence only;
CombatActionDefinition and CombatMath are unchanged.

Liu's existing contact/panel teaches exactly unarmed and liuh through LearnService.
The existing both-hands-empty policy, teacher facts and mutation ordering remain.
Armor/carried items do not prevent learning. Generic cost yields 11 or raw0 22;
strict gin/sen and EXP equality boundaries are unchanged. Enable uses
SkillEnableTransition; Disable uses unmap_skill. Both require valid active physical
Liu contact, no pause/fight/busy, as the approved Native availability gate.
No force/mana/atman reset; raw/learned progress survives disabling.
The panel reads authoritative effective unarmed (temporary + raw/2 + mapped raw).
Primary weapon determines attack skill without deleting the mapping; secondary-only
still blocks Learn while no-primary combat remains mapped unarmed.

## Select-once execution and self-review

The old reverse live-coherence checks were moved intact to
CombatLiveProjectionValidation and shared with runtime forward execution; an exact
approved-action-source comparison was added. IDs, live state, EXP, spirit, attributes,
equipment, mappings, modifiers, busy and relationships remain checked before selection.
A copied approved set is composition authority, not a cached next action. After one
selector draw, complete selected payload membership is checked; the resolver receives
a fresh input with that exact selected action. Existing resolver/math is unchanged.
Reverse QUICK/RIPOSTE rebuild current authority after forward execution and select
independently. Singleton actions retain their bound1 draw; liuh uses bound4.
Only exact reviewed liuh receives PROVEN_NO_AUTHORED_EFFECT. Unknown mapped skills
remain unavailable. No generic hook dispatch or extra RNG stream was introduced.
Combat progression still improves basic unarmed, not liuh.
Feedback renders complete text from committed action ID/result plus existing actor,
victim and limb; receipt retention works after scheduler release; presentation draws zero.

Distinct self-review checked the production diff, preserved reverse checks, exact action
payload membership, unknown mapping refusal, source precedence, terminal receipts and
unchanged math/persistence/legacy/tooling boundaries. This is slice verification, not
an owner-authorized milestone Final Audit.

## Fresh local validation

| Gate | Actual result |
| --- | --- |
| Final standalone P2 focused suite | 283 assertions, 0 failures |
| Complete canonical gameplay suite | 20,544 assertions PASS: 20,261 existing + 283 P2 |
| Affected Skill/Learn/Combat/Snow/Save suites | All included in the 20,544; no subset skipped |
| Full Python tooling suite | 656 tests, OK, 0 failures/errors/skips |
| Repository/static checks | PASS |
| Development headless editor import | exit0, no script errors |
| Sanitizer + sanitized headless editor import | PASS, exit0 after local archive isolation below |
| Whitespace | git diff --check PASS |

The canonical runner includes existing Beast, default unarmed, weapon, QUICK/RIPOSTE,
Flee, progression, corpse/loot, CXR and terminal-feedback regressions unchanged.
P2 tests cover all four indices/texts, cost/strict thresholds/partial mutation,
11 EXP thresholds below/equal/above, equipment asymmetry, stale projection and forged
payload refusal before RNG, independent reverse selections, default singleton draws,
Learn/Combat stream isolation and committed terminal feedback.

Automated persistence tested enabled and disabled snapshots including raw/learned
skills, EXP, potential/spent points, complete relationship/world/equipment state and
all three RNG streams. Full encode/restore comparisons passed with zero restore draws.
Production persistence is unchanged: root schema2, item schema3, SOURCE_ENTRY_V1.

Shared Liu panel regressions passed at 1152x648, 960x540, 800x480 and 480x320,
including confinement, 64-pixel touch targets and focus-following scroll.
Physical Android/iOS qualification is deferred to the later authorized Final Audit.

`tools/ci/verify.py` first reached sanitizer after all tests passed, then correctly
rejected an ignored local `addons/.godot_ai_update` successful-update backup from
4.0.2 to 4.0.4 (dated before this task). The entire untracked directory was preserved
by moving it to ignored `build/smp2-preserved-godot-ai-update`; no tracked plugin,
release checker or ignore policy was changed. The unchanged sanitizer and sanitized
Godot import were rerun successfully. An initial sandbox certificate-store error was
avoided by running the final Godot gates with normal host permissions and isolated
settings. No accepted test skip or suppressed product error was introduced.
Evidence logs are ignored under `build/smp2-*`; they are not release artifacts.

## Historical live acceptance gate

This section records the former acceptance protocol and its evidence. The subsequent
owner decision supersedes the requirement to finish a natural live EXP6 grind or
repeat full-process Continue for P2 functional closure; historical reports stay intact.

Current [changed-path acceptance](PHASE_SNOW_MARTIAL_PROGRESSION_II_CHANGED_PATH_LIVE_ACCEPTANCE.md)
used the owner-authorized existing public-entry fixture and verified exact source birth.
Real route/apprenticeship/Learn reached raw3; first combat reached EXP1 before late
pause, with no Flee request. Sustainable progression remains operationally inconclusive.
Separately, retained source-cloth death receipts show INVALID_ITEM_FACTS →
DEATH_INVENTORY_BLOCKED / LIFECYCLE_FAILED, a confirmed production lifecycle blocker;
Owner review identified missing SourcePlayerCloth armor facts at the production death
composition boundary. Independent base-to-P2 comparison confirms a pre-existing
source-entry / Player-death integration defect, not a Liuh-Ken regression.
[P2R1](PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md) supplies the
existing aligned cloth definition and adds the exact source Player death regression.
The repair is OWNER APPROVED / CLOSED. The
[post-P2R1 acceptance preflight](PHASE_SNOW_MARTIAL_PROGRESSION_II_POST_P2R1_LIVE_ACCEPTANCE.md)
stopped before bootstrap: installed input_sequence supports action states only,
not the required atomic Escape/mouse events. No Player or encounter was created;
this is an acceptance-tool capability gap, not a new gameplay or P2R1 failure.
P2R1 local gates PASS: 2,282 focused / 20,608 canonical assertions, 656 Python tests,
static, development headless/editor and sanitized-project validation.
Historical Attempt1/2/3 reports are preserved. The following paragraphs record Attempt1.

The natural journey ran on pushed `81d0cb63da15f9e384392de98cbaa3fd21475a51`,
following implementation `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401`. The second commit
removed only two trailing blank lines identified by the staged new-file check;
complete P1-to-implementation whitespace validation then passed. No executable
behavior changed after the complete test run.

[The acceptance blocker report](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_BLOCKER.md)
records the sole natural character, real physical route, basic raw0→3, EXP0,
first Bandit03 encounter, four received hits and unconscious defeat after10 logical
seconds. The helper's action-state pause did not emit a shell key event; inspection
latency and a late Flee click contributed. No tactical request was recorded. This
failed attempt does not prove EXP6 impossible or a Liuh implementation defect.
No state/RNG/position injection, balance edit, save edit or discarded combat occurred.
The run stops for owner review; no automatic retry or lower finish is claimed.

Natural EXP6, raw unarmed4/liuh5, live mapped actions, Save/full-process restart/cold
Continue and post-Continue mapped combat remain unaccepted. Automated fixtures above
seed state and are not substitutes for those live gates. Updates through pre-repair HEAD
`c31d915c6b09f00c412800f7025ac2c9054b2dc0` were documentation only; P2R1 is the owner's
subsequent narrow authorization to repair source-cloth death composition.

## Explicit deferrals

Other Liu skills/content/AI/drops, force/internal power/exercise, sword progression,
practice/study/selflearn/perform/exert, generic skill UI, storage/yard/board/full school,
full faction/teacher changes, Phase5B4/hit hooks/conditions, Lake/serpent, enemy/recovery
balance, physical device certification and Migration Tooling P3/extractors/generators
remain outside P2. No remote CI is claimed or triggered; no PR exists.

## Exact implementation file scope

- `docs/migration/DECISIONS.md`
- `docs/migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_RUNTIME.md`
- `docs/production/ROADMAP.md`
- `docs/production/STATUS.md`
- `game/core/combat/action/combat_action_selection_input.gd`
- `game/core/combat/action/combat_action_set.gd`
- `game/core/combat/execution/combat_attack_chain_completion_service.gd`
- `game/core/combat/execution/combat_live_projection_validation.gd`
- `game/core/combat/execution/combat_live_projection_validation.gd.uid`
- `game/core/combat/execution/combat_reverse_attack_projection.gd`
- `game/core/combat/execution/combat_single_attack_execution_service.gd`
- `game/core/combat/resolution/combat_attack_input.gd`
- `game/data/combat/liuh_ken_definition.gd`
- `game/data/combat/liuh_ken_definition.gd.uid`
- `game/data/snow/snow_school_teacher.gd`
- `game/presentation/battle/battle_feedback_reader.gd`
- `game/runtime/combat_slice/combat_slice_content_profile.gd`
- `game/runtime/combat_slice/combat_slice_opportunity_executor.gd`
- `game/runtime/combat_slice/combat_slice_projection_builder.gd`
- `game/runtime/world/snow_school_contact.gd`
- `game/tests/run_snow_martial_tests.gd`
- `game/tests/run_snow_martial_tests.gd.uid`
- `game/tests/run_tests.gd`
- `game/tests/runtime/snow_martial_progression_test.gd`
- `game/tests/runtime/snow_martial_progression_test.gd.uid`
- `game/ui/snow/snow_school_interaction.gd`
