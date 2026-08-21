extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const FamilyStateScript := preload("res://core/relationships/family_state.gd")
const ApprenticeshipStateScript := preload(
	"res://core/relationships/apprenticeship_state.gd"
)
const TeachingOfferScript := preload("res://core/learning/teaching_offer.gd")
const TeacherDefinitionScript := preload("res://core/learning/teacher_definition.gd")
const TeachingContextScript := preload("res://core/learning/teaching_context.gd")
const TeacherPolicyResultScript := preload("res://core/learning/teacher_policy_result.gd")
const ExplicitRecognitionPolicyScript := preload(
	"res://core/learning/explicit_teacher_recognition_policy.gd"
)
const TeacherRecognitionPolicyScript := preload(
	"res://core/learning/teacher_recognition_policy.gd"
)
const DependencyUnavailableRecognitionPolicyScript := preload(
	"res://core/learning/dependency_unavailable_teacher_recognition_policy.gd"
)
const TeacherPreventionPolicyScript := preload(
	"res://core/learning/teacher_prevention_policy.gd"
)
const DependencyUnavailablePreventionPolicyScript := preload(
	"res://core/learning/dependency_unavailable_teacher_prevention_policy.gd"
)
const FMasterPreventionPolicyScript := preload(
	"res://core/learning/f_master_teacher_prevention_policy.gd"
)
const DefaultSkillLearnPolicyScript := preload(
	"res://core/learning/default_skill_learn_policy.gd"
)
const MinimumInnerForcePolicyScript := preload(
	"res://core/learning/minimum_inner_force_skill_learn_policy.gd"
)
const DependencyUnavailablePolicyScript := preload(
	"res://core/learning/dependency_unavailable_skill_learn_policy.gd"
)
const SkillLearnPolicyScript := preload("res://core/learning/skill_learn_policy.gd")
const LearnResultScript := preload("res://core/learning/learn_result.gd")
const LearnServiceScript := preload("res://core/learning/learn_service.gd")
const SkillDefinitionScript := preload("res://core/skills/skill_definition.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const EffectResultScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)
const EffectRegistryScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const ObservingEffectScript := preload(
	"res://tests/support/observing_improvement_effect.gd"
)
const CountingRecognitionPolicyScript := preload(
	"res://tests/support/counting_teacher_recognition_policy.gd"
)

const TEACHER_ID: StringName = &"teacher.liu_chunfeng"
const OTHER_TEACHER_ID: StringName = &"teacher.other"
const FAMILY_ID: StringName = &"family.fonxan"
const OTHER_FAMILY_ID: StringName = &"family.other"
const LEGACY_TEACHER_NAME: String = "柳淳风"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_relationship_admission_paths()
	_test_f_master_prevention_boundaries()
	_test_teacher_validation_and_spirit_boundaries()
	_test_teacher_projection_fact_order()
	_test_cost_and_zero_entry_mutation_order()
	_test_student_essence_and_martial_experience_boundaries()
	_test_progression_random_and_effect_order()
	_test_skill_learn_policy_boundaries()
	_test_legacy_error_boundaries_and_partial_mutation()
	_test_state_and_definition_isolation()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_relationship_admission_paths() -> void:
	var direct: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	var direct_context: TeachingContextScript = _context()
	var direct_recognition: CountingRecognitionPolicyScript = (
		CountingRecognitionPolicyScript.new(TeacherPolicyResultScript.Status.REJECTED)
	)
	direct_context.recognition_policy = direct_recognition
	var direct_result: LearnResultScript = _learn(direct, direct_context)
	_assert_true(direct_result.success, "learn.c private direct apprentice accepted")
	_assert_eq(direct_recognition.evaluation_count, 0, "direct admission short-circuits recognition")
	_assert_eq(
		direct_result.relationship_admission,
		LearnResultScript.RelationshipAdmission.LEARN_PRIVATE_DIRECT,
		"direct admission uses master ID plus generation",
	)
	var direct_without_family_id: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	direct_without_family_id.family.family_id = &""
	var direct_without_family_result: LearnResultScript = _learn(
		direct_without_family_id,
		_context(),
	)
	_assert_true(
		direct_without_family_result.success,
		"learn.c private direct check does not read family name",
	)
	_assert_eq(
		direct_without_family_result.relationship_admission,
		LearnResultScript.RelationshipAdmission.LEARN_PRIVATE_DIRECT,
		"master ID and generation remain sufficient",
	)

	var wrong_generation: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	wrong_generation.family.generation = 13
	var wrong_context: TeachingContextScript = _context()
	wrong_context.legacy_family_privileges = 0
	wrong_context.recognition_policy = ExplicitRecognitionPolicyScript.new(false)
	var wrong_result: LearnResultScript = _learn(wrong_generation, wrong_context)
	_assert_failure(
		wrong_result,
		LearnResultScript.FailureReason.RECOGNITION_REJECTED,
		"wrong generation fails private direct test",
	)

	var spouse: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	spouse.family.family_id = OTHER_FAMILY_ID
	spouse.apprenticeship.master_teacher_id = OTHER_TEACHER_ID
	var spouse_context: TeachingContextScript = _context()
	spouse_context.teacher_is_spouse = true
	spouse_context.legacy_family_privileges = 0
	var spouse_recognition: CountingRecognitionPolicyScript = (
		CountingRecognitionPolicyScript.new(TeacherPolicyResultScript.Status.REJECTED)
	)
	spouse_context.recognition_policy = spouse_recognition
	var spouse_result: LearnResultScript = _learn(spouse, spouse_context)
	_assert_true(spouse_result.success, "spouse bypasses recognition")
	_assert_eq(spouse_recognition.evaluation_count, 0, "spouse admission short-circuits recognition")
	_assert_eq(
		spouse_result.relationship_admission,
		LearnResultScript.RelationshipAdmission.SPOUSE_EXEMPTION,
		"spouse admission recorded",
	)

	var same_family: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	same_family.apprenticeship.master_teacher_id = OTHER_TEACHER_ID
	var same_context: TeachingContextScript = _context()
	var same_recognition: CountingRecognitionPolicyScript = (
		CountingRecognitionPolicyScript.new(TeacherPolicyResultScript.Status.REJECTED)
	)
	same_context.recognition_policy = same_recognition
	var same_result: LearnResultScript = _learn(same_family, same_context)
	_assert_true(same_result.success, "same family and privs -1 bypass recognition")
	_assert_eq(same_recognition.evaluation_count, 0, "family privilege short-circuits recognition")
	_assert_eq(
		same_result.relationship_admission,
		LearnResultScript.RelationshipAdmission.SAME_FAMILY_FULL_PRIVILEGE,
		"same-family admission recorded",
	)

	for recognized: bool in [false, true]:
		var student: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
		student.family.family_id = OTHER_FAMILY_ID
		student.apprenticeship.master_teacher_id = OTHER_TEACHER_ID
		var context: TeachingContextScript = _context()
		context.legacy_family_privileges = 0
		context.recognition_policy = ExplicitRecognitionPolicyScript.new(recognized)
		var result: LearnResultScript = _learn(student, context)
		_assert_eq(result.success, recognized, "explicit recognition result is honored")
		_assert_eq(
			result.failure_reason,
			LearnResultScript.FailureReason.NONE if recognized else LearnResultScript.FailureReason.RECOGNITION_REJECTED,
			"recognition accept/reject reason",
		)

	var missing_policy: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	missing_policy.family.family_id = OTHER_FAMILY_ID
	missing_policy.apprenticeship.master_teacher_id = OTHER_TEACHER_ID
	var missing_context: TeachingContextScript = _context()
	missing_context.legacy_family_privileges = 0
	missing_context.recognition_policy = TeacherRecognitionPolicyScript.new()
	_assert_failure(
		_learn(missing_policy, missing_context),
		LearnResultScript.FailureReason.RECOGNITION_POLICY_ABSENT,
		"teacher with no recognition policy is explicit",
	)

	var unresolved_student: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
	unresolved_student.family.family_id = OTHER_FAMILY_ID
	unresolved_student.apprenticeship.master_teacher_id = OTHER_TEACHER_ID
	var unresolved_context: TeachingContextScript = _context()
	unresolved_context.legacy_family_privileges = 0
	unresolved_context.recognition_policy = DependencyUnavailableRecognitionPolicyScript.new()
	_assert_failure(
		_learn(unresolved_student, unresolved_context),
		LearnResultScript.FailureReason.RECOGNITION_DEPENDENCY_UNAVAILABLE,
		"known recognition dependency unavailable is distinct from no policy",
	)


func _test_f_master_prevention_boundaries() -> void:
	var feature_direct: CharacterStateScript = _student(SkillIdsScript.SWORD, 30)
	feature_direct.family.generation = 99
	var direct_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 31)
	direct_context.prevention_policy = FMasterPreventionPolicyScript.new()
	var direct_result: LearnResultScript = _learn(feature_direct, direct_context)
	_assert_true(direct_result.success, "F_MASTER direct check ignores generation")
	_assert_eq(
		direct_context.prevention_policy.evaluate(feature_direct, direct_context, 30).status,
		TeacherPolicyResultScript.Status.ALLOWED,
		"existing F_MASTER policy reports affirmative pass",
	)

	var wrong_name: CharacterStateScript = _student(SkillIdsScript.SWORD, 30)
	wrong_name.apprenticeship.legacy_master_name = "同 ID 的其他名字"
	var wrong_name_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 90)
	wrong_name_context.prevention_policy = FMasterPreventionPolicyScript.new()
	_assert_failure(
		_learn(wrong_name, wrong_name_context),
		LearnResultScript.FailureReason.TEACHER_PREVENTED,
		"F_MASTER retains legacy master-name equality",
	)

	for student_raw: int in [29, 30]:
		var betrayer: CharacterStateScript = _student(SkillIdsScript.SWORD, student_raw)
		betrayer.apprenticeship.betrayer_count = 1
		var context: TeachingContextScript = _context(SkillIdsScript.SWORD, 50)
		context.prevention_policy = FMasterPreventionPolicyScript.new()
		var result: LearnResultScript = _learn(betrayer, context)
		_assert_eq(result.success, student_raw == 29, "betrayer >= teacher-20 boundary")

	for teacher_raw: int in [30, 31]:
		var non_direct: CharacterStateScript = _student(SkillIdsScript.SWORD, 10)
		non_direct.apprenticeship.master_teacher_id = OTHER_TEACHER_ID
		var context: TeachingContextScript = _context(SkillIdsScript.SWORD, teacher_raw)
		context.prevention_policy = FMasterPreventionPolicyScript.new()
		var result: LearnResultScript = _learn(non_direct, context)
		_assert_eq(result.success, teacher_raw == 31, "non-direct teacher must exceed 3x raw")

	var unavailable_context: TeachingContextScript = _context()
	unavailable_context.prevention_policy = DependencyUnavailablePreventionPolicyScript.new()
	_assert_failure(
		_learn(_student(), unavailable_context),
		LearnResultScript.FailureReason.PREVENTION_DEPENDENCY_UNAVAILABLE,
		"known prevention dependency unavailable is explicit",
	)


