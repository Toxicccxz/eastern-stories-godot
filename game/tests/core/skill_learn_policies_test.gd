extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const FamilyStateScript := preload("res://core/relationships/family_state.gd")
const ApprenticeshipStateScript := preload(
	"res://core/relationships/apprenticeship_state.gd"
)
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const PolicyResultScript := preload("res://core/learning/skill_learn_policy_result.gd")
const DefaultPolicyScript := preload("res://core/learning/default_skill_learn_policy.gd")
const RegistryScript := preload("res://core/learning/skill_learn_policy_registry.gd")
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

const TEACHER_ID: StringName = &"teacher.phase_3c2"
const FAMILY_ID: StringName = &"family.phase_3c2"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_registry_inventory_and_always_allowed()
	_test_maximum_inner_force_policies()
	_test_bellicosity_policies()
	_test_base_strength_and_force_policies()
	_test_raw_skill_policy()
	_test_effective_skill_policies()
	_test_mapped_and_compound_policy()
	_test_deferred_policy_boundaries()
	_test_registry_learn_integration()
	_test_registry_isolation()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_registry_inventory_and_always_allowed() -> void:
	var active_registry: RegistryScript = RegistryScript.new()
	active_registry.register_active_legacy_policies()
	_assert_eq(active_registry.registered_count(), 45, "all explicit valid_learn overrides registered")
	var registry: RegistryScript = _registry()
	_assert_eq(registry.registered_count(), 70, "all active skill definitions registered")
	var always_allowed: Array[StringName] = [
		SkillIdsScript.BOLOMIDUO,
		SkillIdsScript.FONXAN_FORCE,
		SkillIdsScript.FORCE,
		SkillIdsScript.ICEFORCE,
		SkillIdsScript.JIN_GANG,
		SkillIdsScript.JUECHEN_FORCE,
		SkillIdsScript.MYSTFORCE,
		SkillIdsScript.PYROBAT_STEPS,
		SkillIdsScript.QIDAOFORCE,
		SkillIdsScript.SERPENTFORCE,
		SkillIdsScript.SHORTSONG_BLADE,
		SkillIdsScript.SNOWSHADE_FORCE,
		SkillIdsScript.SPRING_BLADE,
	]
	for skill_id: StringName in always_allowed:
		_assert_status(
			registry.policy_for(skill_id).evaluate(CharacterStateScript.new()),
			PolicyResultScript.Status.ALLOWED,
			"%s literal valid_learn return 1" % skill_id,
		)
	var inherited_default_ids: Array[StringName] = [
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
	for skill_id: StringName in inherited_default_ids:
		_assert_status(
			registry.policy_for(skill_id).evaluate(CharacterStateScript.new()),
			PolicyResultScript.Status.ALLOWED,
			"%s inherits std/skill default allow" % skill_id,
		)
	_assert_false(registry.has_policy(&"unknown-skill"), "unknown skill is not assumed allowed")
	_assert_eq(registry.policy_for(&"unknown-skill"), null, "unknown skill has no policy")


func _test_maximum_inner_force_policies() -> void:
	var registry: RegistryScript = _registry()
	var cases: Array[Array] = [
		[SkillIdsScript.CHAOS_STEPS, 50],
		[SkillIdsScript.FALL_STEPS, 50],
		[SkillIdsScript.NOTRACES, 50],
		[SkillIdsScript.SCRATCHING, 80],
	]
	for case: Array in cases:
		var skill_id: StringName = case[0]
		var threshold: int = case[1]
		for offset: int in [-1, 0, 1]:
			var student: CharacterStateScript = CharacterStateScript.new()
			student.recovery.inner_force.maximum = threshold + offset
			_assert_status(
				registry.policy_for(skill_id).evaluate(student),
				PolicyResultScript.Status.REJECTED if offset < 0 else PolicyResultScript.Status.ALLOWED,
				"%s max_force threshold %+d" % [skill_id, offset],
			)


func _test_bellicosity_policies() -> void:
	var registry: RegistryScript = _registry()
	for skill_id: StringName in [SkillIdsScript.BUDDHISM, SkillIdsScript.TAOISM]:
		for value: int in [-1, 99, 100, 101]:
			var student: CharacterStateScript = CharacterStateScript.new()
			student.attributes.bellicosity = value
			_assert_status(
				registry.policy_for(skill_id).evaluate(student),
				PolicyResultScript.Status.REJECTED if value > 100 else PolicyResultScript.Status.ALLOWED,
				"%s bellicosity %d" % [skill_id, value],
			)

	var celestial: CharacterStateScript = CharacterStateScript.new()
	celestial.skills.set_raw_level(SkillIdsScript.CELESTIAL, 20)
	for value: int in [499, 500, 501]:
		celestial.attributes.bellicosity = value
		_assert_status(
			registry.policy_for(SkillIdsScript.CELESTIAL).evaluate(celestial),
			PolicyResultScript.Status.REJECTED if value < 500 else PolicyResultScript.Status.ALLOWED,
			"celestial effective 10 requires bellicosity 500 at %d" % value,
		)
	var celestial_style: StringName = &"test-celestial-style"
	celestial.skills.set_raw_level(celestial_style, 5)
	_assert_true(
		celestial.skills.map_skill(SkillIdsScript.CELESTIAL, celestial_style),
		"celestial test mapping installed",
	)
	celestial.attributes.bellicosity = 749
	_assert_status(
		registry.policy_for(SkillIdsScript.CELESTIAL).evaluate(celestial),
		PolicyResultScript.Status.REJECTED,
		"celestial reads effective mapped level 15, not raw 20",
	)
	celestial.attributes.bellicosity = 750
	_assert_status(
		registry.policy_for(SkillIdsScript.CELESTIAL).evaluate(celestial),
		PolicyResultScript.Status.ALLOWED,
		"celestial mapped effective exact boundary",
	)
	var negative_celestial: CharacterStateScript = CharacterStateScript.new()
	negative_celestial.skills.set_raw_level(SkillIdsScript.CELESTIAL, -2)
	for value: int in [-51, -50, -49]:
		negative_celestial.attributes.bellicosity = value
		_assert_status(
			registry.policy_for(SkillIdsScript.CELESTIAL).evaluate(negative_celestial),
			PolicyResultScript.Status.REJECTED if value < -50 else PolicyResultScript.Status.ALLOWED,
			"celestial preserves negative numeric boundary %d" % value,
		)


func _test_base_strength_and_force_policies() -> void:
	var registry: RegistryScript = _registry()
	for skill_id: StringName in [SkillIdsScript.CLOUDSTAFF, SkillIdsScript.JINGANG_STAFF]:
		for strength: int in [29, 30, 31]:
			var student: CharacterStateScript = CharacterStateScript.new()
			student.attributes.strength = strength
			student.attributes.strength_modifier = 100
			student.recovery.inner_force.maximum = 200
			_assert_status(
				registry.policy_for(skill_id).evaluate(student),
				PolicyResultScript.Status.REJECTED if strength < 30 else PolicyResultScript.Status.ALLOWED,
				"%s uses base str + max_force / 10 at %d" % [skill_id, strength],
			)
	var truncation: CharacterStateScript = CharacterStateScript.new()
	truncation.attributes.strength = 29
	truncation.recovery.inner_force.maximum = 209
	_assert_status(
		registry.policy_for(SkillIdsScript.CLOUDSTAFF).evaluate(truncation),
		PolicyResultScript.Status.REJECTED,
		"cloudstaff max_force 209 integer-divides to 20",
	)
	truncation.recovery.inner_force.maximum = 210
	_assert_status(
		registry.policy_for(SkillIdsScript.CLOUDSTAFF).evaluate(truncation),
		PolicyResultScript.Status.ALLOWED,
		"cloudstaff max_force 210 integer-divides to 21",
	)


func _test_raw_skill_policy() -> void:
	var registry: RegistryScript = _registry()
	for level: int in [59, 60, 61]:
		var student: CharacterStateScript = CharacterStateScript.new()
		student.skills.set_raw_level(SkillIdsScript.LITERATE, level)
		_assert_status(
			registry.policy_for(SkillIdsScript.LINBO_STEPS).evaluate(student),
			PolicyResultScript.Status.REJECTED if level < 60 else PolicyResultScript.Status.ALLOWED,
			"linbo-steps raw literate %d" % level,
		)
	var mapped_student: CharacterStateScript = CharacterStateScript.new()
	mapped_student.skills.set_raw_level(SkillIdsScript.LITERATE, 59)
	var mapped_style: StringName = &"test-literate-style"
	mapped_student.skills.set_raw_level(mapped_style, 100)
	mapped_student.skills.map_skill(SkillIdsScript.LITERATE, mapped_style)
	_assert_status(
		registry.policy_for(SkillIdsScript.LINBO_STEPS).evaluate(mapped_student),
		PolicyResultScript.Status.REJECTED,
		"linbo-steps ignores mapped effective literate and reads raw",
	)


func _test_effective_skill_policies() -> void:
	var registry: RegistryScript = _registry()
	_test_essencemagic(registry)
	_test_gouyee(registry)
	_test_effective_relation(
		registry,
		SkillIdsScript.LOTUSFORCE,
		SkillIdsScript.BUDDHISM,
		SkillIdsScript.LOTUSFORCE,
		false,
		1,
	)
	_test_effective_relation(
		registry,
		SkillIdsScript.MAGIC_ARRAY,
		SkillIdsScript.TAO_MYSTERY,
		SkillIdsScript.MAGIC_ARRAY,
		true,
		1,
	)
	_test_effective_relation(
		registry,
		SkillIdsScript.NECROMANCY,
		SkillIdsScript.TAOISM,
		SkillIdsScript.NECROMANCY,
		false,
		2,
	)
	var necromancy_odd: CharacterStateScript = CharacterStateScript.new()
	necromancy_odd.skills.set_raw_level(SkillIdsScript.NECROMANCY, 42)
	necromancy_odd.skills.set_raw_level(SkillIdsScript.TAOISM, 20)
	_assert_status(
		registry.policy_for(SkillIdsScript.NECROMANCY).evaluate(necromancy_odd),
		PolicyResultScript.Status.ALLOWED,
		"necromancy effective target 21 integer-divides to 10",
	)
	_test_effective_relation(
		registry,
		SkillIdsScript.WU_SHUN,
		SkillIdsScript.LITERATE,
		SkillIdsScript.WU_SHUN,
		false,
		1,
	)


func _test_essencemagic(registry: RegistryScript) -> void:
	var below_minimum: CharacterStateScript = CharacterStateScript.new()
	below_minimum.skills.set_raw_level(SkillIdsScript.BUDDHISM, 18)
	var minimum_result: PolicyResultScript = registry.policy_for(
		SkillIdsScript.ESSENCE_MAGIC
	).evaluate(below_minimum)
	_assert_status(
		minimum_result,
		PolicyResultScript.Status.REJECTED,
		"essencemagic effective buddhism 9 fails absolute 10",
	)
	_assert_eq(minimum_result.actual_value, 9, "essencemagic first check actual")
	_assert_eq(minimum_result.required_value, 10, "essencemagic first check threshold")
	var equal_target: CharacterStateScript = CharacterStateScript.new()
	equal_target.skills.set_raw_level(SkillIdsScript.BUDDHISM, 20)
	equal_target.skills.set_raw_level(SkillIdsScript.ESSENCE_MAGIC, 18)
	_assert_status(
		registry.policy_for(SkillIdsScript.ESSENCE_MAGIC).evaluate(equal_target),
		PolicyResultScript.Status.ALLOWED,
		"essencemagic effective buddhism exact absolute 10 can pass",
	)
	equal_target.skills.set_raw_level(SkillIdsScript.ESSENCE_MAGIC, 20)
	var equality_result: PolicyResultScript = registry.policy_for(
		SkillIdsScript.ESSENCE_MAGIC
	).evaluate(equal_target)
	_assert_status(
		equality_result,
		PolicyResultScript.Status.REJECTED,
		"essencemagic equality fails strict greater relation",
	)
	_assert_eq(equality_result.actual_value, 10, "essencemagic second check actual")
	_assert_eq(equality_result.required_value, 10, "essencemagic second check target")
	var above_target: CharacterStateScript = CharacterStateScript.new()
	above_target.skills.set_raw_level(SkillIdsScript.BUDDHISM, 22)
	above_target.skills.set_raw_level(SkillIdsScript.ESSENCE_MAGIC, 20)
	_assert_status(
		registry.policy_for(SkillIdsScript.ESSENCE_MAGIC).evaluate(above_target),
		PolicyResultScript.Status.ALLOWED,
		"essencemagic effective buddhism one above target",
	)
	var mapped: CharacterStateScript = CharacterStateScript.new()
	mapped.skills.set_raw_level(SkillIdsScript.BUDDHISM, 10)
	mapped.skills.set_raw_level(SkillIdsScript.ESSENCE_MAGIC, 20)
	var style: StringName = &"test-buddhism-style"
	mapped.skills.set_raw_level(style, 10)
	_assert_status(
		registry.policy_for(SkillIdsScript.ESSENCE_MAGIC).evaluate(mapped),
		PolicyResultScript.Status.REJECTED,
		"essencemagic same raw without mapped contribution",
	)
	mapped.skills.map_skill(SkillIdsScript.BUDDHISM, style)
	_assert_status(
		registry.policy_for(SkillIdsScript.ESSENCE_MAGIC).evaluate(mapped),
		PolicyResultScript.Status.ALLOWED,
		"essencemagic uses mapped contribution to effective prerequisite",
	)


func _test_gouyee(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.skills.set_raw_level(SkillIdsScript.GOUYEE, 20)
	for maximum: int in [49, 50, 51]:
		student.recovery.mana.maximum = maximum
		_assert_status(
			registry.policy_for(SkillIdsScript.GOUYEE).evaluate(student),
			PolicyResultScript.Status.REJECTED if maximum < 50 else PolicyResultScript.Status.ALLOWED,
			"gouyee max_mana boundary %d" % maximum,
		)
	var style: StringName = &"test-gouyee-style"
	student.skills.set_raw_level(style, 10)
	student.skills.map_skill(SkillIdsScript.GOUYEE, style)
	student.recovery.mana.maximum = 99
	_assert_status(
		registry.policy_for(SkillIdsScript.GOUYEE).evaluate(student),
		PolicyResultScript.Status.REJECTED,
		"gouyee mapped effective raises required max_mana to 100",
	)
	student.recovery.mana.maximum = 100
	_assert_status(
		registry.policy_for(SkillIdsScript.GOUYEE).evaluate(student),
		PolicyResultScript.Status.ALLOWED,
		"gouyee mapped effective exact max_mana boundary",
	)
	var negative: CharacterStateScript = CharacterStateScript.new()
	negative.skills.set_raw_level(SkillIdsScript.GOUYEE, -2)
	for maximum: int in [-6, -5, -4]:
		negative.recovery.mana.maximum = maximum
		_assert_status(
			registry.policy_for(SkillIdsScript.GOUYEE).evaluate(negative),
			PolicyResultScript.Status.REJECTED if maximum < -5 else PolicyResultScript.Status.ALLOWED,
			"gouyee does not clamp negative legacy values at %d" % maximum,
		)


func _test_effective_relation(
	registry: RegistryScript,
	policy_id: StringName,
	prerequisite_id: StringName,
	target_id: StringName,
	strictly_greater: bool,
	target_divisor: int,
) -> void:
	## Target effective 20; divisor 1 requires 20, divisor 2 requires 10.
	var target_raw: int = 40
	var required: int = 20 / target_divisor
	for offset: int in [-1, 0, 1]:
		var student: CharacterStateScript = CharacterStateScript.new()
		student.skills.set_raw_level(target_id, target_raw)
		student.skills.set_raw_level(prerequisite_id, (required + offset) * 2)
		var should_reject: bool = offset < 0 or (strictly_greater and offset == 0)
		_assert_status(
			registry.policy_for(policy_id).evaluate(student),
			PolicyResultScript.Status.REJECTED if should_reject else PolicyResultScript.Status.ALLOWED,
			"%s effective relation offset %+d" % [policy_id, offset],
		)
	var mapped: CharacterStateScript = CharacterStateScript.new()
	mapped.skills.set_raw_level(target_id, target_raw)
	mapped.skills.set_raw_level(prerequisite_id, max(0, (required - 5) * 2))
	var style: StringName = StringName("test-%s-style" % prerequisite_id)
	mapped.skills.set_raw_level(style, 6 if strictly_greater else 5)
	_assert_status(
		registry.policy_for(policy_id).evaluate(mapped),
		PolicyResultScript.Status.REJECTED,
		"%s same raw without mapping" % policy_id,
	)
	mapped.skills.map_skill(prerequisite_id, style)
	_assert_status(
		registry.policy_for(policy_id).evaluate(mapped),
		PolicyResultScript.Status.ALLOWED,
		"%s reads effective prerequisite with mapping" % policy_id,
	)


func _test_mapped_and_compound_policy() -> void:
	var registry: RegistryScript = _registry()
	var student: CharacterStateScript = CharacterStateScript.new()
	student.skills.set_raw_level(SkillIdsScript.MUSIC, 20)
	student.skills.set_raw_level(SkillIdsScript.MYSTERRIER, 40)
	var no_mapping_result: PolicyResultScript = registry.policy_for(
		SkillIdsScript.MYSTERRIER
	).evaluate(student)
	_assert_status(
		no_mapping_result,
		PolicyResultScript.Status.REJECTED,
		"mysterrier no force mapping rejected first",
	)
	_assert_eq(
		no_mapping_result.reason,
		PolicyResultScript.Reason.MAPPED_SKILL_MISMATCH,
		"mysterrier first failure is mapped identity",
	)
	var wrong_force: StringName = &"wrong-force-style"
	student.skills.set_raw_level(wrong_force, 1)
	student.skills.map_skill(SkillIdsScript.FORCE, wrong_force)
	_assert_status(
		registry.policy_for(SkillIdsScript.MYSTERRIER).evaluate(student),
		PolicyResultScript.Status.REJECTED,
		"mysterrier wrong force mapping rejected",
	)
	student.skills.set_raw_level(SkillIdsScript.MYSTFORCE, 1)
	student.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.MYSTFORCE)
	for music_raw: int in [18, 20, 22]:
		student.skills.set_raw_level(SkillIdsScript.MUSIC, music_raw)
		var result: PolicyResultScript = registry.policy_for(
			SkillIdsScript.MYSTERRIER
		).evaluate(student)
		_assert_status(
			result,
			PolicyResultScript.Status.REJECTED if music_raw < 20 else PolicyResultScript.Status.ALLOWED,
			"mysterrier effective music boundary raw %d" % music_raw,
		)
		if music_raw < 20:
			_assert_eq(
				result.reason,
				PolicyResultScript.Reason.EFFECTIVE_SKILL_TOO_LOW,
				"mysterrier second failure follows successful mapping check",
			)
	var music_style: StringName = &"test-music-style"
	student.skills.set_raw_level(SkillIdsScript.MUSIC, 10)
	student.skills.set_raw_level(music_style, 5)
	student.skills.map_skill(SkillIdsScript.MUSIC, music_style)
	_assert_status(
		registry.policy_for(SkillIdsScript.MYSTERRIER).evaluate(student),
		PolicyResultScript.Status.ALLOWED,
		"mysterrier effective music includes mapped special",
	)
	var dangling: CharacterStateScript = CharacterStateScript.new()
	dangling.skills.set_raw_level(SkillIdsScript.MYSTFORCE, 1)
	_assert_true(
		dangling.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.MYSTFORCE),
		"mysterrier dangling mapping setup",
	)
	_assert_true(
		dangling.skills.remove_skill(SkillIdsScript.MYSTFORCE),
		"mapped target raw entry removed",
	)
	dangling.skills.set_raw_level(SkillIdsScript.MUSIC, 20)
	dangling.skills.set_raw_level(SkillIdsScript.MYSTERRIER, 40)
	_assert_eq(
		dangling.skills.mapped_skill(SkillIdsScript.FORCE),
		SkillIdsScript.MYSTFORCE,
		"Phase 3A preserves dangling mapped identity",
	)
	_assert_status(
		registry.policy_for(SkillIdsScript.MYSTERRIER).evaluate(dangling),
		PolicyResultScript.Status.ALLOWED,
		"mysterrier checks mapping identity without inventing target-level check",
	)


