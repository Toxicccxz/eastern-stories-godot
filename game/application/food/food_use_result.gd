class_name FoodUseResult
extends RefCounted

enum Outcome { ATE, INTERACTION_BLOCKED, NOT_DIRECT_HELD, COMBAT_BLOCKED, BUSY, TOO_FULL, AUTHORITY_FAILURE }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var item_id: StringName = &""
var food_before: int = 0
var food_after: int = 0
var accepted_bite: bool = false
var cleanup: FoodItemRemovalResult
