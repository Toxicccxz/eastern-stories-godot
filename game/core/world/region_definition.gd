class_name RegionDefinition
extends RefCounted

var _region_id: StringName
var _display_name: String
var _legacy_source_roots: Array[String] = []

var region_id: StringName:
	get:
		return _region_id
var display_name: String:
	get:
		return _display_name


func _init(
	p_region_id: StringName = &"",
	p_display_name: String = "",
	p_legacy_source_roots: Array[String] = [],
) -> void:
	_region_id = p_region_id
	_display_name = p_display_name
	_legacy_source_roots = p_legacy_source_roots.duplicate()


func legacy_source_roots() -> Array[String]:
	return _legacy_source_roots.duplicate()


func is_valid() -> bool:
	return not _region_id.is_empty() and not _display_name.is_empty()
