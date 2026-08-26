extends SceneTree

const CharacterStateTest := preload("res://tests/core/character_state_test.gd")
const SkillCoreTest := preload("res://tests/core/skill_core_test.gd")
const CombatFoundationTest := preload(
	"res://tests/core/combat_state_math_action_foundation_test.gd"
)
const CombatOrdinaryAttackTest := preload(
	"res://tests/core/combat_ordinary_attack_core_resolution_test.gd"
)


func _init() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 1 character resource regression")
	results.append(CharacterStateTest.new().run_all())
	print("RUN Phase 3A skill regression")
	results.append(SkillCoreTest.new().run_all())
	print("RUN Phase 5B1 combat foundation regression")
	results.append(CombatFoundationTest.new().run_all())
	print("RUN Phase 5B2A ordinary attack core")
	results.append(CombatOrdinaryAttackTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 5B2A targeted: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL Phase 5B2A targeted: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
