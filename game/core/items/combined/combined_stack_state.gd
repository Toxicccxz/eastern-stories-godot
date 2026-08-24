class_name CombinedStackState
extends RefCounted

## Per-instance authority for the legacy static amount field. Containment and
## current own weight remain authoritative in InventoryState.
var _item_instance_id: StringName
var _amount: int

var item_instance_id: StringName:
	get:
		return _item_instance_id

var amount: int:
	get:
		return _amount


func _init(
	p_item_instance_id: StringName = &"",
	p_amount: int = 0,
) -> void:
	_item_instance_id = p_item_instance_id
	_amount = p_amount

