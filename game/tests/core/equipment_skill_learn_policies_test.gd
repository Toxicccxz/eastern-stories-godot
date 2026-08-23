extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const FamilyStateScript := preload("res://core/relationships/family_state.gd")
const ApprenticeshipStateScript := preload(
	"res://core/relationships/apprenticeship_state.gd"
)
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const PolicyResultScript := preload("res://core/learning/skill_learn_policy_result.gd")
const RegistryScript := preload("res://core/learning/skill_learn_policy_registry.gd")
const DefaultPolicyScript := preload("res://core/learning/default_skill_learn_policy.gd")
const DependencyPolicyScript := preload(
	"res://core/learning/dependency_unavailable_skill_learn_policy.gd"
)
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const EquipmentTransitionResultScript := preload(
	"res://core/equipment/equipment_transition_result.gd"
)
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

const TEACHER_ID: StringName = &"teacher.phase_4a2"
const FAMILY_ID: StringName = &"family.phase_4a2"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_registry_inventory_and_isolation()
	_test_empty_hand_policy_matrix()
	_test_sword_policy_equipment_matrix()
	_test_whip_policy_equipment_matrix()
	_test_phase_4a1_reachable_unusual_states()
	_test_compound_validation_order_and_boundaries()
	_test_dangling_mapping_identity()
	_test_remaining_dependency_boundaries()
	_test_equipment_and_policy_state_isolation()
	_test_policy_evaluation_is_read_only()
	_test_learn_service_equipment_rejection()
	_test_learn_service_empty_hand_policy_success()
	_test_learn_service_primary_sword_policy_success()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_registry_inventory_and_isolation() -> void:
	var active_registry: RegistryScript = RegistryScript.new()
	active_registry.register_active_legacy_policies()
	_assert_eq(active_registry.registered_count(), 45, "exact active valid_learn hook count")

	var known_registry: RegistryScript = _registry()
	_assert_eq(known_registry.registered_count(), 70, "exact known active skill count")
	var equipment_skill_ids: Array[StringName] = [
		SkillIdsScript.BLOODY_STRIKE,
		SkillIdsScript.CELESTRIKE,
		SkillIdsScript.DEISWORD,
		SkillIdsScript.FONXAN_SWORD,
		SkillIdsScript.LIUH_KEN,
		SkillIdsScript.MEIHUA_SHOU,
		SkillIdsScript.MYSTSWORD,
		SkillIdsScript.SIX_CHAOS_SWORD,
		SkillIdsScript.SNOWSHADE_SWORD,
		SkillIdsScript.SNOWWHIP,
		SkillIdsScript.SPICYCLAW,
		SkillIdsScript.TS_FIST,
	]
	for skill_id: StringName in equipment_skill_ids:
		var student: CharacterStateScript = _valid_student(skill_id)
		if skill_id == SkillIdsScript.SNOWWHIP:
			_equip_primary(student, SkillIdsScript.WHIP)
		elif skill_id in [
			SkillIdsScript.DEISWORD,
			SkillIdsScript.FONXAN_SWORD,
			SkillIdsScript.MYSTSWORD,
			SkillIdsScript.SIX_CHAOS_SWORD,
			SkillIdsScript.SNOWSHADE_SWORD,
		]:
			_equip_primary(student, SkillIdsScript.SWORD)
		_assert_allowed(active_registry, skill_id, student, "%s equipment hook executable" % skill_id)

	var dependency_skill_ids: Array[StringName] = [SkillIdsScript.NINE_MOON]
	for skill_id: StringName in dependency_skill_ids:
		_assert_true(
			active_registry.policy_for(skill_id).get_script() == DependencyPolicyScript,
			"%s remains explicit dependency policy" % skill_id,
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
	_assert_eq(inherited_default_ids.size(), 25, "exact inherited default count")
	for skill_id: StringName in inherited_default_ids:
		_assert_true(
			known_registry.policy_for(skill_id).get_script() == DefaultPolicyScript,
			"%s explicitly uses inherited default" % skill_id,
		)
	_assert_false(known_registry.has_policy(&"unknown-phase-4a2"), "unknown skill is not registered")
	_assert_eq(known_registry.policy_for(&"unknown-phase-4a2"), null, "unknown skill has no guessed policy")

	var second_registry: RegistryScript = _registry()
	_assert_false(
		known_registry.policy_for(SkillIdsScript.DEISWORD)
		== second_registry.policy_for(SkillIdsScript.DEISWORD),
		"registries do not share equipment policy instances",
	)


func _test_empty_hand_policy_matrix() -> void:
	var registry: RegistryScript = _registry()
	var skill_ids: Array[StringName] = [
		SkillIdsScript.BLOODY_STRIKE,
		SkillIdsScript.CELESTRIKE,
		SkillIdsScript.LIUH_KEN,
		SkillIdsScript.MEIHUA_SHOU,
		SkillIdsScript.SPICYCLAW,
		SkillIdsScript.TS_FIST,
	]
	for skill_id: StringName in skill_ids:
		var empty: CharacterStateScript = _valid_student(skill_id)
		_assert_status(
			registry,
			skill_id,
			empty,
			PolicyResultScript.Status.ALLOWED,
			PolicyResultScript.Reason.NONE,
			"%s both references empty" % skill_id,
		)

		var primary_only: CharacterStateScript = _valid_student(skill_id)
		_equip_primary(primary_only, SkillIdsScript.SWORD)
		_assert_status(
			registry,
			skill_id,
			primary_only,
			PolicyResultScript.Status.REJECTED,
			PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
			"%s primary only" % skill_id,
		)

		var secondary_only: CharacterStateScript = _valid_student(skill_id)
		_equip_secondary_only(secondary_only, SkillIdsScript.SWORD)
		_assert_status(
			registry,
			skill_id,
			secondary_only,
			PolicyResultScript.Status.REJECTED,
			PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
			"%s secondary only" % skill_id,
		)

		var both: CharacterStateScript = _valid_student(skill_id)
		_equip_primary_with_secondary(both, SkillIdsScript.SWORD, &"custom-secondary")
		var both_result: PolicyResultScript = registry.policy_for(skill_id).evaluate(both)
		_assert_eq(
			both_result.reason,
			PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
			"%s both occupied reason" % skill_id,
		)


func _test_sword_policy_equipment_matrix() -> void:
	var registry: RegistryScript = _registry()
	var skill_ids: Array[StringName] = [
		SkillIdsScript.DEISWORD,
		SkillIdsScript.FONXAN_SWORD,
		SkillIdsScript.MYSTSWORD,
		SkillIdsScript.SIX_CHAOS_SWORD,
		SkillIdsScript.SNOWSHADE_SWORD,
	]
	for skill_id: StringName in skill_ids:
		var no_primary: CharacterStateScript = _valid_student(skill_id)
		_assert_status(
			registry,
			skill_id,
			no_primary,
			PolicyResultScript.Status.REJECTED,
			PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
			"%s no primary" % skill_id,
		)

		var secondary_sword: CharacterStateScript = _valid_student(skill_id)
		_equip_secondary_only(secondary_sword, SkillIdsScript.SWORD)
		_assert_status(
			registry,
			skill_id,
			secondary_sword,
			PolicyResultScript.Status.REJECTED,
			PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
			"%s secondary sword is not promoted" % skill_id,
		)

		for wrong_type: StringName in [SkillIdsScript.WHIP, &"custom-type", &""]:
			var wrong_primary: CharacterStateScript = _valid_student(skill_id)
			_equip_primary(wrong_primary, wrong_type)
			var wrong_result: PolicyResultScript = registry.policy_for(skill_id).evaluate(
				wrong_primary
			)
			_assert_eq(
				wrong_result.reason,
				PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH,
				"%s rejects primary type '%s'" % [skill_id, wrong_type],
			)
			_assert_eq(
				wrong_result.actual_id,
				wrong_type,
				"%s preserves actual primary type" % skill_id,
			)

		var primary_sword: CharacterStateScript = _valid_student(skill_id)
		_equip_primary(primary_sword, SkillIdsScript.SWORD)
		_assert_status(
			registry,
			skill_id,
			primary_sword,
			PolicyResultScript.Status.ALLOWED,
			PolicyResultScript.Reason.NONE,
			"%s primary sword" % skill_id,
		)

		var sword_and_secondary: CharacterStateScript = _valid_student(skill_id)
		_equip_primary_with_secondary(
			sword_and_secondary,
			SkillIdsScript.SWORD,
			&"arbitrary-secondary",
		)
		_assert_status(
			registry,
			skill_id,
			sword_and_secondary,
			PolicyResultScript.Status.ALLOWED,
			PolicyResultScript.Reason.NONE,
			"%s ignores secondary skill_type" % skill_id,
		)


func _test_whip_policy_equipment_matrix() -> void:
	var registry: RegistryScript = _registry()
	var no_primary: CharacterStateScript = _valid_student(SkillIdsScript.SNOWWHIP)
	_assert_status(
		registry,
		SkillIdsScript.SNOWWHIP,
		no_primary,
		PolicyResultScript.Status.REJECTED,
		PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
		"snowwhip no primary",
	)
	var secondary_whip: CharacterStateScript = _valid_student(SkillIdsScript.SNOWWHIP)
	_equip_secondary_only(secondary_whip, SkillIdsScript.WHIP)
	_assert_status(
		registry,
		SkillIdsScript.SNOWWHIP,
		secondary_whip,
		PolicyResultScript.Status.REJECTED,
		PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
		"snowwhip secondary-only whip",
	)
	var primary_sword: CharacterStateScript = _valid_student(SkillIdsScript.SNOWWHIP)
	_equip_primary(primary_sword, SkillIdsScript.SWORD)
	_assert_status(
		registry,
		SkillIdsScript.SNOWWHIP,
		primary_sword,
		PolicyResultScript.Status.REJECTED,
		PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH,
		"snowwhip primary sword",
	)
	var primary_whip: CharacterStateScript = _valid_student(SkillIdsScript.SNOWWHIP)
	_equip_primary(primary_whip, SkillIdsScript.WHIP)
	_assert_status(
		registry,
		SkillIdsScript.SNOWWHIP,
		primary_whip,
		PolicyResultScript.Status.ALLOWED,
		PolicyResultScript.Reason.NONE,
		"snowwhip primary whip",
	)
	var whip_and_secondary: CharacterStateScript = _valid_student(SkillIdsScript.SNOWWHIP)
	_equip_primary_with_secondary(
		whip_and_secondary,
		SkillIdsScript.WHIP,
		&"arbitrary-secondary",
	)
	_assert_status(
		registry,
		SkillIdsScript.SNOWWHIP,
		whip_and_secondary,
		PolicyResultScript.Status.ALLOWED,
		PolicyResultScript.Reason.NONE,
		"snowwhip ignores secondary skill_type",
	)


func _test_phase_4a1_reachable_unusual_states() -> void:
	var registry: RegistryScript = _registry()
	var secondary_capable_primary: CharacterStateScript = _valid_student(SkillIdsScript.DEISWORD)
	var first: EquipmentTransitionResultScript = secondary_capable_primary.equipment.wield(
		_weapon(&"secondary-flag-primary", SkillIdsScript.SWORD, true),
		false,
	)
	_assert_true(first.succeeded, "SECONDARY-capable weapon can occupy primary")
	_assert_allowed(
		registry,
		SkillIdsScript.DEISWORD,
		secondary_capable_primary,
		"SECONDARY flag does not change primary sword fact",
	)
	_assert_reason(
		registry,
		SkillIdsScript.BLOODY_STRIKE,
		secondary_capable_primary,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"SECONDARY-capable primary is not empty hand",
	)

	var two_handed_primary: CharacterStateScript = _valid_student(SkillIdsScript.DEISWORD)
	var two_handed: EquipmentTransitionResultScript = two_handed_primary.equipment.wield(
		_weapon(&"two-handed-primary", SkillIdsScript.SWORD, false, true),
		false,
	)
	_assert_true(two_handed.succeeded, "two-handed sword can occupy primary")
	_assert_allowed(
		registry,
		SkillIdsScript.DEISWORD,
		two_handed_primary,
		"TWO_HANDED flag does not change primary sword fact",
	)

	var odd_both: CharacterStateScript = _valid_student(SkillIdsScript.DEISWORD)
	var odd_primary: EquipmentTransitionResultScript = odd_both.equipment.wield(
		_weapon(&"odd-two-handed-primary", SkillIdsScript.SWORD, false, true),
		false,
	)
	_assert_true(odd_primary.succeeded, "odd state starts with two-handed primary")
	var odd_secondary: EquipmentTransitionResultScript = odd_both.equipment.wield(
		_weapon(&"odd-secondary", &"custom-secondary", true),
		false,
	)
	_assert_true(odd_secondary.succeeded, "Phase 4A1 permits two-handed plus secondary state")
	_assert_allowed(
		registry,
		SkillIdsScript.DEISWORD,
		odd_both,
		"primary sword rule ignores two-handed-plus-secondary oddity",
	)
	_assert_reason(
		registry,
		SkillIdsScript.BLOODY_STRIKE,
		odd_both,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"two-handed-plus-secondary oddity is occupied",
	)


func _test_compound_validation_order_and_boundaries() -> void:
	var registry: RegistryScript = _registry()
	_test_celestrike_order(registry)
	_test_deisword_order(registry)
	_test_fonxansword_order(registry)
	_test_mystsword_order(registry)
	_test_six_chaos_order(registry)
	_test_snowshade_sword_order(registry)
	_test_snowwhip_order(registry)
	_test_empty_hand_force_order(registry, SkillIdsScript.SPICYCLAW)
	_test_empty_hand_force_order(registry, SkillIdsScript.TS_FIST)


func _test_celestrike_order(registry: RegistryScript) -> void:
	var armed: CharacterStateScript = CharacterStateScript.new()
	armed.skills.set_raw_level(SkillIdsScript.CELESTIAL, 19)
	armed.recovery.inner_force.maximum = 99
	_equip_primary(armed, SkillIdsScript.SWORD)
	_assert_reason(registry, SkillIdsScript.CELESTRIKE, armed, PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY, "celestrike equipment first")

	var low_skill: CharacterStateScript = CharacterStateScript.new()
	low_skill.skills.set_raw_level(SkillIdsScript.CELESTIAL, 19)
	low_skill.recovery.inner_force.maximum = 99
	_assert_reason(registry, SkillIdsScript.CELESTRIKE, low_skill, PolicyResultScript.Reason.RAW_SKILL_TOO_LOW, "celestrike raw celestial 19")

	var low_force: CharacterStateScript = CharacterStateScript.new()
	low_force.skills.set_raw_level(SkillIdsScript.CELESTIAL, 20)
	low_force.recovery.inner_force.maximum = 99
	_assert_reason(registry, SkillIdsScript.CELESTRIKE, low_force, PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW, "celestrike max_force 99")

	low_force.recovery.inner_force.maximum = 100
	_assert_allowed(registry, SkillIdsScript.CELESTRIKE, low_force, "celestrike exact boundaries")


func _test_fonxansword_order(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.recovery.inner_force.maximum = 49
	_assert_reason(registry, SkillIdsScript.FONXAN_SWORD, student, PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW, "fonxansword max_force 49")
	student.recovery.inner_force.maximum = 50
	_assert_reason(registry, SkillIdsScript.FONXAN_SWORD, student, PolicyResultScript.Reason.MAPPED_SKILL_MISMATCH, "fonxansword no mapping")
	student.skills.set_raw_level(&"wrong-force", 1)
	student.skills.map_skill(SkillIdsScript.FORCE, &"wrong-force")
	_assert_reason(registry, SkillIdsScript.FONXAN_SWORD, student, PolicyResultScript.Reason.MAPPED_SKILL_MISMATCH, "fonxansword wrong mapping")
	student.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 1)
	student.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	_assert_reason(registry, SkillIdsScript.FONXAN_SWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING, "fonxansword correct mapping no primary")
	_equip_primary(student, SkillIdsScript.WHIP)
	_assert_reason(registry, SkillIdsScript.FONXAN_SWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH, "fonxansword non-sword")
	student.equipment.unwield(&"primary")
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_allowed(registry, SkillIdsScript.FONXAN_SWORD, student, "fonxansword exact valid state")


func _test_deisword_order(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.recovery.inner_force.maximum = 49
	_assert_reason(
		registry,
		SkillIdsScript.DEISWORD,
		student,
		PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW,
		"deisword max_force 49 before primary check",
	)
	student.recovery.inner_force.maximum = 50
	_assert_reason(
		registry,
		SkillIdsScript.DEISWORD,
		student,
		PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
		"deisword max_force 50 reaches primary check",
	)
	_equip_primary(student, SkillIdsScript.WHIP)
	_assert_reason(
		registry,
		SkillIdsScript.DEISWORD,
		student,
		PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH,
		"deisword exact max_force with non-sword",
	)
	student.equipment.unwield(&"primary")
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_allowed(registry, SkillIdsScript.DEISWORD, student, "deisword exact boundaries")


func _test_mystsword_order(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.skills.set_raw_level(SkillIdsScript.MYSTFORCE, 29)
	student.recovery.inner_force.maximum = 100
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_reason(registry, SkillIdsScript.MYSTSWORD, student, PolicyResultScript.Reason.RAW_SKILL_TOO_LOW, "mystsword raw mystforce 29")
	student.skills.set_raw_level(SkillIdsScript.MYSTFORCE, 30)
	student.recovery.inner_force.maximum = 99
	_assert_reason(registry, SkillIdsScript.MYSTSWORD, student, PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW, "mystsword max_force 99")
	student.recovery.inner_force.maximum = 100
	student.equipment.unwield(&"primary")
	_assert_reason(registry, SkillIdsScript.MYSTSWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING, "mystsword exact skill and force with no primary")
	_equip_primary(student, SkillIdsScript.WHIP)
	_assert_reason(registry, SkillIdsScript.MYSTSWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH, "mystsword primary whip")
	student.equipment.unwield(&"primary")
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_allowed(registry, SkillIdsScript.MYSTSWORD, student, "mystsword exact boundaries")


func _test_six_chaos_order(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.recovery.inner_force.maximum = 99
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_reason(registry, SkillIdsScript.SIX_CHAOS_SWORD, student, PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW, "six-chaos max_force 99")
	student.recovery.inner_force.maximum = 100
	student.equipment.unwield(&"primary")
	_assert_reason(registry, SkillIdsScript.SIX_CHAOS_SWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING, "six-chaos exact force with no primary")
	_equip_primary(student, SkillIdsScript.WHIP)
	_assert_reason(registry, SkillIdsScript.SIX_CHAOS_SWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH, "six-chaos primary whip")
	student.equipment.unwield(&"primary")
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_allowed(registry, SkillIdsScript.SIX_CHAOS_SWORD, student, "six-chaos exact valid boundary")


func _test_snowshade_sword_order(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.recovery.inner_force.maximum = 49
	_assert_reason(registry, SkillIdsScript.SNOWSHADE_SWORD, student, PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW, "snowshade max_force 49")
	student.recovery.inner_force.maximum = 50
	_assert_reason(registry, SkillIdsScript.SNOWSHADE_SWORD, student, PolicyResultScript.Reason.MAPPED_SKILL_MISMATCH, "snowshade no mapping")
	student.skills.set_raw_level(&"wrong-force", 1)
	student.skills.map_skill(SkillIdsScript.FORCE, &"wrong-force")
	_assert_reason(registry, SkillIdsScript.SNOWSHADE_SWORD, student, PolicyResultScript.Reason.MAPPED_SKILL_MISMATCH, "snowshade wrong mapping")
	student.skills.set_raw_level(SkillIdsScript.SNOWSHADE_FORCE, 1)
	student.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.SNOWSHADE_FORCE)
	_assert_reason(registry, SkillIdsScript.SNOWSHADE_SWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING, "snowshade correct mapping no primary")
	_equip_primary(student, SkillIdsScript.WHIP)
	_assert_reason(registry, SkillIdsScript.SNOWSHADE_SWORD, student, PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH, "snowshade non-sword")
	student.equipment.unwield(&"primary")
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_allowed(registry, SkillIdsScript.SNOWSHADE_SWORD, student, "snowshade exact valid state")


func _test_empty_hand_force_order(registry: RegistryScript, skill_id: StringName) -> void:
	var armed: CharacterStateScript = CharacterStateScript.new()
	armed.recovery.inner_force.maximum = 79
	_equip_primary(armed, SkillIdsScript.SWORD)
	_assert_reason(registry, skill_id, armed, PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY, "%s equipment before force" % skill_id)
	var empty: CharacterStateScript = CharacterStateScript.new()
	empty.recovery.inner_force.maximum = 79
	_assert_reason(registry, skill_id, empty, PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW, "%s max_force 79" % skill_id)
	empty.recovery.inner_force.maximum = 80
	_assert_allowed(registry, skill_id, empty, "%s max_force 80" % skill_id)


func _test_snowwhip_order(registry: RegistryScript) -> void:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.recovery.inner_force.maximum = 149
	_assert_reason(
		registry,
		SkillIdsScript.SNOWWHIP,
		student,
		PolicyResultScript.Reason.MAXIMUM_INNER_FORCE_TOO_LOW,
		"snowwhip max_force 149 before primary check",
	)
	student.recovery.inner_force.maximum = 150
	_assert_reason(
		registry,
		SkillIdsScript.SNOWWHIP,
		student,
		PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
		"snowwhip max_force 150 reaches primary check",
	)
	_equip_primary(student, SkillIdsScript.SWORD)
	_assert_reason(
		registry,
		SkillIdsScript.SNOWWHIP,
		student,
		PolicyResultScript.Reason.PRIMARY_WEAPON_SKILL_TYPE_MISMATCH,
		"snowwhip exact max_force with primary sword",
	)
	student.equipment.unwield(&"primary")
	_equip_secondary_only(student, SkillIdsScript.WHIP)
	_assert_reason(
		registry,
		SkillIdsScript.SNOWWHIP,
		student,
		PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
		"snowwhip exact max_force with secondary-only whip",
	)
	student.equipment.unwield(&"secondary-only")
	_equip_primary(student, SkillIdsScript.WHIP)
	_assert_allowed(registry, SkillIdsScript.SNOWWHIP, student, "snowwhip exact boundaries")


func _test_dangling_mapping_identity() -> void:
	var registry: RegistryScript = _registry()
	var cases: Array[Array] = [
		[SkillIdsScript.FONXAN_SWORD, SkillIdsScript.FONXAN_FORCE],
		[SkillIdsScript.SNOWSHADE_SWORD, SkillIdsScript.SNOWSHADE_FORCE],
	]
	for case: Array in cases:
		var skill_id: StringName = case[0]
		var mapped_target: StringName = case[1]
		var student: CharacterStateScript = _valid_student(skill_id)
		_equip_primary(student, SkillIdsScript.SWORD)
		_assert_true(student.skills.remove_skill(mapped_target), "%s removes mapped raw target" % skill_id)
		_assert_eq(
			student.skills.mapped_skill(SkillIdsScript.FORCE),
			mapped_target,
			"%s preserves dangling mapped identity" % skill_id,
		)
		_assert_allowed(
			registry,
			skill_id,
			student,
			"%s LPC mapping check does not require raw mapped target" % skill_id,
		)


func _test_remaining_dependency_boundaries() -> void:
	var registry: RegistryScript = _registry()
	for occupied: bool in [false, true]:
		var tender: CharacterStateScript = CharacterStateScript.new()
		if occupied:
			_equip_primary(tender, SkillIdsScript.SWORD)
		_assert_status(
			registry,
			SkillIdsScript.TENDERZHI,
			tender,
			PolicyResultScript.Status.REJECTED,
			PolicyResultScript.Reason.GENDER_MISMATCH,
			"tenderzhi unresolved gender remains first with occupied=%s" % occupied,
		)

	var nine_moon: CharacterStateScript = CharacterStateScript.new()
	nine_moon.recovery.inner_force.maximum = 50
	nine_moon.skills.set_raw_level(SkillIdsScript.NINE_MOON_FORCE, 1)
	nine_moon.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.NINE_MOON_FORCE)
	_equip_primary(nine_moon, SkillIdsScript.SWORD)
	_assert_status(
		registry,
		SkillIdsScript.NINE_MOON,
		nine_moon,
		PolicyResultScript.Status.DEPENDENCY_UNAVAILABLE,
		PolicyResultScript.Reason.LEGACY_REQUIRED_SKILL_MISSING,
		"nine-moon remains blocked despite representable equipment fact",
	)


func _test_equipment_and_policy_state_isolation() -> void:
	var registry: RegistryScript = _registry()
	var armed: CharacterStateScript = _valid_student(SkillIdsScript.BLOODY_STRIKE)
	var empty: CharacterStateScript = _valid_student(SkillIdsScript.BLOODY_STRIKE)
	_equip_primary(armed, SkillIdsScript.SWORD)
	_assert_reason(registry, SkillIdsScript.BLOODY_STRIKE, armed, PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY, "armed character remains isolated")
	_assert_allowed(registry, SkillIdsScript.BLOODY_STRIKE, empty, "empty character does not share equipment")
	_assert_false(empty.equipment.primary_weapon() != null, "independent equipment state remains empty")


func _test_policy_evaluation_is_read_only() -> void:
	var registry: RegistryScript = _registry()
	var student: CharacterStateScript = _valid_student(SkillIdsScript.DEISWORD)
	_equip_secondary_only(student, SkillIdsScript.SWORD)
	var secondary_before: EquippedWeaponRefScript = student.equipment.secondary_weapon()
	_assert_eq(student.equipment.primary_weapon(), null, "read-only setup has no primary")
	_assert_reason(
		registry,
		SkillIdsScript.BLOODY_STRIKE,
		student,
		PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY,
		"empty-hand policy reads occupied secondary",
	)
	_assert_reason(
		registry,
		SkillIdsScript.DEISWORD,
		student,
		PolicyResultScript.Reason.PRIMARY_WEAPON_MISSING,
		"primary-type policy reads missing primary",
	)
	var secondary_after: EquippedWeaponRefScript = student.equipment.secondary_weapon()
	_assert_eq(student.equipment.primary_weapon(), null, "policy evaluation does not create primary")
	_assert_eq(
		secondary_after.instance_id,
		secondary_before.instance_id,
		"policy evaluation preserves secondary instance",
	)
	_assert_eq(
		secondary_after.skill_type,
		secondary_before.skill_type,
		"policy evaluation preserves secondary type",
	)


func _test_learn_service_equipment_rejection() -> void:
	var registry: RegistryScript = _registry()
	var student: CharacterStateScript = _learn_student()
	_equip_primary(student, SkillIdsScript.SWORD)
	var context: TeachingContextScript = _learn_context(SkillIdsScript.BLOODY_STRIKE)
	var result: LearnResultScript = LearnServiceScript.learn(
		student,
		context,
		_skill_definition(SkillIdsScript.BLOODY_STRIKE),
		registry.policy_for(SkillIdsScript.BLOODY_STRIKE),
	)
	_assert_eq(result.failure_reason, LearnResultScript.FailureReason.SKILL_LEARN_REJECTED, "equipment rejects at valid_learn boundary")
	_assert_eq(result.skill_learn_policy_result.reason, PolicyResultScript.Reason.WEAPON_REFERENCES_NOT_EMPTY, "LearnResult carries equipment reason")
	_assert_false(student.skills.has_raw_level(SkillIdsScript.BLOODY_STRIKE), "equipment rejection creates no raw-zero entry")
	_assert_eq(student.progression.potential_spent, 0, "equipment rejection spends no potential")
	_assert_eq(context.current_spirit, 100, "equipment rejection pays no teacher spirit")
	_assert_eq(student.essence.current, 100, "equipment rejection damages no student gin")
	_assert_eq(student.skills.learned_progress(SkillIdsScript.BLOODY_STRIKE), 0, "equipment rejection calls no improve_skill")
	_assert_eq(result.skill_improvement, null, "equipment rejection has no improvement result")


func _test_learn_service_empty_hand_policy_success() -> void:
	var registry: RegistryScript = _registry()
	var student: CharacterStateScript = _learn_student()
	var context: TeachingContextScript = _learn_context(SkillIdsScript.BLOODY_STRIKE)
	var result: LearnResultScript = LearnServiceScript.learn(
		student,
		context,
		_skill_definition(SkillIdsScript.BLOODY_STRIKE),
		registry.policy_for(SkillIdsScript.BLOODY_STRIKE),
	)
	_assert_true(result.success, "newly executable empty-hand policy completes Learn")
	_assert_eq(result.completion, LearnResultScript.Completion.PROGRESSED, "empty-hand normal Learn completion")
	_assert_eq(result.skill_learn_policy_result.status, PolicyResultScript.Status.ALLOWED, "empty-hand policy allowed")
	_assert_eq(student.progression.potential_spent, 1, "successful empty-hand Learn spends potential")
	_assert_eq(student.skills.learned_progress(SkillIdsScript.BLOODY_STRIKE), 1, "successful empty-hand Learn improves skill")
	_assert_eq(context.current_spirit, 87, "empty-hand Learn pays exact teacher spirit cost")
	_assert_eq(student.essence.current, 40, "empty-hand Learn pays doubled new-skill gin cost")
	_assert_true(result.skill_improvement != null, "empty-hand Learn exposes improvement result")
	_assert_true(result.authored_effect != null, "empty-hand Learn applies authored-effect boundary")


func _test_learn_service_primary_sword_policy_success() -> void:
	var registry: RegistryScript = _registry()
	var student: CharacterStateScript = _learn_student()
	student.recovery.inner_force.maximum = 50
	_equip_primary(student, SkillIdsScript.SWORD)
	var context: TeachingContextScript = _learn_context(SkillIdsScript.DEISWORD)
	var result: LearnResultScript = LearnServiceScript.learn(
		student,
		context,
		_skill_definition(SkillIdsScript.DEISWORD),
		registry.policy_for(SkillIdsScript.DEISWORD),
	)
	_assert_true(result.success, "newly executable deisword policy completes Learn")
	_assert_eq(result.completion, LearnResultScript.Completion.PROGRESSED, "deisword normal Learn completion")
	_assert_eq(result.skill_learn_policy_result.status, PolicyResultScript.Status.ALLOWED, "deisword policy allowed")
	_assert_eq(student.progression.potential_spent, 1, "successful deisword Learn spends potential")
	_assert_eq(student.skills.learned_progress(SkillIdsScript.DEISWORD), 1, "successful deisword Learn improves skill")
	_assert_eq(context.current_spirit, 87, "player-style teacher pays exact spirit cost after policy")
	_assert_eq(student.essence.current, 40, "student pays doubled new-skill gin cost")
	_assert_true(result.skill_improvement != null, "deisword Learn exposes improvement result")
	_assert_true(result.authored_effect != null, "deisword Learn applies authored-effect boundary")


func _valid_student(skill_id: StringName) -> CharacterStateScript:
	var student: CharacterStateScript = CharacterStateScript.new()
	student.recovery.inner_force.maximum = 200
	student.skills.set_raw_level(SkillIdsScript.CELESTIAL, 20)
	student.skills.set_raw_level(SkillIdsScript.MYSTFORCE, 30)
	if skill_id == SkillIdsScript.FONXAN_SWORD:
		student.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 1)
		student.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	elif skill_id == SkillIdsScript.SNOWSHADE_SWORD:
		student.skills.set_raw_level(SkillIdsScript.SNOWSHADE_FORCE, 1)
		student.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.SNOWSHADE_FORCE)
	return student


func _equip_primary(student: CharacterStateScript, skill_type: StringName) -> void:
	var result: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"primary", skill_type, false),
		false,
	)
	_assert_true(result.succeeded, "primary setup succeeds for type '%s'" % skill_type)


