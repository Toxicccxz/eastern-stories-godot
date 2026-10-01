class_name NpcRandomInteger
extends RefCounted

## An NPC fact create() draws: `base + random(bound)` (sign 1) or
## `base - random(bound)` (sign -1), e.g. `set("combat_exp", 600+random(400))`.
var _base: int
var _sign: int
var _bound: int

var base: int:
	get:
		return _base


func _init(p_base: int = 0, p_sign: int = 1, p_bound: int = 0) -> void:
	_base = p_base
	_sign = p_sign
	_bound = p_bound


func is_valid() -> bool:
	return _bound > 0 and _sign in [1, -1]


## Whether a saved value is one this rule can draw.
func admits(value: int) -> bool:
	var draw: int = (value - _base) * _sign
	return is_valid() and draw >= 0 and draw < _bound


## Null-safe draw; returns null when the source answers out of range.
func resolve(random_source: NpcInitializationRandomSource) -> Variant:
	var draw: int = random_source.next_below(_bound)
	if draw < 0 or draw >= _bound:
		return null
	return _base + _sign * draw
