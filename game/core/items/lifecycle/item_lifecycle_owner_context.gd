class_name ItemLifecycleOwnerContext
extends RefCounted

const ArmorStateType := preload("res://core/armor/armor_state.gd")
const EquipmentStateType := preload("res://core/equipment/equipment_state.gd")

## Explicit direct-character owner projection. The character ID prevents a
## caller from applying another character's Equipment/Armor authorities.
var _character_id: StringName
var _equipment_state: EquipmentStateType
var _armor_state: ArmorStateType

var character_id: StringName:
	get:
		return _character_id
var equipment_state: EquipmentStateType:
	get:
		return _equipment_state
var armor_state: ArmorStateType:
	get:
		return _armor_state


func _init(
	p_character_id: StringName = &"",
	p_equipment_state: EquipmentStateType = null,
	p_armor_state: ArmorStateType = null,
) -> void:
	_character_id = p_character_id
	_equipment_state = p_equipment_state
	_armor_state = p_armor_state


## A direct-character destruction must receive both current native authorities.
## Null cannot mean "empty" because it could also mean an omitted aggregate.
func is_complete() -> bool:
	return (
		_character_id != &""
		and _equipment_state != null
		and _armor_state != null
	)
