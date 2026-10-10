class_name CombatAttackResolver
extends RefCounted

const UNARMED_SKILL_ID: StringName = &"unarmed"
const FORCE_SKILL_ID: StringName = &"force"


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
	attacker_force: CharacterInternalResourceState = null,
	attacker_essence: CharacterResourceState = null,
	attacker_vitality: CharacterResourceState = null,
	attacker_spirit: CharacterResourceState = null,
	defender_conditions: CharacterConditionState = null,
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
	var standard_force_result: StandardForceHitResult
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
	if (
		attacker.force_hit_policy_status == CombatHitPolicyStatus.Value.STANDARD_FORCE
		and (
			attacker.projected_force_skill_type != FORCE_SKILL_ID
			or defender.projected_force_skill_type != FORCE_SKILL_ID
		)
	):
		return _finish(
			CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
			CombatAttackResult.FailureStage.FORCE_SKILL_PROJECTION_MISMATCH,
			CombatAttackResult.AuthoredPolicyKind.FORCE,
			CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
			false,
			attacker,
			defender,
			action,
			calculation,
			mutation,
			attacker.mapped_force_skill_id,
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
		and not attacker.mapped_force_skill_id.is_empty()
	):
		if attacker_force == null:
			return _finish(
				CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
				CombatAttackResult.FailureStage.FORCE_POLICY_INVALID_INPUT,
				CombatAttackResult.AuthoredPolicyKind.FORCE,
				CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
				false,
				attacker,
				defender,
				action,
				calculation,
				mutation,
				attacker.mapped_force_skill_id,
			)
		if attacker_force.current > strength_projection.force_factor:
			if attacker.force_hit_policy_status == CombatHitPolicyStatus.Value.STANDARD_FORCE:
				standard_force_result = StandardForceHitPolicy.resolve(
					StandardForceHitInput.new(
						attacker.mapped_force_skill_id,
						attacker.character_id,
						defender.character_id,
						strength_projection.force_factor,
						calculation._final_strength_bonus,
						weapon != null,
						attacker.projected_force_skill_type,
						attacker.effective_force_skill_level,
						defender.projected_force_skill_type,
						defender.effective_force_skill_level,
						defender.current_inner_force,
						defender.armor_vs_force,
					),
					attacker_force,
					attacker_essence,
					attacker_vitality,
					attacker_spirit,
					random_source,
				)
				_append_force_rng(calculation, standard_force_result)
				if standard_force_result.outcome == StandardForceHitResult.Outcome.INVALID_SOURCE_STATE:
					return _finish(
						CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
						_force_failure_stage(standard_force_result.failure_stage),
						CombatAttackResult.AuthoredPolicyKind.FORCE,
						CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
						false,
						attacker,
						defender,
						action,
						calculation,
						mutation,
						attacker.mapped_force_skill_id,
						standard_force_result,
					)
				var wound_result: CombatAttackResult = _force_hit_wound(
					attacker, defender, action, calculation, mutation, standard_force_result,
					defender_vitality, defender_conditions, random_source,
				)
				if wound_result != null:
					return wound_result
				if standard_force_result.has_numeric_contribution() and calculation._force_wound == 0:
					calculation._final_strength_bonus += standard_force_result.numeric_contribution
			else:
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

	if attacker.martial_hit_policy_status == CombatHitPolicyStatus.Value.MARTIAL_WOUND:
		var martial_result: CombatAttackResult = _martial_hit_wound(
			attacker, defender, action, calculation, mutation, standard_force_result, defender_vitality, random_source,
		)
		if martial_result != null:
			return martial_result
	elif not attacker.mapped_attack_skill_id.is_empty():
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
			standard_force_result,
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
			standard_force_result,
		)
	elif attacker.attacker_hit_policy_status == CombatHitPolicyStatus.Value.CONDITION_ON_HIT:
		# The attacker's own hit_ob() (venomsnake.c): random(damage_bonus) > the
		# victim's apply/armor and its condition below the mark set the condition.
		var hit: NpcHitCondition = attacker.hit_condition
		var bonus: int = calculation._final_strength_bonus
		var roll: int = _draw(random_source, bonus, calculation) if bonus > 0 else 0
		if not _is_valid_draw(roll, bonus):
			return _invalid_draw_result(
				CombatAttackResult.FailureStage.ATTACKER_HIT_POLICY,
				attacker,
				defender,
				action,
				calculation,
				mutation,
				standard_force_result,
			)
		if roll > defender.armor and defender_conditions != null and _condition_below(defender_conditions, hit.condition_id, hit.below):
			defender_conditions.add_or_replace_duration(hit.condition_id, hit.duration)
			calculation._hit_condition_applied = true
			calculation._hit_condition = hit
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
			standard_force_result,
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
				standard_force_result,
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
		# random(0) is 0, so `random(f) > exp` ends the loop for any exp >= 0.
		# A negative attacker exp would loop for ever in the LPC: invalid state.
		if attacker.combat_experience < 0:
			return _finish(
				CombatAttackResult.Outcome.INVALID_SOURCE_STATE,
				CombatAttackResult.FailureStage.DEFENSE_LOOP_NEGATIVE_EXPERIENCE,
				CombatAttackResult.AuthoredPolicyKind.NONE,
				CombatAttackResult.ThresholdCandidate.NOT_OBSERVED,
				false,
				attacker,
				defender,
				action,
				calculation,
				mutation,
				&"",
				standard_force_result,
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
				standard_force_result,
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
				&"",
				standard_force_result,
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
		&"",
		standard_force_result,
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
	var draw: int = random_source.legacy_random(exclusive_upper_bound)
	if exclusive_upper_bound > 0:
		calculation._random_upper_bounds.append(exclusive_upper_bound)
		calculation._random_draws.append(draw)
	return draw


static func _is_valid_draw(draw: int, exclusive_upper_bound: int) -> bool:
	return exclusive_upper_bound <= 0 or (draw >= 0 and draw < exclusive_upper_bound)


## iceforce.c hit_ob() after ::hit_ob(): when std/force.c returned a number (not its
## reflection line) and damage_bonus plus it is above 0, random(query_skill("iceforce"))
## over that sum wounds the victim's kee by it and sets iceshock to factor / 3; the hook
## then returns its line, so the number is not added. Null unless a draw went wrong.
static func _force_hit_wound(
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	action: CombatActionDefinition,
	calculation: CombatAttackCalculation,
	mutation: CombatResourceMutationResult,
	standard_force_result: StandardForceHitResult,
	defender_vitality: CharacterResourceState,
	defender_conditions: CharacterConditionState,
	random_source: CombatRandomSource,
) -> CombatAttackResult:
	var wound: ForceHitWound = attacker.force_hit_wound
	if wound == null or standard_force_result.outcome == StandardForceHitResult.Outcome.REFLECTION:
		return null
	var foo: int = standard_force_result.numeric_contribution if standard_force_result.has_numeric_contribution() else 0
	var total: int = calculation._final_strength_bonus + foo
	if total <= 0:
		return null
	var level: int = attacker.mapped_force_skill_level
	var roll: int = _draw(random_source, level, calculation)
	if not _is_valid_draw(roll, level):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.FORCE_HIT_POLICY, attacker, defender, action, calculation, mutation,
			standard_force_result,
		)
	if roll > total:
		defender_vitality.apply_wound(total)
		if defender_conditions != null:
			@warning_ignore("integer_division")
			defender_conditions.add_or_replace_duration(wound.condition_id, standard_force_result.factor / wound.factor_divisor)
		calculation._force_wound = total
		calculation._force_hit_wound = wound
	return null


