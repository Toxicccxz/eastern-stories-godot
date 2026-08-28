class_name WorldItemRowProjection
extends RefCounted

var _item_instance_id: StringName
var _item_definition_id: StringName
var _display_name: String
var _description: String
var _amount: int
var _category: StringName
var _can_take: bool
var _corpse_worn: bool
var _corpse_worn_locked: bool

var item_instance_id: StringName:
	get: return _item_instance_id
var item_definition_id: StringName:
	get: return _item_definition_id
var display_name: String:
	get: return _display_name
var description: String:
	get: return _description
var amount: int:
	get: return _amount
var category: StringName:
	get: return _category
var can_take: bool:
	get: return _can_take
var corpse_worn: bool:
	get: return _corpse_worn
var corpse_worn_locked: bool:
	get: return _corpse_worn_locked


func _init(
	p_item_instance_id: StringName = &"",
	p_item_definition_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_amount: int = 1,
	p_category: StringName = &"",
	p_can_take: bool = false,
	p_corpse_worn: bool = false,
	p_corpse_worn_locked: bool = false,
) -> void:
	_item_instance_id = p_item_instance_id
	_item_definition_id = p_item_definition_id
	_display_name = p_display_name
	_description = p_description
	_amount = p_amount
	_category = p_category
	_can_take = p_can_take
	_corpse_worn = p_corpse_worn
	_corpse_worn_locked = p_corpse_worn_locked