func _equip_primary_with_secondary(
	student: CharacterStateScript,
	primary_skill_type: StringName,
	secondary_skill_type: StringName,
) -> void:
	_equip_primary(student, primary_skill_type)
	var result: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"secondary", secondary_skill_type, true),
		false,
	)
	_assert_true(result.succeeded, "secondary setup succeeds")


func _equip_secondary_only(student: CharacterStateScript, skill_type: StringName) -> void:
	var first: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"secondary-only", skill_type, true),
		false,
	)
	_assert_true(first.succeeded, "secondary-only source starts in primary")
	var replacement: EquipmentTransitionResultScript = student.equipment.wield(
		_weapon(&"replacement", &"replacement-type", false),
		false,
	)
	_assert_true(replacement.succeeded, "secondary-only source is moved to secondary")
	var removed: EquipmentTransitionResultScript = student.equipment.unwield(&"replacement")
	_assert_true(removed.succeeded, "replacement removal leaves secondary-only state")


func _weapon(
	instance_id: StringName,
	skill_type: StringName,
	can_wield_as_secondary: bool,
	is_two_handed: bool = false,
) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			StringName("weapon.%s" % instance_id),
			skill_type,
			can_wield_as_secondary,
			is_two_handed,
		),
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
		true,
		false,
		false,
		false,
		1,
		TeacherRecognitionPolicyScript.new(),
		TeacherPreventionPolicyScript.new(),
	)


