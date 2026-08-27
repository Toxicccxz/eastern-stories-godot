extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CombatActionDefinitionScript := preload(
	"res://core/combat/action/combat_action_definition.gd"
)
const CombatStrengthProjectionScript := preload(
	"res://core/combat/resolution/combat_strength_projection.gd"
)
const CombatHitPolicyStatusScript := preload(
	"res://core/combat/resolution/combat_hit_policy_status.gd"
)
const CombatAttackerSnapshotScript := preload(
	"res://core/combat/resolution/combat_attacker_snapshot.gd"
)
const WeaponCombatProfileScript := preload(
	"res://core/combat/resolution/weapon_combat_profile.gd"
)
const CombatDefenderSnapshotScript := preload(
	"res://core/combat/resolution/combat_defender_snapshot.gd"
)
const CombatAttackInputScript := preload(
	"res://core/combat/resolution/combat_attack_input.gd"
)
const CombatAttackResultScript := preload(
	"res://core/combat/resolution/combat_attack_result.gd"
)
const CombatProgressionFactsScript := preload(
	"res://core/combat/completion/combat_progression_facts.gd"
)
const CombatProgressionResultScript := preload(
	"res://core/combat/completion/combat_progression_result.gd"
)
const CombatBusyInterruptProjectionScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_projection.gd"
)
const CombatBusyInterruptResultScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_result.gd"
)
const CombatStatusReportBoundaryResultScript := preload(
	"res://core/combat/completion/combat_status_report_boundary_result.gd"
)
const CombatOrdinaryAttackResultScript := preload(
	"res://core/combat/completion/combat_ordinary_attack_result.gd"
)
const CombatAttackCompletionServiceScript := preload(
	"res://core/combat/completion/combat_attack_completion_service.gd"
)
const ActionBusyStateScript := preload("res://core/combat/busy/action_busy_state.gd")
const ScriptedCombatRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_dodge_defender_progression()
	_test_dodge_defender_boundaries()
	_test_dodge_npc_attacker_progression()
	_test_parry_progression()
	_test_hit_gates_and_live_defender_resource()
	_test_hit_attacker_progression_and_effect()
	_test_hit_partial_failures_and_threshold()
	_test_missing_attack_skill_definition_ordering()
	_test_status_report_boundary_ordering()
	_test_busy_ordering_and_modes()
	_test_projection_coherence_and_base_failure()
	_test_result_snapshots_and_independent_characters()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_dodge_defender_progression() -> void:
	var attacker: CharacterStateScript = _character(0, 20, 20)
	var defender: CharacterStateScript = _character(1, 20, 20, 50, 100)
	defender.attributes.intelligence_modifier = 100
	var rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new(
		[0, 0, 51]
	)
	var result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), attacker, defender, true, false, rng
	)
	var progression: CombatProgressionResultScript = result.progression_result
	_assert_eq(result.outcome, CombatOrdinaryAttackResultScript.Outcome.COMPLETED, "dodge composition completes")
	_assert_eq(result.base_result.outcome, CombatAttackResultScript.Outcome.DODGE, "base branch is dodge")
	_assert_eq(rng.requested_bounds(), [2, 12, 70], "dodge progression uses current gin * 100 / max gin + raw int")
	_assert_eq(defender.attributes.effective_intelligence(), 120, "fixture distinguishes raw from effective intelligence")
	_assert_true(progression.defender_condition_matched, "strict dp < ap mixed-user dodge gate matches")
	_assert_true(progression.defender_roll_succeeded, "dodge progression roll 51 passes strict > 50")
	_assert_eq(defender.progression.combat_experience, 2, "dodge increments defender combat exp before skill")
	_assert_eq(defender.skills.learned_progress(&"dodge"), 1, "dodge delegates amount one to improve_skill")
	_assert_true(progression.defender_skill_improvement_attempted, "dodge skill attempt is explicit")
	_assert_eq(progression.defender_skill_effect.status, SkillImprovementEffectResult.Status.NOT_LEVELED_UP, "non-level-up still routes through effect registry")

	var equal_attacker: CharacterStateScript = _character(1, 20, 20)
	var equal_defender: CharacterStateScript = _character(1, 20, 20)
	var equal_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0])
	var equal_result: CombatOrdinaryAttackResultScript = _complete(
		_input(1, 1, 2, 2), equal_attacker, equal_defender, false, false, equal_rng
	)
	_assert_eq(equal_result.base_result.calculation.attack_power, 3, "equality fixture AP is three")
	_assert_eq(equal_result.base_result.calculation.dodge_power, 3, "equality fixture DP is three")
	_assert_false(equal_result.progression_result.defender_condition_matched, "dp == ap does not progress dodge")
	_assert_eq(equal_rng.call_count(), 2, "false dodge gate consumes no progression RNG")

	var users_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0])
	var users: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), _character(1), true, true, users_rng
	)
	_assert_false(users.progression_result.defender_condition_matched, "both-user dodge skips progression")
	_assert_eq(users_rng.call_count(), 2, "both-user dodge consumes no progression RNG")


