class_name GameSaveSnapshot
extends RefCounted

const ValueTypes := preload("res://core/persistence/game_save_value_types.gd")

const CURRENT_SCHEMA_VERSION: int = 1
const FORMAT_ID: String = "eastern-stories-native-save"
const SESSION_KIND_OLDPINE: StringName = &"oldpine"
const FIXED_SLOT_ID: StringName = &"default-v1"

var _metadata: ValueTypes.GameSaveMetadata
var _session_kind: StringName
var _item_id_allocator: ValueTypes.ItemIdAllocatorSnapshot
var _player: ValueTypes.PlayerRuntimeSnapshot
var _npc_spawn_states: Array[ValueTypes.NpcSpawnStateSnapshot] = []
var _corpses: Array[ValueTypes.CorpseSnapshot] = []
var _items: NativeItemStateSnapshot
var _combat_rng: RandomStreamSnapshot
var _npc_initialization_rng: RandomStreamSnapshot
var _world_interaction_rng: RandomStreamSnapshot

var metadata: ValueTypes.GameSaveMetadata:
	get: return _metadata.duplicate_snapshot()
var session_kind: StringName:
	get: return _session_kind
var item_id_allocator: ValueTypes.ItemIdAllocatorSnapshot:
	get: return _item_id_allocator.duplicate_snapshot()
var player: ValueTypes.PlayerRuntimeSnapshot:
	get: return _player.duplicate_snapshot()
var items: NativeItemStateSnapshot:
	get: return _items.duplicate_snapshot()
var combat_rng: RandomStreamSnapshot:
	get: return _combat_rng.duplicate_snapshot()
var npc_initialization_rng: RandomStreamSnapshot:
	get: return _npc_initialization_rng.duplicate_snapshot()
var world_interaction_rng: RandomStreamSnapshot:
	get: return _world_interaction_rng.duplicate_snapshot()

var npc_spawn_states: Array[ValueTypes.NpcSpawnStateSnapshot]:
	get:
		var result: Array[ValueTypes.NpcSpawnStateSnapshot] = []
		for record: ValueTypes.NpcSpawnStateSnapshot in _npc_spawn_states:
			result.append(null if record == null else record.duplicate_snapshot())
		return result
var corpses: Array[ValueTypes.CorpseSnapshot]:
	get:
		var result: Array[ValueTypes.CorpseSnapshot] = []
		for record: ValueTypes.CorpseSnapshot in _corpses:
			result.append(null if record == null else record.duplicate_snapshot())
		return result


func _init(
	p_metadata: ValueTypes.GameSaveMetadata = null,
	p_session_kind: StringName = SESSION_KIND_OLDPINE,
	p_item_id_allocator: ValueTypes.ItemIdAllocatorSnapshot = null,
	p_player: ValueTypes.PlayerRuntimeSnapshot = null,
	p_npc_spawn_states: Array[ValueTypes.NpcSpawnStateSnapshot] = [],
	p_corpses: Array[ValueTypes.CorpseSnapshot] = [],
	p_items: NativeItemStateSnapshot = null,
	p_combat_rng: RandomStreamSnapshot = null,
	p_npc_initialization_rng: RandomStreamSnapshot = null,
	p_world_interaction_rng: RandomStreamSnapshot = null,
) -> void:
	_metadata = (
		ValueTypes.GameSaveMetadata.new(FORMAT_ID, CURRENT_SCHEMA_VERSION, "", ValueTypes.OptionalText.none(), &"development", FIXED_SLOT_ID)
		if p_metadata == null else p_metadata.duplicate_snapshot()
	)
	_session_kind = p_session_kind
	_item_id_allocator = ValueTypes.ItemIdAllocatorSnapshot.new() if p_item_id_allocator == null else p_item_id_allocator.duplicate_snapshot()
	_player = ValueTypes.PlayerRuntimeSnapshot.new() if p_player == null else p_player.duplicate_snapshot()
	for record: ValueTypes.NpcSpawnStateSnapshot in p_npc_spawn_states:
		_npc_spawn_states.append(null if record == null else record.duplicate_snapshot())
	for record: ValueTypes.CorpseSnapshot in p_corpses:
		_corpses.append(null if record == null else record.duplicate_snapshot())
	_npc_spawn_states.sort_custom(_npc_before)
	_corpses.sort_custom(_corpse_before)
	_items = NativeItemStateSnapshot.new() if p_items == null else p_items.duplicate_snapshot()
	_combat_rng = RandomStreamSnapshot.new() if p_combat_rng == null else p_combat_rng.duplicate_snapshot()
	_npc_initialization_rng = RandomStreamSnapshot.new() if p_npc_initialization_rng == null else p_npc_initialization_rng.duplicate_snapshot()
	_world_interaction_rng = RandomStreamSnapshot.new() if p_world_interaction_rng == null else p_world_interaction_rng.duplicate_snapshot()


func duplicate_snapshot() -> GameSaveSnapshot:
	return GameSaveSnapshot.new(_metadata, _session_kind, _item_id_allocator, _player, _npc_spawn_states, _corpses, _items, _combat_rng, _npc_initialization_rng, _world_interaction_rng)


static func _npc_before(left: ValueTypes.NpcSpawnStateSnapshot, right: ValueTypes.NpcSpawnStateSnapshot) -> bool:
	if left == null: return right != null
	if right == null: return false
	return String(left.spawn_id) < String(right.spawn_id)


static func _corpse_before(left: ValueTypes.CorpseSnapshot, right: ValueTypes.CorpseSnapshot) -> bool:
	if left == null: return right != null
	if right == null: return false
	return String(left.corpse_item_instance_id) < String(right.corpse_item_instance_id)
