class_name DependencyUnavailableTeacherRecognitionPolicy
extends "res://core/learning/teacher_recognition_policy.gd"


func evaluate(
	_student: CharacterStateType,
	_context: TeachingContextType,
) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.DEPENDENCY_UNAVAILABLE)
