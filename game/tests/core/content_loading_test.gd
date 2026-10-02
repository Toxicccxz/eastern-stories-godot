extends RefCounted

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_shipped_content_loads()
	_test_record_reader_reports_problems()
	_test_item_derived_facts()
	_test_item_record_errors()
	_test_npc_and_spawn_records()
	_test_cross_reference_checks()
	_test_missing_files_fail_closed()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_shipped_content_loads() -> void:
	_eq(GameContent.load_errors(), [], "shipped content has no errors")
	var catalog: ContentCatalog = GameContent.catalog()
	_eq(catalog.items().is_empty() or catalog.npcs().is_empty() or catalog.spawns().is_empty() or catalog.vendors().is_empty(), false, "every content kind is present")
	for item: ItemContentDefinition in catalog.items():
		_eq(item.is_valid(), true, "%s is valid" % item.item_definition_id)
	_eq(catalog.native_item_projections().is_valid, true, "item role projections are consistent")
	_eq(catalog.native_item_projections().has_item_definition(CorpseState.ITEM_DEFINITION_ID), true, "rule-created corpse item is projected")
	_eq(catalog.item(CorpseState.ITEM_DEFINITION_ID), null, "corpse is not authored content")
	_eq(catalog.item(&"es2:not/there"), null, "unknown item is null")
	_eq(catalog.denomination_of(&"es2:obj/money/silver"), CurrencyDenomination.Value.SILVER, "silver denomination")
	_eq(catalog.currency_item(CurrencyDenomination.Value.GOLD).currency_base_value, 10000, "gold base value")
	# NPC creation order fixes random draws and loadout item identities.
	var spawn_ids: Array[StringName] = []
	for spawn: NpcSpawnDefinition in catalog.spawns():
		spawn_ids.append(spawn.spawn_id)
	_eq(spawn_ids, [
		&"oldpine.outdoor.spath1.bandits", &"oldpine.outdoor.pine1.tall_bandit", &"oldpine.outdoor.pine1.fat_bandit", &"oldpine.gorge.lake.serpents",
		&"snow.inn.travellers", &"snow.outdoor.eroad2.dogs", &"snow.outdoor.temple.keeper", &"snow.outdoor.mstreet2.drunk",
		&"snow.outdoor.mstreet2.scavenger", &"snow.outdoor.school1.guard", &"snow.outdoor.school2.trainees", &"snow.outdoor.school2.fist_trainer",
		&"snow.outdoor.sroad2.farmers", &"snow.outdoor.sroad4.crazy_dog", &"snow.outdoor.school.teacher",
		&"snow.outdoor.herbshop.woodcutter", &"snow.outdoor.postoffice.post_officer", &"snow.inn_upstairs.inn_2f.rats",
	], "spawn order is the authored order (manifest, then file)")
	var waiter: VendorDefinition = catalog.vendor(&"snow.vendor.waiter")
	_eq(waiter.goods_keys(), ["wineskin", "dumpling"], "waiter goods in vendor_goods order")
	# Imported Snow facts (tools/migration/content_importer.py).
	var guard: NpcDefinition = catalog.npc(&"snow.npc.guard")
	_eq([guard.title, guard.short_name(), guard.attitude], ["门房", "门房 刘安禄", NpcDefinition.Attitude.HEROISM], "set(\"title\") and heroism")
	var trainer: NpcDefinition = catalog.npc(&"snow.npc.fist_trainer")
	_eq(trainer.skill_map(), {&"unarmed": &"liuh-ken"}, "map_skill(unarmed, liuh-ken)")
	var traveller: NpcDefinition = catalog.npc(&"snow.npc.traveller")
	_eq([traveller.gender_roll() != null, traveller.age_roll().base, traveller.combat_experience_roll().base, traveller.score_roll().base], [true, 15, 600, 5], "create()-time draws are rules, not values")
	_eq([catalog.zone_forbids_fighting(&"snow.temple"), catalog.zone_forbids_fighting(&"snow.workplace"), catalog.zone_forbids_fighting(&"snow.square")], [true, true, false], "no_fight rooms: temple and workplace")
	_eq(waiter.item_definition_id("dumpling"), &"es2:obj/example/dumpling", "goods key resolves to its item")
	_eq(waiter.item_definition_id("dagger"), &"", "unsold goods key is empty")
	# feature/vendor.c charges the item's value; smith.c's own buy_object() asks 300 for a hammer worth 3.
	var herbalist: VendorDefinition = catalog.vendor(&"snow.vendor.herbalist")
	var medicine: ItemContentDefinition = catalog.item(&"es2:obj/drug/hurt_drug")
	_eq([herbalist.goods_keys(), herbalist.price("medicine", medicine)], [["medicine"], 2000], "herbalist sells medicine at its value; snake drug waits")
	var smith: VendorDefinition = catalog.vendor(&"snow.vendor.smith")
	var hammer: ItemContentDefinition = catalog.item(smith.item_definition_id("铁锤"))
	_eq([hammer.value, smith.price("铁锤", hammer), waiter.price("dumpling", catalog.item(&"es2:obj/example/dumpling"))], [3, 300, 15], "a vendor's own price replaces the value")


