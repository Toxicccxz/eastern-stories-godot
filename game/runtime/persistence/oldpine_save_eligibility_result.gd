class_name OldPineSaveEligibilityResult
extends RefCounted

enum Outcome {
	ALLOWED,
	SESSION_NOT_READY,
	RESTORE_STAGED,
	SESSION_SWAP_ACTIVE,
	MAP_HANDOFF_ACTIVE,
	MAP_HANDOFF_PARTIAL,
	CAVE_EXIT_PENDING,
	INCOMPLETE_LIFECYCLE,
	PENDING_AGGRESSION,
	COMBAT_CADENCE_ACTIVE,
	OPPONENT_RELATIONSHIP,
	LETHAL_MARKER,
	BUSY,
	INTERRUPT_THRESHOLD,
	GUARDING,
	LIFE_EXISTENCE_CONTRADICTION,
	UNREPRESENTED_ATTRIBUTE_MODIFIER,
}

var outcome: int
var subject_id: StringName
var detail: String


func _init(
	p_outcome: int = Outcome.SESSION_NOT_READY,
	p_subject_id: StringName = &"",
	p_detail: String = "",
) -> void:
	outcome = p_outcome
	subject_id = p_subject_id
	detail = p_detail


func allowed() -> bool:
	return outcome == Outcome.ALLOWED


static func allow() -> OldPineSaveEligibilityResult:
	return OldPineSaveEligibilityResult.new(Outcome.ALLOWED)


static func block(
	p_outcome: int,
	p_subject_id: StringName = &"",
	p_detail: String = "",
) -> OldPineSaveEligibilityResult:
	return OldPineSaveEligibilityResult.new(
		p_outcome,
		p_subject_id,
		p_detail,
	)
