class_name OldPineRuntimeSaveLoadResult
extends RefCounted

enum Outcome {
	SUCCESS,
	REQUEST_REJECTED,
	NO_CURRENT_SESSION,
	SAVE_BLOCKED,
	CAPTURE_FAILED,
	REPOSITORY_FAILED,
	RESTORE_FAILED,
	SESSION_SUSPEND_FAILED,
	ACTIVATION_FAILED,
	ROLLBACK_FAILED,
	NEW_GAME_FAILED,
	SESSION_INVARIANT_FAILED,
}

var outcome: int
var eligibility: OldPineSaveEligibilityResult
var capture: OldPineWorldCaptureResult
var repository: GameSaveResult
var restore: OldPineWorldRestoreResult
var session: OldPineWorldSessionController


func _init(p_outcome: int = Outcome.REQUEST_REJECTED) -> void:
	outcome = p_outcome


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS


static func success(value: OldPineWorldSessionController) -> OldPineRuntimeSaveLoadResult:
	var result := OldPineRuntimeSaveLoadResult.new(Outcome.SUCCESS)
	result.session = value
	return result


static func failure(value: int) -> OldPineRuntimeSaveLoadResult:
	return OldPineRuntimeSaveLoadResult.new(value)
