class_name NewPlayerInitialization
extends RefCounted

## Fresh composition, not a save snapshot. Every mutable aggregate is unique.
var _state: CharacterState
var _facts: PlayerIdentityFacts
var _armor: ArmorState
var _body_facts: PlayerBodyFacts

var state: CharacterState:
	get: return _state
var facts: PlayerIdentityFacts:
	get: return _facts
var armor: ArmorState:
	get: return _armor
var body_weight: int:
	get: return _body_facts.body_weight
var maximum_encumbrance: int:
	get: return _body_facts.maximum_encumbrance
var body_facts: PlayerBodyFacts:
	get: return _body_facts


func _init(
	p_state: CharacterState, p_facts: PlayerIdentityFacts,
	p_body_facts: PlayerBodyFacts,
) -> void:
	_state = p_state
	_facts = p_facts
	_armor = ArmorState.new()
	_body_facts = p_body_facts
