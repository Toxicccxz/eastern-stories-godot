class_name NativeLiquidConsumableRecord
extends RefCounted

var item_instance_id: StringName
var content: LiquidState.Content
var remaining: int
## LiquidState.drink_func and slumber_effect: saved only when something was poured in.
var drink_func: StringName
var slumber_effect: int


func _init(id: StringName, kind: LiquidState.Content, portions: int, p_drink_func: StringName = &"", p_slumber_effect: int = 0) -> void:
	item_instance_id = id
	content = kind
	remaining = portions
	drink_func = p_drink_func
	slumber_effect = p_slumber_effect


func duplicate_snapshot() -> NativeLiquidConsumableRecord:
	return NativeLiquidConsumableRecord.new(item_instance_id, content, remaining, drink_func, slumber_effect)
