class_name CombatSliceCharacterBinding
extends RefCounted

var _character_id: StringName
var _state: CharacterState
var _relationship: CombatRelationshipState
var _busy: ActionBusyState
var _armor: ArmorState
var _content: CombatSliceContentProfile
var _location_id: StringName
var _exists_in_encounter: bool
var _life_status: int
var _is_user: bool
var _combat_available: bool

var character_id: StringName:
	get:
		return _character_id
var state: CharacterState:
	get:
		return _state
var relationship: CombatRelationshipState:
	get:
		return _relationship
var busy: ActionBusyState:
	get:
		return _busy
var armor: ArmorState:
	get:
		return _armor
var content: CombatSliceContentProfile:
	get:
		return _content
var location_id: StringName:
	get:
		return _location_id
var exists_in_encounter: bool:
	get:
		return _exists_in_encounter
var life_status: int:
	get:
		return _life_status
var is_user: bool:
	get:
		return _is_user
var combat_available: bool:
	get:
		return _combat_available


func _init(
	p_character_id: StringName = &"",
	p_state: CharacterState = null,
	p_relationship: CombatRelationshipState = null,
	p_busy: ActionBusyState = null,
	p_armor: ArmorState = null,
	p_content: CombatSliceContentProfile = null,
	p_location_id: StringName = &"",
	p_exists_in_encounter: bool = true,
	p_life_status: int = CombatSliceLifeStatus.Value.ACTIVE,
	p_is_user: bool = false,
	p_combat_available: bool = true,
) -> void:
	_character_id = p_character_id
	_state = p_state
	_relationship = p_relationship
	_busy = p_busy
	_armor = p_armor
	_content = p_content
	_location_id = p_location_id
	_exists_in_encounter = p_exists_in_encounter
	_life_status = p_life_status
	_is_user = p_is_user
	_combat_available = p_combat_available


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and _state != null
		and _relationship != null
		and _relationship.is_valid()
		and _relationship.owner_character_id == _character_id
		and _busy != null
		and _armor != null
		and _content != null
		and _content.is_valid()
		and not _location_id.is_empty()
		and CombatSliceLifeStatus.is_valid(_life_status)
	)


func set_location_id(value: StringName) -> bool:
	if value.is_empty():
		return false
	_location_id = value
	return true


func set_exists_in_encounter(value: bool) -> void:
	_exists_in_encounter = value


func set_life_status(value: int) -> bool:
	if not CombatSliceLifeStatus.is_valid(value):
		return false
	_life_status = value
	return true


func set_combat_available(value: bool) -> void:
	_combat_available = value
