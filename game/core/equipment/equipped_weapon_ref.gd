class_name EquippedWeaponRef
extends RefCounted

const WeaponDefinitionType := preload("res://core/equipment/weapon_definition.gd")

## Immutable runtime identity plus a scalar snapshot of the authored facts used
## by hand-state transitions. No inventory instance or Node reference is held.
var _instance_id: StringName
var _weapon_id: StringName
var _skill_type: StringName
var _can_wield_as_secondary: bool
var _is_two_handed: bool
var _legacy_source_path: String

var instance_id: StringName:
	get:
		return _instance_id

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
	p_instance_id: StringName = &"",
	p_definition: WeaponDefinitionType = null,
) -> void:
	_instance_id = p_instance_id
	if p_definition == null:
		_weapon_id = &""
		_skill_type = &""
		_can_wield_as_secondary = false
		_is_two_handed = false
		_legacy_source_path = ""
		return
	_weapon_id = p_definition.weapon_id
	_skill_type = p_definition.skill_type
	_can_wield_as_secondary = p_definition.can_wield_as_secondary
	_is_two_handed = p_definition.is_two_handed
	_legacy_source_path = p_definition.legacy_source_path


func is_valid() -> bool:
	return instance_id != &"" and weapon_id != &""


## RefCounted has no enforceable private fields in GDScript. EquipmentState
## therefore stores and returns scalar copies instead of sharing this object.
func duplicate_snapshot() -> EquippedWeaponRef:
	var snapshot: EquippedWeaponRef = EquippedWeaponRef.new()
	snapshot._instance_id = _instance_id
	snapshot._weapon_id = _weapon_id
	snapshot._skill_type = _skill_type
	snapshot._can_wield_as_secondary = _can_wield_as_secondary
	snapshot._is_two_handed = _is_two_handed
	snapshot._legacy_source_path = _legacy_source_path
	return snapshot
