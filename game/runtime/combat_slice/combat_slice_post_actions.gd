class_name CombatSlicePostActions
extends RefCounted

## Runs a ported weapond.c post_action (CombatPostActionIds) for one attacker, where its
## items live: `handler(binding, policy_id) -> Array[String]` returns what it told
## the attacker (你的飞刀用完了！).
var _handler: Callable


func _init(handler: Callable = Callable()) -> void:
	_handler = handler


func run(binding: CombatSliceCharacterBinding, policy_id: StringName) -> Array[String]:
	var told: Array[String] = []
	if binding == null or not _handler.is_valid() or not CombatPostActionIds.is_supported(policy_id):
		return told
	told.assign(_handler.call(binding, policy_id))
	return told
