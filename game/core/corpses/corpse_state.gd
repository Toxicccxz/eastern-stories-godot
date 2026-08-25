class_name CorpseState
extends RefCounted

const EndpointType := preload("res://core/inventory/containment_endpoint.gd")
const InventoryStateType := preload("res://core/inventory/inventory_state.gd")

enum Stage {
	FRESH,
	ROTTEN,
	SKELETON,
	FINAL,
}

var _corpse_item_instance_id: StringName
var _victim_character_id: StringName
var _victim_display_name: String
var _victim_gender: StringName
var _victim_age: int
var _decay_stage: int
var _maximum_contents_encumbrance: int
var _worn_by_slot: Dictionary[StringName, StringName] = {}

var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id
var victim_character_id: StringName:
	get: return _victim_character_id
var victim_display_name: String:
	get: return _victim_display_name
var victim_gender: StringName:
	get: return _victim_gender
var victim_age: int:
	get: return _victim_age
var decay_stage: int:
	get: return _decay_stage
var maximum_contents_encumbrance: int:
	get: return _maximum_contents_encumbrance


func _init(
	p_corpse_item_instance_id: StringName = &"",
	p_victim_character_id: StringName = &"",
	p_victim_display_name: String = "",
	p_victim_gender: StringName = &"",
	p_victim_age: int = 0,
	p_maximum_contents_encumbrance: int = 0,
) -> void:
	_corpse_item_instance_id = p_corpse_item_instance_id
	_victim_character_id = p_victim_character_id
	_victim_display_name = p_victim_display_name
	_victim_gender = p_victim_gender
	_victim_age = p_victim_age
	_decay_stage = Stage.FRESH
	_maximum_contents_encumbrance = p_maximum_contents_encumbrance


func is_valid() -> bool:
	return _corpse_item_instance_id != &""


func is_legacy_corpse() -> bool:
	return _decay_stage < Stage.SKELETON


func is_legacy_character_for_equipment() -> bool:
	return _decay_stage < Stage.ROTTEN


func occupied_worn_slots() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_worn_by_slot.keys())
	result.sort_custom(_string_name_less_than)
	return result


func worn_item_in_slot(armor_type: StringName) -> StringName:
	return _worn_by_slot.get(armor_type, &"")


func worn_slot_for_item(item_instance_id: StringName) -> StringName:
	for armor_type: StringName in _worn_by_slot:
		if _worn_by_slot[armor_type] == item_instance_id:
			return armor_type
	return &""


func is_worn(item_instance_id: StringName) -> bool:
	return worn_slot_for_item(item_instance_id) != &""


## Narrow source-equivalent stage-0 wear projection. No numeric Armor facts
## are copied because corpse Combat never consumes them.
func _try_wear(
	armor_type: StringName,
	item_instance_id: StringName,
	inventory: InventoryStateType,
) -> bool:
	var corpse_endpoint: EndpointType = EndpointType.new(
		EndpointType.Kind.ITEM,
		_corpse_item_instance_id,
	)
	if (
		not is_legacy_character_for_equipment()
		or armor_type == &""
		or item_instance_id == &""
		or inventory == null
		or not inventory.is_registered(_corpse_item_instance_id)
		or not inventory.is_direct_child(item_instance_id, corpse_endpoint)
		or _worn_by_slot.has(armor_type)
		or is_worn(item_instance_id)
	):
		return false
	_worn_by_slot[armor_type] = item_instance_id
	return true


## feature/equip.c can detach corpse-worn armor only while stage 0 still
## reports is_character(). The projection is cleared before destination gates.
func _release_worn_for_transfer(item_instance_id: StringName) -> bool:
	if not is_legacy_character_for_equipment():
		return false
	var armor_type: StringName = worn_slot_for_item(item_instance_id)
	if armor_type == &"":
		return false
	_worn_by_slot.erase(armor_type)
	return true


func _apply_next_decay_stage(next_stage: int) -> bool:
	if next_stage != _decay_stage + 1 or next_stage > Stage.FINAL:
		return false
	_decay_stage = next_stage
	return true


func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
