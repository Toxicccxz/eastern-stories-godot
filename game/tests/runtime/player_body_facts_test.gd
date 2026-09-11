extends RefCounted

const Fixture := preload("res://tests/support/oldpine_world_save_fixture.gd")
const Values := preload("res://core/persistence/game_save_value_types.gd")
var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_source_growth_and_carry()
	await _test_v1(tree)
	return {"assertions": _count, "failures": _failures}


func _test_source_growth_and_carry() -> void:
	var birth: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
	_check(birth.initialize(&"player", CharacterState.GENDER_FEMALE, "初雪", SessionItemIdAllocator.new(&"body-test")), "source graph initializes")
	var player: WorldPlayerRuntimeState = NewPlayerRuntimeComposition.create(&"player", birth.player, SnowWorldDefinitions.birth_location())
	_check(player.is_valid(), "explicit body runtime valid")
	var body: PlayerBodyFacts = player.body_facts
	_check(body == birth.player.body_facts, "birth/runtime share one exact body authority")
	_check(body.body_weight == 80000 and body.maximum_encumbrance == 150000, "LPC fresh str30 body80000/cap150000")
	var other: NewPlayerInitialization = NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "独立")
	_check(body != other.body_facts, "independent fresh Players do not share body objects")
	_grow(player, 128)
	_check(player.state.attributes.strength == 32, "unarmed129: 30 < 129/4=32, str +=2")
	_check(player.body_facts == body and body.body_weight == 80000 and body.maximum_encumbrance == 150000, "real registered effect does not refresh body")
	_check(other.state.attributes.strength == 30 and other.body_facts.body_weight == 80000, "other Player remains untouched")
	var world: InventoryTransferDestination = InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"fixture"), true, true, 1000000)
	var death: DeathContext = player.death_context(world, false)
	_check(death.victim_body_own_weight == 80000 and death.victim_maximum_encumbrance == 150000, "death copies established facts, NOT 84000/160000")
	_check(death.victim_display_name == "初雪" and death.victim_age == 14 and death.victim_gender == CharacterState.GENDER_FEMALE, "death identity unchanged")
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)
	_check(birth.inventory.contents_weight(owner) == 3000 and body.body_weight == 80000, "cloth contents weight is separate from own body weight")
	var item: ItemInstance = ItemInstance.new(&"ballast", &"test:ballast")
	_check(birth.inventory.register_item(item, 147001), "carry fixture registers")
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(owner, true, true, player.maximum_encumbrance)
	var transfer: InventoryTransferService = InventoryTransferService.new()
	_check(not transfer.transfer(birth.inventory, item.item_instance_id, destination).succeeded, "150001 contents rejected even with strength32")
	birth.inventory.update_own_weight(item.item_instance_id, 147000)
	_check(transfer.transfer(birth.inventory, item.item_instance_id, destination).succeeded, "exact150000 contents admitted by established capacity")
	_check(body.body_weight == 80000, "inventory mutation never changes own body")
	# Exercise the actual loot adapter's Player capacity consumer as well.
	var corpse: CorpseState = CorpseState.new(&"body-corpse", &"victim", "Victim", CharacterState.GENDER_MALE, 20, 50000)
	var corpse_item: ItemInstance = ItemInstance.new(&"body-corpse", &"es2:obj/corpse")
	birth.inventory.register_item(corpse_item, 0)
	birth.item_index.register_snapshot(corpse_item)
	_check(transfer.transfer(birth.inventory, corpse_item.item_instance_id, world).succeeded, "loot fixture corpse placed in world")
	var sword: ItemInstance = ItemInstance.new(&"body-loot", OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID)
	birth.inventory.register_item(sword, 7000)
	birth.item_index.register_snapshot(sword)
	_check(transfer.transfer(birth.inventory, sword.item_instance_id, InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id), true, true, 50000)).succeeded, "loot fixture sword placed inside corpse")
	var loot: OldPineCorpseLootAdapter = OldPineCorpseLootAdapter.new()
	var denied: CorpseLootTransferResult = loot.take(player, corpse, sword.item_instance_id, true, birth.inventory, birth.stacks, birth.item_index)
	_check(not denied.succeeded and denied.outcome == CorpseLootTransferResult.Outcome.TRANSFER_FAILED, "real loot adapter rejects157000 despite strength32 derived160000")
	birth.inventory.update_own_weight(item.item_instance_id, 140000)
	var admitted: CorpseLootTransferResult = loot.take(player, corpse, sword.item_instance_id, true, birth.inventory, birth.stacks, birth.item_index)
	_check(admitted.succeeded and birth.inventory.contents_weight(owner) == 150000, "real loot adapter admits exact150000 using same authority")
	var signed: PlayerBodyFacts = PlayerBodyFacts.new(-1, -2)
	_check(signed.body_weight == -1 and signed.maximum_encumbrance == -2, "LPC signed facts preserved without invented clamp")
	var zero: PlayerBodyFacts = PlayerBodyFacts.new(0, 0)
	_check(zero.body_weight == 0 and zero.maximum_encumbrance == 0, "explicit zero facts are not silently derived")
	var missing: WorldPlayerRuntimeState = WorldPlayerRuntimeState.new(&"invalid", player.state, player.relationship, player.busy, player.armor, player.world_location())
	_check(not missing.is_valid() and missing.body_facts == null, "missing body fails validation instead of guessing")


