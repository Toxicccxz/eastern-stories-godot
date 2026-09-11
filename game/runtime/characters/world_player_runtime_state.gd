class_name WorldPlayerRuntimeState
extends RefCounted

var _character_id: StringName
var _state: CharacterState
var _relationship: CombatRelationshipState
var _busy: ActionBusyState
var _armor: ArmorState
var _world_location: WorldLocationState
var _life_status: int
var _exists_in_world: bool
var _combat_available: bool
var _maximum_encumbrance: int
var _facts: PlayerIdentityFacts

var facts: PlayerIdentityFacts:
	get: return _facts

var character_id: StringName:
	get: return _character_id
var state: CharacterState:
	get: return _state
var relationship: CombatRelationshipState:
	get: return _relationship
var busy: ActionBusyState:
	get: return _busy
var armor: ArmorState:
	get: return _armor
var life_status: int:
	get: return _life_status
var exists_in_world: bool:
	get: return _exists_in_world
var combat_available: bool:
	get: return _combat_available
var maximum_encumbrance: int:
	get: return _maximum_encumbrance


func _init(
	p_character_id: StringName = &"",
	p_state: CharacterState = null,
	p_relationship: CombatRelationshipState = null,
	p_busy: ActionBusyState = null,
	p_armor: ArmorState = null,
	p_world_location: WorldLocationState = null,
	p_life_status: int = CharacterRuntimeLifeStatus.Value.ACTIVE,
	p_exists_in_world: bool = true,
	p_combat_available: bool = true,
	p_maximum_encumbrance: int = 0,
	p_facts: PlayerIdentityFacts = null,
) -> void:
	_character_id = p_character_id
	_state = p_state
	_relationship = p_relationship
	_busy = p_busy
	_armor = p_armor
	_world_location = (
		null if p_world_location == null else p_world_location.duplicate_snapshot()
	)
	_life_status = p_life_status
	_exists_in_world = p_exists_in_world
	_combat_available = p_combat_available
	_maximum_encumbrance = p_maximum_encumbrance
	_facts = PlayerIdentityFacts.legacy_technical() if p_facts == null else p_facts


## The production Player death projection; source fixtures use this same path.
func death_context(destination: InventoryTransferDestination, has_killer: bool) -> DeathContext:
	return DeathContext.new(
		_character_id, false, false, destination,
		ItemLifecycleOwnerContext.new(_character_id, _state.equipment, _armor),
		_facts.display_name, _state.gender, _facts.age,
		CharacterDerivedValues.human_weight(_state.attributes.strength),
		CharacterDerivedValues.maximum_encumbrance(_state.attributes.strength),
		false, destination.endpoint if has_killer else null, _state.gender, has_killer,
	)


func world_location() -> WorldLocationState:
	return null if _world_location == null else _world_location.duplicate_snapshot()


func set_world_location(value: WorldLocationState) -> bool:
	if value == null or not value.is_valid():
		return false
	_world_location = value.duplicate_snapshot()
	return true


func set_life_status(value: int) -> bool:
	if not CharacterRuntimeLifeStatus.is_valid(value):
		return false
	_life_status = value
	return true


func set_exists_in_world(value: bool) -> void:
	_exists_in_world = value


func set_combat_available(value: bool) -> void:
	_combat_available = value


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and _state != null
		and _relationship != null
		and _relationship.is_valid()
		and _relationship.owner_character_id == _character_id
		and _busy != null
		and _armor != null
		and _facts != null and _facts.is_valid()
		and _world_location != null
		and _world_location.is_valid()
		and CharacterRuntimeLifeStatus.is_valid(_life_status)
	)
