class_name CharacterQuestState
extends RefCounted

## The player's task from 朱鸿雪 (u/cloud/npc/god.c): query("quest"), a copy of the
## qlist entry (null once it is done: set("quest", 0)), the time left until
## task_time, query("quest_factor") and query("tfinished"), the tasks finished in a
## row. Saved.
##
## task_time is time() + the quest's time in ES2, and time() runs on while the
## player is away. Here the time left counts down on play time, fights included,
## and stops while the game is paused or closed (DECISIONS 3C).
var current: QuestDefinition
## task_time - time() in milliseconds; -1 once it has run out (it stops there).
var remaining_ms: int = 0
var factor: int = 0
var finished: int = 0


func has_task() -> bool:
	return current != null


## god.c: a task whose task_time is not after time() has run out.
func is_expired() -> bool:
	return current != null and remaining_ms <= 0


## combatd.c killer_reward(): task_time >= time() still counts the kill.
func kill_counts() -> bool:
	return current != null and remaining_ms >= 0


func assign(quest: QuestDefinition, p_factor: int) -> void:
	current = quest.duplicate_definition()
	remaining_ms = quest.time_seconds * 1000
	factor = p_factor


func clear_task() -> void:
	current = null
	remaining_ms = 0


## Play time passing (ms). The time left stops at -1.
func advance(milliseconds: int) -> void:
	if current == null or milliseconds <= 0:
		return
	remaining_ms = maxi(remaining_ms - milliseconds, -1)


## Nothing to save: no task, factor and tfinished 0.
func is_default() -> bool:
	return current == null and factor == 0 and finished == 0


func is_valid() -> bool:
	return current == null or (current.is_valid() and remaining_ms >= -1 and remaining_ms <= current.time_seconds * 1000)


func duplicate_state() -> CharacterQuestState:
	var value := CharacterQuestState.new()
	value.current = null if current == null else current.duplicate_definition()
	value.remaining_ms = remaining_ms
	value.factor = factor
	value.finished = finished
	return value
