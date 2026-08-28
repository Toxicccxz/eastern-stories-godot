class_name OldPineAggressionDecision
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	NOT_AUTHORED,
	PLAYER_NOT_AVAILABLE,
	PLAYER_NOT_ACTIVE,
	NPC_NOT_AVAILABLE,
	NPC_NOT_ACTIVE,
	NPC_ALREADY_FIGHTING,
	DIFFERENT_COMBAT_LOCATION,
	COMBAT_NOT_ALLOWED,
	QUEUED,
	DUPLICATE_PENDING,
	CANCELLED_NOT_PRESENT,
	READY,
}

var _outcome: int = Outcome.INVALID_INPUT
var _npc_id: StringName = &""

var outcome: int:
	get:
		return _outcome
var npc_id: StringName:
	get:
		return _npc_id


func _init(
	p_outcome: int = Outcome.INVALID_INPUT,
	p_npc_id: StringName = &"",
) -> void:
	_outcome = p_outcome
	_npc_id = p_npc_id
