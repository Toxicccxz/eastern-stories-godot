extends RefCounted

## Temporary: proves the JSON content equals the hand-written GDScript
## definitions it replaces. Deleted together with those definitions.
var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_eq(GameContent.load_errors(), [], "shipped content loads without errors")
	_test_items()
	_test_loadout_content()
	_test_projections()
	_test_currency_and_values()
	_test_npcs()
	_test_spawns()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_items() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_eq(catalog.items().size(), 9, "nine authored items")
	for id: StringName in [
		OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
		OldPineItemContentDefinitions.SILVER_ITEM_ID,
		OldPineItemContentDefinitions.LEATHER_ITEM_ID,
		SourcePlayerCloth.DEFINITION_ID,
		SourceDumpling.DEFINITION_ID,
		SourceWineskin.DEFINITION_ID,
		SourceCoin.DEFINITION_ID,
		SourceGold.DEFINITION_ID,
	]:
		var old: OldPineItemContentDefinition = PlayerItemContentDefinitions.content(id)
		var now: ItemContentDefinition = catalog.item(id)
		_eq(now != null and now.is_valid(), true, "%s exists" % id)
		if now == null:
			continue
		_eq(now.item_definition_id, old.item_definition_id, "%s id" % id)
		_eq(now.display_name, old.display_name, "%s name" % id)
		# Coin and gold used their name as a placeholder description.
		if id not in [SourceCoin.DEFINITION_ID, SourceGold.DEFINITION_ID]:
			_eq(now.description.strip_edges(), old.description.strip_edges(), "%s description" % id)
		_eq(now.category, old.category, "%s category" % id)
		_eq(now.own_weight, old.own_weight, "%s weight" % id)
		_eq(now.weapon_skill_type, old.weapon_skill_type, "%s weapon skill" % id)
		_eq(now.weapon_damage, old.weapon_damage, "%s weapon damage" % id)
		_eq(now.can_wield_secondary, old.can_wield_secondary, "%s secondary" % id)
		_eq(now.is_two_handed, old.is_two_handed, "%s two handed" % id)
		_eq(now.is_stack, old.is_stack, "%s stack" % id)
		_eq(now.stack_base_weight, old.stack_base_weight, "%s stack weight" % id)
		_eq(now.currency_base_value, old.currency_base_value, "%s currency value" % id)
		_eq(now.legacy_source_paths()[0], old.legacy_source_paths()[0], "%s source" % id)
		_same_armor(now.armor_definition(), old.armor_definition(), "%s armor" % id)


func _test_loadout_content() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for old: NpcLoadoutItemDefinition in OldPineNpcDefinitions.loadout_item_definitions():
		var id: StringName = old.item_definition().item_definition_id
		var now: NpcLoadoutItemDefinition = catalog.item(id).loadout_item_definition()
		_eq(now.is_valid(), true, "%s loadout valid" % id)
		_eq(now.item_definition().legacy_source_path, old.item_definition().legacy_source_path, "%s loadout source" % id)
		_eq(now.own_weight, old.own_weight, "%s loadout weight" % id)
		_eq(now.weapon_damage, old.weapon_damage, "%s loadout damage" % id)
		_same_weapon(now.weapon_definition(), old.weapon_definition(), "%s loadout weapon" % id)
		_same_stack(now.stack_definition(), old.stack_definition(), "%s loadout stack" % id)
		_eq(now.currency_definition() == null, old.currency_definition() == null, "%s loadout currency role" % id)
		if old.currency_definition() != null and now.currency_definition() != null:
			_eq(now.currency_definition().base_value, old.currency_definition().base_value, "%s loadout currency" % id)
		_same_armor(now.armor_definition(), old.armor_definition(), "%s loadout armor" % id)
	_eq(catalog.loadout_item_definitions().size(), 9, "every item is available as loadout content")


