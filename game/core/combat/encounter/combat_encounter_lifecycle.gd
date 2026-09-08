class_name CombatEncounterLifecycle
extends RefCounted

enum Value {
	ESTABLISHING,
	ACTIVE,
	RESOLVING,
	COMPLETED,
	FAILED_TO_ESTABLISH,
}


static func is_valid(value: int) -> bool:
	return value >= Value.ESTABLISHING and value <= Value.FAILED_TO_ESTABLISH


static func is_terminal(value: int) -> bool:
	return value == Value.COMPLETED or value == Value.FAILED_TO_ESTABLISH


static func can_transition(from_value: int, to_value: int) -> bool:
	if not is_valid(from_value) or not is_valid(to_value):
		return false
	match from_value:
		Value.ESTABLISHING:
			return to_value in [Value.ACTIVE, Value.FAILED_TO_ESTABLISH]
		Value.ACTIVE:
			return to_value == Value.RESOLVING
		Value.RESOLVING:
			return to_value == Value.COMPLETED
		_:
			return false
