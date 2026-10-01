class_name NpcRandomText
extends RefCounted

## An NPC fact create() picks: `if (random(bound) < below) A else B`, e.g. the
## travellers' `set("gender", ...)`.
var _bound: int
var _below: int
var _then: String
var _else: String


func _init(p_bound: int = 0, p_below: int = 0, p_then: String = "", p_else: String = "") -> void:
	_bound = p_bound
	_below = p_below
	_then = p_then
	_else = p_else


func is_valid() -> bool:
	return _bound > 0 and not _then.is_empty() and not _else.is_empty()


## The first choice, which stands for the fact before a draw.
func first_choice() -> String:
	return _then


## Null-safe draw; returns null when the source answers out of range.
func resolve(random_source: NpcInitializationRandomSource) -> Variant:
	var draw: int = random_source.next_below(_bound)
	if draw < 0 or draw >= _bound:
		return null
	return _then if draw < _below else _else
