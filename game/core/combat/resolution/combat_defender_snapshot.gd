class_name CombatDefenderSnapshot
extends RefCounted

var _character_id: StringName
var _living: bool
var _busy: bool
var _combat_experience: int
var _current_spirit: int
var _maximum_spirit: int
var _effective_dodge_skill_level: int
var _effective_parry_skill_level: int
var _effective_unarmed_skill_level: int
var _defense_usage_bonus: int
var _armor: int
var _has_primary_weapon: bool
var _limbs: Array[StringName] = []

var character_id: StringName:
	get:
		return _character_id
var living: bool:
	get:
		return _living
var busy: bool:
	get:
		return _busy
var combat_experience: int:
	get:
		return _combat_experience
var current_spirit: int:
	get:
		return _current_spirit
var maximum_spirit: int:
	get:
		return _maximum_spirit
var effective_dodge_skill_level: int:
	get:
		return _effective_dodge_skill_level
var effective_parry_skill_level: int:
	get:
		return _effective_parry_skill_level
var effective_unarmed_skill_level: int:
	get:
		return _effective_unarmed_skill_level
var defense_usage_bonus: int:
	get:
		return _defense_usage_bonus
var armor: int:
	get:
		return _armor
var has_primary_weapon: bool:
	get:
		return _has_primary_weapon


func _init(
	p_character_id: StringName = &"",
	p_living: bool = true,
	p_busy: bool = false,
	p_combat_experience: int = 0,
	p_current_spirit: int = 0,
	p_maximum_spirit: int = 0,
	p_effective_dodge_skill_level: int = 0,
	p_effective_parry_skill_level: int = 0,
	p_effective_unarmed_skill_level: int = 0,
	p_defense_usage_bonus: int = 0,
	p_armor: int = 0,
	p_has_primary_weapon: bool = false,
	p_limbs: Array[StringName] = [],
) -> void:
	_character_id = p_character_id
	_living = p_living
	_busy = p_busy
	_combat_experience = p_combat_experience
	_current_spirit = p_current_spirit
	_maximum_spirit = p_maximum_spirit
	_effective_dodge_skill_level = p_effective_dodge_skill_level
	_effective_parry_skill_level = p_effective_parry_skill_level
	_effective_unarmed_skill_level = p_effective_unarmed_skill_level
	_defense_usage_bonus = p_defense_usage_bonus
	_armor = p_armor
	_has_primary_weapon = p_has_primary_weapon
	_limbs = p_limbs.duplicate()


func limbs() -> Array[StringName]:
	return _limbs.duplicate()


func is_valid() -> bool:
	return not _character_id.is_empty()


func duplicate_snapshot() -> CombatDefenderSnapshot:
	return CombatDefenderSnapshot.new(
		_character_id,
		_living,
		_busy,
		_combat_experience,
		_current_spirit,
		_maximum_spirit,
		_effective_dodge_skill_level,
		_effective_parry_skill_level,
		_effective_unarmed_skill_level,
		_defense_usage_bonus,
		_armor,
		_has_primary_weapon,
		_limbs,
	)
