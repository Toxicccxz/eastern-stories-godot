class_name CombatHitPolicyStatus
extends RefCounted

## Source-projected disposition at one of combatd.c's ordered hit_ob sites.
## MudOS documents a call_other to a missing method as `undefined`; combatd.c
## ignores that value because it is neither string nor int.
enum Value {
	NOT_APPLICABLE,
	PROVEN_NO_AUTHORED_EFFECT,
	AUTHORED_POLICY_UNAVAILABLE,
	DRIVER_AMBIGUITY,
}


static func is_valid(value: int) -> bool:
	return value >= Value.NOT_APPLICABLE and value <= Value.DRIVER_AMBIGUITY
