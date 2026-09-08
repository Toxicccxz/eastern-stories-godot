class_name BattleFeedbackProjection
extends RefCounted

## Read-only value snapshot; retains no mutable gameplay authority.
var _progression_order: int
var progression_order: int:
	get: return _progression_order
var _text: String
var text: String:
	get: return _text


func _init(
	p_progression_order: int = 0,
	p_text: String = "",
) -> void:
	_progression_order = p_progression_order
	_text = p_text
