class_name WorldItemInstanceIndex
extends RefCounted

const ItemInstanceType := preload("res://core/items/item_instance.gd")

## Runtime-owner-local immutable identity lookup. The current Old Pine runtime
## owner is its world session, shared by resident maps. InventoryState remains
## the authority for liveness, parentage, and weight.
var _items: Dictionary[StringName, ItemInstanceType] = {}


func register_snapshot(item: ItemInstanceType) -> bool:
	if (
		item == null
		or item.item_instance_id.is_empty()
		or item.item_definition_id.is_empty()
		or _items.has(item.item_instance_id)
	):
		return false
	_items[item.item_instance_id] = ItemInstanceType.new(
		item.item_instance_id,
		item.item_definition_id,
	)
	return true


func has_snapshot(item_instance_id: StringName) -> bool:
	return not item_instance_id.is_empty() and _items.has(item_instance_id)


func resolve(item_instance_id: StringName) -> ItemInstanceType:
	var item: ItemInstanceType = _items.get(item_instance_id)
	return (
		null
		if item == null
		else ItemInstanceType.new(item.item_instance_id, item.item_definition_id)
	)


func snapshot_count() -> int:
	return _items.size()


func snapshot_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_items.keys())
	result.sort_custom(
		func(left: StringName, right: StringName) -> bool:
			return String(left) < String(right)
	)
	return result
