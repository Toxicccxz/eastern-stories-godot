class_name CurrencyDefinition
extends RefCounted

## MONEY adds amount-scaled value on top of COMBINED_ITEM. Ordinary combined
## definitions deliberately have no corresponding generic value formula.
var _item_definition_id: StringName
var _base_value: int

var item_definition_id: StringName:
	get:
		return _item_definition_id

var base_value: int:
	get:
		return _base_value


func _init(
	p_item_definition_id: StringName = &"",
	p_base_value: int = 0,
) -> void:
	_item_definition_id = p_item_definition_id
	_base_value = p_base_value


func value_for_amount(amount: int) -> int:
	return amount * _base_value
