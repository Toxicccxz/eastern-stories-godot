class_name ApplicationSettingsResult
extends RefCounted

enum Outcome {
	SUCCESS,
	NO_SETTINGS,
	INVALID_SETTINGS,
	READ_FAILURE,
	WRITE_FAILURE,
	UNSUPPORTED_VERSION,
}

var _outcome: int
var _snapshot: ApplicationSettingsSnapshot


func _init(
	p_outcome: int,
	p_snapshot: ApplicationSettingsSnapshot = null,
) -> void:
	_outcome = p_outcome
	_snapshot = p_snapshot


func outcome() -> int:
	return _outcome


func snapshot() -> ApplicationSettingsSnapshot:
	return _snapshot


func succeeded() -> bool:
	return _outcome == Outcome.SUCCESS and _snapshot != null and _snapshot.is_valid()


static func success(snapshot_value: ApplicationSettingsSnapshot) -> ApplicationSettingsResult:
	return ApplicationSettingsResult.new(Outcome.SUCCESS, snapshot_value)


static func failure(outcome_value: int) -> ApplicationSettingsResult:
	return ApplicationSettingsResult.new(outcome_value, ApplicationSettingsSnapshot.defaults())
