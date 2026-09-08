class_name CombatEncounterEventKind
extends RefCounted

enum Value {
	ENCOUNTER_ESTABLISHED,
	PHASE_CHANGED,
	TARGET_CHANGED,
	ENCOUNTER_COMPLETED,
	ENCOUNTER_FAILED_TO_ESTABLISH,
}


static func is_valid(value: int) -> bool:
	return value >= Value.ENCOUNTER_ESTABLISHED and value <= Value.ENCOUNTER_FAILED_TO_ESTABLISH
