extends RefCounted

const ScriptedRandom := preload("res://tests/support/scripted_npc_initialization_random_source.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_authored_definition()
	_test_serpent_creation_and_independence()
	_test_definition_copy_boundaries()
	_test_production_spawn_ledger_unchanged()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_authored_definition() -> void:
	var definition: NpcDefinition = OldPineNpcDefinitions.npc_by_id(&"oldpine.npc.serpent")
	_eq(definition != null, true, "catalog resolves serpent without spawning")
	if definition == null:
		return
	_eq(definition.is_valid(), true, "valid definition")
	_eq(definition.legacy_source_path, "d/oldpine/npc/serpent.c", "source path")
	_eq(definition.display_name, "黑冠巨蟒", "source name")
	_eq(definition.description, "一只乌黑油亮的巨蟒，头上生著一个大肉瘤。\n", "source description")
	_eq(definition.aliases(), [&"serpent"], "source aliases")
	_eq(definition.race_id, &"beast", "野兽 race mapping")
	_eq(definition.has_authored_age, true, "age present")
	_eq(definition.age, 400, "age")
	_eq(definition.has_authored_gender, false, "gender is Beast default not authored")
	_eq(definition.attitude, NpcDefinition.Attitude.AGGRESSIVE, "aggressive")
	_eq(definition.combat_experience, 250000, "combat exp")
	_eq(definition.score, 1000, "score")
	_eq(definition.skill_levels().size(), 0, "no invented skills")
	_eq(definition.loadout_entries().size(), 0, "no invented equipment/items")
	_eq(definition.capability_ids(), [&"aggressive_on_player_presence"], "no pursuer/special capability")
	var a: NpcBaseAttributeOverrides = definition.base_attribute_overrides()
	_eq([a.has_strength(), a.has_courage(), a.has_intelligence(), a.has_spirituality()], [true, true, true, true], "authored attributes present")
	_eq([a.strength(), a.courage(), a.intelligence(), a.spirituality()], [40, 70, 10, 20], "exact authored values")
	_eq([a.has_composure(), a.has_personality(), a.has_constitution(), a.has_karma()], [false, false, false, false], "defaults remain undefined in definition")
	var r: NpcResourceOverrides = definition.resource_overrides()
	for track: NpcResourceTrackOverride in [r.essence(), r.vitality(), r.spirit()]:
		_eq([track.has_current(), track.has_effective(), track.has_maximum()], [false, false, true], "only maximum authored")
	_eq([r.essence().maximum(), r.vitality().maximum(), r.spirit().maximum()], [900, 1800, 500], "authored maxima")
	var facts: NpcAuthoredCombatFacts = definition.authored_combat_facts()
	_eq(facts != null, true, "typed authored facts")
	if facts == null:
		return
	_eq(facts.limbs(), ["头部", "躯干", "尾巴"], "ordered limbs")
	_eq(facts.verbs(), [&"bite"], "ordered verb source")
	_eq([facts.intrinsic_attack, facts.intrinsic_damage, facts.intrinsic_armor, facts.intrinsic_dodge], [60, 20, 90, 80], "intrinsic apply not skill/equipment")
	_eq(OldPineNpcDefinitions.bandit_definition().authored_combat_facts(), null, "human has no invented Beast facts")


func _test_serpent_creation_and_independence() -> void:
	var definition: NpcDefinition = OldPineNpcDefinitions.serpent_definition()
	var rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new([10, 0, 39, 0, 30, 40])
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var characters: Array[NpcRuntimeState] = []
	for index: int in range(2):
		var npc: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(
			definition, StringName("test.serpent.%d" % index), &"test.spawn", &"test.point",
			WorldLocationState.new(&"test.region", &"test.map", &"test.zone", &"test.location"),
			inventory, stacks, rng, [],
		)
		_eq(npc != null, true, "fresh serpent created")
		if npc == null:
			return
		characters.append(npc)
		_eq(npc.age, 400, "no age roll")
		_eq(npc.character_state.gender, &"雄性", "Beast default gender")
		_eq(npc.character_state.attributes.karma, 0, "missing kar effective zero")
		_eq(npc.body_weight, 62000, "Beast body weight")
		_eq(npc.maximum_encumbrance, 200000, "raw strength capacity")
		_eq(npc.character_state.progression.combat_experience, 250000, "experience copied")
		_eq(npc.character_state.skills.raw_skill_ids().size(), 0, "no intrinsic dodge in raw skills")
		_eq(npc.character_state.equipment.primary_weapon(), null, "no fake weapon")
		_eq(npc.loadout_items().size(), 0, "no fake loot")
		var tracks: Array[CharacterResourceState] = [npc.character_state.essence, npc.character_state.vitality, npc.character_state.spirit]
		for track_index: int in range(3):
			var track: CharacterResourceState = tracks[track_index]
			var expected: int = [900, 1800, 500][track_index]
			_eq([track.current, track.effective, track.maximum], [expected, expected, expected], "authored maxima full initialization")
	_eq(rng.requested_bounds(), [11, 31, 41, 11, 31, 41], "only cps/per/con per fresh serpent")
	var left: CharacterState = characters[0].character_state
	var right: CharacterState = characters[1].character_state
	_eq([left.attributes.composure, left.attributes.personality, left.attributes.constitution], [15, 5, 44], "first source draws in order")
	_eq([right.attributes.composure, right.attributes.personality, right.attributes.constitution], [5, 35, 45], "second independent source draws")
	_eq(inventory.registered_item_ids().size(), 0, "no item registration")
	_eq(left != right and left.attributes != right.attributes and left.vitality != right.vitality, true, "independent Character authorities")
	_eq(left.skills != right.skills and left.equipment != right.equipment and characters[0].armor != characters[1].armor, true, "independent mutable skills/equipment/armor")
	left.vitality.apply_damage(10)
	left.attributes.constitution = 99
	_eq(right.vitality.current, 1800, "other character undamaged")
	_eq(right.attributes.constitution, 45, "other character attribute unaffected")


func _test_definition_copy_boundaries() -> void:
	var limbs: Array[String] = ["头部", "躯干", "尾巴"]
	var verbs: Array[StringName] = [&"bite"]
	var facts: NpcAuthoredCombatFacts = NpcAuthoredCombatFacts.new(limbs, verbs, 60, 20, 90, 80)
	var definition: NpcDefinition = NpcDefinition.new(&"test.beast", "test.c", "Test", [&"test"],
		&"beast", false, &"", false, 0, null, null, 0, 0, 0, [], [], [], "", facts)
	limbs.clear()
	verbs.clear()
	_eq(facts.limbs(), ["头部", "躯干", "尾巴"], "input limbs copied")
	_eq(facts.verbs(), [&"bite"], "input verbs copied")
	var returned: NpcAuthoredCombatFacts = definition.authored_combat_facts()
	_eq(returned != facts, true, "definition retains own snapshot")
	returned.limbs().clear()
	returned.verbs().clear()
	_eq(definition.authored_combat_facts().limbs(), ["头部", "躯干", "尾巴"], "output limbs defensive")
	_eq(definition.authored_combat_facts().verbs(), [&"bite"], "output verbs defensive")
	# Test storage alias isolation even against direct internal-field misuse.
	facts._attack = 999
	returned._dodge = 999
	_eq(definition.authored_combat_facts().intrinsic_attack, 60, "input fact snapshot isolation")
	_eq(definition.authored_combat_facts().intrinsic_dodge, 80, "output fact snapshot isolation")


func _test_production_spawn_ledger_unchanged() -> void:
	var spawns: Array[NpcSpawnDefinition] = OldPineSpawnDefinitions.all_spawns()
	_eq(spawns.size(), 3, "only existing three production spawn definitions")
	var npc_count: int = 0
	var item_count: int = 0
	for spawn: NpcSpawnDefinition in spawns:
		_eq(spawn.npc_definition_id != &"oldpine.npc.serpent", true, "no serpent placement")
		npc_count += spawn.quantity
		item_count += OldPineNpcDefinitions.npc_by_id(spawn.npc_definition_id).loadout_entries().size() * spawn.quantity
	_eq(npc_count, 5, "3 scouts + tall + fat")
	_eq(item_count, 11, "existing 11 NPC item objects; player starting sword remains separate")
	_eq(OldPineSpawnDefinitions.validate(), true, "production spawn validation unchanged")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
