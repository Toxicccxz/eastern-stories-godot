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
const ObservingPracticePolicyScript := preload(
	"res://tests/support/observing_practice_policy.gd"
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
const RequiredGenderSkillLearnPolicyScript := preload(
	"res://core/learning/required_gender_skill_learn_policy.gd"
)
const MinimumBaseSpiritualitySkillLearnPolicyScript := preload(
	"res://core/learning/minimum_base_spirituality_skill_learn_policy.gd"
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
const GenderLearnPoliciesTest := preload(
	"res://tests/core/gender_learn_policies_test.gd"
)
const ItemDefinitionScript := preload("res://core/items/item_definition.gd")
const ItemInstanceScript := preload("res://core/items/item_instance.gd")
const ItemIdentityTest := preload("res://tests/core/item_identity_test.gd")
const ContainmentEndpointScript := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const InventoryTransferDestinationScript := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const InventoryTransferResultScript := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const InventoryStateScript := preload("res://core/inventory/inventory_state.gd")
const InventoryTransferServiceScript := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const InventoryContainmentTransferTest := preload(
	"res://tests/core/inventory_containment_transfer_test.gd"
)
const CombinedStackDefinitionScript := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const CombinedStackStateScript := preload(
	"res://core/items/combined/combined_stack_state.gd"
)
const CombinedStackCollectionScript := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const CombinedStackAmountResultScript := preload(
	"res://core/items/combined/combined_stack_amount_result.gd"
)
const CombinedStackSplitResultScript := preload(
	"res://core/items/combined/combined_stack_split_result.gd"
)
const CombinedStackMergeResultScript := preload(
	"res://core/items/combined/combined_stack_merge_result.gd"
)
const CombinedStackServiceScript := preload(
	"res://core/items/combined/combined_stack_service.gd"
)
const CurrencyDefinitionScript := preload(
	"res://core/items/combined/currency_definition.gd"
)
const CombinedStackCurrencyTest := preload(
	"res://tests/core/combined_stack_currency_test.gd"
)
const ArmorNumericModifiersScript := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const EquippedArmorRefScript := preload("res://core/armor/equipped_armor_ref.gd")
const ArmorTransitionResultScript := preload(
	"res://core/armor/armor_transition_result.gd"
)
const ArmorStateScript := preload("res://core/armor/armor_state.gd")
const ArmorServiceScript := preload("res://core/armor/armor_service.gd")
const ArmorFoundationTest := preload("res://tests/core/armor_foundation_test.gd")
const NativeItemRecordScript := preload(
	"res://core/persistence/native_item_record.gd"
)
const NativeCombinedStackRecordScript := preload(
	"res://core/persistence/native_combined_stack_record.gd"
)
const NativeCharacterEquipmentRecordScript := preload(
	"res://core/persistence/native_character_equipment_record.gd"
)
const NativeArmorSlotRecordScript := preload(
	"res://core/persistence/native_armor_slot_record.gd"
)
const NativeCharacterArmorRecordScript := preload(
	"res://core/persistence/native_character_armor_record.gd"
)
const NativeItemStateSnapshotScript := preload(
	"res://core/persistence/native_item_state_snapshot.gd"
)
const NativeItemDefinitionProjectionsScript := preload(
	"res://core/persistence/native_item_definition_projections.gd"
)
const NativeCharacterEquipmentSourceScript := preload(
	"res://core/persistence/native_character_equipment_source.gd"
)
const NativeCharacterArmorSourceScript := preload(
	"res://core/persistence/native_character_armor_source.gd"
)
const NativeItemStateValidationResultScript := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)
const NativeItemStateValidatorScript := preload(
	"res://core/persistence/native_item_state_validator.gd"
)
const NativeItemSnapshotCaptureResultScript := preload(
	"res://core/persistence/native_item_snapshot_capture_result.gd"
)
const NativeItemStateCaptureScript := preload(
	"res://core/persistence/native_item_state_capture.gd"
)
const NativeItemDomainStateScript := preload(
	"res://core/persistence/native_item_domain_state.gd"
)
const NativeItemStateRestoreResultScript := preload(
	"res://core/persistence/native_item_state_restore_result.gd"
)
const NativeItemStateRestorerScript := preload(
	"res://core/persistence/native_item_state_restorer.gd"
)
const NativeItemSaveRestoreTest := preload(
	"res://tests/core/native_item_save_restore_test.gd"
)
const LegacyAutoloadEntryScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry.gd"
)
const LegacyAutoloadParseResultScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parse_result.gd"
)
const LegacyAutoloadParserScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parser.gd"
)
const LegacyAutoloadBindingScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_binding.gd"
)
const LegacyAutoloadBindingsScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_bindings.gd"
)
const LegacyAutoloadImportPlanScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_import_plan.gd"
)
const LegacyAutoloadEntryResultScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry_result.gd"
)
const LegacyBandageStateImportScript := preload(
	"res://core/persistence/legacy_autoload/legacy_bandage_state_import.gd"
)
const LegacyMarryCardStateImportScript := preload(
	"res://core/persistence/legacy_autoload/legacy_marry_card_state_import.gd"
)
const LegacyMarryCardRuntimeIntentScript := preload(
	"res://core/persistence/legacy_autoload/legacy_marry_card_runtime_intent.gd"
)
const LegacyStackDestructionIntentScript := preload(
	"res://core/persistence/legacy_autoload/legacy_stack_destruction_intent.gd"
)
const LegacyAutoloadImportResultScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_import_result.gd"
)
const LegacyAutoloadImporterScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_importer.gd"
)
const LegacyAutoloadImportTest := preload(
	"res://tests/core/legacy_autoload_import_test.gd"
)
const ItemLifecycleOwnerContextScript := preload(
	"res://core/items/lifecycle/item_lifecycle_owner_context.gd"
)
const ItemLifecycleResultScript := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)
const ItemLifecycleServiceScript := preload(
	"res://core/items/lifecycle/item_lifecycle_service.gd"
)
const FailingLifecycleEquipmentStateScript := preload(
	"res://tests/support/failing_lifecycle_equipment_state.gd"
)
const FailingLifecycleArmorStateScript := preload(
	"res://tests/support/failing_lifecycle_armor_state.gd"
)
const ItemLifecycleDestructionTest := preload(
	"res://tests/core/item_lifecycle_destruction_test.gd"
)
const DeathContextScript := preload("res://core/death/death_context.gd")
const DeathItemFactsScript := preload("res://core/death/death_item_facts.gd")
const DeferredNpcSpawnIntentScript := preload(
	"res://core/death/deferred_npc_spawn_intent.gd"
)
const DeathItemPolicyResultScript := preload(
	"res://core/death/death_item_policy_result.gd"
)
const DeathItemPolicyScript := preload("res://core/death/death_item_policy.gd")
const DestroyDeathItemPolicyScript := preload(
	"res://core/death/destroy_death_item_policy.gd"
)
const WindspringDeathItemPolicyScript := preload(
	"res://core/death/windspring_death_item_policy.gd"
)
const DeathItemPolicyRegistryScript := preload(
	"res://core/death/death_item_policy_registry.gd"
)
const DeathRewearPolicyRegistryScript := preload(
	"res://core/death/death_rewear_policy_registry.gd"
)
const DeathRewearResultScript := preload(
	"res://core/death/death_rewear_result.gd"
)
const DeathInventoryResultScript := preload(
	"res://core/death/death_inventory_result.gd"
)
const DeathInventoryServiceScript := preload(
	"res://core/death/death_inventory_service.gd"
)
const CorpseStateScript := preload("res://core/corpses/corpse_state.gd")
const CorpseDecayScheduleIntentScript := preload(
	"res://core/corpses/corpse_decay_schedule_intent.gd"
)
const CorpseContentTransferResultScript := preload(
	"res://core/corpses/corpse_content_transfer_result.gd"
)
const CorpseContentTransferServiceScript := preload(
	"res://core/corpses/corpse_content_transfer_service.gd"
)
const CorpseDecayResultScript := preload(
	"res://core/corpses/corpse_decay_result.gd"
)
const CorpseDecayServiceScript := preload(
	"res://core/corpses/corpse_decay_service.gd"
)
const DeathInventoryCorpseTest := preload(
	"res://tests/core/death_inventory_corpse_test.gd"
)
const CombatRelationshipStateScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const ActionBusyStateScript := preload(
	"res://core/combat/busy/action_busy_state.gd"
)
const CombatSkillPowerInputScript := preload(
	"res://core/combat/math/combat_skill_power_input.gd"
)
const CombatMathScript := preload("res://core/combat/math/combat_math.gd")
const CombatRandomSourceScript := preload(
	"res://core/combat/random/combat_random_source.gd"
)
const CombatActionDefinitionScript := preload(
	"res://core/combat/action/combat_action_definition.gd"
)
const CombatActionSetScript := preload(
	"res://core/combat/action/combat_action_set.gd"
)
const CombatActionSelectionInputScript := preload(
	"res://core/combat/action/combat_action_selection_input.gd"
)
const CombatActionSelectionResultScript := preload(
	"res://core/combat/action/combat_action_selection_result.gd"
)
const CombatActionSelectorScript := preload(
	"res://core/combat/action/combat_action_selector.gd"
)
const ScriptedCombatRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const CombatStateMathActionFoundationTest := preload(
	"res://tests/core/combat_state_math_action_foundation_test.gd"
)
const CombatStrengthProjectionScript := preload(
	"res://core/combat/resolution/combat_strength_projection.gd"
)
const CombatHitPolicyStatusScript := preload(
	"res://core/combat/resolution/combat_hit_policy_status.gd"
)
const WeaponCombatProfileScript := preload(
	"res://core/combat/resolution/weapon_combat_profile.gd"
)
const CombatAttackerSnapshotScript := preload(
	"res://core/combat/resolution/combat_attacker_snapshot.gd"
)
const CombatDefenderSnapshotScript := preload(
	"res://core/combat/resolution/combat_defender_snapshot.gd"
)
const CombatAttackInputScript := preload(
	"res://core/combat/resolution/combat_attack_input.gd"
)
const CombatAttackCalculationScript := preload(
	"res://core/combat/resolution/combat_attack_calculation.gd"
)
const CombatResourceMutationResultScript := preload(
	"res://core/combat/resolution/combat_resource_mutation_result.gd"
)
const CombatAttackResultScript := preload(
	"res://core/combat/resolution/combat_attack_result.gd"
)
const CombatAttackResolverScript := preload(
	"res://core/combat/resolution/combat_attack_resolver.gd"
)
const CombatOrdinaryAttackCoreResolutionTest := preload(
	"res://tests/core/combat_ordinary_attack_core_resolution_test.gd"
)
const StandardForceHitInputScript := preload(
	"res://core/combat/force/standard_force_hit_input.gd"
)
const StandardForceReflectionMutationResultScript := preload(
	"res://core/combat/force/standard_force_reflection_mutation_result.gd"
)
const StandardForceHitResultScript := preload(
	"res://core/combat/force/standard_force_hit_result.gd"
)
const StandardForceHitPolicyScript := preload(
	"res://core/combat/force/standard_force_hit_policy.gd"
)
const StandardForceHitPolicyTest := preload(
	"res://tests/core/standard_force_hit_policy_test.gd"
)
const CombatProgressionFactsScript := preload(
	"res://core/combat/completion/combat_progression_facts.gd"
)
const CombatBusyInterruptProjectionScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_projection.gd"
)
const CombatStatusReportBoundaryResultScript := preload(
	"res://core/combat/completion/combat_status_report_boundary_result.gd"
)
const CombatProgressionResultScript := preload(
	"res://core/combat/completion/combat_progression_result.gd"
)
const CombatBusyInterruptResultScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_result.gd"
)
const CombatOrdinaryAttackResultScript := preload(
	"res://core/combat/completion/combat_ordinary_attack_result.gd"
)
const CombatProgressionServiceScript := preload(
	"res://core/combat/completion/combat_progression_service.gd"
)
const CombatAttackCompletionServiceScript := preload(
	"res://core/combat/completion/combat_attack_completion_service.gd"
)
const CombatProgressionBusyCompletionTest := preload(
	"res://tests/core/combat_progression_busy_completion_test.gd"
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
		ObservingPracticePolicyScript,
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
		RequiredGenderSkillLearnPolicyScript,
		MinimumBaseSpiritualitySkillLearnPolicyScript,
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
		GenderLearnPoliciesTest,
		ItemDefinitionScript,
		ItemInstanceScript,
		ItemIdentityTest,
		ContainmentEndpointScript,
		InventoryTransferDestinationScript,
		InventoryTransferResultScript,
		InventoryStateScript,
		InventoryTransferServiceScript,
		InventoryContainmentTransferTest,
		CombinedStackDefinitionScript,
		CombinedStackStateScript,
		CombinedStackCollectionScript,
		CombinedStackAmountResultScript,
		CombinedStackSplitResultScript,
		CombinedStackMergeResultScript,
		CombinedStackServiceScript,
		CurrencyDefinitionScript,
		CombinedStackCurrencyTest,
		ArmorNumericModifiersScript,
		ArmorDefinitionScript,
		EquippedArmorRefScript,
		ArmorTransitionResultScript,
		ArmorStateScript,
		ArmorServiceScript,
		ArmorFoundationTest,
		NativeItemRecordScript,
		NativeCombinedStackRecordScript,
		NativeCharacterEquipmentRecordScript,
		NativeArmorSlotRecordScript,
		NativeCharacterArmorRecordScript,
		NativeItemStateSnapshotScript,
		NativeItemDefinitionProjectionsScript,
		NativeCharacterEquipmentSourceScript,
		NativeCharacterArmorSourceScript,
		NativeItemStateValidationResultScript,
		NativeItemStateValidatorScript,
		NativeItemSnapshotCaptureResultScript,
		NativeItemStateCaptureScript,
		NativeItemDomainStateScript,
		NativeItemStateRestoreResultScript,
		NativeItemStateRestorerScript,
		NativeItemSaveRestoreTest,
		LegacyAutoloadEntryScript,
		LegacyAutoloadParseResultScript,
		LegacyAutoloadParserScript,
		LegacyAutoloadBindingScript,
		LegacyAutoloadBindingsScript,
		LegacyAutoloadImportPlanScript,
		LegacyAutoloadEntryResultScript,
		LegacyBandageStateImportScript,
		LegacyMarryCardStateImportScript,
		LegacyMarryCardRuntimeIntentScript,
		LegacyStackDestructionIntentScript,
		LegacyAutoloadImportResultScript,
		LegacyAutoloadImporterScript,
		LegacyAutoloadImportTest,
		ItemLifecycleOwnerContextScript,
		ItemLifecycleResultScript,
		ItemLifecycleServiceScript,
		FailingLifecycleEquipmentStateScript,
		FailingLifecycleArmorStateScript,
		ItemLifecycleDestructionTest,
		DeathContextScript,
		DeathItemFactsScript,
		DeferredNpcSpawnIntentScript,
		DeathItemPolicyResultScript,
		DeathItemPolicyScript,
		DestroyDeathItemPolicyScript,
		WindspringDeathItemPolicyScript,
		DeathItemPolicyRegistryScript,
		DeathRewearPolicyRegistryScript,
		DeathRewearResultScript,
		DeathInventoryResultScript,
		DeathInventoryServiceScript,
		CorpseStateScript,
		CorpseDecayScheduleIntentScript,
		CorpseContentTransferResultScript,
		CorpseContentTransferServiceScript,
		CorpseDecayResultScript,
		CorpseDecayServiceScript,
		DeathInventoryCorpseTest,
		CombatRelationshipStateScript,
		ActionBusyStateScript,
		CombatSkillPowerInputScript,
		CombatMathScript,
		CombatRandomSourceScript,
		CombatActionDefinitionScript,
		CombatActionSetScript,
		CombatActionSelectionInputScript,
		CombatActionSelectionResultScript,
		CombatActionSelectorScript,
		ScriptedCombatRandomSourceScript,
		CombatStateMathActionFoundationTest,
		CombatStrengthProjectionScript,
		CombatHitPolicyStatusScript,
		WeaponCombatProfileScript,
		CombatAttackerSnapshotScript,
		CombatDefenderSnapshotScript,
		CombatAttackInputScript,
		CombatAttackCalculationScript,
		CombatResourceMutationResultScript,
		CombatAttackResultScript,
		CombatAttackResolverScript,
		CombatOrdinaryAttackCoreResolutionTest,
		StandardForceHitInputScript,
		StandardForceReflectionMutationResultScript,
		StandardForceHitResultScript,
		StandardForceHitPolicyScript,
		StandardForceHitPolicyTest,
		CombatProgressionFactsScript,
		CombatBusyInterruptProjectionScript,
		CombatStatusReportBoundaryResultScript,
		CombatProgressionResultScript,
		CombatBusyInterruptResultScript,
		CombatOrdinaryAttackResultScript,
		CombatProgressionServiceScript,
		CombatAttackCompletionServiceScript,
		CombatProgressionBusyCompletionTest,
	]
	for script: Script in phase_scripts:
		if not script.can_instantiate():
			printerr("FAIL: domain script cannot be instantiated: %s" % script.resource_path)
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
	var phase_4a4_result: Dictionary[String, Variant] = GenderLearnPoliciesTest.new().run_all()
	var phase_4b1_result: Dictionary[String, Variant] = ItemIdentityTest.new().run_all()
	var phase_4b2_result: Dictionary[String, Variant] = (
		InventoryContainmentTransferTest.new().run_all()
	)
	var phase_4b3_result: Dictionary[String, Variant] = (
		CombinedStackCurrencyTest.new().run_all()
	)
	var phase_4b4_result: Dictionary[String, Variant] = ArmorFoundationTest.new().run_all()
	var phase_4b5a_result: Dictionary[String, Variant] = (
		NativeItemSaveRestoreTest.new().run_all()
	)
	var phase_4b5b_result: Dictionary[String, Variant] = (
		ItemLifecycleDestructionTest.new().run_all()
	)
	var phase_4b5c_result: Dictionary[String, Variant] = (
		DeathInventoryCorpseTest.new().run_all()
	)
	var phase_4b5d_result: Dictionary[String, Variant] = (
		LegacyAutoloadImportTest.new().run_all()
	)
	var phase_5b1_result: Dictionary[String, Variant] = (
		CombatStateMathActionFoundationTest.new().run_all()
	)
	var phase_5b2a_result: Dictionary[String, Variant] = (
		CombatOrdinaryAttackCoreResolutionTest.new().run_all()
	)
	var phase_5b2b1_result: Dictionary[String, Variant] = (
		StandardForceHitPolicyTest.new().run_all()
	)
	var phase_5b2b2_result: Dictionary[String, Variant] = (
		CombatProgressionBusyCompletionTest.new().run_all()
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
	) + int(
		phase_4a4_result["assertions"]
	) + int(
		phase_4b1_result["assertions"]
	) + int(
		phase_4b2_result["assertions"]
	) + int(
		phase_4b3_result["assertions"]
	) + int(
		phase_4b4_result["assertions"]
	) + int(
		phase_4b5a_result["assertions"]
	) + int(
		phase_4b5b_result["assertions"]
	) + int(
		phase_4b5c_result["assertions"]
	) + int(
		phase_4b5d_result["assertions"]
	) + int(
		phase_5b1_result["assertions"]
	) + int(
		phase_5b2a_result["assertions"]
	) + int(
		phase_5b2b1_result["assertions"]
	) + int(
		phase_5b2b2_result["assertions"]
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
	failures.append_array(phase_4a4_result["failures"])
	failures.append_array(phase_4b1_result["failures"])
	failures.append_array(phase_4b2_result["failures"])
	failures.append_array(phase_4b3_result["failures"])
	failures.append_array(phase_4b4_result["failures"])
	failures.append_array(phase_4b5a_result["failures"])
	failures.append_array(phase_4b5b_result["failures"])
	failures.append_array(phase_4b5c_result["failures"])
	failures.append_array(phase_4b5d_result["failures"])
	failures.append_array(phase_5b1_result["failures"])
	failures.append_array(phase_5b2a_result["failures"])
	failures.append_array(phase_5b2b1_result["failures"])
	failures.append_array(phase_5b2b2_result["failures"])
	if failures.is_empty():
		print("PASS: %d assertions" % assertion_count)
		quit(0)
		return

	for failure: String in failures:
		push_error(str(failure))
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertion_count])
	quit(1)
