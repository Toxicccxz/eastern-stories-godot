class_name OldPineItemContentDefinition
extends RefCounted

var _item_definition_id: StringName
var _display_name: String
var _description: String
var _category: StringName
var _own_weight: int
var _weapon_skill_type: StringName
var _weapon_damage: int
var _can_wield_secondary: bool
var _is_two_handed: bool
var _is_stack: bool
var _stack_base_weight: int
var _currency_base_value: int
var _legacy_source_paths: Array[String] = []

var item_definition_id: StringName:
	get: return _item_definition_id
var display_name: String:
	get: return _display_name
var description: String:
	get: return _description
var category: StringName:
	get: return _category
var own_weight: int:
	get: return _own_weight
var weapon_skill_type: StringName:
	get: return _weapon_skill_type
var weapon_damage: int:
	get: return _weapon_damage
var can_wield_secondary: bool:
	get: return _can_wield_secondary
var is_two_handed: bool:
	get: return _is_two_handed
var is_stack: bool:
	get: return _is_stack
var stack_base_weight: int:
	get: return _stack_base_weight
var currency_base_value: int:
	get: return _currency_base_value


func _init(
	p_item_definition_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_category: StringName = &"",
	p_own_weight: int = 0,
	p_weapon_skill_type: StringName = &"",
	p_weapon_damage: int = 0,
	p_can_wield_secondary: bool = false,
	p_is_two_handed: bool = false,
	p_is_stack: bool = false,
	p_stack_base_weight: int = 0,
	p_currency_base_value: int = 0,
	p_legacy_source_paths: Array[String] = [],
) -> void:
	_item_definition_id = p_item_definition_id
	_display_name = p_display_name
	_description = p_description
	_category = p_category
	_own_weight = p_own_weight
	_weapon_skill_type = p_weapon_skill_type
	_weapon_damage = p_weapon_damage
	_can_wield_secondary = p_can_wield_secondary
	_is_two_handed = p_is_two_handed
	_is_stack = p_is_stack
	_stack_base_weight = p_stack_base_weight
	_currency_base_value = p_currency_base_value
	_legacy_source_paths = p_legacy_source_paths.duplicate()


func legacy_source_paths() -> Array[String]:
	return _legacy_source_paths.duplicate()


func is_valid() -> bool:
	return (
		not _item_definition_id.is_empty()
		and not _display_name.is_empty()
		and not _description.is_empty()
		and not _category.is_empty()
		and not _legacy_source_paths.is_empty()
	)
