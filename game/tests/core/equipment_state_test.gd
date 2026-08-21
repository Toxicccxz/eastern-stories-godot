extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const EquipmentTransitionResultScript := preload(
	"res://core/equipment/equipment_transition_result.gd"
)
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_default_state_and_character_isolation()
	_test_definition_and_runtime_reference_snapshot()
	_test_equipped_reference_defensive_copy()
	_test_secondary_flag_and_wield_order()
	_test_slot_boundaries_and_duplicate_wield()
	_test_unwield_without_secondary_promotion()
	_test_two_handed_and_shield_quirks()
	_test_weapon_skill_types()
	_test_transition_result_metadata()
	_test_phase_3c2_compatibility_matrix()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_default_state_and_character_isolation() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	_assert_true(equipment.is_primary_hand_empty(), "new primary weapon slot is empty")
	_assert_true(equipment.is_secondary_hand_empty(), "new secondary weapon slot is empty")
	_assert_true(equipment.are_both_hands_empty(), "new equipment has no wielded weapons")
	_assert_eq(equipment.primary_weapon(), null, "new primary reference is null")
	_assert_eq(equipment.secondary_weapon(), null, "new secondary reference is null")
	_assert_eq(equipment.primary_weapon_skill_type(), &"", "empty primary has no skill type")
	_assert_true(equipment is RefCounted, "equipment state is pure RefCounted domain state")
	var equipment_variant: Variant = equipment
	_assert_false(equipment_variant is Node, "equipment state has no Node dependency")

	var first: CharacterStateScript = CharacterStateScript.new()
	var second: CharacterStateScript = CharacterStateScript.new()
	_assert_true(first.equipment != second.equipment, "characters do not share equipment defaults")
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.isolation",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	first.equipment.wield(sword, false)
	_assert_false(first.equipment.is_primary_hand_empty(), "first character owns wielded state")
	_assert_true(second.equipment.are_both_hands_empty(), "second character remains empty")


func _test_definition_and_runtime_reference_snapshot() -> void:
	var definition: WeaponDefinitionScript = WeaponDefinitionScript.new(
		&"weapon.test.short_sword",
		SkillIdsScript.SWORD,
		true,
		false,
		"reference/es2/mudlib/d/oldpine/obj/short_sword.c",
	)
	var reference: EquippedWeaponRefScript = EquippedWeaponRefScript.new(
		&"short_sword.instance.1",
		definition,
	)
	_assert_eq(definition.weapon_id, &"weapon.test.short_sword", "definition stable weapon ID")
	_assert_eq(definition.skill_type, SkillIdsScript.SWORD, "definition authored skill type")
	_assert_true(definition.can_wield_as_secondary, "definition preserves SECONDARY flag")
	_assert_false(definition.is_two_handed, "definition does not invent TWO_HANDED")
	_assert_eq(
		definition.legacy_source_path,
		"reference/es2/mudlib/d/oldpine/obj/short_sword.c",
		"definition legacy traceability",
	)
	_assert_eq(reference.instance_id, &"short_sword.instance.1", "runtime instance identity")
	_assert_eq(reference.weapon_id, definition.weapon_id, "reference snapshots definition ID")
	_assert_eq(reference.skill_type, definition.skill_type, "reference snapshots skill type")
	_assert_eq(
		reference.can_wield_as_secondary,
		definition.can_wield_as_secondary,
		"reference snapshots SECONDARY fact",
	)
	_assert_eq(reference.is_two_handed, definition.is_two_handed, "reference snapshots handedness")
	_assert_eq(
		reference.legacy_source_path,
		definition.legacy_source_path,
		"reference snapshots source metadata",
	)
	## GDScript's underscore privacy is conventional, so deliberately alter the
	## source object to prove EquipmentState refs retain a defensive scalar copy.
	definition._skill_type = SkillIdsScript.BLADE
	definition._can_wield_as_secondary = false
	_assert_eq(reference.skill_type, SkillIdsScript.SWORD, "reference does not retain mutable definition state")
	_assert_true(reference.can_wield_as_secondary, "reference keeps copied SECONDARY fact")
	var independent_definition: WeaponDefinitionScript = WeaponDefinitionScript.new(
		&"weapon.test.independent",
		&"custom-independent-type",
	)
	_assert_eq(
		independent_definition.skill_type,
		&"custom-independent-type",
		"separate definitions do not share authored scalar state",
	)
	_assert_true(reference.is_valid(), "stable definition and instance IDs form a valid reference")
	_assert_false(EquippedWeaponRefScript.new().is_valid(), "empty reference is rejected")
	_assert_true(reference is RefCounted, "weapon reference is pure RefCounted data")
	var reference_variant: Variant = reference
	_assert_false(reference_variant is Node, "weapon reference has no Node dependency")


