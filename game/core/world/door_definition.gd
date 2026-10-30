class_name DoorDefinition
extends RefCounted

## An ES2 `create_door()` pair between two zones: of one map, or of two maps a portal
## joins (a building's door onto its street: both maps place a WorldDoor of this ID over
## the passage, and opening or shutting one opens or shuts the other). It starts closed
## (`open`: open). Door state is not saved. A door the player cannot `operable` is one a
## room rule opens and shuts (an exit keep2.c deletes and sets again).
var _door_id: StringName
var _map_id: StringName
var _map_ids: Array[StringName] = []
var _display_name: String
var _zone_ids: Array[StringName] = []
var _reach: int
var _closable: bool
var _starts_open: bool = false
var _operable: bool = true
## The saved mark (CharacterState.marks) that finds this way: a door nobody can work by hand
## that stands shut until a `find_way` landmark gives the mark, and open ever after
## (DECISIONS「老松林的林径与藏起来的寨门」); "" for an ordinary door.
var _found_by: String = ""
## The item (by definition id) one must carry to open it: a locked cell's iron door
## (DECISIONS「逆灵宫 B」). Opened, it stays open (`closable` false); "" for an ordinary door.
var _key: StringName = &""
## What the player reads trying the door without the key ("" for the default line).
var _locked_line: String = ""
var _legacy_room_id: StringName

var door_id: StringName:
	get:
		return _door_id
## The map of its first zone (where a trap that shuts it stands).
var map_id: StringName:
	get:
		return _map_id
var display_name: String:
	get:
		return _display_name
## Pixels from the door within which the player can operate it.
var reach: int:
	get:
		return _reach
## False for a door the player may only open (an approved adaptation).
var closable: bool:
	get:
		return _closable
var legacy_room_id: StringName:
	get:
		return _legacy_room_id
var starts_open: bool:
	get:
		return _starts_open
var operable: bool:
	get:
		return _operable
var found_by: String:
	get:
		return _found_by
var key: StringName:
	get:
		return _key
var locked_line: String:
	get:
		return _locked_line


func _init(
	p_door_id: StringName = &"",
	p_map_id: StringName = &"",
	p_display_name: String = "",
	p_zone_ids: Array[StringName] = [],
	p_reach: int = 0,
	p_closable: bool = true,
	p_legacy_room_id: StringName = &"",
) -> void:
	_door_id = p_door_id
	_map_id = p_map_id
	_display_name = p_display_name
	_zone_ids = p_zone_ids.duplicate()
	_reach = p_reach
	_closable = p_closable
	_legacy_room_id = p_legacy_room_id


static func from_record(reader: ContentRecordReader) -> DoorDefinition:
	var zones: Array[StringName] = []
	for zone_id: String in reader.text_list("zones"):
		zones.append(StringName(zone_id))
	var definition: DoorDefinition = DoorDefinition.new(
		StringName(reader.required_text("id")),
		&"",
		reader.required_text("name"),
		zones,
		reader.required_integer("reach"),
		reader.boolean("closable", true),
		StringName(reader.required_text("legacy_room")),
	)
	definition._starts_open = reader.boolean("open", false)
	definition._operable = reader.boolean("operable", true)
	definition._found_by = reader.text("found_by")
	definition._key = StringName(reader.text("key"))
	definition._locked_line = reader.text("locked")
	reader.finish()
	if zones.size() != 2:
		reader.fail("zones", "a door joins exactly two zones")
	if definition.reach <= 0:
		reader.fail("reach", "must be positive")
	if not definition._found_by.is_empty() and (definition._starts_open or definition._operable):
		reader.fail("found_by", "a way found by a mark starts shut and is worked by no hand")
	if not definition._key.is_empty() and (not definition._found_by.is_empty() or definition._starts_open or not definition._operable or definition._closable):
		reader.fail("key", "a locked door starts shut, is opened by hand with its key and stays open (closable false)")
	if not definition._locked_line.is_empty() and definition._key.is_empty():
		reader.fail("locked", "only a door with a key has a locked line")
	return definition


## Zones from which the door can be operated (its two sides).
func zone_ids() -> Array[StringName]:
	return _zone_ids.duplicate()


## The maps that place it: one, or the two its portal joins.
func map_ids() -> Array[StringName]:
	return _map_ids.duplicate()


func with_map(map_id: StringName) -> DoorDefinition:
	return with_maps([map_id])


func with_maps(map_ids: Array[StringName]) -> DoorDefinition:
	var copy: DoorDefinition = DoorDefinition.new(_door_id, map_ids[0], _display_name, _zone_ids, _reach, _closable, _legacy_room_id)
	copy._map_ids = map_ids.duplicate()
	copy._starts_open = _starts_open
	copy._operable = _operable
	copy._found_by = _found_by
	copy._key = _key
	copy._locked_line = _locked_line
	return copy
