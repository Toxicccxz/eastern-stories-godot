class_name OldPineSaveEligibilityResult
extends RefCounted

enum Outcome {
	ALLOWED,
	SESSION_NOT_READY,
	RESTORE_STAGED,
	SESSION_SWAP_ACTIVE,
	MAP_HANDOFF_ACTIVE,
	MAP_HANDOFF_PARTIAL,
	PASSAGE_PENDING,
	INCOMPLETE_LIFECYCLE,
	PENDING_AGGRESSION,
	OPPONENT_RELATIONSHIP,
	LETHAL_MARKER,
	BUSY,
	GUARDING,
	LIFE_EXISTENCE_CONTRADICTION,
	UNREPRESENTED_ATTRIBUTE_MODIFIER,
	ACTIVE_COMBAT_ENCOUNTER,
	## A scene holds the player (DECISIONS「剧情演出」): its progress is not saved, so it is
	## seen through first.
	SCENE_RUNNING,
	## The player stands where a save cannot put them back (a doorway: door state is not saved;
	## MapPlacementValidator): one step away and it saves. The autosave waits for it
	## (GameAutosave), the player's Save says so (全项目审查第四批).
	PLAYER_POSITION,
	## An NPC is still making something for the player or telling a test blow by blow
	## (WorldMapNpcLife makings, trials: call_outs, not saved): seen through first, or a save
	## would keep the temp mark and lose the thing (全项目审查第四批). The autosave waits for it.
	NPC_WORKING,
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
