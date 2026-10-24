class_name BountyState
extends RefCounted

## Native (A2): the player's 雪亭驿 board (BountyBoard). Per slot: the tier posted (-1:
## empty), its place, and while empty the play time (ms) until it is filled; the slot taken
## (-1: none); how many have been posted (the next place). Saved while not the default.

var tiers: Array[int] = []
var places: Array[int] = []
var refill_ms: Array[int] = []
var active: int = -1
var serial: int = 0


## `count` slots, the new ones empty and due at once.
func fit(count: int) -> void:
	while tiers.size() < count:
		tiers.append(-1)
		places.append(-1)
		refill_ms.append(0)
	if tiers.size() > count:
		tiers.resize(count)
		places.resize(count)
		refill_ms.resize(count)
		if active >= count:
			active = -1


## Nothing ever posted (New Game, or a save from before A2).
func is_default() -> bool:
	return tiers.is_empty() and active < 0 and serial == 0


func duplicate_state() -> BountyState:
	var copy := BountyState.new()
	copy.tiers = tiers.duplicate()
	copy.places = places.duplicate()
	copy.refill_ms = refill_ms.duplicate()
	copy.active = active
	copy.serial = serial
	return copy


## Each slot's numbers line up, the slot taken holds a posting.
func is_valid() -> bool:
	if places.size() != tiers.size() or refill_ms.size() != tiers.size() or serial < 0:
		return false
	for slot: int in tiers.size():
		if tiers[slot] < -1 or refill_ms[slot] < 0 or (tiers[slot] < 0) != (places[slot] < 0):
			return false
	return active == -1 or (active >= 0 and active < tiers.size() and tiers[active] >= 0)
