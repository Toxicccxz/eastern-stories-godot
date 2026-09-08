class_name CombatEncounterAuthorityBinding
extends RefCounted

## Encounter-neutral references to the exact current combat authorities.
## CharacterState already composes skills and EquipmentState; CXR2 therefore
## does not duplicate those references or add an unrelated InventoryState.
var _participant_id: StringName
var _state: CharacterState
var _relationship: CombatRelationshipState
var _busy: ActionBusyState
var _armor: ArmorState

var participant_id: StringName:
	get:
		return _participant_id
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


func _init(
	p_participant_id: StringName = &"",
	p_state: CharacterState = null,
	p_relationship: CombatRelationshipState = null,
	p_busy: ActionBusyState = null,
	p_armor: ArmorState = null,
) -> void:
	_participant_id = p_participant_id
	_state = p_state
	_relationship = p_relationship
	_busy = p_busy
	_armor = p_armor


func is_valid() -> bool:
	return (
		not _participant_id.is_empty()
		and _state != null
		and _state.skills != null
		and _state.equipment != null
		and _relationship != null
		and _relationship.is_valid()
		and _relationship.owner_character_id == _participant_id
		and _busy != null
		and _armor != null
	)


## The wrapper is copied while every supplied authority reference remains exact.
func duplicate_reference() -> CombatEncounterAuthorityBinding:
	return CombatEncounterAuthorityBinding.new(
		_participant_id,
		_state,
		_relationship,
		_busy,
		_armor,
	)
