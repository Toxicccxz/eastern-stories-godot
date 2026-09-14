class_name LiquidDefinition
extends RefCounted

## Definition facts, not state or a generic LPC effect map.
var item_definition_id: StringName
var maximum_portions: int
var hydration: int
var drunk_apply: int
var own_weight: int
var value: int


func _init(id: StringName, maximum: int, water_gain: int, alcohol_amount: int,
	weight: int, price: int) -> void:
	item_definition_id = id
	maximum_portions = maximum
	hydration = water_gain
	drunk_apply = alcohol_amount
	own_weight = weight
	value = price


func is_valid() -> bool:
	return item_definition_id != &"" and maximum_portions > 0 and hydration > 0 and drunk_apply >= 0 and own_weight >= 0 and value >= 0


func accepts_live_state(content: int, remaining: int) -> bool:
	return is_valid() and content in [LiquidState.Content.RED_WINE, LiquidState.Content.CLEAR_WATER] and remaining >= 0 and remaining <= maximum_portions


func duplicate_definition() -> LiquidDefinition:
	return LiquidDefinition.new(item_definition_id, maximum_portions, hydration, drunk_apply, own_weight, value)
