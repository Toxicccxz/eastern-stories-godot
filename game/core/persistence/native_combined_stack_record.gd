class_name NativeCombinedStackRecord
extends RefCounted

var _item_instance_id: StringName
var _amount: int

var item_instance_id: StringName:
	get:
		return _item_instance_id
var amount: int:
	get:
		return _amount


func _init(
	p_item_instance_id: StringName = &"",
	p_amount: int = 0,
) -> void:
	_item_instance_id = p_item_instance_id
	_amount = p_amount


func duplicate_snapshot() -> NativeCombinedStackRecord:
	return NativeCombinedStackRecord.new(_item_instance_id, _amount)
