class_name NpcBodyFacts
extends RefCounted

## Narrow race-aware expected body facts for current NPC definitions. Not a
## race registry, resource initializer, combat profile, or serialized authority.
var _body_weight: int
var _maximum_encumbrance: int

var body_weight: int:
	get: return _body_weight
var maximum_encumbrance: int:
	get: return _maximum_encumbrance


func _init(p_body_weight: int, p_maximum_encumbrance: int) -> void:
	_body_weight = p_body_weight
	_maximum_encumbrance = p_maximum_encumbrance


static func derive(definition: NpcDefinition, strength: int) -> NpcBodyFacts:
	if definition == null or not definition.is_valid():
		return null
	var weight: int
	match definition.race_id:
		&"human":
			weight = CharacterDerivedValues.human_weight(strength)
		&"beast":
			weight = CharacterDerivedValues.beast_weight(strength)
		_:
			return null
	# chard.c uses raw str * 5000 for every supported race.
	return NpcBodyFacts.new(weight, CharacterDerivedValues.maximum_encumbrance(strength))


func matches_saved(weight: int, capacity: int) -> bool:
	return weight == _body_weight and capacity == _maximum_encumbrance
