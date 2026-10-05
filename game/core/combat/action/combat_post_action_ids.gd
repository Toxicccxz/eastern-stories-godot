class_name CombatPostActionIds
extends RefCounted

## weapond.c post_action functions that are ported (an action's `post_action`). The
## runtime runs them after the attack and before the victim's riposte (combatd.c).
## throw_weapon: the thrown weapon loses one of its amount; the last one is unequipped
## first (你的飞刀用完了！). bash_weapon (hammers) is not ported yet.
const THROW_WEAPON: StringName = &"throw_weapon"
const SUPPORTED: Array[StringName] = [THROW_WEAPON]


static func is_supported(policy_id: StringName) -> bool:
	return SUPPORTED.has(policy_id)
