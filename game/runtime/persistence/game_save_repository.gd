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
		_drop_kept(snapshot)
		return GameSaveResult.failure(GameSaveResult.Outcome.OPERATION_IN_PROGRESS, "repository")
	forget_checked()
	var result: GameSaveResult = _save_impl(snapshot)
	_operation_in_progress = false
	return result


func load() -> GameSaveResult:
	if not _begin_operation():
		return GameSaveResult.failure(GameSaveResult.Outcome.OPERATION_IN_PROGRESS, "repository")
	var result: GameSaveResult = _load_impl()
	_operation_in_progress = false
	return result


func inspect_slot() -> GameSaveSlotInspectionResult:
	if not _begin_operation():
		return GameSaveSlotInspectionResult.new(
			GameSaveResult.Outcome.OPERATION_IN_PROGRESS,
		)
	# The main file first: when it is good, the menu offers 继续 and no recovery file
	# (ApplicationProductResultMapper), so the .bak and .tmp are read only when it is not.
	var canonical: GameSaveResult = null
	if _files.file_exists(_profile.canonical_path()):
		canonical = _read_snapshot(_profile.canonical_path(), true)
	var sources: Array[int] = []
	if canonical == null or not canonical.succeeded():
		sources = _valid_recovery_sources()
	var result: GameSaveResult = _load_impl(sources, canonical)
	_operation_in_progress = false
	return GameSaveSlotInspectionResult.new(result.outcome, sources)


func load_recovery(source: int) -> GameSaveResult:
	if not GameSaveRecoverySource.is_valid(source):
		return GameSaveResult.failure(
			GameSaveResult.Outcome.INVALID_FIELD_TYPE,
			"recovery_source",
		)
	if not _begin_operation():
		return GameSaveResult.failure(
			GameSaveResult.Outcome.OPERATION_IN_PROGRESS,
			"repository",
		)
	var path: String = (
		_profile.backup_path()
		if source == GameSaveRecoverySource.Value.BACKUP
		else _profile.temp_path()
	)
	var result: GameSaveResult = (
		_read_snapshot(path)
		if _files.file_exists(path)
		else GameSaveResult.failure(GameSaveResult.Outcome.NO_SAVE, path)
	)
	_operation_in_progress = false
	return result


## A refused save will not check the snapshot: what a check kept on it goes with it
## (OldPineWorldRestoreComposition.validate()), not left for a caller holding the snapshot.
static func _drop_kept(snapshot: GameSaveSnapshot) -> void:
	if snapshot != null:
		snapshot.take_derived()


func operation_in_progress() -> bool:
	return _operation_in_progress


## The slot whose files this repository reads and writes.
func slot_id() -> StringName:
	return &"" if _profile == null else _profile.slot_id


func select_slot(p_slot_id: StringName) -> bool:
	if _profile == null or _operation_in_progress or not GameSaveSnapshot.is_slot_id(p_slot_id):
		return false
	_profile = _profile.for_slot(p_slot_id)
	return true


## A repository of the same kind on `p_slot_id`'s files (the autosave writes through its own,
## on another thread; the list reads each slot through one).
func for_slot(p_slot_id: StringName) -> GameSaveRepository:
	return (get_script() as GDScript).new(_profile.for_slot(p_slot_id), _files) as GameSaveRepository


## What the slot's file says, for its row (GameSaveSlotSummary). Changes nothing.
func read_summary() -> GameSaveSlotSummary:
	var recoverable: bool = _files.file_exists(_profile.backup_path()) or _files.file_exists(_profile.temp_path())
	return _summary_of(_profile.canonical_path(), recoverable)


## What the slot's .bak says: the autosave's is the one before the last (DECISIONS「自动存档」).
func read_backup_summary() -> GameSaveSlotSummary:
	return _summary_of(_profile.backup_path(), false)


## Rows already read, by the file's size and its bytes' hash: [the contract asked, the row].
## A file whose bytes were read before gives the same row without the UTF-8 walk and the
## parse (owner, 2026-11-07: 读取存档 held the frame a fifth of a second), also once it is the
## .bak. Shared by every slot's repository, the workers' among them, so under a lock.
static var _summaries: Dictionary[Vector2i, Array] = {}
static var _summaries_lock: Mutex = Mutex.new()
const SUMMARIES_KEPT: int = 32


func _summary_of(path: String, recoverable: bool) -> GameSaveSlotSummary:
	if not _files.file_exists(path):
		return GameSaveSlotSummary.new(_profile.slot_id, GameSaveSlotSummary.State.EMPTY, recoverable)
	var read: SaveFileReadResult = _files.read_bytes(path, MAXIMUM_FILE_BYTES)
	if read.error != OK:
		return GameSaveSlotSummary.new(_profile.slot_id, GameSaveSlotSummary.State.UNREADABLE, recoverable)
	var key := Vector2i(read.bytes.size(), hash(read.bytes))
	var current_only: bool = _requires_current_public_contract()
	_summaries_lock.lock()
	var known: Array = _summaries.get(key, [])
	_summaries_lock.unlock()
	if known.size() == 2 and bool(known[0]) == current_only:
		return (known[1] as GameSaveSlotSummary).copied(_profile.slot_id, recoverable)
	var summary: GameSaveSlotSummary
	if not _is_valid_utf8(read.bytes):
		summary = GameSaveSlotSummary.new(_profile.slot_id, GameSaveSlotSummary.State.UNREADABLE, recoverable)
	else:
		summary = GameSaveSlotSummary.of_text(_profile.slot_id, read.bytes.get_string_from_utf8(), current_only, recoverable)
	_summaries_lock.lock()
	if _summaries.size() >= SUMMARIES_KEPT:
		_summaries.clear()
	_summaries[key] = [current_only, summary.copied(_profile.slot_id, false)]
	_summaries_lock.unlock()
	return summary