func _test_projections() -> void:
	var old: NativeItemDefinitionProjections = OldPineNativeItemDefinitionProjections.create(WorldContentRevision.CURRENT_PUBLIC)
	var now: NativeItemDefinitionProjections = GameContent.catalog().native_item_projections()
	_eq(now.is_valid, true, "projections valid")
	var ids: Array[StringName] = [OldPineNativeItemDefinitionProjections.CORPSE_DEFINITION_ID]
	for item: ItemContentDefinition in GameContent.catalog().items():
		ids.append(item.item_definition_id)
	for id: StringName in ids:
		_eq(now.has_item_definition(id) and old.has_item_definition(id), true, "%s projected" % id)
		_eq(now.item_definition(id).legacy_source_path, old.item_definition(id).legacy_source_path, "%s projected source" % id)
		_same_weapon(now.weapon_definition(id), old.weapon_definition(id), "%s projected weapon" % id)
		_same_armor(now.armor_definition(id), old.armor_definition(id), "%s projected armor" % id)
		_same_stack(now.stack_definition(id), old.stack_definition(id), "%s projected stack" % id)
		var old_food: FoodDefinition = old.food_definition(id)
		var new_food: FoodDefinition = now.food_definition(id)
		_eq(new_food == null, old_food == null, "%s food role" % id)
		if old_food != null and new_food != null:
			_eq([new_food.initial_portions, new_food.food_supply, new_food.initial_value, new_food.own_weight],
				[old_food.initial_portions, old_food.food_supply, old_food.initial_value, old_food.own_weight], "%s food" % id)
		var old_liquid: LiquidDefinition = old.liquid_definition(id)
		var new_liquid: LiquidDefinition = now.liquid_definition(id)
		_eq(new_liquid == null, old_liquid == null, "%s liquid role" % id)
		if new_liquid != null:
			_eq(SourceWineskin.is_canonical(new_liquid), true, "%s liquid canonical" % id)
	var wineskin: ItemContentDefinition = GameContent.catalog().item(SourceWineskin.DEFINITION_ID)
	_eq([wineskin.fresh_liquid_state().content, wineskin.fresh_liquid_state().remaining],
		[SourceWineskin.fresh_state().content, SourceWineskin.fresh_state().remaining], "fresh wineskin state")
	_eq(wineskin.liquid_initial_name, SourceWineskin.content_name(LiquidState.Content.RED_WINE), "fresh wineskin liquid name")
	_eq([wineskin.unit, wineskin.aliases()], [SourceWineskin.UNIT, SourceWineskin.ALIASES], "wineskin unit and aliases")
	var dumpling: ItemContentDefinition = GameContent.catalog().item(SourceDumpling.DEFINITION_ID)
	_eq([dumpling.unit, dumpling.aliases(), dumpling.value], [SourceDumpling.UNIT, [SourceDumpling.ALIAS], SourceDumpling.VALUE], "dumpling facts")


func _test_currency_and_values() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.COIN, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.GOLD]:
		var old: GDScript = SourceCurrencyDefinitions.source(denomination)
		var now: ItemContentDefinition = catalog.currency_item(denomination)
		_eq(now != null, true, "denomination %d resolves" % denomination)
		if now == null:
			continue
		_eq(now.item_definition_id, old.DEFINITION_ID, "denomination %d id" % denomination)
		_eq(catalog.denomination_of(old.DEFINITION_ID), denomination, "denomination %d identify" % denomination)
		_eq([now.display_name, now.base_unit, now.money_id, now.currency_base_value, now.stack_base_weight],
			[old.DISPLAY_NAME, old.BASE_UNIT, old.MONEY_ID, old.BASE_VALUE, old.BASE_WEIGHT], "denomination %d facts" % denomination)
		_same_stack(now.stack_definition(), old.stack_definition(), "denomination %d stack" % denomination)
	_eq(catalog.denomination_of(SourceDumpling.DEFINITION_ID), CurrencyDenomination.Value.UNSUPPORTED, "goods are not money")
	for id: StringName in HockshopStaticValues.VALUES:
		_eq(catalog.item(id).value, HockshopStaticValues.VALUES[id], "%s hockshop value" % id)
	_eq(catalog.item(SourceWineskin.DEFINITION_ID).value, SourceWineskin.VALUE, "wineskin value")


func _test_npcs() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_eq(catalog.npcs().size(), 4, "four authored NPCs")
	for id: StringName in [
		OldPineNpcDefinitions.BANDIT_DEFINITION_ID,
		OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID,
		OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID,
		OldPineNpcDefinitions.SERPENT_DEFINITION_ID,
	]:
		var old: NpcDefinition = OldPineNpcDefinitions.npc_by_id(id)
		var now: NpcDefinition = catalog.npc(id)
		_eq(now != null and now.is_valid(), true, "%s exists" % id)
		if now == null:
			continue
		_eq([now.definition_id, now.legacy_source_path, now.display_name, now.description],
			[old.definition_id, old.legacy_source_path, old.display_name, old.description], "%s identity" % id)
		_eq([now.aliases(), now.race_id, now.has_authored_gender, now.gender, now.has_authored_age, now.age],
			[old.aliases(), old.race_id, old.has_authored_gender, old.gender, old.has_authored_age, old.age], "%s body" % id)
		_eq([now.combat_experience, now.score, now.attitude, now.capability_ids()],
			[old.combat_experience, old.score, old.attitude, old.capability_ids()], "%s disposition" % id)
		_eq(_attributes(now), _attributes(old), "%s attributes" % id)
		_eq(_resources(now), _resources(old), "%s resources" % id)
		_eq(_skills(now), _skills(old), "%s skills" % id)
		_eq(_loadout(now), _loadout(old), "%s loadout" % id)
		_eq(_combat_facts(now), _combat_facts(old), "%s combat facts" % id)


