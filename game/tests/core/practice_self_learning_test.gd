extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const VitalityInnerForcePracticePolicyScript := preload(
	"res://core/training/vitality_inner_force_practice_policy.gd"
)
const PracticePoliciesScript := preload("res://core/training/practice_policies.gd")
const PracticeResultScript := preload("res://core/training/practice_result.gd")
const PracticeServiceScript := preload("res://core/training/practice_service.gd")
const SkillLearnPolicyScript := preload("res://core/learning/skill_learn_policy.gd")
const SkillLearnPolicyRegistryScript := preload(
	"res://core/learning/skill_learn_policy_registry.gd"
)
const SkillLearnPolicyResultScript := preload(
	"res://core/learning/skill_learn_policy_result.gd"
)
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const ObservingPracticePolicyScript := preload(
	"res://tests/support/observing_practice_policy.gd"
)
const SelfLearningResultScript := preload("res://core/training/self_learning_result.gd")
const SelfLearningServiceScript := preload("res://core/training/self_learning_service.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_practice_normal_attempt()
	_test_practice_validation_order_and_missing_skills()
	_test_practice_valid_learn_requirement()
	_test_practice_shared_valid_learn_order()
	_test_practice_resource_boundaries()
	_test_practice_no_progress_policy()
	_test_practice_improvement_integer_division_boundaries()
	_test_practice_exact_level_threshold_and_level_up()
	_test_practice_weak_player_semantics()
	_test_practice_policy_and_state_isolation()
	_test_self_learning_normal_attempt()
	_test_self_learning_skill_and_combat_validation_order()
	_test_self_learning_prerequisites()
	_test_self_learning_uses_raw_skill_for_prerequisite()
	_test_self_learning_essence_boundaries()
	_test_self_learning_combat_experience_boundaries()
	_test_self_learning_cost_integer_division_boundaries()
	_test_self_learning_roll_boundaries()
	_test_self_learning_exact_level_threshold_and_level_up()
	_test_self_learning_zero_cost_integer_division()
	_test_self_learning_state_and_result_isolation()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_practice_normal_attempt() -> void:
	var character: CharacterStateScript = _practice_character(50, 20)
	var result: PracticeResultScript = PracticeServiceScript.practice(
		character,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	## practice.c: improvement = raw dodge 50 / 5 + 1 = 11.
	_assert_true(result.success, "practice normal success")
	_assert_eq(result.completion, PracticeResultScript.Completion.PROGRESSED, "practice progress")
	_assert_eq(result.improvement_amount, 11, "practice improvement formula")
	_assert_false(result.weak_mode, "basic above special disables weak mode")
	_assert_eq(character.vitality.current, 70, "fall-steps spends 30 kee")
	_assert_eq(character.recovery.inner_force.current, 7, "fall-steps spends 3 force")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.FALL_STEPS), 11, "practice learned")
	_assert_eq(character.skills.raw_level(SkillIdsScript.FALL_STEPS), 20, "practice no level yet")


