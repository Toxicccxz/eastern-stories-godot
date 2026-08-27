class_name CombatCharacterAuthority
extends RefCounted

## Narrow identity association for live combat state supplied by the caller.
## It exposes no generic query/set API and is never retained in result DTOs.
var _character_id: StringName
var _state: CharacterState

var character_id: StringName:
	get:
		return _character_id


func _init(
	p_character_id: StringName = &"",
	p_state: CharacterState = null,
) -> void:
	_character_id = p_character_id
	_state = p_state


func is_valid() -> bool:
	return not _character_id.is_empty() and _state != null


func state() -> CharacterState:
	return _state
