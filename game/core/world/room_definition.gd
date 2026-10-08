class_name RoomDefinition
extends RefCounted

## One ES2 room as authored: `set("short")`, `set("long")`, its static
## `set("exits")`, `set("no_fight")`, `set("no_magic")` and whether it is `set("outdoors")`. Exit
## targets are room IDs that may not be migrated yet.
var _room_id: StringName
var _short: String
var _long: String
var _exits: Dictionary[String, StringName] = {}
var _no_fight: bool
var _no_magic: bool
var _outdoors: bool

var room_id: StringName:
	get:
		return _room_id
var short: String:
	get:
		return _short
## Authored text, including the MUD's hard line breaks.
var long: String:
	get:
		return _long
## cmds/std/kill.c and fight.c refuse here: "这里不准战斗。"
var no_fight: bool:
	get:
		return _no_fight
## cmds/std/cast.c refuses here: "这里不准念咒文。"
var no_magic: bool:
	get:
		return _no_magic
## Under the open sky (set("outdoors"), any area name): rope.c finds nowhere to hang a rope.
var outdoors: bool:
	get:
		return _outdoors


func _init(
	p_room_id: StringName = &"",
	p_short: String = "",
	p_long: String = "",
	p_exits: Dictionary[String, StringName] = {},
	p_no_fight: bool = false,
) -> void:
	_room_id = p_room_id
	_short = p_short
	_long = p_long
	_exits = p_exits.duplicate()
	_no_fight = p_no_fight


static func from_record(reader: ContentRecordReader) -> RoomDefinition:
	var exits: Dictionary[String, StringName] = {}
	var exit_reader: ContentRecordReader = reader.child("exits")
	if exit_reader != null:
		for direction: String in exit_reader.keys():
			var target: String = exit_reader.required_text(direction)
			if not target.is_empty():
				exits[direction] = StringName(target)
		exit_reader.finish()
	var definition: RoomDefinition = RoomDefinition.new(
		StringName(reader.required_text("id")),
		reader.required_text("short"),
		reader.required_text("long"),
		exits,
		reader.boolean("no_fight", false),
	)
	definition._outdoors = reader.boolean("outdoors", false)
	definition._no_magic = reader.boolean("no_magic", false)
	reader.finish()
	return definition


## Direction → target room ID, in authored order.
func exits() -> Dictionary[String, StringName]:
	return _exits.duplicate()
