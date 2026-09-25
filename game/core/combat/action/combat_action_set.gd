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


func contains_exact(action: CombatActionDefinition) -> bool:
	if not is_valid():
		return false
	for candidate: CombatActionDefinition in _actions:
		if same_action(candidate, action):
			return true
	return false


func matches_exact(other: CombatActionSet) -> bool:
	if other == null or not is_valid() or not other.is_valid() or size() != other.size():
		return false
	for index: int in range(size()):
		if not same_action(_actions[index], other.action_at(index)):
			return false
	return true


static func same_action(left: CombatActionDefinition, right: CombatActionDefinition) -> bool:
	return (
		left != null and right != null and left.is_valid() and right.is_valid()
		and left.action_id == right.action_id
		and left.damage_percent == right.damage_percent
		and left.force_percent == right.force_percent
		and left.damage_type == right.damage_type
		and left.presentation_key == right.presentation_key
		and left.legacy_action_text == right.legacy_action_text
		and left.displayed_weapon_or_body_token == right.displayed_weapon_or_body_token
		and left.post_action_policy_id == right.post_action_policy_id
	)
