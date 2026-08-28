class_name CorpseLootTransferResult
extends RefCounted

enum Outcome {
	COMPLETED,
	COMPLETED_WITH_MERGE,
	PARTIAL_MERGE_FAILED,
	INVALID_REQUEST,
	PLAYER_NOT_AVAILABLE,
	PLAYER_BUSY,
	CORPSE_NOT_AVAILABLE,
	OUT_OF_RANGE,
	ITEM_NOT_AVAILABLE,
	ITEM_NOT_IN_CORPSE,
	CONTENT_UNAVAILABLE,
	TRANSFER_FAILED,
	CORPSE_WORN_LOCKED,
}

var _outcome: int
var _succeeded: bool
var _actor_character_id: StringName
var _corpse_item_instance_id: StringName
var _requested_item_instance_id: StringName
var _corpse_transfer_result: CorpseContentTransferResult
var _merge_result: CombinedStackMergeResult
var _resulting_item_instance_id: StringName
var _busy_started: bool

var outcome: int:
	get: return _outcome
var succeeded: bool:
	get: return _succeeded
var actor_character_id: StringName:
	get: return _actor_character_id
var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id
var requested_item_instance_id: StringName:
	get: return _requested_item_instance_id
var corpse_transfer_result: CorpseContentTransferResult:
	get: return _corpse_transfer_result
var merge_result: CombinedStackMergeResult:
	get: return _merge_result
var resulting_item_instance_id: StringName:
	get: return _resulting_item_instance_id
var busy_started: bool:
	get: return _busy_started


func _init(
	p_outcome: int = Outcome.INVALID_REQUEST,
	p_succeeded: bool = false,
	p_actor_character_id: StringName = &"",
	p_corpse_item_instance_id: StringName = &"",
	p_requested_item_instance_id: StringName = &"",
	p_corpse_transfer_result: CorpseContentTransferResult = null,
	p_merge_result: CombinedStackMergeResult = null,
	p_resulting_item_instance_id: StringName = &"",
	p_busy_started: bool = false,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_actor_character_id = p_actor_character_id
	_corpse_item_instance_id = p_corpse_item_instance_id
	_requested_item_instance_id = p_requested_item_instance_id
	_corpse_transfer_result = p_corpse_transfer_result
	_merge_result = p_merge_result
	_resulting_item_instance_id = p_resulting_item_instance_id
	_busy_started = p_busy_started


func ownership_completed() -> bool:
	return _succeeded or _outcome == Outcome.PARTIAL_MERGE_FAILED