func storage_profile_id() -> StringName:
	return &"" if _profile == null else _profile.profile_id


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


## `read`: the main file as inspect_slot() read it just now (null: read it here).
func _load_impl(valid_recovery_sources: Array[int] = [], read: GameSaveResult = null) -> GameSaveResult:
	if not _files.file_exists(_profile.canonical_path()):
		if _has_valid_recovery_candidate(valid_recovery_sources):
			return GameSaveResult.failure(GameSaveResult.Outcome.BACKUP_AVAILABLE, _profile.canonical_path(), "validated recovery file exists")
		return GameSaveResult.failure(GameSaveResult.Outcome.NO_SAVE, _profile.canonical_path())
	var canonical: GameSaveResult = _read_snapshot(_profile.canonical_path(), false, true) if read == null else read
	if canonical.succeeded(): return canonical
	# Preserve a precise contract refusal, even when an explicit recovery option exists.
	if canonical.outcome in [GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, GameSaveResult.Outcome.UNKNOWN_WORLD_REVISION]:
		return canonical
	if _has_valid_recovery_candidate(valid_recovery_sources):
		return GameSaveResult.failure(GameSaveResult.Outcome.BACKUP_AVAILABLE, _profile.canonical_path(), "canonical invalid; validated recovery file exists")
	return canonical


func _has_valid_recovery_candidate(valid_recovery_sources: Array[int]) -> bool:
	return (
		not valid_recovery_sources.is_empty()
		or not _valid_recovery_sources().is_empty()
	)


func _valid_recovery_sources() -> Array[int]:
	var sources: Array[int] = []
	var candidates: Array[Array] = [
		[GameSaveRecoverySource.Value.BACKUP, _profile.backup_path()],
		[GameSaveRecoverySource.Value.TEMP, _profile.temp_path()],
	]
	for candidate: Array in candidates:
		var source: int = int(candidate[0])
		var path: String = String(candidate[1])
		if _files.file_exists(path) and _read_snapshot(path).succeeded():
			sources.append(source)
	return sources


## The file at `path`, read, decoded and checked in full. `remember`: a good one is kept for
## the next read of the same bytes (inspect_slot(), then 继续). `reuse`: one kept for these very
## bytes is taken instead of decoding them again.
func _read_snapshot(path: String, remember: bool = false, reuse: bool = false) -> GameSaveResult:
	var read: SaveFileReadResult = _files.read_bytes(path, MAXIMUM_FILE_BYTES)
	if read.error == SaveFileReadResult.ERROR_FILE_TOO_LARGE or read.file_size > MAXIMUM_FILE_BYTES:
		return GameSaveResult.failure(GameSaveResult.Outcome.FILE_TOO_LARGE, path)
	if read.error != OK:
		return GameSaveResult.failure(GameSaveResult.Outcome.READ_FAILED, path, error_string(read.error))
	if reuse:
		var kept: GameSaveSnapshot = _take_checked(path, read.bytes)
		if kept != null:
			return GameSaveResult.success(kept)
	if not _is_valid_utf8(read.bytes):
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_UTF8, path)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(read.bytes.get_string_from_utf8(), _requires_current_public_contract())
	if decoded.succeeded():
		decoded = _checked(decoded.snapshot)
	if remember and decoded.succeeded():
		_keep_checked(path, read.bytes, decoded.snapshot)
	return decoded


## What a decoded snapshot must pass besides the codec's rules before it is given out
## (SourceEntrySaveRepository: the world's own check).
func _checked(snapshot: GameSaveSnapshot) -> GameSaveResult:
	return GameSaveResult.success(snapshot)


## The one snapshot read and checked in full and not yet taken (the menu's inspection of the
## slot 继续 then loads): [path, the repository's script, the contract asked, size, hash, bytes,
## snapshot]. 继续 reads the file again and takes it only when every byte is the same; any
## other read decodes in full. Taken once (validate()'s preparation kept on it goes with it);
## dropped by a save, a new inspection, and forget_checked(). Read on worker threads: locked.
static var _kept_check: Array = []
static var _kept_check_lock: Mutex = Mutex.new()


func _keep_checked(path: String, bytes: PackedByteArray, snapshot: GameSaveSnapshot) -> void:
	_kept_check_lock.lock()
	_kept_check = [path, get_script(), _requires_current_public_contract(), bytes.size(), hash(bytes), bytes, snapshot]
	_kept_check_lock.unlock()


func _take_checked(path: String, bytes: PackedByteArray) -> GameSaveSnapshot:
	_kept_check_lock.lock()
	var kept: Array = _kept_check
	_kept_check = []
	_kept_check_lock.unlock()
	if (
		kept.size() == 7
		and String(kept[0]) == path
		and kept[1] == get_script()
		and bool(kept[2]) == _requires_current_public_contract()
		and int(kept[3]) == bytes.size()
		and int(kept[4]) == hash(bytes)
		and kept[5] == bytes
	):
		return kept[6] as GameSaveSnapshot
	return null


## Lets go of the snapshot a menu's inspection kept (a session began from something else).
static func forget_checked() -> void:
	_kept_check_lock.lock()
	_kept_check = []
	_kept_check_lock.unlock()


func _requires_current_public_contract() -> bool:
	return false


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
