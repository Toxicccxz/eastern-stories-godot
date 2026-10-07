class_name ExertResult
extends RefCounted

## One `exert <function>`: what it printed, in order (the function's lines, then
## improve_skill()'s and skill_improved()'s), or the one line that refused it.
enum Failure {
	NONE,
	## exert.c: the character is busy.
	BUSY,
	## exert.c: no force skill is enabled.
	FORCE_NOT_ENABLED,
	## Neither force has the function, or the one that ran refused (notify_fail()).
	REFUSED,
}

var function_id: StringName
var failure: Failure = Failure.NONE
var lines: Array[ColoredLine] = []
## The skill exert.c practised (the enabled force or the basic one), when it did.
var skill_improvement: SkillImprovementResult
var authored_effect: SkillImprovementEffectResult
## The function knocked its user out (powerfade.c in a fight): it falls at the next
## life check.
var fainted: bool = false
## Those it had kill_ob() its user (roar.c), in the room's order.
var killers: Array[StringName] = []


func _init(p_function_id: StringName = &"") -> void:
	function_id = p_function_id


func succeeded() -> bool:
	return failure == Failure.NONE
