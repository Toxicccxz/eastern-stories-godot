extends RefCounted

const OldPineWorld := preload("res://data/oldpine/oldpine_world_definitions.gd")
const OldPineNpcs := preload("res://data/oldpine/oldpine_npc_definitions.gd")
const OldPineSpawns := preload("res://data/oldpine/oldpine_spawn_definitions.gd")
const RuntimeLifeStatus := preload(
	"res://runtime/characters/character_runtime_life_status.gd"
)
const ScriptedRandom := preload(
	"res://tests/support/scripted_npc_initialization_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_exact_bandit_definition()
	_test_human_rng_order_and_derived_state()
	_test_authored_attribute_skips_only_its_draw()
	_test_authored_courage_skips_only_its_draw()
	_test_invalid_rng_draw_rejected()
	_test_bandit_loadout_uses_closed_item_authorities()
	_test_spath1_builds_three_independent_runtime_states()
	_test_runtime_life_status_is_independent_from_threshold()
	_test_map_local_collection_order_and_existence()
	_test_authored_npc_and_spawn_arrays_are_defensive()
	_test_oldpine_native_ids_are_unique()
	_test_invalid_spawn_and_definition_shapes()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_exact_bandit_definition() -> void:
	_assert_true(OldPineNpcs.validate(), "Old Pine NPC content resolves")
	_assert_true(OldPineSpawns.validate(), "Old Pine spawn references resolve")
	var bandit: NpcDefinition = OldPineNpcs.bandit_definition()
	_assert_eq(bandit.definition_id, &"oldpine.npc.bandit", "bandit native ID")
	_assert_eq(bandit.legacy_source_path, "d/oldpine/npc/bandit.c", "bandit source")
	_assert_eq(bandit.display_name, "土匪探哨", "bandit name")
	_assert_eq(bandit.aliases(), [&"bandit"], "bandit aliases")
	_assert_eq(bandit.race_id, &"human", "bandit human race")
	_assert_true(bandit.has_authored_gender, "bandit gender authored")
	_assert_eq(bandit.gender, CharacterState.GENDER_MALE, "bandit male")
	_assert_true(bandit.has_authored_age, "bandit age authored")
	_assert_eq(bandit.age, 19, "bandit age 19")
	_assert_eq(bandit.combat_experience, 600, "bandit combat exp")
	_assert_eq(bandit.score, 60, "bandit score")
	_assert_eq(bandit.attitude, NpcDefinition.Attitude.AGGRESSIVE, "bandit attitude")
	_assert_true(
		bandit.has_capability(OldPineNpcs.AGGRESSIVE_ON_PLAYER_PRESENCE),
		"aggression is authored capability data",
	)
	_assert_true(bandit.base_attribute_overrides().is_empty(), "no fake authored attributes")
	_assert_true(bandit.resource_overrides().is_empty(), "no fake authored resources")

	var skills: Array[NpcSkillLevelDefinition] = bandit.skill_levels()
	_assert_eq(skills.size(), 3, "exact three authored skills")
	_assert_skill(skills[0], &"sword", 10, "sword")
	_assert_skill(skills[1], &"parry", 10, "parry")
	_assert_skill(skills[2], &"dodge", 10, "dodge")
	for forbidden_skill: StringName in [&"unarmed", &"force", &"perception"]:
		var found: bool = false
		for skill: NpcSkillLevelDefinition in skills:
			found = found or skill.skill_id == forbidden_skill
		_assert_false(found, "no invented %s skill" % String(forbidden_skill))

	var loadout: Array[NpcLoadoutEntry] = bandit.loadout_entries()
	_assert_eq(loadout.size(), 2, "exact two loadout entries")
	_assert_eq(loadout[0].item_definition_id, OldPineNpcs.SHORT_SWORD_ITEM_ID, "short sword definition")
	_assert_eq(loadout[0].quantity, 1, "one short sword")
	_assert_eq(loadout[0].equipment_intent, NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY, "wield-primary intent")
	_assert_eq(loadout[0].legacy_source_path, "d/oldpine/npc/obj/short_sword.c", "actual carried sword source")
	_assert_eq(loadout[1].item_definition_id, OldPineNpcs.SILVER_ITEM_ID, "silver definition")
	_assert_eq(loadout[1].quantity, 3, "silver authored amount three")
	_assert_eq(loadout[1].equipment_intent, NpcLoadoutEntry.EquipmentIntent.NONE, "silver not equipped")

	var sword: NpcLoadoutItemDefinition = OldPineNpcs.short_sword_content()
	_assert_eq(sword.item_definition().item_definition_id, OldPineNpcs.SHORT_SWORD_ITEM_ID, "canonical sword item identity")
	_assert_eq(sword.weapon_definition().weapon_id, OldPineNpcs.SHORT_SWORD_ITEM_ID, "canonical sword weapon identity")
	_assert_eq(sword.weapon_definition().skill_type, &"sword", "SWORD skill type")
	_assert_true(sword.weapon_definition().can_wield_as_secondary, "SECONDARY capability")
	_assert_false(sword.weapon_definition().is_two_handed, "short sword one-handed")
	_assert_eq(sword.weapon_damage, 15, "source init_sword damage")
	_assert_eq(sword.own_weight, 3000, "source sword weight")
	_assert_eq(
		sword.legacy_source_paths(),
		["d/oldpine/obj/short_sword.c", "d/oldpine/npc/obj/short_sword.c"],
		"one definition traces both byte-identical sources",
	)
	var silver: NpcLoadoutItemDefinition = OldPineNpcs.silver_content()
	_assert_eq(silver.stack_definition().base_weight, 37, "silver base weight")
	_assert_eq(silver.currency_definition().base_value, 100, "silver base value")
	_assert_eq(silver.currency_definition().value_for_amount(3), 300, "silver amount-scaled value")
	var definition_variant: Variant = bandit
	var content_variant: Variant = sword
	_assert_false(definition_variant is Node, "NPC definition Node-free")
	_assert_false(content_variant is Node, "loadout content Node-free")
	_assert_false(definition_variant is Callable, "NPC definition is not a callback")
	var aliases: Array[StringName] = bandit.aliases()
	aliases[0] = &"mutated"
	_assert_eq(bandit.aliases(), [&"bandit"], "NPC aliases defensive copy")
	var source_paths: Array[String] = sword.legacy_source_paths()
	source_paths[0] = "mutated"
	_assert_eq(sword.legacy_source_paths()[0], "d/oldpine/obj/short_sword.c", "item source paths defensive copy")


func _test_human_rng_order_and_derived_state() -> void:
	var random_source: ScriptedNpcInitializationRandomSource = ScriptedRandom.new(
		[0, 20, 1, 19, 2, 18, 3, 17]
	)
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var runtime: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		OldPineNpcs.bandit_definition(),
		&"bandit.rng.character",
		OldPineSpawns.SPATH1_BANDIT_SPAWN_ID,
		&"bandit.rng.point",
		_south_location(),
		inventory,
		stacks,
		random_source,
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(runtime != null and runtime.is_valid(), "scripted bandit constructs")
	_assert_eq(runtime.age, 19, "explicit age preserved")
	_assert_eq(random_source.call_count(), 8, "explicit age consumes no random draw")
	_assert_eq(random_source.requested_bounds(), [21, 21, 21, 21, 21, 21, 21, 21], "eight random(21) calls")
	var attributes: CharacterBaseAttributes = runtime.character_state.attributes
	_assert_eq(attributes.strength, 10, "str first: draw 0 + 10")
	_assert_eq(attributes.courage, 30, "cor second: draw 20 + 10")
	_assert_eq(attributes.intelligence, 11, "int third")
	_assert_eq(attributes.spirituality, 29, "spi fourth")
	_assert_eq(attributes.composure, 12, "cps fifth")
	_assert_eq(attributes.personality, 28, "per sixth")
	_assert_eq(attributes.constitution, 13, "con seventh")
	_assert_eq(attributes.karma, 27, "kar eighth")
	_assert_resource(runtime.character_state.essence, 200, 200, 200, "age 19 gin")
	_assert_resource(runtime.character_state.vitality, 200, 200, 200, "age 19 kee")
	_assert_resource(runtime.character_state.spirit, 100, 100, 100, "age 19 sen")
	_assert_eq(runtime.body_weight, CharacterDerivedValues.human_weight(10), "body weight uses closed formula")
	_assert_eq(runtime.body_weight, 40000, "strength 10 body weight")
	_assert_eq(runtime.maximum_encumbrance, CharacterDerivedValues.maximum_encumbrance(10), "capacity uses closed formula")
	_assert_eq(runtime.maximum_encumbrance, 50000, "strength 10 capacity")
	_assert_eq(runtime.character_state.progression.combat_experience, 600, "runtime combat exp")
	_assert_eq(runtime.character_state.skills.raw_level(&"sword"), 10, "runtime sword")
	_assert_eq(runtime.character_state.skills.raw_level(&"parry"), 10, "runtime parry")
	_assert_eq(runtime.character_state.skills.raw_level(&"dodge"), 10, "runtime dodge")
	for absent_skill: StringName in [&"unarmed", &"force", &"perception"]:
		_assert_false(
			runtime.character_state.skills.has_raw_level(absent_skill),
			"runtime has no fake %s entry" % String(absent_skill),
		)
	for use_id: StringName in [&"sword", &"parry", &"dodge"]:
		_assert_eq(
			runtime.character_state.skills.mapped_skill(use_id),
			&"",
			"runtime has no invented %s mapping" % String(use_id),
		)
	_assert_eq(runtime.character_state.progression.potential, 0, "no invented potential")
	_assert_eq(runtime.character_state.progression.potential_spent, 0, "no invented spent potential")


func _test_authored_attribute_skips_only_its_draw() -> void:
	var definition: NpcDefinition = NpcDefinition.new(
		&"test.human.partial",
		"test/source.c",
		"部分属性人类",
		[&"partial"],
		NpcCharacterStateFactory.HUMAN_RACE_ID,
		true,
		CharacterState.GENDER_MALE,
		true,
		19,
		NpcBaseAttributeOverrides.new(true, 99),
		NpcResourceOverrides.new(),
		0,
		0,
		NpcDefinition.Attitude.PEACEFUL,
	)
	var random_source: ScriptedNpcInitializationRandomSource = ScriptedRandom.new(
		[0, 1, 2, 3, 4, 5, 20]
	)
	var runtime: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		definition,
		&"partial.character",
		&"partial.spawn",
		&"partial.point",
		_south_location(),
		InventoryState.new(),
		CombinedStackCollection.new(),
		random_source,
		[],
	)
	_assert_true(runtime != null, "partial authored human constructs")
	_assert_eq(random_source.call_count(), 7, "authored strength skips exactly one draw")
	_assert_eq(runtime.character_state.attributes.strength, 99, "authored strength preserved")
	_assert_eq(runtime.character_state.attributes.courage, 10, "first draw advances to courage")
	_assert_eq(runtime.character_state.attributes.karma, 30, "last draw advances to karma")


