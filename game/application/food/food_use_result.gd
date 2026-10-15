class_name FoodUseResult
extends RefCounted

## TOO_BLOATED: food.c's drink_func food while water is full.
## GHOST: food.c do_eat() refuses a ghost (is_ghost()).
enum Outcome { ATE, INTERACTION_BLOCKED, NOT_DIRECT_HELD, COMBAT_BLOCKED, BUSY, TOO_FULL, TOO_BLOATED, AUTHORITY_FAILURE, GHOST }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var item_id: StringName = &""
var food_before: int = 0
var food_after: int = 0
var accepted_bite: bool = false
var cleanup: FoodItemRemovalResult
## What the eaten food became (finish_eat()): its new definition, or empty.
var leftover_id: StringName = &""
