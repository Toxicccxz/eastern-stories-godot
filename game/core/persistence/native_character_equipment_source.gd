class_name NativeCharacterEquipmentSource
extends RefCounted

var _character_id: StringName
var _equipment_state: EquipmentState

var character_id: StringName:
	get:
		return _character_id
var equipment_state: EquipmentState:
	get:
		return _equipment_state


func _init(
	p_character_id: StringName = &"",
	p_equipment_state: EquipmentState = null,
) -> void:
	_character_id = p_character_id
	_equipment_state = p_equipment_state
