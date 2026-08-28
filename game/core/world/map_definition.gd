class_name MapDefinition
extends RefCounted

var _map_id: StringName
var _region_id: StringName
var _scene_path: String
var _zone_ids: Array[StringName] = []
var _portal_ids: Array[StringName] = []
var _spawn_ids: Array[StringName] = []

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
	p_zone_ids: Array[StringName] = [],
	p_portal_ids: Array[StringName] = [],
	p_spawn_ids: Array[StringName] = [],
) -> void:
	_map_id = p_map_id
	_region_id = p_region_id
	_scene_path = p_scene_path
	_zone_ids = p_zone_ids.duplicate()
	_portal_ids = p_portal_ids.duplicate()
	_spawn_ids = p_spawn_ids.duplicate()


func zone_ids() -> Array[StringName]:
	return _zone_ids.duplicate()


func portal_ids() -> Array[StringName]:
	return _portal_ids.duplicate()


func spawn_ids() -> Array[StringName]:
	return _spawn_ids.duplicate()


func is_valid() -> bool:
	return (
		not _map_id.is_empty()
		and not _region_id.is_empty()
		and not _scene_path.is_empty()
		and _all_ids_are_unique_and_non_empty(_zone_ids)
		and _all_ids_are_unique_and_non_empty(_portal_ids)
		and _all_ids_are_unique_and_non_empty(_spawn_ids)
	)


static func _all_ids_are_unique_and_non_empty(ids: Array[StringName]) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
