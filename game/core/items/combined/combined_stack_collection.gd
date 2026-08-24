class_name CombinedStackCollection
extends RefCounted

const StackDefinitionType := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const StackStateType := preload("res://core/items/combined/combined_stack_state.gd")

## Aggregate-local stack associations only. This is not an ItemRepository or
## definition catalog; InventoryState remains authoritative for live item IDs.
var _states: Dictionary[StringName, StackStateType] = {}
var _definitions: Dictionary[StringName, StackDefinitionType] = {}


func has_stack(item_instance_id: StringName) -> bool:
	return item_instance_id != &"" and _states.has(item_instance_id)


func stack_state(item_instance_id: StringName) -> StackStateType:
	var state: StackStateType = _states.get(item_instance_id)
	return (
		null
		if state == null
		else StackStateType.new(state.item_instance_id, state.amount)
	)


func stack_definition(item_instance_id: StringName) -> StackDefinitionType:
	var definition: StackDefinitionType = _definitions.get(item_instance_id)
	return (
		null
		if definition == null
		else StackDefinitionType.new(
			definition.item_definition_id,
			definition.stack_compatibility_id,
			definition.base_weight,
		)
	)


func are_compatible(left_instance_id: StringName, right_instance_id: StringName) -> bool:
	var left: StackDefinitionType = _definitions.get(left_instance_id)
	var right: StackDefinitionType = _definitions.get(right_instance_id)
	return (
		left != null
		and right != null
		and left.compatibility_matches(right.stack_compatibility_id)
	)


func registered_count() -> int:
	return _states.size()


func _register_stack(
	state: StackStateType,
	definition: StackDefinitionType,
) -> bool:
	if (
		state == null
		or definition == null
		or state.item_instance_id == &""
		or not definition.is_valid()
		or _states.has(state.item_instance_id)
	):
		return false
	_states[state.item_instance_id] = StackStateType.new(
		state.item_instance_id,
		state.amount,
	)
	_definitions[state.item_instance_id] = StackDefinitionType.new(
		definition.item_definition_id,
		definition.stack_compatibility_id,
		definition.base_weight,
	)
	return true


func _mutable_state(item_instance_id: StringName) -> StackStateType:
	return _states.get(item_instance_id)


func _apply_amount(item_instance_id: StringName, amount: int) -> bool:
	var state: StackStateType = _states.get(item_instance_id)
	if state == null:
		return false
	state._amount = amount
	return true


func _remove_stack(item_instance_id: StringName) -> bool:
	if not _states.has(item_instance_id):
		return false
	_states.erase(item_instance_id)
	_definitions.erase(item_instance_id)
	return true