func _test_dodge_defender_boundaries() -> void:
	var strict_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0, 50])
	var strict_defender: CharacterStateScript = _character(1, 20, 20, 50, 100)
	var strict: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), strict_defender, true, false, strict_rng
	)
	_assert_false(strict.progression_result.defender_roll_succeeded, "dodge equality 50 fails strict > 50")
	_assert_eq(strict_defender.progression.combat_experience, 1, "failed threshold mutates no exp")

	var zero_max: CharacterStateScript = _character(1, 20, 20, 0, 0)
	var zero_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0])
	var zero: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), zero_max, true, false, zero_rng
	)
	_assert_eq(zero.outcome, CombatOrdinaryAttackResultScript.Outcome.PROGRESSION_FAILED, "zero max gin is typed at progression position")
	_assert_eq(zero.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.DODGE_DEFENDER_GIN_DIVISION, "zero max gin retains exact dodge stage")
	_assert_eq(zero_rng.call_count(), 2, "zero max gin is not prevalidated and consumes resolver RNG first")

	var nonpositive: CharacterStateScript = _character(1, 0, 20, -1, 100)
	var bound_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0])
	var bound: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), nonpositive, true, false, bound_rng
	)
	_assert_eq(bound.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.DODGE_DEFENDER_RANDOM_BOUND, "nonpositive dodge bound is typed without clamp")
	_assert_true(bound.progression_result.has_failed_random_bound, "invalid dodge bound presence is explicit")
	_assert_eq(bound.progression_result.failed_random_bound, -1, "invalid dodge bound preserves exact source arithmetic")
	_assert_eq(bound_rng.call_count(), 2, "nonpositive progression bound is not sent to RNG")


func _test_dodge_npc_attacker_progression() -> void:
	var attacker: CharacterStateScript = _character(0, 20, 20)
	var defender: CharacterStateScript = _character(1, 20, 20)
	var rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new(
		[0, 0, 16, 0]
	)
	var result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 2, 0), attacker, defender, false, true, rng
	)
	var progression: CombatProgressionResultScript = result.progression_result
	_assert_eq(result.base_result.calculation.attack_power, 1, "NPC dodge fixture AP is one")
	_assert_eq(result.base_result.calculation.dodge_power, 10, "NPC dodge fixture DP is ten")
	_assert_true(progression.attacker_condition_matched, "NPC attacker ap < dp gate matches")
	_assert_eq(rng.requested_bounds(), [2, 11, 20, 20], "NPC dodge makes two independent raw-int draws")
	_assert_eq(attacker.progression.combat_experience, 1, "NPC roll1 > 15 increments combat exp")
	_assert_true(progression.attacker_second_roll_performed, "NPC roll2 always occurs")
	_assert_eq(attacker.skills.learned_progress(&"unarmed"), 1, "roll2 zero reaches improve_skill zero-to-one rule unchanged")

	var equality_attacker: CharacterStateScript = _character(0, 20, 20)
	var equality_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0, 15, 1])
	_complete(_input(0, 1, 1, 3, 2, 0), equality_attacker, _character(1), false, true, equality_rng)
	_assert_eq(equality_attacker.progression.combat_experience, 0, "NPC roll1 equality 15 does not increment exp")
	_assert_eq(equality_attacker.skills.learned_progress(&"unarmed"), 1, "NPC roll2 still improves after roll1 failure")

	var partial_attacker: CharacterStateScript = _character(0, 20, 20)
	var partial_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0, 16, 20])
	var partial: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 2, 0), partial_attacker, _character(1), false, true, partial_rng
	)
	_assert_eq(partial.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.DODGE_ATTACKER_SKILL_RANDOM_DRAW, "invalid second NPC draw has exact stage")
	_assert_eq(partial_attacker.progression.combat_experience, 1, "invalid second draw preserves earlier exp")
	_assert_eq(partial_attacker.skills.learned_progress(&"unarmed"), 0, "invalid second draw precedes improve_skill")
	_assert_true(partial.partial_mutation_preserved, "outer result identifies partial progression mutation")

	var invalid_int_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 0])
	var invalid_int: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 2, 0),
		_character(0, 0),
		_character(1),
		false,
		true,
		invalid_int_rng,
	)
	_assert_eq(invalid_int.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.DODGE_ATTACKER_EXP_RANDOM_BOUND, "nonpositive NPC raw int fails at first required draw")
	_assert_eq(invalid_int_rng.call_count(), 2, "nonpositive NPC raw int consumes no progression RNG")


