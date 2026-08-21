class_name DependencyUnavailableTeacherPreventionPolicy
extends "res://core/learning/teacher_prevention_policy.gd"


func evaluate(
	_student: CharacterStateType,
	_context: TeachingContextType,
	_student_raw_level: int,
) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.DEPENDENCY_UNAVAILABLE)
