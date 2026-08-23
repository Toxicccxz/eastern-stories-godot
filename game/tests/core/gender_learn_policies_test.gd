extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const PolicyResultScript := preload("res://core/learning/skill_learn_policy_result.gd")
const RequiredGenderPolicyScript := preload(
	"res://core/learning/required_gender_skill_learn_policy.gd"
)
const RegistryScript := preload("res://core/learning/skill_learn_policy_registry.gd")
const DefaultPolicyScript := preload("res://core/learning/default_skill_learn_policy.gd")
const TeachingOfferScript := preload("res://core/learning/teaching_offer.gd")
const TeachingContextScript := preload("res://core/learning/teaching_context.gd")
const TeacherRecognitionPolicyScript := preload(
	"res://core/learning/teacher_recognition_policy.gd"
)
const TeacherPreventionPolicyScript := preload(
	"res://core/learning/teacher_prevention_policy.gd"
)
const SkillDefinitionScript := preload("res://core/skills/skill_definition.gd")
const LearnResultScript := preload("res://core/learning/learn_result.gd")
const LearnServiceScript := preload("res://core/learning/learn_service.gd")
const SkillImprovementEffectResultScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)
const FamilyStateScript := preload("res://core/relationships/family_state.gd")
const ApprenticeshipStateScript := preload(
	"res://core/relationships/apprenticeship_state.gd"
)
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const EquipmentTransitionResultScript := preload(
	"res://core/equipment/equipment_transition_result.gd"
)

const TEACHER_ID: StringName = &"teacher.phase_4a4"
const FAMILY_ID: StringName = &"family.phase_4a4"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_character_gender_fact()
	_test_exact_gender_policy()
	_test_stormdance_order_and_boundaries()
	_test_tenderzhi_order_and_hand_states()
	_test_registry_inventory()
	_test_learn_success_paths()
	_test_learn_rejections_precede_mutation()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_character_gender_fact() -> void:
	var default_state: CharacterStateScript = CharacterStateScript.new()
	_assert_eq(default_state.gender, &"", "default gender is unresolved")
	_assert_eq(CharacterStateScript.GENDER_MALE, &"男性", "canonical human male")
	_assert_eq(CharacterStateScript.GENDER_FEMALE, &"女性", "canonical human female")
	_assert_eq(CharacterStateScript.GENDER_ANIMAL_MALE, &"雄性", "canonical animal male")
	_assert_eq(CharacterStateScript.GENDER_ANIMAL_FEMALE, &"雌性", "canonical animal female")

	var values: Array[StringName] = [
		CharacterStateScript.GENDER_MALE,
		CharacterStateScript.GENDER_FEMALE,
		CharacterStateScript.GENDER_ANIMAL_MALE,
		CharacterStateScript.GENDER_ANIMAL_FEMALE,
		&"custom-legacy-gender",
		&"malformed legacy value",
	]
	for value: StringName in values:
		var state: CharacterStateScript = CharacterStateScript.new()
		state.gender = value
		_assert_eq(state.gender, value, "gender preserves exact value '%s'" % value)

	var first: CharacterStateScript = CharacterStateScript.new()
	var second: CharacterStateScript = CharacterStateScript.new()
	first.gender = CharacterStateScript.GENDER_FEMALE
	second.gender = CharacterStateScript.GENDER_MALE
	first.gender = &"changed-custom"
	_assert_eq(first.gender, &"changed-custom", "first character keeps its scalar mutation")
	_assert_eq(second.gender, CharacterStateScript.GENDER_MALE, "characters do not share gender")