func _test_equipped_reference_defensive_copy() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var caller_reference: EquippedWeaponRefScript = _weapon(
		&"sword.instance.defensive",
		&"weapon.test.defensive",
		SkillIdsScript.SWORD,
	)
	equipment.wield(caller_reference, false)
	caller_reference._instance_id = &"caller.changed.instance"
	caller_reference._skill_type = SkillIdsScript.WHIP
	_assert_true(
		equipment.has_weapon_instance(&"sword.instance.defensive"),
		"mutating caller-owned reference cannot change equipped identity",
	)
	_assert_eq(
		equipment.primary_weapon_skill_type(),
		SkillIdsScript.SWORD,
		"mutating caller-owned reference cannot change equipped skill type",
	)

	var returned_snapshot: EquippedWeaponRefScript = equipment.primary_weapon()
	returned_snapshot._instance_id = &"returned.changed.instance"
	returned_snapshot._skill_type = SkillIdsScript.BLADE
	_assert_true(
		equipment.has_weapon_instance(&"sword.instance.defensive"),
		"mutating returned snapshot cannot change internal identity",
	)
	_assert_eq(
		equipment.primary_weapon_skill_type(),
		SkillIdsScript.SWORD,
		"mutating returned snapshot cannot change internal skill type",
	)
	_assert_true(
		equipment.primary_weapon() != returned_snapshot,
		"slot queries return defensive snapshots",
	)


func _test_secondary_flag_and_wield_order() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var dagger: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.order",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.order",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	var first_result: EquipmentTransitionResultScript = equipment.wield(dagger, false)
	_assert_transition(
		first_result,
		EquipmentTransitionResultScript.Outcome.WIELDED_PRIMARY,
		true,
		true,
		"first SECONDARY-capable weapon still becomes primary",
	)
	_assert_eq(equipment.primary_weapon().instance_id, dagger.instance_id, "dagger is primary")

	var swap_result: EquipmentTransitionResultScript = equipment.wield(sword, false)
	_assert_transition(
		swap_result,
		EquipmentTransitionResultScript.Outcome.SWAPPED_PRIMARY_TO_SECONDARY,
		true,
		true,
		"non-secondary second weapon displaces secondary-capable primary",
	)
	_assert_eq(equipment.primary_weapon().instance_id, sword.instance_id, "new sword is primary")
	_assert_eq(equipment.secondary_weapon().instance_id, dagger.instance_id, "old dagger moves secondary")
	_assert_eq(swap_result.weapon_instance_id, sword.instance_id, "swap result identifies requested weapon")
	_assert_eq(
		swap_result.previous_primary_instance_id,
		dagger.instance_id,
		"swap result identifies old primary",
	)
	_assert_eq(
		swap_result.affected_slot,
		EquipmentTransitionResultScript.Slot.PRIMARY_AND_SECONDARY,
		"swap result identifies both affected slots",
	)

	var reverse: EquipmentStateScript = EquipmentStateScript.new()
	var reverse_sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.reverse",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	var reverse_dagger: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.reverse",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	reverse.wield(reverse_sword, false)
	var secondary_result: EquipmentTransitionResultScript = reverse.wield(
		reverse_dagger,
		false,
	)
	_assert_transition(
		secondary_result,
		EquipmentTransitionResultScript.Outcome.WIELDED_SECONDARY,
		true,
		true,
		"SECONDARY-capable second weapon fills secondary",
	)
	_assert_eq(reverse.primary_weapon().instance_id, reverse_sword.instance_id, "order keeps sword primary")
	_assert_eq(reverse.secondary_weapon().instance_id, reverse_dagger.instance_id, "order puts dagger secondary")


