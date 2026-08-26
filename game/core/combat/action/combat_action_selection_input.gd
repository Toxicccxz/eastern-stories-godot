class_name CombatActionSelectionInput
extends RefCounted

## Immutable already-projected action sources. There is intentionally no
## secondary-weapon channel because reset_action() never consults it.
var _mapped_skill_present: bool
var _mapped_action_set: CombatActionSet
var _primary_weapon_present: bool
var _primary_weapon_action_set: CombatActionSet
var _default_action_set: CombatActionSet

var mapped_skill_present: bool:
	get:
		return _mapped_skill_present

var primary_weapon_present: bool:
	get:
		return _primary_weapon_present


func _init(
	p_mapped_skill_present: bool = false,
	p_mapped_action_set: CombatActionSet = null,
	p_primary_weapon_present: bool = false,
	p_primary_weapon_action_set: CombatActionSet = null,
	p_default_action_set: CombatActionSet = null,
) -> void:
	_mapped_skill_present = p_mapped_skill_present
	_mapped_action_set = _snapshot_set(p_mapped_action_set)
	_primary_weapon_present = p_primary_weapon_present
	_primary_weapon_action_set = _snapshot_set(p_primary_weapon_action_set)
	_default_action_set = _snapshot_set(p_default_action_set)


func mapped_action_set() -> CombatActionSet:
	return _snapshot_set(_mapped_action_set)


func primary_weapon_action_set() -> CombatActionSet:
	return _snapshot_set(_primary_weapon_action_set)


func default_action_set() -> CombatActionSet:
	return _snapshot_set(_default_action_set)


func _snapshot_set(source: CombatActionSet) -> CombatActionSet:
	if source == null:
		return null
	return CombatActionSet.new(source.actions())
