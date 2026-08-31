extends RefCounted

const CombatAdapter := preload("res://runtime/combat_slice/godot_combat_random_source.gd")
const NpcAdapter := preload("res://runtime/npcs/godot_npc_initialization_random_source.gd")
const WorldAdapter := preload("res://runtime/world/godot_world_interaction_random_source.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_adapter(CombatAdapter, "Combat")
	_test_adapter(NpcAdapter, "NPC initialization")
	_test_adapter(WorldAdapter, "WorldInteraction")
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_adapter(adapter_script: Script, label: String) -> void:
	for prefix_length: int in [0, 1, 2, 7, 31]:
		var source: RefCounted = adapter_script.new(94721, true)
		var twin: RefCounted = adapter_script.new(94721, true)
		for ignored: int in range(prefix_length):
			_assert_eq(source.next_below(100000), twin.next_below(100000), "%s prefix %d setup sequence matches" % [label, prefix_length])
		var captured: RandomStreamSnapshot = source.capture_random_state()
		var twin_capture: RandomStreamSnapshot = twin.capture_random_state()
		_assert_eq(captured.adapter_id, RandomStreamSnapshot.GODOT_PCG32_ADAPTER_ID, "%s prefix %d uses stable adapter ID" % [label, prefix_length])
		_assert_eq(captured.seed, twin_capture.seed, "%s prefix %d capture preserves seed without draw" % [label, prefix_length])
		_assert_eq(captured.state, twin_capture.state, "%s prefix %d capture preserves state without draw" % [label, prefix_length])
		var expected: Array[int] = []
		for ignored: int in range(8): expected.append(source.next_below(100000))
		var restored: RefCounted = adapter_script.new(-99, true)
		_assert_true(restored.restore_random_state(captured), "%s prefix %d accepts current adapter snapshot" % [label, prefix_length])
		for index: int in range(expected.size()):
			_assert_eq(restored.next_below(100000), expected[index], "%s prefix %d exact continuation draw %d" % [label, prefix_length, index])
		var before_mismatch: RandomStreamSnapshot = restored.capture_random_state()
		_assert_false(restored.restore_random_state(RandomStreamSnapshot.new(&"wrong-adapter", 1, 2)), "%s prefix %d rejects incompatible adapter" % [label, prefix_length])
		var after_mismatch: RandomStreamSnapshot = restored.capture_random_state()
		_assert_eq(after_mismatch.seed, before_mismatch.seed, "%s prefix %d mismatch preserves seed" % [label, prefix_length])
		_assert_eq(after_mismatch.state, before_mismatch.state, "%s prefix %d mismatch preserves state" % [label, prefix_length])
		var control: RefCounted = adapter_script.new(0, true)
		_assert_true(control.restore_random_state(after_mismatch), "%s prefix %d capture remains usable" % [label, prefix_length])
		_assert_eq(control.next_below(100000), restored.next_below(100000), "%s prefix %d capture/restore consumes zero extra draws" % [label, prefix_length])


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value: _failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected: _failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
