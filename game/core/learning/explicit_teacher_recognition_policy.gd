class_name ExplicitTeacherRecognitionPolicy
extends "res://core/learning/teacher_recognition_policy.gd"

var _recognized: bool


func _init(p_recognized: bool) -> void:
	_recognized = p_recognized


func evaluate(
	_student: CharacterStateType,
	_context: TeachingContextType,
) -> PolicyResultType:
	return PolicyResultType.new(
		PolicyResultType.Status.ALLOWED
		if _recognized
		else PolicyResultType.Status.REJECTED
	)
