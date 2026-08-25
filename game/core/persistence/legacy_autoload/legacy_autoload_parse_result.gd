class_name LegacyAutoloadParseResult
extends RefCounted

enum Outcome {
	PARSED,
	MALFORMED_PATH,
}

var _outcome: int
var _original_entry: String
var _entry: LegacyAutoloadEntry

var outcome: int:
	get: return _outcome
var succeeded: bool:
	get: return _outcome == Outcome.PARSED
var original_entry: String:
	get: return _original_entry
var entry: LegacyAutoloadEntry:
	get: return null if _entry == null else _entry.duplicate_snapshot()


func _init(
	p_outcome: int = Outcome.MALFORMED_PATH,
	p_original_entry: String = "",
	p_entry: LegacyAutoloadEntry = null,
) -> void:
	_outcome = p_outcome
	_original_entry = p_original_entry
	_entry = null if p_entry == null else p_entry.duplicate_snapshot()
