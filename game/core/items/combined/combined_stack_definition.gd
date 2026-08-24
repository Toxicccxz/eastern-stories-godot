class_name CombinedStackDefinition
extends RefCounted

## Immutable facts belonging only to definitions which implement the legacy
## COMBINED_ITEM protocol. The compatibility ID is an exact merge-policy key,
## not another item identity and not display metadata.
var _item_definition_id: StringName
var _stack_compatibility_id: StringName
var _base_weight: int

var item_definition_id: StringName:
	get:
		return _item_definition_id

var stack_compatibility_id: StringName:
	get:
		return _stack_compatibility_id

var base_weight: int:
	get:
		return _base_weight


func _init(
	p_item_definition_id: StringName = &"",
	p_stack_compatibility_id: StringName = &"",
	p_base_weight: int = 0,
) -> void:
	_item_definition_id = p_item_definition_id
	_stack_compatibility_id = p_stack_compatibility_id
	_base_weight = p_base_weight


func is_valid() -> bool:
	return _item_definition_id != &"" and _stack_compatibility_id != &""


func compatibility_matches(other_compatibility_id: StringName) -> bool:
	return (
		_stack_compatibility_id != &""
		and _stack_compatibility_id == other_compatibility_id
	)


func own_weight_for_amount(amount: int) -> int:
	return amount * _base_weight