func _test_practice_validation_order_and_missing_skills() -> void:
	var unmapped: CharacterStateScript = _base_character()
	var fighting: PracticeResultScript = PracticeServiceScript.practice(
		unmapped,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		true,
	)
	_assert_failure(fighting, PracticeResultScript.FailureReason.IN_COMBAT, "practice combat first")

	var no_mapping: PracticeResultScript = PracticeServiceScript.practice(
		unmapped,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(no_mapping, PracticeResultScript.FailureReason.SKILL_NOT_MAPPED, "practice mapping")

	var missing_both: CharacterStateScript = _practice_character(0, 0)
	var missing_special: PracticeResultScript = PracticeServiceScript.practice(
		missing_both,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(
		missing_special,
		PracticeResultScript.FailureReason.SPECIAL_SKILL_NOT_LEARNED,
		"practice special checked before basic",
	)

	var missing_basic: CharacterStateScript = _practice_character(0, 1)
	var basic_failure: PracticeResultScript = PracticeServiceScript.practice(
		missing_basic,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(
		basic_failure,
		PracticeResultScript.FailureReason.BASIC_SKILL_NOT_LEARNED,
		"practice missing basic",
	)
	_assert_practice_resources(missing_basic, 100, 10, "missing skill mutates nothing")


func _test_practice_valid_learn_requirement() -> void:
	var character: CharacterStateScript = _practice_character(50, 20)
	character.recovery.inner_force.maximum = 49
	var result: PracticeResultScript = PracticeServiceScript.practice(
		character,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(
		result,
		PracticeResultScript.FailureReason.VALID_LEARN_REJECTED,
		"fall-steps max_force below 50",
	)
	_assert_practice_resources(character, 100, 10, "valid_learn failure no resource mutation")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.FALL_STEPS), 0, "valid_learn no learned")
	_assert_eq(
		result.skill_learn_policy_result.reason,
		SkillLearnPolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW,
		"practice exposes shared fall-steps valid_learn reason",
	)


func _test_practice_shared_valid_learn_order() -> void:
	var gender_blocked: CharacterStateScript = _mapped_practice_character(
		SkillIdsScript.DODGE,
		SkillIdsScript.STORMDANCE,
		50,
		20,
	)
	gender_blocked.gender = CharacterStateScript.GENDER_MALE
	gender_blocked.attributes.spirituality = 20
	var gender_hook: ObservingPracticePolicyScript = ObservingPracticePolicyScript.new(
		SkillIdsScript.STORMDANCE,
		true,
	)
	var gender_result: PracticeResultScript = PracticeServiceScript.practice(
		gender_blocked,
		SkillIdsScript.DODGE,
		gender_hook,
		_learn_policy(SkillIdsScript.STORMDANCE),
		false,
	)
	_assert_failure(
		gender_result,
		PracticeResultScript.FailureReason.VALID_LEARN_REJECTED,
		"practice shared gender valid_learn",
	)
	_assert_eq(
		gender_result.skill_learn_policy_result.reason,
		SkillLearnPolicyResultScript.Reason.GENDER_MISMATCH,
		"practice keeps authored gender rejection",
	)
	_assert_eq(gender_hook.practice_call_count, 0, "gender rejection precedes practice_skill")
	_assert_eq(
		gender_blocked.skills.learned_progress(SkillIdsScript.STORMDANCE),
		0,
		"gender rejection does not improve skill",
	)

	var equipment_blocked: CharacterStateScript = _mapped_practice_character(
		SkillIdsScript.UNARMED,
		SkillIdsScript.BLOODY_STRIKE,
		50,
		20,
	)
	var blocking_weapon: EquippedWeaponRefScript = EquippedWeaponRefScript.new(
		&"weapon:practice_blocker",
		WeaponDefinitionScript.new(
			&"definition:practice_blocker",
			SkillIdsScript.SWORD,
		),
	)
	equipment_blocked.equipment.wield(blocking_weapon, false)
	var equipment_hook: ObservingPracticePolicyScript = ObservingPracticePolicyScript.new(
		SkillIdsScript.BLOODY_STRIKE,
		true,
	)
	var equipment_result: PracticeResultScript = PracticeServiceScript.practice(
		equipment_blocked,
		SkillIdsScript.UNARMED,
		equipment_hook,
		_learn_policy(SkillIdsScript.BLOODY_STRIKE),
		false,
	)
	_assert_failure(
		equipment_result,
		PracticeResultScript.FailureReason.VALID_LEARN_REJECTED,
		"practice shared equipment valid_learn",
	)
	_assert_eq(
		equipment_result.skill_learn_policy_result.reason,
		SkillLearnPolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"practice keeps authored equipment rejection",
	)
	_assert_eq(equipment_hook.practice_call_count, 0, "equipment rejection precedes practice_skill")
	_assert_eq(
		equipment_blocked.skills.learned_progress(SkillIdsScript.BLOODY_STRIKE),
		0,
		"equipment rejection does not improve skill",
	)

	equipment_blocked.equipment.unwield(blocking_weapon.instance_id)
	var allowed_result: PracticeResultScript = PracticeServiceScript.practice(
		equipment_blocked,
		SkillIdsScript.UNARMED,
		equipment_hook,
		_learn_policy(SkillIdsScript.BLOODY_STRIKE),
		false,
	)
	_assert_true(allowed_result.success, "allowed shared valid_learn reaches practice_skill")
	_assert_eq(equipment_hook.practice_call_count, 1, "allowed path invokes practice_skill once")
	_assert_eq(
		allowed_result.skill_learn_policy_result.status,
		SkillLearnPolicyResultScript.Status.ALLOWED,
		"allowed practice exposes shared valid_learn result",
	)

	var hook_rejected: CharacterStateScript = _mapped_practice_character(
		SkillIdsScript.UNARMED,
		SkillIdsScript.BLOODY_STRIKE,
		50,
		20,
	)
	var rejecting_hook: ObservingPracticePolicyScript = ObservingPracticePolicyScript.new(
		SkillIdsScript.BLOODY_STRIKE,
		false,
	)
	var hook_result: PracticeResultScript = PracticeServiceScript.practice(
		hook_rejected,
		SkillIdsScript.UNARMED,
		rejecting_hook,
		_learn_policy(SkillIdsScript.BLOODY_STRIKE),
		false,
	)
	_assert_failure(
		hook_result,
		PracticeResultScript.FailureReason.PRACTICE_HOOK_REJECTED,
		"practice_skill remains separate after allowed valid_learn",
	)
	_assert_eq(rejecting_hook.practice_call_count, 1, "practice_skill rejection hook invoked once")
	_assert_eq(
		hook_result.skill_learn_policy_result.status,
		SkillLearnPolicyResultScript.Status.ALLOWED,
		"practice_skill rejection follows allowed valid_learn",
	)
	_assert_eq(
		hook_rejected.skills.learned_progress(SkillIdsScript.BLOODY_STRIKE),
		0,
		"practice_skill rejection does not improve skill",
	)


func _test_practice_resource_boundaries() -> void:
	var low_vitality: CharacterStateScript = _practice_character(50, 20)
	low_vitality.vitality.current = 29
	var vitality_failure: PracticeResultScript = PracticeServiceScript.practice(
		low_vitality,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(
		vitality_failure,
		PracticeResultScript.FailureReason.PRACTICE_HOOK_REJECTED,
		"fall-steps one below kee requirement",
	)
	_assert_practice_resources(low_vitality, 29, 10, "low kee no mutation")

	var low_force: CharacterStateScript = _practice_character(50, 20)
	low_force.vitality.current = 30
	low_force.recovery.inner_force.current = 2
	var force_failure: PracticeResultScript = PracticeServiceScript.practice(
		low_force,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(
		force_failure,
		PracticeResultScript.FailureReason.PRACTICE_HOOK_REJECTED,
		"fall-steps one below force requirement",
	)
	_assert_practice_resources(low_force, 30, 2, "low force no mutation")

	var exact: CharacterStateScript = _practice_character(50, 20)
	exact.vitality.current = 30
	exact.recovery.inner_force.current = 3
	var exact_result: PracticeResultScript = PracticeServiceScript.practice(
		exact,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_true(exact_result.success, "fall-steps exact resources succeed")
	_assert_practice_resources(exact, 0, 0, "fall-steps exact resources consumed")


func _test_practice_no_progress_policy() -> void:
	var character: CharacterStateScript = _base_character()
	character.skills.set_raw_level(SkillIdsScript.FORCE, 20)
	character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 20)
	character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	var result: PracticeResultScript = PracticeServiceScript.practice(
		character,
		SkillIdsScript.FORCE,
		PracticePoliciesScript.create_fonxan_force(),
		_learn_policy(SkillIdsScript.FONXAN_FORCE),
		false,
	)
	_assert_failure(
		result,
		PracticeResultScript.FailureReason.PRACTICE_HOOK_REJECTED,
		"fonxanforce practice always rejects",
	)
	_assert_eq(result.completion, PracticeResultScript.Completion.NO_PROGRESS, "practice no progress")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.FONXAN_FORCE), 0, "rejected no learned")


func _test_practice_improvement_integer_division_boundaries() -> void:
	var cases: Array[Array] = [
		[4, 1],
		[5, 2],
		[6, 2],
	]
	for values: Array in cases:
		var basic_level: int = int(values[0])
		var expected_amount: int = int(values[1])
		var character: CharacterStateScript = _practice_character(basic_level, 1)
		var result: PracticeResultScript = PracticeServiceScript.practice(
			character,
			SkillIdsScript.DODGE,
			PracticePoliciesScript.create_fall_steps(),
			_learn_policy(SkillIdsScript.FALL_STEPS),
			false,
		)
		## practice.c: amount is raw basic / 5 + 1 with integer division.
		_assert_eq(
			result.improvement_amount,
			expected_amount,
			"practice raw basic / 5 boundary " + str(basic_level),
		)


func _test_practice_exact_level_threshold_and_level_up() -> void:
	var below: CharacterStateScript = _practice_character(10, 1)
	var below_result: PracticeResultScript = PracticeServiceScript.practice(
		below,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	## amount 3 leaves learned at 3, one below (1 + 1)^2 == 4.
	_assert_eq(below_result.completion, PracticeResultScript.Completion.PROGRESSED, "below threshold")
	_assert_eq(below.skills.raw_level(SkillIdsScript.FALL_STEPS), 1, "below threshold raw")
	_assert_eq(below.skills.learned_progress(SkillIdsScript.FALL_STEPS), 3, "below threshold learned")

	var exact: CharacterStateScript = _practice_character(10, 1)
	exact.skills.set_learned_progress(SkillIdsScript.FALL_STEPS, 1)
	var exact_result: PracticeResultScript = PracticeServiceScript.practice(
		exact,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	## amount 10 / 5 + 1 = 3; learned 1 + 3 == (1 + 1)^2 == 4.
	_assert_eq(exact_result.improvement_amount, 3, "practice exact threshold amount")
	_assert_eq(exact_result.completion, PracticeResultScript.Completion.PROGRESSED, "threshold equality no level")
	_assert_eq(exact.skills.raw_level(SkillIdsScript.FALL_STEPS), 1, "exact threshold raw unchanged")
	_assert_eq(exact.skills.learned_progress(SkillIdsScript.FALL_STEPS), 4, "exact threshold learned kept")

	var level_up: CharacterStateScript = _practice_character(10, 1)
	level_up.skills.set_learned_progress(SkillIdsScript.FALL_STEPS, 2)
	var level_result: PracticeResultScript = PracticeServiceScript.practice(
		level_up,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_eq(level_result.completion, PracticeResultScript.Completion.LEVEL_INCREASED, "practice levels")
	_assert_eq(level_up.skills.raw_level(SkillIdsScript.FALL_STEPS), 2, "practice one level")
	_assert_eq(level_up.skills.learned_progress(SkillIdsScript.FALL_STEPS), 0, "practice level clears learned")
	_assert_practice_resources(level_up, 70, 7, "policy mutation precedes improvement")


func _test_practice_weak_player_semantics() -> void:
	var character: CharacterStateScript = _practice_character(20, 20)
	character.skills.set_learned_progress(SkillIdsScript.FALL_STEPS, 440)
	var result: PracticeResultScript = PracticeServiceScript.practice(
		character,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
		true,
	)
	## basic <= special passes weak_mode=1; player learned grows but cannot level.
	_assert_true(result.weak_mode, "practice weak mode at equality")
	_assert_eq(result.improvement_amount, 5, "weak practice amount")
	_assert_eq(character.skills.raw_level(SkillIdsScript.FALL_STEPS), 20, "weak player no level")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.FALL_STEPS), 445, "weak player learned grows")


func _test_practice_policy_and_state_isolation() -> void:
	var first_policy: VitalityInnerForcePracticePolicyScript = (
		PracticePoliciesScript.create_fall_steps()
	)
	var second_policy: VitalityInnerForcePracticePolicyScript = (
		PracticePoliciesScript.create_fall_steps()
	)
	first_policy.required_vitality = 99
	_assert_eq(second_policy.required_vitality, 30, "practice policies independent")
	_assert_eq(first_policy.skill_id, SkillIdsScript.FALL_STEPS, "policy lookup stable ID")
	_assert_false(
		_has_property(second_policy, &"minimum_maximum_inner_force"),
		"practice_skill policy does not duplicate valid_learn max_force",
	)
	_assert_eq(second_policy.vitality_cost, 30, "policy lookup stable kee cost")
	_assert_eq(second_policy.inner_force_cost, 3, "policy lookup stable force cost")

	var first: CharacterStateScript = _practice_character(50, 20)
	var second: CharacterStateScript = _practice_character(50, 20)
	var first_result: PracticeResultScript = PracticeServiceScript.practice(
		first,
		SkillIdsScript.DODGE,
		second_policy,
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_practice_resources(second, 100, 10, "second practice state unchanged")
	var second_result: PracticeResultScript = PracticeServiceScript.practice(
		second,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_true(first_result != second_result, "practice results independent")

	var mismatch: PracticeResultScript = PracticeServiceScript.practice(
		_practice_character(50, 20),
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fonxan_force(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_failure(
		mismatch,
		PracticeResultScript.FailureReason.POLICY_SKILL_MISMATCH,
		"policy cannot dispatch another skill",
	)

	var validation_failure: CharacterStateScript = _practice_character(50, 20)
	validation_failure.recovery.inner_force.maximum = 49
	var before_failure: Array[Variant] = _training_state_snapshot(validation_failure)
	PracticeServiceScript.practice(
		validation_failure,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		_learn_policy(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_eq(
		_training_state_snapshot(validation_failure),
		before_failure,
		"practice validation failure leaves complete training state untouched",
	)


func _test_self_learning_normal_attempt() -> void:
	var character: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		character,
		SkillIdsScript.SWORD,
		false,
		5,
	)
	## selflearn.c: gin cost 300 / base int 10 = 30; required exp 40^3 / 10 = 6400.
	_assert_true(result.success, "selflearn normal success")
	_assert_eq(result.completion, SelfLearningResultScript.Completion.PROGRESSED, "selflearn progressed")
	_assert_eq(result.essence_cost, 30, "selflearn base intelligence cost")
	_assert_eq(result.improvement_roll_upper_bound, 50, "selflearn random bound")
	_assert_eq(character.essence.current, 70, "selflearn spends gin after progress")
	_assert_eq(character.progression.potential_spent, 1, "selflearn spends one potential point")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.SWORD), 5, "selflearn roll improves skill")


func _test_self_learning_skill_and_combat_validation_order() -> void:
	var invalid: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var invalid_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		invalid,
		SkillIdsScript.MAGIC,
		true,
		0,
	)
	_assert_self_failure(
		invalid_result,
		SelfLearningResultScript.FailureReason.SKILL_NOT_SELF_LEARNABLE,
		"selflearn whitelist before combat",
	)

	var fighting_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		invalid,
		SkillIdsScript.SWORD,
		true,
		0,
	)
	_assert_self_failure(fighting_result, SelfLearningResultScript.FailureReason.IN_COMBAT, "selflearn combat")

	var allowed_ids: Array[StringName] = [
		SkillIdsScript.DODGE,
		SkillIdsScript.FORCE,
		SkillIdsScript.SWORD,
		SkillIdsScript.BLADE,
		SkillIdsScript.STAFF,
		SkillIdsScript.PARRY,
		SkillIdsScript.UNARMED,
	]
	for skill_id: StringName in allowed_ids:
		var character: CharacterStateScript = _base_character()
		var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
			character,
			skill_id,
			false,
			0,
		)
		_assert_eq(
			result.failure_reason,
			SelfLearningResultScript.FailureReason.RAW_SKILL_BELOW_MINIMUM,
			"selflearn allowed basic ID " + str(skill_id),
		)


func _test_self_learning_prerequisites() -> void:
	var low_skill: CharacterStateScript = _self_learning_character(39, 100, 6_400)
	_assert_self_failure(
		SelfLearningServiceScript.self_learn(low_skill, SkillIdsScript.SWORD, false, 0),
		SelfLearningResultScript.FailureReason.RAW_SKILL_BELOW_MINIMUM,
		"selflearn raw level one below 40",
	)

	var zero_intelligence: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	zero_intelligence.attributes.intelligence = 0
	_assert_self_failure(
		SelfLearningServiceScript.self_learn(zero_intelligence, SkillIdsScript.SWORD, false, 0),
		SelfLearningResultScript.FailureReason.LEGACY_NON_POSITIVE_INTELLIGENCE,
		"selflearn zero intelligence divisor",
	)
	_assert_self_unchanged(zero_intelligence, 100, 0, 0, "zero intelligence no mutation")

	var negative_intelligence: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	negative_intelligence.attributes.intelligence = -1
	_assert_self_failure(
		SelfLearningServiceScript.self_learn(negative_intelligence, SkillIdsScript.SWORD, false, 0),
		SelfLearningResultScript.FailureReason.LEGACY_NON_POSITIVE_INTELLIGENCE,
		"selflearn negative legacy cost",
	)

	var exhausted: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	exhausted.progression.potential = 5
	exhausted.progression.potential_spent = 5
	_assert_self_failure(
		SelfLearningServiceScript.self_learn(exhausted, SkillIdsScript.SWORD, false, 0),
		SelfLearningResultScript.FailureReason.POTENTIAL_EXHAUSTED,
		"selflearn potential equality blocks",
	)
	_assert_self_unchanged(exhausted, 100, 5, 0, "potential failure no mutation")

	var one_potential_left: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	one_potential_left.progression.potential = 5
	one_potential_left.progression.potential_spent = 4
	var one_left_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		one_potential_left,
		SkillIdsScript.SWORD,
		false,
		1,
	)
	_assert_true(one_left_result.success, "selflearn one potential point remaining succeeds")
	_assert_eq(one_potential_left.progression.potential_spent, 5, "selflearn spends final potential")


func _test_self_learning_uses_raw_skill_for_prerequisite() -> void:
	var character: CharacterStateScript = _self_learning_character(39, 100, 6_400)
	character.skills.set_raw_level(SkillIdsScript.FONXAN_SWORD, 100)
	character.skills.map_skill(SkillIdsScript.SWORD, SkillIdsScript.FONXAN_SWORD)
	## feature/skill.c: effective sword is 39 / 2 + mapped 100 == 119,
	## while selflearn.c explicitly queries query_skill("sword", 1) == 39.
	_assert_eq(character.skills.effective_level(SkillIdsScript.SWORD), 119, "effective skill evidence")
	var before: Array[Variant] = _training_state_snapshot(character)
	var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		character,
		SkillIdsScript.SWORD,
		false,
		0,
	)
	_assert_self_failure(
		result,
		SelfLearningResultScript.FailureReason.RAW_SKILL_BELOW_MINIMUM,
		"selflearn does not substitute effective skill for raw skill",
	)
	_assert_eq(
		_training_state_snapshot(character),
		before,
		"raw prerequisite failure leaves complete training state untouched",
	)


func _test_self_learning_essence_boundaries() -> void:
	for starting_essence: int in [29, 30]:
		var character: CharacterStateScript = _self_learning_character(40, starting_essence, 6_400)
		var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
			character,
			SkillIdsScript.SWORD,
			false,
			5,
		)
		_assert_eq(
			result.completion,
			SelfLearningResultScript.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE,
			"selflearn gin at or below cost has no progress",
		)
		_assert_eq(result.essence_spent, starting_essence, "selflearn spends all remaining gin")
		_assert_self_unchanged(character, 0, 0, 0, "insufficient gin no progression")

	var one_above: CharacterStateScript = _self_learning_character(40, 31, 6_400)
	var success: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		one_above,
		SkillIdsScript.SWORD,
		false,
		5,
	)
	_assert_eq(success.completion, SelfLearningResultScript.Completion.PROGRESSED, "gin one above cost")
	_assert_self_unchanged(one_above, 1, 1, 5, "gin one above permits progress")


