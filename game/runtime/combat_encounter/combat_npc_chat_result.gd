class_name CombatNpcChatResult
extends RefCounted

## What one npc.c chat() in a fight did: the lines it showed (said, or a special's
## message_vision()), whom a special hurt (their last_damage_from is the NPC) and who
## came in to kill whom (ask_for_help()'s kill_ob(), a summoned soldier's invocation()).
## Read-only once made.
var _lines: Array[VisionLine] = []
var _damaged: Array[StringName] = []
var _joins: Array[CombatJoin] = []


func _init(p_lines: Array[VisionLine] = [], p_damaged: Array[StringName] = []) -> void:
	_lines = p_lines.duplicate()
	_damaged = p_damaged.duplicate()


func with_joins(p_joins: Array[CombatJoin]) -> CombatNpcChatResult:
	_joins = p_joins.duplicate()
	return self


func joins() -> Array[CombatJoin]:
	return _joins.duplicate()


## Those who came in, in order.
func joiners() -> Array[StringName]:
	var ids: Array[StringName] = []
	for join: CombatJoin in _joins:
		ids.append(join.joiner_id)
	return ids


func lines() -> Array[VisionLine]:
	return _lines.duplicate()


func damaged(character_id: StringName) -> bool:
	return _damaged.has(character_id)
