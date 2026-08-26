class_name CombatMath
extends RefCounted


## Exact integer evaluation order from adm/daemons/combatd.c::skill_power().
static func skill_power(input: CombatSkillPowerInput) -> int:
	if input == null or not input.living:
		return 0
	var level: int = input.effective_skill_level + input.usage_bonus
	if level == 0:
		@warning_ignore("integer_division")
		return input.combat_experience / 2
	var cube_divided_by_three: int
	@warning_ignore("integer_division")
	cube_divided_by_three = level * level * level / 3
	if input.maximum_spirit > 0:
		@warning_ignore("integer_division")
		var scaled_level_power: int = cube_divided_by_three / input.maximum_spirit
		return scaled_level_power * input.current_spirit + input.combat_experience
	return cube_divided_by_three + input.combat_experience
