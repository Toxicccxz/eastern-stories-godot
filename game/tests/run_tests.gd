extends SceneTree

const CharacterAttributesScript := preload(
	"res://core/characters/character_base_attributes.gd"
)
const CharacterDerivedValuesScript := preload(
	"res://core/characters/character_derived_values.gd"
)
const CharacterResourceScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterInternalResourceScript := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const CharacterRecoveryStateScript := preload(
	"res://core/characters/character_recovery_state.gd"
)
const RecoverySkillLevelsScript := preload(
	"res://core/characters/recovery_skill_levels.gd"
)
const CharacterRecoveryScript := preload(
	"res://core/characters/character_recovery.gd"
)
const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterStateTest := preload("res://tests/core/character_state_test.gd")
const CharacterRecoveryTest := preload("res://tests/core/character_recovery_test.gd")
const ConditionIdsScript := preload("res://core/conditions/condition_ids.gd")
const ConditionUpdateFlagsScript := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const ConditionPayloadScript := preload("res://core/conditions/condition_payload.gd")
const DurationConditionPayloadScript := preload(
	"res://core/conditions/duration_condition_payload.gd"
)
const PoisonConditionPayloadScript := preload(
	"res://core/conditions/poison_condition_payload.gd"
)
const CharacterConditionStateScript := preload(
	"res://core/conditions/character_condition_state.gd"
)
const ConditionEffectScript := preload("res://core/conditions/condition_effect.gd")
const ConditionUpdateResultScript := preload(
	"res://core/conditions/condition_update_result.gd"
)
const SnakePoisonConditionEffectScript := preload(
	"res://core/conditions/effects/snake_poison_condition_effect.gd"
)
const BandagedConditionEffectScript := preload(
	"res://core/conditions/effects/bandaged_condition_effect.gd"
)
const ConditionSystemScript := preload("res://core/conditions/condition_system.gd")
const NoHealConditionEffectScript := preload(
	"res://tests/support/no_heal_condition_effect.gd"
)
const ConditionSystemTest := preload("res://tests/core/condition_system_test.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const SkillUseIdsScript := preload("res://core/skills/skill_use_ids.gd")
const SkillDefinitionScript := preload("res://core/skills/skill_definition.gd")
const SkillProgressStateScript := preload("res://core/skills/skill_progress_state.gd")
const SkillLoadoutScript := preload("res://core/skills/skill_loadout.gd")
const CharacterSkillStateScript := preload("res://core/skills/character_skill_state.gd")
const SkillMappingChangeResultScript := preload(
	"res://core/skills/skill_mapping_change_result.gd"
)
const SkillEnableTransitionScript := preload("res://core/skills/skill_enable_transition.gd")
const RecoverySkillLevelsAdapterScript := preload(
	"res://core/skills/recovery_skill_levels_adapter.gd"
)
const SkillCoreTest := preload("res://tests/core/skill_core_test.gd")
const CultivationResultScript := preload("res://core/cultivation/cultivation_result.gd")
const CultivationServiceScript := preload("res://core/cultivation/cultivation_service.gd")
const CultivationServiceTest := preload("res://tests/core/cultivation_service_test.gd")
const CharacterProgressionStateScript := preload(
	"res://core/characters/character_progression_state.gd"
)
const PracticePolicyScript := preload("res://core/training/practice_policy.gd")
const VitalityInnerForcePracticePolicyScript := preload(
	"res://core/training/vitality_inner_force_practice_policy.gd"
)
const UnpracticeablePracticePolicyScript := preload(
	"res://core/training/unpracticeable_practice_policy.gd"
)
const PracticePoliciesScript := preload("res://core/training/practice_policies.gd")
const PracticeResultScript := preload("res://core/training/practice_result.gd")
const PracticeServiceScript := preload("res://core/training/practice_service.gd")
const SelfLearningResultScript := preload("res://core/training/self_learning_result.gd")
const SelfLearningServiceScript := preload("res://core/training/self_learning_service.gd")
const PracticeSelfLearningTest := preload(
	"res://tests/core/practice_self_learning_test.gd"
)
const SkillImprovementResultScript := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const SkillImprovementEffectResultScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)
const SkillImprovementEffectScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect.gd"
)
const PeriodicAttributeImprovementEffectScript := preload(
	"res://core/skills/improvement_effects/periodic_attribute_improvement_effect.gd"
)
const BellicosityImprovementEffectScript := preload(
	"res://core/skills/improvement_effects/bellicosity_improvement_effect.gd"
)
const NineMoonImprovementEffectScript := preload(
	"res://core/skills/improvement_effects/nine_moon_improvement_effect.gd"
)
const SkillImprovementEffectRegistryScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const SkillImprovementEffectsTest := preload(
	"res://tests/core/skill_improvement_effects_test.gd"
)
const FamilyStateScript := preload("res://core/relationships/family_state.gd")
const ApprenticeshipStateScript := preload(
	"res://core/relationships/apprenticeship_state.gd"
)
const TeachingOfferScript := preload("res://core/learning/teaching_offer.gd")
const TeacherDefinitionScript := preload("res://core/learning/teacher_definition.gd")
const TeacherPolicyResultScript := preload("res://core/learning/teacher_policy_result.gd")
const TeacherRecognitionPolicyScript := preload(
	"res://core/learning/teacher_recognition_policy.gd"
)
const ExplicitTeacherRecognitionPolicyScript := preload(
	"res://core/learning/explicit_teacher_recognition_policy.gd"
)
const DependencyUnavailableTeacherRecognitionPolicyScript := preload(
	"res://core/learning/dependency_unavailable_teacher_recognition_policy.gd"
)
const TeacherPreventionPolicyScript := preload(
	"res://core/learning/teacher_prevention_policy.gd"
)
const DependencyUnavailableTeacherPreventionPolicyScript := preload(
	"res://core/learning/dependency_unavailable_teacher_prevention_policy.gd"
)
const FMasterTeacherPreventionPolicyScript := preload(
	"res://core/learning/f_master_teacher_prevention_policy.gd"
)
const SkillLearnPolicyResultScript := preload(
	"res://core/learning/skill_learn_policy_result.gd"
)
const SkillLearnPolicyScript := preload("res://core/learning/skill_learn_policy.gd")
const DefaultSkillLearnPolicyScript := preload(
	"res://core/learning/default_skill_learn_policy.gd"
)
const MinimumInnerForceSkillLearnPolicyScript := preload(
	"res://core/learning/minimum_inner_force_skill_learn_policy.gd"
)
const DependencyUnavailableSkillLearnPolicyScript := preload(
	"res://core/learning/dependency_unavailable_skill_learn_policy.gd"
)
const MaximumBellicositySkillLearnPolicyScript := preload(
	"res://core/learning/maximum_bellicosity_skill_learn_policy.gd"
)
const ScaledBellicositySkillLearnPolicyScript := preload(
	"res://core/learning/scaled_bellicosity_skill_learn_policy.gd"
)
const StrengthForceSkillLearnPolicyScript := preload(
	"res://core/learning/strength_force_skill_learn_policy.gd"
)
const ScaledMaximumManaSkillLearnPolicyScript := preload(
	"res://core/learning/scaled_maximum_mana_skill_learn_policy.gd"
)
const MinimumRawSkillLearnPolicyScript := preload(
	"res://core/learning/minimum_raw_skill_learn_policy.gd"
)
const MinimumEffectiveSkillLearnPolicyScript := preload(
	"res://core/learning/minimum_effective_skill_learn_policy.gd"
)
const MinimumEffectiveSkillRatioLearnPolicyScript := preload(
	"res://core/learning/minimum_effective_skill_ratio_learn_policy.gd"
)
const StrictlyGreaterEffectiveSkillLearnPolicyScript := preload(
	"res://core/learning/strictly_greater_effective_skill_learn_policy.gd"
)
const RequiredMappedSkillLearnPolicyScript := preload(
	"res://core/learning/required_mapped_skill_learn_policy.gd"
)
const OrderedSkillLearnPolicyScript := preload(
	"res://core/learning/ordered_skill_learn_policy.gd"
)
const RequireBothWeaponRefsEmptySkillLearnPolicyScript := preload(
	"res://core/learning/require_both_weapon_refs_empty_skill_learn_policy.gd"
)
const RequirePrimaryWeaponSkillTypeSkillLearnPolicyScript := preload(
	"res://core/learning/require_primary_weapon_skill_type_skill_learn_policy.gd"
)
const SkillLearnPolicyRegistryScript := preload(
	"res://core/learning/skill_learn_policy_registry.gd"
)
const TeachingContextScript := preload("res://core/learning/teaching_context.gd")
const LearnResultScript := preload("res://core/learning/learn_result.gd")
const LearnServiceScript := preload("res://core/learning/learn_service.gd")
const ObservingImprovementEffectScript := preload(
	"res://tests/support/observing_improvement_effect.gd"
)
const CountingTeacherRecognitionPolicyScript := preload(
	"res://tests/support/counting_teacher_recognition_policy.gd"
)
const LearnServiceTest := preload("res://tests/core/learn_service_test.gd")
const SkillLearnPoliciesTest := preload("res://tests/core/skill_learn_policies_test.gd")
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")
const EquipmentTransitionResultScript := preload(
	"res://core/equipment/equipment_transition_result.gd"
)
const EquipmentStateScript := preload("res://core/equipment/equipment_state.gd")
const EquipmentStateTest := preload("res://tests/core/equipment_state_test.gd")
const EquipmentSkillLearnPoliciesTest := preload(
	"res://tests/core/equipment_skill_learn_policies_test.gd"
)


