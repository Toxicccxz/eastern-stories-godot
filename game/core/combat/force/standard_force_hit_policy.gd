class_name StandardForceHitPolicy
extends RefCounted

const FORCE_SKILL_ID: StringName = &"force"


static func resolve(
	input: StandardForceHitInput,
	attacker_force: CharacterInternalResourceState,
	attacker_essence: CharacterResourceState,
	attacker_vitality: CharacterResourceState,
	attacker_spirit: CharacterResourceState,
	random_source: CombatRandomSource,
) -> StandardForceHitResult:
	var result: StandardForceHitResult = StandardForceHitResult.new()
	if input != null:
		result._provider_id = input.provider_id
		result._entering_damage_bonus = input.damage_bonus
		result._factor = input.factor
	if (
		input == null
		or not input.is_valid()
		or input.attacker_force_skill_type != FORCE_SKILL_ID
		or input.defender_force_skill_type != FORCE_SKILL_ID
		or attacker_force == null
		or attacker_essence == null
		or attacker_vitality == null
		or attacker_spirit == null
		or random_source == null
	):
		return result

	result._force_before = attacker_force.current
	attacker_force.current -= input.factor
	result._force_after_deduction = attacker_force.current
	result._reached_stage = StandardForceHitResult.ReachedStage.FORCE_DEDUCTED

	@warning_ignore("integer_division")
	result._force_damage_before_armor = (
		attacker_force.current / 20
		+ input.factor
		- input.defender_current_force / 25
	)
	result._reached_stage = StandardForceHitResult.ReachedStage.FORCE_DAMAGE_CALCULATED

	if result._force_damage_before_armor < 0:
		if not input.attacker_has_primary_weapon:
			var reflection_result: StandardForceHitResult = _resolve_reflection_check(
				input,
				attacker_essence,
				attacker_vitality,
				attacker_spirit,
				random_source,
				result,
			)
			if reflection_result.outcome != StandardForceHitResult.Outcome.NUMERIC_BONUS:
				return reflection_result
		return _numeric_result(input.damage_bonus, result._force_damage_before_armor, result)

	result._force_damage_after_armor = (
		result._force_damage_before_armor - input.defender_armor_vs_force
	)
	result._armor_subtraction_reached = true
	result._reached_stage = StandardForceHitResult.ReachedStage.ARMOR_APPLIED
	if input.damage_bonus + result._force_damage_after_armor < 0:
		return _complete_numeric(-input.damage_bonus, result)

	var bound: int = input.attacker_effective_force_skill_level
	if bound <= 0:
		return _invalid_bound(
			bound,
			StandardForceHitResult.FailureStage.NORMAL_RANDOM_BOUND,
			result,
		)
	var draw: int = _draw(bound, random_source, result)
	if not _is_valid_draw(draw, bound):
		result._failure_stage = StandardForceHitResult.FailureStage.NORMAL_RANDOM_DRAW
		return result
	result._reached_stage = StandardForceHitResult.ReachedStage.NORMAL_RANDOM_CHECKED
	if draw < result._force_damage_after_armor:
		return _complete_numeric(result._force_damage_after_armor, result)
	result._outcome = StandardForceHitResult.Outcome.NO_NUMERIC_EFFECT
	result._failure_stage = StandardForceHitResult.FailureStage.NONE
	result._reached_stage = StandardForceHitResult.ReachedStage.COMPLETED
	return result


static func _resolve_reflection_check(
	input: StandardForceHitInput,
	attacker_essence: CharacterResourceState,
	attacker_vitality: CharacterResourceState,
	attacker_spirit: CharacterResourceState,
	random_source: CombatRandomSource,
	result: StandardForceHitResult,
) -> StandardForceHitResult:
	var bound: int = input.defender_effective_force_skill_level
	if bound <= 0:
		return _invalid_bound(
			bound,
			StandardForceHitResult.FailureStage.REFLECTION_RANDOM_BOUND,
			result,
		)
	var draw: int = _draw(bound, random_source, result)
	if not _is_valid_draw(draw, bound):
		result._failure_stage = StandardForceHitResult.FailureStage.REFLECTION_RANDOM_DRAW
		return result
	result._reached_stage = StandardForceHitResult.ReachedStage.REFLECTION_CHECKED
	@warning_ignore("integer_division")
	if draw <= input.attacker_effective_force_skill_level / 2:
		## Internal marker: the caller continues through the common negative numeric branch.
		result._outcome = StandardForceHitResult.Outcome.NUMERIC_BONUS
		return result

	var reflection_damage: int = -result._force_damage_before_armor
	var current_before: int = attacker_vitality.current
	var effective_before: int = attacker_vitality.effective
	attacker_vitality.apply_damage(reflection_damage * 2)
	var current_after_damage: int = attacker_vitality.current
	var effective_after_damage: int = attacker_vitality.effective
	attacker_vitality.apply_wound(reflection_damage)
	result._reflection_mutation = StandardForceReflectionMutationResult.new(
		true,
		true,
		reflection_damage * 2,
		reflection_damage,
		current_before,
		effective_before,
		current_after_damage,
		effective_after_damage,
		attacker_vitality.current,
		attacker_vitality.effective,
	)
	result._outcome = StandardForceHitResult.Outcome.REFLECTION
	result._failure_stage = StandardForceHitResult.FailureStage.NONE
	result._reached_stage = StandardForceHitResult.ReachedStage.REFLECTION_APPLIED
	result._attacker_threshold_candidate = _threshold_candidate(
		attacker_essence,
		attacker_vitality,
		attacker_spirit,
	)
	return result


static func _numeric_result(
	damage_bonus: int,
	force_damage: int,
	result: StandardForceHitResult,
) -> StandardForceHitResult:
	if damage_bonus + force_damage < 0:
		return _complete_numeric(-damage_bonus, result)
	return _complete_numeric(force_damage, result)


static func _complete_numeric(
	contribution: int,
	result: StandardForceHitResult,
) -> StandardForceHitResult:
	result._outcome = StandardForceHitResult.Outcome.NUMERIC_BONUS
	result._failure_stage = StandardForceHitResult.FailureStage.NONE
	result._numeric_contribution = contribution
	result._reached_stage = StandardForceHitResult.ReachedStage.COMPLETED
	return result


static func _invalid_bound(
	bound: int,
	stage: int,
	result: StandardForceHitResult,
) -> StandardForceHitResult:
	result._failure_stage = stage
	result._failed_random_bound = bound
	result._has_failed_random_bound = true
	return result


static func _draw(
	bound: int,
	random_source: CombatRandomSource,
	result: StandardForceHitResult,
) -> int:
	result._random_upper_bounds.append(bound)
	var draw: int = random_source.next_below(bound)
	result._random_draws.append(draw)
	return draw


static func _is_valid_draw(draw: int, bound: int) -> bool:
	return draw >= 0 and draw < bound


static func _threshold_candidate(
	essence: CharacterResourceState,
	vitality: CharacterResourceState,
	spirit: CharacterResourceState,
) -> int:
	if (
		essence.is_death_threshold_reached()
		or vitality.is_death_threshold_reached()
		or spirit.is_death_threshold_reached()
	):
		return CombatAttackResult.ThresholdCandidate.DEATH
	if (
		essence.is_unconscious_threshold_reached()
		or vitality.is_unconscious_threshold_reached()
		or spirit.is_unconscious_threshold_reached()
	):
		return CombatAttackResult.ThresholdCandidate.UNCONSCIOUS
	return CombatAttackResult.ThresholdCandidate.NONE
