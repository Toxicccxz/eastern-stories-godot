class_name OldPineWorldCaptureResult
extends RefCounted

enum Outcome {
	SUCCESS,
	INVALID_SESSION,
	UNREPRESENTED_CHARACTER_STATE,
	ITEM_CAPTURE_FAILED,
	BODY_BINDING_MISSING,
	CORPSE_BINDING_MISSING,
	INVALID_CAPTURED_SNAPSHOT,
}

var outcome: int
var path: String
var detail: String
var snapshot: GameSaveSnapshot


func _init(
	p_outcome: int = Outcome.INVALID_SESSION,
	p_path: String = "",
	p_detail: String = "",
	p_snapshot: GameSaveSnapshot = null,
) -> void:
	outcome = p_outcome
	path = p_path
	detail = p_detail
	snapshot = null if p_snapshot == null else p_snapshot.duplicate_snapshot()


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS and snapshot != null


static func success(value: GameSaveSnapshot) -> OldPineWorldCaptureResult:
	return OldPineWorldCaptureResult.new(Outcome.SUCCESS, "", "", value)


static func failure(
	p_outcome: int,
	p_path: String,
	p_detail: String = "",
) -> OldPineWorldCaptureResult:
	return OldPineWorldCaptureResult.new(p_outcome, p_path, p_detail)
