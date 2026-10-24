class_name RegionDefinition
extends RefCounted

var _region_id: StringName
var _display_name: String
var _recommended_exp: int = 0

var region_id: StringName:
	get:
		return _region_id
var display_name: String:
	get:
		return _display_name
## Native (A2 落后补偿): the combat_exp the region is meant for (world.json
## `recommended_exp`); below it the player's gains are larger (ProgressionGain). 0: none.
var recommended_exp: int:
	get:
		return _recommended_exp


func _init(p_region_id: StringName = &"", p_display_name: String = "") -> void:
	_region_id = p_region_id
	_display_name = p_display_name


static func from_record(reader: ContentRecordReader) -> RegionDefinition:
	var definition: RegionDefinition = RegionDefinition.new(
		StringName(reader.required_text("id")),
		reader.required_text("name"),
	)
	definition._recommended_exp = reader.integer("recommended_exp", 0)
	if definition._recommended_exp < 0:
		reader.fail("recommended_exp", "must not be negative")
	reader.finish()
	return definition


func is_valid() -> bool:
	return not _region_id.is_empty() and not _display_name.is_empty()
