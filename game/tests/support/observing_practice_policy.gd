extends "res://core/training/practice_policy.gd"

var practice_call_count: int = 0
var should_succeed: bool


func _init(
	p_skill_id: StringName = &"",
	p_should_succeed: bool = true,
) -> void:
	super(p_skill_id)
	should_succeed = p_should_succeed


func practice(_character: CharacterStateType) -> bool:
	practice_call_count += 1
	return should_succeed