func _test_deferred_policy_boundaries() -> void:
	var registry: RegistryScript = _registry()
	var tender_result: PolicyResultScript = registry.policy_for(
		SkillIdsScript.TENDERZHI
	).evaluate(CharacterStateScript.new())
	_assert_status(
		tender_result,
		PolicyResultScript.Status.DEPENDENCY_UNAVAILABLE,
		"tenderzhi remains deferred at first gender check",
	)
	_assert_eq(
		tender_result.reason,
		PolicyResultScript.Reason.GENDER_STATE_UNAVAILABLE,
		"tenderzhi reports first unavailable LPC dependency",
	)
	var storm_result: PolicyResultScript = registry.policy_for(SkillIdsScript.STORMDANCE).evaluate(
		CharacterStateScript.new()
	)
	_assert_status(storm_result, PolicyResultScript.Status.DEPENDENCY_UNAVAILABLE, "stormdance deferred")
	_assert_eq(
		storm_result.reason,
		PolicyResultScript.Reason.GENDER_STATE_UNAVAILABLE,
		"stormdance gender reason",
	)
	var nine_result: PolicyResultScript = registry.policy_for(SkillIdsScript.NINE_MOON).evaluate(
		CharacterStateScript.new()
	)
	_assert_status(nine_result, PolicyResultScript.Status.DEPENDENCY_UNAVAILABLE, "nine-moon defect")
	_assert_eq(
		nine_result.reason,
		PolicyResultScript.Reason.LEGACY_REQUIRED_SKILL_MISSING,
		"nine-moon missing force daemon reason",
	)

	var student: CharacterStateScript = _learn_student()
	var context: TeachingContextScript = _learn_context(SkillIdsScript.TENDERZHI)
	var learn_result: LearnResultScript = LearnServiceScript.learn(
		student,
		context,
		SkillDefinitionScript.new(
			SkillIdsScript.TENDERZHI,
			SkillDefinitionScript.Kind.SPECIALIZED,
			SkillDefinitionScript.Type.MARTIAL,
		),
		registry.policy_for(SkillIdsScript.TENDERZHI),
	)
	_assert_eq(
		learn_result.failure_reason,
		LearnResultScript.FailureReason.SKILL_LEARN_DEPENDENCY_UNAVAILABLE,
		"dependency unavailable stops at valid_learn",
	)
	_assert_eq(
		learn_result.skill_learn_policy_result.reason,
		PolicyResultScript.Reason.GENDER_STATE_UNAVAILABLE,
		"LearnResult preserves typed policy detail",
	)
	_assert_false(student.skills.has_raw_level(SkillIdsScript.TENDERZHI), "no raw-zero entry")
	_assert_eq(student.progression.potential_spent, 0, "no potential mutation")
	_assert_eq(context.current_spirit, 100, "no teacher sen payment")
	_assert_eq(student.essence.current, 100, "no student gin damage")
	_assert_eq(student.skills.learned_progress(SkillIdsScript.TENDERZHI), 0, "no improve_skill progress")
	_assert_eq(learn_result.skill_improvement, null, "no improve_skill result")


