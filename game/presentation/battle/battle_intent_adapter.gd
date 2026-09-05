class_name BattleIntentAdapter
extends RefCounted

var _coordinator: CombatEncounterCoordinator
var _player_id: StringName
var _encounter_id: StringName = &""
var _next_correlation: int = 1


func _init(coordinator: CombatEncounterCoordinator, player_id: StringName) -> void:
	_coordinator = coordinator
	_player_id = player_id


func submit(action_id: StringName, declared_target: StringName = &"") -> CombatTacticalResult:
	var encounter: CombatEncounter = _coordinator.active_encounter()
	if encounter == null:
		return CombatTacticalResult.new()
	if _encounter_id != encounter.encounter_id:
		_encounter_id = encounter.encounter_id
		_next_correlation = 1
	var info: CombatTacticalActionInfo
	for registered: CombatTacticalActionInfo in _coordinator.action_infos():
		if registered.action_id == action_id:
			info = registered
			break
	if info == null:
		return CombatTacticalResult.new(CombatTacticalResult.Code.UNKNOWN_ACTION)
	if _next_correlation == 9223372036854775807:
		return CombatTacticalResult.new(CombatTacticalResult.Code.SEQUENCE_EXHAUSTED)
	var request_id := StringName("battle-ui:%s:%d" % [_encounter_id, _next_correlation])
	_next_correlation += 1
	return _coordinator.submit_player_action(CombatTacticalRequest.new(
		request_id, _encounter_id, _player_id, info.action_id, info.category, declared_target,
	))


func cancel(expected_request_id: StringName) -> CombatTacticalResult:
	return _coordinator.cancel_player_action(expected_request_id)
