class_name NpcSpawnDefinition
extends RefCounted

enum InitialSpawnPolicy {
	INVALID,
	INITIAL_ONLY,
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


func spawn_point_ids() -> Array[StringName]:
	return _spawn_point_ids.duplicate()


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
		or _initial_spawn_policy != InitialSpawnPolicy.INITIAL_ONLY
	):
		return false
	var seen: Dictionary[StringName, bool] = {}
	for spawn_point_id: StringName in _spawn_point_ids:
		if spawn_point_id.is_empty() or seen.has(spawn_point_id):
			return false
		seen[spawn_point_id] = true
	return true