func _test_exact_gender_policy() -> void:
	var policy: RequiredGenderPolicyScript = RequiredGenderPolicyScript.new(
		SkillIdsScript.STORMDANCE,
		CharacterStateScript.GENDER_FEMALE,
	)
	var cases: Array[Array] = [
		[CharacterStateScript.GENDER_FEMALE, PolicyResultScript.Status.ALLOWED],
		[CharacterStateScript.GENDER_MALE, PolicyResultScript.Status.REJECTED],
		[CharacterStateScript.GENDER_ANIMAL_FEMALE, PolicyResultScript.Status.REJECTED],
		[CharacterStateScript.GENDER_ANIMAL_MALE, PolicyResultScript.Status.REJECTED],
		[&"", PolicyResultScript.Status.REJECTED],
		[&"custom-legacy-gender", PolicyResultScript.Status.REJECTED],
		[&"malformed legacy value", PolicyResultScript.Status.REJECTED],
	]
	for case: Array in cases:
		var state: CharacterStateScript = CharacterStateScript.new()
		state.gender = case[0]
		var result: PolicyResultScript = policy.evaluate(state)
		_assert_eq(result.status, case[1], "exact female policy for '%s'" % state.gender)
		if result.status == PolicyResultScript.Status.REJECTED:
			_assert_eq(result.reason, PolicyResultScript.Reason.GENDER_MISMATCH, "gender mismatch reason")
			_assert_eq(result.actual_id, state.gender, "gender mismatch preserves actual value")
			_assert_eq(
				result.required_id,
				CharacterStateScript.GENDER_FEMALE,
				"gender mismatch preserves required value",
			)


func _test_stormdance_order_and_boundaries() -> void:
	var registry: RegistryScript = _registry()
	for spirituality: int in [19, 20, 21]:
		var female: CharacterStateScript = CharacterStateScript.new()
		female.gender = CharacterStateScript.GENDER_FEMALE
		female.attributes.spirituality = spirituality
		var result: PolicyResultScript = _evaluate(registry, SkillIdsScript.STORMDANCE, female)
		_assert_eq(
			result.status,
			PolicyResultScript.Status.REJECTED if spirituality < 20 else PolicyResultScript.Status.ALLOWED,
			"stormdance female base spi %d status" % spirituality,
		)
		_assert_eq(
			result.reason,
			PolicyResultScript.Reason.BASE_SPIRITUALITY_TOO_LOW if spirituality < 20 else PolicyResultScript.Reason.NONE,
			"stormdance female base spi %d reason" % spirituality,
		)

	var modified: CharacterStateScript = CharacterStateScript.new()
	modified.gender = CharacterStateScript.GENDER_FEMALE
	modified.attributes.spirituality = 19
	modified.attributes.spirituality_modifier = 100
	_assert_reason(
		registry,
		SkillIdsScript.STORMDANCE,
		modified,
		PolicyResultScript.Reason.BASE_SPIRITUALITY_TOO_LOW,
		"stormdance ignores effective spirituality modifier",
	)

	var rejected_values: Array[StringName] = [
		CharacterStateScript.GENDER_MALE,
		CharacterStateScript.GENDER_ANIMAL_FEMALE,
		CharacterStateScript.GENDER_ANIMAL_MALE,
		&"",
		&"custom-legacy-gender",
	]
	for gender: StringName in rejected_values:
		var student: CharacterStateScript = CharacterStateScript.new()
		student.gender = gender
		student.attributes.spirituality = 100
		_assert_reason(
			registry,
			SkillIdsScript.STORMDANCE,
			student,
			PolicyResultScript.Reason.GENDER_MISMATCH,
			"stormdance rejects exact non-female value '%s'" % gender,
		)

	var both_invalid: CharacterStateScript = CharacterStateScript.new()
	both_invalid.gender = CharacterStateScript.GENDER_MALE
	both_invalid.attributes.spirituality = 0
	_assert_reason(
		registry,
		SkillIdsScript.STORMDANCE,
		both_invalid,
		PolicyResultScript.Reason.GENDER_MISMATCH,
		"stormdance gender failure precedes spirituality",
	)


