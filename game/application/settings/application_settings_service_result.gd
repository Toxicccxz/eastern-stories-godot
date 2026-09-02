class_name ApplicationSettingsServiceResult
extends RefCounted

enum Outcome {
	SUCCESS,
	DEFAULTED,
	APPLY_FAILURE,
	PERSISTENCE_FAILURE,
	UNSUPPORTED_CAPABILITY,
}

var _outcome: int
var _repository_outcome: int
var _snapshot: ApplicationSettingsSnapshot


func _init(
	p_outcome: int,
	p_repository_outcome: int,
	p_snapshot: ApplicationSettingsSnapshot,
) -> void:
	_outcome = p_outcome
	_repository_outcome = p_repository_outcome
	_snapshot = p_snapshot


func outcome() -> int:
	return _outcome


func repository_outcome() -> int:
	return _repository_outcome


func snapshot() -> ApplicationSettingsSnapshot:
	return _snapshot


func succeeded() -> bool:
	return _outcome == Outcome.SUCCESS