func _test_teacher_validation_and_spirit_boundaries() -> void:
	var zero_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 0)
	_assert_failure(
		_learn(_student(SkillIdsScript.SWORD, -1), zero_context),
		LearnResultScript.FailureReason.TEACHER_SKILL_ZERO,
		"teacher raw zero rejected exactly",
	)
	for teacher_raw: int in [10, 11]:
		var result: LearnResultScript = _learn(
			_student(SkillIdsScript.SWORD, 10),
			_context(SkillIdsScript.SWORD, teacher_raw),
		)
		_assert_eq(result.success, teacher_raw == 11, "student must be strictly below teacher raw")

	## LPC cost at int 10/10 is 15 + 15 == 30; teacher cost is 30/5+1 == 7.
	for teacher_spirit: int in [7, 8]:
		var context: TeachingContextScript = _context()
		context.current_spirit = teacher_spirit
		var result: LearnResultScript = _learn(_student(), context)
		_assert_eq(result.success, teacher_spirit == 8, "teacher sen is strictly greater than 7")
		_assert_eq(context.current_spirit, teacher_spirit, "NPC teacher never pays spirit")

	var player_context: TeachingContextScript = _context()
	player_context.teacher_pays_spirit_cost = true
	player_context.current_spirit = 100
	var paid: LearnResultScript = _learn(_student(), player_context)
	_assert_true(paid.success, "player-style teacher can teach")
	_assert_eq(paid.teacher_spirit_cost, 7, "teacher exact spirit cost")
	_assert_eq(player_context.current_spirit, 93, "player-style teacher pays before student branch")

	var tired_player_context: TeachingContextScript = _context()
	tired_player_context.teacher_pays_spirit_cost = true
	tired_player_context.current_spirit = 7
	var tired_player: LearnResultScript = _learn(_student(), tired_player_context)
	_assert_failure(
		tired_player,
		LearnResultScript.FailureReason.TEACHER_TOO_TIRED,
		"player teacher exact threshold fails",
	)
	_assert_eq(tired_player_context.current_spirit, 7, "failed threshold deducts no teacher sen")

	var paid_before_student_failure: CharacterStateScript = _student()
	paid_before_student_failure.essence.current = 30
	var paid_failure_context: TeachingContextScript = _context()
	paid_failure_context.teacher_pays_spirit_cost = true
	var paid_failure: LearnResultScript = _learn(
		paid_before_student_failure,
		paid_failure_context,
	)
	_assert_eq(
		paid_failure.completion,
		LearnResultScript.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE,
		"later student gin failure is handled after teacher payment",
	)
	_assert_eq(paid_failure_context.current_spirit, 93, "later failure does not roll back teacher sen")
	_assert_eq(paid_before_student_failure.essence.current, 0, "later failure consumes equal gin")

	var no_teach: TeachingContextScript = _context()
	no_teach.teaching_temporarily_disabled = true
	_assert_failure(
		_learn(_student(), no_teach),
		LearnResultScript.FailureReason.TEACHING_TEMPORARILY_DISABLED,
		"env/no_teach rejection",
	)