func _test_self_learning_combat_experience_boundaries() -> void:
	var below: CharacterStateScript = _self_learning_character(40, 100, 6_399)
	var no_progress: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		below,
		SkillIdsScript.SWORD,
		false,
		5,
	)
	_assert_eq(
		no_progress.completion,
		SelfLearningResultScript.Completion.NO_PROGRESS_COMBAT_EXPERIENCE,
		"combat experience one below requirement",
	)
	_assert_self_unchanged(below, 70, 0, 0, "combat no progress still spends gin")

	var exact: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var progress: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		exact,
		SkillIdsScript.SWORD,
		false,
		5,
	)
	_assert_eq(progress.completion, SelfLearningResultScript.Completion.PROGRESSED, "combat equality passes")


func _test_self_learning_cost_integer_division_boundaries() -> void:
	var cases: Array[Array] = [
		[7, 42],
		[8, 37],
	]
	for values: Array in cases:
		var intelligence: int = int(values[0])
		var expected_cost: int = int(values[1])
		var character: CharacterStateScript = _self_learning_character(40, 100, 6_400)
		character.attributes.intelligence = intelligence
		var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
			character,
			SkillIdsScript.SWORD,
			false,
			1,
		)
		## selflearn.c: gin_cost = 300 / base int, truncated as integer division.
		_assert_eq(result.essence_cost, expected_cost, "selflearn 300 / int boundary " + str(intelligence))
		_assert_eq(character.essence.current, 100 - expected_cost, "selflearn truncated gin spend")

	var minimum_positive: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	_set_primary(minimum_positive.essence, 301, 301)
	minimum_positive.attributes.intelligence = 1
	var minimum_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		minimum_positive,
		SkillIdsScript.SWORD,
		false,
		0,
	)
	_assert_true(minimum_result.success, "selflearn base int one is valid")
	_assert_eq(minimum_result.essence_cost, 300, "selflearn base int one cost")
	_assert_eq(minimum_positive.essence.current, 1, "selflearn base int one strict gin threshold")