func _test_authored_courage_skips_only_its_draw() -> void:
	var definition: NpcDefinition = NpcDefinition.new(
		&"test.human.authored_courage",
		"test/source.c",
		"指定勇气人类",
		[&"authored_courage"],
		NpcCharacterStateFactory.HUMAN_RACE_ID,
		true,
		CharacterState.GENDER_MALE,
		true,
		19,
		NpcBaseAttributeOverrides.new(false, 0, true, 88),
		NpcResourceOverrides.new(),
		0,
		0,
		NpcDefinition.Attitude.PEACEFUL,
	)
	var random_source: ScriptedNpcInitializationRandomSource = ScriptedRandom.new(
		[0, 1, 2, 3, 4, 5, 6]
	)
	var runtime: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		definition,
		&"authored_courage.character",
		&"authored_courage.spawn",
		&"authored_courage.point",
		_south_location(),
		InventoryState.new(),
		CombinedStackCollection.new(),
		random_source,
		[],
	)
	_assert_true(runtime != null, "authored courage human constructs")
	_assert_eq(random_source.call_count(), 7, "authored courage skips exactly its draw")
	_assert_eq(random_source.requested_bounds(), [21, 21, 21, 21, 21, 21, 21], "remaining authored-courage draws keep random(21) bounds")
	_assert_eq(runtime.character_state.attributes.strength, 10, "str consumes first draw")
	_assert_eq(runtime.character_state.attributes.courage, 88, "authored courage preserved")
	_assert_eq(runtime.character_state.attributes.intelligence, 11, "int consumes second draw")
	_assert_eq(runtime.character_state.attributes.karma, 16, "kar consumes seventh draw")