func _test_tenderzhi_order_and_hand_states() -> void:
	var registry: RegistryScript = _registry()
	var empty: CharacterStateScript = _female_student()
	_assert_allowed(registry, SkillIdsScript.TENDERZHI, empty, "tenderzhi female both empty")

	var primary: CharacterStateScript = _female_student()
	_equip_primary(primary, &"primary")
	_assert_reason(
		registry,
		SkillIdsScript.TENDERZHI,
		primary,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"tenderzhi female primary occupied",
	)

	var secondary_only: CharacterStateScript = _female_student()
	_equip_secondary_only(secondary_only)
	_assert_reason(
		registry,
		SkillIdsScript.TENDERZHI,
		secondary_only,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"tenderzhi female secondary-only occupied",
	)

	var both: CharacterStateScript = _female_student()
	_equip_both(both)
	_assert_reason(
		registry,
		SkillIdsScript.TENDERZHI,
		both,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"tenderzhi female both occupied",
	)

	var rejected_values: Array[StringName] = [
		CharacterStateScript.GENDER_MALE,
		&"",
		CharacterStateScript.GENDER_ANIMAL_FEMALE,
		&"custom-legacy-gender",
	]
	for gender: StringName in rejected_values:
		var student: CharacterStateScript = CharacterStateScript.new()
		student.gender = gender
		_assert_reason(
			registry,
			SkillIdsScript.TENDERZHI,
			student,
			PolicyResultScript.Reason.GENDER_MISMATCH,
			"tenderzhi rejects exact value '%s'" % gender,
		)

	var armed_male: CharacterStateScript = CharacterStateScript.new()
	armed_male.gender = CharacterStateScript.GENDER_MALE
	_equip_primary(armed_male, &"male-primary")
	_assert_reason(
		registry,
		SkillIdsScript.TENDERZHI,
		armed_male,
		PolicyResultScript.Reason.GENDER_MISMATCH,
		"tenderzhi gender failure precedes weapon failure",
	)


func _test_registry_inventory() -> void:
	var active: RegistryScript = RegistryScript.new()
	active.register_active_legacy_policies()
	_assert_eq(active.registered_count(), 45, "45 explicit valid_learn hooks")
	var explicit_ids: Array[StringName] = [
		SkillIdsScript.BLOODY_STRIKE,
		SkillIdsScript.BOLOMIDUO,
		SkillIdsScript.BUDDHISM,
		SkillIdsScript.CELESTIAL,
		SkillIdsScript.CELESTRIKE,
		SkillIdsScript.CHAOS_STEPS,
		SkillIdsScript.CLOUDSTAFF,
		SkillIdsScript.DEISWORD,
		SkillIdsScript.ESSENCE_MAGIC,
		SkillIdsScript.FALL_STEPS,
		SkillIdsScript.FONXAN_FORCE,
		SkillIdsScript.FONXAN_SWORD,
		SkillIdsScript.FORCE,
		SkillIdsScript.GOUYEE,
		SkillIdsScript.ICEFORCE,
		SkillIdsScript.JIN_GANG,
		SkillIdsScript.JINGANG_STAFF,
		SkillIdsScript.JUECHEN_FORCE,
		SkillIdsScript.LINBO_STEPS,
		SkillIdsScript.LIUH_KEN,
		SkillIdsScript.LOTUSFORCE,
		SkillIdsScript.MAGIC_ARRAY,
		SkillIdsScript.MEIHUA_SHOU,
		SkillIdsScript.MYSTERRIER,
		SkillIdsScript.MYSTFORCE,
		SkillIdsScript.MYSTSWORD,
		SkillIdsScript.NECROMANCY,
		SkillIdsScript.NINE_MOON,
		SkillIdsScript.NOTRACES,
		SkillIdsScript.PYROBAT_STEPS,
		SkillIdsScript.QIDAOFORCE,
		SkillIdsScript.SCRATCHING,
		SkillIdsScript.SERPENTFORCE,
		SkillIdsScript.SHORTSONG_BLADE,
		SkillIdsScript.SIX_CHAOS_SWORD,
		SkillIdsScript.SNOWSHADE_FORCE,
		SkillIdsScript.SNOWSHADE_SWORD,
		SkillIdsScript.SNOWWHIP,
		SkillIdsScript.SPICYCLAW,
		SkillIdsScript.SPRING_BLADE,
		SkillIdsScript.STORMDANCE,
		SkillIdsScript.TAOISM,
		SkillIdsScript.TENDERZHI,
		SkillIdsScript.TS_FIST,
		SkillIdsScript.WU_SHUN,
	]
	_assert_eq(explicit_ids.size(), 45, "independent explicit hook inventory")
	var executable_count: int = 0
	var blocked_count: int = 0
	for skill_id: StringName in explicit_ids:
		var result: PolicyResultScript = active.policy_for(skill_id).evaluate(CharacterStateScript.new())
		if result.status == PolicyResultScript.Status.DEPENDENCY_UNAVAILABLE:
			blocked_count += 1
			_assert_eq(skill_id, SkillIdsScript.NINE_MOON, "only nine-moon remains blocked")
			_assert_eq(
				result.reason,
				PolicyResultScript.Reason.LEGACY_REQUIRED_SKILL_MISSING,
				"nine-moon retains missing skill reason",
			)
		else:
			executable_count += 1
	_assert_eq(executable_count, 44, "44 explicit hooks executable")
	_assert_eq(blocked_count, 1, "one explicit hook dependency-blocked")

	var known: RegistryScript = _registry()
	_assert_eq(known.registered_count(), 70, "70 known active skills")
	var inherited_ids: Array[StringName] = [
		SkillIdsScript.AXE,
		SkillIdsScript.BLADE,
		SkillIdsScript.CHANTING,
		SkillIdsScript.DAGGER,
		SkillIdsScript.DODGE,
		SkillIdsScript.FORK,
		SkillIdsScript.HAMMER,
		SkillIdsScript.INSTRUMENTS,
		SkillIdsScript.IRON_CLOTH,
		SkillIdsScript.LITERATE,
		SkillIdsScript.MAGIC,
		SkillIdsScript.MOVE,
		SkillIdsScript.MUSIC,
		SkillIdsScript.PARRY,
		SkillIdsScript.PERCEPTION,
		SkillIdsScript.SPELLS,
		SkillIdsScript.SPIDER_ARRAY,
		SkillIdsScript.STAFF,
		SkillIdsScript.STEALING,
		SkillIdsScript.SWORD,
		SkillIdsScript.TAO_MYSTERY,
		SkillIdsScript.THROWING,
		SkillIdsScript.UNARMED,
		SkillIdsScript.WHIP,
		SkillIdsScript.YIRONG,
	]
	_assert_eq(inherited_ids.size(), 25, "25 inherited std/skill defaults")
	for skill_id: StringName in inherited_ids:
		_assert_true(
			known.policy_for(skill_id).get_script() == DefaultPolicyScript,
			"%s keeps explicit inherited default" % skill_id,
		)
	_assert_eq(known.policy_for(&"unknown-phase-4a4"), null, "unknown ID remains unsupported")


