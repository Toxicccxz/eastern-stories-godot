class_name CombatActionSet
extends RefCounted

var _actions: Array[CombatActionDefinition] = []
var _valid: bool = false


func _init(p_actions: Array[CombatActionDefinition] = []) -> void:
	_valid = not p_actions.is_empty()
	var seen_ids: Array[StringName] = []
	for action: CombatActionDefinition in p_actions:
		if action == null:
			_valid = false
			_actions.append(null)
			continue
		var snapshot: CombatActionDefinition = action.duplicate_snapshot()
		_actions.append(snapshot)
		if not snapshot.is_valid() or seen_ids.has(snapshot.action_id):
			_valid = false
		else:
			seen_ids.append(snapshot.action_id)


func is_valid() -> bool:
	return _valid


func is_empty() -> bool:
	return _actions.is_empty()


func size() -> int:
	return _actions.size()


func action_at(index: int) -> CombatActionDefinition:
	if index < 0 or index >= _actions.size():
		return null
	var action: CombatActionDefinition = _actions[index]
	return action.duplicate_snapshot() if action != null else null


func actions() -> Array[CombatActionDefinition]:
	var snapshots: Array[CombatActionDefinition] = []
	for action: CombatActionDefinition in _actions:
		snapshots.append(action.duplicate_snapshot() if action != null else null)
	return snapshots
