class_name LiquidUseResult
extends RefCounted

enum Outcome { AUTHORITY_FAILURE, INTERACTION_BLOCKED, NOT_DIRECT_HELD, BUSY, COMBAT_BLOCKED, NO_WATER_SOURCE, ALCOHOL_DEFERRED, EMPTY, TOO_FULL, FILLED, DRANK, ADMITTED }
var outcome: Outcome = Outcome.AUTHORITY_FAILURE
var item_id: StringName = &""
var water_before: int = 0
var water_after: int = 0
var remaining_before: int = 0
var remaining_after: int = 0
var discarded_wine: bool = false


func succeeded() -> bool:
	return outcome in [Outcome.FILLED, Outcome.DRANK]
