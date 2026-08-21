class_name LearnService
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const TeachingContextType := preload("res://core/learning/teaching_context.gd")
const SkillDefinitionType := preload("res://core/skills/skill_definition.gd")
const SkillLearnPolicyType := preload("res://core/learning/skill_learn_policy.gd")
const SkillLearnPolicyResultType := preload(
	"res://core/learning/skill_learn_policy_result.gd"
)
const TeacherPolicyResultType := preload("res://core/learning/teacher_policy_result.gd")
const LearnResultType := preload("res://core/learning/learn_result.gd")
const EffectRegistryType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)

const ESSENCE_COST_NUMERATOR: int = 150
const TEACHER_SPIRIT_COST_DIVISOR: int = 5
const COMBAT_EXPERIENCE_DIVISOR: int = 10
const RANDOM_EXPERIENCE_BASE_DIVISOR: int = 1000


## Deterministic translation of cmds/std/learn.c after command/world lookup.
## The order is intentionally mutation-sensitive and must not be refactored
## into an all-validations-first transaction.
static func learn(
	student: CharacterStateType,
	context: TeachingContextType,
	skill_definition: SkillDefinitionType,
	skill_policy: SkillLearnPolicyType,
	effect_registry: EffectRegistryType = null,
) -> LearnResultType:
	var skill_id: StringName = context.offer.skill_id
	var result: LearnResultType = LearnResultType.new(skill_id)
	_snapshot_initial(result, student, context)

	## 1. me->is_fighting().
	if context.student_is_fighting:
		return _fail(result, LearnResultType.FailureReason.STUDENT_FIGHTING)

	## 2. present()/is_character()/living() become ordered typed facts.
	if not context.teacher_is_available:
		return _fail(result, LearnResultType.FailureReason.TEACHER_UNAVAILABLE)
	if not context.teacher_is_character:
		return _fail(result, LearnResultType.FailureReason.TEACHER_NOT_CHARACTER)
	if not context.teacher_is_awake:
		return _fail(result, LearnResultType.FailureReason.TEACHER_ASLEEP)

	## 3. Preserve learn.c's private ID+generation predicate separately from
	## feature/apprentice.c's ID+legacy-name predicate used by F_MASTER.
	var is_learn_private_direct: bool = (
		student.apprenticeship.has_master()
		and student.apprenticeship.master_teacher_id == context.teacher_id
		and student.family.generation == context.teacher_generation + 1
	)
	if is_learn_private_direct:
		result.relationship_admission = LearnResultType.RelationshipAdmission.LEARN_PRIVATE_DIRECT
	elif context.teacher_is_spouse:
		result.relationship_admission = LearnResultType.RelationshipAdmission.SPOUSE_EXEMPTION
	elif (
		student.family.has_family()
		and context.teacher_family_id != &""
		and student.family.family_id == context.teacher_family_id
		and context.legacy_family_privileges == -1
	):
		result.relationship_admission = (
			LearnResultType.RelationshipAdmission.SAME_FAMILY_FULL_PRIVILEGE
		)
	else:
		var recognition: TeacherPolicyResultType = context.recognition_policy.evaluate(
			student,
			context,
		)
		if recognition.status == TeacherPolicyResultType.Status.NO_ADDITIONAL_POLICY:
			return _fail(
				result,
				LearnResultType.FailureReason.RECOGNITION_POLICY_ABSENT,
			)
		if recognition.status == TeacherPolicyResultType.Status.DEPENDENCY_UNAVAILABLE:
			return _fail(
				result,
				LearnResultType.FailureReason.RECOGNITION_DEPENDENCY_UNAVAILABLE,
			)
		if recognition.status != TeacherPolicyResultType.Status.ALLOWED:
			return _fail(result, LearnResultType.FailureReason.RECOGNITION_REJECTED)
		result.relationship_admission = (
			LearnResultType.RelationshipAdmission.AUTHORED_RECOGNITION
		)

	## 4. LPC truthiness rejects exactly zero, not negative raw values.
	if context.teacher_raw_level == 0:
		return _fail(result, LearnResultType.FailureReason.TEACHER_SKILL_ZERO)

	## 5. Teacher prevent_learn(). No additional policy explicitly permits
	## continuation; dependency unavailable is not a gameplay rejection.
	var prevention: TeacherPolicyResultType = context.prevention_policy.evaluate(
		student,
		context,
		result.student_raw_before,
	)
	if prevention.status == TeacherPolicyResultType.Status.DEPENDENCY_UNAVAILABLE:
		return _fail(
			result,
			LearnResultType.FailureReason.PREVENTION_DEPENDENCY_UNAVAILABLE,
		)
	if prevention.status == TeacherPolicyResultType.Status.REJECTED:
		return _fail(result, LearnResultType.FailureReason.TEACHER_PREVENTED)

	## 6. Student and teacher raw comparison is strict.
	if result.student_raw_before >= context.teacher_raw_level:
		return _fail(
			result,
			LearnResultType.FailureReason.STUDENT_SKILL_NOT_BELOW_TEACHER,
		)

	## 7. SKILL_D(skill)->valid_learn(). Request integrity checks live at the
	## same boundary and never turn missing authored coverage into allow.
	if skill_definition == null or skill_definition.skill_id != skill_id:
		return _fail(result, LearnResultType.FailureReason.SKILL_DEFINITION_MISMATCH)
	if skill_policy == null or skill_policy.skill_id != skill_id:
		return _fail(result, LearnResultType.FailureReason.SKILL_POLICY_MISMATCH)
	var learn_policy_result: SkillLearnPolicyResultType = skill_policy.evaluate(student)
	result.skill_learn_policy_result = learn_policy_result
	if learn_policy_result.status == SkillLearnPolicyResultType.Status.DEPENDENCY_UNAVAILABLE:
		return _fail(
			result,
			LearnResultType.FailureReason.SKILL_LEARN_DEPENDENCY_UNAVAILABLE,
		)
	if learn_policy_result.status == SkillLearnPolicyResultType.Status.REJECTED:
		return _fail(result, LearnResultType.FailureReason.SKILL_LEARN_REJECTED)

	## 8. LPC evaluates teacher division before student division.
	if context.base_intelligence == 0:
		return _legacy_error(
			result,
			LearnResultType.FailureReason.LEGACY_TEACHER_INTELLIGENCE_DIVISION_BY_ZERO,
		)
	@warning_ignore("integer_division")
	var calculated_cost: int = ESSENCE_COST_NUMERATOR / context.base_intelligence
	if student.attributes.intelligence == 0:
		return _legacy_error(
			result,
			LearnResultType.FailureReason.LEGACY_STUDENT_INTELLIGENCE_DIVISION_BY_ZERO,
		)
	@warning_ignore("integer_division")
	calculated_cost += ESSENCE_COST_NUMERATOR / student.attributes.intelligence

	## 9. A raw value of zero (missing or explicit) doubles cost and writes an
	## explicit zero entry before every later rejection.
	if result.student_raw_before == 0:
		calculated_cost *= 2
		student.skills.set_raw_level(skill_id, 0)
		result.wrote_explicit_zero_skill_entry = true
		result.created_explicit_zero_skill_entry = not result.student_had_raw_entry_before
	result.calculated_essence_cost = calculated_cost
	_sync_student_state(result, student, context)

	## 10. Potential check follows the zero-entry mutation.
	if student.progression.potential_spent >= student.progression.potential:
		return _fail(result, LearnResultType.FailureReason.POTENTIAL_EXHAUSTED)

	## 11. env/no_teach follows potential.
	if context.teaching_temporarily_disabled:
		return _fail(
			result,
			LearnResultType.FailureReason.TEACHING_TEMPORARILY_DISABLED,
		)

	## 12. Exact strict teacher sen threshold.
	@warning_ignore("integer_division")
	var teacher_spirit_cost: int = calculated_cost / TEACHER_SPIRIT_COST_DIVISOR + 1
	result.teacher_spirit_cost = teacher_spirit_cost
	if context.current_spirit <= teacher_spirit_cost:
		result.completion = LearnResultType.Completion.NO_PROGRESS_TEACHER_FATIGUE
		return _fail(result, LearnResultType.FailureReason.TEACHER_TOO_TIRED)

	## 13. userp(ob) is an explicit projection policy. Negative damage would
	## error here, after the zero-entry and late checks, so preserve them.
	if context.teacher_pays_spirit_cost:
		if teacher_spirit_cost < 0:
			return _legacy_error(
				result,
				LearnResultType.FailureReason.LEGACY_NEGATIVE_TEACHER_SPIRIT_DAMAGE,
			)
		context.current_spirit -= teacher_spirit_cost
		result.teacher_spirit_after = context.current_spirit

	## 14. Only strict gin > cost can progress.
	if student.essence.current <= calculated_cost:
		var available_essence: int = student.essence.current
		result.actual_essence_cost = available_essence
		if available_essence < 0:
			return _legacy_error(
				result,
				LearnResultType.FailureReason.LEGACY_NEGATIVE_STUDENT_ESSENCE_DAMAGE,
			)
		student.essence.apply_damage(available_essence)
		result.success = true
		result.completion = LearnResultType.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE
		_sync_student_state(result, student, context)
		return result

	## 15. Martial experience gate uses the raw level before this Learn.
	if skill_definition.skill_type == SkillDefinitionType.Type.MARTIAL:
		@warning_ignore("integer_division")
		var required_experience: int = (
			result.student_raw_before
			* result.student_raw_before
			* result.student_raw_before
			/ COMBAT_EXPERIENCE_DIVISOR
		)
		result.required_combat_experience = required_experience
		if required_experience > student.progression.combat_experience:
			if not _apply_student_essence_cost(result, student, context, calculated_cost):
				return result
			result.success = true
			result.completion = LearnResultType.Completion.NO_PROGRESS_COMBAT_EXPERIENCE
			return result

	## 16. learned_points changes before random() and improve_skill().
	student.progression.potential_spent += 1
	result.potential_spent_after = student.progression.potential_spent

	## LPC evaluates the nested denominator only on the actual progress path.
	@warning_ignore("integer_division")
	var random_denominator: int = (
		RANDOM_EXPERIENCE_BASE_DIVISOR
		+ student.progression.combat_experience / RANDOM_EXPERIENCE_BASE_DIVISOR
	)
	if random_denominator == 0:
		return _legacy_error(
			result,
			LearnResultType.FailureReason.LEGACY_RANDOM_DENOMINATOR_DIVISION_BY_ZERO,
		)
	@warning_ignore("integer_division")
	var random_upper_bound: int = (
		student.attributes.intelligence
		+ student.progression.combat_experience / random_denominator
	)
	result.random_upper_bound = random_upper_bound
	if random_upper_bound <= 0:
		return _legacy_error(
			result,
			LearnResultType.FailureReason.LEGACY_NON_POSITIVE_RANDOM_BOUND,
		)
	if (
		context.deterministic_improvement_roll < 0
		or context.deterministic_improvement_roll >= random_upper_bound
	):
		return _legacy_error(
			result,
			LearnResultType.FailureReason.INVALID_DETERMINISTIC_ROLL,
		)

	## 17. Existing generic progression executes exactly once.
	result.skill_improvement = student.skills.improve_skill(
		skill_id,
		context.deterministic_improvement_roll,
		student.attributes.spirituality,
	)

	## 18. Reuse the same authored callback pipeline as Practice/Selflearn.
	var registry: EffectRegistryType = effect_registry
	if registry == null:
		registry = EffectRegistryType.new()
		registry.register_legacy_defaults()
	result.authored_effect = registry.apply(student, result.skill_improvement)

	## 19. gin damage occurs after skill_improved(). A negative cost would have
	## raised feature/damage.c::receive_damage() here, preserving prior effects.
	if not _apply_student_essence_cost(result, student, context, calculated_cost):
		return result
	result.success = true
	result.completion = (
		LearnResultType.Completion.LEVEL_INCREASED
		if result.skill_improvement.leveled_up
		else LearnResultType.Completion.PROGRESSED
	)
	return result