func _test_self_learning_roll_boundaries() -> void:
	var zero_roll: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var zero_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		zero_roll,
		SkillIdsScript.SWORD,
		false,
		0,
	)
	_assert_eq(zero_result.improvement_roll_upper_bound, 50, "selflearn roll bound int plus level")
	_assert_eq(zero_roll.skills.learned_progress(SkillIdsScript.SWORD), 1, "zero roll becomes one in improve_skill")

	var upper_roll: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	SelfLearningServiceScript.self_learn(upper_roll, SkillIdsScript.SWORD, false, 49)
	_assert_eq(upper_roll.skills.learned_progress(SkillIdsScript.SWORD), 49, "roll upper minus one accepted")

	var invalid_roll: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var before_invalid: Array[Variant] = _training_state_snapshot(invalid_roll)
	var invalid_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		invalid_roll,
		SkillIdsScript.SWORD,
		false,
		50,
	)
	_assert_self_failure(
		invalid_result,
		SelfLearningResultScript.FailureReason.INVALID_IMPROVEMENT_ROLL,
		"impossible injected random result",
	)
	_assert_self_unchanged(invalid_roll, 100, 0, 0, "invalid roll no mutation")
	_assert_eq(
		_training_state_snapshot(invalid_roll),
		before_invalid,
		"late selflearn validation failure leaves complete training state untouched",
	)