func _grow(player: WorldPlayerRuntimeState, previous_level: int) -> void:
	# Controlled precondition, then the real generic progression + registered hook.
	# skill.c strict learned > (raw+1)^2; exactly one more point must level up.
	player.state.skills.set_raw_level(&"unarmed", previous_level)
	player.state.skills.set_learned_progress(&"unarmed", (previous_level + 1) * (previous_level + 1))
	var registry: SkillImprovementEffectRegistry = SkillImprovementEffectRegistry.new()
	registry.register_legacy_defaults()
	var improved: SkillImprovementResult = player.state.skills.improve_skill(&"unarmed", 1, 30, false, true)
	_check(improved.leveled_up and improved.current_level == previous_level + 1, "production improve_skill crosses strict threshold")
	var effect: SkillImprovementEffectResult = registry.apply(player.state, improved)
	_check(effect.status == SkillImprovementEffectResult.Status.APPLIED and effect.mutation_amount == 2, "registered authored effect applies exact +2")


func _test_v1(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.deterministic_npc_seed = true
	session.deterministic_combat_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(player.body_facts.body_weight == 60000 and player.maximum_encumbrance == 100000, "technical fresh str20 body60000/cap100000")
	var capture: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-11T00:00:00Z")
	_check(capture.succeeded(), "ordinary technical v1 capture remains available")
	if not capture.succeeded():
		session.free()
		return
	# Historical file fixture: neither new birth nor a runtime body mutation.
	var base: GameSaveSnapshot = capture.snapshot
	var saved_player: Values.PlayerRuntimeSnapshot = base.player
	saved_player.character.attributes.strength = 32
	saved_player.maximum_encumbrance = 150000
	saved_player.character.internal_resources.food = 123
	saved_player.character.internal_resources.water = 234
	saved_player.character.progression.combat_experience = 37
	var saved: GameSaveSnapshot = GameSaveSnapshot.new(base.metadata, base.session_kind, base.item_id_allocator, saved_player, base.npc_spawn_states, base.corpses, base.items, base.combat_rng, base.npc_initialization_rng, base.world_interaction_rng)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(saved)
	_check(encoded.succeeded(), "strict historical schema1 represents divergent saved capacity")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(decoded.succeeded(), "historical v1 exact decode")
	var result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(result.succeeded(), "v1 divergent capacity builds production candidate: " + result.path)
	if result.succeeded():
		var candidate: OldPineWorldSessionController = result.candidate
		var restored: WorldPlayerRuntimeState = candidate.player_runtime()
		var body: PlayerBodyFacts = restored.body_facts
		_check(body.body_weight == 84000 and body.maximum_encumbrance == 150000, "v1 derives missing weight ONCE; trusts saved capacity")
		_check(restored != player and body != player.body_facts, "fresh runtime graph, not old object reparent")
		_check(candidate.outdoor_map().player_runtime().body_facts == body and candidate.cave_map().player_runtime().body_facts == body, "both restored physical maps bind exact body authority")
		_check(restored.state.recovery.food == 123 and restored.state.recovery.water == 234 and restored.state.progression.combat_experience == 37, "no birth or refill")
		_check(candidate.inventory_state().registered_item_ids() == session.inventory_state().registered_item_ids(), "exact inventory IDs; no granted cloth")
		_check(restored.state.equipment.primary_weapon().instance_id == player.state.equipment.primary_weapon().instance_id and restored.armor.occupied_slots().is_empty(), "legacy equipment exact")
		_check(candidate.npc_random_source().capture_random_state().state == session.npc_random_source().capture_random_state().state and candidate.combat_random_source().capture_random_state().state == session.combat_random_source().capture_random_state().state and candidate.world_interaction_random_source().capture_random_state().state == session.world_interaction_random_source().capture_random_state().state, "three RNG states exact")
		_check(candidate.item_id_allocator().scope == session.item_id_allocator().scope and candidate.item_id_allocator().next_dynamic_sequence == session.item_id_allocator().next_dynamic_sequence, "allocator exact")
		var resave: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(candidate, &"test", "2026-09-11T00:00:00Z")
		_check(resave.succeeded() and resave.snapshot.player.maximum_encumbrance == 150000, "representable restored v1 can resave saved capacity")
		_grow(restored, 138)
		_check(restored.state.attributes.strength == 34 and restored.body_facts == body and body.body_weight == 84000 and body.maximum_encumbrance == 150000, "post-restore growth does not derive again")
		var reject: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(candidate, &"test", "2026-09-11T00:00:00Z")
		_check(reject.outcome == OldPineWorldCaptureResult.Outcome.UNREPRESENTED_CHARACTER_STATE and reject.path == "player.body_facts.body_weight", "divergent body refuses lossy v1 capture")
		candidate.free()
	# Player corpse validation must use saved capacity too (NPC policy unchanged).
	var corpse_saved: GameSaveSnapshot = Fixture.with_player_corpse(saved)
	var corpse_result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(corpse_saved, tree.root)
	_check(corpse_result.succeeded(), "v1 Player corpse with saved divergent capacity restores: " + corpse_result.path)
	if corpse_result.succeeded():
		var corpse_player: WorldPlayerRuntimeState = corpse_result.candidate.player_runtime()
		var death: DeathContext = corpse_player.death_context(InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"fixture")), false)
		_check(death.victim_body_own_weight == 84000 and death.victim_maximum_encumbrance == 150000, "legacy restored death copies interpreted body")
		corpse_result.candidate.free()
	_grow(player, 88)
	_check(player.state.attributes.strength == 22 and player.body_facts.body_weight == 60000 and player.maximum_encumbrance == 100000, "technical ordinary growth preserves initial body")
	var technical_reject: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-11T00:00:00Z")
	_check(technical_reject.outcome == OldPineWorldCaptureResult.Outcome.UNREPRESENTED_CHARACTER_STATE, "technical v1 cannot silently lose independent weight")
	session.free()
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("NGE5A0: " + label)
