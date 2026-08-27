class_name CombatOpponentAvailabilityFacts
extends RefCounted

var _opponent_id: StringName
var _exists: bool
var _same_location: bool
var _living: bool

var opponent_id: StringName:
	get:
		return _opponent_id
var exists: bool:
	get:
		return _exists
var same_location: bool:
	get:
		return _same_location
var living: bool:
	get:
		return _living


func _init(
	p_opponent_id: StringName = &"",
	p_exists: bool = false,
	p_same_location: bool = false,
	p_living: bool = false,
) -> void:
	_opponent_id = p_opponent_id
	_exists = p_exists
	_same_location = p_same_location
	_living = p_living


func is_valid() -> bool:
	return not _opponent_id.is_empty()


func duplicate_snapshot() -> CombatOpponentAvailabilityFacts:
	return CombatOpponentAvailabilityFacts.new(
		_opponent_id,
		_exists,
		_same_location,
		_living,
	)
