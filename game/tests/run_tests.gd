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
	var assertion_count: int = int(phase_1_result["assertions"]) + int(
		phase_2a_result["assertions"]
	) + int(phase_2b_result["assertions"]) + int(phase_3a_result["assertions"])
	var failures: Array[String] = phase_1_result["failures"]
	failures.append_array(phase_2a_result["failures"])
	failures.append_array(phase_2b_result["failures"])
	failures.append_array(phase_3a_result["failures"])
	if failures.is_empty():
		print("PASS: %d assertions" % assertion_count)
		quit(0)
		return

	for failure: String in failures:
		push_error(str(failure))
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertion_count])
	quit(1)
