class_name CombatProgressionService
extends RefCounted

const DODGE_SKILL_ID: StringName = &"dodge"
const PARRY_SKILL_ID: StringName = &"parry"


static func apply(
	base_result: CombatAttackResult,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatProgressionResult:
	var result: CombatProgressionResult = CombatProgressionResult.new()
	if (
		base_result == null
		or attacker == null
		or defender == null
		or attacker_facts == null
		or defender_facts == null
		or random_source == null
		or effect_registry == null
	):
		result._outcome = CombatProgressionResult.Outcome.INVALID_SOURCE_STATE
		result._failure_stage = CombatProgressionResult.FailureStage.INVALID_INPUT
		return result
	_snapshot_before(result, attacker, defender)
	match base_result.outcome:
		CombatAttackResult.Outcome.DODGE:
			result._branch = CombatProgressionResult.Branch.DODGE
			result._reached_stage = CombatProgressionResult.ReachedStage.BRANCH_SELECTED
			_apply_dodge(
				result,
				base_result,
				attacker,
				defender,
				attacker_facts,
				defender_facts,
				random_source,
				effect_registry,
			)
		CombatAttackResult.Outcome.PARRY:
			result._branch = CombatProgressionResult.Branch.PARRY
			result._reached_stage = CombatProgressionResult.ReachedStage.BRANCH_SELECTED
			_apply_parry(
				result,
				base_result,
				defender,
				attacker_facts,
				defender_facts,
				random_source,
				effect_registry,
			)
		CombatAttackResult.Outcome.HIT:
			result._branch = CombatProgressionResult.Branch.HIT
			result._reached_stage = CombatProgressionResult.ReachedStage.BRANCH_SELECTED
			_apply_hit(
				result,
				base_result,
				attacker,
				defender,
				attacker_facts,
				defender_facts,
				random_source,
				effect_registry,
			)
		_:
			result._outcome = CombatProgressionResult.Outcome.NOT_REACHED
	_snapshot_after(result, attacker, defender)
	return result


static func _apply_dodge(
	result: CombatProgressionResult,
	base_result: CombatAttackResult,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> void:
	var calculation: CombatAttackCalculation = base_result.calculation
	result._defender_condition_evaluated = true
	result._defender_condition_matched = (
		calculation.dodge_power < calculation.attack_power
		and (not defender_facts.is_user or not attacker_facts.is_user)
	)
	result._reached_stage = CombatProgressionResult.ReachedStage.DEFENDER_CONDITION_EVALUATED
	if result._defender_condition_matched:
		var defender_bound: int = _health_intelligence_bound(
			defender.essence,
			defender_facts.base_intelligence,
		)
		if defender.essence.maximum == 0:
			_fail(result, CombatProgressionResult.FailureStage.DODGE_DEFENDER_GIN_DIVISION)
			return
		if defender_bound <= 0:
			_fail_bound(
				result,
				CombatProgressionResult.FailureStage.DODGE_DEFENDER_RANDOM_BOUND,
				defender_bound,
			)
			return
		var defender_draw: int = _draw(result, random_source, defender_bound)
		if not _valid_draw(defender_draw, defender_bound):
			_fail(result, CombatProgressionResult.FailureStage.DODGE_DEFENDER_RANDOM_DRAW)
			return
		result._defender_roll_performed = true
		result._defender_roll_succeeded = defender_draw > 50
		result._reached_stage = CombatProgressionResult.ReachedStage.DEFENDER_RANDOM_EVALUATED
		if result._defender_roll_succeeded:
			defender.progression.combat_experience += 1
			_improve_defender(
				result,
				defender,
				defender_facts,
				DODGE_SKILL_ID,
				1,
				effect_registry,
			)
			result._reached_stage = CombatProgressionResult.ReachedStage.DEFENDER_MUTATION_COMPLETED

	result._attacker_condition_evaluated = true
	result._attacker_condition_matched = (
		calculation.attack_power < calculation.dodge_power and not attacker_facts.is_user
	)
	result._reached_stage = CombatProgressionResult.ReachedStage.ATTACKER_CONDITION_EVALUATED
	if result._attacker_condition_matched:
		var attacker_bound: int = attacker_facts.base_intelligence
		if attacker_bound <= 0:
			_fail_bound(
				result,
				CombatProgressionResult.FailureStage.DODGE_ATTACKER_EXP_RANDOM_BOUND,
				attacker_bound,
			)
			return
		var exp_draw: int = _draw(result, random_source, attacker_bound)
		if not _valid_draw(exp_draw, attacker_bound):
			_fail(result, CombatProgressionResult.FailureStage.DODGE_ATTACKER_EXP_RANDOM_DRAW)
			return
		result._attacker_first_roll_performed = true
		result._attacker_first_roll_succeeded = exp_draw > 15
		result._reached_stage = CombatProgressionResult.ReachedStage.ATTACKER_FIRST_RANDOM_EVALUATED
		if result._attacker_first_roll_succeeded:
			attacker.progression.combat_experience += 1

		if attacker_bound <= 0:
			_fail_bound(
				result,
				CombatProgressionResult.FailureStage.DODGE_ATTACKER_SKILL_RANDOM_BOUND,
				attacker_bound,
			)
			return
		var skill_draw: int = _draw(result, random_source, attacker_bound)
		if not _valid_draw(skill_draw, attacker_bound):
			_fail(result, CombatProgressionResult.FailureStage.DODGE_ATTACKER_SKILL_RANDOM_DRAW)
			return
		result._attacker_second_roll_performed = true
		result._reached_stage = CombatProgressionResult.ReachedStage.ATTACKER_SECOND_RANDOM_EVALUATED
		if not _improve_attacker(
			result,
			attacker,
			attacker_facts,
			calculation.attack_skill_type,
			skill_draw,
			effect_registry,
			CombatProgressionResult.FailureStage.DODGE_ATTACKER_SKILL_DEFINITION,
		):
			return
		result._reached_stage = CombatProgressionResult.ReachedStage.ATTACKER_MUTATION_COMPLETED
	_complete(result)


static func _apply_parry(
	result: CombatProgressionResult,
	base_result: CombatAttackResult,
	defender: CharacterState,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> void:
	var calculation: CombatAttackCalculation = base_result.calculation
	result._defender_condition_evaluated = true
	result._defender_condition_matched = (
		calculation.dodge_power < calculation.attack_power
		and (not defender_facts.is_user or not attacker_facts.is_user)
	)
	result._reached_stage = CombatProgressionResult.ReachedStage.DEFENDER_CONDITION_EVALUATED
	if result._defender_condition_matched:
		if defender.essence.maximum == 0:
			_fail(result, CombatProgressionResult.FailureStage.PARRY_DEFENDER_GIN_DIVISION)
			return
		var defender_bound: int = _health_intelligence_bound(
			defender.essence,
			defender_facts.base_intelligence,
		)
		if defender_bound <= 0:
			_fail_bound(
				result,
				CombatProgressionResult.FailureStage.PARRY_DEFENDER_RANDOM_BOUND,
				defender_bound,
			)
			return
		var defender_draw: int = _draw(result, random_source, defender_bound)
		if not _valid_draw(defender_draw, defender_bound):
			_fail(result, CombatProgressionResult.FailureStage.PARRY_DEFENDER_RANDOM_DRAW)
			return
		result._defender_roll_performed = true
		result._defender_roll_succeeded = defender_draw > 50
		result._reached_stage = CombatProgressionResult.ReachedStage.DEFENDER_RANDOM_EVALUATED
		if result._defender_roll_succeeded:
			defender.progression.combat_experience += 1
			_improve_defender(
				result,
				defender,
				defender_facts,
				PARRY_SKILL_ID,
				1,
				effect_registry,
			)
			result._reached_stage = CombatProgressionResult.ReachedStage.DEFENDER_MUTATION_COMPLETED
	_complete(result)


static func _apply_hit(
	result: CombatProgressionResult,
	base_result: CombatAttackResult,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> void:
	var calculation: CombatAttackCalculation = base_result.calculation
	result._outer_condition_evaluated = true
	result._outer_condition_matched = not attacker_facts.is_user or not defender_facts.is_user
	result._reached_stage = CombatProgressionResult.ReachedStage.HIT_OUTER_CONDITION_EVALUATED
	if not result._outer_condition_matched:
		_complete(result)
		return

	result._attacker_condition_evaluated = true
	result._attacker_condition_matched = calculation.attack_power < calculation.dodge_power
	result._reached_stage = CombatProgressionResult.ReachedStage.HIT_ATTACKER_CONDITION_EVALUATED
	if result._attacker_condition_matched:
		if attacker.essence.maximum == 0:
			_fail(result, CombatProgressionResult.FailureStage.HIT_ATTACKER_GIN_DIVISION)
			return
		var attacker_bound: int = _health_intelligence_bound(
			attacker.essence,
			attacker_facts.base_intelligence,
		)
		if attacker_bound <= 0:
			_fail_bound(
				result,
				CombatProgressionResult.FailureStage.HIT_ATTACKER_RANDOM_BOUND,
				attacker_bound,
			)
			return
		var attacker_draw: int = _draw(result, random_source, attacker_bound)
		if not _valid_draw(attacker_draw, attacker_bound):
			_fail(result, CombatProgressionResult.FailureStage.HIT_ATTACKER_RANDOM_DRAW)
			return
		result._attacker_first_roll_performed = true
		result._attacker_first_roll_succeeded = attacker_draw > 30
		result._reached_stage = CombatProgressionResult.ReachedStage.HIT_ATTACKER_RANDOM_EVALUATED
		if result._attacker_first_roll_succeeded:
			attacker.progression.combat_experience += 1
			if attacker.progression.potential - attacker.progression.potential_spent < 100:
				attacker.progression.potential += 1
			if not _improve_attacker(
				result,
				attacker,
				attacker_facts,
				calculation.attack_skill_type,
				1,
				effect_registry,
				CombatProgressionResult.FailureStage.HIT_ATTACKER_SKILL_DEFINITION,
			):
				return
			result._reached_stage = CombatProgressionResult.ReachedStage.HIT_ATTACKER_MUTATION_COMPLETED

	var defender_bound: int = defender.vitality.maximum + defender.vitality.current
	if defender_bound <= 0:
		_fail_bound(
			result,
			CombatProgressionResult.FailureStage.HIT_DEFENDER_RANDOM_BOUND,
			defender_bound,
		)
		return
	var defender_draw: int = _draw(result, random_source, defender_bound)
	if not _valid_draw(defender_draw, defender_bound):
		_fail(result, CombatProgressionResult.FailureStage.HIT_DEFENDER_RANDOM_DRAW)
		return
	result._defender_roll_performed = true
	result._defender_roll_succeeded = defender_draw < calculation.requested_damage
	result._reached_stage = CombatProgressionResult.ReachedStage.HIT_DEFENDER_RANDOM_EVALUATED
	if result._defender_roll_succeeded:
		defender.progression.combat_experience += 1
		if defender.progression.potential - defender.progression.potential_spent < 100:
			defender.progression.potential += 1
		result._reached_stage = CombatProgressionResult.ReachedStage.HIT_DEFENDER_MUTATION_COMPLETED
	_complete(result)


static func _health_intelligence_bound(
	resource: CharacterResourceState,
	base_intelligence: int,
) -> int:
	if resource.maximum == 0:
		return 0
	@warning_ignore("integer_division")
	return resource.current * 100 / resource.maximum + base_intelligence


static func _draw(
	result: CombatProgressionResult,
	random_source: CombatRandomSource,
	bound: int,
) -> int:
	result._random_upper_bounds.append(bound)
	var draw: int = random_source.next_below(bound)
	result._random_draws.append(draw)
	return draw


static func _valid_draw(draw: int, bound: int) -> bool:
	return draw >= 0 and draw < bound


static func _improve_attacker(
	result: CombatProgressionResult,
	character: CharacterState,
	facts: CombatProgressionFacts,
	skill_id: StringName,
	amount: int,
	effect_registry: SkillImprovementEffectRegistry,
	failure_stage: int,
) -> bool:
	result._attacker_skill_definition_checked = true
	result._attacker_skill_definition_available = (
		facts.has_attack_skill_definition(skill_id)
	)
	if not result._attacker_skill_definition_available:
		_fail(result, failure_stage)
		return false
	result._attacker_skill_improvement_attempted = true
	result._attacker_skill_improvement = character.skills.improve_skill(
		skill_id,
		amount,
		facts.base_spirituality,
		false,
		facts.is_user,
	)
	result._attacker_skill_effect = effect_registry.apply(
		character,
		result._attacker_skill_improvement,
	)
	return true


static func _improve_defender(
	result: CombatProgressionResult,
	character: CharacterState,
	facts: CombatProgressionFacts,
	skill_id: StringName,
	amount: int,
	effect_registry: SkillImprovementEffectRegistry,
) -> void:
	result._defender_skill_improvement_attempted = true
	result._defender_skill_improvement = character.skills.improve_skill(
		skill_id,
		amount,
		facts.base_spirituality,
		false,
		facts.is_user,
	)
	result._defender_skill_effect = effect_registry.apply(
		character,
		result._defender_skill_improvement,
	)


static func _snapshot_before(
	result: CombatProgressionResult,
	attacker: CharacterState,
	defender: CharacterState,
) -> void:
	result._attacker_combat_experience_before = attacker.progression.combat_experience
	result._defender_combat_experience_before = defender.progression.combat_experience
	result._attacker_potential_before = attacker.progression.potential
	result._defender_potential_before = defender.progression.potential


static func _snapshot_after(
	result: CombatProgressionResult,
	attacker: CharacterState,
	defender: CharacterState,
) -> void:
	result._attacker_combat_experience_after = attacker.progression.combat_experience
	result._defender_combat_experience_after = defender.progression.combat_experience
	result._attacker_potential_after = attacker.progression.potential
	result._defender_potential_after = defender.progression.potential


static func _fail(result: CombatProgressionResult, stage: int) -> void:
	result._outcome = CombatProgressionResult.Outcome.INVALID_SOURCE_STATE
	result._failure_stage = stage


static func _fail_bound(
	result: CombatProgressionResult,
	stage: int,
	bound: int,
) -> void:
	result._has_failed_random_bound = true
	result._failed_random_bound = bound
	_fail(result, stage)


static func _complete(result: CombatProgressionResult) -> void:
	result._outcome = CombatProgressionResult.Outcome.COMPLETED
	result._failure_stage = CombatProgressionResult.FailureStage.NONE
	result._reached_stage = CombatProgressionResult.ReachedStage.COMPLETED
