class_name PlayerInventoryRowProjection
extends RefCounted

enum EquipmentSlot {
	NONE,
	PRIMARY,
	SECONDARY,
	WORN,
}

var _item_instance_id: StringName
var _item_definition_id: StringName
var _display_name: String
var _description: String
var _amount: int
var _category: StringName
var _equipment_slot: int
var _weapon_skill_type: StringName
var _weapon_damage: int
var _total_value: int
var _can_wield: bool
var _can_unwield: bool
var _armor_type: StringName
var _armor_modifiers: ArmorNumericModifiers
var _can_wear: bool
var _can_remove: bool

var item_instance_id: StringName:
	get: return _item_instance_id
var item_definition_id: StringName:
	get: return _item_definition_id
var display_name: String:
	get: return _display_name
var description: String:
	get: return _description
var amount: int:
	get: return _amount
var category: StringName:
	get: return _category
var equipment_slot: int:
	get: return _equipment_slot
var weapon_skill_type: StringName:
	get: return _weapon_skill_type
var weapon_damage: int:
	get: return _weapon_damage
var total_value: int:
	get: return _total_value
var can_wield: bool:
	get: return _can_wield
var can_unwield: bool:
	get: return _can_unwield
var armor_type: StringName:
	get: return _armor_type
var armor_modifiers: ArmorNumericModifiers:
	get: return _armor_modifiers.duplicate_snapshot()
var can_wear: bool:
	get: return _can_wear
var can_remove: bool:
	get: return _can_remove


func _init(
	p_item_instance_id: StringName = &"",
	p_item_definition_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_amount: int = 1,
	p_category: StringName = &"",
	p_equipment_slot: int = EquipmentSlot.NONE,
	p_weapon_skill_type: StringName = &"",
	p_weapon_damage: int = 0,
	p_total_value: int = 0,
	p_can_wield: bool = false,
	p_can_unwield: bool = false,
	p_armor_type: StringName = &"",
	p_armor_modifiers: ArmorNumericModifiers = null,
	p_can_wear: bool = false,
	p_can_remove: bool = false,
) -> void:
	_item_instance_id = p_item_instance_id
	_item_definition_id = p_item_definition_id
	_display_name = p_display_name
	_description = p_description
	_amount = p_amount
	_category = p_category
	_equipment_slot = p_equipment_slot
	_weapon_skill_type = p_weapon_skill_type
	_weapon_damage = p_weapon_damage
	_total_value = p_total_value
	_can_wield = p_can_wield
	_can_unwield = p_can_unwield
	_armor_type = p_armor_type
	_armor_modifiers = (
		ArmorNumericModifiers.new()
		if p_armor_modifiers == null
		else p_armor_modifiers.duplicate_snapshot()
	)
	_can_wear = p_can_wear
	_can_remove = p_can_remove


func duplicate_snapshot() -> PlayerInventoryRowProjection:
	return PlayerInventoryRowProjection.new(
		_item_instance_id,
		_item_definition_id,
		_display_name,
		_description,
		_amount,
		_category,
		_equipment_slot,
		_weapon_skill_type,
		_weapon_damage,
		_total_value,
		_can_wield,
		_can_unwield,
		_armor_type,
		_armor_modifiers,
		_can_wear,
		_can_remove,
	)


func equipment_label() -> String:
	match _equipment_slot:
		EquipmentSlot.PRIMARY:
			return "PRIMARY"
		EquipmentSlot.SECONDARY:
			return "SECONDARY"
		EquipmentSlot.WORN:
			return "WORN"
	return "NONE"
