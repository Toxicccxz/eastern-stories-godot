class_name BattlePresentationProjection
extends RefCounted

var _encounter_id: StringName
var _mode: int
var _player_id: StringName
var _current_target_id: StringName
var _participants: Array[BattleParticipantProjection]
var _actions: Array[CombatTacticalActionInfo]
var _queued: CombatQueuedAction
var _queue_status: int
var encounter_id: StringName:
	get: return _encounter_id
var active: bool:
	get: return not _encounter_id.is_empty()
var mode: int:
	get: return _mode
var player_id: StringName:
	get: return _player_id
var current_target_id: StringName:
	get: return _current_target_id
var queue_status: int:
	get: return _queue_status


func _init(
	p_encounter_id: StringName = &"", p_mode: int = -1,
	p_player_id: StringName = &"", p_current_target_id: StringName = &"",
	p_participants: Array[BattleParticipantProjection] = [],
	p_actions: Array[CombatTacticalActionInfo] = [],
	p_queued: CombatQueuedAction = null,
	p_queue_status: int = CombatQueuedAction.Status.EMPTY,
) -> void:
	_encounter_id = p_encounter_id
	_mode = p_mode
	_player_id = p_player_id
	_current_target_id = p_current_target_id
	_participants = p_participants.duplicate()
	_actions = p_actions.duplicate()
	_queued = null if p_queued == null else p_queued.duplicate_snapshot()
	_queue_status = p_queue_status


func participants() -> Array[BattleParticipantProjection]:
	return _participants.duplicate()


func actions() -> Array[CombatTacticalActionInfo]:
	return _actions.duplicate()


func queued_action() -> CombatQueuedAction:
	return null if _queued == null else _queued.duplicate_snapshot()


func display_name(id: StringName) -> String:
	if id.is_empty():
		return "none"
	for participant: BattleParticipantProjection in _participants:
		if participant.participant_id == id:
			return participant.display_name
	return String(id)
