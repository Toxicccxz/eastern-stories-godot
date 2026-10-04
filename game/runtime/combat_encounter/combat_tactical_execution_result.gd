class_name CombatTacticalExecutionResult
extends RefCounted

## DISENGAGED is a semantic terminal intent; only encounter resolution may apply it.
enum Outcome { UNSUPPORTED, APPLIED, FAILED, DISENGAGED }

var _outcome: int
var _effect_id: StringName
var _lines: Array[ColoredLine] = []
var _special: SpecialReport
var outcome: int:
	get: return _outcome
var effect_id: StringName:
	get: return _effect_id
## What a perform file showed and did (its lines and attacks), or null.
var special: SpecialReport:
	get: return _special


## `lines`: what the action printed (exert.c's), in the shown language.
func _init(p_outcome: int = Outcome.UNSUPPORTED, p_effect_id: StringName = &"", p_lines: Array[ColoredLine] = [], p_special: SpecialReport = null) -> void:
	_outcome = p_outcome
	_effect_id = p_effect_id
	_lines = p_lines.duplicate()
	_special = p_special


func lines() -> Array[ColoredLine]:
	return _lines.duplicate()


func duplicate_snapshot() -> CombatTacticalExecutionResult:
	return CombatTacticalExecutionResult.new(_outcome, _effect_id, _lines, _special)
