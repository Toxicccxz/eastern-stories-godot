class_name CharacterTimedApplies
extends RefCounted

## query_temp("apply/<key>") that a special adds for a while and a call_out() takes
## back: daemon/class/fighter/celestial/powerup.c add_temp()s apply/attack and
## apply/dodge, set_temp("powerup") and remove_effect() runs `skill` seconds later.
## Each entry is named by the temp flag the special checks (powerup) and counts down
## in ms: by the fight's rounds in a fight, by world time outside one (call_out() runs
## on the driver's clock, the world stands still while a fight runs). Saved.

class Entry:
	extends RefCounted
	var effect_id: StringName
	var applies: Dictionary[StringName, int] = {}
	var remaining_ms: int

	func _init(p_effect_id: StringName = &"", p_applies: Dictionary[StringName, int] = {}, p_remaining_ms: int = 0) -> void:
		effect_id = p_effect_id
		applies = p_applies.duplicate()
		remaining_ms = p_remaining_ms

	func duplicate_entry() -> Entry:
		return Entry.new(effect_id, applies, remaining_ms)

	func is_valid() -> bool:
		return not effect_id.is_empty() and remaining_ms > 0 and not applies.is_empty()


var _entries: Array[Entry] = []


## query_temp(<effect_id>): the special is still running.
func has(effect_id: StringName) -> bool:
	for entry: Entry in _entries:
		if entry.effect_id == effect_id:
			return true
	return false


## What the running entries add to query_temp("apply/<key>").
func value(key: StringName) -> int:
	var total: int = 0
	for entry: Entry in _entries:
		total += entry.applies.get(key, 0)
	return total


## add_temp() of `applies` and the call_out() that takes them back after
## `duration_ms`. False (nothing changes) when the entry runs already or is empty.
func start(effect_id: StringName, applies: Dictionary[StringName, int], duration_ms: int) -> bool:
	var entry := Entry.new(effect_id, applies, duration_ms)
	if has(effect_id) or not entry.is_valid():
		return false
	_entries.append(entry)
	return true


## `elapsed_ms` pass: the entries whose time is up end (remove_effect()); their
## IDs, in the order they were started.
func advance(elapsed_ms: int) -> Array[StringName]:
	var ended: Array[StringName] = []
	if elapsed_ms <= 0:
		return ended
	var kept: Array[Entry] = []
	for entry: Entry in _entries:
		entry.remaining_ms -= elapsed_ms
		if entry.remaining_ms > 0:
			kept.append(entry)
		else:
			ended.append(entry.effect_id)
	_entries = kept
	return ended


func is_empty() -> bool:
	return _entries.is_empty()


## Copies, in start order.
func entries() -> Array[Entry]:
	var result: Array[Entry] = []
	for entry: Entry in _entries:
		result.append(entry.duplicate_entry())
	return result


## A saved table, as restore() finds it. False (nothing changes) for an invalid one.
func restore(saved: Array[Entry]) -> bool:
	var seen: Array[StringName] = []
	for entry: Entry in saved:
		if entry == null or not entry.is_valid() or seen.has(entry.effect_id):
			return false
		seen.append(entry.effect_id)
	_entries.clear()
	for entry: Entry in saved:
		_entries.append(entry.duplicate_entry())
	return true