func _test_parry_progression() -> void:
	var defender: CharacterStateScript = _character(1, 20, 20, 50, 100)
	var rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 0, 51])
	var result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), defender, true, false, rng
	)
	_assert_eq(result.base_result.outcome, CombatAttackResultScript.Outcome.PARRY, "base branch is parry")
	_assert_eq(rng.requested_bounds(), [2, 12, 12, 70], "parry uses identical defender health-int bound")
	_assert_eq(defender.progression.combat_experience, 2, "parry increments defender exp")
	_assert_eq(defender.skills.learned_progress(&"parry"), 1, "parry improves only parry")
	_assert_eq(defender.skills.learned_progress(&"dodge"), 0, "parry does not improve dodge")
	var strict_defender: CharacterStateScript = _character(1, 20, 20, 50, 100)
	var strict: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), strict_defender, true, false,
		ScriptedCombatRandomSourceScript.new([0, 3, 0, 50])
	)
	_assert_false(strict.progression_result.defender_roll_succeeded, "parry equality 50 fails strict > 50")
	_assert_eq(strict_defender.progression.combat_experience, 1, "failed parry threshold mutates no exp")
	var zero_max: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), _character(1, 20, 20, 0, 0), true, false,
		ScriptedCombatRandomSourceScript.new([0, 3, 0])
	)
	_assert_eq(zero_max.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.PARRY_DEFENDER_GIN_DIVISION, "parry zero max gin is typed at exact branch")

	var npc_attacker: CharacterStateScript = _character(0, 20, 20)
	var no_block_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 10, 0])
	var no_block: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 0, 0), npc_attacker, _character(1), false, true, no_block_rng
	)
	_assert_eq(no_block.base_result.outcome, CombatAttackResultScript.Outcome.PARRY, "low-AP fixture still parries")
	_assert_eq(no_block_rng.call_count(), 3, "parry has no NPC attacker failed-hit RNG block")
	_assert_eq(npc_attacker.skills.learned_progress(&"unarmed"), 0, "parry does not teach attacker skill")


func _test_hit_gates_and_live_defender_resource() -> void:
	var both_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0])
	var both: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), _character(1), true, true, both_rng
	)
	_assert_eq(both.base_result.outcome, CombatAttackResultScript.Outcome.HIT, "both-user fixture hits")
	_assert_false(both.progression_result.outer_condition_matched, "both users skip all HIT progression")
	_assert_eq(both_rng.call_count(), 6, "both-user HIT consumes no progression RNG")

	var defender: CharacterStateScript = _character(1, 20, 20, 100, 100, 20, 100)
	var rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 7])
	var hit: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), defender, true, false, rng
	)
	_assert_eq(hit.base_result.calculation.requested_damage, 8, "control HIT requests eight damage")
	_assert_eq(defender.vitality.current, 12, "base damage mutates kee before progression")
	_assert_eq(rng.requested_bounds()[-1], 112, "defender progression bound uses live post-damage kee")
	_assert_eq(hit.status_report_result.outcome, CombatStatusReportBoundaryResultScript.Outcome.VALIDATED, "positive HIT reaches report_status after progression")
	_assert_eq(hit.status_report_result.value_source, CombatStatusReportBoundaryResultScript.ValueSource.CURRENT_VITALITY, "non-wounding HIT reports current kee")
	_assert_eq(hit.status_report_result.ratio, 12, "current kee report ratio preserves integer arithmetic")
	_assert_true(hit.progression_result.defender_roll_succeeded, "draw 7 is strictly less than requested D 8")
	_assert_eq(defender.progression.combat_experience, 2, "successful defender HIT roll increments exp")
	_assert_eq(defender.progression.potential, 1, "successful defender HIT roll increments potential")
	_assert_false(hit.progression_result.defender_skill_improvement_attempted, "HIT defender progression has no skill improvement")

	var equality_defender: CharacterStateScript = _character(1, 20, 20, 100, 100, 20, 100)
	var equality_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 8])
	var equality: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), equality_defender, true, false, equality_rng
	)
	_assert_false(equality.progression_result.defender_roll_succeeded, "defender draw equality D fails strict <")

	var gap_defender: CharacterStateScript = _character(1, 20, 20, 100, 100, 20, 100)
	gap_defender.progression.potential = 110
	gap_defender.progression.potential_spent = 10
	var gap_result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), gap_defender, true, false,
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 7])
	)
	_assert_true(gap_result.progression_result.defender_roll_succeeded, "defender gap fixture succeeds")
	_assert_eq(gap_defender.progression.potential, 110, "defender potential gap exactly 100 does not increment")


