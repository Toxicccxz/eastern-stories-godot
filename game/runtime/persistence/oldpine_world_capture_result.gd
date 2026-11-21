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
	p_adopt: bool = false,
) -> void:
	outcome = p_outcome
	path = p_path
	detail = p_detail
	snapshot = p_snapshot if p_snapshot == null or p_adopt else p_snapshot.duplicate_snapshot()


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS and snapshot != null


## `adopt`: `value` is new and nothing else holds it (the capture's own): the result keeps it as it
## is, without a copy.
static func success(value: GameSaveSnapshot, adopt: bool = false) -> OldPineWorldCaptureResult:
	return OldPineWorldCaptureResult.new(Outcome.SUCCESS, "", "", value, adopt)


static func failure(
	p_outcome: int,
	p_path: String,
	p_detail: String = "",
) -> OldPineWorldCaptureResult:
	return OldPineWorldCaptureResult.new(p_outcome, p_path, p_detail)
