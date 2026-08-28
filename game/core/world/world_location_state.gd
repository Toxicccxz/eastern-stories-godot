class_name WorldLocationState
extends RefCounted

var _region_id: StringName
var _map_id: StringName
var _zone_id: StringName
var _combat_location_id: StringName

var region_id: StringName:
	get:
		return _region_id
var map_id: StringName:
	get:
		return _map_id
var zone_id: StringName:
	get:
		return _zone_id
var combat_location_id: StringName:
	get:
		return _combat_location_id


func _init(
	p_region_id: StringName = &"",
	p_map_id: StringName = &"",
	p_zone_id: StringName = &"",
	p_combat_location_id: StringName = &"",
) -> void:
	_region_id = p_region_id
	_map_id = p_map_id
	_zone_id = p_zone_id
	_combat_location_id = p_combat_location_id


func is_valid() -> bool:
	return (
		not _region_id.is_empty()
		and not _map_id.is_empty()
		and not _zone_id.is_empty()
		and not _combat_location_id.is_empty()
	)


func same_location(other: WorldLocationState) -> bool:
	return (
		other != null
		and is_valid()
		and other.is_valid()
		and _region_id == other.region_id
		and _map_id == other.map_id
		and _zone_id == other.zone_id
		and _combat_location_id == other.combat_location_id
	)


func shares_combat_location(other: WorldLocationState) -> bool:
	return (
		other != null
		and is_valid()
		and other.is_valid()
		and _combat_location_id == other.combat_location_id
	)


func duplicate_snapshot() -> WorldLocationState:
	return WorldLocationState.new(
		_region_id,
		_map_id,
		_zone_id,
		_combat_location_id,
	)
