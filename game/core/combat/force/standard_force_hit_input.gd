class_name StandardForceHitInput
extends RefCounted

var _provider_id: StringName
var _attacker_id: StringName
var _defender_id: StringName
var _factor: int
var _damage_bonus: int
var _attacker_has_primary_weapon: bool
var _attacker_force_skill_type: StringName
var _attacker_effective_force_skill_level: int
var _defender_force_skill_type: StringName
var _defender_effective_force_skill_level: int
var _defender_current_force: int
var _defender_armor_vs_force: int

var provider_id: StringName:
	get:
		return _provider_id
var attacker_id: StringName:
	get:
		return _attacker_id
var defender_id: StringName:
	get:
		return _defender_id
var factor: int:
	get:
		return _factor
var damage_bonus: int:
	get:
		return _damage_bonus
var attacker_has_primary_weapon: bool:
	get:
		return _attacker_has_primary_weapon
var attacker_force_skill_type: StringName:
	get:
		return _attacker_force_skill_type
var attacker_effective_force_skill_level: int:
	get:
		return _attacker_effective_force_skill_level
var defender_force_skill_type: StringName:
	get:
		return _defender_force_skill_type
var defender_effective_force_skill_level: int:
	get:
		return _defender_effective_force_skill_level
var defender_current_force: int:
	get:
		return _defender_current_force
var defender_armor_vs_force: int:
	get:
		return _defender_armor_vs_force


func _init(
	p_provider_id: StringName = &"",
	p_attacker_id: StringName = &"",
	p_defender_id: StringName = &"",
	p_factor: int = 0,
	p_damage_bonus: int = 0,
	p_attacker_has_primary_weapon: bool = false,
	p_attacker_force_skill_type: StringName = &"",
	p_attacker_effective_force_skill_level: int = 0,
	p_defender_force_skill_type: StringName = &"",
	p_defender_effective_force_skill_level: int = 0,
	p_defender_current_force: int = 0,
	p_defender_armor_vs_force: int = 0,
) -> void:
	_provider_id = p_provider_id
	_attacker_id = p_attacker_id
	_defender_id = p_defender_id
	_factor = p_factor
	_damage_bonus = p_damage_bonus
	_attacker_has_primary_weapon = p_attacker_has_primary_weapon
	_attacker_force_skill_type = p_attacker_force_skill_type
	_attacker_effective_force_skill_level = p_attacker_effective_force_skill_level
	_defender_force_skill_type = p_defender_force_skill_type
	_defender_effective_force_skill_level = p_defender_effective_force_skill_level
	_defender_current_force = p_defender_current_force
	_defender_armor_vs_force = p_defender_armor_vs_force


func is_valid() -> bool:
	return (
		not _provider_id.is_empty()
		and not _attacker_id.is_empty()
		and not _defender_id.is_empty()
		and not _attacker_force_skill_type.is_empty()
		and not _defender_force_skill_type.is_empty()
	)


func duplicate_snapshot() -> StandardForceHitInput:
	return StandardForceHitInput.new(
		_provider_id,
		_attacker_id,
		_defender_id,
		_factor,
		_damage_bonus,
		_attacker_has_primary_weapon,
		_attacker_force_skill_type,
		_attacker_effective_force_skill_level,
		_defender_force_skill_type,
		_defender_effective_force_skill_level,
		_defender_current_force,
		_defender_armor_vs_force,
	)
