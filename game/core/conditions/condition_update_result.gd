class_name ConditionUpdateResult
extends RefCounted

const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)

var combined_flags: int = 0

var no_heal_up: bool:
	get:
		return (combined_flags & ConditionUpdateFlagsType.NO_HEAL_UP) != 0


func include_flags(flags: int) -> void:
	combined_flags |= flags
