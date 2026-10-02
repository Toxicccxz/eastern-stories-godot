class_name ItemHandlingResult
extends RefCounted

## What one give, drop, put or get-from did. `lines` are what the player reads, in
## order (the NPC's own lines come before give.c's).
enum Outcome {
	DONE,
	INVALID_REQUEST,
	NOT_CARRIED,
	NOT_ENOUGH,
	NOT_HERE,
	REFUSED,
	TOO_HEAVY,
	AUTHORITY_FAILURE,
}

var outcome: Outcome = Outcome.INVALID_REQUEST
var lines: Array[String] = []
## The instance that moved or was destroyed: the split-off part when only some
## of a stack was handled.
var item_id: StringName = &""
## give.c destructs a gift with a value; drop.c one without.
var destroyed: bool = false
## The NPC's accept_object() rule that decided a give (null: none matched).
var rule: NpcObjectRule


func done() -> bool:
	return outcome == Outcome.DONE
