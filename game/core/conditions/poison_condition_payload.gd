class_name PoisonConditionPayload
extends "res://core/conditions/condition_payload.gd"

## Explicit translation of the mapping shape read by daemon/condition/poison.c.
## Its handler is deferred because that daemon writes this payload under the
## incompatible snake_poison ID; keeping the shape typed avoids a generic map.
var damage: int
var remaining: int
var legacy_message: String


func _init(
	p_damage: int = 0,
	p_remaining: int = 0,
	p_legacy_message: String = "",
) -> void:
	damage = p_damage
	remaining = p_remaining
	legacy_message = p_legacy_message
