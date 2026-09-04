class_name CombatSchedulerConfig
extends RefCounted

var _opportunity_interval_seconds: float

var opportunity_interval_seconds: float:
	get: return _opportunity_interval_seconds


func _init(p_opportunity_interval_seconds: float = 0.0) -> void:
	_opportunity_interval_seconds = p_opportunity_interval_seconds


func is_valid() -> bool:
	return (
		is_finite(_opportunity_interval_seconds)
		and _opportunity_interval_seconds > 0.0
	)
