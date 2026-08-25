class_name CorpseDecayScheduleIntent
extends RefCounted

var _corpse_item_instance_id: StringName
var _expected_stage: int
var _next_stage: int
var _delay_seconds: int

var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id
var expected_stage: int:
	get: return _expected_stage
var next_stage: int:
	get: return _next_stage
var delay_seconds: int:
	get: return _delay_seconds


func _init(
	p_corpse_item_instance_id: StringName = &"",
	p_expected_stage: int = 0,
	p_next_stage: int = 1,
	p_delay_seconds: int = 120,
) -> void:
	_corpse_item_instance_id = p_corpse_item_instance_id
	_expected_stage = p_expected_stage
	_next_stage = p_next_stage
	_delay_seconds = p_delay_seconds
