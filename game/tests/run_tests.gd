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
	]
	for script: Script in phase_scripts:
		if not script.can_instantiate():
			printerr("FAIL: character domain script cannot be instantiated: %s" % script.resource_path)
			quit(1)
			return

	var phase_1_result: Dictionary[String, Variant] = CharacterStateTest.new().run_all()
	var phase_2a_result: Dictionary[String, Variant] = CharacterRecoveryTest.new().run_all()
	var assertion_count: int = int(phase_1_result["assertions"]) + int(
		phase_2a_result["assertions"]
	)
	var failures: Array[String] = phase_1_result["failures"]
	failures.append_array(phase_2a_result["failures"])
	if failures.is_empty():
		print("PASS: %d assertions" % assertion_count)
		quit(0)
		return

	for failure: String in failures:
		push_error(str(failure))
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertion_count])
	quit(1)
