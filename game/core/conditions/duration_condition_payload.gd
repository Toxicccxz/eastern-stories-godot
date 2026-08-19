class_name DurationConditionPayload
extends "res://core/conditions/condition_payload.gd"

## Integer payload used by six of the seven legacy condition daemons.
## The value is intentionally unrestricted: several daemons treat zero and
## negative durations differently.
var remaining: int


func _init(p_remaining: int = 0) -> void:
	remaining = p_remaining
