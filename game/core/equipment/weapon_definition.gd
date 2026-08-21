class_name WeaponDefinition
extends RefCounted

## Immutable authored facts required by feature/equip.c's hand-slot rules.
## Damage, weapon_prop, actions, value, weight, and presentation are deferred.
var _weapon_id: StringName
var _skill_type: StringName
var _can_wield_as_secondary: bool
var _is_two_handed: bool
var _legacy_source_path: String

var weapon_id: StringName:
	get:
		return _weapon_id

var skill_type: StringName:
	get:
		return _skill_type

var can_wield_as_secondary: bool:
	get:
		return _can_wield_as_secondary

var is_two_handed: bool:
	get:
		return _is_two_handed

var legacy_source_path: String:
	get:
		return _legacy_source_path


func _init(
	p_weapon_id: StringName = &"",
	p_skill_type: StringName = &"",
	p_can_wield_as_secondary: bool = false,
	p_is_two_handed: bool = false,
	p_legacy_source_path: String = "",
) -> void:
	_weapon_id = p_weapon_id
	_skill_type = p_skill_type
	_can_wield_as_secondary = p_can_wield_as_secondary
	_is_two_handed = p_is_two_handed
	_legacy_source_path = p_legacy_source_path
