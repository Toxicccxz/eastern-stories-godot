extends SceneTree

const Cxr3LifecycleTest := preload(
	"res://tests/runtime/combat_encounter_lifecycle_test.gd"
)
const Cxr2CoreTest := preload(
	"res://tests/core/combat_encounter_core_test.gd"
)
const WorldSessionTest := preload(
	"res://tests/runtime/oldpine_world_session_test.gd"
)
const PortalAggressionTest := preload(
	"res://tests/runtime/oldpine_portal_aggression_test.gd"
)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var results: Array[Dictionary] = []
	print("RUN CXR3 world encounter lifecycle")
	results.append(await Cxr3LifecycleTest.new().run_all(self))
	print("RUN CXR2 encounter core regression")
	results.append(Cxr2CoreTest.new().run_all())
	print("RUN Session/resident map regression")
	results.append(await WorldSessionTest.new().run_all(self))
	print("RUN portal/aggression regression")
	results.append(await PortalAggressionTest.new().run_all(self))
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS CXR3 targeted: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr("FAIL CXR3 targeted: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