func _test_learn_success_paths() -> void:
	var registry: RegistryScript = _registry()
	for skill_id: StringName in [SkillIdsScript.STORMDANCE, SkillIdsScript.TENDERZHI]:
		var student: CharacterStateScript = _learn_student(CharacterStateScript.GENDER_FEMALE, 20)
		## A roll of 2 takes a new raw-0 skill strictly above (0 + 1)^2,
		## proving the existing progression result and authored-effect registry path.
		var context: TeachingContextScript = _learn_context(skill_id, 2)
		var result: LearnResultScript = LearnServiceScript.learn(
			student,
			context,
			_skill_definition(skill_id),
			registry.policy_for(skill_id),
		)
		_assert_true(result.success, "%s Learn succeeds with exact facts" % skill_id)
		_assert_eq(
			result.skill_learn_policy_result.status,
			PolicyResultScript.Status.ALLOWED,
			"%s valid_learn allowed" % skill_id,
		)
		_assert_eq(student.progression.potential_spent, 1, "%s spends potential" % skill_id)
		_assert_eq(student.skills.raw_level(skill_id), 1, "%s reaches raw level one" % skill_id)
		_assert_eq(student.skills.learned_progress(skill_id), 0, "%s clears learned on level-up" % skill_id)
		_assert_true(result.skill_improvement != null, "%s returns improvement result" % skill_id)
		if result.skill_improvement != null:
			_assert_eq(result.skill_improvement.skill_id, skill_id, "%s improvement skill ID" % skill_id)
			_assert_eq(result.skill_improvement.previous_level, 0, "%s previous raw level" % skill_id)
			_assert_eq(result.skill_improvement.current_level, 1, "%s current raw level" % skill_id)
			_assert_true(result.skill_improvement.leveled_up, "%s reports level-up" % skill_id)
		_assert_true(result.authored_effect != null, "%s returns authored effect result" % skill_id)
		if result.authored_effect != null:
			var expected_effect_status: int = (
				SkillImprovementEffectResultScript.Status.EVALUATED_NO_MUTATION
				if skill_id == SkillIdsScript.STORMDANCE
				else SkillImprovementEffectResultScript.Status.NO_AUTHORED_EFFECT
			)
			_assert_eq(
				result.authored_effect.status,
				expected_effect_status,
				"%s uses authored effect registry" % skill_id,
			)
			_assert_eq(result.authored_effect.skill_id, skill_id, "%s authored effect skill ID" % skill_id)
		_assert_eq(context.current_spirit, 87, "%s pays exact teacher sen" % skill_id)
		_assert_eq(student.essence.current, 40, "%s pays doubled new-skill gin" % skill_id)