func _test_hit_attacker_progression_and_effect() -> void:
	var attacker: CharacterStateScript = _character(0, 20, 20, 50, 100)
	attacker.progression.potential = 109
	attacker.progression.potential_spent = 10
	attacker.skills.set_raw_level(&"unarmed", 8)
	attacker.skills.set_learned_progress(&"unarmed", 81)
	var defender: CharacterStateScript = _character(1, 20, 20)
	var rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new(
		[0, 10, 1, 0, 0, 31, 0]
	)
	var result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 0, 0, false, 10, 0), attacker, defender, false, true, rng
	)
	var progression: CombatProgressionResultScript = result.progression_result
	_assert_eq(result.base_result.outcome, CombatAttackResultScript.Outcome.HIT, "low-AP forced fixture hits")
	_assert_eq(rng.requested_bounds(), [2, 11, 2, 10, 1, 70, 195], "global HIT RNG order is resolver then attacker then defender")
	_assert_true(progression.attacker_first_roll_succeeded, "attacker draw 31 passes strict > 30")
	_assert_eq(attacker.progression.combat_experience, 1, "HIT attacker exp increments first")
	_assert_eq(attacker.progression.potential, 110, "potential gap 99 increments without cap-to-100")
	_assert_eq(attacker.skills.raw_level(&"unarmed"), 9, "HIT attacker delegates amount one to improve_skill")
	_assert_eq(attacker.attributes.strength, 2, "unarmed level-nine authored effect is routed")
	_assert_eq(progression.attacker_skill_effect.status, SkillImprovementEffectResult.Status.APPLIED, "authored effect evidence is retained")

	var gap_attacker: CharacterStateScript = _character(0, 20, 20, 50, 100)
	gap_attacker.progression.potential = 110
	gap_attacker.progression.potential_spent = 10
	var gap_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 10, 1, 0, 0, 31, 0])
	_complete(
		_input(0, 1, 1, 3, 0, 0, false, 10, 0),
		gap_attacker,
		_character(1),
		false,
		true,
		gap_rng,
	)
	_assert_eq(gap_attacker.progression.potential, 110, "potential gap exactly 100 does not increment")


