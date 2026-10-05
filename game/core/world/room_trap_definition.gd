class_name RoomTrapDefinition
extends RefCounted

## An ES2 room that shuts its way out behind the player (keep2.c): leaving
## `from_zone` for `to_zone` while the door stands open shouts (HIY) and shuts it
## (valid_leave() deletes the exit) and calls in the `summon` spawn; the room's
## reset, or a played item whose `play` is `opens_on` heard in `from_zone`
## (pipe_notify()), opens it again. Its state is not saved, as doors are not.
const MESSAGES: Array[String] = ["shout", "shut", "open"]

var _trap_id: StringName
var _room_id: StringName
var _door_id: StringName
var _from_zone_id: StringName
var _to_zone_id: StringName
var _summon_spawn_id: StringName
var _opens_on: StringName
var _messages: Dictionary[String, String] = {}
var _legacy_source_path: String

var trap_id: StringName:
	get:
		return _trap_id
## The ES2 room whose reset opens the door again.
var room_id: StringName:
	get:
		return _room_id
var door_id: StringName:
	get:
		return _door_id
var from_zone_id: StringName:
	get:
		return _from_zone_id
var to_zone_id: StringName:
	get:
		return _to_zone_id
var summon_spawn_id: StringName:
	get:
		return _summon_spawn_id
var opens_on: StringName:
	get:
		return _opens_on
var legacy_source_path: String:
	get:
		return _legacy_source_path


static func from_record(reader: ContentRecordReader) -> RoomTrapDefinition:
	var definition: RoomTrapDefinition = RoomTrapDefinition.new()
	definition._trap_id = StringName(reader.required_text("id"))
	definition._room_id = StringName(reader.required_text("room"))
	definition._door_id = StringName(reader.required_text("door"))
	definition._from_zone_id = StringName(reader.required_text("from_zone"))
	definition._to_zone_id = StringName(reader.required_text("to_zone"))
	definition._summon_spawn_id = StringName(reader.text("summon"))
	definition._opens_on = StringName(reader.text("opens_on"))
	var messages: ContentRecordReader = reader.child("messages")
	if messages != null:
		for key: String in messages.keys():
			definition._messages[key] = messages.required_text(key)
		messages.finish()
	definition._legacy_source_path = reader.required_text("legacy_source")
	reader.finish()
	var keys: Array = definition._messages.keys()
	keys.sort()
	var expected: Array = MESSAGES.duplicate()
	expected.sort()
	if keys != expected:
		reader.fail("messages", "a trap needs exactly %s" % [expected])
	if definition._from_zone_id == definition._to_zone_id:
		reader.fail("to_zone", "must differ from from_zone")
	return definition


func message(key: String) -> String:
	return _messages.get(key, "")
