class_name CombatTriggerCause
extends RefCounted

enum Value {
	PLAYER_LETHAL_ATTACK,
	PLAYER_SPAR,
	NPC_AGGRESSION,
	VENDETTA_HOSTILITY,
	SCRIPTED,
	QUEST,
	## combatd.c start_berserk()'s fight_ob(): an NPC challenges the player to a spar.
	NPC_SPAR,
}


static func is_valid(value: int) -> bool:
	return value >= Value.PLAYER_LETHAL_ATTACK and value <= Value.NPC_SPAR
