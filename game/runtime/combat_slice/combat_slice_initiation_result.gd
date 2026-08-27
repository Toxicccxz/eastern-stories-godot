class_name CombatSliceInitiationResult
extends RefCounted

enum Outcome {
	INVALID_INPUT,
	INITIATOR_NOT_AVAILABLE,
	TARGET_NOT_AVAILABLE,
	SELF_TARGET_REJECTED,
	DIFFERENT_LOCATION,
	TARGET_DEAD,
	FIRST_RELATIONSHIP_FAILED,
	SECOND_RELATIONSHIP_FAILED,
	COMPLETED,
}

var _outcome: int = Outcome.INVALID_INPUT
var _initiator_id: StringName = &""
var _target_id: StringName = &""
var _initiator_exists: bool = false
var _target_exists: bool = false
var _ids_differ: bool = false
var _same_location: bool = false
var _target_dead: bool = false
var _first_mutation_attempted: bool = false
var _first_mutation_succeeded: bool = false
var _first_mutation_changed: bool = false
var _second_mutation_attempted: bool = false
var _second_mutation_succeeded: bool = false
var _second_mutation_changed: bool = false

var outcome: int:
	get:
		return _outcome
var initiator_id: StringName:
	get:
		return _initiator_id
var target_id: StringName:
	get:
		return _target_id
var initiator_exists: bool:
	get:
		return _initiator_exists
var target_exists: bool:
	get:
		return _target_exists
var ids_differ: bool:
	get:
		return _ids_differ
var same_location: bool:
	get:
		return _same_location
var target_dead: bool:
	get:
		return _target_dead
var first_mutation_attempted: bool:
	get:
		return _first_mutation_attempted
var first_mutation_succeeded: bool:
	get:
		return _first_mutation_succeeded
var first_mutation_changed: bool:
	get:
		return _first_mutation_changed
var second_mutation_attempted: bool:
	get:
		return _second_mutation_attempted
var second_mutation_succeeded: bool:
	get:
		return _second_mutation_succeeded
var second_mutation_changed: bool:
	get:
		return _second_mutation_changed
var partial_mutation_preserved: bool:
	get:
		return _first_mutation_succeeded and not _second_mutation_succeeded


func duplicate_snapshot() -> CombatSliceInitiationResult:
	var copy: CombatSliceInitiationResult = CombatSliceInitiationResult.new()
	copy._outcome = _outcome
	copy._initiator_id = _initiator_id
	copy._target_id = _target_id
	copy._initiator_exists = _initiator_exists
	copy._target_exists = _target_exists
	copy._ids_differ = _ids_differ
	copy._same_location = _same_location
	copy._target_dead = _target_dead
	copy._first_mutation_attempted = _first_mutation_attempted
	copy._first_mutation_succeeded = _first_mutation_succeeded
	copy._first_mutation_changed = _first_mutation_changed
	copy._second_mutation_attempted = _second_mutation_attempted
	copy._second_mutation_succeeded = _second_mutation_succeeded
	copy._second_mutation_changed = _second_mutation_changed
	return copy
