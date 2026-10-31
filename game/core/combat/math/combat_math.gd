class_name CombatMath
extends RefCounted


## adm/daemons/combatd.c::skill_power() in its exact integer evaluation order, or, with
## `rules` on the MODERN curve (CombatPowerRules), Elo's shape over the same inputs;
## `defense` applies the rules' defense_power_percent (the victim's dodge and parry).
## Without rules, or with every knob at ES2's, this is the ported function bit for bit.
static func skill_power(input: CombatSkillPowerInput, rules: CombatPowerRules = null, defense: bool = false) -> int:
	if input == null or not input.living:
		return 0
	if rules != null and rules.curve == CombatPowerRules.PowerCurve.MODERN:
		return _modern_power(input, rules, defense)
	var level: int = input.effective_skill_level + input.usage_bonus
	var power: int
	if level == 0:
		@warning_ignore("integer_division")
		power = input.combat_experience / 2
	else:
		var cube_divided_by_three: int
		@warning_ignore("integer_division")
		cube_divided_by_three = level * level * level / 3
		if input.maximum_spirit > 0:
			@warning_ignore("integer_division")
			var scaled_level_power: int = cube_divided_by_three / input.maximum_spirit
			power = scaled_level_power * input.current_spirit + input.combat_experience
		else:
			power = cube_divided_by_three + input.combat_experience
	return _discounted(power, rules, defense)


## power_base × 2^(level / doubling levels), scaled by sen / max_sen as combatd.c scales the
## cube, plus combat_exp / exp_power_divisor (not scaled, as combatd.c adds it).
static func _modern_power(input: CombatSkillPowerInput, rules: CombatPowerRules, defense: bool) -> int:
	var level: int = input.effective_skill_level + input.usage_bonus
	var power: int = roundi(float(rules.power_base) * pow(2.0, float(level) / float(rules.power_doubling_levels)))
	if input.maximum_spirit > 0:
		@warning_ignore("integer_division")
		power = power * input.current_spirit / input.maximum_spirit
	@warning_ignore("integer_division")
	power += input.combat_experience / rules.exp_power_divisor
	return _discounted(power, rules, defense)


static func _discounted(power: int, rules: CombatPowerRules, defense: bool) -> int:
	if not defense or rules == null or rules.defense_power_percent == 100:
		return power
	@warning_ignore("integer_division")
	return power * rules.defense_power_percent / 100


## Exact feature/attribute.c::query_str() scalar projection.
static func effective_strength(input: CombatStrengthProjection) -> int:
	if input == null:
		return 0
	return input.base_strength + input.force_factor + input.strength_modifier
