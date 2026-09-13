class_name LiquidCollection
extends RefCounted

## Session association. Inventory alone owns existence/containment/weight.
var _states: Dictionary[StringName, LiquidState] = {}


func register_state(id: StringName, state: LiquidState) -> bool:
	if id == &"" or state == null or _states.has(id):
		return false
	_states[id] = state.duplicate_state()
	return true


func state(id: StringName) -> LiquidState:
	return _states.get(id)


func instance_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_states.keys())
	ids.sort()
	return ids


func forget_removed(ids: Array[StringName], inventory: InventoryState) -> bool:
	if inventory == null:
		return false
	for id: StringName in ids:
		if inventory.is_registered(id):
			return false
	for id: StringName in ids:
		_states.erase(id)
	return true
