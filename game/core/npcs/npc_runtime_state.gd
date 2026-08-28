class_name NpcRuntimeState
extends RefCounted

const NpcDefinitionType := preload("res://core/npcs/npc_definition.gd")
const CharacterStateType := preload("res://core/characters/character_state.gd")
const RuntimeLifeStatusType := preload(
	"res://runtime/characters/character_runtime_life_status.gd"
)
const RelationshipStateType := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const BusyStateType := preload("res://core/combat/busy/action_busy_state.gd")
const ArmorStateType := preload("res://core/armor/armor_state.gd")
const WorldLocationStateType := preload("res://core/world/world_location_state.gd")
const ItemInstanceType := preload("res://core/items/item_instance.gd")

var _character_id: StringName
var _definition: NpcDefinitionType
var _spawn_id: StringName
var _spawn_point_id: StringName
var _character_state: CharacterStateType
var _relationship: RelationshipStateType
var _busy: BusyStateType
var _armor: ArmorStateType
var _world_location: WorldLocationStateType
var _life_status: int
var _combat_available: bool
var _exists_in_map: bool
var _age: int
var _body_weight: int
var _maximum_encumbrance: int
var _loadout_items: Array[ItemInstance] = []

var character_id: StringName:
	get:
		return _character_id
var definition_id: StringName:
	get:
		return &"" if _definition == null else _definition.definition_id
var spawn_id: StringName:
	get:
		return _spawn_id
var spawn_point_id: StringName:
	get:
		return _spawn_point_id
var character_state: CharacterStateType:
	get:
		return _character_state
var relationship: RelationshipStateType:
	get:
		return _relationship
var busy: BusyStateType:
	get:
		return _busy
var armor: ArmorStateType:
	get:
		return _armor
var life_status: int:
	get:
		return _life_status
var combat_available: bool:
	get:
		return _combat_available
var exists_in_map: bool:
	get:
		return _exists_in_map
var age: int:
	get:
		return _age
var body_weight: int:
	get:
		return _body_weight
var maximum_encumbrance: int:
	get:
		return _maximum_encumbrance


func _init(
	p_character_id: StringName = &"",
	p_definition: NpcDefinitionType = null,
	p_spawn_id: StringName = &"",
	p_spawn_point_id: StringName = &"",
	p_character_state: CharacterStateType = null,
	p_relationship: RelationshipStateType = null,
	p_busy: BusyStateType = null,
	p_armor: ArmorStateType = null,
	p_world_location: WorldLocationStateType = null,
	p_life_status: int = RuntimeLifeStatusType.Value.ACTIVE,
	p_combat_available: bool = true,
	p_exists_in_map: bool = true,
	p_age: int = 0,
	p_body_weight: int = 0,
	p_maximum_encumbrance: int = 0,
	p_loadout_items: Array[ItemInstance] = [],
) -> void:
	_character_id = p_character_id
	_definition = p_definition
	_spawn_id = p_spawn_id
	_spawn_point_id = p_spawn_point_id
	_character_state = p_character_state
	_relationship = p_relationship
	_busy = p_busy
	_armor = p_armor
	_world_location = (
		null if p_world_location == null else p_world_location.duplicate_snapshot()
	)
	_life_status = p_life_status
	_combat_available = p_combat_available
	_exists_in_map = p_exists_in_map
	_age = p_age
	_body_weight = p_body_weight
	_maximum_encumbrance = p_maximum_encumbrance
	for item: ItemInstanceType in p_loadout_items:
		if item != null:
			_loadout_items.append(
				ItemInstanceType.new(item.item_instance_id, item.item_definition_id)
			)


func definition() -> NpcDefinitionType:
	return _definition


func world_location() -> WorldLocationStateType:
	return null if _world_location == null else _world_location.duplicate_snapshot()


func set_world_location(value: WorldLocationStateType) -> bool:
	if value == null or not value.is_valid():
		return false
	_world_location = value.duplicate_snapshot()
	return true


func loadout_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstanceType in _loadout_items:
		result.append(ItemInstanceType.new(item.item_instance_id, item.item_definition_id))
	return result


func set_life_status(value: int) -> bool:
	if not RuntimeLifeStatusType.is_valid(value):
		return false
	_life_status = value
	return true


func set_combat_available(value: bool) -> void:
	_combat_available = value


func set_exists_in_map(value: bool) -> void:
	_exists_in_map = value


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and _definition != null
		and _definition.is_valid()
		and not _spawn_id.is_empty()
		and not _spawn_point_id.is_empty()
		and _character_state != null
		and _relationship != null
		and _relationship.is_valid()
		and _relationship.owner_character_id == _character_id
		and _busy != null
		and _armor != null
		and _world_location != null
		and _world_location.is_valid()
		and RuntimeLifeStatusType.is_valid(_life_status)
	)
