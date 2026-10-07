class_name CombatNpcChatResult
extends RefCounted

## What one npc.c chat() in a fight did: the lines it showed (said, or a special's
## message_vision()), whom a special hurt (their last_damage_from is the NPC) and who
## came in to kill the player (ask_for_help()'s kill_ob()). Read-only once made.
var _lines: Array[VisionLine] = []
var _damaged: Array[StringName] = []
var _joiners: Array[StringName] = []


func _init(p_lines: Array[VisionLine] = [], p_damaged: Array[StringName] = []) -> void:
	_lines = p_lines.duplicate()
	_damaged = p_damaged.duplicate()


func with_joiners(p_joiners: Array[StringName]) -> CombatNpcChatResult:
	_joiners = p_joiners.duplicate()
	return self


func joiners() -> Array[StringName]:
	return _joiners.duplicate()


func lines() -> Array[VisionLine]:
	return _lines.duplicate()


func damaged(character_id: StringName) -> bool:
	return _damaged.has(character_id)
