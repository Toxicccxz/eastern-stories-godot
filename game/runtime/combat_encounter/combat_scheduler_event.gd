class_name CombatSchedulerEvent
extends RefCounted

enum Kind {
	PARTICIPANT_SKIPPED,
	ORDINARY_OPPORTUNITY_RESOLVED,
}

enum SkipReason {
	NONE,
	PARTICIPANT_UNAVAILABLE,
	RELATIONSHIP_INACTIVE,
	TARGET_UNAVAILABLE,
}

var _sequence: int
var _logical_cycle: int
var _logical_time_seconds: float
var _kind: int
var _skip_reason: int
var _actor_id: StringName
var _target_id: StringName
var _resolution: CombatSliceOpportunityResult
var _progression_order: int

var progression_order: int:
	get: return _progression_order

var sequence: int:
	get: return _sequence
var logical_cycle: int:
	get: return _logical_cycle
var logical_time_seconds: float:
	get: return _logical_time_seconds
var kind: int:
	get: return _kind
var skip_reason: int:
	get: return _skip_reason
var actor_id: StringName:
	get: return _actor_id
var target_id: StringName:
	get: return _target_id
var resolution: CombatSliceOpportunityResult:
	get:
		return null if _resolution == null else _resolution.duplicate_snapshot()


func _init(
	p_sequence: int = 0,
	p_logical_cycle: int = 0,
	p_logical_time_seconds: float = 0.0,
	p_kind: int = Kind.PARTICIPANT_SKIPPED,
	p_skip_reason: int = SkipReason.PARTICIPANT_UNAVAILABLE,
	p_actor_id: StringName = &"",
	p_target_id: StringName = &"",
	p_resolution: CombatSliceOpportunityResult = null,
	p_progression_order: int = 0,
) -> void:
	_progression_order = p_progression_order
	_sequence = p_sequence
	_logical_cycle = p_logical_cycle
	_logical_time_seconds = p_logical_time_seconds
	_kind = p_kind
	_skip_reason = p_skip_reason
	_actor_id = p_actor_id
	_target_id = p_target_id
	_resolution = (
		null if p_resolution == null else p_resolution.duplicate_snapshot()
	)


func is_valid() -> bool:
	if (
		_sequence <= 0
		or _logical_cycle <= 0
		or not is_finite(_logical_time_seconds)
		or _logical_time_seconds <= 0.0
		or _actor_id.is_empty()
		or _kind not in [Kind.PARTICIPANT_SKIPPED, Kind.ORDINARY_OPPORTUNITY_RESOLVED]
	):
		return false
	if _kind == Kind.PARTICIPANT_SKIPPED:
		return (
			_resolution == null
			and _skip_reason in [
				SkipReason.PARTICIPANT_UNAVAILABLE,
				SkipReason.RELATIONSHIP_INACTIVE,
				SkipReason.TARGET_UNAVAILABLE,
			]
		)
	return _skip_reason == SkipReason.NONE and _resolution != null


func duplicate_snapshot() -> CombatSchedulerEvent:
	return CombatSchedulerEvent.new(
		_sequence,
		_logical_cycle,
		_logical_time_seconds,
		_kind,
		_skip_reason,
		_actor_id,
		_target_id,
		_resolution,
		_progression_order,
	)
