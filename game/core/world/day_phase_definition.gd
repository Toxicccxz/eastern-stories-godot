class_name DayPhaseDefinition
extends RefCounted

## One of the day's eight phases (adm/etc/nature/day_phase; DECISIONS「昼夜」): its length in
## game minutes, the line natured.c sends whoever is outdoors as it begins (`time_msg`) and the
## line look.c adds after an outdoor room's text while it lasts (`desc_msg`), as authored.
## `frame`: the lighting keyframe the voxel view shows for it (dawn, day, dusk, night, midnight).
const FRAMES: Array[String] = ["dawn", "day", "dusk", "night", "midnight"]

var phase_id: StringName
var name: String
var minutes: int
var frame: String
var time_msg: String
var desc_msg: String


func _init(
	p_phase_id: StringName = &"",
	p_name: String = "",
	p_minutes: int = 0,
	p_frame: String = "day",
	p_time_msg: String = "",
	p_desc_msg: String = "",
) -> void:
	phase_id = p_phase_id
	name = p_name
	minutes = p_minutes
	frame = p_frame
	time_msg = p_time_msg
	desc_msg = p_desc_msg


static func from_record(reader: ContentRecordReader) -> DayPhaseDefinition:
	var definition := DayPhaseDefinition.new(
		StringName(reader.required_text("phase_id")),
		reader.required_text("name"),
		reader.required_integer("minutes"),
		reader.text("frame", "day"),
		reader.required_text("time_msg"),
		reader.required_text("desc_msg"),
	)
	reader.finish()
	if definition.minutes <= 0:
		reader.fail("minutes", "must be positive")
	if not FRAMES.has(definition.frame):
		reader.fail("frame", "unknown lighting frame '%s'" % definition.frame)
	return definition
