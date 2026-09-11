class_name NewPlayerInitializationPolicy
extends RefCounted


## Birth only: cannot take or reset an existing Player. No RNG/gift state.
## logind.c::init_new_player -> user.setup -> chard/human setup.
static func create(selected_gender: StringName, display_name: String) -> NewPlayerInitialization:
	if selected_gender not in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		return null
	var facts: PlayerIdentityFacts = PlayerIdentityFacts.new(display_name, "普通百姓", 14)
	if not facts.is_valid():
		return null
	var state: CharacterState = CharacterState.new()
	state.gender = selected_gender
	state.attributes = CharacterBaseAttributes.new(30, 30, 30, 30, 30, 30, 30, 30)
	state.progression = CharacterProgressionState.new(0, 99, 0)
	state.essence = _full_resource(CharacterDerivedValues.human_maximum_essence(facts.age))
	state.vitality = _full_resource(CharacterDerivedValues.human_maximum_vitality(facts.age))
	state.spirit = _full_resource(CharacterDerivedValues.human_maximum_spirit(facts.age))
	# Owner-approved correction: establish body BEFORE querying capacities.
	# LPC actually queried at weight=0. Only fresh birth gets full food/water.
	var body_weight: int = CharacterDerivedValues.human_weight(state.attributes.strength)
	var capacity: int = CharacterDerivedValues.maximum_encumbrance(state.attributes.strength)
	state.recovery.food = CharacterRecovery.maximum_food_capacity(body_weight)
	state.recovery.water = CharacterRecovery.maximum_water_capacity(body_weight)
	return NewPlayerInitialization.new(state, facts, body_weight, capacity)


static func _full_resource(maximum: int) -> CharacterResourceState:
	return CharacterResourceState.new(maximum, maximum, maximum)