## spicyclaw.c hit_ob(me, victim, damage_bonus): below the wound's at_least nothing; else
## random(damage_bonus / 2) over the victim's query_str() wounds its kee by
## (damage_bonus - at_least) / 2 and returns one of the messages (random(3)); the damage_bonus
## itself is unchanged either way (a string is not added to it).
static func _martial_hit_wound(
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	action: CombatActionDefinition,
	calculation: CombatAttackCalculation,
	mutation: CombatResourceMutationResult,
	standard_force_result: StandardForceHitResult,
	defender_vitality: CharacterResourceState,
	random_source: CombatRandomSource,
) -> CombatAttackResult:
	var wound: MartialHitWound = attacker.martial_hit_wound
	var bonus: int = calculation._final_strength_bonus
	if wound == null or bonus < wound.at_least:
		return null
	@warning_ignore("integer_division")
	var bound: int = bonus / 2
	var roll: int = _draw(random_source, bound, calculation) if bound > 0 else 0
	if not _is_valid_draw(roll, bound):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.MARTIAL_HIT_POLICY, attacker, defender, action, calculation, mutation,
			standard_force_result,
		)
	if roll <= defender.strength:
		return null
	@warning_ignore("integer_division")
	var amount: int = (bonus - wound.at_least) / 2
	if amount > 0:
		defender_vitality.apply_wound(amount)
	var count: int = wound.messages.size()
	var pick: int = _draw(random_source, count, calculation)
	if not _is_valid_draw(pick, count):
		return _invalid_draw_result(
			CombatAttackResult.FailureStage.MARTIAL_HIT_POLICY, attacker, defender, action, calculation, mutation,
			standard_force_result,
		)
	calculation._martial_wound = amount
	calculation._martial_hit_wound = wound
	calculation._martial_message = wound.messages[pick]
	return null


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


## query_condition(id) < below; absent is 0. A payload that is not a duration (a
## mapping in ES2) cannot be compared: no.
static func _condition_below(conditions: CharacterConditionState, condition_id: StringName, below: int) -> bool:
	if not conditions.has_condition(condition_id):
		return 0 < below
	var duration: DurationConditionPayload = conditions.get_condition(condition_id) as DurationConditionPayload
	return duration != null and duration.remaining < below


static func _invalid_draw_result(
	stage: int,
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	action: CombatActionDefinition,
	calculation: CombatAttackCalculation,
	mutation: CombatResourceMutationResult,
	standard_force_result: StandardForceHitResult = null,
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
		&"",
		standard_force_result,
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
	standard_force_result: StandardForceHitResult = null,
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
		standard_force_result,
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
	standard_force_result: StandardForceHitResult = null,
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
		standard_force_result,
	)


static func _append_force_rng(
	calculation: CombatAttackCalculation,
	force_result: StandardForceHitResult,
) -> void:
	calculation._random_upper_bounds.append_array(force_result.random_upper_bounds())
	calculation._random_draws.append_array(force_result.random_draws())


static func _force_failure_stage(policy_stage: int) -> int:
	match policy_stage:
		StandardForceHitResult.FailureStage.REFLECTION_RANDOM_DRAW:
			return CombatAttackResult.FailureStage.FORCE_REFLECTION_RANDOM_DRAW
		StandardForceHitResult.FailureStage.NORMAL_RANDOM_DRAW:
			return CombatAttackResult.FailureStage.FORCE_NORMAL_RANDOM_DRAW
		_:
			return CombatAttackResult.FailureStage.FORCE_POLICY_INVALID_INPUT