func _test_slot_boundaries_and_duplicate_wield() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.boundary",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	var whip: EquippedWeaponRefScript = _weapon(
		&"whip.instance.boundary",
		&"weapon.test.whip",
		SkillIdsScript.WHIP,
	)
	equipment.wield(sword, false)
	_assert_transition(
		equipment.wield(whip, false),
		EquipmentTransitionResultScript.Outcome.PRIMARY_MUST_BE_UNWIELDED,
		false,
		false,
		"two non-secondary weapons cannot be combined",
	)
	_assert_true(equipment.is_secondary_hand_empty(), "failed second wield leaves secondary empty")

	var dagger: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.boundary",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	equipment.wield(dagger, false)
	var duplicate: EquipmentTransitionResultScript = equipment.wield(dagger, false)
	_assert_transition(
		duplicate,
		EquipmentTransitionResultScript.Outcome.ALREADY_WIELDED,
		true,
		false,
		"feature wield recognizes already equipped object without mutation",
	)
	_assert_eq(equipment.primary_weapon().instance_id, sword.instance_id, "duplicate does not replace primary")
	_assert_eq(equipment.secondary_weapon().instance_id, dagger.instance_id, "duplicate does not duplicate slot")
	var third: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.third",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	_assert_transition(
		equipment.wield(third, false),
		EquipmentTransitionResultScript.Outcome.NO_FREE_HAND,
		false,
		false,
		"third weapon fails when both weapon slots are occupied",
	)
	_assert_transition(
		equipment.wield(EquippedWeaponRefScript.new(), false),
		EquipmentTransitionResultScript.Outcome.INVALID_WEAPON_REFERENCE,
		false,
		false,
		"invalid stable reference is not wielded",
	)

	var shared_definition: WeaponDefinitionScript = WeaponDefinitionScript.new(
		&"weapon.test.shared_dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	var same_definition_state: EquipmentStateScript = EquipmentStateScript.new()
	var first_copy: EquippedWeaponRefScript = EquippedWeaponRefScript.new(
		&"shared_dagger.instance.1",
		shared_definition,
	)
	var second_copy: EquippedWeaponRefScript = EquippedWeaponRefScript.new(
		&"shared_dagger.instance.2",
		shared_definition,
	)
	same_definition_state.wield(first_copy, false)
	same_definition_state.wield(second_copy, false)
	_assert_eq(
		same_definition_state.primary_weapon().instance_id,
		first_copy.instance_id,
		"first runtime instance of shared definition is primary",
	)
	_assert_eq(
		same_definition_state.secondary_weapon().instance_id,
		second_copy.instance_id,
		"distinct runtime instance of same definition can be secondary",
	)


func _test_unwield_without_secondary_promotion() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.unwield",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	var dagger: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.unwield",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	equipment.wield(sword, false)
	equipment.wield(dagger, false)
	_assert_transition(
		equipment.unwield(sword.instance_id),
		EquipmentTransitionResultScript.Outcome.UNWIELDED_PRIMARY,
		true,
		true,
		"unwield primary succeeds",
	)
	_assert_true(equipment.is_primary_hand_empty(), "primary remains empty after unwield")
	_assert_false(equipment.is_secondary_hand_empty(), "secondary remains occupied")
	_assert_eq(equipment.secondary_weapon().instance_id, dagger.instance_id, "secondary is not promoted")
	_assert_false(equipment.are_both_hands_empty(), "secondary-only state is not empty-handed")

	var blade: EquippedWeaponRefScript = _weapon(
		&"blade.instance.unwield",
		&"weapon.test.blade",
		SkillIdsScript.BLADE,
	)
	_assert_transition(
		equipment.wield(blade, false),
		EquipmentTransitionResultScript.Outcome.WIELDED_PRIMARY,
		true,
		true,
		"empty primary fills even while secondary remains occupied",
	)
	_assert_transition(
		equipment.unwield(dagger.instance_id),
		EquipmentTransitionResultScript.Outcome.UNWIELDED_SECONDARY,
		true,
		true,
		"unwield secondary succeeds",
	)
	_assert_true(equipment.is_secondary_hand_empty(), "secondary clears independently")
	_assert_transition(
		equipment.unwield(dagger.instance_id),
		EquipmentTransitionResultScript.Outcome.NOT_WIELDED,
		false,
		false,
		"unwield missing instance fails without mutation",
	)


func _test_two_handed_and_shield_quirks() -> void:
	var two_handed: EquippedWeaponRefScript = _weapon(
		&"axe.instance.two_handed",
		&"weapon.test.lumber_axe",
		SkillIdsScript.AXE,
		false,
		true,
	)
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	_assert_transition(
		equipment.wield(two_handed, false),
		EquipmentTransitionResultScript.Outcome.WIELDED_PRIMARY,
		true,
		true,
		"two-handed weapon starts in primary when both slots are empty",
	)
	_assert_true(
		equipment.is_secondary_hand_empty(),
		"LPC TWO_HANDED does not write secondary_weapon",
	)
	var dagger: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.after_two_handed",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	_assert_transition(
		equipment.wield(dagger, false),
		EquipmentTransitionResultScript.Outcome.WIELDED_SECONDARY,
		true,
		true,
		"legacy code permits SECONDARY weapon after a two-handed primary",
	)

	var combined_flags: EquipmentStateScript = EquipmentStateScript.new()
	var two_handed_secondary: EquippedWeaponRefScript = _weapon(
		&"axe.instance.combined_flags",
		&"weapon.test.combined_flags",
		SkillIdsScript.AXE,
		true,
		true,
	)
	combined_flags.wield(two_handed_secondary, false)
	var replacement_sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.combined_replacement",
		&"weapon.test.combined_replacement",
		SkillIdsScript.SWORD,
	)
	_assert_transition(
		combined_flags.wield(replacement_sword, false),
		EquipmentTransitionResultScript.Outcome.REPLACED_TWO_HANDED_PRIMARY,
		true,
		true,
		"combined TWO_HANDED and SECONDARY old primary fails its legacy re-wield",
	)
	_assert_eq(
		combined_flags.primary_weapon().instance_id,
		replacement_sword.instance_id,
		"combined-flag replacement installs new primary",
	)
	_assert_true(
		combined_flags.is_secondary_hand_empty(),
		"combined-flag old primary remains unequipped after ignored re-wield failure",
	)

	var occupied: EquipmentStateScript = EquipmentStateScript.new()
	occupied.wield(dagger, false)
	_assert_transition(
		occupied.wield(two_handed, false),
		EquipmentTransitionResultScript.Outcome.TWO_HANDED_REQUIRES_EMPTY_HANDS,
		false,
		false,
		"two-handed weapon cannot be wielded after another weapon",
	)
	var shield_only_context: EquipmentStateScript = EquipmentStateScript.new()
	_assert_transition(
		shield_only_context.wield(two_handed, true),
		EquipmentTransitionResultScript.Outcome.TWO_HANDED_REQUIRES_EMPTY_HANDS,
		false,
		false,
		"equipped shield blocks initial two-handed wield",
	)
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.shield",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	_assert_transition(
		shield_only_context.wield(sword, true),
		EquipmentTransitionResultScript.Outcome.WIELDED_PRIMARY,
		true,
		true,
		"shield does not block first one-handed primary",
	)
	_assert_transition(
		shield_only_context.wield(dagger, true),
		EquipmentTransitionResultScript.Outcome.NO_FREE_HAND,
		false,
		false,
		"shield blocks a secondary weapon",
	)


