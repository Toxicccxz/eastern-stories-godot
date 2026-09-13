class_name NativeFoodConsumableRecord
extends RefCounted

var item_instance_id: StringName
var remaining_portions: int
var current_value: int


func _init(id: StringName, portions: int, value: int) -> void:
	item_instance_id = id
	remaining_portions = portions
	current_value = value


func duplicate_snapshot() -> NativeFoodConsumableRecord:
	return NativeFoodConsumableRecord.new(item_instance_id, remaining_portions, current_value)
