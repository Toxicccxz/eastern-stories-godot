extends RefCounted

const OldPineNpcs := preload("res://data/oldpine/oldpine_npc_definitions.gd")
const OldPineSpawns := preload("res://data/oldpine/oldpine_spawn_definitions.gd")
const OldPineWorld := preload("res://data/oldpine/oldpine_world_definitions.gd")
const ScriptedRandom := preload(
	"res://tests/support/scripted_npc_initialization_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_exact_fat_bandit_and_leather_content()
	_test_fat_human_initialization_order_and_derived_state()
	_test_wear_loadout_registers_transfers_then_wears()
	_test_unsupported_armor_preserves_prior_mutation()
	_test_duplicate_slot_preserves_prior_mutation()
	_test_definition_mismatch_preserves_prior_mutation()
	_test_transfer_failure_preserves_registration_only()
	_test_failed_wear_spawn_is_not_exposed_as_live_npc()
	_test_existing_wield_and_none_paths_remain_unchanged()
	_test_independent_npcs_do_not_share_armor_state()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_exact_fat_bandit_and_leather_content() -> void:
	var fat: NpcDefinition = OldPineNpcs.fat_bandit_definition()
	_assert_eq(fat.definition_id, &"oldpine.npc.fat_bandit", "fat native ID")
	_assert_eq(fat.legacy_source_path, "d/oldpine/npc/fat_bandit.c", "fat source")
	_assert_eq(fat.display_name, "土匪", "fat display name")
	_assert_eq(fat.description, "这家伙又矮又胖，圆滚滚的眼珠子在满脸肥肉中骨碌碌地转来转去。\n", "fat description")
	_assert_eq(fat.aliases(), [&"bandit"], "fat alias")
	_assert_eq(fat.gender, CharacterState.GENDER_MALE, "fat gender")
	_assert_eq(fat.age, 36, "fat age")
	_assert_eq(fat.combat_experience, 500, "fat combat experience")
	_assert_eq(fat.score, 80, "fat score")
	_assert_eq(fat.attitude, NpcDefinition.Attitude.AGGRESSIVE, "fat aggressive")
	_assert_true(fat.base_attribute_overrides().is_empty(), "fat has no invented attributes")
	_assert_true(fat.resource_overrides().is_empty(), "fat has no invented resources")
	var skills: Array[NpcSkillLevelDefinition] = fat.skill_levels()
	_assert_eq(skills.size(), 3, "fat exact skill count")
	_assert_skill(skills[0], &"sword", 20, "fat sword")
	_assert_skill(skills[1], &"parry", 10, "fat parry")
	_assert_skill(skills[2], &"dodge", 10, "fat dodge")
	var entries: Array[NpcLoadoutEntry] = fat.loadout_entries()
	_assert_eq(entries.size(), 3, "fat exact loadout count")
	_assert_entry(entries[0], OldPineNpcs.SHORT_SWORD_ITEM_ID, 1, NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY, "fat sword")
	_assert_entry(entries[1], OldPineNpcs.LEATHER_ITEM_ID, 1, NpcLoadoutEntry.EquipmentIntent.WEAR, "fat leather")
	_assert_entry(entries[2], OldPineNpcs.SILVER_ITEM_ID, 5, NpcLoadoutEntry.EquipmentIntent.NONE, "fat silver")
	var leather: NpcLoadoutItemDefinition = OldPineNpcs.leather_content()
	_assert_true(leather != null and leather.is_valid(), "canonical leather loadout content")
	_assert_eq(leather.item_definition().item_definition_id, OldPineNpcs.LEATHER_ITEM_ID, "leather item identity")
	_assert_eq(leather.own_weight, 6000, "leather source weight")
	_assert_eq(leather.legacy_source_paths(), ["d/oldpine/obj/leather.c", "d/oldpine/npc/obj/leather.c"], "both source-equivalent leather paths")
	var armor: ArmorDefinition = leather.armor_definition()
	_assert_eq(armor.armor_type, &"cloth", "leather open slot ID")
	_assert_eq(armor.numeric_modifiers.armor, 5, "leather armor modifier")
	var lpc_weight: int = 6000
	@warning_ignore("integer_division")
	var lpc_dodge: int = -lpc_weight / 3000
	_assert_true(lpc_weight > 3000, "cloth strict source threshold is reached")
	_assert_eq(lpc_dodge, -2, "source contract computes -6000 / 3000 exactly")
	_assert_eq(armor.numeric_modifiers.dodge, lpc_dodge, "authored content matches independent cloth source contract")
	_assert_ne(leather.armor_definition(), leather.armor_definition(), "loadout returns independent ArmorDefinition snapshots")
	_assert_ne(armor.numeric_modifiers, armor.numeric_modifiers, "ArmorDefinition returns independent modifier snapshots")
	var authored: OldPineItemContentDefinition = OldPineItemContentDefinitions.content_by_id(OldPineNpcs.LEATHER_ITEM_ID)
	_assert_eq(authored.display_name, "皮衣", "leather display name")
	_assert_eq(authored.description, "皮衣(Leather)。\n", "leather executable default long")
	_assert_eq(authored.category, OldPineItemContentDefinitions.CATEGORY_ARMOR, "leather armor category")
	var spawn: NpcSpawnDefinition = OldPineSpawns.pine1_fat_bandit_spawn()
	_assert_eq(spawn.quantity, 1, "fat exact spawn quantity")
	_assert_eq(spawn.zone_id, OldPineWorld.PINE_ENTRANCE_ZONE_ID, "fat Pine Entrance placement")


func _test_fat_human_initialization_order_and_derived_state() -> void:
	var random_source: ScriptedNpcInitializationRandomSource = ScriptedRandom.new(
		[0, 20, 1, 19, 2, 18, 3, 17]
	)
	var runtime: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
		OldPineNpcs.fat_bandit_definition(),
		&"fat.rng.character",
		OldPineSpawns.PINE1_FAT_BANDIT_SPAWN_ID,
		&"fat.rng.point",
		WorldLocationState.new(
			OldPineWorld.REGION_ID,
			OldPineWorld.OUTDOOR_MAP_ID,
			OldPineWorld.PINE_ENTRANCE_ZONE_ID,
			OldPineWorld.PINE_ENTRANCE_ZONE_ID,
		),
		InventoryState.new(),
		CombinedStackCollection.new(),
		random_source,
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(runtime != null and runtime.is_valid(), "scripted Fat constructs")
	_assert_eq(runtime.age, 36, "authored Fat age is exact")
	_assert_eq(random_source.call_count(), 8, "authored age consumes zero RNG draws")
	_assert_eq(random_source.requested_bounds(), [21, 21, 21, 21, 21, 21, 21, 21], "Fat uses exact eight human attribute draws")
	var attributes: CharacterBaseAttributes = runtime.character_state.attributes
	_assert_eq(
		[
			attributes.strength, attributes.courage,
			attributes.intelligence, attributes.spirituality,
			attributes.composure, attributes.personality,
			attributes.constitution, attributes.karma,
		],
		[10, 30, 11, 29, 12, 28, 13, 27],
		"Fat preserves closed human attribute order",
	)
	_assert_resource(runtime.character_state.essence, 190, 190, 190, "age 36 gin")
	_assert_resource(runtime.character_state.vitality, 220, 220, 220, "age 36 kee")
	_assert_resource(runtime.character_state.spirit, 130, 130, 130, "age 36 sen")
	_assert_eq(runtime.body_weight, 40000, "strength 10 body weight")
	_assert_eq(runtime.maximum_encumbrance, 50000, "strength 10 capacity")


func _test_wear_loadout_registers_transfers_then_wears() -> void:
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var runtime: NpcRuntimeState = _create(
		OldPineNpcs.fat_bandit_definition(),
		&"fat.factory.character",
		inventory,
		stacks,
		OldPineNpcs.loadout_item_definitions(),
	)
	_assert_true(runtime != null and runtime.is_valid(), "fat factory succeeds")
	var items: Array[ItemInstance] = runtime.loadout_items()
	_assert_eq(items.size(), 3, "fat owns three live item objects")
	var sword: ItemInstance = _item_by_definition(items, OldPineNpcs.SHORT_SWORD_ITEM_ID)
	var leather: ItemInstance = _item_by_definition(items, OldPineNpcs.LEATHER_ITEM_ID)
	var silver: ItemInstance = _item_by_definition(items, OldPineNpcs.SILVER_ITEM_ID)
	var owner: ContainmentEndpoint = _owner(runtime.character_id)
	_assert_true(inventory.is_direct_child(sword.item_instance_id, owner), "sword transferred before equip")
	_assert_true(inventory.is_direct_child(leather.item_instance_id, owner), "leather remains direct inventory while worn")
	_assert_true(inventory.is_direct_child(silver.item_instance_id, owner), "silver transferred")
	_assert_eq(runtime.character_state.equipment.primary_weapon().instance_id, sword.item_instance_id, "fat exact short-sword primary")
	_assert_eq(runtime.armor.item_instance_id_in_slot(&"cloth"), leather.item_instance_id, "fat exact leather occupies cloth")
	_assert_eq(runtime.armor.aggregate_numeric_modifiers().armor, 5, "fat live armor aggregate")
	_assert_eq(runtime.armor.aggregate_numeric_modifiers().dodge, -2, "fat live dodge aggregate")
	_assert_eq(stacks.stack_state(silver.item_instance_id).amount, 5, "fat silver is one amount-five stack")
	_assert_eq(inventory.own_weight(silver.item_instance_id), 185, "fat silver weight 5 * 37")
	_assert_eq(OldPineNpcs.silver_content().currency_definition().value_for_amount(5), 500, "fat silver value 5 * 100")


func _test_unsupported_armor_preserves_prior_mutation() -> void:
	var inventory: InventoryState = InventoryState.new()
	var definition_id: StringName = &"test:unsupported-wear"
	var definition: NpcDefinition = _definition_with_entries([
		NpcLoadoutEntry.new(definition_id, 1, NpcLoadoutEntry.EquipmentIntent.WEAR, "test/unsupported.c"),
	])
	var content: NpcLoadoutItemDefinition = NpcLoadoutItemDefinition.new(
		ItemDefinition.new(definition_id, "test/unsupported.c"), 1, null, 0, null, null, ["test/unsupported.c"]
	)
	var runtime: NpcRuntimeState = _create(definition, &"unsupported.character", inventory, CombinedStackCollection.new(), [content])
	_assert_true(runtime == null, "WEAR without ArmorDefinition fails construction")
	var item_id: StringName = &"unsupported.character.loadout.0.0"
	_assert_true(inventory.is_registered(item_id), "unsupported item remains registered")
	_assert_true(inventory.is_direct_child(item_id, _owner(&"unsupported.character")), "unsupported item remains transferred")


func _test_duplicate_slot_preserves_prior_mutation() -> void:
	var inventory: InventoryState = InventoryState.new()
	var first_id: StringName = &"test:first-cloth"
	var second_id: StringName = &"test:second-cloth"
	var definition: NpcDefinition = _definition_with_entries([
		NpcLoadoutEntry.new(first_id, 1, NpcLoadoutEntry.EquipmentIntent.WEAR, "test/first.c"),
		NpcLoadoutEntry.new(second_id, 1, NpcLoadoutEntry.EquipmentIntent.WEAR, "test/second.c"),
	])
	var content: Array[NpcLoadoutItemDefinition] = [
		_armor_content(first_id, &"cloth", 10, "test/first.c"),
		_armor_content(second_id, &"cloth", 20, "test/second.c"),
	]
	var runtime: NpcRuntimeState = _create(definition, &"duplicate.character", inventory, CombinedStackCollection.new(), content)
	_assert_true(runtime == null, "duplicate cloth slot fails construction")
	for index: int in range(2):
		var item_id: StringName = StringName("duplicate.character.loadout.%d.0" % index)
		_assert_true(inventory.is_registered(item_id), "duplicate slot item %d remains registered" % index)
		_assert_true(inventory.is_direct_child(item_id, _owner(&"duplicate.character")), "duplicate slot item %d remains transferred" % index)


func _test_definition_mismatch_preserves_prior_mutation() -> void:
	var inventory: InventoryState = InventoryState.new()
	var item_id: StringName = &"test:mismatch-item"
	var content: NpcLoadoutItemDefinition = NpcLoadoutItemDefinition.new(
		ItemDefinition.new(item_id, "test/mismatch.c"),
		1,
		null,
		0,
		null,
		null,
		["test/mismatch.c"],
		ArmorDefinition.new(&"test:other-definition", &"cloth", ArmorNumericModifiers.new(1)),
	)
	_assert_true(content.is_valid(), "mismatch fixture reaches ordered factory identity check")
	var runtime: NpcRuntimeState = _create(
		_definition_with_entries([NpcLoadoutEntry.new(item_id, 1, NpcLoadoutEntry.EquipmentIntent.WEAR, "test/mismatch.c")]),
		&"mismatch.character",
		inventory,
		CombinedStackCollection.new(),
		[content],
	)
	_assert_true(runtime == null, "armor/item identity mismatch fails construction")
	var instance_id: StringName = &"mismatch.character.loadout.0.0"
	_assert_true(inventory.is_registered(instance_id), "mismatch item remains registered")
	_assert_true(inventory.is_direct_child(instance_id, _owner(&"mismatch.character")), "mismatch item remains transferred")


func _test_transfer_failure_preserves_registration_only() -> void:
	var inventory: InventoryState = InventoryState.new()
	var definition_id: StringName = &"test:over-capacity-armor"
	var runtime: NpcRuntimeState = _create(
		_definition_with_entries([NpcLoadoutEntry.new(definition_id, 1, NpcLoadoutEntry.EquipmentIntent.WEAR, "test/heavy.c")]),
		&"heavy.character",
		inventory,
		CombinedStackCollection.new(),
		[_armor_content(definition_id, &"cloth", 60000, "test/heavy.c")],
	)
	_assert_true(runtime == null, "capacity rejection fails construction")
	var instance_id: StringName = &"heavy.character.loadout.0.0"
	_assert_true(inventory.is_registered(instance_id), "transfer failure preserves registration")
	_assert_true(inventory.direct_parent(instance_id) == null, "transfer failure leaves item without a parent")


func _test_failed_wear_spawn_is_not_exposed_as_live_npc() -> void:
	var definition_id: StringName = &"test:failed-live-wear"
	var definition: NpcDefinition = _definition_with_entries([
		NpcLoadoutEntry.new(
			definition_id,
			1,
			NpcLoadoutEntry.EquipmentIntent.WEAR,
			"test/failed-live-wear.c",
		),
	])
	var spawn: NpcSpawnDefinition = NpcSpawnDefinition.new(
		&"test.failed-live-wear.spawn",
		definition.definition_id,
		OldPineWorld.OUTDOOR_MAP_ID,
		OldPineWorld.PINE_ENTRANCE_ZONE_ID,
		[&"test.failed-live-wear.point"],
		1,
		"test/room.c",
		1,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)
	var inventory: InventoryState = InventoryState.new()
	var created: Array[NpcRuntimeState] = (
		NpcCharacterStateFactory.new().create_spawn_instances(
			spawn,
			definition,
			WorldLocationState.new(
				OldPineWorld.REGION_ID,
				OldPineWorld.OUTDOOR_MAP_ID,
				OldPineWorld.PINE_ENTRANCE_ZONE_ID,
				OldPineWorld.PINE_ENTRANCE_ZONE_ID,
			),
			inventory,
			CombinedStackCollection.new(),
			ScriptedRandom.new([0, 0, 0, 0, 0, 0, 0, 0]),
			[
				NpcLoadoutItemDefinition.new(
					ItemDefinition.new(definition_id, "test/failed-live-wear.c"),
					1,
					null,
					0,
					null,
					null,
					["test/failed-live-wear.c"],
				),
			],
		)
	)
	var collection: MapCharacterRuntimeState = MapCharacterRuntimeState.new(
		OldPineWorld.OUTDOOR_MAP_ID
	)
	for runtime: NpcRuntimeState in created:
		collection.register_npc(runtime)
	_assert_true(created.is_empty(), "failed WEAR spawn construction returns no runtime")
	_assert_eq(collection.size(), 0, "caller cannot expose a failed WEAR runtime as live NPC")
	var partial_item_id: StringName = &"test.failed-live-wear.point.character.loadout.0.0"
	_assert_true(inventory.is_registered(partial_item_id), "failed construction retains honest partial item registration")
	_assert_true(inventory.is_direct_child(partial_item_id, _owner(&"test.failed-live-wear.point.character")), "failed construction retains honest partial direct ownership")


func _test_existing_wield_and_none_paths_remain_unchanged() -> void:
	for fixture: Array[Variant] in [
		[OldPineNpcs.bandit_definition(), &"regression.bandit", OldPineNpcs.SHORT_SWORD_ITEM_ID, 3],
		[OldPineNpcs.tall_bandit_definition(), &"regression.tall", OldPineNpcs.LONG_SWORD_ITEM_ID, 6],
	]:
		var inventory: InventoryState = InventoryState.new()
		var stacks: CombinedStackCollection = CombinedStackCollection.new()
		var runtime: NpcRuntimeState = _create(fixture[0], fixture[1], inventory, stacks, OldPineNpcs.loadout_item_definitions())
		_assert_true(runtime != null, "closed NPC factory path still succeeds")
		_assert_eq(runtime.loadout_items().size(), 2, "closed NPC still owns two objects")
		_assert_eq(runtime.character_state.equipment.primary_weapon().weapon_id, fixture[2], "closed NPC primary definition unchanged")
		_assert_true(runtime.armor.occupied_slots().is_empty(), "closed NPC gains no armor")
		var silver: ItemInstance = _item_by_definition(runtime.loadout_items(), OldPineNpcs.SILVER_ITEM_ID)
		_assert_eq(stacks.stack_state(silver.item_instance_id).amount, fixture[3], "closed NPC silver amount unchanged")


func _test_independent_npcs_do_not_share_armor_state() -> void:
	var first: NpcRuntimeState = _create(OldPineNpcs.fat_bandit_definition(), &"independent.first", InventoryState.new(), CombinedStackCollection.new(), OldPineNpcs.loadout_item_definitions())
	var second: NpcRuntimeState = _create(OldPineNpcs.fat_bandit_definition(), &"independent.second", InventoryState.new(), CombinedStackCollection.new(), OldPineNpcs.loadout_item_definitions())
	var first_leather: StringName = first.armor.item_instance_id_in_slot(&"cloth")
	var second_leather: StringName = second.armor.item_instance_id_in_slot(&"cloth")
	_assert_ne(first_leather, second_leather, "fat leather instances are unique")
	_assert_true(first.armor.remove(first_leather).succeeded, "first armor can be removed")
	_assert_false(first.armor.is_slot_occupied(&"cloth"), "first cloth slot is empty")
	_assert_eq(second.armor.item_instance_id_in_slot(&"cloth"), second_leather, "second cloth slot remains independent")


func _create(
	definition: NpcDefinition,
	character_id: StringName,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	content: Array[NpcLoadoutItemDefinition],
) -> NpcRuntimeState:
	return NpcCharacterStateFactory.new().create_one(
		definition,
		character_id,
		&"test.spawn",
		&"test.point",
		WorldLocationState.new(OldPineWorld.REGION_ID, OldPineWorld.OUTDOOR_MAP_ID, OldPineWorld.PINE_ENTRANCE_ZONE_ID, OldPineWorld.PINE_ENTRANCE_ZONE_ID),
		inventory,
		stacks,
		ScriptedRandom.new([0, 0, 0, 0, 0, 0, 0, 0]),
		content,
	)


func _definition_with_entries(entries: Array[NpcLoadoutEntry]) -> NpcDefinition:
	return NpcDefinition.new(
		&"test.npc.wear",
		"test/npc.c",
		"测试对象",
		[&"test"],
		NpcCharacterStateFactory.HUMAN_RACE_ID,
		true,
		CharacterState.GENDER_MALE,
		true,
		20,
		NpcBaseAttributeOverrides.new(),
		NpcResourceOverrides.new(),
		0,
		0,
		NpcDefinition.Attitude.PEACEFUL,
		[],
		entries,
	)


func _armor_content(
	definition_id: StringName,
	slot: StringName,
	weight: int,
	source: String,
) -> NpcLoadoutItemDefinition:
	return NpcLoadoutItemDefinition.new(
		ItemDefinition.new(definition_id, source),
		weight,
		null,
		0,
		null,
		null,
		[source],
		ArmorDefinition.new(definition_id, slot, ArmorNumericModifiers.new(1)),
	)


func _owner(character_id: StringName) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)


func _item_by_definition(items: Array[ItemInstance], definition_id: StringName) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _assert_skill(skill: NpcSkillLevelDefinition, skill_id: StringName, level: int, label: String) -> void:
	_assert_eq(skill.skill_id, skill_id, "%s ID" % label)
	_assert_eq(skill.raw_level, level, "%s level" % label)


func _assert_entry(entry: NpcLoadoutEntry, definition_id: StringName, quantity: int, intent: int, label: String) -> void:
	_assert_eq(entry.item_definition_id, definition_id, "%s definition" % label)
	_assert_eq(entry.quantity, quantity, "%s quantity" % label)
	_assert_eq(entry.equipment_intent, intent, "%s intent" % label)


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (actual=%s expected=%s)" % [label, actual, expected])


func _assert_ne(actual: Variant, unexpected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("%s (unexpected=%s)" % [label, unexpected])


func _assert_resource(
	resource: CharacterResourceState,
	current: int,
	effective: int,
	maximum: int,
	label: String,
) -> void:
	_assert_eq(resource.current, current, "%s current" % label)
	_assert_eq(resource.effective, effective, "%s effective" % label)
	_assert_eq(resource.maximum, maximum, "%s maximum" % label)