func _test_record_reader_reports_problems() -> void:
	var errors: Array[String] = []
	var reader: ContentRecordReader = ContentRecordReader.new(
		{"name": 5, "weight": 1.5, "count": 3.0, "tags": ["a", 2], "typo": true}, "file.items[0]", errors,
	)
	_eq(reader.required_text("id"), "", "missing required text reads empty")
	_eq(reader.text("name", "fallback"), "fallback", "wrong type falls back")
	_eq(reader.integer("weight", 7), 7, "fractional number is not an integer")
	_eq(reader.integer("count"), 3, "integral JSON number is accepted")
	_eq(reader.text_list("tags"), ["a"], "non-string list entries are dropped")
	reader.finish()
	_eq(errors, [
		"file.items[0].id: is required",
		"file.items[0].name: expected a string",
		"file.items[0].weight: expected an integer",
		"file.items[0].tags[1]: expected a non-empty string",
		"file.items[0].typo: unknown field",
	], "every problem is reported with its path")


func _test_item_derived_facts() -> void:
	var errors: Array[String] = []
	var leather: ItemContentDefinition = _item({"id": "t:leather", "legacy_sources": ["t/leather.c"], "name": "皮衣", "aliases": ["leather"], "weight": 6000, "armor": {"type": "cloth", "props": {"armor": 5, "dodge": 9}}}, errors)
	_eq(leather.description, "皮衣(Leather)。\n", "feature/name.c default long")
	_eq(leather.armor_definition().numeric_modifiers.dodge, -2, "cloth.c setup overrides dodge with -weight/3000")
	_eq(leather.category, ItemContentDefinition.CATEGORY_ARMOR, "armor category")
	var light: ItemContentDefinition = _item({"id": "t:cloth", "legacy_sources": ["t/cloth.c"], "name": "布衣", "aliases": ["cloth"], "weight": 3000, "armor": {"type": "cloth", "props": {"armor": 1}}}, errors)
	_eq(light.armor_definition().numeric_modifiers.dodge, 0, "cloth at exactly 3000 has no dodge penalty")
	var shield: ItemContentDefinition = _item({"id": "t:shield", "legacy_sources": ["t/shield.c"], "name": "盾", "aliases": ["shield"], "weight": 7000, "armor": {"type": "shield", "props": {"armor": 5, "defense": 3}}}, errors)
	_eq([shield.armor_definition().numeric_modifiers.dodge, shield.armor_definition().numeric_modifiers.defense], [0, 3], "the cloth rule applies to cloth only")
	var money: ItemContentDefinition = _item({"id": "t:silver", "legacy_sources": ["obj/money/silver.c"], "name": "银子", "aliases": ["silver"], "money": {"money_id": "silver", "base_value": 100, "base_unit": "两", "base_weight": 37}}, errors)
	_eq([money.own_weight, money.is_stack, money.category, money.stack_definition().stack_compatibility_id], [37, true, ItemContentDefinition.CATEGORY_CURRENCY, &"/obj/money/silver"], "money derives weight and merge key")
	var sword: ItemContentDefinition = _item({"id": "t:sword", "legacy_sources": ["t/sword.c"], "name": "剑", "aliases": ["sword"], "weight": 1, "weapon": {"skill": "sword", "damage": 15, "flags": ["secondary"]}}, errors)
	_eq([sword.weapon_skill_type, sword.weapon_damage, sword.can_wield_secondary, sword.is_two_handed, sword.value], [&"sword", 15, true, false, 0], "weapon facts; unset value is 0")
	var skin: ItemContentDefinition = _item({"id": "t:skin", "legacy_sources": ["t/skin.c"], "name": "水袋", "aliases": ["skin"], "weight": 700, "value": 20, "liquid": {"max_liquid": 15, "type": "water", "name": "清水", "remaining": 4}}, errors)
	_eq([skin.liquid_definition().hydration, skin.fresh_liquid_state().content, skin.fresh_liquid_state().remaining], [30, LiquidState.Content.CLEAR_WATER, 4], "liquid.c hydration and authored initial contents")
	_eq(errors, [], "valid item records report nothing")


