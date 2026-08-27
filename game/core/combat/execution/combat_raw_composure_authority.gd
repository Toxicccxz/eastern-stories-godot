class_name CombatRawComposureAuthority
extends RefCounted

## Identity-bound live authority for combatd.c's late my["cps"] read.
## The outer execution service validates this authority against the forward
## attacker CharacterState before any B2A RNG or gameplay mutation.
var _character_id: StringName
var _attributes: CharacterBaseAttributes

var character_id: StringName:
	get:
		return _character_id


func _init(
	p_character_id: StringName = &"",
	p_attributes: CharacterBaseAttributes = null,
) -> void:
	_character_id = p_character_id
	_attributes = p_attributes


func is_valid() -> bool:
	return not _character_id.is_empty() and _attributes != null


func is_bound_to(character: CharacterState) -> bool:
	return character != null and _attributes == character.attributes


func current_raw_composure() -> int:
	return _attributes.composure