func _test_self_learning_exact_level_threshold_and_level_up() -> void:
	var below: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	below.skills.set_learned_progress(SkillIdsScript.SWORD, 1_679)
	var below_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		below,
		SkillIdsScript.SWORD,
		false,
		1,
	)
	## 1679 + 1 == 1680, one below (40 + 1)^2 == 1681.
	_assert_eq(below_result.completion, SelfLearningResultScript.Completion.PROGRESSED, "selflearn below threshold")
	_assert_eq(below.skills.raw_level(SkillIdsScript.SWORD), 40, "selflearn below threshold raw")
	_assert_eq(below.skills.learned_progress(SkillIdsScript.SWORD), 1_680, "selflearn below threshold learned")

	var exact: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	exact.skills.set_learned_progress(SkillIdsScript.SWORD, 1_680)
	var exact_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		exact,
		SkillIdsScript.SWORD,
		false,
		1,
	)
	## 1680 + 1 == (40 + 1)^2; improve_skill requires strict greater-than.
	_assert_eq(exact_result.completion, SelfLearningResultScript.Completion.PROGRESSED, "selflearn threshold equality")
	_assert_eq(exact.skills.raw_level(SkillIdsScript.SWORD), 40, "selflearn equality no level")
	_assert_eq(exact.skills.learned_progress(SkillIdsScript.SWORD), 1_681, "selflearn equality learned")

	var level_up: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	level_up.skills.set_learned_progress(SkillIdsScript.SWORD, 1_681)
	var level_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		level_up,
		SkillIdsScript.SWORD,
		false,
		1,
	)
	_assert_eq(level_result.completion, SelfLearningResultScript.Completion.LEVEL_INCREASED, "selflearn level up")
	_assert_eq(level_up.skills.raw_level(SkillIdsScript.SWORD), 41, "selflearn exactly one level")
	_assert_eq(level_up.skills.learned_progress(SkillIdsScript.SWORD), 0, "selflearn level clears learned")
	_assert_eq(level_up.progression.potential_spent, 1, "potential spent before improvement")
	_assert_eq(level_up.essence.current, 70, "gin spent after improvement")


