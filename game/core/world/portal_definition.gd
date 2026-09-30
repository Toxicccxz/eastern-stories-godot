class_name PortalDefinition
extends RefCounted

## A way from one zone to a spawn marker in another zone, on the same map or a
## different one. The maps follow from the zones.
var _portal_id: StringName
var _source_map_id: StringName
var _source_zone_id: StringName
var _destination_map_id: StringName
var _destination_zone_id: StringName
var _destination_spawn_point_id: StringName
var _legacy_room_id: StringName
var _legacy_command: String

var portal_id: StringName:
	get:
		return _portal_id
var source_map_id: StringName:
	get:
		return _source_map_id
var source_zone_id: StringName:
	get:
		return _source_zone_id
var destination_map_id: StringName:
	get:
		return _destination_map_id
var destination_zone_id: StringName:
	get:
		return _destination_zone_id
var destination_spawn_point_id: StringName:
	get:
		return _destination_spawn_point_id
## The ES2 room whose exit or command this portal carries.
var legacy_room_id: StringName:
	get:
		return _legacy_room_id
## The ES2 command that used it, e.g. "east" or "climb pine".
var legacy_command: String:
	get:
		return _legacy_command


func _init(
	p_portal_id: StringName = &"",
	p_source_map_id: StringName = &"",
	p_source_zone_id: StringName = &"",
	p_destination_map_id: StringName = &"",
	p_destination_zone_id: StringName = &"",
	p_destination_spawn_point_id: StringName = &"",
	p_legacy_room_id: StringName = &"",
	p_legacy_command: String = "",
) -> void:
	_portal_id = p_portal_id
	_source_map_id = p_source_map_id
	_source_zone_id = p_source_zone_id
	_destination_map_id = p_destination_map_id
	_destination_zone_id = p_destination_zone_id
	_destination_spawn_point_id = p_destination_spawn_point_id
	_legacy_room_id = p_legacy_room_id
	_legacy_command = p_legacy_command


static func from_record(reader: ContentRecordReader) -> PortalDefinition:
	var definition: PortalDefinition = PortalDefinition.new(
		StringName(reader.required_text("id")),
		&"",
		StringName(reader.required_text("from_zone")),
		&"",
		StringName(reader.required_text("to_zone")),
		StringName(reader.required_text("to_spawn")),
		StringName(reader.required_text("legacy_room")),
		reader.required_text("legacy_command"),
	)
	reader.finish()
	return definition


## Copy with the maps of its source and destination zones filled in.
func with_maps(source_map_id: StringName, destination_map_id: StringName) -> PortalDefinition:
	return PortalDefinition.new(
		_portal_id,
		source_map_id,
		_source_zone_id,
		destination_map_id,
		_destination_zone_id,
		_destination_spawn_point_id,
		_legacy_room_id,
		_legacy_command,
	)


func is_valid() -> bool:
	return (
		not _portal_id.is_empty()
		and not _source_map_id.is_empty()
		and not _source_zone_id.is_empty()
		and not _destination_map_id.is_empty()
		and not _destination_zone_id.is_empty()
		and not _destination_spawn_point_id.is_empty()
		and not _legacy_room_id.is_empty()
		and not _legacy_command.is_empty()
	)