func _test_item_record_errors() -> void:
	var errors: Array[String] = []
	_item({"id": "t:bad", "legacy_sources": [], "name": "坏", "weight": -1, "value": -5, "weapon": {"skill": "sword", "damage": 1, "flags": ["flying"]}, "liquid": {"max_liquid": 5, "type": "oil", "name": "油", "remaining": 9}, "food": {"remaining": 0, "supply": 10}}, errors)
	for expected: String in [
		"t.items[0].legacy_sources: needs at least one LPC source path",
		"t.items[0].value: must not be negative",
		"t.items[0].weight: must not be negative",
		"t.items[0].long: needs either long or an alias for the default description",
		"t.items[0].weapon.flags: unsupported weapon flag 'flying'",
		"t.items[0].food: remaining and supply must be positive",
		"t.items[0].liquid.type: unsupported liquid type 'oil'",
		"t.items[0].liquid: max_liquid must be positive and remaining within it",
		"t.items[0].food: food that is also a weapon, armor or money is not supported yet",
	]:
		_eq(errors.has(expected), true, "reports: " + expected)
	_eq(errors.size(), 9, "and nothing else: %s" % str(errors))


func _test_npc_and_spawn_records() -> void:
	var errors: Array[String] = []
	var npc: NpcDefinition = NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.npc", "legacy_source": "t/npc.c", "name": "人", "aliases": ["man"], "age": 30,
		"resources": {"kee": 50, "eff_kee": 60, "max_kee": 70}, "attributes": {"cps": 12},
		"skills": {"parry": 5, "dodge": 3}, "carry": [{"item": "t:sword", "source": "t/sword.c"}],
	}, "t.npcs[0]", errors))
	_eq(errors, [], "valid NPC record reports nothing")
	_eq([npc.race_id, npc.attitude, npc.has_authored_gender, npc.has_authored_age, npc.authored_combat_facts()], [&"human", NpcDefinition.Attitude.PEACEFUL, false, true, null], "LPC defaults: human, peaceful, no authored gender or combat facts")
	var vitality: NpcResourceTrackOverride = npc.resource_overrides().vitality()
	_eq([vitality.current(), vitality.effective(), vitality.maximum(), npc.resource_overrides().essence().is_empty()], [50, 60, 70, true], "kee/eff_kee/max_kee map to vitality only")
	_eq([npc.base_attribute_overrides().has_composure(), npc.base_attribute_overrides().composure(), npc.base_attribute_overrides().has_strength()], [true, 12, false], "cps maps to composure only")
	_eq([npc.skill_levels()[0].skill_id, npc.skill_levels()[1].skill_id], [&"parry", &"dodge"], "skills keep authored order")
	_eq([npc.loadout_entries()[0].quantity, npc.loadout_entries()[0].equipment_intent], [1, NpcLoadoutEntry.EquipmentIntent.NONE], "carry defaults to one unequipped item")
	var rolled: NpcDefinition = NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.rolled", "legacy_source": "t/rolled.c", "name": "客", "aliases": ["guest"], "title": "旅人",
		"gender": {"random": 10, "below": 7, "then": "男性", "else": "女性"}, "age": {"base": 15, "plus_random": 50},
		"combat_exp": {"base": 600, "plus_random": 400}, "score": {"base": 5, "minus_random": 10},
		"attitude": "friendly", "skills": {"unarmed": 10, "liuh-ken": 5}, "skill_map": {"unarmed": "liuh-ken"},
	}, "t.npcs[2]", errors))
	_eq(errors, [], "random forms, title and skill_map read cleanly")
	_eq([rolled.short_name(), rolled.attitude, rolled.has_authored_gender, rolled.gender, rolled.age, rolled.combat_experience], ["旅人 客", NpcDefinition.Attitude.FRIENDLY, true, &"男性", 15, 600], "a roll's base stands for the fact before the draw")
	_eq([rolled.age_roll().admits(15), rolled.age_roll().admits(64), rolled.age_roll().admits(65), rolled.score_roll().admits(-4), rolled.score_roll().admits(-5)], [true, true, false, true, false], "admits exactly the values random(n) can give")
	var draws: NpcInitializationRandomSource = ScriptedNpcDraws.new([7, 49, 0])
	_eq([rolled.gender_roll().resolve(draws), rolled.age_roll().resolve(draws), rolled.combat_experience_roll().resolve(draws)], ["女性", 64, 600], "random(10) < 7 picks then; 15+random(50); 600+random(400)")
	NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.badroll", "legacy_source": "t/badroll.c", "name": "错", "aliases": ["wrong"],
		"age": {"base": 1}, "combat_exp": {"base": 1, "plus_random": 0}, "skills": {"dodge": 1}, "skill_map": {"unarmed": "liuh-ken"},
	}, "t.npcs[3]", errors))
	_eq(errors, [
		"t.npcs[3].age: needs exactly one of plus_random and minus_random",
		"t.npcs[3].combat_exp: random bound must be positive",
		"t.npcs[3]: is not a valid NPC definition (aliases, gender, skills, skill_map, carry, random values or talk)",
	], "bad rolls and a skill_map to an unknown skill are reported")
	errors.clear()
	NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.bad", "legacy_source": "t/bad.c", "name": "坏", "aliases": ["bad"], "race": "dragon",
		"attitude": "killer", "attributes": {"luck": 1}, "resources": {"mana": 1}, "apply": {"parry": 1},
		"carry": [{"item": "t:sword", "source": "t/sword.c", "equip": "hold"}],
	}, "t.npcs[1]", errors))
	_eq(errors, [
		"t.npcs[1].race: unsupported race 'dragon'",
		"t.npcs[1].attitude: unsupported attitude 'killer'",
		"t.npcs[1].carry[0].equip: expected 'wield' or 'wear'",
		"t.npcs[1].attributes.luck: unsupported attribute",
		"t.npcs[1].resources.mana: unsupported resource",
		"t.npcs[1].apply.parry: unsupported apply value",
	], "unsupported NPC facts are reported, not guessed")
	errors.clear()
	NpcContentRecords.spawn_from_record(ContentRecordReader.new({
		"id": "t.spawn", "npc": "t.npc", "map": "t.map", "zone": "t.zone", "points": ["p1", "p2"], "legacy_room": "t/room.c", "legacy_quantity": 3,
	}, "t.spawns[0]", errors))
	_eq(errors, ["t.spawns[0]: is not a valid spawn (points must be unique and match legacy_quantity)"], "spawn points must match the LPC quantity")


