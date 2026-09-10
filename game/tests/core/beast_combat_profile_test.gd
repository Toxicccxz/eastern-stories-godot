extends RefCounted

const Fixture := preload("res://tests/support/beast_combat_fixture.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_source_profile_and_selection()
	_test_readiness()
	_test_provider_priority_and_mismatched_action()
	_test_human_profiles()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_source_profile_and_selection() -> void:
	var f: RefCounted = Fixture.new()
	var profile: CombatSliceContentProfile = f.serpent.content
	_eq(profile.readiness(), CombatSliceContentProfile.Readiness.READY, "serpent combat ready")
	_eq(profile.limbs(), [&"头部", &"躯干", &"尾巴"], "source limb order")
	var bite: CombatActionDefinition = profile.unarmed_action()
	_eq(bite.action_id, BeastCombatActionDefinitions.BITE_ACTION_ID, "not punch/slash")
	_eq(bite.legacy_action_text, "$N扑上来张嘴往$n的$l狠狠地一咬", "beast.c exact text")
	_eq([bite.damage_percent, bite.force_percent, bite.damage_type], [20, 0, &"咬伤"], "bite semantics")
	_eq(bite.post_action_policy_id, &"", "no special hook")
	_eq([profile.intrinsic_attack, profile.projected_apply_damage(null), profile.intrinsic_armor, profile.intrinsic_dodge], [60, 20, 90, 80], "four independent source contributions")
	var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0])
	var result: CombatActionSelectionResult = CombatActionSelector.select_action(
		CombatSliceProjectionBuilder.build_action_selection_input(f.serpent), rng)
	_eq(result.succeeded, true, "single bite selected")
	_eq(rng.requested_bounds(), [1], "verbs[random(sizeof(verbs))] consumes exactly random(1)")
	_eq(f.serpent.state.skills.raw_skill_ids(), [], "projection creates no raw skills")
	_eq(f.inventory.registered_item_ids(), [], "no fake item")
	_eq(f.serpent.state == f.npc.character_state and f.serpent.armor == f.npc.armor, true, "binding preserves authority identity")
	var other: RefCounted = Fixture.new()
	profile.limbs().clear()
	profile._beast_facts._attack = 61 # Deliberate alias-abuse test; never production API.
	_eq(other.serpent.content.intrinsic_attack, 60, "independent profiles")
	_eq(f.npc.definition().authored_combat_facts().intrinsic_attack, 60, "definition snapshot independent")
	_eq(profile.limbs().size(), 3, "returned limbs defensive")


func _test_readiness() -> void:
	_eq(_profile(null).readiness(), CombatSliceContentProfile.Readiness.MISSING_COMBAT_FACTS, "missing facts")
	_eq(_profile(null).limbs(), [], "missing facts no human anatomy")
	_eq(_profile(null).unarmed_action(), null, "missing facts no punch")
	_eq(_profile(NpcAuthoredCombatFacts.new([], [&"bite"])).readiness(), CombatSliceContentProfile.Readiness.EMPTY_LIMBS, "empty limbs")
	_eq(_profile(NpcAuthoredCombatFacts.new([""], [&"bite"])).readiness(), CombatSliceContentProfile.Readiness.INVALID_LIMB, "invalid limb")
	_eq(_profile(NpcAuthoredCombatFacts.new(["头部"], [])).readiness(), CombatSliceContentProfile.Readiness.EMPTY_VERBS, "empty verbs")
	for verb: StringName in [&"unknown", &"claw", &"hoof", &"poke"]:
		_eq(_profile(NpcAuthoredCombatFacts.new(["头部"], [verb])).readiness(), CombatSliceContentProfile.Readiness.UNSUPPORTED_VERB, "unmigrated verb explicit: %s" % verb)
	_eq(_profile(NpcAuthoredCombatFacts.new(["头部"], [&"bite", &"bite"])).readiness(), CombatSliceContentProfile.Readiness.UNSUPPORTED_VERB_DISTRIBUTION, "weighted duplicates deferred")
	_eq(CombatSliceContentProfile.new(&"", &"", 0, &"monster").readiness(), CombatSliceContentProfile.Readiness.UNSUPPORTED_RACE, "unknown race no fallback")
	var definition: NpcDefinition = NpcDefinition.new(&"test.beast", "test.c", "Test", [&"test"], &"beast")
	_eq(definition.is_valid(), true, "generic NPC definition remains legal without combat facts")
	_eq(CombatSliceContentProfile.new().for_npc_definition(definition).readiness(), CombatSliceContentProfile.Readiness.MISSING_COMBAT_FACTS, "consumer separately not ready")
	var draws: Array[int] = []
	draws.resize(9)
	draws.fill(0)
	var npc: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(definition,
		&"test.unready", &"test.spawn", &"test.point",
		WorldLocationState.new(&"region", &"map", &"zone", &"combat"),
		InventoryState.new(), CombinedStackCollection.new(), ScriptedNpcInitializationRandomSource.new(draws), [])
	_eq(npc != null, true, "NPC without combat facts can initialize")
	_eq(WorldCombatBindingAdapter.from_npc(npc, CombatSliceContentProfile.new()), null, "world binding rejects missing facts instead of human fallback")
	var bad: CombatSliceContentProfile = _profile(OldPineNpcDefinitions.serpent_definition().authored_combat_facts())
	bad._unarmed_action = CombatActionDefinition.new()
	_eq(bad.readiness(), CombatSliceContentProfile.Readiness.INVALID_ACTION_DATA, "invalid resolved definition rejected")
	bad._unarmed_action = CombatSliceContentProfile.new().unarmed_action()
	_eq(bad.readiness(), CombatSliceContentProfile.Readiness.INVALID_ACTION_DATA, "resolved human action mismatch rejected")


