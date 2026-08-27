extends SceneTree

const CombatFoundationTest := preload(
	"res://tests/core/combat_state_math_action_foundation_test.gd"
)
const CombatProgressionBusyCompletionTest := preload(
	"res://tests/core/combat_progression_busy_completion_test.gd"
)
const CombatRelationshipOpponentFriendlyStopTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)


func _init() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 5B1 relationship foundation regression")
	results.append(CombatFoundationTest.new().run_all())
	print("RUN Phase 5B2B2 ordinary attack completion regression")
	results.append(CombatProgressionBusyCompletionTest.new().run_all())
	print("RUN Phase 5B3A relationship/opponent/friendly-stop")
	results.append(CombatRelationshipOpponentFriendlyStopTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 5B3A targeted: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL Phase 5B3A targeted: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
