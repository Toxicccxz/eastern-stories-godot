extends RefCounted

## 战斗决策层 1A (DECISIONS「战斗数值」): an NPC record's `classic` block holds the ES2 numbers
## the modern record changed; ContentCatalog.npc() hands the block's definition out under
## pacing es2_npc_values (经典) and the modern one otherwise.

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_overlay()
	_test_catalog_by_pace()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_overlay() -> void:
	var errors: Array[String] = []
	var reader := ContentRecordReader.new({
		"id": "x", "a": 1, "b": {"k": 2}, "c": 3, "classic": {"a": 10, "without": ["c"]},
	}, "r", errors)
	var laid: ContentRecordReader = reader.overlay("classic")
	_assert_true(laid != null and laid.integer("a") == 10 and laid.child("b").integer("k") == 2 and not laid.has("c") and not laid.has("classic") and not laid.has("without"), "the block's keys replace, `without` takes away, the rest stays")
	_assert_true(reader.integer("a") == 1 and reader.integer("c") == 3, "the record itself is untouched")
	_assert_true(reader.overlay("missing") == null and errors.is_empty(), "no block: null, no error")
	var npc_errors: Array[String] = []
	var definition: NpcDefinition = NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.rat", "legacy_source": "t/rat.c", "name": "老鼠", "aliases": ["rat"], "race": "beast", "age": 1,
		"long": "一只老鼠。", "limbs": ["头部", "身体"], "verbs": ["bite"],
		"skills": {"dodge": 15}, "resources": {"kee": 15, "max_kee": 15},
		"classic": {"skills": {"dodge": 120}, "without": ["resources"]},
	}, "npc", npc_errors))
	_assert_true(npc_errors.is_empty(), "both records read clean: %s" % [npc_errors])
	_assert_true(definition.skill_levels()[0].raw_level == 15 and not definition.resource_overrides().is_empty(), "the modern definition")
	var es2: NpcDefinition = definition.es2_variant()
	_assert_true(es2 != null and es2.definition_id == definition.definition_id and es2.display_name == "老鼠", "the ES2 variant is the same NPC")
	_assert_true(es2.skill_levels()[0].raw_level == 120 and es2.resource_overrides().is_empty() and es2.es2_variant() == null, "with ES2's dodge and no kee override")


func _test_catalog_by_pace() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	_assert_true(not production.es2_npc_values, "pacing.json: the modern numbers")
	var rat: NpcDefinition = catalog.npc(&"snow.npc.rat")
	_assert_true(rat != null and rat.skill_levels()[0].raw_level == 15 and rat.es2_variant() != null, "老鼠 dodges at 15 today (ES2: 120)")
	var bandit: NpcDefinition = catalog.npc(&"oldpine.npc.bandit")
	_assert_true(bandit != null and bandit.combat_experience == 250 and bandit.es2_variant().combat_experience == 600, "土匪探哨 at 250 exp (ES2: 600)")
	var dog: NpcDefinition = catalog.npc(&"snow.npc.dog")
	_assert_true(dog != null and dog.es2_variant() == null, "野狗 was not changed: no block")
	catalog.set_pacing(PacePresets.of(production, CharacterState.PACE_CLASSIC))
	var classic_rat: NpcDefinition = catalog.npc(&"snow.npc.rat")
	_assert_true(classic_rat == rat.es2_variant() and classic_rat.skill_levels()[0].raw_level == 120, "经典: the catalog hands out the ES2 variant")
	_assert_true(catalog.npc(&"oldpine.npc.bandit").combat_experience == 600 and catalog.npc(&"snow.npc.dog") == dog, "the bandit's 600, the dog itself")
	catalog.set_pacing(production)
	_assert_true(catalog.npc(&"snow.npc.rat") == rat, "back to the modern one")


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)
