class_name MapCharacterRuntimeState
extends RefCounted

const NpcRuntimeStateType := preload("res://core/npcs/npc_runtime_state.gd")

## Map-local runtime membership for the first authored NPC use case. A world
## player binding is deliberately not invented until Phase 7B2 supplies its
## second concrete runtime shape.
var _map_id: StringName
var _ordered_character_ids: Array[StringName] = []
var _npcs_by_character_id: Dictionary[StringName, NpcRuntimeState] = {}

var map_id: StringName:
	get:
		return _map_id


func _init(p_map_id: StringName = &"") -> void:
	_map_id = p_map_id


func register_npc(runtime: NpcRuntimeStateType) -> bool:
	if (
		runtime == null
		or not runtime.is_valid()
		or runtime.world_location().map_id != _map_id
		or _npcs_by_character_id.has(runtime.character_id)
	):
		return false
	_npcs_by_character_id[runtime.character_id] = runtime
	_ordered_character_ids.append(runtime.character_id)
	runtime.set_exists_in_map(true)
	return true


func has_character(character_id: StringName) -> bool:
	return _npcs_by_character_id.has(character_id)


func find_npc(character_id: StringName) -> NpcRuntimeStateType:
	return _npcs_by_character_id.get(character_id)


func ordered_active_characters() -> Array[NpcRuntimeState]:
	var result: Array[NpcRuntimeState] = []
	for character_id: StringName in _ordered_character_ids:
		var runtime: NpcRuntimeStateType = _npcs_by_character_id.get(character_id)
		if runtime != null and runtime.exists_in_map:
			result.append(runtime)
	return result


func ordered_character_ids() -> Array[StringName]:
	return _ordered_character_ids.duplicate()


func remove_character(character_id: StringName) -> bool:
	var runtime: NpcRuntimeStateType = _npcs_by_character_id.get(character_id)
	if runtime == null:
		return false
	runtime.set_exists_in_map(false)
	_npcs_by_character_id.erase(character_id)
	_ordered_character_ids.erase(character_id)
	return true


func size() -> int:
	return _npcs_by_character_id.size()
