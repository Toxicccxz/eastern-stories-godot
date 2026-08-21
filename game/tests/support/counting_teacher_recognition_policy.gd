class_name CountingTeacherRecognitionPolicy
extends "res://core/learning/teacher_recognition_policy.gd"

var evaluation_count: int = 0
var _status: int


func _init(p_status: int) -> void:
	_status = p_status


func evaluate(
	_student: CharacterStateType,
	_context: TeachingContextType,
) -> PolicyResultType:
	evaluation_count += 1
	return PolicyResultType.new(_status)
