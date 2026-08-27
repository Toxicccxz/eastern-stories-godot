extends SceneTree

const CombatFoundationTest := preload(
	"res://tests/core/combat_state_math_action_foundation_test.gd"
)
const CombatOrdinaryAttackTest := preload(
	"res://tests/core/combat_ordinary_attack_core_resolution_test.gd"
)
const StandardForceTest := preload(
	"res://tests/core/standard_force_hit_policy_test.gd"
)
const CombatCompletionTest := preload(
	"res://tests/core/combat_progression_busy_completion_test.gd"
)
const CombatRelationshipTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const CombatFightDecisionTest := preload(
	"res://tests/core/combat_fight_decision_guard_test.gd"
)
const CombatSingleAttackTest := preload(
	"res://tests/core/combat_single_attack_post_action_riposte_decision_test.gd"
)


func _init() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 5B1 combat foundation regression")
	results.append(CombatFoundationTest.new().run_all())
	print("RUN Phase 5B2A ordinary attack regression")
	results.append(CombatOrdinaryAttackTest.new().run_all())
	print("RUN Phase 5B2B1 standard force regression")
	results.append(StandardForceTest.new().run_all())
	print("RUN Phase 5B2B2 completion regression")
	results.append(CombatCompletionTest.new().run_all())
	print("RUN Phase 5B3A relationship regression")
	results.append(CombatRelationshipTest.new().run_all())
	print("RUN Phase 5B3B1 fight decision regression")
	results.append(CombatFightDecisionTest.new().run_all())
	print("RUN Phase 5B3B2A single attack composition")
	results.append(CombatSingleAttackTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 5B3B2A targeted: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL Phase 5B3B2A targeted: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