static func _snapshot_initial(
	result: LearnResultType,
	student: CharacterStateType,
	context: TeachingContextType,
) -> void:
	result.student_had_raw_entry_before = student.skills.has_raw_level(result.skill_id)
	result.student_raw_before = student.skills.raw_level(result.skill_id)
	result.student_raw_after = result.student_raw_before
	result.learned_before = student.skills.learned_progress(result.skill_id)
	result.learned_after = result.learned_before
	result.potential_spent_before = student.progression.potential_spent
	result.potential_spent_after = result.potential_spent_before
	result.essence_before = student.essence.current
	result.essence_after = result.essence_before
	result.teacher_spirit_before = context.current_spirit
	result.teacher_spirit_after = result.teacher_spirit_before
	result.deterministic_improvement_roll = context.deterministic_improvement_roll


static func _sync_student_state(
	result: LearnResultType,
	student: CharacterStateType,
	context: TeachingContextType,
) -> void:
	result.student_raw_after = student.skills.raw_level(result.skill_id)
	result.learned_after = student.skills.learned_progress(result.skill_id)
	result.potential_spent_after = student.progression.potential_spent
	result.essence_after = student.essence.current
	result.teacher_spirit_after = context.current_spirit


static func _apply_student_essence_cost(
	result: LearnResultType,
	student: CharacterStateType,
	context: TeachingContextType,
	cost: int,
) -> bool:
	result.actual_essence_cost = cost
	if cost < 0:
		_legacy_error(
			result,
			LearnResultType.FailureReason.LEGACY_NEGATIVE_STUDENT_ESSENCE_DAMAGE,
		)
		_sync_student_state(result, student, context)
		return false
	student.essence.apply_damage(cost)
	_sync_student_state(result, student, context)
	return true


static func _fail(result: LearnResultType, reason: int) -> LearnResultType:
	result.success = false
	result.failure_reason = reason
	return result


static func _legacy_error(result: LearnResultType, reason: int) -> LearnResultType:
	result.success = false
	result.failure_reason = reason
	result.completion = LearnResultType.Completion.LEGACY_ERROR
	return result
