class_name RegionDefinition
extends RefCounted

var _region_id: StringName
var _display_name: String

var region_id: StringName:
	get:
		return _region_id
var display_name: String:
	get:
		return _display_name


func _init(p_region_id: StringName = &"", p_display_name: String = "") -> void:
	_region_id = p_region_id
	_display_name = p_display_name


static func from_record(reader: ContentRecordReader) -> RegionDefinition:
	var definition: RegionDefinition = RegionDefinition.new(
		StringName(reader.required_text("id")),
		reader.required_text("name"),
	)
	reader.finish()
	return definition


func is_valid() -> bool:
	return not _region_id.is_empty() and not _display_name.is_empty()
