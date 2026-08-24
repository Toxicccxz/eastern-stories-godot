class_name NativeArmorSlotRecord
extends RefCounted

var _armor_type: StringName
var _item_instance_id: StringName

var armor_type: StringName:
	get:
		return _armor_type
var item_instance_id: StringName:
	get:
		return _item_instance_id


func _init(
	p_armor_type: StringName = &"",
	p_item_instance_id: StringName = &"",
) -> void:
	_armor_type = p_armor_type
	_item_instance_id = p_item_instance_id


func duplicate_snapshot() -> NativeArmorSlotRecord:
	return NativeArmorSlotRecord.new(_armor_type, _item_instance_id)
