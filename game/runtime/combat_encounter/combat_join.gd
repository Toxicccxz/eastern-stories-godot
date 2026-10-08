class_name CombatJoin
extends RefCounted

## One who comes into the running fight against the player's side, or turns in it: it
## kill_ob()s `target_ids` in that order. The player only fights it back (fight_ob()); an
## NPC target kills it back when `killed_back` (heaven_soldier.c invocation():
## enemy->kill_ob(this_object())), else only fights it back.
var joiner_id: StringName
var target_ids: Array[StringName] = []
var killed_back: bool


func _init(p_joiner_id: StringName = &"", p_target_ids: Array[StringName] = [], p_killed_back: bool = false) -> void:
	joiner_id = p_joiner_id
	target_ids = p_target_ids.duplicate()
	killed_back = p_killed_back
