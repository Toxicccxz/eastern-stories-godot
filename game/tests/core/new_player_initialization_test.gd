extends RefCounted

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	for gender: StringName in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		_test_profile(gender)
	_test_rejection_and_isolation()
	return {"assertions": _count, "failures": _failures}


func _test_profile(gender: StringName) -> void:
	var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(&"birth-fixture", 7)
	var graph: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
	_check(graph.initialize(&"player", gender, "初雪", allocator), "fresh composition succeeds")
	if graph.player == null:
		return
	var fresh: NewPlayerInitialization = graph.player
	var state: CharacterState = fresh.state
	# Independent expected literals: logind/init_new_player, user/update_age,
	# human/chard/setup, cloth/setup. Food 400 is the approved correction, NOT LPC execution.
	_check(fresh.facts.display_name == "初雪", "caller name")
	_check(fresh.facts.age == 14 and fresh.facts.title == "普通百姓", "age/title")
	_check(fresh.facts.race_id == &"human", "Human identity")
	_check(state.gender == gender, "gender remains CharacterState authority")
	var attributes: CharacterBaseAttributes = state.attributes
	for value: int in [attributes.strength, attributes.courage, attributes.intelligence,
		attributes.spirituality, attributes.composure, attributes.personality,
		attributes.constitution, attributes.karma]:
		_check(value == 30, "each source base attribute is 30")
	_check(attributes.force_factor == 0 and attributes.bellicosity == 0, "absent adjustments are zero")
	_check(state.progression.combat_experience == 0, "source experience zero")
	_check(state.progression.potential == 99 and state.progression.potential_spent == 0, "potential 99/0")
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		_check(resource.current == 100, "current resource 100")
		_check(resource.effective == 100 and resource.maximum == 100, "effective/maximum 100")
	for resource: CharacterInternalResourceState in [state.recovery.inner_force, state.recovery.mana, state.recovery.atman]:
		_check(resource.current == 0 and resource.maximum == 0, "internal resource 0/0")
	_check(fresh.body_weight == 80000, "40000 + (30 - 10) * 2000 body weight")
	_check(fresh.maximum_encumbrance == 150000, "30 * 5000 encumbrance")
	_check(state.recovery.food == 400 and state.recovery.water == 400, "approved post-body 80000 / 200 fill")
	_check(not state.skills.has_skills_mapping(), "absent raw mapping")
	_check(not state.skills.has_learned_mapping(), "absent learned mapping")
	_check(state.skills.raw_skill_ids().is_empty(), "no fabricated raw entries")
	_check(state.skills.learned_skill_ids().is_empty(), "no learned entries")
	_check(state.skills.enabled_use_ids().is_empty(), "no enabled mapping")
	_check(not state.skills.remove_skill(&"sword"), "observable absent mapping behavior")
	_check(not state.family.has_family() and not state.apprenticeship.has_master(), "no family/master")
	_check(state.conditions.size() == 0, "no pending gift condition or other condition")
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"player")
	_check(graph.inventory.registered_item_ids().size() == 1, "exactly one item, no weapons or money")
	_check(graph.inventory.direct_children(owner) == [graph.cloth.item_instance_id], "cloth is direct child")
	_check(graph.inventory.own_weight(graph.cloth.item_instance_id) == 3000 and graph.inventory.contents_weight(owner) == 3000, "real Inventory weight is cloth weight")
	_check(graph.cloth.item_definition_id == &"es2:obj/cloth", "source cloth definition identity")
	_check(graph.cloth.item_instance_id == &"birth-fixture.dynamic.7", "caller allocator supplies durable identity")
	_check(allocator.next_dynamic_sequence == 8, "only cloth allocation")
	_check(graph.item_index.resolve(graph.cloth.item_instance_id).item_definition_id == graph.cloth.item_definition_id, "index resolves actual cloth")
	_check(fresh.armor.item_instance_id_in_slot(&"cloth") == graph.cloth.item_instance_id, "actual Armor authority references cloth")
	_check(fresh.armor.aggregate_numeric_modifiers().armor == 1, "cloth armor +1")
	_check(fresh.armor.aggregate_numeric_modifiers().dodge == 0, "cloth override has NO 3000-weight dodge penalty")
	_check(state.equipment.are_both_hands_empty(), "empty hands")
	_check(SourcePlayerCloth.DISPLAY_NAME == "布衣" and SourcePlayerCloth.OWN_WEIGHT == 3000, "authored name/weight")
	var player: WorldPlayerRuntimeState = WorldPlayerRuntimeState.new(
		&"player", state, CombatRelationshipState.new(&"player"), ActionBusyState.new(),
		fresh.armor, null, CharacterRuntimeLifeStatus.Value.ACTIVE, true, true,
		fresh.body_facts, fresh.facts,
	)
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"fixture"),
	)
	var context: DeathContext = player.death_context(destination, false)
	_check(context.victim_display_name == "初雪" and context.victim_age == 14, "production death projection reads source name/age")
	_check(context.victim_gender == gender, "death gender uses CharacterState")
	_check(context.victim_body_own_weight == 80000 and context.victim_maximum_encumbrance == 150000, "death body projection")
	_check(player.state.equipment == state.equipment and player.armor == fresh.armor, "runtime receives exact authorities")
	_check(context.victim_owner.equipment_state == state.equipment and context.victim_owner.armor_state == fresh.armor, "death consumes exact equipment/armor authorities")
	state.recovery.food = -3
	state.recovery.water = 901
	_check(not graph.initialize(&"player", gender, "再生", allocator), "one-shot graph refuses repeat birth")
	_check(state.recovery.food == -3 and state.recovery.water == 901, "repeat birth cannot refill existing resources")
	_check(allocator.next_dynamic_sequence == 8, "repeat birth consumes no ID")