func _test_invalid_rng_draw_rejected() -> void:
	var low_inventory: InventoryState = InventoryState.new()
	var low_stacks: CombinedStackCollection = CombinedStackCollection.new()
	var low: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		OldPineNpcs.bandit_definition(),
		&"invalid.low.character",
		&"invalid.low.spawn",
		&"invalid.low.point",
		_south_location(),
		low_inventory,
		low_stacks,
		ScriptedRandom.new([-1]),
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(low == null, "negative RNG draw is rejected, not clamped")
	_assert_true(low_inventory.registered_item_ids().is_empty(), "invalid low draw creates no items")
	_assert_eq(low_stacks.registered_count(), 0, "invalid low draw creates no stack")

	var high_inventory: InventoryState = InventoryState.new()
	var high_stacks: CombinedStackCollection = CombinedStackCollection.new()
	var high_source: ScriptedNpcInitializationRandomSource = ScriptedRandom.new([0, 21])
	var high: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		OldPineNpcs.bandit_definition(),
		&"invalid.high.character",
		&"invalid.high.spawn",
		&"invalid.high.point",
		_south_location(),
		high_inventory,
		high_stacks,
		high_source,
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(high == null, "draw equal to bound is rejected, not clamped")
	_assert_eq(high_source.call_count(), 2, "factory stops at first invalid draw")
	_assert_eq(high_source.requested_bounds(), [21, 21], "invalid draw is checked against exact source bound")
	_assert_true(high_inventory.registered_item_ids().is_empty(), "invalid high draw creates no items")
	_assert_eq(high_stacks.registered_count(), 0, "invalid high draw creates no stack")