func _test_self_learning_zero_cost_integer_division() -> void:
	var character: CharacterStateScript = _self_learning_character(40, 1, 6_400)
	character.attributes.intelligence = 301
	var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		character,
		SkillIdsScript.SWORD,
		false,
		1,
	)
	_assert_true(result.success, "selflearn zero cost succeeds with positive gin")
	_assert_eq(result.essence_cost, 0, "300 / 301 truncates to zero")
	_assert_eq(character.essence.current, 1, "zero gin cost changes no gin")
	_assert_eq(character.progression.potential_spent, 1, "zero cost still spends potential")


func _test_self_learning_state_and_result_isolation() -> void:
	var first: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var second: CharacterStateScript = _self_learning_character(40, 100, 6_400)
	var first_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		first,
		SkillIdsScript.SWORD,
		false,
		5,
	)
	_assert_self_unchanged(second, 100, 0, 0, "second selflearn state unchanged")
	var second_result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		second,
		SkillIdsScript.SWORD,
		false,
		5,
	)
	_assert_true(first_result != second_result, "selflearn results independent")


func _base_character() -> CharacterStateScript:
	var character: CharacterStateScript = CharacterStateScript.new()
	_set_primary(character.essence, 100)
	_set_primary(character.vitality, 100)
	_set_primary(character.spirit, 100)
	character.attributes.intelligence = 10
	character.attributes.spirituality = 10
	character.progression.potential = 100
	return character