func _test_rejection_and_isolation() -> void:
	var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(&"shared")
	var invalid: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
	_check(not invalid.initialize(&"player", &"unknown", "Name", allocator), "unknown gender fails closed")
	_check(not invalid.initialize(&"player", CharacterState.GENDER_MALE, "  ", allocator), "blank name fails closed")
	_check(not invalid.initialize(&"", CharacterState.GENDER_MALE, "Name", allocator), "empty identity fails closed")
	_check(allocator.next_dynamic_sequence == 0 and invalid.player == null, "invalid inputs publish nothing or allocate")
	var exhausted: SessionItemIdAllocator = SessionItemIdAllocator.new(&"full", 9223372036854775807)
	_check(not invalid.initialize(&"player", CharacterState.GENDER_MALE, "Name", exhausted), "overflow fails")
	_check(exhausted.next_dynamic_sequence == 9223372036854775807 and invalid.inventory == null, "overflow no partial graph")
	var a: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
	var b: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
	_check(a.initialize(&"a", CharacterState.GENDER_MALE, "A", allocator), "independent A")
	_check(b.initialize(&"b", CharacterState.GENDER_FEMALE, "B", allocator), "independent B")
	_check(a.player.state != b.player.state, "CharacterState isolation")
	_check(a.player.state.attributes != b.player.state.attributes, "attributes isolation")
	_check(a.player.state.essence != b.player.state.essence and a.player.state.vitality != b.player.state.vitality and a.player.state.spirit != b.player.state.spirit, "resource isolation")
	_check(a.player.state.recovery != b.player.state.recovery and a.player.state.recovery.inner_force != b.player.state.recovery.inner_force, "internal resource isolation")
	_check(a.player.state.skills != b.player.state.skills, "skill isolation")
	_check(a.player.state.equipment != b.player.state.equipment and a.player.armor != b.player.armor, "equipment/armor isolation")
	_check(a.inventory != b.inventory and a.item_index != b.item_index and a.stacks != b.stacks, "inventory/index/stack isolation")
	_check(a.cloth != b.cloth and a.cloth.item_instance_id != b.cloth.item_instance_id, "cloth instance isolation")
	a.player.state.attributes.strength = 99
	a.player.state.recovery.food = 1
	a.player.state.skills.set_raw_level(&"force", 9)
	a.player.armor.remove(a.cloth.item_instance_id)
	_check(b.player.state.attributes.strength == 30 and b.player.state.recovery.food == 400, "B untouched by A mutation")
	_check(not b.player.state.skills.has_skills_mapping() and b.player.armor.is_worn(b.cloth.item_instance_id), "B skills/cloth untouched")
	# Structural regression: birth must never acquire a gift state or randomness
	# dependency. Generic property inspection is test-only, NOT a production API.
	for object: RefCounted in [a.player, a.player.facts, a.player.state, a]:
		for property: Dictionary in object.get_property_list():
			_check(not String(property["name"]).to_lower().contains("gift"), "no pending gift field")
	var random_calls: RegEx = RegEx.new()
	random_calls.compile("\\b(randf|randi|randf_range|randi_range|randomize|seed|rand_from_seed|RandomNumberGenerator|GodotCombatRandomSource|GodotNpcInitializationRandomSource|GodotWorldInteractionRandomSource)\\s*[.(]")
	for path: String in ["res://core/characters/new_player_initialization_policy.gd", "res://core/characters/new_player_initialization.gd", "res://core/characters/player_identity_facts.gd", "res://application/new_game/new_player_inventory_composition.gd", "res://data/items/source_player_cloth.gd"]:
		_check(random_calls.search(FileAccess.get_file_as_string(path)) == null, "no birth RNG calls/dependencies: " + path)


func _check(value: bool, label: String) -> void:
	_count += 1
	if not value:
		_failures.append("NGE1: " + label)
