class_name ConditionUpdateResult
extends RefCounted

const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)

var combined_flags: int = 0
## Conditions updated in this pass, and the lines they told the character (translated).
var updated: int = 0
var lines: Array[ColoredLine] = []
## What the room saw (message("vision")): source templates naming the character as {name}.
var room_lines: Array[String] = []
## A daemon called unconcious() (drunk.c, slumber_drug.c).
var knocked_out: bool = false

var no_heal_up: bool:
	get:
		return (combined_flags & ConditionUpdateFlagsType.NO_HEAL_UP) != 0


func include_flags(flags: int) -> void:
	combined_flags |= flags
