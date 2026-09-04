extends SceneTree

const CharacterStateTest := preload("res://tests/core/character_state_test.gd")
const CombatFoundationTest := preload(
	"res://tests/core/combat_state_math_action_foundation_test.gd"
)
const CombatRelationshipTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const CombatEncounterCoreTest := preload(
	"res://tests/core/combat_encounter_core_test.gd"
)


func _init() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 1 character authority regression")
	results.append(CharacterStateTest.new().run_all())
	print("RUN Phase 5B1 combat foundation regression")
	results.append(CombatFoundationTest.new().run_all())
	print("RUN Phase 5B3A relationship regression")
	results.append(CombatRelationshipTest.new().run_all())
	print("RUN CXR2 CombatEncounter Core")
	var cxr2_result: Dictionary[String, Variant] = CombatEncounterCoreTest.new().run_all()
	results.append(cxr2_result)
	print("CXR2 core assertions: %d" % int(cxr2_result["assertions"]))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS CXR2 targeted: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL CXR2 targeted: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
