class_name LearnPreview
extends RefCounted

## What one more cmds/std/learn.c would do, read without changing anything:
## LearnService.learn() writes a new skill's explicit zero entry, spends the teacher's
## sen and the student's gin, and draws for improve_skill(); this only reads, in learn()'s
## order. The result carries learn()'s failure, or the completion it reaches before the
## draw: NO_PROGRESS_* (gin spent for nothing), or PROGRESSED for the progress path (a
## level-up is the draw's to decide). Continuous 请教 looks with it before each step
## (TrainingRun). `context`'s recognition policy may draw for its refusal line: build
## it with a random source apart from the world's (TeacherService.preview_learn()).
## learn()'s legacy errors (a 0 or negative int, combat_exp near -1000000) all read as
## LEGACY_ERROR here; which of them comes first may differ, as no character reaches them.


static func next(
	student: CharacterState,
	context: TeachingContext,
	skill_definition: SkillDefinition,
	skill_policy: SkillLearnPolicy,
) -> LearnResult:
	var skill_id: StringName = context.offer.skill_id
	var result := LearnResult.new(skill_id)
	var raw: int = student.skills.raw_level(skill_id)
	result.student_had_raw_entry_before = student.skills.has_raw_level(skill_id)
	result.student_raw_before = raw
	result.student_raw_after = raw
	result.learned_before = student.skills.learned_progress(skill_id)
	result.learned_after = result.learned_before
	result.potential_spent_before = student.progression.potential_spent
	result.potential_spent_after = result.potential_spent_before
	result.essence_before = student.essence.current
	result.essence_after = result.essence_before
	result.teacher_spirit_before = context.current_spirit
	result.teacher_spirit_after = context.current_spirit

	if context.student_is_fighting:
		return _fail(result, LearnResult.FailureReason.STUDENT_FIGHTING)
	if not context.teacher_is_available:
		return _fail(result, LearnResult.FailureReason.TEACHER_UNAVAILABLE)
	if not context.teacher_is_character:
		return _fail(result, LearnResult.FailureReason.TEACHER_NOT_CHARACTER)
	if not context.teacher_is_awake:
		return _fail(result, LearnResult.FailureReason.TEACHER_ASLEEP)
	var admission_failure: int = LearnService.admit(result, student, context)
	if admission_failure != LearnResult.FailureReason.NONE:
		return _fail(result, admission_failure)
	if context.teacher_raw_level == 0:
		return _fail(result, LearnResult.FailureReason.TEACHER_SKILL_ZERO)
	var prevention: TeacherPolicyResult = context.prevention_policy.evaluate(student, context, raw)
	if prevention.status == TeacherPolicyResult.Status.DEPENDENCY_UNAVAILABLE:
		return _fail(result, LearnResult.FailureReason.PREVENTION_DEPENDENCY_UNAVAILABLE)
	if prevention.status == TeacherPolicyResult.Status.REJECTED:
		return _fail(result, LearnResult.FailureReason.TEACHER_PREVENTED)
	if raw >= context.teacher_raw_level:
		return _fail(result, LearnResult.FailureReason.STUDENT_SKILL_NOT_BELOW_TEACHER)
	if skill_definition == null or skill_definition.skill_id != skill_id:
		return _fail(result, LearnResult.FailureReason.SKILL_DEFINITION_MISMATCH)
	if skill_policy == null or skill_policy.skill_id != skill_id:
		return _fail(result, LearnResult.FailureReason.SKILL_POLICY_MISMATCH)
	var policy_result: SkillLearnPolicyResult = skill_policy.evaluate(student)
	result.skill_learn_policy_result = policy_result
	if policy_result.status == SkillLearnPolicyResult.Status.DEPENDENCY_UNAVAILABLE:
		return _fail(result, LearnResult.FailureReason.SKILL_LEARN_DEPENDENCY_UNAVAILABLE)
	if policy_result.status == SkillLearnPolicyResult.Status.REJECTED:
		return _fail(result, LearnResult.FailureReason.SKILL_LEARN_REJECTED)
	if context.base_intelligence == 0:
		return _legacy_error(result, LearnResult.FailureReason.LEGACY_TEACHER_INTELLIGENCE_DIVISION_BY_ZERO)
	if student.attributes.intelligence == 0:
		return _legacy_error(result, LearnResult.FailureReason.LEGACY_STUDENT_INTELLIGENCE_DIVISION_BY_ZERO)
	var cost: int = LearnService.base_essence_cost(context.base_intelligence, student.attributes.intelligence)
	if raw == 0:
		cost *= 2
	result.calculated_essence_cost = cost
	if student.progression.potential_spent >= student.progression.potential:
		return _fail(result, LearnResult.FailureReason.POTENTIAL_EXHAUSTED)
	if context.teaching_temporarily_disabled:
		return _fail(result, LearnResult.FailureReason.TEACHING_TEMPORARILY_DISABLED)
	@warning_ignore("integer_division")
	var teacher_spirit_cost: int = cost / LearnService.TEACHER_SPIRIT_COST_DIVISOR + 1
	result.teacher_spirit_cost = teacher_spirit_cost
	if context.current_spirit <= teacher_spirit_cost:
		result.completion = LearnResult.Completion.NO_PROGRESS_TEACHER_FATIGUE
		return _fail(result, LearnResult.FailureReason.TEACHER_TOO_TIRED)
	if context.teacher_pays_spirit_cost and teacher_spirit_cost < 0:
		return _legacy_error(result, LearnResult.FailureReason.LEGACY_NEGATIVE_TEACHER_SPIRIT_DAMAGE)
	if student.essence.current <= cost:
		if student.essence.current < 0:
			return _legacy_error(result, LearnResult.FailureReason.LEGACY_NEGATIVE_STUDENT_ESSENCE_DAMAGE)
		result.success = true
		result.completion = LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE
		return result
	if cost < 0:
		return _legacy_error(result, LearnResult.FailureReason.LEGACY_NEGATIVE_STUDENT_ESSENCE_DAMAGE)
	if skill_definition.skill_type == SkillDefinition.Type.MARTIAL:
		var required: int = LearnService.required_combat_experience(raw)
		result.required_combat_experience = required
		if required > student.progression.combat_experience:
			result.success = true
			result.completion = LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE
			return result
	@warning_ignore("integer_division")
	var denominator: int = (
		LearnService.RANDOM_EXPERIENCE_BASE_DIVISOR
		+ student.progression.combat_experience / LearnService.RANDOM_EXPERIENCE_BASE_DIVISOR
	)
	if denominator == 0:
		return _legacy_error(result, LearnResult.FailureReason.LEGACY_RANDOM_DENOMINATOR_DIVISION_BY_ZERO)
	result.success = true
	result.completion = LearnResult.Completion.PROGRESSED
	return result


## The step would spend gin and learn nothing (gin not above the cost, or too little
## combat_exp for the level): continuous 请教 stops before it (owner, 2026-10-19).
static func wastes(result: LearnResult) -> bool:
	return result.failure_reason == LearnResult.FailureReason.NONE and result.completion in [
		LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE,
		LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE,
	]


static func _fail(result: LearnResult, reason: int) -> LearnResult:
	result.success = false
	result.failure_reason = reason
	return result


static func _legacy_error(result: LearnResult, reason: int) -> LearnResult:
	result.success = false
	result.failure_reason = reason
	result.completion = LearnResult.Completion.LEGACY_ERROR
	return result
