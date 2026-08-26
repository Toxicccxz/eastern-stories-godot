class_name CombatSkillPowerInput
extends RefCounted

## Immutable scalar projection consumed by combatd.c::skill_power().
var _living: bool
var _effective_skill_level: int
var _usage_bonus: int
var _combat_experience: int
var _maximum_spirit: int
var _current_spirit: int

var living: bool:
	get:
		return _living
var effective_skill_level: int:
	get:
		return _effective_skill_level
var usage_bonus: int:
	get:
		return _usage_bonus
var combat_experience: int:
	get:
		return _combat_experience
var maximum_spirit: int:
	get:
		return _maximum_spirit
var current_spirit: int:
	get:
		return _current_spirit


func _init(
	p_living: bool = false,
	p_effective_skill_level: int = 0,
	p_usage_bonus: int = 0,
	p_combat_experience: int = 0,
	p_maximum_spirit: int = 0,
	p_current_spirit: int = 0,
) -> void:
	_living = p_living
	_effective_skill_level = p_effective_skill_level
	_usage_bonus = p_usage_bonus
	_combat_experience = p_combat_experience
	_maximum_spirit = p_maximum_spirit
	_current_spirit = p_current_spirit
