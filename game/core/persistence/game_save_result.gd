class_name GameSaveResult
extends RefCounted

enum Outcome {
	SUCCESS,
	NO_SAVE,
	READ_FAILED,
	INVALID_UTF8,
	FILE_TOO_LARGE,
	MALFORMED_JSON,
	INVALID_ROOT,
	INVALID_FORMAT_ID,
	UNSUPPORTED_GAME_SCHEMA,
	UNSUPPORTED_ITEM_SCHEMA,
	MISSING_FIELD,
	INVALID_FIELD_TYPE,
	INVALID_INTEGER,
	INTEGER_OUT_OF_RANGE,
	INVALID_FINITE_NUMBER,
	DUPLICATE_ID,
	INVALID_RANDOM_STREAM,
	INVALID_SNAPSHOT,
	WRITE_FAILED,
	TEMP_VERIFY_FAILED,
	BACKUP_AVAILABLE,
	REPLACE_FAILED,
	OPERATION_IN_PROGRESS,
}

var outcome: int
var path: String
var detail: String
var snapshot: GameSaveSnapshot
var text: String
var rollback_failed: bool


func _init(
	p_outcome: int = Outcome.SUCCESS,
	p_path: String = "",
	p_detail: String = "",
	p_snapshot: GameSaveSnapshot = null,
	p_text: String = "",
	p_rollback_failed: bool = false,
) -> void:
	outcome = p_outcome
	path = p_path
	detail = p_detail
	snapshot = null if p_snapshot == null else p_snapshot.duplicate_snapshot()
	text = p_text
	rollback_failed = p_rollback_failed


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS


static func success(p_snapshot: GameSaveSnapshot = null) -> GameSaveResult:
	return GameSaveResult.new(Outcome.SUCCESS, "", "", p_snapshot)


static func encoded_success(p_text: String) -> GameSaveResult:
	return GameSaveResult.new(Outcome.SUCCESS, "", "", null, p_text)


static func failure(p_outcome: int, p_path: String, p_detail: String = "", p_rollback_failed: bool = false) -> GameSaveResult:
	return GameSaveResult.new(p_outcome, p_path, p_detail, null, "", p_rollback_failed)