func _test_bandit_loadout_uses_closed_item_authorities() -> void:
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var runtime: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		OldPineNpcs.bandit_definition(),
		&"bandit.loadout.character",
		OldPineSpawns.SPATH1_BANDIT_SPAWN_ID,
		&"bandit.loadout.point",
		_south_location(),
		inventory,
		stacks,
		ScriptedRandom.new([0, 0, 0, 0, 0, 0, 0, 0]),
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(runtime != null, "loadout bandit constructs")
	var items: Array[ItemInstance] = runtime.loadout_items()
	_assert_eq(items.size(), 2, "one sword object plus one combined silver object")
	var sword_item: ItemInstance = _item_with_definition(items, OldPineNpcs.SHORT_SWORD_ITEM_ID)
	var silver_item: ItemInstance = _item_with_definition(items, OldPineNpcs.SILVER_ITEM_ID)
	_assert_true(sword_item != null, "live short sword instance exists")
	_assert_true(silver_item != null, "live silver stack instance exists")
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		runtime.character_id,
	)
	_assert_true(inventory.is_direct_child(sword_item.item_instance_id, owner), "sword directly owned")
	_assert_true(inventory.is_direct_child(silver_item.item_instance_id, owner), "silver directly owned")
	_assert_eq(inventory.direct_children(owner).size(), 2, "two direct inventory objects")
	_assert_eq(inventory.own_weight(sword_item.item_instance_id), 3000, "sword live weight")
	_assert_eq(inventory.own_weight(silver_item.item_instance_id), 111, "silver amount weight 3 * 37")
	_assert_eq(stacks.stack_state(silver_item.item_instance_id).amount, 3, "one combined silver stack amount three")
	_assert_eq(stacks.stack_definition(silver_item.item_instance_id).base_weight, 37, "live silver stack definition")
	var primary: EquippedWeaponRef = runtime.character_state.equipment.primary_weapon()
	_assert_true(primary != null, "short sword wielded")
	_assert_eq(primary.instance_id, sword_item.item_instance_id, "short sword is primary")
	_assert_eq(primary.skill_type, &"sword", "primary uses sword skill")
	_assert_true(primary.can_wield_as_secondary, "SECONDARY remains weapon capability")
	_assert_true(runtime.character_state.equipment.is_secondary_hand_empty(), "bandit did not equip it secondary")