func _test_provider_priority_and_mismatched_action() -> void:
	var f: RefCounted = Fixture.new()
	var forged: CombatActionDefinition = CombatActionDefinition.new(BeastCombatActionDefinitions.BITE_ACTION_ID, 99, 0, &"咬伤")
	_eq(f.serpent.content.action_readiness(null, forged), CombatSliceContentProfile.Readiness.INVALID_ACTION_DATA, "same ID wrong facts rejected")
	_eq(CombatSliceProjectionBuilder.build_attack_input(f.serpent, f.human, forged), null, "mismatch cannot enter core")
	f.serpent.state.skills.set_raw_level(&"test.martial", 2)
	f.serpent.state.skills.map_skill(&"unarmed", &"test.martial")
	var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([])
	var selected: CombatActionSelectionResult = CombatActionSelector.select_action(CombatSliceProjectionBuilder.build_action_selection_input(f.serpent), rng)
	_eq(selected.outcome, CombatActionSelectionResult.Outcome.MAPPED_ACTION_DATA_UNAVAILABLE, "mapped provider not silently bite")
	_eq(rng.call_count(), 0, "unavailable mapped provider before RNG")
	f = Fixture.new()
	f.serpent.state.equipment.wield(EquippedWeaponRef.new(&"test.unknown", WeaponDefinition.new(&"unknown", &"sword")), false)
	selected = CombatActionSelector.select_action(CombatSliceProjectionBuilder.build_action_selection_input(f.serpent), rng)
	_eq(selected.outcome, CombatActionSelectionResult.Outcome.PRIMARY_WEAPON_ACTION_DATA_UNAVAILABLE, "unknown primary not default slash/bite")
	_eq(rng.call_count(), 0, "unavailable weapon before RNG")


func _test_human_profiles() -> void:
	for definition: NpcDefinition in [OldPineNpcDefinitions.bandit_definition(), OldPineNpcDefinitions.tall_bandit_definition(), OldPineNpcDefinitions.fat_bandit_definition()]:
		var profile: CombatSliceContentProfile = CombatSliceContentProfile.new().for_npc_definition(definition)
		_eq(profile.readiness(), CombatSliceContentProfile.Readiness.READY, "%s ready" % definition.definition_id)
		_eq(profile.limbs(), [&"头部", &"颈部", &"胸口", &"後心", &"左肩", &"右肩", &"左臂", &"右臂", &"左手", &"右手", &"腰间", &"小腹", &"左腿", &"右腿", &"左脚", &"右脚"], "human ordered 16 limbs unchanged")
		_eq(profile.unarmed_action().action_id, CombatSliceContentProfile.UNARMED_ACTION_ID, "human punch unchanged")
		_eq([profile.intrinsic_attack, profile.intrinsic_dodge, profile.intrinsic_armor, profile.projected_apply_damage(null)], [0, 0, 0, 0], "no Beast facts on human")
	for content: NpcLoadoutItemDefinition in [OldPineNpcDefinitions.long_sword_content(), OldPineNpcDefinitions.short_sword_content()]:
		var expected: int = 25 if content.item_definition().item_definition_id == OldPineNpcDefinitions.LONG_SWORD_ITEM_ID else 15
		var weapon: EquippedWeaponRef = EquippedWeaponRef.new(&"test.weapon", content.weapon_definition())
		var profile: CombatSliceContentProfile = CombatSliceContentProfile.new(weapon.weapon_id, weapon.skill_type, expected)
		_eq(profile.projected_apply_damage(weapon), expected, "source long25/short15")
		_eq(profile.attack_template_for(weapon).action_id, CombatSliceContentProfile.SLASH_ACTION_ID, "existing slash unchanged")
		_eq(profile.for_npc_definition(OldPineNpcDefinitions.serpent_definition()).projected_apply_damage(weapon), expected + 20, "real weapon plus intrinsic damage")
	var leather: ArmorNumericModifiers = OldPineNpcDefinitions.leather_content().armor_definition().numeric_modifiers
	_eq([leather.armor, leather.dodge], [5, -2], "leather.c armor5 + cloth.c -6000/3000")


func _profile(facts: NpcAuthoredCombatFacts) -> CombatSliceContentProfile:
	return CombatSliceContentProfile.new(&"", &"", 0, &"beast", facts)


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
