class_name MapDefinition
extends RefCounted

## One scene the player walks in. Its zones and portals name it; the catalog
## lists them (ContentCatalog.zones_for_map / portals_for_map).
var _map_id: StringName
var _region_id: StringName
var _scene_path: String

var map_id: StringName:
	get:
		return _map_id
var region_id: StringName:
	get:
		return _region_id
var scene_path: String:
	get:
		return _scene_path


func _init(
	p_map_id: StringName = &"",
	p_region_id: StringName = &"",
	p_scene_path: String = "",
) -> void:
	_map_id = p_map_id
	_region_id = p_region_id
	_scene_path = p_scene_path


static func from_record(reader: ContentRecordReader) -> MapDefinition:
	var definition: MapDefinition = MapDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("region")),
		reader.required_text("scene"),
	)
	reader.finish()
	return definition


func is_valid() -> bool:
	return not _map_id.is_empty() and not _region_id.is_empty() and not _scene_path.is_empty()