func _test_hit_partial_failures_and_threshold() -> void:
	var zero_gin_attacker: CharacterStateScript = _character(0, 20, 20, 0, 0)
	var damaged_defender: CharacterStateScript = _character(1)
	var zero_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 10, 1, 0, 0])
	var zero: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 0, 0, false, 10, 0),
		zero_gin_attacker,
		damaged_defender,
		false,
		true,
		zero_rng,
	)
	_assert_eq(zero.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.HIT_ATTACKER_GIN_DIVISION, "HIT attacker zero max gin fails after resolver")
	_assert_eq(damaged_defender.vitality.current, 95, "late attacker division failure preserves damage")
	_assert_true(zero.partial_mutation_preserved, "late attacker failure reports preserved mutation")

	var attacker: CharacterStateScript = _character(0, 20, 20, 50, 100)
	var invalid_defender: CharacterStateScript = _character(1, 20, 20, 100, 100, 0, 0)
	var late_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 10, 1, 0, 0, 31])
	var late: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 0, 0, false, 10, 0),
		attacker,
		invalid_defender,
		false,
		true,
		late_rng,
	)
	_assert_eq(late.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.HIT_DEFENDER_RANDOM_BOUND, "nonpositive live kee bound fails at late defender stage")
	_assert_eq(attacker.progression.combat_experience, 1, "late defender failure preserves attacker exp")
	_assert_eq(attacker.progression.potential, 1, "late defender failure preserves attacker potential")
	_assert_eq(attacker.skills.learned_progress(&"unarmed"), 1, "late defender failure preserves attacker skill progress")
	_assert_eq(invalid_defender.vitality.current, -1, "late defender failure preserves saturated damage")
	_assert_eq(late.base_result.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.UNCONSCIOUS, "threshold candidate is retained")

	var saturated: CharacterStateScript = _character(1, 20, 20, 100, 100, 3, 100)
	var threshold_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 4])
	var threshold: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), saturated, true, false, threshold_rng
	)
	_assert_eq(threshold.base_result.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.UNCONSCIOUS, "base reports unconscious candidate")
	_assert_eq(threshold_rng.requested_bounds()[-1], 99, "saturated current -1 is used in defender progression bound")
	_assert_true(threshold.progression_result.defender_combat_experience_incremented(), "threshold candidate does not stop progression")


func _test_missing_attack_skill_definition_ordering() -> void:
	var dodge_attacker: CharacterStateScript = _character(0, 20, 20)
	var dodge_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new(
		[0, 0, 16, 1]
	)
	var dodge: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 2, 0, false, 10, 0, &"missing-weapon-skill"),
		dodge_attacker,
		_character(1),
		false,
		true,
		dodge_rng,
		null,
		null,
		false,
	)
	_assert_eq(dodge.outcome, CombatOrdinaryAttackResultScript.Outcome.PROGRESSION_FAILED, "missing DODGE attack skill definition fails at improve position")
	_assert_eq(dodge.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.DODGE_ATTACKER_SKILL_DEFINITION, "missing DODGE definition has exact stage")
	_assert_eq(dodge_rng.requested_bounds(), [2, 11, 20, 20], "missing DODGE definition is checked after both NPC rolls")
	_assert_eq(dodge_attacker.progression.combat_experience, 1, "missing DODGE definition preserves preceding exp mutation")
	_assert_eq(dodge_attacker.skills.learned_progress(&"missing-weapon-skill"), 0, "missing DODGE definition performs no skill mutation")
	_assert_true(dodge.progression_result.attacker_skill_definition_checked, "DODGE definition lookup evidence is explicit")
	_assert_false(dodge.progression_result.attacker_skill_improvement_attempted, "missing DODGE definition never calls improve_skill")

	var hit_attacker: CharacterStateScript = _character(0, 20, 20, 50, 100)
	var hit_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new(
		[0, 10, 1, 0, 0, 0, 31]
	)
	var hit: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 0, 0, false, 10, 0, &"missing-weapon-skill"),
		hit_attacker,
		_character(1),
		false,
		true,
		hit_rng,
		null,
		null,
		false,
	)
	_assert_eq(hit.progression_result.failure_stage, CombatProgressionResultScript.FailureStage.HIT_ATTACKER_SKILL_DEFINITION, "missing HIT definition has exact stage")
	_assert_eq(hit_rng.requested_bounds(), [2, 11, 2, 10, 1, 5, 70], "missing HIT definition is checked after armed wound roll and attacker roll, before defender roll")
	_assert_eq(hit_attacker.progression.combat_experience, 1, "missing HIT definition preserves preceding exp")
	_assert_eq(hit_attacker.progression.potential, 1, "missing HIT definition preserves preceding potential")
	_assert_eq(hit_attacker.skills.learned_progress(&"missing-weapon-skill"), 0, "missing HIT definition performs no skill mutation")
	_assert_false(hit.progression_result.defender_roll_performed, "missing HIT definition stops before defender progression")


