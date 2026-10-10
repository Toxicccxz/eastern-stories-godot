class_name CrimeRecord
extends RefCounted

## What the law knows of the player, kept as set() values on the character
## (CharacterState.counters, saved): query("thief"), the steals they were caught at
## (cmds/std/steal.c adds one; obj/user.c reset() takes one off, combatd.c halves it at
## death), and query("crime_lv"), what 程不平 has them beaten for (d/choyin: a constable's
## catch, a bribe too small, a constable killed). 卧龙岗's marks/强盗 is no crime (owner,
## DECISIONS 乔阴 A Q1).

const THIEF: String = "thief"
const CRIME: String = "crime_lv"
## rankd.c query_rank(): more caught steals than this make one a 惯窃.
const HABITUAL_ABOVE: int = 10


static func thief(state: CharacterState) -> int:
	return 0 if state == null else int(state.counters.get(THIEF, 0))


static func crime(state: CharacterState) -> int:
	return 0 if state == null else int(state.counters.get(CRIME, 0))


## add("thief", n); a count that falls to 0 or below is deleted (delete("thief")).
static func add_thief(state: CharacterState, amount: int) -> void:
	_add(state, THIEF, amount)


## add("crime_lv", n); none left is deleted.
static func add_crime(state: CharacterState, amount: int) -> void:
	_add(state, CRIME, amount)


static func clear_crime(state: CharacterState) -> void:
	if state != null:
		state.counters.erase(CRIME)


## obj/user.c reset(): a caught steal is forgotten (thief - 1 while above 0).
static func reset(state: CharacterState) -> void:
	if thief(state) > 0:
		add_thief(state, -1)


## combatd.c killer_reward() for a user: set("thief", thief / 2).
@warning_ignore("integer_division")
static func halve_thief(state: CharacterState) -> void:
	if thief(state) != 0:
		var halved: int = thief(state) / 2
		if halved == 0:
			state.counters.erase(THIEF)
		else:
			state.counters[THIEF] = halved


static func _add(state: CharacterState, key: String, amount: int) -> void:
	if state == null:
		return
	var value: int = int(state.counters.get(key, 0)) + amount
	if value <= 0:
		state.counters.erase(key)
	else:
		state.counters[key] = value
