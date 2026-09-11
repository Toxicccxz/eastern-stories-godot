class_name PlayerBodyFacts
extends RefCounted

## Established Player own-body facts, not inventory contents or live str projections.
## Valid values are signed int64 facts: LPC move.c setters impose no positivity
## clamp or equality with current strength.
## Required/non-null at runtime binding; immutable through the public API.
var _body_weight: int
var _maximum_encumbrance: int

var body_weight: int:
	get: return _body_weight
var maximum_encumbrance: int:
	get: return _maximum_encumbrance


func _init(p_body_weight: int, p_maximum_encumbrance: int) -> void:
	_body_weight = p_body_weight
	_maximum_encumbrance = p_maximum_encumbrance


## Fresh Human body only: race/human.c + chard.c setup formulas.
static func fresh_human(strength: int) -> PlayerBodyFacts:
	return PlayerBodyFacts.new(
		CharacterDerivedValues.human_weight(strength),
		CharacterDerivedValues.maximum_encumbrance(strength),
	)