func _test_status_report_boundary_ordering() -> void:
	var wounded_defender: CharacterStateScript = _character(1)
	var wounded: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 1, 3, 0, 0, false, 10, 0, &"known-weapon-skill"),
		_character(),
		wounded_defender,
		true,
		true,
		ScriptedCombatRandomSourceScript.new([0, 10, 1, 0, 0, 1]),
	)
	_assert_true(wounded.base_result.resource_mutation.wound_transition_completed, "armed fixture applies wound before status report")
	_assert_eq(wounded.status_report_result.value_source, CombatStatusReportBoundaryResultScript.ValueSource.EFFECTIVE_VITALITY, "wounding HIT reports effective kee")
	_assert_eq(wounded.status_report_result.numerator, 95, "effective kee report uses post-wound authority")
	_assert_eq(wounded.status_report_result.ratio, 95, "effective kee report ratio is exact")

	var busy_state: ActionBusyStateScript = ActionBusyStateScript.new()
	busy_state.start_busy(2, 3)
	var defender: CharacterStateScript = _character(1, 20, 20, 100, 100, 0, 0)
	var result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true),
		_character(),
		defender,
		true,
		true,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		),
		busy_state,
	)
	_assert_eq(result.outcome, CombatOrdinaryAttackResultScript.Outcome.STATUS_REPORT_BOUNDARY_FAILED, "zero max kee fails at report_status position")
	_assert_eq(result.failure_stage, CombatOrdinaryAttackResultScript.FailureStage.REPORT_STATUS, "report_status failure stage is explicit")
	_assert_eq(result.status_report_result.outcome, CombatStatusReportBoundaryResultScript.Outcome.ZERO_MAXIMUM_DIVISOR, "zero report divisor is retained")
	_assert_eq(result.status_report_result.maximum, 0, "report boundary retains exact zero maximum")
	_assert_eq(defender.vitality.current, -1, "report boundary preserves preceding saturated damage")
	_assert_eq(result.progression_result.outcome, CombatProgressionResultScript.Outcome.COMPLETED, "both-user progression completes before report boundary")
	_assert_eq(result.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.NOT_REACHED, "report boundary failure prevents busy interruption")
	_assert_eq(busy_state.busy_value, 2, "report boundary failure leaves busy unchanged")


func _test_busy_ordering_and_modes() -> void:
	var not_busy: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 0])
	)
	_assert_eq(not_busy.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.DEFENDER_NOT_BUSY, "positive HIT explicitly observes not-busy mode")

	var clear_busy: ActionBusyStateScript = ActionBusyStateScript.new()
	clear_busy.start_busy(2, 3)
	var clear_defender: CharacterStateScript = _character(1)
	var clear: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true),
		_character(),
		clear_defender,
		true,
		false,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		),
		clear_busy,
	)
	_assert_true(clear.progression_result.defender_combat_experience_incremented(), "busy happens after defender progression")
	_assert_eq(clear.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.INTEGER_BUSY_CLEARED, "busy 2 < threshold 3 clears")
	_assert_eq(clear_busy.busy_value, 0, "successful integer interrupt clears busy")
	_assert_eq(clear_busy.interrupt_threshold, 3, "successful clear preserves threshold")

	var equal_busy: ActionBusyStateScript = ActionBusyStateScript.new()
	equal_busy.start_busy(3, 3)
	var equal: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0, 9]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), equal_busy
	)
	_assert_eq(equal.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.INTEGER_BUSY_REMAINED, "busy equality does not clear")
	_assert_eq(equal_busy.busy_value, 3, "strict integer interrupt leaves equal busy")

	var zero_busy: ActionBusyStateScript = ActionBusyStateScript.new()
	zero_busy.start_busy(2, 3)
	var zero_damage: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true, 1, 0), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), zero_busy
	)
	_assert_eq(zero_damage.base_result.calculation.requested_damage, 0, "zero-damage fixture completes HIT")
	_assert_eq(zero_damage.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.NOT_REACHED, "D == 0 skips busy after progression")
	_assert_eq(zero_busy.busy_value, 2, "zero damage leaves busy unchanged")

	var dodge_busy: ActionBusyStateScript = ActionBusyStateScript.new()
	dodge_busy.start_busy(2, 3)
	var dodge: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 10, true), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 0, 51]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), dodge_busy
	)
	_assert_eq(dodge.base_result.outcome, CombatAttackResultScript.Outcome.DODGE, "busy dodge fixture dodges")
	_assert_eq(dodge.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.NOT_REACHED, "dodge never reaches late busy")
	_assert_eq(dodge_busy.busy_value, 2, "dodge leaves busy unchanged")

	var parry_busy: ActionBusyStateScript = ActionBusyStateScript.new()
	parry_busy.start_busy(2, 3)
	var parry: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 1, 0, 51]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), parry_busy
	)
	_assert_eq(parry.base_result.outcome, CombatAttackResultScript.Outcome.PARRY, "busy parry fixture parries")
	_assert_eq(parry.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.NOT_REACHED, "parry never reaches late busy")
	_assert_eq(parry_busy.busy_value, 2, "parry leaves busy unchanged")

	var integer_function_defender: CharacterStateScript = _character(1)
	var integer_function_result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true), _character(), integer_function_defender, true, false,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.FUNCTION,
		), null
	)
	_assert_eq(integer_function_result.outcome, CombatOrdinaryAttackResultScript.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE, "integer busy plus function interrupt fails only at late interrupt stage")
	_assert_eq(integer_function_defender.progression.combat_experience, 2, "function interrupt failure preserves prior progression")
	_assert_true(integer_function_result.partial_mutation_preserved, "function interrupt result exposes preserved mutations")

	var function_function: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.FUNCTION,
			CombatBusyInterruptProjectionScript.InterruptKind.FUNCTION,
		), null
	)
	_assert_eq(function_function.outcome, CombatOrdinaryAttackResultScript.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE, "function busy plus function interrupt is typed unavailable")

	var function_integer: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 2, true), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 1, 1, 0, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.FUNCTION,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), null
	)
	_assert_eq(function_integer.outcome, CombatOrdinaryAttackResultScript.Outcome.COMPLETED, "function busy plus integer interrupt is an LPC no-op")
	_assert_eq(function_integer.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.FUNCTION_BUSY_INTEGER_INTERRUPT_NO_OP, "function/integer no-op is explicit")

	var stale_interrupt: ActionBusyStateScript = ActionBusyStateScript.new()
	stale_interrupt.start_busy(2, 3)
	stale_interrupt.try_interrupt()
	var stale: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), _character(1), true, false,
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 0]),
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.NOT_BUSY,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), stale_interrupt
	)
	_assert_eq(stale.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.DEFENDER_NOT_BUSY, "not-busy short-circuits despite stale integer interrupt")
	_assert_eq(stale_interrupt.interrupt_threshold, 3, "not-busy short-circuit preserves stale threshold")


