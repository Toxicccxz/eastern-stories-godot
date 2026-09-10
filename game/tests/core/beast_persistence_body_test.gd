extends RefCounted

const Fixture := preload("res://tests/support/beast_persistence_fixture.gd")
const Values := preload("res://core/persistence/game_save_value_types.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_body_policy()
	_test_fresh_graph_round_trip(false)
	_test_fresh_graph_round_trip(true)
	_test_unconscious_and_malformed_body()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_body_policy() -> void:
	for definition: NpcDefinition in [OldPineNpcDefinitions.bandit_definition(), OldPineNpcDefinitions.tall_bandit_definition(), OldPineNpcDefinitions.fat_bandit_definition()]:
		var body: NpcBodyFacts = NpcBodyFacts.derive(definition, 40)
		_eq([body.body_weight, body.maximum_encumbrance], [100000, 200000], "human 40000+(40-10)*2000; common capacity")
		_eq(body.matches_saved(100000, 200000), true, "human expected accepted")
		_eq(body.matches_saved(62000, 200000), false, "human Beast-weight rejected")
	var beast: NpcBodyFacts = NpcBodyFacts.derive(OldPineNpcDefinitions.serpent_definition(), 40)
	_eq([beast.body_weight, beast.maximum_encumbrance], [62000, 200000], "Beast 2000+(40-10)*2000; common capacity")
	_eq(beast.matches_saved(100000, 200000), false, "Beast human-weight rejected")
	_eq(beast.matches_saved(62000, 199999), false, "wrong capacity rejected")
	var changed: NpcBodyFacts = NpcBodyFacts.derive(OldPineNpcDefinitions.serpent_definition(), 41)
	_eq([changed.body_weight, changed.maximum_encumbrance], [64000, 205000], "derive from saved strength, not authored strength40")
	for race: StringName in [&"", &"monster", &"unknown"]:
		var definition: NpcDefinition = NpcDefinition.new(&"test.race", "test.c", "test", [&"test"], race)
		_eq(NpcBodyFacts.derive(definition, 40), null, "unsupported race fails closed")
	_eq(NpcBodyFacts.derive(null, 40), null, "missing definition fails closed")


func _test_fresh_graph_round_trip(dead: bool) -> void:
	var f: Fixture = Fixture.new()
	var a: CharacterState = f.npc.character_state
	_eq(f.npc_random.calls, 3, "only fresh cps/per/con draws")
	var cps_per_con: Array[int] = [a.attributes.composure, a.attributes.personality, a.attributes.constitution]
	a.vitality.apply_damage(123)
	a.vitality.apply_wound(17)
	a.essence.apply_damage(12)
	a.spirit.apply_damage(21)
	a.progression.combat_experience += 7
	a.skills.improve_skill(&"unarmed", 2, 20, false, false)
	a.skills.improve_skill(&"unarmed", 3, 20, false, false)
	a.conditions.add_or_replace(&"bandaged", DurationConditionPayload.new(3))
	a.conditions.add_or_replace(&"test.poison", PoisonConditionPayload.new(4, -2, "saved typed poison"))
	if dead:
		a.vitality.apply_wound(9999)
		f.npc.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
		f.npc.set_exists_in_map(false)
		f.npc.set_combat_available(false)
	var snapshot: GameSaveSnapshot = f.capture()
	_eq(snapshot != null, true, "real production Character capture accepts Beast state")
	if snapshot == null:
		return
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_eq(encoded.succeeded(), true, "existing v1 JSON encodes")
	for key: String in ["\"race\"", "\"limbs\"", "\"verbs\"", "\"intrinsic_attack\"", "\"combat_profile\""]:
		_eq(encoded.text.contains(key), false, "immutable authored field absent: %s" % key)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_eq(decoded.succeeded(), true, "existing v1 JSON decodes")
	var entry: OldPineRestoredNpcEntry = f.restore(decoded.snapshot)
	_eq(entry != null and entry.is_valid(), true, "lowest real composition creates fresh graph")
	if entry == null:
		return
	var b: NpcRuntimeState = entry.runtime
	_eq(b != f.npc and b.character_state != a, true, "new runtime and Character object identities")
	_eq(b.character_state.attributes != a.attributes and b.character_state.skills != a.skills and b.character_state.conditions != a.conditions, true, "fresh mutable sub-authorities, not shared graph A state")
	_eq([b.character_state.attributes.strength, b.character_state.attributes.courage, b.character_state.attributes.intelligence, b.character_state.attributes.spirituality, b.character_state.attributes.karma], [40, 70, 10, 20, 0], "other initialized attributes exact")
	_eq(b.character_id, f.npc.character_id, "same semantic ID")
	_eq([b.character_state.attributes.composure, b.character_state.attributes.personality, b.character_state.attributes.constitution], cps_per_con, "persisted cps/per/con exact; no fresh initialization")
	_eq([b.age, b.body_weight, b.maximum_encumbrance, b.character_state.gender], [400, 62000, 200000, &"雄性"], "saved body facts exact")
	_eq([b.character_state.essence.current, b.character_state.essence.effective, b.character_state.essence.maximum], [888, 900, 900], "gin saved, not age formula")
	_eq([b.character_state.vitality.current, b.character_state.vitality.effective, b.character_state.vitality.maximum], [-1, -1, 1800] if dead else [1677, 1783, 1800], "kee saved exact incl dead floor")
	_eq([b.character_state.spirit.current, b.character_state.spirit.effective, b.character_state.spirit.maximum], [479, 500, 500], "sen saved, not age400 default3850")
	_eq(b.character_state.progression.combat_experience, 250007, "experience not reset to authored250000")
	_eq([b.character_state.skills.raw_level(&"unarmed"), b.character_state.skills.learned_progress(&"unarmed")], [1, 3], "live raw and learned progress restored")
	_eq((b.character_state.conditions.get_condition(&"bandaged") as DurationConditionPayload).remaining, 3, "duration condition preserved")
	var poison: PoisonConditionPayload = b.character_state.conditions.get_condition(&"test.poison") as PoisonConditionPayload
	_eq([poison.damage, poison.remaining, poison.legacy_message], [4, -2, "saved typed poison"], "existing poison payload preserved, no condition tick")
	_eq([b.life_status, b.exists_in_map, b.combat_available], [CharacterRuntimeLifeStatus.Value.DEAD, false, false] if dead else [CharacterRuntimeLifeStatus.Value.ACTIVE, true, true], "lifecycle/existence tombstone not respawned")
	_eq(entry.map_position, Vector2(17.5, -3.25), "position DTO preserved")
	_eq([b.world_location().region_id, b.world_location().map_id, b.world_location().zone_id, b.world_location().combat_location_id], [&"test.region", &"test.map", &"test.zone", &"test.location"], "location preserved without world placement")
	_eq(b.character_state.equipment == f.restored_items.domain_state.equipment_state(b.character_id), true, "exact Phase4 restored Equipment injected")
	_eq(b.armor == f.restored_items.domain_state.armor_state(b.character_id), true, "exact Phase4 restored Armor injected")
	_eq(b.armor != f.npc.armor and b.character_state.equipment != a.equipment, true, "no reused graph A equipment/armor")
	_eq(f.restored_items.domain_state.inventory.registered_item_ids(), [], "no synthetic item records")
	_eq(f.restored_items.item_index.snapshot_count(), 0, "fresh empty derived index")
	_eq(b.loadout_items(), [], "no invented loot/loadout")
	_eq(b.definition().race_id, &"beast", "race reconstructed from catalog")
	_eq(b.definition().display_name, "黑冠巨蟒", "name from catalog")
	var facts: NpcAuthoredCombatFacts = b.definition().authored_combat_facts()
	_eq(facts.limbs(), ["头部", "躯干", "尾巴"], "ordered limbs reobtained from immutable definition")
	_eq(facts.verbs(), [&"bite"], "bite default reobtained from definition, not saved action")
	_eq([facts.intrinsic_attack, facts.intrinsic_damage, facts.intrinsic_armor, facts.intrinsic_dodge], [60, 20, 90, 80], "intrinsics reobtained from definition")
	_eq(f.restored_random.calls, 0, "restore consumes zero initialization draws")
	_eq(f.restored_random.capture_random_state().state, snapshot.npc_initialization_rng.state, "saved stream state exact before continuation")
	_eq(f.restored_random.capture_random_state().seed, snapshot.npc_initialization_rng.seed, "saved seed exact, not a newly seeded stream")
	var next_a: NpcRuntimeState = _next_fresh(f.npc_random)
	var next_b: NpcRuntimeState = _next_fresh(f.restored_random)
	_eq(next_a != null and next_b != null, true, "next legitimate fresh NPC initializes on each continued stream")
	_eq([next_b.character_state.attributes.composure, next_b.character_state.attributes.personality, next_b.character_state.attributes.constitution], [next_a.character_state.attributes.composure, next_a.character_state.attributes.personality, next_a.character_state.attributes.constitution], "next factory's cps/per/con identical to uninterrupted stream")
	_eq(f.restored_random.calls, 3, "only the subsequent NEW NPC consumes three draws")
	_eq(f.restored_random.capture_random_state().state, f.npc_random.capture_random_state().state, "continuation remains identical")
	# A lower DTO capability is deliberately not a production Old Pine save slot.
	_eq(OldPineSpawnDefinitions.all_spawns().size(), 3, "production spawn definitions unchanged")


func _test_unconscious_and_malformed_body() -> void:
	var f: Fixture = Fixture.new()
	f.npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var saved: GameSaveSnapshot = f.capture()
	var restored: OldPineRestoredNpcEntry = f.restore(saved)
	_eq(restored.runtime.life_status, CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "unconscious status retained")
	for capacity_error: bool in [false, true]:
		var npc: Values.NpcSpawnStateSnapshot = saved.npc_spawn_states[0]
		if capacity_error:
			npc.maximum_encumbrance = 1
		else:
			npc.body_weight = 100000
		var bad: GameSaveSnapshot = GameSaveSnapshot.new(saved.metadata, saved.session_kind, saved.item_id_allocator, saved.player, [npc], [], saved.items, saved.combat_rng, saved.npc_initialization_rng, saved.world_interaction_rng)
		_eq(f.restore(bad), null, "real body helper rejects malformed Beast saved facts")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _next_fresh(rng: NpcInitializationRandomSource) -> NpcRuntimeState:
	return NpcCharacterStateFactory.new().create_one(OldPineNpcDefinitions.serpent_definition(), &"test.next", &"test.next.spawn", &"test.next.point", WorldLocationState.new(&"test.region", &"test.map", &"test.zone", &"test.location"), InventoryState.new(), CombinedStackCollection.new(), rng, [])
