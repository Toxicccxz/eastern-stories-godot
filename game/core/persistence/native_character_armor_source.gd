class_name NativeCharacterArmorSource
extends RefCounted

var _character_id: StringName
var _armor_state: ArmorState

var character_id: StringName:
	get:
		return _character_id
var armor_state: ArmorState:
	get:
		return _armor_state


func _init(
	p_character_id: StringName = &"",
	p_armor_state: ArmorState = null,
) -> void:
	_character_id = p_character_id
	_armor_state = p_armor_state