func _test_projection_coherence_and_base_failure() -> void:
	var mismatch_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var mismatch: CombatOrdinaryAttackResultScript = _complete(
		_input(5, 1), _character(4), _character(1), true, false, mismatch_rng
	)
	_assert_eq(mismatch.failure_stage, CombatOrdinaryAttackResultScript.FailureStage.ATTACKER_PROGRESSION_PROJECTION, "combat_exp mismatch is typed")
	_assert_eq(mismatch_rng.call_count(), 0, "combat_exp mismatch fails before resolver RNG")

	var busy_state: ActionBusyStateScript = ActionBusyStateScript.new()
	busy_state.start_busy(2, 3)
	var busy_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var busy_mismatch: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), _character(1), true, false, busy_rng,
		_busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.INTEGER,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		), busy_state
	)
	_assert_eq(busy_mismatch.failure_stage, CombatOrdinaryAttackResultScript.FailureStage.BUSY_PROJECTION, "busy projection mismatch is typed")
	_assert_eq(busy_rng.call_count(), 0, "busy mismatch fails before resolver RNG")

	var base_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 3])
	var base_failure: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1, 3, 2, 2, 0), _character(), _character(1), true, false, base_rng
	)
	_assert_eq(base_failure.outcome, CombatOrdinaryAttackResultScript.Outcome.BASE_ATTACK_INCOMPLETE, "base failure stops composition")
	_assert_eq(base_failure.progression_result.outcome, CombatProgressionResultScript.Outcome.NOT_REACHED, "base failure runs no progression")
	_assert_eq(base_failure.busy_result.outcome, CombatBusyInterruptResultScript.Outcome.NOT_REACHED, "base failure runs no busy")


func _test_result_snapshots_and_independent_characters() -> void:
	var first: CharacterStateScript = _character(1, 20, 20, 50, 100)
	var second: CharacterStateScript = _character(1, 20, 20, 50, 100)
	var result: CombatOrdinaryAttackResultScript = _complete(
		_input(0, 1), _character(), first, true, false,
		ScriptedCombatRandomSourceScript.new([0, 0, 51])
	)
	_assert_eq(first.skills.learned_progress(&"dodge"), 1, "first defender receives dodge progress")
	_assert_eq(second.skills.learned_progress(&"dodge"), 0, "independent defender shares no skill state")
	var bounds: Array[int] = result.combined_random_upper_bounds()
	bounds.clear()
	_assert_eq(result.combined_random_upper_bounds(), [2, 12, 70], "combined RNG evidence getter is defensive")
	var returned: CombatProgressionResultScript = result.progression_result
	returned._defender_combat_experience_after = 999
	_assert_eq(result.progression_result.defender_combat_experience_after, 2, "progression result getter is defensive")


