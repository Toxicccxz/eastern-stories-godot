class_name CombatTacticalActionInfo
extends RefCounted

## Read-only value snapshot; retains no mutable gameplay authority.
var _action_id: StringName
var action_id: StringName:
	get: return _action_id
var _category: int
var category: int:
	get: return _category
var _target_rule: int
var target_rule: int:
	get: return _target_rule
var _blocks_when_busy: bool
var blocks_when_busy: bool:
	get: return _blocks_when_busy


func _init(
	p_action_id: StringName = &"",
	p_category: int = -1,
	p_target_rule: int = -1,
	p_blocks_when_busy: bool = true,
) -> void:
	_action_id = p_action_id
	_category = p_category
	_target_rule = p_target_rule
	_blocks_when_busy = p_blocks_when_busy