func _test_weapon_skill_types() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.type",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	equipment.wield(sword, false)
	_assert_eq(equipment.primary_weapon_skill_type(), SkillIdsScript.SWORD, "primary sword skill_type")
	equipment.unwield(sword.instance_id)
	var whip: EquippedWeaponRefScript = _weapon(
		&"whip.instance.type",
		&"weapon.test.whip",
		SkillIdsScript.WHIP,
	)
	equipment.wield(whip, false)
	_assert_eq(equipment.primary_weapon_skill_type(), SkillIdsScript.WHIP, "primary whip skill_type")
	equipment.unwield(whip.instance_id)
	var blade: EquippedWeaponRefScript = _weapon(
		&"blade.instance.type",
		&"weapon.test.blade",
		SkillIdsScript.BLADE,
	)
	equipment.wield(blade, false)
	_assert_eq(equipment.primary_weapon_skill_type(), SkillIdsScript.BLADE, "other authored skill_type")
	_assert_true(
		equipment.primary_weapon_skill_type() != SkillIdsScript.SWORD,
		"weapon inheritance is not substituted for skill_type",
	)
	_assert_true(
		equipment.primary_weapon_skill_type() != SkillIdsScript.WHIP,
		"non-whip identifier remains distinct",
	)

	var absent_type_state: EquipmentStateScript = EquipmentStateScript.new()
	var absent_type: EquippedWeaponRefScript = _weapon(
		&"weapon.instance.absent_type",
		&"weapon.test.absent_type",
		&"",
	)
	_assert_true(absent_type.is_valid(), "empty skill_type does not invalidate stable weapon identity")
	absent_type_state.wield(absent_type, false)
	_assert_false(absent_type_state.is_primary_hand_empty(), "empty skill_type weapon still occupies primary")
	_assert_eq(absent_type_state.primary_weapon_skill_type(), &"", "absent authored skill_type is preserved")

	var custom_type_state: EquipmentStateScript = EquipmentStateScript.new()
	var custom_type: EquippedWeaponRefScript = _weapon(
		&"weapon.instance.custom_type",
		&"weapon.test.custom_type",
		&"custom-polearm",
	)
	custom_type_state.wield(custom_type, false)
	_assert_eq(
		custom_type_state.primary_weapon_skill_type(),
		&"custom-polearm",
		"unexpected authored skill_type remains an open stable ID",
	)


