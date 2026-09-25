# Snow Martial Progression II — Liuh-Ken source and Native dependency analysis

## P1 decision and authorization boundary

P1 source/dependency analysis is complete. The recommended P2 is **Liuh-Ken Minimal Martial Progression**: extend the existing Liu contact with source-valid learning and explicit unarmed mapping, supply all four authored actions, integrate them into the existing ordinary-combat pipeline, show committed action feedback, and validate persistence through a real process restart. This is a proposal awaiting owner review; **NO P2 implementation is authorized**.

The proposed primary finish is natural combat EXP at least 6, basic unarmed at least 4, and liuh-ken at least 5. The arithmetic supports that finish, but the existing natural-play evidence reaches only EXP 2. Reaching EXP 6 safely and within a practical play session is an unresolved acceptance risk, not a proven runtime result. No enemy rebalance, free EXP, favorable RNG, or skill grant is included.

Two findings materially constrain P2. First, ES2 ordinary combat does **not** read liuh-ken's action `dodge` and `parry` fields; adding those as bonuses would invent a mechanic. Second, Native action selection supports action sets, but both forward and reverse execution currently validate against a prebuilt single-action template. Four-action data and mapping alone will not complete the integration.

This document does not claim gameplay implementation, runtime PASS, full martial-art parity, PR readiness, or permission to start another slice. Migration Tooling v1 remains integrated and untouched.

## Frozen base and branch gate

