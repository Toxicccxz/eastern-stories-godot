class_name NpcRandomMove
extends RefCounted

## std/char/npc.c random_move(): `go` through a random exit of the NPC's room
## (cmds/std/go.c). The exit is drawn as `dirs[random(sizeof(dirs))]`; the move
## happens only when go would succeed here and the place is within the NPC's
## range, else nothing does, as a failed go. Range (owner, DECISIONS 4D): the
## NPC's home zone and its neighbours on the same map. A zone of several rooms
## uses its primary room's exits.

## go.c default_dirs.
const DIRECTION_NAMES: Dictionary[String, String] = {
	"north": "北", "south": "南", "east": "东", "west": "西",
	"northup": "北边", "southup": "南边", "eastup": "东边", "westup": "西边",
	"northdown": "北边", "southdown": "南边", "eastdown": "东边", "westdown": "西边",
	"northeast": "东北", "northwest": "西北", "southeast": "东南", "southwest": "西南",
	"up": "上", "down": "下", "out": "外", "enter": "里",
}


class Move:
	extends RefCounted
	var direction: String
	var to_zone_id: StringName

	func _init(p_direction: String = "", p_to_zone_id: StringName = &"") -> void:
		direction = p_direction
		to_zone_id = p_to_zone_id

	## go.c: `<name>往<dir>离开。` (its 走了过来。 is seen where it arrives, which the
	## player, who must share the NPC's place for it to move, never is.)
	func leave_line(name: String) -> String:
		return "%s往%s离开。" % [name, DIRECTION_NAMES.get(direction, direction)]


## The move one random_move() makes, or null. `door_closed(from, to)` answers
## room.c valid_leave() for a door between the two zones.
static func choose(
	catalog: ContentCatalog,
	zone_id: StringName,
	home_zone_id: StringName,
	random: WorldInteractionRandomSource,
	door_closed: Callable,
) -> Move:
	var zone: ZoneDefinition = null if catalog == null else catalog.zone(zone_id)
	if zone == null or zone.room_ids().is_empty() or random == null:
		return null
	var exits: Dictionary[String, StringName] = catalog.room(zone.room_ids()[0]).exits()
	if exits.is_empty():
		return null
	var directions: Array[String] = []
	directions.assign(exits.keys())
	var drawn: int = random.legacy_random(directions.size())
	if drawn < 0 or drawn >= directions.size():
		return null
	var direction: String = directions[drawn]
	var to_zone: ZoneDefinition = catalog.zone_of_room(exits[direction])
	if to_zone == null or to_zone.map_id != zone.map_id or to_zone.zone_id == zone_id:
		return null
	if to_zone.zone_id != home_zone_id and not catalog.zones_adjacent(home_zone_id, to_zone.zone_id):
		return null
	if door_closed.is_valid() and door_closed.call(zone_id, to_zone.zone_id):
		return null
	return Move.new(direction, to_zone.zone_id)
