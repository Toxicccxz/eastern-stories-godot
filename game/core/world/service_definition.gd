class_name ServiceDefinition
extends RefCounted

## Something the player can use at one spot of a zone: an ES2 room's own command
## (bank convert, work, pawn shop, water source, a dance floor, a command that acts on
## the player: `act`, RoomActDefinition). The kind picks the rules;
## the scene places it with a WorldServicePoint of the same ID. What an NPC offers
## (goods, teaching) is on its NPC record and goes with its body (NpcService).
## `coach`: a 车马行 stop (native; CoachLines, DECISIONS「车马行」).
const KINDS: Array[StringName] = [&"bank", &"work", &"hockshop", &"water", &"dance", &"act", &"bounty", &"coach"]

var _service_id: StringName
var _kind: StringName
var _map_id: StringName
var _zone_id: StringName
var _display_name: String
var _reach: int
var _legacy_source: String
var _dance: DanceDefinition
var _act: RoomActDefinition
var _arrival_spawn_id: StringName

var service_id: StringName:
	get:
		return _service_id
var kind: StringName:
	get:
		return _kind
var map_id: StringName:
	get:
		return _map_id
var zone_id: StringName:
	get:
		return _zone_id
var display_name: String:
	get:
		return _display_name
## Pixels from the service point within which the player can use it.
var reach: int:
	get:
		return _reach
var legacy_source: String:
	get:
		return _legacy_source
## The `dance` kind's do_dancing() (DanceDefinition); null for any other kind.
var dance: DanceDefinition:
	get:
		return _dance
## The `act` kind's command (RoomActDefinition); null for any other kind.
var act: RoomActDefinition:
	get:
		return _act
## The `coach` kind's spawn point beside its cart, where a ride from another stop sets the
## player down; "" for any other kind.
var arrival_spawn_id: StringName:
	get:
		return _arrival_spawn_id


func _init(
	p_service_id: StringName = &"",
	p_kind: StringName = &"",
	p_map_id: StringName = &"",
	p_zone_id: StringName = &"",
	p_display_name: String = "",
	p_reach: int = 0,
	p_legacy_source: String = "",
) -> void:
	_service_id = p_service_id
	_kind = p_kind
	_map_id = p_map_id
	_zone_id = p_zone_id
	_display_name = p_display_name
	_reach = p_reach
	_legacy_source = p_legacy_source


static func from_record(reader: ContentRecordReader) -> ServiceDefinition:
	var definition: ServiceDefinition = ServiceDefinition.new(
		StringName(reader.required_text("id")),
		StringName(reader.required_text("kind")),
		&"",
		StringName(reader.required_text("zone")),
		reader.required_text("name"),
		reader.required_integer("reach"),
		reader.required_text("legacy_source"),
	)
	var dance: ContentRecordReader = reader.child("dance")
	if dance != null:
		definition._dance = DanceDefinition.from_record(dance)
	var act: ContentRecordReader = reader.child("act")
	if act != null:
		definition._act = RoomActDefinition.from_record(act)
	definition._arrival_spawn_id = StringName(reader.text("arrival", ""))
	reader.finish()
	if (definition.kind == &"coach") != not definition._arrival_spawn_id.is_empty():
		reader.fail("arrival", "a coach stop and only one has its arrival spawn point")
	if (definition.kind == &"dance") != (definition._dance != null):
		reader.fail("dance", "a dance service and only one has its dance")
	if (definition.kind == &"act") != (definition._act != null):
		reader.fail("act", "an act service and only one has its act")
	if not KINDS.has(definition.kind):
		reader.fail("kind", "unsupported service kind '%s'" % definition.kind)
	if definition.reach <= 0:
		reader.fail("reach", "must be positive")
	return definition


## Copy placed on the map of its zone.
func with_map(map_id: StringName) -> ServiceDefinition:
	var copy := ServiceDefinition.new(_service_id, _kind, map_id, _zone_id, _display_name, _reach, _legacy_source)
	copy._dance = _dance
	copy._act = _act
	copy._arrival_spawn_id = _arrival_spawn_id
	return copy
