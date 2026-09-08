class_name CombatTacticalRequest
extends RefCounted

enum Category { MARTIAL_SPECIAL, INTERNAL_FORCE, SPELL, TACTICAL_DEFENSE, ITEM, FLEE }
enum TargetRule { NONE, SELF, CURRENT_HOSTILE, SINGLE_HOSTILE }

var _request_id: StringName
var _encounter_id: StringName
var _actor_id: StringName
var _action_id: StringName
var _category: int
var _target_id: StringName

var request_id: StringName:
	get: return _request_id
var encounter_id: StringName:
	get: return _encounter_id
var actor_id: StringName:
	get: return _actor_id
var action_id: StringName:
	get: return _action_id
var category: int:
	get: return _category
var target_id: StringName:
	get: return _target_id


func _init(
	p_request_id: StringName = &"",
	p_encounter_id: StringName = &"",
	p_actor_id: StringName = &"",
	p_action_id: StringName = &"",
	p_category: int = -1,
	p_target_id: StringName = &"",
) -> void:
	_request_id = p_request_id
	_encounter_id = p_encounter_id
	_actor_id = p_actor_id
	_action_id = p_action_id
	_category = p_category
	_target_id = p_target_id


func is_valid() -> bool:
	return (
		not _request_id.is_empty() and not _encounter_id.is_empty()
		and not _actor_id.is_empty() and not _action_id.is_empty()
		and _category in Category.values()
	)


func duplicate_snapshot() -> CombatTacticalRequest:
	return CombatTacticalRequest.new(
		_request_id, _encounter_id, _actor_id, _action_id, _category, _target_id,
	)