func _test_spath1_builds_three_independent_runtime_states() -> void:
	var spawn: NpcSpawnDefinition = OldPineSpawns.spath1_bandit_spawn()
	_assert_true(spawn.is_valid(), "spath1 spawn coherent")
	_assert_eq(spawn.quantity, 3, "spath1 native quantity three")
	_assert_eq(spawn.legacy_quantity, 3, "spath1 source quantity three")
	_assert_eq(spawn.spawn_point_ids().size(), 3, "exact three stable spawn points")
	_assert_eq(spawn.legacy_source_room_path, "d/oldpine/spath1.c", "spawn source trace")
	var draws: Array[int] = []
	for index: int in range(24):
		draws.append(index % 21)
	var random_source: ScriptedNpcInitializationRandomSource = ScriptedRandom.new(draws)
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var runtimes: Array[NpcRuntimeState] = NpcCharacterStateFactory.new().create_spawn_instances(
		spawn,
		OldPineNpcs.bandit_definition(),
		_south_location(),
		inventory,
		stacks,
		random_source,
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_eq(runtimes.size(), 3, "all three source-authored bandits constructed")
	_assert_eq(random_source.call_count(), 24, "continuous stream: eight draws per instance")
	for bound: int in random_source.requested_bounds():
		_assert_eq(bound, 21, "every spawned attribute uses random(21)")
	_assert_eq(runtimes[0].character_state.attributes.strength, 10, "first instance starts at draw 0")
	_assert_eq(runtimes[1].character_state.attributes.strength, 18, "second instance continues at draw 8")
	_assert_eq(runtimes[2].character_state.attributes.strength, 26, "third instance continues at draw 16")
	_assert_eq(runtimes[1].body_weight, 56000, "second strength uses human weight formula")
	_assert_eq(runtimes[1].maximum_encumbrance, 90000, "second strength uses encumbrance formula")
	var character_ids: Dictionary[StringName, bool] = {}
	var sword_ids: Dictionary[StringName, bool] = {}
	var silver_ids: Dictionary[StringName, bool] = {}
	for runtime: NpcRuntimeState in runtimes:
		character_ids[runtime.character_id] = true
		_assert_eq(runtime.definition_id, OldPineNpcs.BANDIT_DEFINITION_ID, "shared definition identity")
		_assert_true(runtime.definition() == runtimes[0].definition(), "immutable definition object may be shared")
		_assert_eq(runtime.spawn_id, spawn.spawn_id, "runtime spawn identity")
		_assert_true(spawn.spawn_point_ids().has(runtime.spawn_point_id), "runtime spawn point identity")
		var sword: ItemInstance = _item_with_definition(runtime.loadout_items(), OldPineNpcs.SHORT_SWORD_ITEM_ID)
		var silver: ItemInstance = _item_with_definition(runtime.loadout_items(), OldPineNpcs.SILVER_ITEM_ID)
		_assert_true(sword != null, "spawned bandit has sword")
		_assert_true(silver != null, "spawned bandit has silver")
		sword_ids[sword.item_instance_id] = true
		silver_ids[silver.item_instance_id] = true
		_assert_eq(stacks.stack_state(silver.item_instance_id).amount, 3, "each silver identity owns amount three")
	_assert_eq(character_ids.size(), 3, "unique CharacterIds")
	_assert_eq(sword_ids.size(), 3, "unique short-sword instance IDs")
	_assert_eq(silver_ids.size(), 3, "unique silver instance IDs")
	_assert_independent_runtime_authorities(runtimes[0], runtimes[1])
	_assert_independent_runtime_authorities(runtimes[1], runtimes[2])
	var previous_second_strength: int = runtimes[1].character_state.attributes.strength
	runtimes[0].character_state.attributes.strength = 777
	_assert_eq(runtimes[1].character_state.attributes.strength, previous_second_strength, "attribute mutation remains instance-local")
	runtimes[0].busy.start_busy(4)
	_assert_false(runtimes[1].busy.is_busy(), "busy mutation remains instance-local")
	runtimes[0].relationship.add_opponent(runtimes[1].character_id)
	_assert_false(runtimes[2].relationship.has_opponent(runtimes[1].character_id), "relationship mutation remains instance-local")


func _test_runtime_life_status_is_independent_from_threshold() -> void:
	var runtime: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		OldPineNpcs.bandit_definition(),
		&"threshold.character",
		&"threshold.spawn",
		&"threshold.point",
		_south_location(),
		InventoryState.new(),
		CombinedStackCollection.new(),
		ScriptedRandom.new([0, 0, 0, 0, 0, 0, 0, 0]),
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(runtime != null, "threshold test NPC constructs")
	_assert_eq(runtime.life_status, RuntimeLifeStatus.Value.ACTIVE, "fresh runtime status committed ACTIVE")
	runtime.character_state.vitality.apply_damage(201)
	_assert_eq(runtime.character_state.life_threshold(), CharacterState.LifeThreshold.UNCONSCIOUS, "resource evidence crosses unconscious threshold")
	_assert_eq(runtime.life_status, RuntimeLifeStatus.Value.ACTIVE, "threshold crossing does not auto-commit runtime status")
	_assert_true(runtime.set_life_status(RuntimeLifeStatus.Value.UNCONSCIOUS), "outer lifecycle may commit unconscious status")
	runtime.character_state.vitality.apply_wound(201)
	_assert_eq(runtime.character_state.life_threshold(), CharacterState.LifeThreshold.DEAD, "resource evidence crosses death threshold")
	_assert_eq(runtime.life_status, RuntimeLifeStatus.Value.UNCONSCIOUS, "death evidence does not auto-commit terminal status")


func _test_map_local_collection_order_and_existence() -> void:
	var draws: Array[int] = []
	for index: int in range(24):
		draws.append(index % 21)
	var runtimes: Array[NpcRuntimeState] = NpcCharacterStateFactory.new().create_spawn_instances(
		OldPineSpawns.spath1_bandit_spawn(),
		OldPineNpcs.bandit_definition(),
		_south_location(),
		InventoryState.new(),
		CombinedStackCollection.new(),
		ScriptedRandom.new(draws),
		OldPineNpcs.loadout_item_definitions(),
	)
	var collection: MapCharacterRuntimeState = MapCharacterRuntimeState.new(
		OldPineWorld.OUTDOOR_MAP_ID
	)
	for runtime: NpcRuntimeState in runtimes:
		_assert_true(collection.register_npc(runtime), "map accepts ordered NPC")
	_assert_eq(collection.size(), 3, "map collection supports more than two")
	_assert_eq(collection.ordered_character_ids(), [
		runtimes[0].character_id,
		runtimes[1].character_id,
		runtimes[2].character_id,
	], "map collection preserves insertion order")
	_assert_eq(collection.ordered_active_characters(), runtimes, "ordered runtime snapshot")
	var returned_runtimes: Array[NpcRuntimeState] = collection.ordered_active_characters()
	returned_runtimes.clear()
	_assert_eq(collection.size(), 3, "runtime snapshot cannot mutate collection")
	var returned_ids: Array[StringName] = collection.ordered_character_ids()
	returned_ids.clear()
	_assert_eq(collection.ordered_character_ids().size(), 3, "ID snapshot cannot mutate collection")
	_assert_true(collection.find_npc(runtimes[1].character_id) == runtimes[1], "stable ID lookup")
	_assert_false(collection.register_npc(runtimes[1]), "duplicate CharacterId rejected")
	var removed_state: CharacterState = runtimes[1].character_state
	_assert_true(collection.remove_character(runtimes[1].character_id), "explicit removal succeeds")
	_assert_false(runtimes[1].exists_in_map, "removed runtime existence false")
	_assert_true(runtimes[1].character_state == removed_state, "removal does not destroy CharacterState")
	_assert_false(collection.has_character(runtimes[1].character_id), "removed lookup absent")
	_assert_eq(collection.ordered_character_ids(), [runtimes[0].character_id, runtimes[2].character_id], "removal preserves remaining order")
	_assert_false(collection.remove_character(runtimes[1].character_id), "repeated removal rejected")
	var collection_variant: Variant = collection
	_assert_false(collection_variant is Node, "map-local collection Node-free")


func _test_authored_npc_and_spawn_arrays_are_defensive() -> void:
	var aliases: Array[StringName] = [&"immutable"]
	var skills: Array[NpcSkillLevelDefinition] = [
		NpcSkillLevelDefinition.new(&"sword", 10),
	]
	var loadout: Array[NpcLoadoutEntry] = [
		NpcLoadoutEntry.new(&"item", 1, NpcLoadoutEntry.EquipmentIntent.NONE, "item.c"),
	]
	var capabilities: Array[StringName] = [&"capability"]
	var definition: NpcDefinition = NpcDefinition.new(
		&"immutable.npc",
		"npc.c",
		"Immutable NPC",
		aliases,
		&"human",
		false,
		&"",
		false,
		0,
		null,
		null,
		0,
		0,
		NpcDefinition.Attitude.PEACEFUL,
		skills,
		loadout,
		capabilities,
	)
	aliases[0] = &"mutated"
	skills[0] = NpcSkillLevelDefinition.new(&"mutated", 99)
	loadout[0] = NpcLoadoutEntry.new(&"mutated", 2, 0, "mutated.c")
	capabilities[0] = &"mutated"
	_assert_eq(definition.aliases(), [&"immutable"], "NPC alias input copied")
	_assert_eq(definition.skill_levels()[0].skill_id, &"sword", "NPC skill input copied")
	_assert_eq(definition.loadout_entries()[0].item_definition_id, &"item", "NPC loadout input copied")
	_assert_eq(definition.capability_ids(), [&"capability"], "NPC capability input copied")
	var returned_aliases: Array[StringName] = definition.aliases()
	var returned_skills: Array[NpcSkillLevelDefinition] = definition.skill_levels()
	var returned_loadout: Array[NpcLoadoutEntry] = definition.loadout_entries()
	var returned_capabilities: Array[StringName] = definition.capability_ids()
	returned_aliases[0] = &"returned"
	returned_skills[0] = NpcSkillLevelDefinition.new(&"returned", 1)
	returned_loadout[0] = NpcLoadoutEntry.new(&"returned", 1, 0, "returned.c")
	returned_capabilities[0] = &"returned"
	_assert_eq(definition.aliases(), [&"immutable"], "NPC alias output copied")
	_assert_eq(definition.skill_levels()[0].skill_id, &"sword", "NPC skill output copied")
	_assert_eq(definition.loadout_entries()[0].item_definition_id, &"item", "NPC loadout output copied")
	_assert_eq(definition.capability_ids(), [&"capability"], "NPC capability output copied")

	var points: Array[StringName] = [&"point"]
	var spawn: NpcSpawnDefinition = NpcSpawnDefinition.new(
		&"immutable.spawn",
		definition.definition_id,
		&"map",
		&"zone",
		points,
		1,
		"room.c",
		1,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)
	points[0] = &"mutated"
	_assert_eq(spawn.spawn_point_ids(), [&"point"], "spawn point input copied")
	var returned_points: Array[StringName] = spawn.spawn_point_ids()
	returned_points[0] = &"returned"
	_assert_eq(spawn.spawn_point_ids(), [&"point"], "spawn point output copied")


func _test_oldpine_native_ids_are_unique() -> void:
	var native_ids: Dictionary[StringName, bool] = {}
	_assert_register_unique(native_ids, OldPineWorld.region_definition().region_id, "region")
	for map: MapDefinition in OldPineWorld.map_definitions():
		_assert_register_unique(native_ids, map.map_id, "map")
	for zone: ZoneDefinition in OldPineWorld.zone_definitions():
		_assert_register_unique(native_ids, zone.zone_id, "zone")
	for portal: PortalDefinition in OldPineWorld.portal_definitions():
		_assert_register_unique(native_ids, portal.portal_id, "portal")
	_assert_register_unique(native_ids, OldPineNpcs.bandit_definition().definition_id, "NPC")
	_assert_register_unique(native_ids, OldPineSpawns.spath1_bandit_spawn().spawn_id, "spawn")
	for content: NpcLoadoutItemDefinition in OldPineNpcs.loadout_item_definitions():
		_assert_register_unique(
			native_ids,
			content.item_definition().item_definition_id,
			"item",
		)
	_assert_eq(native_ids.size(), 23, "all 23 cross-category native IDs are distinct")


func _test_invalid_spawn_and_definition_shapes() -> void:
	_assert_false(NpcDefinition.new().is_valid(), "empty NPC definition invalid")
	_assert_false(NpcLoadoutEntry.new(&"item", 0, NpcLoadoutEntry.EquipmentIntent.NONE, "source").is_valid(), "zero loadout quantity invalid")
	_assert_false(NpcSpawnDefinition.new().is_valid(), "empty spawn invalid")
	var mismatched: NpcSpawnDefinition = NpcSpawnDefinition.new(
		&"spawn", &"npc", &"map", &"zone", [&"one"], 2, "room.c", 2,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)
	_assert_false(mismatched.is_valid(), "spawn point count must match quantity")
	var duplicate_skill: NpcDefinition = NpcDefinition.new(
		&"npc", "source.c", "NPC", [&"npc"], &"human", false, &"", false, 0,
		null, null, 0, 0, NpcDefinition.Attitude.PEACEFUL,
		[NpcSkillLevelDefinition.new(&"sword", 1), NpcSkillLevelDefinition.new(&"sword", 2)],
	)
	_assert_false(duplicate_skill.is_valid(), "duplicate skill IDs rejected")


func _south_location() -> WorldLocationState:
	return WorldLocationState.new(
		OldPineWorld.REGION_ID,
		OldPineWorld.OUTDOOR_MAP_ID,
		OldPineWorld.SOUTH_SLOPE_ZONE_ID,
		OldPineWorld.SOUTH_SLOPE_ZONE_ID,
	)


func _item_with_definition(
	items: Array[ItemInstance],
	definition_id: StringName,
) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _assert_independent_runtime_authorities(
	left: NpcRuntimeState,
	right: NpcRuntimeState,
) -> void:
	_assert_true(left != right, "runtime state independent")
	_assert_true(left.character_state != right.character_state, "CharacterState independent")
	_assert_true(left.character_state.attributes != right.character_state.attributes, "attributes independent")
	_assert_true(left.character_state.essence != right.character_state.essence, "essence independent")
	_assert_true(left.character_state.vitality != right.character_state.vitality, "vitality independent")
	_assert_true(left.character_state.spirit != right.character_state.spirit, "spirit independent")
	_assert_true(left.character_state.recovery != right.character_state.recovery, "recovery independent")
	_assert_true(left.character_state.recovery.inner_force != right.character_state.recovery.inner_force, "inner force independent")
	_assert_true(left.character_state.recovery.mana != right.character_state.recovery.mana, "mana independent")
	_assert_true(left.character_state.recovery.atman != right.character_state.recovery.atman, "atman independent")
	_assert_true(left.character_state.conditions != right.character_state.conditions, "conditions independent")
	_assert_true(left.character_state.skills != right.character_state.skills, "skills independent")
	_assert_true(left.character_state.progression != right.character_state.progression, "progression independent")
	_assert_true(left.character_state.equipment != right.character_state.equipment, "equipment independent")
	_assert_true(left.character_state.family != right.character_state.family, "family independent")
	_assert_true(left.character_state.apprenticeship != right.character_state.apprenticeship, "apprenticeship independent")
	_assert_true(left.relationship != right.relationship, "relationship independent")
	_assert_true(left.busy != right.busy, "busy independent")
	_assert_true(left.armor != right.armor, "armor independent")


func _assert_skill(
	skill: NpcSkillLevelDefinition,
	expected_id: StringName,
	expected_level: int,
	label: String,
) -> void:
	_assert_eq(skill.skill_id, expected_id, "%s ID" % label)
	_assert_eq(skill.raw_level, expected_level, "%s level" % label)


func _assert_register_unique(
	seen: Dictionary[StringName, bool],
	id: StringName,
	category: String,
) -> void:
	_assert_false(id.is_empty(), "%s native ID non-empty" % category)
	_assert_false(seen.has(id), "%s native ID does not collide: %s" % [category, id])
	seen[id] = true


func _assert_resource(
	resource: CharacterResourceState,
	expected_current: int,
	expected_effective: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(resource.current, expected_current, "%s current" % label)
	_assert_eq(resource.effective, expected_effective, "%s effective" % label)
	_assert_eq(resource.maximum, expected_maximum, "%s maximum" % label)


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("Expected true: %s" % label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
