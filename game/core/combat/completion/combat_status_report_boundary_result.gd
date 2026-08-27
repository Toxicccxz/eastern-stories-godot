class_name CombatStatusReportBoundaryResult
extends RefCounted

enum Outcome {
	NOT_REACHED,
	VALIDATED,
	ZERO_MAXIMUM_DIVISOR,
}

enum ValueSource {
	NOT_APPLICABLE,
	CURRENT_VITALITY,
	EFFECTIVE_VITALITY,
}

var _outcome: int
var _value_source: int
var _numerator: int
var _maximum: int
var _ratio: int

var outcome: int:
	get:
		return _outcome
var value_source: int:
	get:
		return _value_source
var numerator: int:
	get:
		return _numerator
var maximum: int:
	get:
		return _maximum
var ratio: int:
	get:
		return _ratio


func _init(
	p_outcome: int = Outcome.NOT_REACHED,
	p_value_source: int = ValueSource.NOT_APPLICABLE,
	p_numerator: int = 0,
	p_maximum: int = 0,
	p_ratio: int = 0,
) -> void:
	_outcome = p_outcome
	_value_source = p_value_source
	_numerator = p_numerator
	_maximum = p_maximum
	_ratio = p_ratio


func duplicate_snapshot() -> CombatStatusReportBoundaryResult:
	return CombatStatusReportBoundaryResult.new(
		_outcome,
		_value_source,
		_numerator,
		_maximum,
		_ratio,
	)
