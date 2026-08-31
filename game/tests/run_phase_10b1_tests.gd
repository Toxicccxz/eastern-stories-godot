extends SceneTree

const CodecTest := preload("res://tests/core/game_save_json_codec_test.gd")
const RandomTest := preload("res://tests/runtime/random_stream_persistence_test.gd")
const RepositoryTest := preload("res://tests/runtime/game_save_repository_test.gd")
const ItemRegressionTest := preload("res://tests/core/native_item_save_restore_test.gd")


func _init() -> void:
	var scripts: Array[Script] = [
		preload("res://core/persistence/game_save_value_types.gd"),
		preload("res://core/persistence/random_stream_snapshot.gd"),
		preload("res://core/persistence/game_save_snapshot.gd"),
		preload("res://core/persistence/game_save_result.gd"),
		preload("res://core/persistence/decimal_int64_codec.gd"),
		preload("res://core/persistence/game_save_snapshot_validator.gd"),
		preload("res://core/persistence/game_save_json_codec.gd"),
		preload("res://runtime/persistence/save_file_read_result.gd"),
		preload("res://runtime/persistence/save_file_operations.gd"),
		preload("res://runtime/persistence/godot_save_file_operations.gd"),
		preload("res://runtime/persistence/game_save_storage_profile.gd"),
		preload("res://runtime/persistence/game_save_repository.gd"),
		CodecTest, RandomTest, RepositoryTest,
	]
	for script: Script in scripts:
		if not script.can_instantiate():
			printerr("FAIL: Phase 10B1 script cannot instantiate: %s" % script.resource_path)
			quit(1)
			return
	var codec_result: Dictionary = CodecTest.new().run_all()
	var random_result: Dictionary = RandomTest.new().run_all()
	var repository_result: Dictionary = RepositoryTest.new().run_all()
	var item_result: Dictionary = ItemRegressionTest.new().run_all()
	var results: Array[Dictionary] = [codec_result, random_result, repository_result, item_result]
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		var phase_10b1_assertions: int = int(codec_result["assertions"]) + int(random_result["assertions"]) + int(repository_result["assertions"])
		print("PASS Phase 10B1: %d assertions; Phase 4B5A regression: %d assertions; total: %d" % [phase_10b1_assertions, int(item_result["assertions"]), assertions])
		quit(0)
		return
	for failure: String in failures: push_error(failure)
	print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
	quit(1)
