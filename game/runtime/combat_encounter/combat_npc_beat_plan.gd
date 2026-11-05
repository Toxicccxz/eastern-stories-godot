class_name CombatNpcBeatPlan
extends RefCounted

## 战斗拍数 A (DECISIONS「战斗拍数」): an NPC's beats for its next round, drawn a beat early
## (npc_telegraph): the first is settled and never changes once shown; the rest are its
## read (预判), changed only by what the player can see — its target's last move, a lock,
## its school's line — and the log says 变招 when one changes. Each entry carries the move
## (an action ID, or perform/<id>) and fight()'s courage draw taken with it.


class Entry:
	extends RefCounted
	## An action ID of the NPC's set, or perform/<id> (CombatBeatRules.perform_of()).
	var action: StringName
	var tag: StringName
	var cost: int
	var courage: CombatPredrawnCourage
	var confirmed: bool
	## Whether the NPC's school line (npc_if) chose this entry.
	var from_line: bool

	func _init(p_action: StringName = &"", p_tag: StringName = &"", p_cost: int = 1, p_courage: CombatPredrawnCourage = null, p_confirmed: bool = true, p_from_line: bool = false) -> void:
		action = p_action
		tag = p_tag
		cost = p_cost
		courage = p_courage
		confirmed = p_confirmed
		from_line = p_from_line

	func is_perform() -> bool:
		return not CombatBeatRules.perform_of(action).is_empty()


var actor_id: StringName
var entries: Array[Entry] = []


func _init(p_actor_id: StringName = &"") -> void:
	actor_id = p_actor_id


func is_empty() -> bool:
	return entries.is_empty()


func size() -> int:
	return entries.size()


func entry(index: int) -> Entry:
	return entries[index] if index >= 0 and index < entries.size() else null


func first() -> Entry:
	return entry(0)


## The next beat's entry, taken off the plan.
func pop() -> Entry:
	return entries.pop_front() if not entries.is_empty() else null


func append(value: Entry) -> void:
	entries.append(value)


## The tags of the planned beats, in order (the card's stamps).
func tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Entry in entries:
		result.append(value.tag)
	return result


## How many of the planned beats are settled (the first, once drawn).
func confirmed_count() -> int:
	var count: int = 0
	for value: Entry in entries:
		if value.confirmed:
			count += 1
	return count
