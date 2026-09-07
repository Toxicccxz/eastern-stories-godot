class_name CombatOrderedTargetEvent
extends RefCounted

## Orders the existing Core event alongside ordinary/tactical feedback, not target state.
var _event: CombatEncounterEvent
var event: CombatEncounterEvent:
	get: return _event.duplicate_snapshot()
var _order: int
var progression_order: int:
	get: return _order


func _init(value: CombatEncounterEvent, order: int) -> void:
	_event = value.duplicate_snapshot()
	_order = order