func _test_teacher_projection_fact_order() -> void:
	var facts: Array[StringName] = [&"available", &"character", &"awake"]
	var expected_reasons: Array[int] = [
		LearnResultScript.FailureReason.TEACHER_UNAVAILABLE,
		LearnResultScript.FailureReason.TEACHER_NOT_CHARACTER,
		LearnResultScript.FailureReason.TEACHER_ASLEEP,
	]
	for index: int in range(facts.size()):
		var context: TeachingContextScript = _context()
		match facts[index]:
			&"available":
				context.teacher_is_available = false
			&"character":
				context.teacher_is_character = false
			&"awake":
				context.teacher_is_awake = false
		_assert_failure(
			_learn(_student(), context),
			expected_reasons[index],
			"typed teacher fact " + str(facts[index]),
		)

	var ordered: TeachingContextScript = _context()
	ordered.teacher_is_available = false
	ordered.teacher_is_character = false
	ordered.teacher_is_awake = false
	_assert_failure(
		_learn(_student(), ordered),
		LearnResultScript.FailureReason.TEACHER_UNAVAILABLE,
		"teacher facts retain present/is_character/living order",
	)


func _test_cost_and_zero_entry_mutation_order() -> void:
	var normal_context: TeachingContextScript = _context()
	normal_context.base_intelligence = 24
	var normal: LearnResultScript = _learn(_student(), normal_context)
	## LPC integer divisions: 150/24 == 6 and 150/10 == 15.
	_assert_eq(normal.calculated_essence_cost, 21, "integer cost terms truncate independently")
	_assert_eq(normal.teacher_spirit_cost, 5, "21/5+1 truncates to 5")

	var intelligence_edges: Array[Array] = [
		[1, 1, 300],
		[149, 150, 2],
		[150, 151, 1],
		[151, 1000, 0],
	]
	for edge: Array in intelligence_edges:
		var edge_student: CharacterStateScript = _student()
		edge_student.attributes.intelligence = int(edge[1])
		edge_student.essence.current = 200
		var edge_context: TeachingContextScript = _context()
		edge_context.base_intelligence = int(edge[0])
		edge_context.current_spirit = 500
		var edge_result: LearnResultScript = _learn(edge_student, edge_context)
		_assert_eq(
			edge_result.calculated_essence_cost,
			int(edge[2]),
			"150/int integer edge teacher=%d student=%d" % [edge[0], edge[1]],
		)

	var new_student: CharacterStateScript = _student(SkillIdsScript.SWORD, 0, false)
	var new_result: LearnResultScript = _learn(new_student, _context())
	_assert_eq(new_result.calculated_essence_cost, 60, "new raw-zero skill doubles cost")
	_assert_false(new_result.student_had_raw_entry_before, "missing raw entry recorded before Learn")
	_assert_true(new_result.wrote_explicit_zero_skill_entry, "raw-zero branch performs LPC set_skill")
	_assert_true(new_result.created_explicit_zero_skill_entry, "raw-zero branch reports creation")
	_assert_true(new_student.skills.has_raw_level(SkillIdsScript.SWORD), "raw zero stored explicitly")

	var existing_zero: CharacterStateScript = _student(SkillIdsScript.SWORD, 0, true)
	var existing_zero_result: LearnResultScript = _learn(existing_zero, _context())
	_assert_true(existing_zero_result.student_had_raw_entry_before, "explicit raw zero remains distinguishable")
	_assert_true(existing_zero_result.wrote_explicit_zero_skill_entry, "existing zero still follows LPC set_skill")
	_assert_false(existing_zero_result.created_explicit_zero_skill_entry, "existing zero is not reported as newly created")
	_assert_eq(existing_zero_result.calculated_essence_cost, 60, "explicit zero also doubles LPC cost")

	var late_failures: Array[int] = [
		LearnResultScript.FailureReason.POTENTIAL_EXHAUSTED,
		LearnResultScript.FailureReason.TEACHING_TEMPORARILY_DISABLED,
		LearnResultScript.FailureReason.TEACHER_TOO_TIRED,
	]
	for reason: int in late_failures:
		var student: CharacterStateScript = _student(SkillIdsScript.SWORD, 0, false)
		var context: TeachingContextScript = _context()
		if reason == LearnResultScript.FailureReason.POTENTIAL_EXHAUSTED:
			student.progression.potential_spent = student.progression.potential
		elif reason == LearnResultScript.FailureReason.TEACHING_TEMPORARILY_DISABLED:
			context.teaching_temporarily_disabled = true
		else:
			context.current_spirit = 13 # New skill cost 60: 60/5+1 == 13.
		var result: LearnResultScript = _learn(student, context)
		_assert_failure(result, reason, "late new-skill failure reason")
		_assert_true(student.skills.has_raw_level(SkillIdsScript.SWORD), "late failure keeps zero entry")
		_assert_eq(student.progression.potential_spent, result.potential_spent_before, "late failure does not spend potential")
		_assert_eq(student.essence.current, result.essence_before, "late failure does not damage gin")

	var early_fail: CharacterStateScript = _student(SkillIdsScript.SWORD, 0, false)
	var early_context: TeachingContextScript = _context()
	early_context.student_is_fighting = true
	_learn(early_fail, early_context)
	_assert_false(early_fail.skills.has_raw_level(SkillIdsScript.SWORD), "early failure does not create zero entry")

	var policy_failure: CharacterStateScript = _student(SkillIdsScript.FALL_STEPS, 0, false)
	policy_failure.recovery.inner_force.maximum = 49
	var policy_failure_result: LearnResultScript = _learn(
		policy_failure,
		_context(SkillIdsScript.FALL_STEPS, 10),
		SkillDefinitionScript.Type.MARTIAL,
		MinimumInnerForcePolicyScript.new(SkillIdsScript.FALL_STEPS, 50),
	)
	_assert_failure(
		policy_failure_result,
		LearnResultScript.FailureReason.SKILL_LEARN_REJECTED,
		"valid_learn rejection occurs before zero entry",
	)
	_assert_false(
		policy_failure.skills.has_raw_level(SkillIdsScript.FALL_STEPS),
		"valid_learn rejection creates no raw zero",
	)

	var comparison_failure: CharacterStateScript = _student(SkillIdsScript.SWORD, 0, false)
	var comparison_result: LearnResultScript = _learn(
		comparison_failure,
		_context(SkillIdsScript.SWORD, -1),
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_failure(
		comparison_result,
		LearnResultScript.FailureReason.STUDENT_SKILL_NOT_BELOW_TEACHER,
		"student raw comparison occurs before zero entry",
	)
	_assert_false(
		comparison_failure.skills.has_raw_level(SkillIdsScript.SWORD),
		"student comparison rejection creates no raw zero",
	)


func _test_student_essence_and_martial_experience_boundaries() -> void:
	for essence: int in [29, 30, 31]:
		var student: CharacterStateScript = _student()
		student.essence.current = essence
		var result: LearnResultScript = _learn(student, _context())
		_assert_eq(
			result.completion,
			LearnResultScript.Completion.PROGRESSED if essence == 31 else LearnResultScript.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE,
			"student gin must be strictly greater than 30",
		)
		_assert_eq(student.essence.current, 1 if essence == 31 else 0 if essence == 30 else 0, "gin consumption at/below/above cost")
		_assert_eq(student.progression.potential_spent, 1 if essence == 31 else 0, "potential only on progress branch")

	var zero_maximum: CharacterStateScript = _student()
	zero_maximum.essence.maximum = 0
	var zero_maximum_result: LearnResultScript = _learn(zero_maximum, _context())
	_assert_eq(zero_maximum_result.actual_essence_cost, 0, "zero resource maximum supplies current gin zero")
	_assert_eq(zero_maximum_result.completion, LearnResultScript.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE, "zero resource maximum adds no invented minimum")
	_assert_eq(zero_maximum.essence.current, 0, "zero gin remains zero after zero damage")

	## Raw 10 requires 10^3/10 == 100 combat experience.
	for combat_experience: int in [99, 100, 101]:
		var student: CharacterStateScript = _student()
		student.progression.combat_experience = combat_experience
		var result: LearnResultScript = _learn(student, _context())
		_assert_eq(result.required_combat_experience, 100, "raw-cubed martial requirement")
		_assert_eq(
			result.completion,
			LearnResultScript.Completion.NO_PROGRESS_COMBAT_EXPERIENCE if combat_experience == 99 else LearnResultScript.Completion.PROGRESSED,
			"martial combat-exp one-below/exact/one-above boundary",
		)
		_assert_eq(student.essence.current, 70, "martial gate still consumes exact gin")
		_assert_eq(student.progression.potential_spent, 0 if combat_experience == 99 else 1, "martial failure does not spend potential")

	var one_remaining: CharacterStateScript = _student()
	one_remaining.progression.potential = 7
	one_remaining.progression.potential_spent = 6
	var one_remaining_result: LearnResultScript = _learn(one_remaining, _context())
	_assert_true(one_remaining_result.success, "one remaining potential can progress")
	_assert_eq(one_remaining.progression.potential_spent, 7, "last potential increments exactly once")

	var exhausted: CharacterStateScript = _student()
	exhausted.progression.potential = 7
	exhausted.progression.potential_spent = 7
	var exhausted_result: LearnResultScript = _learn(exhausted, _context())
	_assert_failure(
		exhausted_result,
		LearnResultScript.FailureReason.POTENTIAL_EXHAUSTED,
		"potential equality rejects",
	)
	_assert_eq(exhausted.progression.potential_spent, 7, "exhausted potential is unchanged")


func _test_progression_random_and_effect_order() -> void:
	var no_level: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	no_level.skills.set_learned_progress(SkillIdsScript.SWORD, 3)
	no_level.progression.combat_experience = 1
	var no_level_result: LearnResultScript = _learn(no_level, _context(SkillIdsScript.SWORD, 20))
	_assert_eq(no_level_result.completion, LearnResultScript.Completion.PROGRESSED, "learned exactly square does not level")
	_assert_false(no_level_result.skill_improvement.leveled_up, "strict learned > (raw+1)^2")
	_assert_eq(no_level_result.skill_improvement.learned_after, 4, "improve called once with minimum adjusted amount 1")
	_assert_eq(no_level_result.authored_effect.status, EffectResultScript.Status.NOT_LEVELED_UP, "no level skips callback")

	var level_up: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	level_up.skills.set_learned_progress(SkillIdsScript.SWORD, 4)
	level_up.progression.combat_experience = 1
	var level_result: LearnResultScript = _learn(level_up, _context(SkillIdsScript.SWORD, 20))
	_assert_eq(level_result.completion, LearnResultScript.Completion.LEVEL_INCREASED, "one Learn raises at most one level")
	_assert_eq(level_result.skill_improvement.previous_level, 1, "level result previous raw")
	_assert_eq(level_result.skill_improvement.current_level, 2, "level result current raw")
	_assert_eq(level_result.skill_improvement.learned_after, 0, "level result has no carry")
	_assert_eq(level_result.authored_effect.status, EffectResultScript.Status.NO_AUTHORED_EFFECT, "sword has no authored callback")

	var observing_character: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	observing_character.skills.set_learned_progress(SkillIdsScript.SWORD, 4)
	observing_character.progression.combat_experience = 1
	var observer: ObservingEffectScript = ObservingEffectScript.new(SkillIdsScript.SWORD)
	var registry: EffectRegistryScript = EffectRegistryScript.new()
	registry.register_effect(observer)
	var observed: LearnResultScript = _learn(
		observing_character,
		_context(SkillIdsScript.SWORD, 20),
		SkillDefinitionScript.Type.MARTIAL,
		DefaultSkillLearnPolicyScript.new(SkillIdsScript.SWORD),
		registry,
	)
	_assert_true(observed.skill_improvement.leveled_up, "observer sees level event")
	_assert_eq(observer.apply_count, 1, "authored effect pipeline invoked exactly once")
	_assert_eq(observer.observed_potential_spent, 1, "potential increments before improve/effect")
	_assert_eq(observer.observed_essence_current, 100, "effect runs before student gin damage")
	_assert_eq(observing_character.essence.current, 70, "student gin damaged after effect")

	var force_student: CharacterStateScript = _student(SkillIdsScript.FORCE, 48)
	force_student.skills.set_learned_progress(SkillIdsScript.FORCE, 2401)
	force_student.progression.combat_experience = 11_059
	force_student.attributes.constitution = 11
	var force_result: LearnResultScript = _learn(
		force_student,
		_context(SkillIdsScript.FORCE, 100),
	)
	_assert_eq(force_result.completion, LearnResultScript.Completion.LEVEL_INCREASED, "Learn reaches authored force callback")
	_assert_eq(force_result.authored_effect.status, EffectResultScript.Status.APPLIED, "existing registry applies force effect")
	_assert_eq(force_student.attributes.constitution, 13, "force skill_improved mutation is not duplicated")
	_assert_eq(force_student.essence.current, 70, "force effect completes before exact gin damage")

	## At exp 100 and int 10, upper bound is 10 + 100/1000 == 10.
	for roll: int in [0, 9, -1, 10]:
		var student: CharacterStateScript = _student()
		student.progression.combat_experience = 100
		var context: TeachingContextScript = _context()
		context.deterministic_improvement_roll = roll
		var result: LearnResultScript = _learn(student, context)
		var valid: bool = roll >= 0 and roll < 10
		_assert_eq(result.success, valid, "deterministic random contract 0 <= roll < upper")
		_assert_eq(result.random_upper_bound, 10, "exact random upper bound")
		_assert_eq(student.progression.potential_spent, 1, "potential increments before roll validation")
		_assert_eq(student.essence.current, 70 if valid else 100, "invalid roll errors before gin damage")

	## LPC: int 1 + exp 0/(1000+0/1000) gives random(1), whose only roll is 0.
	for roll: int in [0, 1]:
		var upper_one_student: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
		upper_one_student.attributes.intelligence = 1
		upper_one_student.progression.combat_experience = 0
		upper_one_student.essence.current = 200
		var upper_one_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 20)
		upper_one_context.deterministic_improvement_roll = roll
		var upper_one_result: LearnResultScript = _learn(
			upper_one_student,
			upper_one_context,
			SkillDefinitionScript.Type.KNOWLEDGE,
		)
		_assert_eq(upper_one_result.random_upper_bound, 1, "random upper bound exactly one")
		_assert_eq(upper_one_result.success, roll == 0, "random(1) accepts only roll zero")
		_assert_eq(upper_one_student.progression.potential_spent, 1, "upper-one validation follows potential mutation")

	## LPC nested integer division: 1_000_000/(1000+1_000_000/1000)
	## is 1_000_000/2000 == 500; base int 10 produces upper 510.
	var nested_student: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	nested_student.progression.combat_experience = 1_000_000
	var nested_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 20)
	nested_context.deterministic_improvement_roll = 509
	var nested_result: LearnResultScript = _learn(
		nested_student,
		nested_context,
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_eq(nested_result.random_upper_bound, 510, "nested random division order")
	_assert_true(nested_result.success, "upper minus one remains valid at nested division edge")


func _test_skill_learn_policy_boundaries() -> void:
	var default_allowed: LearnResultScript = _learn(
		_student(),
		_context(),
		SkillDefinitionScript.Type.MARTIAL,
		DefaultSkillLearnPolicyScript.new(SkillIdsScript.SWORD),
	)
	_assert_true(default_allowed.success, "std/skill default valid_learn allows")

	for maximum_force: int in [49, 50]:
		var student: CharacterStateScript = _student(SkillIdsScript.FALL_STEPS, 1)
		student.recovery.inner_force.maximum = maximum_force
		var result: LearnResultScript = _learn(
			student,
			_context(SkillIdsScript.FALL_STEPS, 10),
			SkillDefinitionScript.Type.MARTIAL,
			MinimumInnerForcePolicyScript.new(SkillIdsScript.FALL_STEPS, 50),
		)
		_assert_eq(result.success, maximum_force == 50, "authored max-force allow/reject boundary")
		_assert_eq(
			result.failure_reason,
			LearnResultScript.FailureReason.NONE if maximum_force == 50 else LearnResultScript.FailureReason.SKILL_LEARN_REJECTED,
			"authored policy typed rejection",
		)

	var unavailable: LearnResultScript = _learn(
		_student(),
		_context(),
		SkillDefinitionScript.Type.MARTIAL,
		DependencyUnavailablePolicyScript.new(SkillIdsScript.SWORD),
	)
	_assert_failure(
		unavailable,
		LearnResultScript.FailureReason.SKILL_LEARN_DEPENDENCY_UNAVAILABLE,
		"missing authored dependency is not silently allowed",
	)


func _test_legacy_error_boundaries_and_partial_mutation() -> void:
	var teacher_zero: TeachingContextScript = _context()
	teacher_zero.base_intelligence = 0
	_assert_failure(
		_learn(_student(SkillIdsScript.SWORD, 0, false), teacher_zero),
		LearnResultScript.FailureReason.LEGACY_TEACHER_INTELLIGENCE_DIVISION_BY_ZERO,
		"teacher division fails before zero entry",
	)

	var student_zero_int: CharacterStateScript = _student(SkillIdsScript.SWORD, 0, false)
	student_zero_int.attributes.intelligence = 0
	var student_zero_result: LearnResultScript = _learn(student_zero_int, _context())
	_assert_failure(
		student_zero_result,
		LearnResultScript.FailureReason.LEGACY_STUDENT_INTELLIGENCE_DIVISION_BY_ZERO,
		"student division fails before zero entry",
	)
	_assert_false(student_zero_int.skills.has_raw_level(SkillIdsScript.SWORD), "division error precedes zero skill mutation")

	var non_positive_bound: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	non_positive_bound.attributes.intelligence = -1
	non_positive_bound.progression.combat_experience = 1
	var bound_result: LearnResultScript = _learn(
		non_positive_bound,
		_context(SkillIdsScript.SWORD, 20),
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_failure(bound_result, LearnResultScript.FailureReason.LEGACY_NON_POSITIVE_RANDOM_BOUND, "non-positive random upper bound is explicit")
	_assert_eq(non_positive_bound.progression.potential_spent, 1, "random-bound error keeps earlier potential increment")
	_assert_eq(non_positive_bound.essence.current, 100, "random-bound error occurs before gin damage")

	var denominator_zero: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	denominator_zero.progression.combat_experience = -1_000_000
	var denominator_result: LearnResultScript = _learn(
		denominator_zero,
		_context(SkillIdsScript.SWORD, 20),
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_failure(denominator_result, LearnResultScript.FailureReason.LEGACY_RANDOM_DENOMINATOR_DIVISION_BY_ZERO, "nested random denominator zero")
	_assert_eq(denominator_zero.progression.potential_spent, 1, "denominator error keeps potential")

	var negative_teacher_cost: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	negative_teacher_cost.attributes.intelligence = -10
	var paying_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 20)
	paying_context.base_intelligence = -10
	paying_context.teacher_pays_spirit_cost = true
	paying_context.current_spirit = 100
	var teacher_error: LearnResultScript = _learn(
		negative_teacher_cost,
		paying_context,
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_failure(teacher_error, LearnResultScript.FailureReason.LEGACY_NEGATIVE_TEACHER_SPIRIT_DAMAGE, "negative cost errors at player-teacher sen damage")
	_assert_eq(negative_teacher_cost.progression.potential_spent, 0, "teacher damage error precedes potential")

	var negative_student_cost: CharacterStateScript = _student(SkillIdsScript.SWORD, 1)
	negative_student_cost.attributes.intelligence = -10
	negative_student_cost.progression.combat_experience = 1_000_000
	var npc_context: TeachingContextScript = _context(SkillIdsScript.SWORD, 20)
	npc_context.base_intelligence = -10
	var student_error: LearnResultScript = _learn(
		negative_student_cost,
		npc_context,
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_failure(student_error, LearnResultScript.FailureReason.LEGACY_NEGATIVE_STUDENT_ESSENCE_DAMAGE, "NPC negative cost errors at student gin damage")
	_assert_eq(negative_student_cost.progression.potential_spent, 1, "NPC negative cost preserves progression")
	_assert_eq(negative_student_cost.skills.learned_progress(SkillIdsScript.SWORD), 1, "NPC negative cost preserves improve_skill mutation")
	_assert_eq(negative_student_cost.essence.current, 100, "negative damage does not mutate gin")

	var negative_teacher_raw: LearnResultScript = _learn(
		_student(SkillIdsScript.SWORD, -2),
		_context(SkillIdsScript.SWORD, -1),
		SkillDefinitionScript.Type.KNOWLEDGE,
	)
	_assert_true(negative_teacher_raw.success, "negative nonzero teacher raw remains LPC-truthy")


func _test_state_and_definition_isolation() -> void:
	var first: CharacterStateScript = CharacterStateScript.new()
	var second: CharacterStateScript = CharacterStateScript.new()
	first.family.family_id = FAMILY_ID
	first.apprenticeship.master_teacher_id = TEACHER_ID
	_assert_eq(second.family.family_id, &"", "FamilyState defaults are not shared")
	_assert_eq(second.apprenticeship.master_teacher_id, &"", "ApprenticeshipState defaults are not shared")

	var caller_offer: TeachingOfferScript = TeachingOfferScript.new(SkillIdsScript.SWORD)
	var offers: Array[TeachingOfferScript] = [caller_offer]
	var definition: TeacherDefinitionScript = TeacherDefinitionScript.new(
		TEACHER_ID,
		offers,
		"daemon/class/swordsman/master.c",
		"master swordsman",
		LEGACY_TEACHER_NAME,
	)
	offers.append(TeachingOfferScript.new(SkillIdsScript.FORCE))
	caller_offer._skill_id = SkillIdsScript.FORCE
	_assert_eq(definition.offer_count(), 1, "TeacherDefinition copies offer collection")
	_assert_true(definition.has_offer(SkillIdsScript.SWORD), "definition deep-copies original offer")
	_assert_false(definition.has_offer(SkillIdsScript.FORCE), "caller cannot mutate definition offer state")

	var first_context: TeachingContextScript = _context()
	var second_context: TeachingContextScript = _context()
	var shared_input_offer: TeachingOfferScript = TeachingOfferScript.new(SkillIdsScript.SWORD)
	var copied_context: TeachingContextScript = TeachingContextScript.new(
		TEACHER_ID,
		shared_input_offer,
	)
	shared_input_offer._skill_id = SkillIdsScript.FORCE
	_assert_eq(copied_context.offer.skill_id, SkillIdsScript.SWORD, "TeachingContext copies offer projection")
	first_context.current_spirit = 1
	_assert_eq(second_context.current_spirit, 100, "TeachingContext dynamic state is independent")
	_assert_true(first_context.recognition_policy != second_context.recognition_policy, "context policy defaults are independent")

	var first_result: LearnResultScript = _learn(_student(), _context())
	var second_result: LearnResultScript = _learn(_student(), _context())
	first_result.calculated_essence_cost = 999
	_assert_eq(second_result.calculated_essence_cost, 30, "LearnResult instances are independent")

	var first_policy: CountingRecognitionPolicyScript = CountingRecognitionPolicyScript.new(
		TeacherPolicyResultScript.Status.ALLOWED,
	)
	var second_policy: CountingRecognitionPolicyScript = CountingRecognitionPolicyScript.new(
		TeacherPolicyResultScript.Status.ALLOWED,
	)
	first_policy.evaluate(first, first_context)
	_assert_eq(first_policy.evaluation_count, 1, "first policy owns its mutable test state")
	_assert_eq(second_policy.evaluation_count, 0, "independent policy state is not shared")


func _student(
	skill_id: StringName = SkillIdsScript.SWORD,
	raw_level: int = 10,
	has_raw_entry: bool = true,
) -> CharacterStateScript:
	var student: CharacterStateScript = CharacterStateScript.new()
	_set_resource(student.essence, 100)
	_set_resource(student.vitality, 100)
	_set_resource(student.spirit, 100)
	student.attributes.intelligence = 10
	student.attributes.spirituality = 30
	student.progression.combat_experience = 100
	student.progression.potential = 100
	student.progression.potential_spent = 0
	student.family = FamilyStateScript.new(FAMILY_ID, 14)
	student.apprenticeship = ApprenticeshipStateScript.new(
		TEACHER_ID,
		LEGACY_TEACHER_NAME,
		0,
	)
	if has_raw_entry:
		student.skills.set_raw_level(skill_id, raw_level)
	return student


func _context(
	skill_id: StringName = SkillIdsScript.SWORD,
	teacher_raw_level: int = 100,
) -> TeachingContextScript:
	return TeachingContextScript.new(
		TEACHER_ID,
		TeachingOfferScript.new(skill_id),
		teacher_raw_level,
		10,
		100,
		FAMILY_ID,
		13,
		-1,
		LEGACY_TEACHER_NAME,
		true,
		true,
		true,
		false,
		false,
		false,
		false,
		1,
		TeacherRecognitionPolicyScript.new(),
		TeacherPreventionPolicyScript.new(),
	)


func _learn(
	student: CharacterStateScript,
	context: TeachingContextScript,
	skill_type: int = SkillDefinitionScript.Type.MARTIAL,
	policy: SkillLearnPolicyScript = null,
	registry: EffectRegistryScript = null,
) -> LearnResultScript:
	var actual_policy: SkillLearnPolicyScript = policy
	if actual_policy == null:
		actual_policy = DefaultSkillLearnPolicyScript.new(context.offer.skill_id)
	return LearnServiceScript.learn(
		student,
		context,
		SkillDefinitionScript.new(
			context.offer.skill_id,
			SkillDefinitionScript.Kind.BASIC,
			skill_type,
		),
		actual_policy,
		registry,
	)


func _set_resource(resource: CharacterResourceStateScript, value: int) -> void:
	resource.maximum = 200
	resource.effective = 200
	resource.current = value


func _assert_failure(result: LearnResultScript, reason: int, label: String) -> void:
	_assert_false(result.success, label + " success")
	_assert_eq(result.failure_reason, reason, label + " reason")


func _assert_true(condition: bool, label: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(label + ": expected true")


func _assert_false(condition: bool, label: String) -> void:
	_assertion_count += 1
	if condition:
		_failures.append(label + ": expected false")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
