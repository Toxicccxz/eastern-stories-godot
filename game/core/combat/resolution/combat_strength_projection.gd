class_name CombatStrengthProjection
extends RefCounted

## Immutable scalar projection of feature/attribute.c::query_str().
var _base_strength: int
var _force_factor: int
var _strength_modifier: int

var base_strength: int:
	get:
		return _base_strength
var force_factor: int:
	get:
		return _force_factor
var strength_modifier: int:
	get:
		return _strength_modifier


func _init(
	p_base_strength: int = 0,
	p_force_factor: int = 0,
	p_strength_modifier: int = 0,
) -> void:
	_base_strength = p_base_strength
	_force_factor = p_force_factor
	_strength_modifier = p_strength_modifier


func duplicate_snapshot() -> CombatStrengthProjection:
	return CombatStrengthProjection.new(
		_base_strength,
		_force_factor,
		_strength_modifier,
	)