func _test_registry_learn_integration() -> void:
	var registry: RegistryScript = _registry()
	var student: CharacterStateScript = _learn_student()
	var context: TeachingContextScript = _learn_context(SkillIdsScript.SWORD)
	var result: LearnResultScript = LearnServiceScript.learn(
		student,
		context,
		SkillDefinitionScript.new(
			SkillIdsScript.SWORD,
			SkillDefinitionScript.Kind.BASIC,
			SkillDefinitionScript.Type.MARTIAL,
		),
		registry.policy_for(SkillIdsScript.SWORD),
	)
	_assert_true(result.success, "inherited std default permits normal Learn flow")
	_assert_eq(result.completion, LearnResultScript.Completion.PROGRESSED, "normal Learn completion")
	_assert_eq(student.progression.potential_spent, 1, "normal Learn spends potential")
	_assert_eq(student.skills.learned_progress(SkillIdsScript.SWORD), 1, "normal Learn improves skill")

	var unknown_id: StringName = &"unknown-skill"
	var unknown_student: CharacterStateScript = _learn_student()
	var unknown_context: TeachingContextScript = _learn_context(unknown_id)
	var unknown_result: LearnResultScript = LearnServiceScript.learn(
		unknown_student,
		unknown_context,
		SkillDefinitionScript.new(
			unknown_id,
			SkillDefinitionScript.Kind.SPECIALIZED,
			SkillDefinitionScript.Type.MARTIAL,
		),
		registry.policy_for(unknown_id),
	)
	_assert_eq(
		unknown_result.failure_reason,
		LearnResultScript.FailureReason.SKILL_POLICY_MISMATCH,
		"unknown skill does not inherit permissive default",
	)
	_assert_false(unknown_student.skills.has_raw_level(unknown_id), "unknown policy fails before raw-zero")
	_assert_eq(unknown_student.progression.potential_spent, 0, "unknown policy spends no potential")


