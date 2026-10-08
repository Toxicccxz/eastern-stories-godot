class_name NpcSpawnDefinition
extends RefCounted

const DEFAULT_PRESENCE_RADIUS: int = 120

enum InitialSpawnPolicy {
	INVALID,
	INITIAL_ONLY,
	## Made with the world but absent until a room rule calls them in (keep2.c
	## valid_leave() new()s its guards); a room reset does not remake them.
	SUMMONED,
	## One of a `draw` group (d/temple/road2.c's guards on duty): made with the world
	## but absent; at the world's start and at each reset of its room one spawn of the
	## group is drawn and comes, or is made anew, or is called home. The others stay as
	## they are (an earlier draw stays on duty; a dead one waits until it is drawn).
	DRAWN,
}

var _spawn_id: StringName
var _npc_definition_id: StringName
var _map_id: StringName
var _zone_id: StringName
var _spawn_point_ids: Array[StringName] = []
var _quantity: int
var _legacy_source_room_path: String
var _legacy_quantity: int
var _initial_spawn_policy: int
var _presence_radius: int
var _draw_group: StringName = &""

var spawn_id: StringName:
	get:
		return _spawn_id
var npc_definition_id: StringName:
	get:
		return _npc_definition_id
var map_id: StringName:
	get:
		return _map_id
var zone_id: StringName:
	get:
		return _zone_id
var quantity: int:
	get:
		return _quantity
var legacy_source_room_path: String:
	get:
		return _legacy_source_room_path
var legacy_quantity: int:
	get:
		return _legacy_quantity
var initial_spawn_policy: int:
	get:
		return _initial_spawn_policy
## Pixels around the NPC body in which the player is "in its room" for aggression.
var presence_radius: int:
	get:
		return _presence_radius
var summoned: bool:
	get:
		return _initial_spawn_policy == InitialSpawnPolicy.SUMMONED
## The group a DRAWN spawn is one of; "" for the others.
var draw_group: StringName:
	get:
		return _draw_group
var drawn: bool:
	get:
		return _initial_spawn_policy == InitialSpawnPolicy.DRAWN
## Absent when the world is made (SUMMONED or DRAWN).
var starts_absent: bool:
	get:
		return _initial_spawn_policy != InitialSpawnPolicy.INITIAL_ONLY


func _init(
	p_spawn_id: StringName = &"",
	p_npc_definition_id: StringName = &"",
	p_map_id: StringName = &"",
	p_zone_id: StringName = &"",
	p_spawn_point_ids: Array[StringName] = [],
	p_quantity: int = 0,
	p_legacy_source_room_path: String = "",
	p_legacy_quantity: int = 0,
	p_initial_spawn_policy: int = InitialSpawnPolicy.INVALID,
	p_presence_radius: int = DEFAULT_PRESENCE_RADIUS,
) -> void:
	_spawn_id = p_spawn_id
	_npc_definition_id = p_npc_definition_id
	_map_id = p_map_id
	_zone_id = p_zone_id
	_spawn_point_ids = p_spawn_point_ids.duplicate()
	_quantity = p_quantity
	_legacy_source_room_path = p_legacy_source_room_path
	_legacy_quantity = p_legacy_quantity
	_initial_spawn_policy = p_initial_spawn_policy
	_presence_radius = p_presence_radius


func spawn_point_ids() -> Array[StringName]:
	return _spawn_point_ids.duplicate()


## d/temple/road2.c reset()'s set("objects", ([ ... + (random(3)+1) : 1 ])): one of the
## group's spawns.
func with_draw_group(group: StringName) -> NpcSpawnDefinition:
	_draw_group = group
	if not group.is_empty():
		_initial_spawn_policy = InitialSpawnPolicy.DRAWN
	return self


func is_valid() -> bool:
	if (
		_spawn_id.is_empty()
		or _npc_definition_id.is_empty()
		or _map_id.is_empty()
		or _zone_id.is_empty()
		or _quantity <= 0
		or _legacy_quantity <= 0
		or _quantity != _legacy_quantity
		or _spawn_point_ids.size() != _quantity
		or _legacy_source_room_path.is_empty()
		or _initial_spawn_policy not in [InitialSpawnPolicy.INITIAL_ONLY, InitialSpawnPolicy.SUMMONED, InitialSpawnPolicy.DRAWN]
		or (_initial_spawn_policy == InitialSpawnPolicy.DRAWN) == _draw_group.is_empty()
	):
		return false
	var seen: Dictionary[StringName, bool] = {}
	for spawn_point_id: StringName in _spawn_point_ids:
		if spawn_point_id.is_empty() or seen.has(spawn_point_id):
			return false
		seen[spawn_point_id] = true
	return true
