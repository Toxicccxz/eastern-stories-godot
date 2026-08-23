class_name ItemInstance
extends RefCounted

## Immutable runtime identity plus its immutable definition identity reference.
## Containment, equipment, quantity, persistence, and other mutable state are
## deliberately absent from Phase 4B1.
var _item_instance_id: StringName
var _item_definition_id: StringName

var item_instance_id: StringName:
	get:
		return _item_instance_id

var item_definition_id: StringName:
	get:
		return _item_definition_id


func _init(
	p_item_instance_id: StringName = &"",
	p_item_definition_id: StringName = &"",
) -> void:
	_item_instance_id = p_item_instance_id
	_item_definition_id = p_item_definition_id
