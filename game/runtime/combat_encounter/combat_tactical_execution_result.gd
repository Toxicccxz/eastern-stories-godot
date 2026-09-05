class_name CombatTacticalExecutionResult
extends RefCounted

enum Outcome { UNSUPPORTED, APPLIED, FAILED }

var _outcome: int
var _effect_id: StringName
var outcome: int:
	get: return _outcome
var effect_id: StringName:
	get: return _effect_id


func _init(p_outcome: int = Outcome.UNSUPPORTED, p_effect_id: StringName = &"") -> void:
	_outcome = p_outcome
	_effect_id = p_effect_id


func duplicate_snapshot() -> CombatTacticalExecutionResult:
	return CombatTacticalExecutionResult.new(_outcome, _effect_id)
