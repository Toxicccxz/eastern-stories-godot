extends RefCounted

const Fixture := preload("res://tests/support/game_save_test_fixture.gd")

class MemoryFiles extends SaveFileOperations:
	var files: Dictionary[String, PackedByteArray] = {}
	var directory_error: int = OK
	var write_error: int = OK
	var corrupt_after_write: bool = false
	var fail_rename_from_suffix: String = ""
	var fail_rename_to_suffix: String = ""
	var fail_remove_suffix: String = ""
	var repository_to_reenter: GameSaveRepository
	var reentry_result: GameSaveResult
	var _reentered: bool = false

	func file_exists(path: String) -> bool:
		return files.has(path)

	func make_directory_recursive(_path: String) -> int:
		return directory_error

	func read_bytes(path: String, maximum_bytes: int) -> SaveFileReadResult:
		if not files.has(path): return SaveFileReadResult.new(ERR_FILE_NOT_FOUND)
		var bytes: PackedByteArray = files[path]
		if bytes.size() > maximum_bytes: return SaveFileReadResult.new(SaveFileReadResult.ERROR_FILE_TOO_LARGE, PackedByteArray(), bytes.size())
		return SaveFileReadResult.new(OK, bytes, bytes.size())

	func write_bytes(path: String, bytes: PackedByteArray) -> int:
		if repository_to_reenter != null and not _reentered:
			_reentered = true
			reentry_result = repository_to_reenter.load()
		if write_error != OK: return write_error
		files[path] = ("{".to_utf8_buffer() if corrupt_after_write else bytes.duplicate())
		return OK

	func rename_file(from_path: String, to_path: String) -> int:
		if (not fail_rename_from_suffix.is_empty() and from_path.ends_with(fail_rename_from_suffix)) or (not fail_rename_to_suffix.is_empty() and to_path.ends_with(fail_rename_to_suffix)):
			return ERR_CANT_CREATE
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK

	func remove_file(path: String) -> int:
		if not fail_remove_suffix.is_empty() and path.ends_with(fail_remove_suffix): return ERR_CANT_CREATE
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK


var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_profiles_and_fixed_paths()
	_test_happy_path_second_save_and_reentry()
	_test_temp_write_and_rotation_failures()
	_test_replace_and_rollback_failures()
	_test_bounded_utf8_and_recovery_results()
	_test_actual_godot_rename_contract()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_profiles_and_fixed_paths() -> void:
	var development := GameSaveStorageProfile.development()
	var release := GameSaveStorageProfile.release()
	var test := GameSaveStorageProfile.isolated_test("phase10b1-safe_1")
	_assert_true(development.is_valid(), "development profile is valid")
	_assert_true(release.is_valid(), "release profile is valid")
	_assert_true(test.is_valid(), "isolated test profile is valid")
	_assert_ne(development.canonical_path(), release.canonical_path(), "development and release paths differ")
	_assert_true(test.canonical_path().begins_with("user://save-data/tests/"), "test path stays beneath test root")
	_assert_true(test.canonical_path().ends_with("/default-v1.json"), "slot filename is fixed")
	for unsafe: String in ["../release", "a/b", "C:\\save", "", ".", "two words"]:
		_assert_false(GameSaveStorageProfile.isolated_test(unsafe).is_valid(), "unsafe test child rejects: %s" % unsafe)


func _test_happy_path_second_save_and_reentry() -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10b1-memory-happy")
	var files := MemoryFiles.new()
	var repository := GameSaveRepository.new(profile, files)
	files.repository_to_reenter = repository
	var first: GameSaveSnapshot = Fixture.substantial(&"test", 1)
	var second: GameSaveSnapshot = Fixture.substantial(&"test", 2)
	_assert_true(repository.save(first).succeeded(), "first repository save succeeds")
	_assert_eq(files.reentry_result.outcome, GameSaveResult.Outcome.OPERATION_IN_PROGRESS, "synchronous operation gate rejects reentry")
	_assert_true(files.file_exists(profile.canonical_path()), "first save creates canonical")
	_assert_false(files.file_exists(profile.backup_path()), "first save creates no backup")
	var loaded: GameSaveResult = repository.load()
	_assert_true(loaded.succeeded(), "saved snapshot loads")
	_assert_eq(loaded.snapshot.player.character.kee.current, 82, "loaded first snapshot is exact")
	_assert_true(repository.save(second).succeeded(), "second repository save succeeds")
	_assert_eq(repository.load().snapshot.player.character.kee.current, 83, "canonical contains second snapshot")
	var backup: GameSaveResult = GameSaveJsonCodec.decode(files.files[profile.backup_path()].get_string_from_utf8())
	_assert_true(backup.succeeded(), "backup remains a valid previous save")
	_assert_eq(backup.snapshot.player.character.kee.current, 82, "backup contains first snapshot")


