class_name CombatEncounterEvent
extends RefCounted

const NO_PHASE: int = -1

var _encounter_id: StringName
var _sequence: int
var _kind: int
var _previous_phase: int
var _current_phase: int
var _actor_id: StringName
var _previous_target_id: StringName
var _current_target_id: StringName
var _result: CombatEncounterResult

var encounter_id: StringName:
	get:
		return _encounter_id
var sequence: int:
	get:
		return _sequence
var kind: int:
	get:
		return _kind
var previous_phase: int:
	get:
		return _previous_phase
var current_phase: int:
	get:
		return _current_phase
var actor_id: StringName:
	get:
		return _actor_id
var previous_target_id: StringName:
	get:
		return _previous_target_id
var current_target_id: StringName:
	get:
		return _current_target_id
var result: CombatEncounterResult:
	get:
		return null if _result == null else _result.duplicate_snapshot()


func _init(
	p_encounter_id: StringName = &"",
	p_sequence: int = 0,
	p_kind: int = -1,
	p_previous_phase: int = NO_PHASE,
	p_current_phase: int = NO_PHASE,
	p_actor_id: StringName = &"",
	p_previous_target_id: StringName = &"",
	p_current_target_id: StringName = &"",
	p_result: CombatEncounterResult = null,
) -> void:
	_encounter_id = p_encounter_id
	_sequence = p_sequence
	_kind = p_kind
	_previous_phase = p_previous_phase
	_current_phase = p_current_phase
	_actor_id = p_actor_id
	_previous_target_id = p_previous_target_id
	_current_target_id = p_current_target_id
	_result = null if p_result == null else p_result.duplicate_snapshot()


func is_valid() -> bool:
	if (
		_encounter_id.is_empty()
		or _sequence <= 0
		or not CombatEncounterEventKind.is_valid(_kind)
	):
		return false
	match _kind:
		CombatEncounterEventKind.Value.ENCOUNTER_ESTABLISHED:
			return (
				_previous_phase == CombatEncounterLifecycle.Value.ESTABLISHING
				and _current_phase == CombatEncounterLifecycle.Value.ACTIVE
				and _actor_id.is_empty()
				and _result == null
			)
		CombatEncounterEventKind.Value.PHASE_CHANGED:
			return (
				CombatEncounterLifecycle.can_transition(_previous_phase, _current_phase)
				and _actor_id.is_empty()
				and _result == null
			)
		CombatEncounterEventKind.Value.TARGET_CHANGED:
			return (
				_previous_phase == NO_PHASE
				and _current_phase == NO_PHASE
				and not _actor_id.is_empty()
				and _previous_target_id != _current_target_id
				and (not _previous_target_id.is_empty() or not _current_target_id.is_empty())
				and _result == null
			)
		CombatEncounterEventKind.Value.ENCOUNTER_COMPLETED:
			return (
				_previous_phase == CombatEncounterLifecycle.Value.RESOLVING
				and _current_phase == CombatEncounterLifecycle.Value.COMPLETED
				and _actor_id.is_empty()
				and _result != null
				and _result.is_valid()
				and _result.encounter_id == _encounter_id
				and _result.kind != CombatEncounterResultKind.Value.FAILED_TO_ESTABLISH
			)
		CombatEncounterEventKind.Value.ENCOUNTER_FAILED_TO_ESTABLISH:
			return (
				_previous_phase == CombatEncounterLifecycle.Value.ESTABLISHING
				and _current_phase == CombatEncounterLifecycle.Value.FAILED_TO_ESTABLISH
				and _actor_id.is_empty()
				and _result != null
				and _result.is_valid()
				and _result.encounter_id == _encounter_id
				and _result.kind == CombatEncounterResultKind.Value.FAILED_TO_ESTABLISH
			)
	return false


func duplicate_snapshot() -> CombatEncounterEvent:
	return CombatEncounterEvent.new(
		_encounter_id,
		_sequence,
		_kind,
		_previous_phase,
		_current_phase,
		_actor_id,
		_previous_target_id,
		_current_target_id,
		_result,
	)


static func established(encounter_id: StringName, sequence: int) -> CombatEncounterEvent:
	return CombatEncounterEvent.new(
		encounter_id,
		sequence,
		CombatEncounterEventKind.Value.ENCOUNTER_ESTABLISHED,
		CombatEncounterLifecycle.Value.ESTABLISHING,
		CombatEncounterLifecycle.Value.ACTIVE,
	)


static func phase_changed(
	encounter_id: StringName,
	sequence: int,
	previous_phase: int,
	current_phase: int,
) -> CombatEncounterEvent:
	return CombatEncounterEvent.new(
		encounter_id,
		sequence,
		CombatEncounterEventKind.Value.PHASE_CHANGED,
		previous_phase,
		current_phase,
	)


static func target_changed(
	encounter_id: StringName,
	sequence: int,
	actor_id: StringName,
	previous_target_id: StringName,
	current_target_id: StringName,
) -> CombatEncounterEvent:
	return CombatEncounterEvent.new(
		encounter_id,
		sequence,
		CombatEncounterEventKind.Value.TARGET_CHANGED,
		NO_PHASE,
		NO_PHASE,
		actor_id,
		previous_target_id,
		current_target_id,
	)


static func completed(
	encounter_id: StringName,
	sequence: int,
	value: CombatEncounterResult,
) -> CombatEncounterEvent:
	return CombatEncounterEvent.new(
		encounter_id,
		sequence,
		CombatEncounterEventKind.Value.ENCOUNTER_COMPLETED,
		CombatEncounterLifecycle.Value.RESOLVING,
		CombatEncounterLifecycle.Value.COMPLETED,
		&"",
		&"",
		&"",
		value,
	)

static func failed_to_establish(
	encounter_id: StringName,
	sequence: int,
	value: CombatEncounterResult,
) -> CombatEncounterEvent:
	return CombatEncounterEvent.new(
		encounter_id,
		sequence,
		CombatEncounterEventKind.Value.ENCOUNTER_FAILED_TO_ESTABLISH,
		CombatEncounterLifecycle.Value.ESTABLISHING,
		CombatEncounterLifecycle.Value.FAILED_TO_ESTABLISH,
		&"",
		&"",
		&"",
		value,
	)