func _test_learn_rejections_precede_mutation() -> void:
	var registry: RegistryScript = _registry()
	var storm: CharacterStateScript = _learn_student(CharacterStateScript.GENDER_MALE, 100)
	var storm_context: TeachingContextScript = _learn_context(SkillIdsScript.STORMDANCE)
	var storm_result: LearnResultScript = LearnServiceScript.learn(
		storm,
		storm_context,
		_skill_definition(SkillIdsScript.STORMDANCE),
		registry.policy_for(SkillIdsScript.STORMDANCE),
	)
	_assert_pre_mutation_rejection(
		storm,
		storm_context,
		storm_result,
		SkillIdsScript.STORMDANCE,
		PolicyResultScript.Reason.GENDER_MISMATCH,
		"stormdance gender",
	)

	var tender: CharacterStateScript = _learn_student(CharacterStateScript.GENDER_MALE, 100)
	_equip_primary(tender, &"male-learn-primary")
	var tender_context: TeachingContextScript = _learn_context(SkillIdsScript.TENDERZHI)
	var tender_result: LearnResultScript = LearnServiceScript.learn(
		tender,
		tender_context,
		_skill_definition(SkillIdsScript.TENDERZHI),
		registry.policy_for(SkillIdsScript.TENDERZHI),
	)
	_assert_pre_mutation_rejection(
		tender,
		tender_context,
		tender_result,
		SkillIdsScript.TENDERZHI,
		PolicyResultScript.Reason.GENDER_MISMATCH,
		"tenderzhi armed male gender-first",
	)

	var armed_female: CharacterStateScript = _learn_student(
		CharacterStateScript.GENDER_FEMALE,
		100,
	)
	_equip_primary(armed_female, &"female-learn-primary")
	var female_context: TeachingContextScript = _learn_context(SkillIdsScript.TENDERZHI)
	var female_result: LearnResultScript = LearnServiceScript.learn(
		armed_female,
		female_context,
		_skill_definition(SkillIdsScript.TENDERZHI),
		registry.policy_for(SkillIdsScript.TENDERZHI),
	)
	_assert_pre_mutation_rejection(
		armed_female,
		female_context,
		female_result,
		SkillIdsScript.TENDERZHI,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"tenderzhi female equipment",
	)


func _female_student() -> CharacterStateScript:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.gender = CharacterStateScript.GENDER_FEMALE
	return student


func _learn_student(gender: StringName, spirituality: int) -> CharacterStateScript:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.gender = gender
	student.attributes.intelligence = 10
	student.attributes.spirituality = spirituality
	student.essence.maximum = 100
	student.essence.effective = 100
	student.essence.current = 100
	student.progression.potential = 100
	student.family = FamilyStateScript.new(FAMILY_ID, 14)
	student.apprenticeship = ApprenticeshipStateScript.new(TEACHER_ID, "测试教师", 0)
	return student


