class_name ZoneDefinition
extends RefCounted

var _zone_id: StringName
var _map_id: StringName
var _combat_location_id: StringName
var _display_name: String
var _legacy_room_ids: Array[String] = []
var _flavor_text: String

var zone_id: StringName:
	get:
		return _zone_id
var map_id: StringName:
	get:
		return _map_id
var combat_location_id: StringName:
	get:
		return _combat_location_id
var display_name: String:
	get:
		return _display_name
var flavor_text: String:
	get:
		return _flavor_text


func _init(
	p_zone_id: StringName = &"",
	p_map_id: StringName = &"",
	p_combat_location_id: StringName = &"",
	p_display_name: String = "",
	p_legacy_room_ids: Array[String] = [],
	p_flavor_text: String = "",
) -> void:
	_zone_id = p_zone_id
	_map_id = p_map_id
	_combat_location_id = p_combat_location_id
	_display_name = p_display_name
	_legacy_room_ids = p_legacy_room_ids.duplicate()
	_flavor_text = p_flavor_text


func legacy_room_ids() -> Array[String]:
	return _legacy_room_ids.duplicate()


func is_valid() -> bool:
	return (
		not _zone_id.is_empty()
		and not _map_id.is_empty()
		and not _combat_location_id.is_empty()
		and not _display_name.is_empty()
		and not _legacy_room_ids.is_empty()
	)