func _skill_definition(skill_id: StringName) -> SkillDefinitionScript:
	return SkillDefinitionScript.new(
		skill_id,
		SkillDefinitionScript.Kind.SPECIALIZED,
		SkillDefinitionScript.Type.MARTIAL,
	)


func _assert_allowed(
	registry: RegistryScript,
	skill_id: StringName,
	student: CharacterStateScript,
	label: String,
) -> void:
	_assert_status(
		registry,
		skill_id,
		student,
		PolicyResultScript.Status.ALLOWED,
		PolicyResultScript.Reason.NONE,
		label,
	)


func _assert_reason(
	registry: RegistryScript,
	skill_id: StringName,
	student: CharacterStateScript,
	expected_reason: int,
	label: String,
) -> void:
	_assert_status(
		registry,
		skill_id,
		student,
		PolicyResultScript.Status.REJECTED,
		expected_reason,
		label,
	)


func _assert_status(
	registry: RegistryScript,
	skill_id: StringName,
	student: CharacterStateScript,
	expected_status: int,
	expected_reason: int,
	label: String,
) -> void:
	var result: PolicyResultScript = registry.policy_for(skill_id).evaluate(student)
	_assert_eq(result.status, expected_status, label + " status")
	_assert_eq(result.reason, expected_reason, label + " reason")


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
