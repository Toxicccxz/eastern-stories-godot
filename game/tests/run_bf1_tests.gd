extends SceneTree

const BeastFormulas := preload("res://tests/core/beast_derived_values_test.gd")
const BeastInitialization := preload("res://tests/core/beast_initialization_test.gd")
const SerpentDefinition := preload("res://tests/core/serpent_definition_test.gd")
const CharacterRegression := preload("res://tests/core/character_state_test.gd")
const NpcRegression := preload("res://tests/core/npc_spawn_foundation_test.gd")
const NpcArmorRegression := preload("res://tests/core/npc_armor_loadout_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var assertions: int = 0
	var failures: Array[String] = []
	var suites: Array[Script] = [BeastFormulas, BeastInitialization, SerpentDefinition,
		CharacterRegression, NpcRegression, NpcArmorRegression]
	for suite: Script in suites:
		var result: Dictionary[String, Variant] = suite.new().run_all()
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
		print("%s: %d assertions, %d failures" % [suite.resource_path, result["assertions"], result["failures"].size()])
	for failure: String in failures:
		printerr(failure)
	print("%s BF1 focused + human regressions: %d assertions" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
