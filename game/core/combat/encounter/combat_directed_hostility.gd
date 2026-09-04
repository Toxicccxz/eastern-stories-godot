class_name CombatDirectedHostility
extends RefCounted

var _from_side_id: StringName
var _to_side_id: StringName

var from_side_id: StringName:
	get:
		return _from_side_id
var to_side_id: StringName:
	get:
		return _to_side_id


func _init(
	p_from_side_id: StringName = &"",
	p_to_side_id: StringName = &"",
) -> void:
	_from_side_id = p_from_side_id
	_to_side_id = p_to_side_id


func is_valid() -> bool:
	return (
		not _from_side_id.is_empty()
		and not _to_side_id.is_empty()
		and _from_side_id != _to_side_id
	)


func same_direction(other: CombatDirectedHostility) -> bool:
	return (
		other != null
		and _from_side_id == other.from_side_id
		and _to_side_id == other.to_side_id
	)


func duplicate_snapshot() -> CombatDirectedHostility:
	return CombatDirectedHostility.new(_from_side_id, _to_side_id)
