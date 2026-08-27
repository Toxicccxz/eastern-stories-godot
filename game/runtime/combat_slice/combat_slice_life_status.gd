class_name CombatSliceLifeStatus
extends RefCounted

enum Value {
	ACTIVE,
	UNCONSCIOUS,
	DEAD,
}


static func is_valid(value: int) -> bool:
	return value >= Value.ACTIVE and value <= Value.DEAD
