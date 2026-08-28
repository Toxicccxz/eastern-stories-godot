class_name NpcLoadoutEntry
extends RefCounted

enum EquipmentIntent {
	NONE,
	WIELD_PRIMARY,
	WEAR,
}

var _item_definition_id: StringName
var _quantity: int
var _equipment_intent: int
var _legacy_source_path: String

var item_definition_id: StringName:
	get:
		return _item_definition_id
var quantity: int:
	get:
		return _quantity
var equipment_intent: int:
	get:
		return _equipment_intent
var legacy_source_path: String:
	get:
		return _legacy_source_path


func _init(
	p_item_definition_id: StringName = &"",
	p_quantity: int = 0,
	p_equipment_intent: int = EquipmentIntent.NONE,
	p_legacy_source_path: String = "",
) -> void:
	_item_definition_id = p_item_definition_id
	_quantity = p_quantity
	_equipment_intent = p_equipment_intent
	_legacy_source_path = p_legacy_source_path


func is_valid() -> bool:
	return (
		not _item_definition_id.is_empty()
		and _quantity > 0
		and _equipment_intent >= EquipmentIntent.NONE
		and _equipment_intent <= EquipmentIntent.WEAR
		and not _legacy_source_path.is_empty()
	)


func duplicate_snapshot() -> NpcLoadoutEntry:
	return NpcLoadoutEntry.new(
		_item_definition_id,
		_quantity,
		_equipment_intent,
		_legacy_source_path,
	)