func _test_spawns() -> void:
	var old_spawns: Array[NpcSpawnDefinition] = OldPineSpawnDefinitions.all_spawns()
	var new_spawns: Array[NpcSpawnDefinition] = GameContent.catalog().spawns()
	_eq(new_spawns.size(), old_spawns.size(), "spawn count")
	for index: int in range(mini(old_spawns.size(), new_spawns.size())):
		var old: NpcSpawnDefinition = old_spawns[index]
		var now: NpcSpawnDefinition = new_spawns[index]
		_eq(now.is_valid(), true, "spawn %d valid" % index)
		_eq([now.spawn_id, now.npc_definition_id, now.map_id, now.zone_id, now.spawn_point_ids(), now.quantity, now.legacy_source_room_path, now.legacy_quantity, now.initial_spawn_policy],
			[old.spawn_id, old.npc_definition_id, old.map_id, old.zone_id, old.spawn_point_ids(), old.quantity, old.legacy_source_room_path, old.legacy_quantity, old.initial_spawn_policy], "spawn %d facts and order" % index)
	_eq(GameContent.catalog().spawns_for_map(OldPineWorldDefinitions.OUTDOOR_MAP_ID).size(), 4, "outdoor spawns")
	_eq(GameContent.catalog().spawns_for_map(OldPineWorldDefinitions.CAVE_MAP_ID).size(), 0, "cave has no spawns")


func _attributes(definition: NpcDefinition) -> Array:
	var a: NpcBaseAttributeOverrides = definition.base_attribute_overrides()
	return [
		a.has_strength(), a.strength(), a.has_courage(), a.courage(),
		a.has_intelligence(), a.intelligence(), a.has_spirituality(), a.spirituality(),
		a.has_composure(), a.composure(), a.has_personality(), a.personality(),
		a.has_constitution(), a.constitution(), a.has_karma(), a.karma(),
	]


func _resources(definition: NpcDefinition) -> Array:
	var result: Array = []
	var overrides: NpcResourceOverrides = definition.resource_overrides()
	for track: NpcResourceTrackOverride in [overrides.essence(), overrides.vitality(), overrides.spirit()]:
		result.append([track.has_current(), track.current(), track.has_effective(), track.effective(), track.has_maximum(), track.maximum()])
	return result


func _skills(definition: NpcDefinition) -> Array:
	var result: Array = []
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		result.append([skill.skill_id, skill.raw_level])
	return result


func _loadout(definition: NpcDefinition) -> Array:
	var result: Array = []
	for entry: NpcLoadoutEntry in definition.loadout_entries():
		result.append([entry.item_definition_id, entry.quantity, entry.equipment_intent, entry.legacy_source_path])
	return result


func _combat_facts(definition: NpcDefinition) -> Array:
	var facts: NpcAuthoredCombatFacts = definition.authored_combat_facts()
	if facts == null:
		return []
	return [facts.limbs(), facts.verbs(), facts.intrinsic_attack, facts.intrinsic_damage, facts.intrinsic_armor, facts.intrinsic_dodge]


func _same_weapon(now: WeaponDefinition, old: WeaponDefinition, label: String) -> void:
	_eq(now == null, old == null, label + " role")
	if now != null and old != null:
		_eq([now.weapon_id, now.skill_type, now.can_wield_as_secondary, now.is_two_handed, now.legacy_source_path],
			[old.weapon_id, old.skill_type, old.can_wield_as_secondary, old.is_two_handed, old.legacy_source_path], label)


func _same_stack(now: CombinedStackDefinition, old: CombinedStackDefinition, label: String) -> void:
	_eq(now == null, old == null, label + " role")
	if now != null and old != null:
		_eq([now.item_definition_id, now.stack_compatibility_id, now.base_weight],
			[old.item_definition_id, old.stack_compatibility_id, old.base_weight], label)


func _same_armor(now: ArmorDefinition, old: ArmorDefinition, label: String) -> void:
	_eq(now == null, old == null, label + " role")
	if now == null or old == null:
		return
	var a: ArmorNumericModifiers = now.numeric_modifiers
	var b: ArmorNumericModifiers = old.numeric_modifiers
	_eq([now.item_definition_id, now.armor_type, a.armor, a.armor_vs_force, a.attack, a.defense, a.dodge, a.composure, a.courage, a.intelligence, a.karma, a.personality, a.magic, a.move, a.spells, a.unarmed],
		[old.item_definition_id, old.armor_type, b.armor, b.armor_vs_force, b.attack, b.defense, b.dodge, b.composure, b.courage, b.intelligence, b.karma, b.personality, b.magic, b.move, b.spells, b.unarmed], label)


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
