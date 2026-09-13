class_name FoodCollection
extends RefCounted

## Session-owned association only. Inventory owns identity existence/weight/parent.
var _states: Dictionary[StringName, FoodState] = {}


func register_state(id: StringName, state: FoodState) -> bool:
	if id == &"" or state == null or _states.has(id):
		return false
	_states[id] = FoodState.new(state.remaining_portions, state.current_value)
	return true


func state(id: StringName) -> FoodState:
	return _states.get(id)


func instance_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_states.keys())
	ids.sort()
	return ids


## Caller has already completed authoritative item removal.
func forget_removed(ids: Array[StringName], inventory: InventoryState) -> bool:
	if inventory == null:
		return false
	for id: StringName in ids:
		if inventory.is_registered(id):
			return false
	for id: StringName in ids:
		_states.erase(id)
	return true
