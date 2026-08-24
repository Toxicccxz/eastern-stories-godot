class_name NativeItemDomainState
extends RefCounted

## Successful restore output. This bundle is scoped application/session state,
## not a global registry. Each contained aggregate remains the sole authority
## for its existing domain facts.
var _items: Dictionary[StringName, ItemInstance] = {}
var _inventory: InventoryState
var _combined_stacks: CombinedStackCollection
var _equipment_by_character: Dictionary[StringName, EquipmentState] = {}
var _armor_by_character: Dictionary[StringName, ArmorState] = {}

var inventory: InventoryState:
	get:
		return _inventory
var combined_stacks: CombinedStackCollection:
	get:
		return _combined_stacks


func _init(
	p_items: Dictionary[StringName, ItemInstance] = {},
	p_inventory: InventoryState = null,
	p_combined_stacks: CombinedStackCollection = null,
	p_equipment_by_character: Dictionary[StringName, EquipmentState] = {},
	p_armor_by_character: Dictionary[StringName, ArmorState] = {},
) -> void:
	for item_instance_id: StringName in p_items:
		var item: ItemInstance = p_items[item_instance_id]
		_items[item_instance_id] = ItemInstance.new(
			item.item_instance_id,
			item.item_definition_id,
		)
	_inventory = p_inventory
	_combined_stacks = p_combined_stacks
	_equipment_by_character = p_equipment_by_character.duplicate()
	_armor_by_character = p_armor_by_character.duplicate()


func item_instance(item_instance_id: StringName) -> ItemInstance:
	var item: ItemInstance = _items.get(item_instance_id)
	return (
		null
		if item == null
		else ItemInstance.new(item.item_instance_id, item.item_definition_id)
	)


func item_instance_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_items.keys())
	result.sort_custom(_string_name_less_than)
	return result


func equipment_state(character_id: StringName) -> EquipmentState:
	return _equipment_by_character.get(character_id)


func armor_state(character_id: StringName) -> ArmorState:
	return _armor_by_character.get(character_id)


func equipment_character_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_equipment_by_character.keys())
	result.sort_custom(_string_name_less_than)
	return result


func armor_character_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_armor_by_character.keys())
	result.sort_custom(_string_name_less_than)
	return result


func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