func _test_cross_reference_checks() -> void:
	var builder: ContentCatalogBuilder = ContentCatalogBuilder.new()
	builder.add_document({
		"items": [
			{"id": "t:sword", "legacy_sources": ["t/sword.c"], "name": "剑", "aliases": ["sword"], "weight": 1, "weapon": {"skill": "sword", "damage": 1}},
			{"id": "t:sword", "legacy_sources": ["t/sword2.c"], "name": "剑", "aliases": ["sword"], "weight": 1},
			{"id": "t:coin", "legacy_sources": ["t/coin.c"], "name": "钱", "aliases": ["coin"], "money": {"money_id": "coin", "base_value": 1, "base_unit": "文", "base_weight": 1}},
			{"id": "t:coin2", "legacy_sources": ["t/coin2.c"], "name": "钱", "aliases": ["coin"], "money": {"money_id": "coin", "base_value": 1, "base_unit": "文", "base_weight": 1}},
			{"id": "t:shell", "legacy_sources": ["t/shell.c"], "name": "贝", "aliases": ["shell"], "money": {"money_id": "shell", "base_value": 1, "base_unit": "枚", "base_weight": 1}},
		],
		"npcs": [{"id": "t.npc", "legacy_source": "t/npc.c", "name": "人", "aliases": ["man"], "carry": [
			{"item": "t:missing", "source": "t/missing.c"},
			{"item": "t:coin", "source": "t/coin.c", "equip": "wield"},
			{"item": "t:sword", "source": "t/sword.c", "equip": "wear"},
		]}],
		"spawns": [
			{"id": "t.spawn.a", "npc": "t.nobody", "map": "m", "zone": "z", "points": ["p"], "legacy_room": "t/r.c", "legacy_quantity": 1},
			{"id": "t.spawn.b", "npc": "t.npc", "map": "m", "zone": "z", "points": ["p"], "legacy_room": "t/r.c", "legacy_quantity": 1},
		],
		"vendors": [
			{"id": "t.vendor", "legacy_source": "t/v.c", "goods": [{"key": "pie", "item": "t:pie"}]},
			{"id": "t.vendor2", "legacy_source": "t/v2.c", "goods": [{"key": "free", "item": "t:sword", "price": 0}]},
		],
		"places": [],
	}, "t")
	_eq(builder.build(), null, "a catalog with problems is not built")
	_eq(builder.errors(), [
		"t.items[1].id: 't:sword' is already defined at t.items[0]",
		"t.vendors[1].goods[0].price: must be at least 1",
		"t.vendors[1].goods: needs at least one entry",
		"t.places: unknown field",
		"t.items[3].money.money_id: 'coin' is already t:coin",
		"t.items[4].money.money_id: unsupported money 'shell'",
		"items: no money item with money_id 'silver'",
		"items: no money item with money_id 'gold'",
		"t.npcs[0].carry[0].item: unknown item 't:missing'",
		"t.npcs[0].carry[1].equip: 't:coin' is not a weapon",
		"t.npcs[0].carry[2].equip: 't:sword' is not armor",
		"t.spawns[0].npc: unknown NPC 't.nobody'",
		"t.spawns[1].points: 'p' is already used by t.spawn.a",
		"t.vendors[0].goods.pie: unknown item 't:pie'",
		"t.spawns[0].map: unknown map 'm'",
		"t.spawns[1].map: unknown map 'm'",
		"pacing: no document defines it",
	], "cross references are checked")
	var not_object: ContentCatalogBuilder = ContentCatalogBuilder.new()
	not_object.add_document([], "list.json")
	not_object.add_document(null, "null.json")
	_eq(not_object.errors(), ["list.json: expected a JSON object", "null.json: expected a JSON object"], "a document must be an object")


func _test_missing_files_fail_closed() -> void:
	var errors: Array[String] = []
	_eq(GameContent.load_catalog("res://data/no_such_manifest.json", GameContent.DATA_ROOT, errors), null, "missing manifest builds nothing")
	_eq(errors.has("res://data/no_such_manifest.json: file not found"), true, "missing manifest is reported")
	errors.clear()
	_eq(GameContent.load_catalog(GameContent.MANIFEST_PATH, "res://tests/", errors), null, "missing data file builds nothing")
	_eq(errors.has("res://tests/common/items.json: file not found"), true, "missing data file is reported")


func _item(record: Dictionary, errors: Array[String]) -> ItemContentDefinition:
	return ItemContentDefinition.from_record(ContentRecordReader.new(record, "t.items[0]", errors))


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


## Scripted NpcInitializationRandomSource for the roll tests.
class ScriptedNpcDraws extends NpcInitializationRandomSource:
	var _values: Array[int] = []

	func _init(values: Array[int]) -> void:
		_values = values.duplicate()

	func next_below(_exclusive_upper_bound: int) -> int:
		return _values.pop_front() if not _values.is_empty() else -1
