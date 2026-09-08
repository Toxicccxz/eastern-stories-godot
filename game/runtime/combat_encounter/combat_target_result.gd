class_name CombatTargetResult
extends RefCounted

enum Code {
	NO_ACTIVE_ENCOUNTER, INVALID_REQUEST, STALE_ENCOUNTER, APPLICATION_BLOCKED,
	WORLD_GATE_MISMATCH, INVALID_ACTOR, BINDING_MISMATCH, TARGET_UNAVAILABLE,
	UNCHANGED, CHANGED,
}

var code: int


func _init(value: int = Code.NO_ACTIVE_ENCOUNTER) -> void:
	code = value


func accepted() -> bool:
	return code in [Code.UNCHANGED, Code.CHANGED]