func _init() -> void:
	var phase_scripts: Array[Script] = [
		CharacterAttributesScript,
		CharacterDerivedValuesScript,
		CharacterResourceScript,
		CharacterInternalResourceScript,
		CharacterRecoveryStateScript,
		RecoverySkillLevelsScript,
		CharacterRecoveryScript,
		CharacterStateScript,
		CharacterStateTest,
		CharacterRecoveryTest,
		ConditionIdsScript,
		ConditionUpdateFlagsScript,
		ConditionPayloadScript,
		DurationConditionPayloadScript,
		PoisonConditionPayloadScript,
		CharacterConditionStateScript,
		ConditionEffectScript,
		ConditionUpdateResultScript,
		SnakePoisonConditionEffectScript,
		BandagedConditionEffectScript,
		ConditionSystemScript,
		NoHealConditionEffectScript,
		ConditionSystemTest,
		SkillIdsScript,
		SkillUseIdsScript,
		SkillDefinitionScript,
		SkillProgressStateScript,
		SkillLoadoutScript,
		CharacterSkillStateScript,
		SkillMappingChangeResultScript,
		SkillEnableTransitionScript,
		RecoverySkillLevelsAdapterScript,
		SkillCoreTest,
		CultivationResultScript,
		CultivationServiceScript,
		CultivationServiceTest,
		CharacterProgressionStateScript,
		PracticePolicyScript,
		VitalityInnerForcePracticePolicyScript,
		UnpracticeablePracticePolicyScript,
		PracticePoliciesScript,
		PracticeResultScript,
		PracticeServiceScript,
		SelfLearningResultScript,
		SelfLearningServiceScript,
		PracticeSelfLearningTest,
		SkillImprovementResultScript,
		SkillImprovementEffectResultScript,
		SkillImprovementEffectScript,
		PeriodicAttributeImprovementEffectScript,
		BellicosityImprovementEffectScript,
		NineMoonImprovementEffectScript,
		SkillImprovementEffectRegistryScript,
		SkillImprovementEffectsTest,
		FamilyStateScript,
		ApprenticeshipStateScript,
		TeachingOfferScript,
		TeacherDefinitionScript,
		TeacherPolicyResultScript,
		TeacherRecognitionPolicyScript,
		ExplicitTeacherRecognitionPolicyScript,
		DependencyUnavailableTeacherRecognitionPolicyScript,
		TeacherPreventionPolicyScript,
		DependencyUnavailableTeacherPreventionPolicyScript,
		FMasterTeacherPreventionPolicyScript,
		SkillLearnPolicyResultScript,
		SkillLearnPolicyScript,
		DefaultSkillLearnPolicyScript,
		MinimumInnerForceSkillLearnPolicyScript,
		DependencyUnavailableSkillLearnPolicyScript,
		MaximumBellicositySkillLearnPolicyScript,
		ScaledBellicositySkillLearnPolicyScript,
		StrengthForceSkillLearnPolicyScript,
		ScaledMaximumManaSkillLearnPolicyScript,
		MinimumRawSkillLearnPolicyScript,
		MinimumEffectiveSkillLearnPolicyScript,
		MinimumEffectiveSkillRatioLearnPolicyScript,
		StrictlyGreaterEffectiveSkillLearnPolicyScript,
		RequiredMappedSkillLearnPolicyScript,
		OrderedSkillLearnPolicyScript,
		RequireBothWeaponRefsEmptySkillLearnPolicyScript,
		RequirePrimaryWeaponSkillTypeSkillLearnPolicyScript,
		SkillLearnPolicyRegistryScript,
		TeachingContextScript,
		LearnResultScript,
		LearnServiceScript,
		ObservingImprovementEffectScript,
		CountingTeacherRecognitionPolicyScript,
		LearnServiceTest,
		SkillLearnPoliciesTest,
		WeaponDefinitionScript,
		EquippedWeaponRefScript,
		EquipmentTransitionResultScript,
		EquipmentStateScript,
		EquipmentStateTest,
		EquipmentSkillLearnPoliciesTest,
	]
	for script: Script in phase_scripts:
		if not script.can_instantiate():
			printerr("FAIL: character domain script cannot be instantiated: %s" % script.resource_path)
			quit(1)
			return

	var phase_1_result: Dictionary[String, Variant] = CharacterStateTest.new().run_all()
	var phase_2a_result: Dictionary[String, Variant] = CharacterRecoveryTest.new().run_all()
	var phase_2b_result: Dictionary[String, Variant] = ConditionSystemTest.new().run_all()
	var phase_3a_result: Dictionary[String, Variant] = SkillCoreTest.new().run_all()
	var phase_3b1_result: Dictionary[String, Variant] = CultivationServiceTest.new().run_all()
	var phase_3b2_result: Dictionary[String, Variant] = PracticeSelfLearningTest.new().run_all()
	var phase_3b3_result: Dictionary[String, Variant] = SkillImprovementEffectsTest.new().run_all()
	var phase_3c1_result: Dictionary[String, Variant] = LearnServiceTest.new().run_all()
	var phase_3c2_result: Dictionary[String, Variant] = SkillLearnPoliciesTest.new().run_all()
	var phase_4a1_result: Dictionary[String, Variant] = EquipmentStateTest.new().run_all()
	var phase_4a2_result: Dictionary[String, Variant] = (
		EquipmentSkillLearnPoliciesTest.new().run_all()
	)
	var assertion_count: int = int(phase_1_result["assertions"]) + int(
		phase_2a_result["assertions"]
	) + int(phase_2b_result["assertions"]) + int(phase_3a_result["assertions"]) + int(
		phase_3b1_result["assertions"]
	) + int(
		phase_3b2_result["assertions"]
	) + int(
		phase_3b3_result["assertions"]
	) + int(
		phase_3c1_result["assertions"]
	) + int(
		phase_3c2_result["assertions"]
	) + int(
		phase_4a1_result["assertions"]
	) + int(
		phase_4a2_result["assertions"]
	)
	var failures: Array[String] = phase_1_result["failures"]
	failures.append_array(phase_2a_result["failures"])
	failures.append_array(phase_2b_result["failures"])
	failures.append_array(phase_3a_result["failures"])
	failures.append_array(phase_3b1_result["failures"])
	failures.append_array(phase_3b2_result["failures"])
	failures.append_array(phase_3b3_result["failures"])
	failures.append_array(phase_3c1_result["failures"])
	failures.append_array(phase_3c2_result["failures"])
	failures.append_array(phase_4a1_result["failures"])
	failures.append_array(phase_4a2_result["failures"])
	if failures.is_empty():
		print("PASS: %d assertions" % assertion_count)
		quit(0)
		return

	for failure: String in failures:
		push_error(str(failure))
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertion_count])
	quit(1)
