class_name GameSaveRepository
extends RefCounted

const MAXIMUM_FILE_BYTES: int = 16 * 1024 * 1024

var _profile: GameSaveStorageProfile
var _files: SaveFileOperations
var _operation_in_progress: bool = false


func _init(p_profile: GameSaveStorageProfile, p_files: SaveFileOperations = null) -> void:
	_profile = p_profile
	_files = GodotSaveFileOperations.new() if p_files == null else p_files


func save(snapshot: GameSaveSnapshot) -> GameSaveResult:
	if not _begin_operation():
		return GameSaveResult.failure(GameSaveResult.Outcome.OPERATION_IN_PROGRESS, "repository")
	var result: GameSaveResult = _save_impl(snapshot)
	_operation_in_progress = false
	return result


func load() -> GameSaveResult:
	if not _begin_operation():
		return GameSaveResult.failure(GameSaveResult.Outcome.OPERATION_IN_PROGRESS, "repository")
	var result: GameSaveResult = _load_impl()
	_operation_in_progress = false
	return result


func operation_in_progress() -> bool:
	return _operation_in_progress


func _begin_operation() -> bool:
	if _operation_in_progress or _profile == null or not _profile.is_valid() or _files == null:
		return false
	_operation_in_progress = true
	return true


func _save_impl(snapshot: GameSaveSnapshot) -> GameSaveResult:
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	if not encoded.succeeded(): return encoded
	var directory_error: int = _files.make_directory_recursive(_profile.directory_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return GameSaveResult.failure(GameSaveResult.Outcome.WRITE_FAILED, _profile.directory_path, error_string(directory_error))
	var bytes: PackedByteArray = encoded.text.to_utf8_buffer()
	if bytes.size() > MAXIMUM_FILE_BYTES:
		return GameSaveResult.failure(GameSaveResult.Outcome.FILE_TOO_LARGE, "encoded_save")
	var write_error: int = _files.write_bytes(_profile.temp_path(), bytes)
	if write_error != OK:
		return GameSaveResult.failure(GameSaveResult.Outcome.WRITE_FAILED, _profile.temp_path(), error_string(write_error))
	var verified: GameSaveResult = _read_snapshot(_profile.temp_path())
	if not verified.succeeded():
		return GameSaveResult.failure(GameSaveResult.Outcome.TEMP_VERIFY_FAILED, verified.path, verified.detail)
	if _files.file_exists(_profile.backup_path()):
		var remove_error: int = _files.remove_file(_profile.backup_path())
		if remove_error != OK:
			return GameSaveResult.failure(GameSaveResult.Outcome.REPLACE_FAILED, _profile.backup_path(), error_string(remove_error))
	var rotated: bool = false
	if _files.file_exists(_profile.canonical_path()):
		var rotate_error: int = _files.rename_file(_profile.canonical_path(), _profile.backup_path())
		if rotate_error != OK:
			return GameSaveResult.failure(GameSaveResult.Outcome.REPLACE_FAILED, _profile.canonical_path(), "canonical-to-backup: " + error_string(rotate_error))
		rotated = true
	var replace_error: int = _files.rename_file(_profile.temp_path(), _profile.canonical_path())
	if replace_error != OK:
		var rollback_failed: bool = false
		var rollback_detail: String = ""
		if rotated:
			var rollback_error: int = _files.rename_file(_profile.backup_path(), _profile.canonical_path())
			rollback_failed = rollback_error != OK
			if rollback_failed: rollback_detail = "; rollback: " + error_string(rollback_error)
		return GameSaveResult.failure(GameSaveResult.Outcome.REPLACE_FAILED, _profile.canonical_path(), "temp-to-canonical: " + error_string(replace_error) + rollback_detail, rollback_failed)
	return GameSaveResult.success(snapshot)


func _load_impl() -> GameSaveResult:
	if not _files.file_exists(_profile.canonical_path()):
		if _has_valid_recovery_candidate():
			return GameSaveResult.failure(GameSaveResult.Outcome.BACKUP_AVAILABLE, _profile.canonical_path(), "validated recovery file exists")
		return GameSaveResult.failure(GameSaveResult.Outcome.NO_SAVE, _profile.canonical_path())
	var canonical: GameSaveResult = _read_snapshot(_profile.canonical_path())
	if canonical.succeeded(): return canonical
	if _has_valid_recovery_candidate():
		return GameSaveResult.failure(GameSaveResult.Outcome.BACKUP_AVAILABLE, _profile.canonical_path(), "canonical invalid; validated recovery file exists")
	return canonical


func _has_valid_recovery_candidate() -> bool:
	for path: String in [_profile.backup_path(), _profile.temp_path()]:
		if _files.file_exists(path) and _read_snapshot(path).succeeded():
			return true
	return false


func _read_snapshot(path: String) -> GameSaveResult:
	var read: SaveFileReadResult = _files.read_bytes(path, MAXIMUM_FILE_BYTES)
	if read.error == SaveFileReadResult.ERROR_FILE_TOO_LARGE or read.file_size > MAXIMUM_FILE_BYTES:
		return GameSaveResult.failure(GameSaveResult.Outcome.FILE_TOO_LARGE, path)
	if read.error != OK:
		return GameSaveResult.failure(GameSaveResult.Outcome.READ_FAILED, path, error_string(read.error))
	if not _is_valid_utf8(read.bytes):
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_UTF8, path)
	return GameSaveJsonCodec.decode(read.bytes.get_string_from_utf8())


static func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first <= 0x7F:
			index += 1
			continue
		var continuation_count: int
		var minimum_second: int = 0x80
		var maximum_second: int = 0xBF
		if first >= 0xC2 and first <= 0xDF:
			continuation_count = 1
		elif first >= 0xE0 and first <= 0xEF:
			continuation_count = 2
			if first == 0xE0: minimum_second = 0xA0
			if first == 0xED: maximum_second = 0x9F
		elif first >= 0xF0 and first <= 0xF4:
			continuation_count = 3
			if first == 0xF0: minimum_second = 0x90
			if first == 0xF4: maximum_second = 0x8F
		else:
			return false
		if index + continuation_count >= bytes.size(): return false
		var second: int = bytes[index + 1]
		if second < minimum_second or second > maximum_second: return false
		for offset: int in range(2, continuation_count + 1):
			var next: int = bytes[index + offset]
			if next < 0x80 or next > 0xBF: return false
		index += continuation_count + 1
	return true
