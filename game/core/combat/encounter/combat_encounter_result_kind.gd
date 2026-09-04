class_name CombatEncounterResultKind
extends RefCounted

enum Value {
	VICTORY,
	DEFEAT,
	SPAR_CONCLUDED,
	FLED,
	SCRIPTED,
	FAILED_TO_ESTABLISH,
}


static func is_valid(value: int) -> bool:
	return value >= Value.VICTORY and value <= Value.FAILED_TO_ESTABLISH
