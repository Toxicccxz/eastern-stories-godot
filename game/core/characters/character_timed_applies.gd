class_name CharacterTimedApplies
extends RefCounted

## query_temp("apply/<key>") that a special adds for a while and a call_out() takes
## back: daemon/class/fighter/celestial/powerup.c add_temp()s apply/attack and
## apply/dodge, set_temp("powerup") and remove_effect() runs `skill` seconds later.
## Each entry is named by the temp flag the special checks (powerup) and counts down
## in ms: by the fight's rounds in a fight, by world time outside one (call_out() runs
## on the driver's clock, the world stands still while a fight runs). Saved, but for
## `target_id`: whom remove_effect() acts on (fakefault.c's strike), which only
## matters in the fight it began in.

class Entry:
	extends RefCounted
	var effect_id: StringName
	var applies: Dictionary[StringName, int] = {}
	var remaining_ms: int
	var target_id: StringName

	func _init(p_effect_id: StringName = &"", p_applies: Dictionary[StringName, int] = {}, p_remaining_ms: int = 0, p_target_id: StringName = &"") -> void:
		effect_id = p_effect_id
		applies = p_applies.duplicate()
		remaining_ms = p_remaining_ms
		target_id = p_target_id

	func duplicate_entry() -> Entry:
		return Entry.new(effect_id, applies, remaining_ms, target_id)

	func is_valid() -> bool:
		return not effect_id.is_empty() and remaining_ms > 0 and not applies.is_empty()


var _entries: Array[Entry] = []
## add_temp() a running special takes back before it returns (fakefault.c's
## remove_effect() around its strike). Never saved: empty between calls.
var _held: Dictionary[StringName, int] = {}


## query_temp(<effect_id>): the special is still running.
func has(effect_id: StringName) -> bool:
	for entry: Entry in _entries:
		if entry.effect_id == effect_id:
			return true
	return false


## What the running entries add to query_temp("apply/<key>").
func value(key: StringName) -> int:
	var total: int = _held.get(key, 0)
	for entry: Entry in _entries:
		total += entry.applies.get(key, 0)
	return total


## add_temp() of `applies` and the call_out() that takes them back after
## `duration_ms`. False (nothing changes) when the entry runs already or is empty.
func start(effect_id: StringName, applies: Dictionary[StringName, int], duration_ms: int, target_id: StringName = &"") -> bool:
	var entry := Entry.new(effect_id, applies, duration_ms, target_id)
	if has(effect_id) or not entry.is_valid():
		return false
	_entries.append(entry)
	return true


## `elapsed_ms` pass: the entries whose time is up end (remove_effect()); their
## IDs, in the order they were started.
func advance(elapsed_ms: int) -> Array[StringName]:
	var ended: Array[StringName] = []
	for entry: Entry in advance_entries(elapsed_ms):
		ended.append(entry.effect_id)
	return ended


## advance(), returning the ended entries themselves (their applies are gone).
func advance_entries(elapsed_ms: int) -> Array[Entry]:
	var ended: Array[Entry] = []
	if elapsed_ms <= 0:
		return ended
	var kept: Array[Entry] = []
	for entry: Entry in _entries:
		entry.remaining_ms -= elapsed_ms
		if entry.remaining_ms > 0:
			kept.append(entry)
		else:
			ended.append(entry)
	_entries = kept
	return ended


## The fight the entries began in is over: remove_effect() names nobody any more.
func forget_targets() -> void:
	for entry: Entry in _entries:
		entry.target_id = &""


## add_temp() of `applies` for the rest of a running special; release() takes them back.
func hold(applies: Dictionary[StringName, int]) -> void:
	for key: StringName in applies:
		_held[key] = _held.get(key, 0) + applies[key]


func release(applies: Dictionary[StringName, int]) -> void:
	for key: StringName in applies:
		var left: int = _held.get(key, 0) - applies[key]
		if left == 0:
			_held.erase(key)
		else:
			_held[key] = left


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
