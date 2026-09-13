class_name FoodState
extends RefCounted

## feature/food.c: food_remaining and value. Zero portions can be a reached
## failed-destruction state, but can never pass live Save validation.
var remaining_portions: int
var current_value: int


func _init(portions: int, value: int) -> void:
	remaining_portions = portions
	current_value = value


func consume_portion() -> void:
	current_value = 0
	remaining_portions -= 1
