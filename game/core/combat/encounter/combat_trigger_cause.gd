class_name CombatTriggerCause
extends RefCounted

enum Value {
	PLAYER_LETHAL_ATTACK,
	PLAYER_SPAR,
	NPC_AGGRESSION,
	VENDETTA_HOSTILITY,
	SCRIPTED,
	QUEST,
}


static func is_valid(value: int) -> bool:
	return value >= Value.PLAYER_LETHAL_ATTACK and value <= Value.QUEST