func _test_temp_write_and_rotation_failures() -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10b1-memory-temp")
	var directory_files := MemoryFiles.new()
	directory_files.directory_error = ERR_CANT_CREATE
	_assert_eq(GameSaveRepository.new(profile, directory_files).save(Fixture.substantial()).outcome, GameSaveResult.Outcome.WRITE_FAILED, "directory creation failure is typed")
	var files := MemoryFiles.new()
	var repository := GameSaveRepository.new(profile, files)
	_assert_true(repository.save(Fixture.substantial(&"test", 1)).succeeded(), "failure fixture canonical exists")
	var canonical_before: PackedByteArray = files.files[profile.canonical_path()].duplicate()
	files.corrupt_after_write = true
	_assert_eq(repository.save(Fixture.substantial(&"test", 2)).outcome, GameSaveResult.Outcome.TEMP_VERIFY_FAILED, "corrupt temp fails verification")
	_assert_eq(files.files[profile.canonical_path()], canonical_before, "corrupt temp leaves canonical exact")
	files.corrupt_after_write = false
	files.write_error = ERR_CANT_CREATE
	_assert_eq(repository.save(Fixture.substantial(&"test", 2)).outcome, GameSaveResult.Outcome.WRITE_FAILED, "temp write failure is typed")
	_assert_eq(files.files[profile.canonical_path()], canonical_before, "write failure leaves canonical exact")
	files.write_error = OK
	files.fail_rename_from_suffix = "default-v1.json"
	_assert_eq(repository.save(Fixture.substantial(&"test", 2)).outcome, GameSaveResult.Outcome.REPLACE_FAILED, "canonical-to-backup failure is typed")
	_assert_eq(files.files[profile.canonical_path()], canonical_before, "rotation failure leaves canonical exact")


func _test_replace_and_rollback_failures() -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10b1-memory-replace")
	var files := MemoryFiles.new()
	var repository := GameSaveRepository.new(profile, files)
	_assert_true(repository.save(Fixture.substantial(&"test", 1)).succeeded(), "replace fixture canonical exists")
	files.fail_rename_from_suffix = ".tmp"
	var result: GameSaveResult = repository.save(Fixture.substantial(&"test", 2))
	_assert_eq(result.outcome, GameSaveResult.Outcome.REPLACE_FAILED, "temp-to-canonical failure is typed")
	_assert_false(result.rollback_failed, "successful backup rollback is reported")
	_assert_true(files.file_exists(profile.canonical_path()), "rollback restores canonical")
	_assert_eq(GameSaveJsonCodec.decode(files.files[profile.canonical_path()].get_string_from_utf8()).snapshot.player.character.kee.current, 82, "rollback restores old bytes")
	files.fail_rename_to_suffix = "default-v1.json"
	result = repository.save(Fixture.substantial(&"test", 3))
	_assert_eq(result.outcome, GameSaveResult.Outcome.REPLACE_FAILED, "second final rename failure remains typed")
	_assert_true(result.rollback_failed, "rollback failure is precise evidence")
	_assert_true(files.file_exists(profile.backup_path()), "failed rollback preserves backup recovery file")
	_assert_true(files.file_exists(profile.temp_path()), "failed rollback preserves temp recovery file")