| Item | Freshly verified P1 value |
| --- | --- |
| Repository | `Toxicccxz/eastern-stories-godot` |
| Base local main / origin main | `36a26b13e2bdebeb44c14c0a013d509000c29476` |
| Documentation closeout | [PR 21](https://github.com/Toxicccxz/eastern-stories-godot/pull/21), merged |
| PR 21 head | `3829ff1f98e7f2fc845ea9bcdd1a0132ffc3fbc4` |
| PR 21 normal merge | `36a26b13e2bdebeb44c14c0a013d509000c29476` |
| Exact post-merge workflow | [36087588011](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36087588011), completed / success |
| Required jobs on that SHA | Godot Verify, Android Release Build, Windows Release Build, iOS Build Validation: all success |
| New major-phase branch | `phase/snow-martial-progression-liuh-ken`, created from the exact base after the green gate |
| Initial tracked worktree / index | Clean |
| Phase PR | None; P1 must not create one |

One major milestone owns this one phase branch and one eventual final PR. P1 does not reopen either Migration Tooling integration or its documentation closeout.

## Reviewed project baseline

The following baseline was read for this analysis. Later integrated audits and current code take precedence over intermediate proposals; historical evidence is identified as historical rather than rerun evidence.

| Area | Reviewed documents |
| --- | --- |
| Repository / operational policy | [README](../../README.md), [STATUS](../production/STATUS.md), [ROADMAP](../production/ROADMAP.md), [repository policy](../production/REPOSITORY_POLICY.md), root and documentation AGENTS instructions |
| Application / platforms / persistence | [application shell](../production/contracts/APPLICATION_SHELL_CONTRACT.md), [mobile](../production/contracts/MOBILE_APPLICATION_CONTRACT.md), [Native Save/Load](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md) |
| Architecture / substitutions | [DECISIONS](DECISIONS.md), [ES2 architecture](ES2_ARCHITECTURE_ANALYSIS.md) |
| New Game / Snow | [source rebaseline](PHASE_START_OF_GAME_SOURCE_REBASELINE.md), [New Game final audit](PHASE_NEW_GAME_ENTRY_FINAL_AUDIT.md), [Snow Hub final audit](PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md), [Hockshop final audit](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_FINAL_AUDIT.md) |
| First progression | [source analysis](PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md), [runtime](PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md), [zero-EXP blocker](PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_BLOCKER.md), [zero-EXP fix](PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_FIX.md), [final audit](PHASE_SNOW_FIRST_PROGRESSION_FINAL_AUDIT.md) |
| Skills / Learn | [3A](PHASE_3A_SKILL_CORE.md), [3C0](PHASE_3C0_LEARN_DEPENDENCY_ANALYSIS.md), [3C1](PHASE_3C1_LEARN_CORE.md), [4A2](PHASE_4A2_EQUIPMENT_SKILL_LEARN_POLICIES.md) |
| Combat foundation | [5A](PHASE_5A_COMBAT_DEPENDENCY_ANALYSIS.md), [5B1](PHASE_5B1_COMBAT_STATE_MATH_ACTION_FOUNDATION.md), [5B2A](PHASE_5B2A_ORDINARY_ATTACK_CORE_RESOLUTION.md), [5B2B2](PHASE_5B2B2_COMBAT_PROGRESSION_BUSY_COMPLETION.md) |
| Active combat integration | [Active Semi-Auto design](PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md), [CXR2](PHASE_COMBAT_CXR2_ENCOUNTER_CORE.md), [CXR8](PHASE_COMBAT_CXR8_RESOLUTION_CUTOVER.md), [CXR9](PHASE_COMBAT_CXR9_PLAYABILITY_BALANCE.md), [CXR10](PHASE_COMBAT_CXR10_FINAL_AUDIT.md) |

## Authoritative Liuh-Ken and inherited behavior

Authority: [liuh-ken.c](../../reference/es2/mudlib/daemon/skill/liuh-ken.c), lines 3–50. `SKILL` resolves through [globals.h](../../reference/es2/mudlib/include/globals.h) to [std/skill.c](../../reference/es2/mudlib/std/skill.c), which inherits [clean_up.c](../../reference/es2/mudlib/feature/clean_up.c).

| Authored action and exact text | Lines | dodge | parry | damage_type |
| --- | --- | ---: | ---: | --- |
| 古松挂月: `$N使一招「古松挂月」，对准$n的$l「呼」地一拳` | 6–9 | -40 | 40 | 瘀伤 |
| 傲雪冬梅: `$N扬起拳头，一招「傲雪冬梅」便往$n的$l招呼过去` | 11–14 | -30 | 30 | 瘀伤 |
| 孤崖听涛: `$N左手虚晃，右拳「孤崖听涛」往$n的$l击出` | 16–19 | -30 | 30 | 瘀伤 |
| 荒山虎吟: `$N步履一沉，左拳拉开，右拳使出「荒山虎吟」击向$n$l` | 21–24 | -30 | 30 | 瘀伤 |

The last text deliberately has `$n$l`, not `$n的$l`. None of the four defines `damage` or `force`; no invented percentage modifier is allowed. There is no per-level action unlock.

`std/skill.c::type()` returns `martial` (line 39). Its default `valid_learn` is overridden: liuh-ken lines 28–33 reject either primary `weapon` or `secondary_weapon`; both weapon references must be empty. This does not prohibit armor, shields as armor, or unwielded inventory. `valid_enable` (35–38) accepts only `unarmed`. `query_action` (40–43) selects `action[random(sizeof(action))]`: all four actions, one uniform bounded draw per actual query.

`practice_skill` (45–50) rejects kee below 30, otherwise damages kee by 30 and succeeds, including at exactly 30. The additional requirements are in [practice.c](../../reference/es2/mudlib/cmds/std/practice.c), lines 13–34: not fighting, an enabled special skill, nonzero basic and special raw levels, `valid_learn`, then the practice hook, then `improve_skill` with `basic/5+1` and its weak-mode argument. They are not an extra inherited liuh-ken practice implementation. Practice is deferred.

The inheritance chain supplies the generic `perform_action` / `exert_function` dispatch infrastructure, default `valid_effect`, and a no-op `skill_improved`; liuh-ken authors no perform/exert implementation, `hit_ob`, or `post_action` here. That proves no authored effect in this inspected chain, not the behavior of calling a missing lfun on an arbitrary MudOS/FluffOS driver. P2 should use an explicit, narrow Native no-authored-effect classification for this skill, retaining refusal for unknown effect-bearing skills. General hook emulation and Phase 5B4 are not prerequisites.

## Liu Chunfeng teacher authority and Native projection

Authority: [swordsman/master.c](../../reference/es2/mudlib/daemon/class/swordsman/master.c), `create`, `attempt_apprentice`, and `recruit_apprentice`, lines 8–88.

| Raw skill | Level | Raw special skill | Level |
| --- | ---: | --- | ---: |
| unarmed | 40 | fonxanforce | 60 |
| parry | 120 | fonxansword | 150 |
| dodge | 80 | liuh-ken | 60 |
| sword | 150 | chaos-steps | 100 |
| force | 40 | spider-array | 85 |
| literate | 60 | — | — |

Mappings are `unarmed -> liuh-ken`, `sword -> fonxansword`, `parry -> fonxansword`, `dodge -> chaos-steps`. Do not infer a force mapping from knowing fonxanforce.

Liu is 柳淳风, titled 风雨双侠, male, age 44, raw str 27 / cor 30 / cps 27 / int 24, max_force and force 1500, force_factor 3, combat_exp 1,000,000, score 200,000. His family is 封山剑派, generation 13, 掌门人. `attempt_apprentice` requires effective courage and composure at least 20. Successful inherited recruitment is followed by setting the **student's** class to `swordsman`; the file does not assign Liu that class.

Resource derivation was traced through [human.c](../../reference/es2/mudlib/adm/daemons/race/human.c) and [chard.c](../../reference/es2/mudlib/adm/daemons/chard.c): age 44 produces max_gin 150, max_kee 595, max_sen 170; setup fills missing current/effective resources from maxima. Learn consumes current teacher `sen`, hence 170 in the current teaching projection. An NPC teacher is checked but not debited; only a player teacher pays sen in `learn.c`. These derived numbers are not proposed new Liu combat stats.

[apprentice.c](../../reference/es2/mudlib/feature/apprentice.c) records master identity/name, family generation +1, title 弟子, privileges 0, and recruitment time. Its identity predicate differs from `learn.c::is_appr_of`: Learn checks master ID and generation. [std/char/master.c](../../reference/es2/mudlib/std/char/master.c) also applies `prevent_learn`: betrayal-scaled teacher ceiling and, for a student failing its direct-apprentice predicate, the teacher-raw versus three-times-student-raw limit. Knowledge alone does not establish teachability.

[SnowSchoolTeacher](../../game/data/snow/snow_school_teacher.gd) already records all eleven raw skills, int 24, teaching spirit 170, generation 13, and offer metadata. [SwordsmanApprenticeship](../../game/core/relationships/swordsman_apprenticeship.gd) already implements the approved narrow recruitment path. However, [SnowSchoolContact](../../game/runtime/world/snow_school_contact.gd) constructs only the unarmed teaching definition/policy/context, and [SnowSchoolInteraction](../../game/ui/snow/snow_school_interaction.gd) exposes only basic unarmed. Teacher metadata is not a working liuh-ken Learn endpoint.

The contact is an approved Native teaching projection, not the source NPC's full AI/combat/drop implementation. Liu's source counterattack chat, blackthorn weapon, silkcloth, other skills, and full school population stay outside this milestone.

## Exact Learn ordering and partial mutations

Authority: [learn.c](../../reference/es2/mudlib/cmds/std/learn.c), lines 24–129, helper 134–144; [feature/skill.c](../../reference/es2/mudlib/feature/skill.c), `improve_skill`, lines 126–155. Native comparison: [LearnService](../../game/core/learning/learn_service.gd) and [FMasterTeacherPreventionPolicy](../../game/core/learning/f_master_teacher_prevention_policy.gd).

1. Parse request; reject fighting (27), absent/non-character teacher (30), or nonliving teacher (33).
2. Inspect marrycard state (37–50), then direct Learn apprenticeship; otherwise spouse, same-family teacher with privilege -1, or the rejection/recognition path (54–64). The latter selects rejection text before asking recognition. P2 retains the already-supported direct Liu relationship; it does not add spouse/player-teaching paths.
3. Require nonzero teacher raw skill (66); call `prevent_learn` (70); require student raw below teacher raw (73–75).
4. Call liuh-ken `valid_learn` (78), checking both weapon references.
5. Compute `150 / teacher_int + 150 / student_int`, with each integer division performed before addition (80).
6. If student raw is zero, double the cost and explicitly `set_skill(skill, 0)` (82–85). This raw-entry mutation precedes later rejection checks.
7. Reject when `learned_points >= potential` (87), then `env/no_teach` (93).
8. Require teacher sen strictly greater than `cost/5 + 1` (100). Debit only a player teacher. A tired teacher returns before Player gin damage; the earlier zero entry remains.
9. Require Player gin strictly greater than cost (111). If sufficient, compare martial `raw^3/10 > combat_exp` (112–114).
10. An EXP rejection makes no learned-progress draw or spent-point increment, but still reaches final gin damage. Otherwise increment `learned_points` by one (120), then draw and call `improve_skill` (121).
11. If Player gin was insufficient or equal to cost, replace cost with current gin (125), with no improvement. Finally `receive_damage("gin", cost)` (129).

This is not an all-preflight transaction. Existing raw-zero presence, spent-point mutation before improvement, and resource mutation ordering must survive typed failure handling. Do not replace LearnService with a second liuh-ken-specific learner.

The improvement draw bound is `int + EXP/(1000 + EXP/1000)` with nested integer division. At the proposed low EXP and source-entry int 30, it is 30. `improve_skill` applies its existing learned-entry-count versus spirituality penalty, treats zero amount as one, and levels only when learned progress is **strictly greater** than `(raw+1)^2`; one level is awarded and overflow discarded. The requested skill ID is liuh-ken. Its inherited level callback is a no-op; basic [unarmed.c](../../reference/es2/mudlib/daemon/skill/unarmed.c) separately has its raw-level/strength callback.

For Liu int 24 and Player int 30, cost is `6 + 5 = 11`, or 22 while raw is zero. Teacher sen must be greater than 3 or 5 respectively; Player gin must be greater than 11 or 22. UI previews must use these same semantics, including repeated raw-zero costs and the distinction between remaining potential and learned progress.

## Combat EXP thresholds and proposed finish

The gate rejects only when `floor(raw^3/10) > EXP`. Equality passes. These are requirements to **continue learning at that current raw level**, not the EXP needed merely to possess that level.

| Current raw | Minimum EXP to improve at that level |
| ---: | ---: |
| 0 | 0 |
| 1 | 0 |
| 2 | 0 |
| 3 | 2 |
| 4 | 6 |
| 5 | 12 |
| 6 | 21 |
| 7 | 34 |
| 8 | 51 |
| 9 | 72 |
| 10 | 100 |

Thus EXP 0 permits reaching raw 3, EXP 2 permits raw 3 -> 4, and EXP 6 permits raw 4 -> 5. EXP 12 is needed to continue from raw 5. The older `E>=6 / unarmed4 / liuh5` proposal is arithmetically valid after independent recomputation. Neither unarmed 4 nor EXP 6 is an authored prerequisite to begin learning liuh-ken: the only skill-specific Learn predicate is both hands empty. The finish is a proposed product acceptance boundary.

## Enable, effective skill, and equipment boundaries

Authority: [enable.c](../../reference/es2/mudlib/cmds/std/enable.c), lines 70–112; [feature/skill.c](../../reference/es2/mudlib/feature/skill.c), lines 38–77; [attack.c](../../reference/es2/mudlib/feature/attack.c), `reset_action`, lines 202–220; [equip.c](../../reference/es2/mudlib/feature/equip.c), wield/unequip action reset.

`enable unarmed liuh-ken` requires a valid use, nonzero raw liuh-ken, nonzero raw basic unarmed, and `valid_enable("unarmed")`. It calls `map_skill`, then `reset_action`. The magic/force/spells resource resets do not apply to unarmed. Defined raw-zero entries are insufficient for the Enable command, although lower-level `map_skill` is less restrictive; the UI must use [SkillEnableTransition](../../game/core/skills/skill_enable_transition.gd), not bypass it.

Explicit `none` clears the mapping and resets action before the other-skill checks. Disabling does not delete raw/learned skills, spend resources, or remove apprenticeship. [CharacterSkillState](../../game/core/skills/character_skill_state.gd) already has `unmap_skill`; the contact/UI command and fresh action projection still need wiring. The source command has no empty-hand requirement and no explicit busy/fighting/family gate. Limiting this new UI to a noncombat Liu interaction would be an explicit Native availability substitution, not an LPC rule.

For nonnegative raw levels, with integer truncation:

`effective_unarmed = temporary_apply_unarmed + raw_unarmed / 2 + mapped_liuh_raw`

The last term is zero when unmapped. Temporary bonuses enter the existing effective-skill computation; they are not persisted as a newly invented martial stat.

| Boundary | Source behavior | Native P2 implication |
| --- | --- | --- |
| Learn | Neither primary nor secondary weapon reference may exist | Reuse [RequireBothWeaponRefsEmptySkillLearnPolicy](../../game/core/learning/require_both_weapon_refs_empty_skill_learn_policy.gd), already registered for liuh-ken |
| Enable | Nonzero basic/special raw and valid use; no hand check | Do not call Learn policy as an Enable predicate |
| Ordinary action selection | Primary weapon selects its skill type; no primary selects unarmed; then mapped skill wins | Map remains stored when a sword is wielded; sword action profile is used instead |
| Wield / unequip | Rebuild action selection; do not remove mappings | Reproject current equipment/mapping without clearing skills |
| Secondary-only state | Source reset_action still uses unarmed when primary is absent | Such a state can reject Learn while using unarmed combat; do not add implicit promotion or mapping deletion |
| Armor / carried weapon | Not the two weapon references checked by Learn | Avoid a broad inventory-empty or armor-empty rule |

## Ordinary combat consumption and measurable value

Authority: [combatd.c](../../reference/es2/mudlib/adm/daemons/combatd.c), `skill_power` (165–190), `do_attack` (203–466), `fight` (470–500); [dbase.c](../../reference/es2/mudlib/feature/dbase.c), `query` (34–51); [attribute.c](../../reference/es2/mudlib/feature/attribute.c); [action.c](../../reference/es2/mudlib/feature/action.c); [char.c](../../reference/es2/mudlib/std/char.c) lifecycle.

`reset_action` stores the appropriate mapped action provider. Reading `actions` evaluates that provider through `dbase::query`; an unarmed liuh mapping therefore calls liuh-ken `query_action`. The ordinary attacker skill identity remains `unarmed`, chosen from the primary weapon's skill type or the no-primary fallback, independently of the returned action. No LPC callback cache needs to be recreated in Native code.

The inspected ordinary resolver reads action text, damage type, damage/force modifiers, and its bounded hook sites. It never reads the action's `dodge` or `parry` keys. Their exact source values should remain traceable authored metadata, without extending CombatMath to consume them. All four liuh actions have the same relevant numeric fields. Their `瘀伤` damage type selects outcome narration, not an extra elemental/resistance/damage multiplier.

For skill power, `L = effective_skill + usage_bonus` (attack or defense). A nonliving participant yields zero. At L=0 the source returns `EXP/2`; otherwise, if max_sen > 0:

`power = ((L*L*L / 3) / max_sen) * current_sen + EXP`

Each division truncates at that exact point. If max_sen <= 0 it is `L^3/3 + EXP`. Ordinary AP and DP are floored to one before the busy-defense adjustment; parry has its own final floor. Preserve [CombatMath](../../game/core/combat/math/combat_math.gd), existing resolver, CXR9 zero-damage-base compatibility, and ZE1 zero-EXP defense compatibility rather than retuning any of them.

An attacker first passes `random(AP+DP) >= DP`, then the parry test. Against an armed defender, PP comes from parry and doubles for an unarmed attacker. An unarmed defender facing an armed attacker has zero source parry power before the ordinary floor; mapping unarmed is therefore not an all-purpose defense bonus. Both-unarmed parry uses effective unarmed. Busy affects defense and interruption at the existing lifecycle stages.

| Controlled source calculation, no temporary modifiers, current/max sen 100/100 | Unmapped | Mapped |
| --- | ---: | ---: |
| EXP 2, unarmed 4 / liuh 4: effective unarmed | 2 | 6 |
| Same EXP 2 case: attack power | 2 | 2 |
| EXP 6, unarmed 4 / liuh 5: effective unarmed | 2 | 7 |
| Same EXP 6 case: attack power | 6 | 106 |

The integer plateau at effective 6 matters. The smaller EXP-2 finish proves mapping/action identity and effective-level value, but cannot honestly claim an AP increase under these conditions. At EXP 6 the intended finish crosses that plateau. Against a stationary, nonbusy armed bandit projection with DP 600 and PP 1200, conditional probability of passing both defense tests is `AP/(AP+600) * AP/(AP+1200)`: approximately 0.004926% for AP 6 and 1.21861% for AP 106. These are analytical one-attack distributions, not simulated results, encounter win rates, guaranteed hits, or guaranteed greater damage. Spirit, busy state, live progression and equipment can change them.

Damage still follows existing apply/damage, effective strength, force/hook classification, random strength, defense-EXP reduction, damage/wound and completion ordering. Mapping does not directly add strength or a liuh damage percentage.

## Combat improvement identity

`combatd.c` lines 258–272 / 298–304 / 390–410 and [CombatProgressionService](../../game/core/combat/completion/combat_progression_service.gd) were compared.

- Successful qualifying hit progression improves `attack_skill`, which is **basic unarmed** on this route. It does not improve liuh-ken and does not improve both. Mapping does not rename the progression target.
- Dodge/parry completion improves the defender's basic `dodge` / `parry` when the source comparison, not-both-users restriction and health/intelligence draw permit it. The dodge path also has a separate NPC-attacker low-power progression branch: its EXP draw and subsequent attack-skill improvement draw are distinct; the improvement draw is not conditional on the EXP draw succeeding.
- Hit attacker progression requires AP < DP, not both users, and its health/intelligence roll; it can award EXP, available potential subject to the existing cap, and basic attack-skill improvement. The hit defender's separate post-damage roll can award EXP/potential without a skill improvement.
- EXP is not a fixed victory reward. Basic unarmed's separate `skill_improved` strength callback remains in its existing skill service; liuh-ken's inherited callback adds no such reward.

P2 must preserve those branch conditions, live completion state and RNG order. Ordinary combat is the source of the proposed natural EXP; further liuh-ken levels on this scope come from Learn, not an invented passive special-skill gain.

## Native capability and gap matrix

Codes: **A** already supported; **B** existing capability not wired to this Player route; **C** new authored data; **D** explicit Native compatibility/composition decision; **E** deferred general hook work. These codes are capability labels, distinct from the Type A/B/C ledger below.

| Capability | Current code evidence | Category and proposed bounded work |
| --- | --- | --- |
| Raw / learned / mapped / effective skill | [CharacterSkillState](../../game/core/skills/character_skill_state.gd), [SkillDefinition](../../game/core/skills/skill_definition.gd), existing liuh ID | A/B: reuse state; supply martial definition allowing only unarmed |
| Learn order / equipment policy | [LearnService](../../game/core/learning/learn_service.gd), both-weapon policy, current registry | A/B: compose liuh definition, teacher context and registered policy; no new Learn algorithm |
| Teacher interaction | [teacher](../../game/data/snow/snow_school_teacher.gd), [contact](../../game/runtime/world/snow_school_contact.gd), [UI](../../game/ui/snow/snow_school_interaction.gd) | B/C: existing physical Liu contact; expose only unarmed and liuh, correct chosen-skill previews and result labels |
| Enable / Disable | [SkillEnableTransition](../../game/core/skills/skill_enable_transition.gd), state unmap | A/B/D: explicit contact commands, current mapping/effective readout, refresh action composition; proposed contact availability restriction |
| Authored action representation | [CombatActionDefinition](../../game/core/combat/action/combat_action_definition.gd), existing action sets | C: four stable IDs, exact texts, bruise type, no invented damage/force; dodge/parry remain non-operative metadata |
| Mapped action selection | [CombatActionSelector](../../game/core/combat/action/combat_action_selector.gd) | A/B: mapped -> primary weapon -> default precedence already supported; provide the actual liuh set |
| Runtime projection | [projection builder](../../game/runtime/combat_slice/combat_slice_projection_builder.gd) | B/D: currently supplies a mapping flag with null mapped action set; mapped skills are classified AUTHORED_POLICY_UNAVAILABLE; narrowly bind liuh authority and known absence of authored hit effect |
| Forward execution | [opportunity executor](../../game/runtime/combat_slice/combat_slice_opportunity_executor.gd), [single attack execution](../../game/core/combat/execution/combat_single_attack_execution_service.gd) | D: current attack template is prebuilt; `_matches_attack_projection` requires exact selected-action field equality, including ID/text; compose the validated selected action at the existing selection stage |
| Reverse execution | [attack chain completion](../../game/core/combat/execution/combat_attack_chain_completion_service.gd) | D: same single-template equality constraint; QUICK/RIPOSTE must bind their own one selected action from freshly projected live reverse state |
| Math / resolution / progression | [CombatMath](../../game/core/combat/math/combat_math.gd), existing resolver and completion | A: preserve formulas, guards, busy, lifecycle, completion and progression identity |
| Live authority / cadence | [binding adapter](../../game/runtime/characters/world_combat_binding_adapter.gd), [encounter scheduler](../../game/runtime/combat_encounter/combat_encounter_scheduler.gd) | A: shared CharacterState/equipment/relationship/busy authority and existing Active Semi-Auto cadence |
| Feedback | [BattleFeedbackReader](../../game/presentation/battle/battle_feedback_reader.gd), [CombatAttackResult](../../game/core/combat/resolution/combat_attack_result.gd) | B/C: selected/committed action IDs already exist, generic feedback omits names; derive authored presentation from those IDs and existing results, including terminal receipts |
| General effect dispatch | Phase 5B4, dynamic perform/exert/post-hit/conditions | E: no extension; unknown effects remain refused |

The execution change must retain the validated source action set, participant/weapon identities, complete selected-action fields and live scalar checks. Select once, validate membership/authority, compose that exact action input, then resolve. Do not delete `_matches_attack_projection` checks wholesale, pre-roll an action to make the template match, select twice, or cache a favorable action. Reverse completion currently checks live post-forward EXP, spirit, raw attributes, equipment, mappings and modifiers; that coherence must survive the bounded multi-action extension.

[CombatSliceContentProfile](../../game/runtime/combat_slice/combat_slice_content_profile.gd) currently certifies one default human punch and one weapon slash. Source human fallback has five actions, but that previous Native scope is not expanded here. Add a separate validated liuh mapped set; do not replace default unarmed with liuh, change unmapped RNG distribution, or weaken Beast/profile admission.

## Action RNG and opportunity ownership

Use the existing [GodotCombatRandomSource](../../game/runtime/combat_slice/godot_combat_random_source.gd), not WorldInteraction RNG or a fourth stream. Learn continues using the existing WorldInteraction source.

The native selector makes exactly one `next_below(action_count)` after successful action-source validation, including for a one-action set. Liuh uses count 4. The draw belongs after a real fight opportunity reaches attack execution and before limb/resolution draws; all four outcomes remain reachable without level gates. ES2's fight decision and Native cadence may consume preceding fight-decision draws without selecting an attack. The current encounter fixes the selected target; it does not add the source's separate opponent-selection random-4 draw.

Paused/non-active sessions, invalid delta, rejected authority before execution, non-due cadence, and busy-only progression do not acquire an action draw. Flee uses its existing separate path before ordinary attacks. This is not a promise that every late invalid result rolls back every earlier draw: coherent execution retains established prior-consumption semantics. Tests must distinguish preselection rejection from failures after selection.

Each actual reverse attack has its own action selection in the existing reverse order. No presentation query may reroll; feedback reads committed results. Changing action count from one to four intentionally changes bounded-selection semantics; preserving a seed does not promise identical old combat trajectories. Preserve exact PCG seed/state at Save and restore without a draw, then test continuation from that state. Do not serialize a preselected next liuh action.

## Smallest Player interaction and presentation

Extend the existing Liu panel with Learn liuh-ken, both raw levels/learned progress, available potential and gin cost/result, explicit enable/disable, current unarmed mapping, and effective unarmed. Keep the existing physical Snow school contact, map/zone/proximity, active-session, pause, combat and busy authority gates. Applying those contact gates to new mapping controls is a proposed Native UI limitation; it is not required by `enable.c` itself.

Use existing responsive input/UI contracts, real buttons and shared state. Do not build a generic Skills app, tree, hotbar, technique loadout, trainer framework or command console. Do not grant skills when opening the panel. Disabling uses the source `none` meaning and preserves learned state.

Recommended feedback is all four exact authored action texts, with existing committed attacker/target/limb substitutions, plus the existing outcome text. Stable action ID -> authored text is presentation lookup, not a second authoritative combat event. Read forward and reverse results and preserve terminal feedback after an encounter ends. If the owner chooses compact action names instead, record that presentation substitution explicitly; never invent hit success or damage from an action name.

## Save and cold Continue

Inspected [world save capture](../../game/runtime/persistence/oldpine_world_save_capture.gd), [JSON codec](../../game/core/persistence/game_save_json_codec.gd), [snapshot validator](../../game/core/persistence/game_save_snapshot_validator.gd), [character restorer](../../game/core/persistence/character_state_snapshot_restorer.gd), and [restore composition](../../game/runtime/persistence/oldpine_world_restore_composition.gd).

| Required state | Existing persistence path | P2 acceptance |
| --- | --- | --- |
| Raw liuh-ken, including explicit zero presence | Generic raw-skill entries and state presence flags | Exact level, entry/presence semantics after cold restore |
| Learned liuh-ken progress | Generic learned-skill entries | Exact remainder and presence, not reconstructed from raw |
| unarmed -> liuh-ken | Generic mappings; validation requires defined target | Exact map and disable state; no new allowlist/schema field |
| Combat EXP / potential / spent learned points | Existing character fields | Exact values, including source-ordered partial Learn mutations |
| Family / master / class | Existing family/master/affiliation snapshots | Same identity, generation, class and relation |
| Combat RNG | Existing seed/state strings and restore path | Exact state with no restore draw; next action/resolution uses that state |
| Other RNG / physical state / equipment | Existing three-stream and world/item capture | Full snapshot coherence; no isolated skill-only restore claim |

No required state is missing. Keep current root schema 2, item schema 3 and SOURCE_ENTRY_V1 compatibility; no schema version change is proposed. Authored skill/action definitions are composition data, not mutable Save payload. Transient panel selection and an active encounter are not new persisted state; Save occurs under the existing permitted lifecycle boundary. A new action-ID catalogue does not justify changing character serialization.

This is static persistence-path evidence. P2 still must Save, terminate the entire process, start a fresh process, Continue, compare the full state and all RNG streams, and exercise subsequent mapped combat. An in-process reload or a skills-only equality check is insufficient.

## Natural Player journey: feasible structure, unproven EXP-6 duration

The current SOURCE_ENTRY_V1 starts at age 14 with base attributes 30, resources 100, EXP 0, potential 99, empty weapon hands and cloth. Food/water and the existing work, bank, dumpling/wine and waterfall supply loop support recovery. Earlier CXR9 technical birth/combat fixtures and Hockshop QA-injected high EXP/strength are not the current birth contract and are not evidence for this route.

The integrated Snow First Progression final audit recorded a real New Game journey with nine Bandit03 encounters and real Flee input: EXP remained zero through encounter six, reached one in encounter seven and two in encounter nine, followed by return to Liu, unarmed 3 -> 4, and exact Save/process-stop/cold-Continue evidence. That is historical evidence, not a fresh P1 runtime run. It establishes a production EXP-2 path; it does not establish EXP 6, liuh learning/UI, or mapped liuh combat.

The primary proposed route is New Game -> Snow Inn -> supplies/work as needed -> physical Liu apprenticeship/basic training -> physical Snow/Old Pine traversal -> production combat EXP >=6 -> return to Liu -> source-valid liuh Learn to >=5 with unarmed >=4 -> enable -> return to ordinary combat -> observe committed liuh actions -> leave combat under existing rules -> Save -> terminate -> cold Continue -> exact restore -> further correct combat. The source permits learning some liuh earlier; that alternate ordering is not a free-skill shortcut, but must be specified before acceptance if chosen.

Recovery is conditional, takes time, and can consume supplies. UNCONSCIOUS is not equivalent to ordinary recoverable active/noncombat rest. Flee is not a survival guarantee, and EXP is stochastic rather than a per-fight award. Consequently EXP-6 practical reachability remains a material runtime risk: no deterministic source impossibility was found, but P1 cannot certify session length, survivability or success probability. If authorized P2 cannot complete it naturally, report the acceptance blocker and stop for owner review; do not silently inject EXP, retune enemies, change recovery or lower the finish. The smaller option below explicitly limits that risk.

## Type A / B / C ledger for proposed P2 behavior

| Proposed behavior | Type | Authority or substitution boundary |
| --- | --- | --- |
| Eleven teacher raw facts, liuh martial definition and four exact actions | A | Direct source data; teacher offer surface limited to two skills |
| Both-weapon-empty Learn predicate; teacher relationship/prevention; Learn mutation order, costs, RNG bounds and EXP gate | A | Existing typed Learn services preserve inspected LPC semantics |
| Raw/learned/mapping state; enable valid use and nonzero levels; explicit none; effective-skill formula | A | Feature skill and enable source; no invented reset or cooldown |
| Primary-weapon selection; four-action draw; ordinary AP/DP/damage/progression identity | A | Inspected ordinary consumers, including non-consumption of action dodge/parry |
| Physical Liu contact, active/noncombat interaction and responsive buttons | B | Existing approved Native world/UI approach; applying availability gates to new mapping controls is proposed |
| Source action providers represented as typed authored sets and IDs | B | Native data/composition replaces LPC closures; exact action payload remains Type A |
| Bind selected action into forward/reverse validated execution inputs | B | Narrow Native composition contract extension; keep one resolver, exact selection point and authority checks |
| liuh known-no-authored-hit-effect classification | B | Explicit Native treatment of inspected absent authored hook; not a claim about missing-lfun driver behavior or a general effect framework |
| Existing seeded Combat / WorldInteraction RNG and exact persistence | B | Retain approved Native streams; source draw bounds/order remain Type A |
| Committed action feedback / optional compact display | B | Presentation only, no extra roll or state mutation; full source text recommended |
| Full native Save/process restart and physical travel | B | Existing approved Native persistence/world model, unchanged schema |
| Existing CXR9 and ZE1 compatibility boundaries | B | Already integrated decisions retained, not new martial balance changes |
| EXP-6 finish and chosen natural route | B | Proposed product acceptance boundary, not a source unlock rule or a new mechanic |

**Type C target = 0.** Free skills/EXP, action dodge/parry buffs, special-skill combat XP, guaranteed bonus damage, new cooldowns, fixed favorable RNG, and silent enemy/recovery retuning are excluded. Proposed Type B extensions are not owner-approved decisions merely because they appear in P1; DECISIONS is unchanged.

## Exactly three ranked P2 options

| Criterion | 1. Recommended: Minimal Martial Progression | 2. Smaller fallback: First mapped art | 3. Larger option: Extended single-art progression |
| --- | --- | --- | --- |
| Finish / Player value | Natural EXP >=6, unarmed >=4, liuh >=5; four actions, effective 2 -> 7 and demonstrable AP distribution change under controlled conditions | Natural EXP >=2, unarmed >=4, liuh >=4; four actions and effective 2 -> 6, without claiming AP improvement on the integer plateau | Natural EXP >=12, unarmed >=6, liuh >=6; effective 3 -> 9, broader progression plus portable two-skill mapping controls |
| Source fidelity | Exact liuh Learn/Enable/ordinary combat | Same exact four-action semantics; smaller finish, not one hardcoded action | Same source rules; portable Native mapping location explicitly scoped |
| Architecture delta | Liu contact, definition/four-action data, narrow forward/reverse composition and classification, feedback | Nearly the same integration; less journey/finish scope, not a shortcut around execution contracts | All primary changes plus portable mapping UI and wider lifecycle/input coverage |
| Principal risk | EXP-6 natural duration/survival, multi-action coherence, driver-boundary classification | Multi-action coherence remains; EXP-2 precedent reduces but does not eliminate live risk | More stochastic play/recovery, resource expenditure, UI lifecycle and validation scope |
| Save impact | No schema change; exact full cold continuation | Same | Same expected schema; extra UI remains transient |
| Combat impact | Selected liuh set in existing forward/QUICK/RIPOSTE; no formulas changed | Same action integration; no false hit-rate promise at EXP 2 | Same formulas; higher raw/EXP envelope, no new special techniques |
| Runtime burden | Full natural journey, real contact/enable, mapped attacks, equipment boundary, cold Continue, affected mobile UI | Full route to EXP 2, mapping/actions/cold Continue; no shortcut via injected state | Longer EXP-12 route, higher training, portable control availability and more mobile/lifecycle cases |
| Explicit exclusions | All deferred systems below; no portable Skills app | Same; excludes higher finish and outcome-boost promise | Still one art; no general Skills app, other arts, hooks, default human-action expansion or rebalance |

Option 1 is recommended for meaningful source-backed outcome distribution value. Option 2 is a legitimate fallback if the owner prefers the smaller natural-play requirement; it does not pretend four-action combat integration is cheaper than it is. Option 3 is not recommended for this next minimal slice.

## Proposed P2 verification contract and owner decisions

If P2 is later authorized, focused tests should cover Learn ordering/partial mutations, raw-zero cost and strict gin gates, every EXP boundary above, both weapon references, enabling/unmapping, all four authored actions, absence of invented action modifiers, forward and reverse selected-action coherence, preselection versus postselection RNG failure boundaries, progression of basic unarmed only, and full Save validation/restore. Existing test families for skill core, Learn, equipment policies, synchronous reverse attacks, encounter lifecycle and persistence provide the foundation; they were inspected as dependencies, not rerun as P1 acceptance tests.

Distinct verification must then use the canonical game with healthy helper/runtime evidence, real input and physical routes. The natural journey must not inject XP, skills, production QA stats, or favorable RNG. All four actions can be exhaustively checked using deterministic test sources in domain tests; live proof must show actual randomly selected liuh actions and committed IDs/results, not reroll until a chosen animation appears. Affected desktop/mobile UI, pause/busy/rejection paths, weapon transitions, terminal feedback, full process restart and post-Continue combat need acceptance evidence. Analysis probabilities do not replace that evidence.

Only these decisions remain for the owner:

1. Approve a P2 scope and exact finish: recommended natural EXP 6 / unarmed 4 / liuh 5, fallback EXP 2 / 4 / 4, or the larger option. Keep a stop-and-report gate if the selected natural route proves impractical.
2. Approve the proposed local Liu Enable/Disable controls and their noncombat contact availability, or explicitly choose the larger portable control scope. Disable semantics themselves are source-settled.
3. Choose full authored action text with committed substitutions (recommended) or compact names with an explicit presentation substitution. Four authored choices and their source values are not open design questions in a source-valid liuh port.
4. Accept the narrow Native known-no-authored-effect classification and selected-action composition extension as the proposed implementation boundary; this does not authorize general missing-lfun behavior or Phase 5B4.
5. Confirm the proposed finish/journey and platform validation scope when authorizing P2. Existing real-input, helper health and process-restart requirements remain mandatory; they are not optional owner shortcuts requested by this analysis.

## Explicit deferrals and Migration Tooling boundary

Defer fonxanforce, force enable, exercise/internal force, fonxansword/sword progression, chaos-steps, spider-array, practice, study, selflearn, perform, exert, special techniques, weapon_storage/free bamboo sword, inner yard, secret storage, school board/full population, Liu combat/drop, Player teaching, changing master, expell, spouse-card behavior and full faction systems.

Also defer Phase 5B4, general post-hit hooks, condition-producing attacks, Lake/serpent, generic Skills app/tree/hotbar/loadout/trainer/console, and full default-human-action parity. No second resolver, LPC interpreter or runtime compatibility layer is proposed.

Migration Tooling v1 remains COMPLETE / integrated. No Migration Tooling P3, NPC/skill/item extractor, generator, Native generation or new Migration IR consumer is authorized. This analysis used direct source reading; no tooling output was treated as martial authority.

## P1 validation and delivery record

P1 changes exactly this new report, STATUS and ROADMAP. STATUS registers the new planning state and explicitly withholds P2 authorization; ROADMAP appends the new milestone after Migration Tooling. Prior Migration Tooling closeout/history text is preserved, and DECISIONS is unchanged.

Fresh docs-only verification: `python tools/ci/repository_checks.py --repository .` PASS; `git diff --check` PASS; all 272 local Markdown links across the three changed documents resolve, including four anchor references. Baseline comparison confirms the previous STATUS Migration Tooling content and the entire previous ROADMAP content are preserved. Independent review rechecked source threshold arithmetic, the integer-power plateau, both execution-template guards, and the distinction between ordinary basic-skill progression and liuh learning.

The delivery gate also requires exact three-file scope and zero delta under reference/es2, game, tools/tests, production tools, workflow/build and DECISIONS. The final commit/remote identity and clean-worktree result are reported with delivery rather than embedded as a self-referential commit hash. No Godot gameplay runtime PASS or fresh gameplay test-suite result is claimed for this docs-only P1. The previously green four-job main run is the branch creation gate, not CI for this P1 commit.

P1 ANALYSIS COMPLETE — AWAIT OWNER REVIEW