func _test_registry_isolation() -> void:
	var first: RegistryScript = _registry()
	var second: RegistryScript = _registry()
	_assert_true(
		first.policy_for(SkillIdsScript.BUDDHISM) != second.policy_for(SkillIdsScript.BUDDHISM),
		"registries do not share policy instances",
	)
	first.register_policy(DefaultPolicyScript.new(SkillIdsScript.CELESTRIKE))
	_assert_status(
		first.policy_for(SkillIdsScript.CELESTRIKE).evaluate(CharacterStateScript.new()),
		PolicyResultScript.Status.ALLOWED,
		"first registry can be changed independently",
	)
	_assert_status(
		second.policy_for(SkillIdsScript.CELESTRIKE).evaluate(CharacterStateScript.new()),
		PolicyResultScript.Status.REJECTED,
		"second registry remains unchanged",
	)


func _registry() -> RegistryScript:
	var registry: RegistryScript = RegistryScript.new()
	registry.register_known_legacy_policies()
	return registry


func _learn_student() -> CharacterStateScript:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.attributes.intelligence = 10
	student.attributes.spirituality = 30
	student.essence.maximum = 100
	student.essence.effective = 100
	student.essence.current = 100
	student.progression.potential = 100
	student.family = FamilyStateScript.new(FAMILY_ID, 14)
	student.apprenticeship = ApprenticeshipStateScript.new(TEACHER_ID, "测试教师", 0)
	return student


func _learn_context(skill_id: StringName) -> TeachingContextScript:
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
		false,
		false,
		false,
		false,
		1,
		TeacherRecognitionPolicyScript.new(),
		TeacherPreventionPolicyScript.new(),
	)


func _assert_status(result: PolicyResultScript, expected: int, label: String) -> void:
	_assert_eq(result.status, expected, label)


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
