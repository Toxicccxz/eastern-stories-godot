class_name CombatActionSelectionInput
extends RefCounted

## Immutable already-projected action sources. There is intentionally no
## secondary-weapon channel because reset_action() never consults it.
var _mapped_skill_present: bool
var _mapped_action_set: CombatActionSet
var _primary_weapon_present: bool
var _primary_weapon_action_set: CombatActionSet
var _default_action_set: CombatActionSet
## 战斗决策层 1B: the move the player chose (or the NPC's move drawn a beat early): taken
## from the set without a draw when it is in it; &"" draws as combatd.c reset_action().
var _chosen_action_id: StringName

var mapped_skill_present: bool:
	get:
		return _mapped_skill_present

var primary_weapon_present: bool:
	get:
		return _primary_weapon_present
var chosen_action_id: StringName:
	get:
		return _chosen_action_id


func _init(
	p_mapped_skill_present: bool = false,
	p_mapped_action_set: CombatActionSet = null,
	p_primary_weapon_present: bool = false,
	p_primary_weapon_action_set: CombatActionSet = null,
	p_default_action_set: CombatActionSet = null,
	p_chosen_action_id: StringName = &"",
) -> void:
	_chosen_action_id = p_chosen_action_id
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


## Same precedence as CombatActionSelector, without performing a draw.
func current_action_set() -> CombatActionSet:
	if mapped_skill_present:
		return mapped_action_set()
	if primary_weapon_present:
		return primary_weapon_action_set()
	return default_action_set()