func _practice_character(basic_level: int, special_level: int) -> CharacterStateScript:
	var character: CharacterStateScript = _mapped_practice_character(
		SkillIdsScript.DODGE,
		SkillIdsScript.FALL_STEPS,
		basic_level,
		special_level,
	)
	character.recovery.inner_force.current = 10
	character.recovery.inner_force.maximum = 50
	return character


func _mapped_practice_character(
	basic_skill_id: StringName,
	special_skill_id: StringName,
	basic_level: int,
	special_level: int,
) -> CharacterStateScript:
	var character: CharacterStateScript = _base_character()
	character.skills.set_raw_level(basic_skill_id, basic_level)
	character.skills.set_raw_level(special_skill_id, special_level)
	character.skills.map_skill(basic_skill_id, special_skill_id)
	return character


func _learn_policy(skill_id: StringName) -> SkillLearnPolicyScript:
	var registry: SkillLearnPolicyRegistryScript = SkillLearnPolicyRegistryScript.new()
	registry.register_known_legacy_policies()
	return registry.policy_for(skill_id)


func _self_learning_character(
	level: int,
	essence: int,
	combat_experience: int,
) -> CharacterStateScript:
	var character: CharacterStateScript = _base_character()
	character.skills.set_raw_level(SkillIdsScript.SWORD, level)
	character.essence.current = essence
	character.progression.combat_experience = combat_experience
	return character