func _complete(
	input: CombatAttackInput,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_is_user: bool,
	defender_is_user: bool,
	rng: ScriptedCombatRandomSource,
	busy_projection: CombatBusyInterruptProjection = null,
	busy_state: ActionBusyState = null,
	attack_skill_definition_available: bool = true,
) -> CombatOrdinaryAttackResult:
	var resolved_busy_projection: CombatBusyInterruptProjection = busy_projection
	if resolved_busy_projection == null:
		resolved_busy_projection = _busy_projection(
			CombatBusyInterruptProjectionScript.BusyKind.NOT_BUSY,
			CombatBusyInterruptProjectionScript.InterruptKind.INTEGER,
		)
	return CombatAttackCompletionServiceScript.resolve(
		input,
		attacker,
		defender,
		CombatProgressionFactsScript.new(
			input.attacker.character_id,
			attacker_is_user,
			attacker.attributes.intelligence,
			attacker.attributes.spirituality,
			input.attacker.projected_attack_skill_type,
			attack_skill_definition_available,
		),
		CombatProgressionFactsScript.new(
			input.defender.character_id,
			defender_is_user,
			defender.attributes.intelligence,
			defender.attributes.spirituality,
			&"unarmed",
			true,
		),
		resolved_busy_projection,
		busy_state,
		rng,
	)


func _input(
	attacker_exp: int = 0,
	defender_exp: int = 1,
	attack_level: int = 3,
	dodge_level: int = 2,
	parry_level: int = 2,
	unarmed_level: int = 2,
	busy: bool = false,
	apply_damage: int = 10,
	base_strength: int = 6,
	attack_skill_type: StringName = &"unarmed",
) -> CombatAttackInput:
	var weapon_profile: WeaponCombatProfile = null
	if attack_skill_type != &"unarmed":
		weapon_profile = WeaponCombatProfileScript.new(
			&"test-weapon",
			attack_skill_type,
			CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
		)
	return CombatAttackInputScript.new(
		CombatAttackerSnapshotScript.new(
			&"attacker-1",
			true,
			attacker_exp,
			0,
			0,
			attack_skill_type,
			attack_level,
			0,
			apply_damage,
			CombatStrengthProjectionScript.new(base_strength, 0, 0),
			false,
			&"",
			CombatHitPolicyStatusScript.Value.NOT_APPLICABLE,
			&"",
			CombatHitPolicyStatusScript.Value.NOT_APPLICABLE,
			CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
			weapon_profile,
			&"force",
			0,
		),
		CombatDefenderSnapshotScript.new(
			&"defender-1",
			true,
			busy,
			defender_exp,
			0,
			0,
			dodge_level,
			parry_level,
			unarmed_level,
			0,
			0,
			false,
			[&"头", &"右臂"],
		),
		CombatActionDefinitionScript.new(&"ordinary-action", 0, 0, &"伤害"),
	)


func _busy_projection(busy_kind: int, interrupt_kind: int) -> CombatBusyInterruptProjection:
	return CombatBusyInterruptProjectionScript.new(busy_kind, interrupt_kind)


func _character(
	combat_experience: int = 0,
	base_intelligence: int = 20,
	base_spirituality: int = 20,
	gin_current: int = 100,
	gin_maximum: int = 100,
	kee_current: int = 100,
	kee_maximum: int = 100,
) -> CharacterState:
	var character: CharacterState = CharacterStateScript.new()
	character.attributes.intelligence = base_intelligence
	character.attributes.spirituality = base_spirituality
	character.essence = CharacterResourceStateScript.new(
		gin_current,
		gin_maximum,
		gin_maximum,
	)
	character.vitality = CharacterResourceStateScript.new(
		kee_current,
		kee_maximum,
		kee_maximum,
	)
	character.spirit = CharacterResourceStateScript.new(100, 100, 100)
	character.progression.combat_experience = combat_experience
	return character


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
