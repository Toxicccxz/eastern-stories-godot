class_name GameSaveSnapshot
extends RefCounted

const ValueTypes := preload("res://core/persistence/game_save_value_types.gd")

## Schema 3 (DECISIONS「昼夜」) adds the root's `day_seconds`; schema 4 (DECISIONS「天气」) the
## root's `sky_level` and `sky_minutes_left`; an older file is refused.
const CURRENT_SCHEMA_VERSION: int = 4
const FORMAT_ID: String = "eastern-stories-native-save"
const SESSION_KIND_OLDPINE: StringName = &"oldpine"
## The slots (现代基线 A; DECISIONS「存档位」): three the player saves to, one the autosave rolls.
const MANUAL_SLOT_IDS: Array[StringName] = [&"slot-1", &"slot-2", &"slot-3"]
const AUTO_SLOT_ID: StringName = &"auto"
const DEFAULT_SLOT_ID: StringName = &"slot-1"
## The one fixed slot before them: old files name it, and nothing writes it any more.
const LEGACY_SLOT_ID: StringName = &"default-v1"

var _metadata: ValueTypes.GameSaveMetadata
var _session_kind: StringName
var _world_content_revision: WorldContentRevision.Value
var _item_id_allocator: ValueTypes.ItemIdAllocatorSnapshot
var _player: ValueTypes.PlayerRuntimeSnapshot
var _npc_spawn_states: Array[ValueTypes.NpcSpawnStateSnapshot] = []
var _corpses: Array[ValueTypes.CorpseSnapshot] = []
var _items: NativeItemStateSnapshot
var _combat_rng: RandomStreamSnapshot
var _npc_initialization_rng: RandomStreamSnapshot
var _world_interaction_rng: RandomStreamSnapshot
var _floor_items: Array[ValueTypes.FloorItemSnapshot] = []
## The note each note_maze landmark shows (WorldMapMazes), by landmark ID: an index into its
## notes. Only those drawn are written (默认, 乔阴 C).
var _maze_notes: Dictionary[StringName, int] = {}
## The world time each map but the player's was owed, in ms, by map ID (DECISIONS「别的地图
## 时间补算」). Only maps owed some are written.
var _away_ms: Dictionary[StringName, int] = {}
## The time of day (DayClock, DECISIONS「昼夜」): seconds since 0:00 of the game day.
var _day_seconds: int = DayClock.NEW_GAME_SECONDS
## The cloud (SkyState, DECISIONS「天气」): its level and the game minutes to its next change.
var _sky_level: int = SkyState.NEW_GAME_LEVEL
var _sky_minutes_left: int = SkyState.NEW_GAME_MINUTES
## What the slot list shows (GameSaveSlotSummary): seconds played and the objective at the
## save, in the source language. Written only when there is one.
var _played_seconds: int = 0
var _objective: String = ""
## Something worked out from exactly this content (the runtime's restore preparation after
## a check): kept for one taker, moved to an exact copy, dropped when the content changes.
var _derived: RefCounted

var metadata: ValueTypes.GameSaveMetadata:
	get: return _metadata.duplicate_snapshot()
var session_kind: StringName:
	get: return _session_kind
var world_content_revision: WorldContentRevision.Value:
	get: return _world_content_revision
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
var maze_notes: Dictionary[StringName, int]:
	get:
		return _maze_notes.duplicate()
var away_ms: Dictionary[StringName, int]:
	get:
		return _away_ms.duplicate()
var day_seconds: int:
	get:
		return _day_seconds
var sky_level: int:
	get:
		return _sky_level
var sky_minutes_left: int:
	get:
		return _sky_minutes_left
var played_seconds: int:
	get:
		return _played_seconds
var objective: String:
	get:
		return _objective
## Items lying on the floor away from their spawn markers (dropped).
var floor_items: Array[ValueTypes.FloorItemSnapshot]:
	get:
		var result: Array[ValueTypes.FloorItemSnapshot] = []
		for record: ValueTypes.FloorItemSnapshot in _floor_items:
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
	p_world_content_revision: WorldContentRevision.Value = WorldContentRevision.Value.LEGACY_OLDPINE_V1,
) -> void:
	_metadata = (
		ValueTypes.GameSaveMetadata.new(FORMAT_ID, CURRENT_SCHEMA_VERSION, "", ValueTypes.OptionalText.none(), &"development", DEFAULT_SLOT_ID)
		if p_metadata == null else p_metadata.duplicate_snapshot()
	)
	_session_kind = p_session_kind
	_world_content_revision = p_world_content_revision
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
	var copy: GameSaveSnapshot = GameSaveSnapshot.new(_metadata, _session_kind, _item_id_allocator, _player, _npc_spawn_states, _corpses, _items, _combat_rng, _npc_initialization_rng, _world_interaction_rng, _world_content_revision).with_floor_items(_floor_items).with_maze_notes(_maze_notes).with_away_ms(_away_ms).with_day_seconds(_day_seconds).with_sky(_sky_level, _sky_minutes_left).with_summary(_played_seconds, _objective)
	copy._derived = take_derived()
	return copy


## Whether `slot_id` names a slot of the game's.
static func is_slot_id(slot_id: StringName) -> bool:
	return slot_id == AUTO_SLOT_ID or MANUAL_SLOT_IDS.has(slot_id)


func keep_derived(value: RefCounted) -> void:
	_derived = value


func take_derived() -> RefCounted:
	var value: RefCounted = _derived
	_derived = null
	return value


## The dropped items (ordered by item ID); a save without any has none.
func with_maze_notes(notes: Dictionary[StringName, int]) -> GameSaveSnapshot:
	_derived = null
	_maze_notes = notes.duplicate()
	return self


func with_away_ms(owed: Dictionary[StringName, int]) -> GameSaveSnapshot:
	_derived = null
	_away_ms = owed.duplicate()
	return self


func with_day_seconds(seconds: int) -> GameSaveSnapshot:
	_derived = null
	_day_seconds = seconds
	return self


func with_sky(level: int, minutes_left: int) -> GameSaveSnapshot:
	_derived = null
	_sky_level = level
	_sky_minutes_left = minutes_left
	return self


func with_summary(played_seconds_value: int, objective_text: String) -> GameSaveSnapshot:
	_derived = null
	_played_seconds = played_seconds_value
	_objective = objective_text
	return self


func with_floor_items(records: Array[ValueTypes.FloorItemSnapshot]) -> GameSaveSnapshot:
	_derived = null
	_floor_items.clear()
	for record: ValueTypes.FloorItemSnapshot in records:
		_floor_items.append(null if record == null else record.duplicate_snapshot())
	_floor_items.sort_custom(func(left: ValueTypes.FloorItemSnapshot, right: ValueTypes.FloorItemSnapshot) -> bool:
		if left == null: return right != null
		if right == null: return false
		return String(left.item_instance_id) < String(right.item_instance_id))
	return self


static func _npc_before(left: ValueTypes.NpcSpawnStateSnapshot, right: ValueTypes.NpcSpawnStateSnapshot) -> bool:
	if left == null: return right != null
	if right == null: return false
	# One spawn places several NPCs; sort_custom is not stable, so the point decides ties.
	if left.spawn_id != right.spawn_id:
		return String(left.spawn_id) < String(right.spawn_id)
	return String(left.spawn_point_id) < String(right.spawn_point_id)


static func _corpse_before(left: ValueTypes.CorpseSnapshot, right: ValueTypes.CorpseSnapshot) -> bool:
	if left == null: return right != null
	if right == null: return false
	return String(left.corpse_item_instance_id) < String(right.corpse_item_instance_id)
