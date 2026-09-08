class_name CombatEncounterMode
extends RefCounted

enum Value {
	SPAR,
	LETHAL,
	SCRIPTED,
}


static func is_valid(value: int) -> bool:
	return value >= Value.SPAR and value <= Value.SCRIPTED