func _test_bounded_utf8_and_recovery_results() -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10b1-memory-read")
	var files := MemoryFiles.new()
	var repository := GameSaveRepository.new(profile, files)
	_assert_eq(repository.load().outcome, GameSaveResult.Outcome.NO_SAVE, "missing canonical and recovery returns NO_SAVE")
	files.files[profile.canonical_path()] = PackedByteArray([0xC3, 0x28])
	_assert_eq(repository.load().outcome, GameSaveResult.Outcome.INVALID_UTF8, "invalid UTF-8 rejects distinctly")
	files.files[profile.canonical_path()] = PackedByteArray()
	files.files[profile.canonical_path()].resize(GameSaveRepository.MAXIMUM_FILE_BYTES + 1)
	_assert_eq(repository.load().outcome, GameSaveResult.Outcome.FILE_TOO_LARGE, "oversized canonical rejects before JSON")
	files.files.erase(profile.canonical_path())
	files.files[profile.backup_path()] = GameSaveJsonCodec.encode(Fixture.substantial()).text.to_utf8_buffer()
	_assert_eq(repository.load().outcome, GameSaveResult.Outcome.BACKUP_AVAILABLE, "valid backup is recovery evidence, not auto-load")
	files.files.erase(profile.backup_path())
	files.files[profile.temp_path()] = GameSaveJsonCodec.encode(Fixture.substantial()).text.to_utf8_buffer()
	_assert_eq(repository.load().outcome, GameSaveResult.Outcome.BACKUP_AVAILABLE, "valid temp is recovery evidence, not auto-load")
	files.files[profile.canonical_path()] = "{".to_utf8_buffer()
	_assert_eq(repository.load().outcome, GameSaveResult.Outcome.BACKUP_AVAILABLE, "invalid canonical plus valid temp reports recovery")


func _test_actual_godot_rename_contract() -> void:
	var suite_id: String = "phase10b1-rename-%d" % Time.get_ticks_usec()
	var profile := GameSaveStorageProfile.isolated_test(suite_id)
	var files := GodotSaveFileOperations.new()
	_assert_eq(files.make_directory_recursive(profile.directory_path), OK, "Godot creates isolated test directory")
	var source: String = profile.directory_path + "/source"
	var destination: String = profile.directory_path + "/destination"
	_assert_eq(files.write_bytes(source, "source".to_utf8_buffer()), OK, "Godot writes rename source")
	_assert_eq(files.rename_file(source, destination), OK, "Godot same-directory rename succeeds")
	_assert_false(files.file_exists(source), "successful rename removes source name")
	_assert_true(files.file_exists(destination), "successful rename creates destination name")
	_assert_ne(files.rename_file(source, profile.directory_path + "/missing-target"), OK, "Godot missing-source rename fails")
	_assert_eq(files.write_bytes(source, "new".to_utf8_buffer()), OK, "Godot recreates source")
	var destination_exists_result: int = files.rename_file(source, destination)
	_assert_eq(destination_exists_result, OK, "Godot 4.7.2 rename replaces an existing destination on Windows")
	var destination_bytes: SaveFileReadResult = files.read_bytes(destination, 100)
	_assert_eq(destination_bytes.bytes.get_string_from_utf8(), "new", "destination replacement contains source bytes")
	if files.file_exists(source): files.remove_file(source)
	if files.file_exists(destination): files.remove_file(destination)
	var repository := GameSaveRepository.new(profile, files)
	_assert_true(repository.save(Fixture.substantial(&"test", 1)).succeeded(), "real Godot file repository first save succeeds")
	_assert_true(repository.save(Fixture.substantial(&"test", 2)).succeeded(), "real Godot file repository second save succeeds")
	_assert_eq(repository.load().snapshot.player.character.kee.current, 83, "real Godot file repository loads latest canonical")
	_assert_true(files.file_exists(profile.backup_path()), "real Godot file repository keeps one prior backup")
	for path: String in [profile.temp_path(), profile.canonical_path(), profile.backup_path()]:
		if files.file_exists(path): files.remove_file(path)
	var cleanup_error: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.directory_path))
	_assert_eq(cleanup_error, OK, "cleanup removes only exact validated test child")


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value: _failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected: _failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_ne(actual: Variant, unexpected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual == unexpected: _failures.append("%s (unexpected %s)" % [message, str(unexpected)])
