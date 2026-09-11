class_name NewPlayerInitialization
extends RefCounted

## Fresh composition, not a save snapshot. Every mutable aggregate is unique.
var _state: CharacterState
var _facts: PlayerIdentityFacts
var _armor: ArmorState
var _body_weight: int
var _maximum_encumbrance: int

var state: CharacterState:
	get: return _state
var facts: PlayerIdentityFacts:
	get: return _facts
var armor: ArmorState:
	get: return _armor
var body_weight: int:
	get: return _body_weight
var maximum_encumbrance: int:
	get: return _maximum_encumbrance


func _init(
	p_state: CharacterState, p_facts: PlayerIdentityFacts,
	p_body_weight: int, p_maximum_encumbrance: int,
) -> void:
	_state = p_state
	_facts = p_facts
	_armor = ArmorState.new()
	_body_weight = p_body_weight
	_maximum_encumbrance = p_maximum_encumbrance
