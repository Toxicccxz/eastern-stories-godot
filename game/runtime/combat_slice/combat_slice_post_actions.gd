class_name CombatSlicePostActions
extends RefCounted

## Runs a ported weapond.c post_action (CombatPostActionIds) for one attack, where the
## items live: `handler(attacker, policy_id, victim, parried, random) -> Array[ColoredLine]`
## returns what the player sees of it (你的飞刀用完了！ to the thrower; bash_weapon's
## message_vision() lines to the room).
var _handler: Callable


func _init(handler: Callable = Callable()) -> void:
	_handler = handler


## `parried`: combatd.c's damage == RESULT_PARRY. `random`: the fight's stream.
func run(attacker: CombatSliceCharacterBinding, policy_id: StringName, victim: CombatSliceCharacterBinding, parried: bool, random: CombatRandomSource) -> Array[ColoredLine]:
	var shown: Array[ColoredLine] = []
	if attacker == null or not _handler.is_valid() or not CombatPostActionIds.is_supported(policy_id):
		return shown
	shown.assign(_handler.call(attacker, policy_id, victim, parried, random))
	return shown
