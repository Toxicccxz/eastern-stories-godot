class_name OldPineWorldRestoreResult
extends RefCounted

enum Outcome {
	SUCCESS,
	INVALID_SNAPSHOT,
	UNKNOWN_CONTENT_ID,
	ITEM_RESTORE_FAILED,
	CHARACTER_RESTORE_FAILED,
	INCONSISTENT_SPAWN_STATE,
	INCONSISTENT_CORPSE_STATE,
	INVALID_WORLD_LOCATION,
	INVALID_PHYSICAL_POSITION,
	INVALID_RANDOM_STREAM,
	BODY_BINDING_FAILED,
	RECONSTRUCTION_FAILED,
	ACTIVATION_FAILED,
}

var outcome: int
var path: String
var detail: String
var candidate: OldPineWorldSessionController
var preparation: OldPineWorldRestorePreparation


func _init(
	p_outcome: int = Outcome.INVALID_SNAPSHOT,
	p_path: String = "",
	p_detail: String = "",
	p_candidate: OldPineWorldSessionController = null,
	p_preparation: OldPineWorldRestorePreparation = null,
) -> void:
	outcome = p_outcome
	path = p_path
	detail = p_detail
	candidate = p_candidate
	preparation = p_preparation


func succeeded() -> bool:
	return outcome == Outcome.SUCCESS and candidate != null


static func failure(
	p_outcome: int,
	p_path: String,
	p_detail: String = "",
) -> OldPineWorldRestoreResult:
	return OldPineWorldRestoreResult.new(p_outcome, p_path, p_detail)
