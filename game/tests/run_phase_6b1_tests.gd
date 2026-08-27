extends SceneTree

const Phase6B1Test := preload(
	"res://tests/runtime/combat_slice_opportunity_integration_test.gd"
)
const CombatFoundationTest := preload(
	"res://tests/core/combat_state_math_action_foundation_test.gd"
)
const CombatCompletionTest := preload(
	"res://tests/core/combat_progression_busy_completion_test.gd"
)
const CombatRelationshipTest := preload(
	"res://tests/core/combat_relationship_opponent_friendly_stop_test.gd"
)
const CombatFightTest := preload(
	"res://tests/core/combat_fight_decision_guard_test.gd"
)
const ForwardAttackTest := preload(
	"res://tests/core/combat_single_attack_post_action_riposte_decision_test.gd"
)
const ReverseChainTest := preload(
	"res://tests/core/combat_synchronous_reverse_attack_execution_test.gd"
)
const EquipmentStateTest := preload("res://tests/core/equipment_state_test.gd")


func _init() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 4A1 equipment state regression")
	results.append(EquipmentStateTest.new().run_all())
	print("RUN Phase 5B1 action/equipment-sensitive regression")
	results.append(CombatFoundationTest.new().run_all())
	print("RUN Phase 5B2B2 progression/busy regression")
	results.append(CombatCompletionTest.new().run_all())
	print("RUN Phase 5B3A relationship/opponent regression")
	results.append(CombatRelationshipTest.new().run_all())
	print("RUN Phase 5B3B1 fight/guard regression")
	results.append(CombatFightTest.new().run_all())
	print("RUN Phase 5B3B2A forward composition regression")
	results.append(ForwardAttackTest.new().run_all())
	print("RUN Phase 5B3B2B synchronous reverse regression")
	results.append(ReverseChainTest.new().run_all())
	print("RUN Phase 6B1 runtime combat opportunity bridge")
	results.append(Phase6B1Test.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 6B1 targeted regressions: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL Phase 6B1 targeted regressions: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