func _test_transition_result_metadata() -> void:
	var equipment: EquipmentStateScript = EquipmentStateScript.new()
	var sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.result",
		&"weapon.test.result",
		SkillIdsScript.SWORD,
	)
	var wield_result: EquipmentTransitionResultScript = equipment.wield(sword, false)
	_assert_eq(wield_result.weapon_instance_id, sword.instance_id, "wield result stable instance ID")
	_assert_eq(
		wield_result.affected_slot,
		EquipmentTransitionResultScript.Slot.PRIMARY,
		"wield result affected primary slot",
	)
	_assert_eq(wield_result.previous_primary_instance_id, &"", "ordinary wield has no displaced primary")
	var duplicate_result: EquipmentTransitionResultScript = equipment.wield(sword, false)
	_assert_eq(duplicate_result.weapon_instance_id, sword.instance_id, "duplicate result stable instance ID")
	_assert_eq(
		duplicate_result.affected_slot,
		EquipmentTransitionResultScript.Slot.PRIMARY,
		"duplicate result reports existing slot despite no mutation",
	)
	var unwield_result: EquipmentTransitionResultScript = equipment.unwield(sword.instance_id)
	_assert_eq(unwield_result.weapon_instance_id, sword.instance_id, "unwield result stable instance ID")
	_assert_eq(
		unwield_result.affected_slot,
		EquipmentTransitionResultScript.Slot.PRIMARY,
		"unwield result affected primary slot",
	)
	var missing_result: EquipmentTransitionResultScript = equipment.unwield(&"missing.instance")
	_assert_eq(missing_result.weapon_instance_id, &"missing.instance", "failed result retains requested ID")
	_assert_eq(
		missing_result.affected_slot,
		EquipmentTransitionResultScript.Slot.NONE,
		"failed result reports no affected slot",
	)


