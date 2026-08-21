class_name TeacherPreventionPolicy
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const TeachingContextType := preload("res://core/learning/teaching_context.gd")
const PolicyResultType := preload("res://core/learning/teacher_policy_result.gd")


## Explicit equivalent of a teacher with no prevent_learn() implementation.
func evaluate(
	_student: CharacterStateType,
	_context: TeachingContextType,
	_student_raw_level: int,
) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.NO_ADDITIONAL_POLICY)
