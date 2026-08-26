class_name CombatAttackResolver
extends RefCounted

const UNARMED_SKILL_ID: StringName = &"unarmed"


## Resolves only combatd.c::do_attack()'s hook-free ordinary core through
## damage/wound mutation and threshold observation. Scheduling, progression,
## busy mutation, relationships, post_action, and riposte are intentionally
## outside this operation.
static func resolve(
	input: CombatAttackInput,
	defender_essence: CharacterResourceState,
	defender_vitality: CharacterResourceState,
	defender_spirit: CharacterResourceState,
	random_source: CombatRandomSource,
) -> CombatAttackResult:
	if (
		input == null
		or not input.is_valid()
		or defender_essence == null
		or defender_vitality == null
		or defender_spirit == null
	):
		return CombatAttackResult.new(
			CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
			CombatAttackResult.FailureStage.INVALID_ATTACK_INPUT,
		)

	var attacker: CombatAttackerSnapshot = input.attacker
	var defender: CombatDefenderSnapshot = input.defender
	var action: CombatActionDefinition = input.selected_action
	var calculation: CombatAttackCalculation = CombatAttackCalculation.new()
	var vitality_current_before: int = defender_vitality.current
	var vitality_effective_before: int = defender_vitality.effective
	var mutation: CombatResourceMutationResult = _mutation_snapshot(
		false,
		false,
		0,
		0,
		vitality_current_before,
		vitality_effective_before,
		defender_vitality,
	)
	var weapon: WeaponCombatProfile = attacker.weapon_profile
	var selected_attack_skill_type: StringName = (
		weapon.skill_type if weapon != null else UNARMED_SKILL_ID
	)
	if selected_attack_skill_type != attacker.projected_attack_skill_type:
		return _finish(
			CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
			CombatAttackResult.FailureStage.ATTACK_SKILL_PROJECTION_MISMATCH,
			CombatAttackResult.AuthoredPolicyKind.NONE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)

	var limbs: Array[StringName] = defender.limbs()
	if limbs.is_empty():
		return _finish(
			CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
			CombatAttackResult.FailureStage.INVALID_LIMB_SET,
			CombatAttackResult.AuthoredPolicyKind.NONE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	if random_source == null:
		return _finish(
			CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
			CombatAttackResult.FailureStage.RANDOM_SOURCE_MISSING,
			CombatAttackResult.AuthoredPolicyKind.NONE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)

	var limb_roll: int = _draw(random_source, limbs.size(), calculation)
	if not _is_valid_draw(limb_roll, limbs.size()):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.LIMB_RANDOM_DRAW,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	calculation._selected_limb = limbs[limb_roll]
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.LIMB_SELECTED

	calculation._attack_skill_type = selected_attack_skill_type
	var attack_power_input: CombatSkillPowerInput = CombatSkillPowerInput.new(
		attacker.living,
		attacker.effective_attack_skill_level,
		attacker.attack_usage_bonus,
		attacker.combat_experience,
		attacker.maximum_spirit,
		attacker.current_spirit,
	)
	calculation._attack_power = CombatMath.skill_power(attack_power_input)
	if calculation._attack_power < 1:
		calculation._attack_power = 1

	var dodge_power_input: CombatSkillPowerInput = CombatSkillPowerInput.new(
		defender.living,
		defender.effective_dodge_skill_level,
		defender.defense_usage_bonus,
		defender.combat_experience,
		defender.maximum_spirit,
		defender.current_spirit,
	)
	calculation._dodge_power = CombatMath.skill_power(dodge_power_input)
	if calculation._dodge_power < 1:
		calculation._dodge_power = 1
	if defender.busy:
		@warning_ignore("integer_division")
		calculation._dodge_power /= 3
	calculation._reached_stage = (
		CombatAttackCalculation.ReachedStage.ATTACK_AND_DODGE_POWER_READY
	)

	var dodge_bound: int = calculation._attack_power + calculation._dodge_power
	var dodge_roll: int = _draw(random_source, dodge_bound, calculation)
	if not _is_valid_draw(dodge_roll, dodge_bound):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.DODGE_RANDOM_DRAW,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.DODGE_EVALUATED
	if dodge_roll < calculation._dodge_power:
		return _finish(
			CombatAttackResult.Outcome.DODGE,
			CombatAttackResult.FailureStage.NONE,
			CombatAttackResult.AuthoredPolicyKind.NONE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)

	var parry_effective_level: int
	if defender.has_primary_weapon:
		parry_effective_level = defender.effective_parry_skill_level
		calculation._parry_power = _defense_skill_power(defender, parry_effective_level)
		if weapon == null:
			calculation._parry_power *= 2
	elif weapon != null:
		calculation._parry_power = 0
	else:
		parry_effective_level = defender.effective_unarmed_skill_level
		calculation._parry_power = _defense_skill_power(defender, parry_effective_level)
	if defender.busy:
		@warning_ignore("integer_division")
		calculation._parry_power /= 3
	if calculation._parry_power < 1:
		calculation._parry_power = 1
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.PARRY_POWER_READY

	var parry_bound: int = calculation._attack_power + calculation._parry_power
	var parry_roll: int = _draw(random_source, parry_bound, calculation)
	if not _is_valid_draw(parry_roll, parry_bound):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.PARRY_RANDOM_DRAW,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.PARRY_EVALUATED
	if parry_roll < calculation._parry_power:
		return _finish(
			CombatAttackResult.Outcome.PARRY,
			CombatAttackResult.FailureStage.NONE,
			CombatAttackResult.AuthoredPolicyKind.NONE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)

	calculation._base_apply_damage = attacker.projected_apply_damage
	calculation._damage_value = calculation._base_apply_damage
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.APPLY_DAMAGE_PROJECTED
	if calculation._damage_value <= 0:
		return _finish(
			CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
			CombatAttackResult.FailureStage.APPLY_DAMAGE_RANDOM_BOUND,
			CombatAttackResult.AuthoredPolicyKind.NONE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	var damage_roll: int = _draw(random_source, calculation._damage_value, calculation)
	if not _is_valid_draw(damage_roll, calculation._damage_value):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.APPLY_DAMAGE_RANDOM_DRAW,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	@warning_ignore("integer_division")
	calculation._damage_value = (calculation._damage_value + damage_roll) / 2
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.BASE_DAMAGE_READY
	if action.damage_percent != 0:
		@warning_ignore("integer_division")
		calculation._damage_value += (
			action.damage_percent * calculation._damage_value / 100
		)
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.ACTION_DAMAGE_READY

	var strength_projection: CombatStrengthProjection = attacker.strength_projection
	calculation._initial_strength_bonus = CombatMath.effective_strength(strength_projection)
	calculation._final_strength_bonus = calculation._initial_strength_bonus
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.INITIAL_STRENGTH_READY

	if (
		strength_projection.force_factor != 0
		and attacker.current_inner_force > strength_projection.force_factor
		and not attacker.mapped_force_skill_id.is_empty()
	):
		var force_policy_result: CombatAttackResult = _policy_gate_result(
			attacker.force_hit_policy_status,
			CombatAttackResult.FailureStage.FORCE_HIT_POLICY,
			CombatAttackResult.AuthoredPolicyKind.FORCE,
			attacker.mapped_force_skill_id,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
		if force_policy_result != null:
			return force_policy_result
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.FORCE_HOOK_PASSED

	## combatd.c applies action force after the force hook but before martial.
	if action.force_percent != 0:
		@warning_ignore("integer_division")
		calculation._final_strength_bonus += (
			action.force_percent * calculation._final_strength_bonus / 100
		)
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.ACTION_FORCE_READY

	if not attacker.mapped_attack_skill_id.is_empty():
		var martial_policy_result: CombatAttackResult = _policy_gate_result(
			attacker.martial_hit_policy_status,
			CombatAttackResult.FailureStage.MARTIAL_HIT_POLICY,
			CombatAttackResult.AuthoredPolicyKind.MARTIAL,
			attacker.mapped_attack_skill_id,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
		if martial_policy_result != null:
			return martial_policy_result
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.MARTIAL_HOOK_PASSED

	var terminal_policy_result: CombatAttackResult
	if weapon != null:
		terminal_policy_result = _policy_gate_result(
			weapon.hit_policy_status,
			CombatAttackResult.FailureStage.WEAPON_HIT_POLICY,
			CombatAttackResult.AuthoredPolicyKind.WEAPON,
			weapon.weapon_id,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	else:
		terminal_policy_result = _policy_gate_result(
			attacker.attacker_hit_policy_status,
			CombatAttackResult.FailureStage.ATTACKER_HIT_POLICY,
			CombatAttackResult.AuthoredPolicyKind.ATTACKER,
			attacker.character_id,
			attacker,
			defender,
			action,
			calculation,
			mutation,
		)
	if terminal_policy_result != null:
		return terminal_policy_result
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.TERMINAL_HOOK_PASSED

	if calculation._final_strength_bonus > 0:
		var strength_roll: int = _draw(
			random_source,
			calculation._final_strength_bonus,
			calculation,
		)
		if not _is_valid_draw(strength_roll, calculation._final_strength_bonus):
			return _invalid_draw_result(
				CombatAttackResult.FailureStage.STRENGTH_RANDOM_DRAW,
				attacker,
				defender,
				action,
				calculation,
				mutation,
			)
		@warning_ignore("integer_division")
		calculation._damage_value += (
			(calculation._final_strength_bonus + strength_roll) / 2
		)
	if calculation._damage_value < 0:
		calculation._damage_value = 0
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.STRENGTH_DAMAGE_READY

	var defense_factor: int = defender.combat_experience
	while true:
		calculation._defense_factor_at_exit = defense_factor
		if defense_factor <= 0:
			return _finish(
				CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
				CombatAttackResult.FailureStage.DEFENSE_FACTOR_RANDOM_BOUND,
				CombatAttackResult.AuthoredPolicyKind.NONE,
				CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
				false,
				attacker,
				defender,
				action,
				calculation,
				mutation,
			)
		var defense_roll: int = _draw(random_source, defense_factor, calculation)
		if not _is_valid_draw(defense_roll, defense_factor):
			return _invalid_draw_result(
				CombatAttackResult.FailureStage.DEFENSE_FACTOR_RANDOM_DRAW,
				attacker,
				defender,
				action,
				calculation,
				mutation,
			)
		if defense_roll <= attacker.combat_experience:
			break
		@warning_ignore("integer_division")
		calculation._damage_value -= calculation._damage_value / 3
		@warning_ignore("integer_division")
		defense_factor /= 2
		calculation._defense_iterations += 1
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.DEFENSE_LOOP_COMPLETED

	calculation._requested_damage = calculation._damage_value
	defender_vitality.apply_damage(calculation._requested_damage)
	mutation = _mutation_snapshot(
		true,
		false,
		calculation._requested_damage,
		0,
		vitality_current_before,
		vitality_effective_before,
		defender_vitality,
	)
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.DAMAGE_APPLIED

	calculation._armor = defender.armor
	calculation._wound_eligible = attacker.lethal_intent or weapon != null
	calculation._reached_stage = (
		CombatAttackCalculation.ReachedStage.WOUND_ELIGIBILITY_EVALUATED
	)
	if calculation._wound_eligible:
		if calculation._requested_damage <= 0:
			return _finish(
				CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
				CombatAttackResult.FailureStage.WOUND_RANDOM_BOUND,
				CombatAttackResult.AuthoredPolicyKind.NONE,
				CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
				false,
				attacker,
				defender,
				action,
				calculation,
				mutation,
			)
		var wound_roll: int = _draw(
			random_source,
			calculation._requested_damage,
			calculation,
		)
		if not _is_valid_draw(wound_roll, calculation._requested_damage):
			return _finish(
				CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
				CombatAttackResult.FailureStage.WOUND_RANDOM_DRAW,
				CombatAttackResult.AuthoredPolicyKind.NONE,
				CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
				false,
				attacker,
				defender,
				action,
				calculation,
				mutation,
			)
		calculation._wound_roll_performed = true
		if wound_roll > calculation._armor:
			calculation._wound_amount = calculation._requested_damage - calculation._armor
			defender_vitality.apply_wound(calculation._wound_amount)
			mutation = _mutation_snapshot(
				true,
				true,
				calculation._requested_damage,
				calculation._wound_amount,
				vitality_current_before,
				vitality_effective_before,
				defender_vitality,
			)
		calculation._reached_stage = CombatAttackCalculation.ReachedStage.WOUND_EVALUATED

	return _finish(
		CombatAttackResult.Outcome.HIT,
		CombatAttackResult.FailureStage.NONE,
		CombatAttackResult.AuthoredPolicyKind.NONE,
		_observe_threshold(defender_essence, defender_vitality, defender_spirit, calculation),
		calculation._requested_damage > 0,
		attacker,
		defender,
		action,
		calculation,
		mutation,
	)


static func _defense_skill_power(
	defender: CombatDefenderSnapshot,
	effective_level: int,
) -> int:
	return CombatMath.skill_power(
		CombatSkillPowerInput.new(
			defender.living,
			effective_level,
			defender.defense_usage_bonus,
			defender.combat_experience,
			defender.maximum_spirit,
			defender.current_spirit,
		)
	)


static func _draw(
	random_source: CombatRandomSource,
	exclusive_upper_bound: int,
	calculation: CombatAttackCalculation,
) -> int:
	calculation._random_upper_bounds.append(exclusive_upper_bound)
	var draw: int = random_source.next_below(exclusive_upper_bound)
	calculation._random_draws.append(draw)
	return draw


static func _is_valid_draw(draw: int, exclusive_upper_bound: int) -> bool:
	return draw >= 0 and draw < exclusive_upper_bound


static func _observe_threshold(
	essence: CharacterResourceState,
	vitality: CharacterResourceState,
	spirit: CharacterResourceState,
	calculation: CombatAttackCalculation,
) -> int:
	calculation._reached_stage = CombatAttackCalculation.ReachedStage.THRESHOLD_OBSERVED
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


static func _mutation_snapshot(
	damage_completed: bool,
	wound_completed: bool,
	requested_damage: int,
	requested_wound: int,
	current_before: int,
	effective_before: int,
	vitality: CharacterResourceState,
) -> CombatResourceMutationResult:
	return CombatResourceMutationResult.new(
		damage_completed,
		wound_completed,
		requested_damage,
		requested_wound,
		current_before,
		effective_before,
		vitality.current,
		vitality.effective,
	)


static func _invalid_draw_result(
	stage: int,
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	action: CombatActionDefinition,
	calculation: CombatAttackCalculation,
	mutation: CombatResourceMutationResult,
) -> CombatAttackResult:
	return _finish(
		CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
		stage,
		CombatAttackResult.AuthoredPolicyKind.NONE,
		CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
		false,
		attacker,
		defender,
		action,
		calculation,
		mutation,
	)


static func _policy_gate_result(
	policy_status: int,
	stage: int,
	policy_kind: int,
	policy_id: StringName,
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	action: CombatActionDefinition,
	calculation: CombatAttackCalculation,
	mutation: CombatResourceMutationResult,
) -> CombatAttackResult:
	if policy_status == CombatHitPolicyStatus.Value.PROVEN_NO_AUTHORED_EFFECT:
		return null
	var outcome: int = CombatAttackResult.Outcome.AUTHORED_HIT_POLICY_UNAVAILABLE
	if policy_status == CombatHitPolicyStatus.Value.DRIVER_AMBIGUITY:
		outcome = CombatAttackResult.Outcome.HIT_POLICY_DISPATCH_AMBIGUOUS
	return _finish(
		outcome,
		stage,
		policy_kind,
		CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
		false,
		attacker,
		defender,
		action,
		calculation,
		mutation,
		policy_id,
	)


static func _finish(
	outcome: int,
	failure_stage: int,
	policy_kind: int,
	threshold: int,
	interrupt_requested: bool,
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	action: CombatActionDefinition,
	calculation: CombatAttackCalculation,
	mutation: CombatResourceMutationResult,
	policy_id: StringName = &"",
) -> CombatAttackResult:
	return CombatAttackResult.new(
		outcome,
		failure_stage,
		policy_kind,
		policy_id,
		threshold,
		attacker.character_id,
		defender.character_id,
		action.action_id,
		interrupt_requested,
		calculation,
		mutation,
	)
