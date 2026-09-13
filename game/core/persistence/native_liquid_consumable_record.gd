class_name NativeLiquidConsumableRecord
extends RefCounted

var item_instance_id: StringName
var content: LiquidState.Content
var remaining: int


func _init(id: StringName, kind: LiquidState.Content, portions: int) -> void:
	item_instance_id = id
	content = kind
	remaining = portions


func duplicate_snapshot() -> NativeLiquidConsumableRecord:
	return NativeLiquidConsumableRecord.new(item_instance_id, content, remaining)