func _learn_context(
	skill_id: StringName,
	deterministic_improvement_roll: int = 1,
) -> TeachingContextScript:
	return TeachingContextScript.new(
		TEACHER_ID,
		TeachingOfferScript.new(skill_id),
		100,
		10,
		100,
		FAMILY_ID,
		13,
		-1,
		"测试教师",
		true,
		true,
		true,
		true,
		false,
		false,
		false,
		deterministic_improvement_roll,
		TeacherRecognitionPolicyScript.new(),
		TeacherPreventionPolicyScript.new(),
	)


func _skill_definition(skill_id: StringName) -> SkillDefinitionScript:
	return SkillDefinitionScript.new(
		skill_id,
		SkillDefinitionScript.Kind.SPECIALIZED,
		SkillDefinitionScript.Type.MARTIAL,
	)


func _registry() -> RegistryScript:
	var registry: RegistryScript = RegistryScript.new()
	registry.register_known_legacy_policies()
	return registry


func _evaluate(
	registry: RegistryScript,
	skill_id: StringName,
	student: CharacterStateScript,
) -> PolicyResultScript:
	return registry.policy_for(skill_id).evaluate(student)


func _equip_primary(student: CharacterStateScript, instance_id: StringName) -> void:
	var result: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(instance_id, false),
		false,
	)
	_assert_true(result.succeeded, "primary setup '%s' succeeds" % instance_id)


func _equip_secondary_only(student: CharacterStateScript) -> void:
	var first: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"secondary-only", true),
		false,
	)
	_assert_true(first.succeeded, "secondary-only source starts in primary")
	var replacement: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"replacement", false),
		false,
	)
	_assert_true(replacement.succeeded, "replacement moves source to secondary")
	var removed: EquipmentTransitionResultScript = student.equipment.unwield(&"replacement")
	_assert_true(removed.succeeded, "replacement removal leaves secondary-only")


func _equip_both(student: CharacterStateScript) -> void:
	_equip_primary(student, &"both-primary")
	var second: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"both-secondary", true),
		false,
	)
	_assert_true(second.succeeded, "secondary setup succeeds")


func _weapon(instance_id: StringName, can_wield_as_secondary: bool) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			StringName("weapon.%s" % instance_id),
			SkillIdsScript.SWORD,
			can_wield_as_secondary,
		),
	)


func _assert_allowed(
	registry: RegistryScript,
	skill_id: StringName,
	student: CharacterStateScript,
	label: String,
) -> void:
	var result: PolicyResultScript = _evaluate(registry, skill_id, student)
	_assert_eq(result.status, PolicyResultScript.Status.ALLOWED, label + " status")
	_assert_eq(result.reason, PolicyResultScript.Reason.NONE, label + " reason")


func _assert_reason(
	registry: RegistryScript,
	skill_id: StringName,
	student: CharacterStateScript,
	expected_reason: int,
	label: String,
) -> void:
	var result: PolicyResultScript = _evaluate(registry, skill_id, student)
	_assert_eq(result.status, PolicyResultScript.Status.REJECTED, label + " status")
	_assert_eq(result.reason, expected_reason, label + " reason")


func _assert_pre_mutation_rejection(
	student: CharacterStateScript,
	context: TeachingContextScript,
	result: LearnResultScript,
	skill_id: StringName,
	expected_policy_reason: int,
	label: String,
) -> void:
	_assert_eq(
		result.failure_reason,
		LearnResultScript.FailureReason.SKILL_LEARN_REJECTED,
		label + " Learn failure",
	)
	_assert_eq(result.skill_learn_policy_result.reason, expected_policy_reason, label + " reason")
	_assert_false(student.skills.has_raw_level(skill_id), label + " creates no raw-zero entry")
	_assert_eq(student.progression.potential_spent, 0, label + " spends no potential")
	_assert_eq(context.current_spirit, 100, label + " pays no teacher spirit")
	_assert_eq(student.essence.current, 100, label + " damages no student gin")
	_assert_eq(student.skills.learned_progress(skill_id), 0, label + " calls no improve_skill")
	_assert_eq(result.skill_improvement, null, label + " has no improvement result")


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
