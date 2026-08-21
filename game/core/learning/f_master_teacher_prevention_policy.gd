class_name FMasterTeacherPreventionPolicy
extends "res://core/learning/teacher_prevention_policy.gd"


## Literal std/char/master.c::prevent_learn(). Its direct-apprentice test uses
## stable master ID plus the retained legacy master-name equality and does not
## use generation, deliberately differing from learn.c::is_appr_of().
func evaluate(
	student: CharacterStateType,
	context: TeachingContextType,
	student_raw_level: int,
) -> PolicyResultType:
	var betrayer_count: int = student.apprenticeship.betrayer_count
	if betrayer_count != 0:
		if student_raw_level >= context.teacher_raw_level - betrayer_count * 20:
			return PolicyResultType.new(PolicyResultType.Status.REJECTED)

	var is_feature_direct_apprentice: bool = (
		student.apprenticeship.has_master()
		and student.apprenticeship.master_teacher_id == context.teacher_id
		and student.apprenticeship.legacy_master_name == context.legacy_display_name
	)
	if not is_feature_direct_apprentice:
		if context.teacher_raw_level <= student_raw_level * 3:
			return PolicyResultType.new(PolicyResultType.Status.REJECTED)

	return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