func _set_primary(
	resource: CharacterResourceStateScript,
	value: int,
	maximum: int = 100,
) -> void:
	resource.maximum = maximum
	resource.effective = maximum
	resource.current = value


func _training_state_snapshot(character: CharacterStateScript) -> Array[Variant]:
	var snapshot: Array[Variant] = [
		character.attributes.strength,
		character.attributes.courage,
		character.attributes.intelligence,
		character.attributes.spirituality,
		character.attributes.composure,
		character.attributes.personality,
		character.attributes.constitution,
		character.attributes.karma,
		character.essence.current,
		character.essence.effective,
		character.essence.maximum,
		character.vitality.current,
		character.vitality.effective,
		character.vitality.maximum,
		character.spirit.current,
		character.spirit.effective,
		character.spirit.maximum,
		character.recovery.inner_force.current,
		character.recovery.inner_force.maximum,
		character.recovery.mana.current,
		character.recovery.mana.maximum,
		character.recovery.atman.current,
		character.recovery.atman.maximum,
		character.recovery.food,
		character.recovery.water,
		character.progression.combat_experience,
		character.progression.potential,
		character.progression.potential_spent,
		character.conditions.sorted_condition_ids(),
	]
	var skill_ids: Array[StringName] = [
		SkillIdsScript.DODGE,
		SkillIdsScript.FORCE,
		SkillIdsScript.SWORD,
		SkillIdsScript.FALL_STEPS,
		SkillIdsScript.FONXAN_FORCE,
		SkillIdsScript.FONXAN_SWORD,
	]
	for skill_id: StringName in skill_ids:
		snapshot.append(character.skills.has_raw_level(skill_id))
		snapshot.append(character.skills.raw_level(skill_id))
		snapshot.append(character.skills.learned_progress(skill_id))
		snapshot.append(character.skills.mapped_skill(skill_id))
	return snapshot


func _assert_failure(result: PracticeResultScript, expected_reason: int, label: String) -> void:
	_assert_false(result.success, label + " success")
	_assert_eq(result.failure_reason, expected_reason, label + " reason")


func _assert_self_failure(
	result: SelfLearningResultScript,
	expected_reason: int,
	label: String,
) -> void:
	_assert_false(result.success, label + " success")
	_assert_eq(result.failure_reason, expected_reason, label + " reason")
	_assert_eq(result.essence_spent, 0, label + " essence spent")


func _assert_practice_resources(
	character: CharacterStateScript,
	expected_vitality: int,
	expected_force: int,
	label: String,
) -> void:
	_assert_eq(character.vitality.current, expected_vitality, label + " vitality")
	_assert_eq(character.recovery.inner_force.current, expected_force, label + " force")


func _assert_self_unchanged(
	character: CharacterStateScript,
	expected_essence: int,
	expected_potential_spent: int,
	expected_learned: int,
	label: String,
) -> void:
	_assert_eq(character.essence.current, expected_essence, label + " essence")
	_assert_eq(character.progression.potential_spent, expected_potential_spent, label + " potential")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.SWORD), expected_learned, label + " learned")


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


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false
