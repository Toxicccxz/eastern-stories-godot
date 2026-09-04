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
const CombatOpponentAvailabilityFactsScript := preload(
	"res://core/combat/relationship/combat_opponent_availability_facts.gd"
)
const CombatOpponentSelectionResultScript := preload(
	"res://core/combat/relationship/combat_opponent_selection_result.gd"
)
const CombatOpponentSelectionServiceScript := preload(
	"res://core/combat/relationship/combat_opponent_selection_service.gd"
)
const CombatPostRelationshipResultScript := preload(
	"res://core/combat/relationship/combat_post_relationship_result.gd"
)
const CombatPostRelationshipServiceScript := preload(
	"res://core/combat/relationship/combat_post_relationship_service.gd"
)
const FailingCombatRelationshipStateScript := preload(
	"res://tests/support/failing_combat_relationship_state.gd"
)
const CombatRelationshipOpponentFriendlyStopTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const CombatTriggerCauseScript := preload(
	"res://core/combat/encounter/combat_trigger_cause.gd"
)
const CombatEncounterModeScript := preload(
	"res://core/combat/encounter/combat_encounter_mode.gd"
)
const CombatEncounterLifecycleScript := preload(
	"res://core/combat/encounter/combat_encounter_lifecycle.gd"
)
const CombatEncounterResultKindScript := preload(
	"res://core/combat/encounter/combat_encounter_result_kind.gd"
)
const CombatEncounterEventKindScript := preload(
	"res://core/combat/encounter/combat_encounter_event_kind.gd"
)
const CombatTriggerCandidateScript := preload(
	"res://core/combat/encounter/combat_trigger_candidate.gd"
)
const CombatTriggerScript := preload("res://core/combat/encounter/combat_trigger.gd")
const CombatEncounterAuthorityBindingScript := preload(
	"res://core/combat/encounter/combat_encounter_authority_binding.gd"
)
const CombatParticipantScript := preload(
	"res://core/combat/encounter/combat_participant.gd"
)
const CombatDirectedHostilityScript := preload(
	"res://core/combat/encounter/combat_directed_hostility.gd"
)
const CombatTargetAssignmentScript := preload(
	"res://core/combat/encounter/combat_target_assignment.gd"
)
const CombatEncounterResultScript := preload(
	"res://core/combat/encounter/combat_encounter_result.gd"
)
const CombatEncounterEventScript := preload(
	"res://core/combat/encounter/combat_encounter_event.gd"
)
const CombatEncounterScript := preload(
	"res://core/combat/encounter/combat_encounter.gd"
)
const CombatEncounterCoreTest := preload(
	"res://tests/core/combat_encounter_core_test.gd"
)
const CombatAttackTypeScript := preload(
	"res://core/combat/fight/combat_attack_type.gd"
)
const CombatPerceptionSkillProjectionScript := preload(
	"res://core/combat/fight/combat_perception_skill_projection.gd"
)
const CombatFightDecisionFactsScript := preload(
	"res://core/combat/fight/combat_fight_decision_facts.gd"
)
const CombatFightDecisionResultScript := preload(
	"res://core/combat/fight/combat_fight_decision_result.gd"
)
const CombatFightDecisionServiceScript := preload(
	"res://core/combat/fight/combat_fight_decision_service.gd"
)
const CombatFightDecisionGuardTest := preload(
	"res://tests/core/combat_fight_decision_guard_test.gd"
)
const CombatRiposteRequestScript := preload(
	"res://core/combat/execution/combat_riposte_request.gd"
)
const CombatRawComposureAuthorityScript := preload(
	"res://core/combat/execution/combat_raw_composure_authority.gd"
)
const CombatSingleAttackExecutionResultScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_result.gd"
)
const CombatSingleAttackExecutionServiceScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_service.gd"
)
const CombatSingleAttackPostActionRiposteDecisionTest := preload(
	"res://tests/core/combat_single_attack_post_action_riposte_decision_test.gd"
)
const CombatCharacterAuthorityScript := preload(
	"res://core/combat/execution/combat_character_authority.gd"
)
const CombatReverseAttackProjectionScript := preload(
	"res://core/combat/execution/combat_reverse_attack_projection.gd"
)
const CombatReverseModifierProjectionScript := preload(
	"res://core/combat/execution/combat_reverse_modifier_projection.gd"
)
const CombatAttackChainResultScript := preload(
	"res://core/combat/execution/combat_attack_chain_result.gd"
)
const CombatAttackChainCompletionServiceScript := preload(
	"res://core/combat/execution/combat_attack_chain_completion_service.gd"
)
const CombatSynchronousReverseAttackExecutionTest := preload(
	"res://tests/core/combat_synchronous_reverse_attack_execution_test.gd"
)
const CharacterRuntimeLifeStatusScript := preload(
	"res://runtime/characters/character_runtime_life_status.gd"
)
const CombatSliceLifeStatusScript := preload(
	"res://runtime/combat_slice/combat_slice_life_status.gd"
)
const CombatSliceCharacterBindingScript := preload(
	"res://runtime/combat_slice/combat_slice_character_binding.gd"
)
const CombatSliceContentProfileScript := preload(
	"res://runtime/combat_slice/combat_slice_content_profile.gd"
)
const CombatSliceInitiationResultScript := preload(
	"res://runtime/combat_slice/combat_slice_initiation_result.gd"
)
const CombatSliceProjectionBuilderScript := preload(
	"res://runtime/combat_slice/combat_slice_projection_builder.gd"
)
const CombatSliceOpportunityResultScript := preload(
	"res://runtime/combat_slice/combat_slice_opportunity_result.gd"
)
const CombatSliceOpportunityExecutorScript := preload(
	"res://runtime/combat_slice/combat_slice_opportunity_executor.gd"
)
const CombatSliceOpportunityIntegrationTest := preload(
	"res://tests/runtime/combat_slice_opportunity_integration_test.gd"
)
const CombatVerticalSliceSmokeTest := preload(
	"res://tests/runtime/combat_vertical_slice_smoke_test.gd"
)
const CombatSliceLifecycleResultScript := preload(
	"res://runtime/combat_slice/combat_slice_lifecycle_result.gd"
)
const CombatSliceDeathExecutionResultScript := preload(
	"res://runtime/combat_slice/combat_slice_death_execution_result.gd"
)
const CombatSliceDeathAdapterScript := preload(
	"res://runtime/combat_slice/combat_slice_death_adapter.gd"
)
const CombatSliceLifecycleAdapterScript := preload(
	"res://runtime/combat_slice/combat_slice_lifecycle_adapter.gd"
)
const CombatSliceCorpseViewScript := preload(
	"res://runtime/combat_slice/combat_slice_corpse_view.gd"
)
const CombatSliceLifecycleCorpseTest := preload(
	"res://tests/runtime/combat_slice_lifecycle_corpse_test.gd"
)
const RegionDefinitionScript := preload("res://core/world/region_definition.gd")
const MapDefinitionScript := preload("res://core/world/map_definition.gd")
const ZoneDefinitionScript := preload("res://core/world/zone_definition.gd")
const PortalDefinitionScript := preload("res://core/world/portal_definition.gd")
const WorldLandmarkDefinitionScript := preload(
	"res://core/world/world_landmark_definition.gd"
)
const WorldLocationStateScript := preload("res://core/world/world_location_state.gd")
const NpcBaseAttributeOverridesScript := preload(
	"res://core/npcs/npc_base_attribute_overrides.gd"
)
const NpcResourceTrackOverrideScript := preload(
	"res://core/npcs/npc_resource_track_override.gd"
)
const NpcResourceOverridesScript := preload(
	"res://core/npcs/npc_resource_overrides.gd"
)
const NpcSkillLevelDefinitionScript := preload(
	"res://core/npcs/npc_skill_level_definition.gd"
)
const NpcLoadoutEntryScript := preload("res://core/npcs/npc_loadout_entry.gd")
const NpcLoadoutItemDefinitionScript := preload(
	"res://core/npcs/npc_loadout_item_definition.gd"
)
const NpcDefinitionScript := preload("res://core/npcs/npc_definition.gd")
const NpcSpawnDefinitionScript := preload("res://core/npcs/npc_spawn_definition.gd")
const NpcInitializationRandomSourceScript := preload(
	"res://core/npcs/npc_initialization_random_source.gd"
)
const NpcRuntimeStateScript := preload("res://core/npcs/npc_runtime_state.gd")
const NpcCharacterStateFactoryScript := preload(
	"res://core/npcs/npc_character_state_factory.gd"
)
const MapCharacterRuntimeStateScript := preload(
	"res://runtime/world/map_character_runtime_state.gd"
)
const OldPineWorldDefinitionsScript := preload(
	"res://data/oldpine/oldpine_world_definitions.gd"
)
const OldPineLandmarkDefinitionsScript := preload(
	"res://data/oldpine/oldpine_landmark_definitions.gd"
)
const OldPineNpcDefinitionsScript := preload(
	"res://data/oldpine/oldpine_npc_definitions.gd"
)
const OldPineSpawnDefinitionsScript := preload(
	"res://data/oldpine/oldpine_spawn_definitions.gd"
)
const ScriptedNpcInitializationRandomSourceScript := preload(
	"res://tests/support/scripted_npc_initialization_random_source.gd"
)
const WorldDefinitionTest := preload("res://tests/core/world_definition_test.gd")
const NpcSpawnFoundationTest := preload(
	"res://tests/core/npc_spawn_foundation_test.gd"
)
const WorldPlayerRuntimeStateScript := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)
const WorldCombatBindingAdapterScript := preload(
	"res://runtime/characters/world_combat_binding_adapter.gd"
)
const GodotNpcInitializationRandomSourceScript := preload(
	"res://runtime/npcs/godot_npc_initialization_random_source.gd"
)
const WorldSpawnMarker2DScript := preload(
	"res://runtime/world/world_spawn_marker_2d.gd"
)
const WorldCharacterBody2DScript := preload(
	"res://runtime/world/world_character_body_2d.gd"
)
const OldPineOutdoorHudScript := preload(
	"res://runtime/world/oldpine_outdoor_hud.gd"
)
const OldPineResidentMapControllerScript := preload(
	"res://runtime/world/oldpine_resident_map_controller.gd"
)
const OldPineMapHandoffResultScript := preload(
	"res://runtime/world/oldpine_map_handoff_result.gd"
)
const OldPineCavePassageControllerScript := preload(
	"res://runtime/world/oldpine_cave_passage_controller.gd"
)
const OldPineWorldSessionControllerScript := preload(
	"res://runtime/world/oldpine_world_session_controller.gd"
)
const OldPineOutdoorControllerScript := preload(
	"res://runtime/world/oldpine_outdoor_controller.gd"
)
const WorldInteractionTargetScript := preload(
	"res://runtime/world/world_interaction_target.gd"
)
const WorldPortalTraversalResultScript := preload(
	"res://runtime/world/world_portal_traversal_result.gd"
)
const OldPinePortalTraversalAdapterScript := preload(
	"res://runtime/world/oldpine_portal_traversal_adapter.gd"
)
const OldPineAggressionDecisionScript := preload(
	"res://runtime/world/oldpine_aggression_decision.gd"
)
const OldPineBanditAggressionAdapterScript := preload(
	"res://runtime/world/oldpine_bandit_aggression_adapter.gd"
)
const WorldLandmarkArea2DScript := preload(
	"res://runtime/world/world_landmark_area_2d.gd"
)
const OldPineOutdoorSmokeTest := preload(
	"res://tests/runtime/oldpine_outdoor_smoke_test.gd"
)
const OldPinePortalAggressionTest := preload(
	"res://tests/runtime/oldpine_portal_aggression_test.gd"
)
const WorldItemInstanceIndexScript := preload(
	"res://runtime/world/world_item_instance_index.gd"
)
const OldPineItemContentDefinitionScript := preload(
	"res://data/oldpine/oldpine_item_content_definition.gd"
)
const OldPineItemContentDefinitionsScript := preload(
	"res://data/oldpine/oldpine_item_content_definitions.gd"
)
const WorldItemRowProjectionScript := preload(
	"res://runtime/world/world_item_row_projection.gd"
)
const CorpseLootTransferResultScript := preload(
	"res://runtime/world/corpse_loot_transfer_result.gd"
)
const OldPineCorpseLootAdapterScript := preload(
	"res://runtime/world/oldpine_corpse_loot_adapter.gd"
)
const OldPineLootPanelScript := preload(
	"res://ui/world/oldpine_loot_panel.gd"
)
const OldPineCorpseLootInteractionTest := preload(
	"res://tests/runtime/oldpine_corpse_loot_interaction_test.gd"
)
const PlayerInventoryRowProjectionScript := preload(
	"res://runtime/world/player_inventory_row_projection.gd"
)
const PlayerInventoryProjectionScript := preload(
	"res://runtime/world/player_inventory_projection.gd"
)
const OldPineEquipmentInteractionResultScript := preload(
	"res://runtime/world/oldpine_equipment_interaction_result.gd"
)
const OldPineEquipmentInteractionAdapterScript := preload(
	"res://runtime/world/oldpine_equipment_interaction_adapter.gd"
)
const OldPineArmorInteractionResultScript := preload(
	"res://runtime/world/oldpine_armor_interaction_result.gd"
)
const OldPineArmorInteractionAdapterScript := preload(
	"res://runtime/world/oldpine_armor_interaction_adapter.gd"
)
const OldPineWeaponContentResolutionScript := preload(
	"res://runtime/world/oldpine_weapon_content_resolution.gd"
)
const OldPineWeaponContentResolverScript := preload(
	"res://runtime/world/oldpine_weapon_content_resolver.gd"
)
const PlayerInventoryPanelScript := preload(
	"res://ui/world/player_inventory_panel.gd"
)
const PlayerInventoryEquipmentTest := preload(
	"res://tests/runtime/player_inventory_equipment_test.gd"
)
const OldPineFullLootLoopTest := preload(
	"res://tests/runtime/oldpine_full_loot_loop_test.gd"
)
const OldPinePineMazeTallBanditTest := preload(
	"res://tests/runtime/oldpine_pine_maze_tall_bandit_test.gd"
)
const NpcArmorLoadoutTest := preload("res://tests/core/npc_armor_loadout_test.gd")
const PlayerArmorInteractionTest := preload(
	"res://tests/runtime/player_armor_interaction_test.gd"
)
const OldPineFatBanditArmorLoopTest := preload(
	"res://tests/runtime/oldpine_fat_bandit_armor_loop_test.gd"
)
const OldPineWorldSessionTest := preload(
	"res://tests/runtime/oldpine_world_session_test.gd"
)
const VineTraversalPolicyTest := preload(
	"res://tests/core/vine_traversal_policy_test.gd"
)
const OldPineVineCrossMapTraversalTest := preload(
	"res://tests/runtime/oldpine_vine_cross_map_traversal_test.gd"
)
const OldPineRiverCliffRouteTest := preload(
	"res://tests/runtime/oldpine_river_cliff_route_test.gd"
)
const GameSaveValueTypesScript := preload("res://core/persistence/game_save_value_types.gd")
const RandomStreamSnapshotScript := preload("res://core/persistence/random_stream_snapshot.gd")
const GameSaveSnapshotScript := preload("res://core/persistence/game_save_snapshot.gd")
const GameSaveResultScript := preload("res://core/persistence/game_save_result.gd")
const DecimalInt64CodecScript := preload("res://core/persistence/decimal_int64_codec.gd")
const GameSaveSnapshotValidatorScript := preload("res://core/persistence/game_save_snapshot_validator.gd")
const GameSaveJsonCodecScript := preload("res://core/persistence/game_save_json_codec.gd")
const SaveFileReadResultScript := preload("res://runtime/persistence/save_file_read_result.gd")
const SaveFileOperationsScript := preload("res://runtime/persistence/save_file_operations.gd")
const GodotSaveFileOperationsScript := preload("res://runtime/persistence/godot_save_file_operations.gd")
const GameSaveStorageProfileScript := preload("res://runtime/persistence/game_save_storage_profile.gd")
const GameSaveRepositoryScript := preload("res://runtime/persistence/game_save_repository.gd")
const GameSaveJsonCodecTest := preload("res://tests/core/game_save_json_codec_test.gd")
const RandomStreamPersistenceTest := preload("res://tests/runtime/random_stream_persistence_test.gd")
const GameSaveRepositoryTest := preload("res://tests/runtime/game_save_repository_test.gd")
const SessionItemIdAllocationResultScript := preload("res://core/persistence/session_item_id_allocation_result.gd")
const SessionItemIdAllocatorRestoreResultScript := preload("res://core/persistence/session_item_id_allocator_restore_result.gd")
const SessionItemIdAllocatorScript := preload("res://core/persistence/session_item_id_allocator.gd")
const SessionItemIdScopeFactoryScript := preload("res://core/persistence/session_item_id_scope_factory.gd")
const NativeItemRestoreCompositionResultScript := preload("res://core/persistence/native_item_restore_composition_result.gd")
const NativeItemPersistenceCompositionScript := preload("res://core/persistence/native_item_persistence_composition.gd")
const OldPineNativeItemDefinitionProjectionsScript := preload("res://data/oldpine/oldpine_native_item_definition_projections.gd")
const NativeItemPersistenceCompositionTest := preload("res://tests/core/native_item_persistence_composition_test.gd")
const CharacterStateSnapshotRestorerScript := preload("res://core/persistence/character_state_snapshot_restorer.gd")
const OldPineRestoredNpcEntryScript := preload("res://runtime/persistence/oldpine_restored_npc_entry.gd")
const OldPineRestoredCorpseEntryScript := preload("res://runtime/persistence/oldpine_restored_corpse_entry.gd")
const OldPineWorldRestorePreparationScript := preload("res://runtime/persistence/oldpine_world_restore_preparation.gd")
const OldPineWorldRestoreResultScript := preload("res://runtime/persistence/oldpine_world_restore_result.gd")
const OldPineWorldRestoreCompositionScript := preload("res://runtime/persistence/oldpine_world_restore_composition.gd")
const OldPineMapPlacementValidatorScript := preload("res://runtime/persistence/oldpine_map_placement_validator.gd")
const OldPineWorldRestoreServiceScript := preload("res://runtime/persistence/oldpine_world_restore_service.gd")
const OldPineWorldRestoreTest := preload("res://tests/runtime/oldpine_world_restore_test.gd")
const OldPineSaveEligibilityResultScript := preload("res://runtime/persistence/oldpine_save_eligibility_result.gd")
const OldPineSaveEligibilityScript := preload("res://runtime/persistence/oldpine_save_eligibility.gd")
const OldPineWorldCaptureResultScript := preload("res://runtime/persistence/oldpine_world_capture_result.gd")
const OldPineWorldSaveCaptureScript := preload("res://runtime/persistence/oldpine_world_save_capture.gd")
const OldPineRuntimeSaveLoadResultScript := preload("res://runtime/persistence/oldpine_runtime_save_load_result.gd")
const OldPineSessionLoadCoordinatorScript := preload("res://runtime/persistence/oldpine_session_load_coordinator.gd")
const OldPineGameRuntimeHostScript := preload("res://runtime/persistence/oldpine_game_runtime_host.gd")
const OldPineSaveLoadTransactionTest := preload("res://tests/runtime/oldpine_save_load_transaction_test.gd")
const ApplicationShellStateScript := preload("res://application/application_shell_state.gd")
const ApplicationSlotInspectionScript := preload("res://application/application_slot_inspection.gd")
const ApplicationOperationResultScript := preload("res://application/application_operation_result.gd")
const ApplicationProductResultMapperScript := preload("res://application/application_product_result_mapper.gd")
const ApplicationMessageCatalogScript := preload("res://application/application_message_catalog.gd")
const ApplicationShellControllerScript := preload("res://runtime/application/application_shell_controller.gd")
const ApplicationShellTest := preload("res://tests/application/application_shell_test.gd")
const ApplicationShellPhase10C1CTest := preload("res://tests/application/application_shell_phase10c1c_test.gd")
const MobilePresentationTest := preload("res://tests/presentation/mobile_presentation_test.gd")
const MobilePresentationAuditTest := preload("res://tests/presentation/mobile_presentation_audit_test.gd")
const MobileTouchTest := preload("res://tests/application/mobile_touch_test.gd")
const MobileTouchAuditTest := preload("res://tests/application/mobile_touch_audit_test.gd")
const MobileLifecycleTest := preload("res://tests/application/mobile_lifecycle_test.gd")
const MobileLifecycleAuditTest := preload("res://tests/application/mobile_lifecycle_audit_test.gd")


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
		CombatOpponentAvailabilityFactsScript,
		CombatOpponentSelectionResultScript,
		CombatOpponentSelectionServiceScript,
		CombatPostRelationshipResultScript,
		CombatPostRelationshipServiceScript,
		FailingCombatRelationshipStateScript,
		CombatRelationshipOpponentFriendlyStopTest,
		CombatTriggerCauseScript,
		CombatEncounterModeScript,
		CombatEncounterLifecycleScript,
		CombatEncounterResultKindScript,
		CombatEncounterEventKindScript,
		CombatTriggerCandidateScript,
		CombatTriggerScript,
		CombatEncounterAuthorityBindingScript,
		CombatParticipantScript,
		CombatDirectedHostilityScript,
		CombatTargetAssignmentScript,
		CombatEncounterResultScript,
		CombatEncounterEventScript,
		CombatEncounterScript,
		CombatEncounterCoreTest,
		CombatAttackTypeScript,
		CombatPerceptionSkillProjectionScript,
		CombatFightDecisionFactsScript,
		CombatFightDecisionResultScript,
		CombatFightDecisionServiceScript,
		CombatFightDecisionGuardTest,
		CombatRiposteRequestScript,
		CombatRawComposureAuthorityScript,
		CombatSingleAttackExecutionResultScript,
		CombatSingleAttackExecutionServiceScript,
		CombatSingleAttackPostActionRiposteDecisionTest,
		CombatCharacterAuthorityScript,
		CombatReverseAttackProjectionScript,
		CombatReverseModifierProjectionScript,
		CombatAttackChainResultScript,
		CombatAttackChainCompletionServiceScript,
		CombatSynchronousReverseAttackExecutionTest,
		CharacterRuntimeLifeStatusScript,
		CombatSliceLifeStatusScript,
		CombatSliceCharacterBindingScript,
		CombatSliceContentProfileScript,
		CombatSliceInitiationResultScript,
		CombatSliceProjectionBuilderScript,
		CombatSliceOpportunityResultScript,
		CombatSliceOpportunityExecutorScript,
		CombatSliceOpportunityIntegrationTest,
		CombatVerticalSliceSmokeTest,
		CombatSliceLifecycleResultScript,
		CombatSliceDeathExecutionResultScript,
		CombatSliceDeathAdapterScript,
		CombatSliceLifecycleAdapterScript,
		CombatSliceCorpseViewScript,
		CombatSliceLifecycleCorpseTest,
		RegionDefinitionScript,
		MapDefinitionScript,
		ZoneDefinitionScript,
		PortalDefinitionScript,
		WorldLandmarkDefinitionScript,
		WorldLocationStateScript,
		NpcBaseAttributeOverridesScript,
		NpcResourceTrackOverrideScript,
		NpcResourceOverridesScript,
		NpcSkillLevelDefinitionScript,
		NpcLoadoutEntryScript,
		NpcLoadoutItemDefinitionScript,
		NpcDefinitionScript,
		NpcSpawnDefinitionScript,
		NpcInitializationRandomSourceScript,
		NpcRuntimeStateScript,
		NpcCharacterStateFactoryScript,
		MapCharacterRuntimeStateScript,
		OldPineWorldDefinitionsScript,
		OldPineLandmarkDefinitionsScript,
		OldPineNpcDefinitionsScript,
		OldPineSpawnDefinitionsScript,
		ScriptedNpcInitializationRandomSourceScript,
		WorldDefinitionTest,
		NpcSpawnFoundationTest,
		WorldPlayerRuntimeStateScript,
		WorldCombatBindingAdapterScript,
		GodotNpcInitializationRandomSourceScript,
		WorldSpawnMarker2DScript,
		WorldCharacterBody2DScript,
		OldPineOutdoorHudScript,
		OldPineResidentMapControllerScript,
		OldPineMapHandoffResultScript,
		OldPineCavePassageControllerScript,
		OldPineWorldSessionControllerScript,
		OldPineOutdoorControllerScript,
		WorldInteractionTargetScript,
		WorldPortalTraversalResultScript,
		OldPinePortalTraversalAdapterScript,
		OldPineAggressionDecisionScript,
		OldPineBanditAggressionAdapterScript,
		WorldLandmarkArea2DScript,
		OldPineOutdoorSmokeTest,
		OldPinePortalAggressionTest,
		WorldItemInstanceIndexScript,
		OldPineItemContentDefinitionScript,
		OldPineItemContentDefinitionsScript,
		WorldItemRowProjectionScript,
		CorpseLootTransferResultScript,
		OldPineCorpseLootAdapterScript,
		OldPineLootPanelScript,
		OldPineCorpseLootInteractionTest,
		PlayerInventoryRowProjectionScript,
		PlayerInventoryProjectionScript,
		OldPineEquipmentInteractionResultScript,
		OldPineEquipmentInteractionAdapterScript,
		OldPineArmorInteractionResultScript,
		OldPineArmorInteractionAdapterScript,
		OldPineWeaponContentResolutionScript,
		OldPineWeaponContentResolverScript,
		PlayerInventoryPanelScript,
		PlayerInventoryEquipmentTest,
		OldPineFullLootLoopTest,
		OldPinePineMazeTallBanditTest,
		NpcArmorLoadoutTest,
		PlayerArmorInteractionTest,
		OldPineFatBanditArmorLoopTest,
		OldPineWorldSessionTest,
		VineTraversalPolicyTest,
		OldPineVineCrossMapTraversalTest,
		OldPineRiverCliffRouteTest,
		GameSaveValueTypesScript,
		RandomStreamSnapshotScript,
		GameSaveSnapshotScript,
		GameSaveResultScript,
		DecimalInt64CodecScript,
		GameSaveSnapshotValidatorScript,
		GameSaveJsonCodecScript,
		SaveFileReadResultScript,
		SaveFileOperationsScript,
		GodotSaveFileOperationsScript,
		GameSaveStorageProfileScript,
		GameSaveRepositoryScript,
		GameSaveJsonCodecTest,
		RandomStreamPersistenceTest,
		GameSaveRepositoryTest,
		SessionItemIdAllocationResultScript,
		SessionItemIdAllocatorRestoreResultScript,
		SessionItemIdAllocatorScript,
		SessionItemIdScopeFactoryScript,
		NativeItemRestoreCompositionResultScript,
		NativeItemPersistenceCompositionScript,
		OldPineNativeItemDefinitionProjectionsScript,
		NativeItemPersistenceCompositionTest,
		CharacterStateSnapshotRestorerScript,
		OldPineRestoredNpcEntryScript,
		OldPineRestoredCorpseEntryScript,
		OldPineWorldRestorePreparationScript,
		OldPineWorldRestoreResultScript,
		OldPineWorldRestoreCompositionScript,
		OldPineMapPlacementValidatorScript,
		OldPineWorldRestoreServiceScript,
		OldPineWorldRestoreTest,
		OldPineSaveEligibilityResultScript,
		OldPineSaveEligibilityScript,
		OldPineWorldCaptureResultScript,
		OldPineWorldSaveCaptureScript,
		OldPineRuntimeSaveLoadResultScript,
		OldPineSessionLoadCoordinatorScript,
		OldPineGameRuntimeHostScript,
		OldPineSaveLoadTransactionTest,
		ApplicationShellStateScript,
		ApplicationSlotInspectionScript,
		ApplicationOperationResultScript,
		ApplicationProductResultMapperScript,
		ApplicationMessageCatalogScript,
		ApplicationShellControllerScript,
		ApplicationShellTest,
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
	var phase_5b3a_result: Dictionary[String, Variant] = (
		CombatRelationshipOpponentFriendlyStopTest.new().run_all()
	)
	var phase_5b3b1_result: Dictionary[String, Variant] = (
		CombatFightDecisionGuardTest.new().run_all()
	)
	var phase_5b3b2a_result: Dictionary[String, Variant] = (
		CombatSingleAttackPostActionRiposteDecisionTest.new().run_all()
	)
	var phase_5b3b2b_result: Dictionary[String, Variant] = (
		CombatSynchronousReverseAttackExecutionTest.new().run_all()
	)
	var cxr2_result: Dictionary[String, Variant] = CombatEncounterCoreTest.new().run_all()
	var phase_6b1_result: Dictionary[String, Variant] = (
		CombatSliceOpportunityIntegrationTest.new().run_all()
	)
	var phase_6b2_result: Dictionary[String, Variant] = (
		await CombatVerticalSliceSmokeTest.new().run_all(self)
	)
	var phase_6b3_result: Dictionary[String, Variant] = (
		await CombatSliceLifecycleCorpseTest.new().run_all(self)
	)
	var phase_7b1_world_result: Dictionary[String, Variant] = (
		WorldDefinitionTest.new().run_all()
	)
	var phase_7b1_npc_result: Dictionary[String, Variant] = (
		NpcSpawnFoundationTest.new().run_all()
	)
	var phase_7b2_result: Dictionary[String, Variant] = (
		await OldPineOutdoorSmokeTest.new().run_all(self)
	)
	var phase_7b3_result: Dictionary[String, Variant] = (
		await OldPinePortalAggressionTest.new().run_all(self)
	)
	var phase_8b1_result: Dictionary[String, Variant] = (
		await OldPineCorpseLootInteractionTest.new().run_all(self)
	)
	var phase_8b2_unit_result: Dictionary[String, Variant] = (
		PlayerInventoryEquipmentTest.new().run_all()
	)
	var phase_8b2_loop_result: Dictionary[String, Variant] = (
		await OldPineFullLootLoopTest.new().run_all(self)
	)
	var phase_9b1_result: Dictionary[String, Variant] = (
		await OldPinePineMazeTallBanditTest.new().run_all(self)
	)
	var phase_9b2_factory_result: Dictionary[String, Variant] = (
		NpcArmorLoadoutTest.new().run_all()
	)
	var phase_9b2_player_result: Dictionary[String, Variant] = (
		PlayerArmorInteractionTest.new().run_all()
	)
	var phase_9b2_loop_result: Dictionary[String, Variant] = (
		await OldPineFatBanditArmorLoopTest.new().run_all(self)
	)
	var phase_9b3b1_result: Dictionary[String, Variant] = (
		await OldPineWorldSessionTest.new().run_all(self)
	)
	var phase_9b3b2_policy_result: Dictionary[String, Variant] = (
		VineTraversalPolicyTest.new().run_all()
	)
	var phase_9b3b2_runtime_result: Dictionary[String, Variant] = (
		await OldPineVineCrossMapTraversalTest.new().run_all(self)
	)
	var phase_9b3b3_result: Dictionary[String, Variant] = (
		await OldPineRiverCliffRouteTest.new().run_all(self)
	)
	var phase_10b1_codec_result: Dictionary[String, Variant] = GameSaveJsonCodecTest.new().run_all()
	var phase_10b1_random_result: Dictionary[String, Variant] = RandomStreamPersistenceTest.new().run_all()
	var phase_10b1_repository_result: Dictionary[String, Variant] = GameSaveRepositoryTest.new().run_all()
	var phase_10b2_result: Dictionary[String, Variant] = NativeItemPersistenceCompositionTest.new().run_all()
	var phase_10b3_result: Dictionary[String, Variant] = await OldPineWorldRestoreTest.new().run_all(self)
	var phase_10b4_result: Dictionary[String, Variant] = await OldPineSaveLoadTransactionTest.new().run_all(self)
	var phase_10c1a_result: Dictionary[String, Variant] = await ApplicationShellTest.new().run_all(self)
	var phase_10c1c_result: Dictionary[String, Variant] = await ApplicationShellPhase10C1CTest.new().run_all(self)
	var phase_10c2a_result: Dictionary[String, Variant] = await MobilePresentationTest.new().run_all(self)
	var phase_10c2a_audit_result: Dictionary[String, Variant] = await MobilePresentationAuditTest.new().run_all(self)
	var phase_10c2b_result: Dictionary[String, Variant] = await MobileTouchTest.new().run_all(self)
	var phase_10c2b_audit_result: Dictionary[String, Variant] = await MobileTouchAuditTest.new().run_all(self)
	var phase_10c2c_result: Dictionary[String, Variant] = await MobileLifecycleTest.new().run_all(self)
	var lifecycle_audit_result: Dictionary[String, Variant] = await MobileLifecycleAuditTest.new().run_all(self)
	phase_10c2c_result["assertions"] += lifecycle_audit_result["assertions"]
	phase_10c2c_result["failures"].append_array(lifecycle_audit_result["failures"])
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
	) + int(
		phase_5b3a_result["assertions"]
	) + int(
		phase_5b3b1_result["assertions"]
	) + int(
		phase_5b3b2a_result["assertions"]
	) + int(
		phase_5b3b2b_result["assertions"]
	) + int(
		cxr2_result["assertions"]
	) + int(
		phase_6b1_result["assertions"]
	) + int(
		phase_6b2_result["assertions"]
	) + int(
		phase_6b3_result["assertions"]
	) + int(
		phase_7b1_world_result["assertions"]
	) + int(
		phase_7b1_npc_result["assertions"]
	) + int(
		phase_7b2_result["assertions"]
	) + int(
		phase_7b3_result["assertions"]
	) + int(
		phase_8b1_result["assertions"]
	) + int(
		phase_8b2_unit_result["assertions"]
	) + int(
		phase_8b2_loop_result["assertions"]
	) + int(
		phase_9b1_result["assertions"]
	) + int(
		phase_9b2_factory_result["assertions"]
	) + int(
		phase_9b2_player_result["assertions"]
	) + int(
		phase_9b2_loop_result["assertions"]
	) + int(
		phase_9b3b1_result["assertions"]
	) + int(
		phase_9b3b2_policy_result["assertions"]
	) + int(
		phase_9b3b2_runtime_result["assertions"]
	) + int(
		phase_9b3b3_result["assertions"]
	) + int(
		phase_10b1_codec_result["assertions"]
	) + int(
		phase_10b1_random_result["assertions"]
	) + int(
		phase_10b1_repository_result["assertions"]
	) + int(
		phase_10b2_result["assertions"]
	) + int(
		phase_10b3_result["assertions"]
	) + int(
		phase_10b4_result["assertions"]
	) + int(
		phase_10c1a_result["assertions"] + phase_10c1c_result["assertions"] + phase_10c2a_result["assertions"] + phase_10c2a_audit_result["assertions"] + phase_10c2b_result["assertions"] + phase_10c2b_audit_result["assertions"] + phase_10c2c_result["assertions"]
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
	failures.append_array(phase_5b3a_result["failures"])
	failures.append_array(phase_5b3b1_result["failures"])
	failures.append_array(phase_5b3b2a_result["failures"])
	failures.append_array(phase_5b3b2b_result["failures"])
	failures.append_array(cxr2_result["failures"])
	failures.append_array(phase_6b1_result["failures"])
	failures.append_array(phase_6b2_result["failures"])
	failures.append_array(phase_6b3_result["failures"])
	failures.append_array(phase_7b1_world_result["failures"])
	failures.append_array(phase_7b1_npc_result["failures"])
	failures.append_array(phase_7b2_result["failures"])
	failures.append_array(phase_7b3_result["failures"])
	failures.append_array(phase_8b1_result["failures"])
	failures.append_array(phase_8b2_unit_result["failures"])
	failures.append_array(phase_8b2_loop_result["failures"])
	failures.append_array(phase_9b1_result["failures"])
	failures.append_array(phase_9b2_factory_result["failures"])
	failures.append_array(phase_9b2_player_result["failures"])
	failures.append_array(phase_9b2_loop_result["failures"])
	failures.append_array(phase_9b3b1_result["failures"])
	failures.append_array(phase_9b3b2_policy_result["failures"])
	failures.append_array(phase_9b3b2_runtime_result["failures"])
	failures.append_array(phase_9b3b3_result["failures"])
	failures.append_array(phase_10b1_codec_result["failures"])
	failures.append_array(phase_10b1_random_result["failures"])
	failures.append_array(phase_10b1_repository_result["failures"])
	failures.append_array(phase_10b2_result["failures"])
	failures.append_array(phase_10b3_result["failures"])
	failures.append_array(phase_10b4_result["failures"])
	failures.append_array(phase_10c1a_result["failures"])
	failures.append_array(phase_10c1c_result["failures"])
	failures.append_array(phase_10c2a_result["failures"])
	failures.append_array(phase_10c2a_audit_result["failures"])
	failures.append_array(phase_10c2b_result["failures"])
	failures.append_array(phase_10c2b_audit_result["failures"])
	failures.append_array(phase_10c2c_result["failures"])
	if failures.is_empty():
		print("PASS: %d assertions" % assertion_count)
		quit(0)
		return

	for failure: String in failures:
		push_error(str(failure))
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertion_count])
	quit(1)
