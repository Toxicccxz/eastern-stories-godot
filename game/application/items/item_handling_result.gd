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
## The colour of a line in `lines` by its index, where it is not plain (whisper.c's GRN).
var line_colors: Dictionary[int, StringName] = {}
## The instance that moved or was destroyed: the split-off part when only some
## of a stack was handled.
var item_id: StringName = &""
## give.c destructs a gift with a value; drop.c one without.
var destroyed: bool = false
## The NPC's accept_object() rule that decided a give (null: none matched).
var rule: NpcObjectRule
## Things that ended up on the floor at the player's feet (winnings too heavy to carry).
var dropped_item_ids: Array[StringName] = []


func done() -> bool:
	return outcome == Outcome.DONE


## `lines` in their colours.
func colored_lines() -> Array[ColoredLine]:
	var colored: Array[ColoredLine] = []
	for index: int in range(lines.size()):
		colored.append(ColoredLine.new(lines[index], line_colors.get(index, ColoredLine.PLAIN)))
	return colored
