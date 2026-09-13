class_name FoodDefinition
extends RefCounted

## Single-use supply rules; no liquid, callback dispatcher, containment or stock.
var item_definition_id: StringName
var initial_portions: int
var food_supply: int
var initial_value: int
var own_weight: int


func _init(id: StringName = &"", portions: int = 0, supply: int = 0,
	value: int = 0, weight: int = 0) -> void:
	item_definition_id = id
	initial_portions = portions
	food_supply = supply
	initial_value = value
	own_weight = weight


func is_valid() -> bool:
	return item_definition_id != &"" and initial_portions > 0 and food_supply > 0 and initial_value >= 0 and own_weight >= 0


func accepts_live_state(portions: int, value: int) -> bool:
	return is_valid() and portions > 0 and portions <= initial_portions and value == (initial_value if portions == initial_portions else 0)


func duplicate_definition() -> FoodDefinition:
	return FoodDefinition.new(item_definition_id, initial_portions, food_supply, initial_value, own_weight)
