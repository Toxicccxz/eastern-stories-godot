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
	## haunt.c do_haunt(): the NPC the player raised kill_ob()s the one its sheet names, who
	## fights it back; the player stands by on its side, in no fight of their own.
	SERVANT_KILL,
}


static func is_valid(value: int) -> bool:
	return value >= Value.PLAYER_LETHAL_ATTACK and value <= Value.SERVANT_KILL