func _test_phase_3c2_compatibility_matrix() -> void:
	var empty: EquipmentStateScript = EquipmentStateScript.new()
	var empty_hand_skill_ids: Array[StringName] = [
		SkillIdsScript.BLOODY_STRIKE,
		SkillIdsScript.CELESTRIKE,
		SkillIdsScript.LIUH_KEN,
		SkillIdsScript.MEIHUA_SHOU,
		SkillIdsScript.SPICYCLAW,
		SkillIdsScript.TENDERZHI,
		SkillIdsScript.TS_FIST,
	]
	for skill_id: StringName in empty_hand_skill_ids:
		_assert_true(empty.are_both_hands_empty(), "%s can observe both weapon slots empty" % skill_id)

	var sword_state: EquipmentStateScript = EquipmentStateScript.new()
	sword_state.wield(
		_weapon(&"sword.instance.matrix", &"weapon.test.sword", SkillIdsScript.SWORD),
		false,
	)
	var sword_skill_ids: Array[StringName] = [
		SkillIdsScript.DEISWORD,
		SkillIdsScript.FONXAN_SWORD,
		SkillIdsScript.MYSTSWORD,
		SkillIdsScript.SIX_CHAOS_SWORD,
		SkillIdsScript.SNOWSHADE_SWORD,
	]
	for skill_id: StringName in sword_skill_ids:
		_assert_eq(
			sword_state.primary_weapon_skill_type(),
			SkillIdsScript.SWORD,
			"%s can observe primary sword" % skill_id,
		)

	var whip_state: EquipmentStateScript = EquipmentStateScript.new()
	whip_state.wield(
		_weapon(&"whip.instance.matrix", &"weapon.test.whip", SkillIdsScript.WHIP),
		false,
	)
	_assert_eq(
		whip_state.primary_weapon_skill_type(),
		SkillIdsScript.WHIP,
		"snowwhip can observe primary whip",
	)

	var other_state: EquipmentStateScript = EquipmentStateScript.new()
	other_state.wield(
		_weapon(&"blade.instance.matrix", &"weapon.test.blade", SkillIdsScript.BLADE),
		false,
	)
	_assert_false(other_state.is_primary_hand_empty(), "matrix represents primary occupied only")
	_assert_true(other_state.is_secondary_hand_empty(), "matrix primary-only secondary empty")
	_assert_eq(other_state.primary_weapon_skill_type(), SkillIdsScript.BLADE, "matrix distinguishes other type")

	var secondary_only: EquipmentStateScript = EquipmentStateScript.new()
	var secondary_dagger: EquippedWeaponRefScript = _weapon(
		&"dagger.instance.matrix",
		&"weapon.test.dagger",
		SkillIdsScript.DAGGER,
		true,
	)
	var primary_sword: EquippedWeaponRefScript = _weapon(
		&"sword.instance.secondary_matrix",
		&"weapon.test.sword",
		SkillIdsScript.SWORD,
	)
	secondary_only.wield(primary_sword, false)
	secondary_only.wield(secondary_dagger, false)
	secondary_only.unwield(primary_sword.instance_id)
	_assert_true(secondary_only.is_primary_hand_empty(), "matrix represents secondary-only state")
	_assert_false(secondary_only.is_secondary_hand_empty(), "matrix observes secondary presence")
	_assert_false(secondary_only.are_both_hands_empty(), "secondary presence fails empty-hand fact")
	for skill_id: StringName in empty_hand_skill_ids:
		_assert_false(
			secondary_only.are_both_hands_empty(),
			"%s detects secondary weapon even without primary" % skill_id,
		)

	var both: EquipmentStateScript = EquipmentStateScript.new()
	both.wield(primary_sword, false)
	both.wield(secondary_dagger, false)
	_assert_false(both.is_primary_hand_empty(), "matrix represents both primary and secondary occupied")
	_assert_false(both.is_secondary_hand_empty(), "matrix both-slots secondary occupied")


func _weapon(
	instance_id: StringName,
	weapon_id: StringName,
	skill_type: StringName,
	can_wield_as_secondary: bool = false,
	is_two_handed: bool = false,
) -> EquippedWeaponRefScript:
	return EquippedWeaponRefScript.new(
		instance_id,
		WeaponDefinitionScript.new(
			weapon_id,
			skill_type,
			can_wield_as_secondary,
			is_two_handed,
			"reference/es2/mudlib/test-fixture",
		),
	)


func _assert_transition(
	result: EquipmentTransitionResultScript,
	expected_outcome: int,
	expected_succeeded: bool,
	expected_changed: bool,
	label: String,
) -> void:
	_assert_eq(result.outcome, expected_outcome, label + " outcome")
	_assert_eq(result.succeeded, expected_succeeded, label + " succeeded")
	_assert_eq(result.changed, expected_changed, label + " changed")


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
