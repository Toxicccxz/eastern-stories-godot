class_name CombatAttackType
extends RefCounted

## Exact values from include/combat.h.
enum Value {
	REGULAR = 0,
	RIPOSTE = 1,
	QUICK = 2,
}


static func is_valid(value: int) -> bool:
	return value >= Value.REGULAR and value <= Value.QUICK


static func is_fight_decision_intent(value: int) -> bool:
	return value == Value.REGULAR or value == Value.QUICK

