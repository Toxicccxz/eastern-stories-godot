class_name TeacherRecognitionPolicy
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const TeachingContextType := preload("res://core/learning/teaching_context.gd")
const PolicyResultType := preload("res://core/learning/teacher_policy_result.gd")


## Explicit equivalent of a teacher with no recognize_apprentice() policy.
## LearnService keeps this distinct from an authored dependency that exists but
## cannot yet be evaluated.
func evaluate(
	_student: CharacterStateType,
	_context: TeachingContextType,
) -> PolicyResultType:
	return PolicyResultType.new(PolicyResultType.Status.NO_ADDITIONAL_POLICY)
