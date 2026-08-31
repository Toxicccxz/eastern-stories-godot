extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const OldPineWorldSaveFixture := preload(
	"res://tests/support/oldpine_world_save_fixture.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_outdoor_restore_and_identity_injection(tree)
	await _test_unconscious_lifecycle_restores_independently(tree)
	await _test_dead_tombstone_and_corpse_graph(tree)
	await _test_strict_position_and_cross_reference_failures(tree)
	await _test_cave_restore_and_candidate_activation(tree)
	await _test_new_game_regression(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_outdoor_restore_and_identity_injection(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1001, 1002, 1003)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	_assert_true(snapshot != null, "fixture captures a complete New Game graph")
	var source_scope: StringName = snapshot.item_id_allocator.scope
	_free_node(source)
	await tree.process_frame

	var result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	)
	_assert_eq(
		result.outcome,
		OldPineWorldRestoreResult.Outcome.SUCCESS,
		"Outdoor snapshot constructs a staged candidate (%s: %s)" % [result.path, result.detail],
	)
	var candidate: OldPineWorldSessionController = result.candidate
	_assert_true(candidate != null and candidate.is_restore_candidate_staged(), "RESTORE candidate remains staged")
	_assert_eq(candidate.bootstrap_mode(), OldPineWorldSessionController.BootstrapMode.RESTORE, "bootstrap mode was chosen before ready")
	_assert_eq(candidate.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "active map derives from Player location")
	_assert_true(candidate.outdoor_map().get_parent() == candidate.active_map_slot, "Outdoor alone is attached")
	_assert_true(candidate.cave_map().get_parent() == null, "inactive Cave is detached")
	_assert_eq(candidate.active_map_child_count(), 1, "exactly one resident is attached")
	_assert_eq(candidate.resident_map_count(), 2, "both residents are fresh and retained")
	_assert_eq(candidate.outdoor_map().initialization_count(), 1, "Outdoor initializes once")
	_assert_eq(candidate.cave_map().initialization_count(), 1, "Cave initializes once")
	_assert_eq(candidate.inventory_state().registered_item_ids().size(), 12, "RESTORE creates no default item duplicate")
	_assert_eq(candidate.item_instance_index().snapshot_count(), 12, "derived index matches restored Inventory")
	_assert_eq(candidate.item_instance_scope(), source_scope, "allocator scope survives exactly")
	_assert_eq(candidate.outdoor_map().npc_runtimes().size(), 5, "complete five-slot NPC ledger restores")
	_assert_eq(candidate.item_id_allocator().next_dynamic_sequence, snapshot.item_id_allocator.next_dynamic_sequence, "RESTORE does not allocate an item ID")
	_assert_random_equal(candidate.combat_random_source().capture_random_state(), snapshot.combat_rng, "Combat RNG consumes zero draws")
	_assert_random_equal(candidate.npc_random_source().capture_random_state(), snapshot.npc_initialization_rng, "NPC RNG consumes zero draws")
	_assert_random_equal(candidate.world_interaction_random_source().capture_random_state(), snapshot.world_interaction_rng, "World RNG consumes zero draws")
	var player: WorldPlayerRuntimeState = candidate.player_runtime()
	_assert_true(player.state.equipment == result.preparation.item_domain.equipment_state(player.character_id), "Player receives exact Phase 10B2 EquipmentState")
	_assert_true(player.armor == result.preparation.item_domain.armor_state(player.character_id), "Player receives exact Phase 10B2 ArmorState")
	_assert_eq(player.state.skills.raw_level(&"force"), snapshot.player.character.skills.raw_levels[0].value, "raw skill restores before mapping")
	_assert_eq(player.state.skills.mapped_skill(&"force"), &"force", "skill mapping restores against raw target")
	_assert_eq(player.state.skills.learned_progress(&"force"), 7, "learned progress restores exactly")
	_assert_eq(candidate.outdoor_map().player_body.global_position, Vector2(snapshot.player.map_position.x, snapshot.player.map_position.y), "Player exact map-local position survives")
	_assert_false(candidate.outdoor_map().player_body.player_controlled, "staged Player control stays disabled")
	_assert_false((candidate.outdoor_map().player_body.get_node("Camera2D") as Camera2D).enabled, "staged camera stays disabled")
	_assert_true(_all_areas_disabled(candidate.outdoor_map()), "staged authored Areas are disabled")
	_assert_eq(candidate.cave_map().process_mode, Node.PROCESS_MODE_DISABLED, "inactive Cave remains frozen")
	for saved: Values.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		var npc: NpcRuntimeState = candidate.outdoor_map().find_resident_npc(saved.character_id)
		_assert_true(npc != null, "authored NPC slot %s restores once" % saved.spawn_point_id)
		_assert_eq(npc.age, saved.age, "NPC age is restored without reroll")
		_assert_true(npc.character_state.equipment == result.preparation.item_domain.equipment_state(saved.character_id), "NPC receives exact Phase 10B2 EquipmentState")
		_assert_true(npc.armor == result.preparation.item_domain.armor_state(saved.character_id), "NPC receives exact Phase 10B2 ArmorState")
		_assert_eq(_body_for(candidate.outdoor_map(), saved.character_id).global_position, Vector2(saved.map_position.x, saved.map_position.y), "NPC exact map-local position survives")
	_free_node(candidate)
	await tree.process_frame


func _test_unconscious_lifecycle_restores_independently(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1051, 1052, 1053)
	var base: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	var npc_states: Array[Values.NpcSpawnStateSnapshot] = base.npc_spawn_states
	var saved: Values.NpcSpawnStateSnapshot = npc_states[0]
	npc_states[0] = Values.NpcSpawnStateSnapshot.new(
		saved.spawn_id, saved.spawn_point_id, saved.npc_definition_id,
		saved.character_id, true, &"unconscious", false, saved.character,
		saved.age, saved.body_weight, saved.maximum_encumbrance,
		saved.world_location, saved.map_position, saved.live_loadout_item_ids,
	)
	var snapshot := GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		npc_states, base.corpses, base.items, base.combat_rng,
		base.npc_initialization_rng, base.world_interaction_rng,
	)
	_free_node(source)
	await tree.process_frame
	var result := OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	_assert_eq(result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "committed unconscious NPC restores")
	var candidate: OldPineWorldSessionController = result.candidate
	var runtime: NpcRuntimeState = candidate.outdoor_map().find_resident_npc(saved.character_id)
	_assert_eq(runtime.life_status, CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "committed lifecycle is not re-derived")
	_assert_false(runtime.character_state.is_unconscious_threshold_reached(), "resource thresholds remain an independent fact")
	_assert_true(runtime.exists_in_map, "unconscious NPC remains present")
	_assert_false(runtime.combat_available, "unconscious combat-availability fact survives")
	_free_node(candidate)
	await tree.process_frame


func _test_dead_tombstone_and_corpse_graph(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1101, 1102, 1103)
	var base: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.with_fat_bandit_corpse(base)
	_free_node(source)
	await tree.process_frame
	var result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	_assert_eq(result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "dead NPC/corpse snapshot restores")
	var candidate: OldPineWorldSessionController = result.candidate
	var fat_snapshot: Values.NpcSpawnStateSnapshot = _npc_by_definition(snapshot, OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID)
	var fat: NpcRuntimeState = candidate.outdoor_map().find_resident_npc(fat_snapshot.character_id)
	_assert_true(fat != null, "dead authored slot remains a ledger tombstone")
	_assert_eq(fat.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "dead lifecycle restores independently")
	_assert_false(fat.exists_in_map, "dead tombstone does not respawn")
	_assert_false(fat.combat_available, "dead combat availability fact survives")
	_assert_eq(candidate.outdoor_map().npc_runtimes().size(), 5, "tombstone replaces rather than duplicates its slot")
	_assert_eq(candidate.inventory_state().registered_item_ids().size(), 13, "corpse adds one item without default loadout duplicates")
	_assert_eq(candidate.outdoor_map().corpse_states().size(), 1, "one CorpseState reconstructs")
	var corpse: CorpseState = candidate.outdoor_map().corpse_states()[0]
	var corpse_snapshot: Values.CorpseSnapshot = snapshot.corpses[0]
	_assert_eq(corpse.corpse_item_instance_id, corpse_snapshot.corpse_item_instance_id, "corpse stable ItemInstanceId survives")
	_assert_eq(corpse.victim_character_id, fat.character_id, "corpse victim identity cross-reference survives")
	_assert_eq(corpse.worn_item_in_slot(&"cloth"), corpse_snapshot.worn_items[0].item_instance_id, "corpse worn projection restores without Wear replay")
	_assert_true(candidate.outdoor_map().corpse_view_for(corpse.corpse_item_instance_id) != null, "fresh CorpseView binds after domain validation")
	_assert_true(_all_areas_disabled(candidate.outdoor_map()), "fresh CorpseView Area remains disabled while staged")
	_assert_eq(candidate.outdoor_map().corpse_view_for(corpse.corpse_item_instance_id).global_position, Vector2(corpse_snapshot.map_position.x, corpse_snapshot.map_position.y), "corpse exact position survives")
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)
	var direct: Array[StringName] = candidate.inventory_state().direct_children(corpse_endpoint)
	_assert_eq(direct.size(), 2, "corpse direct contents restore separately from nested contents")
	var short_sword_id: StringName = _loadout_id_for_definition(snapshot, fat_snapshot, OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID)
	var silver_id: StringName = _loadout_id_for_definition(snapshot, fat_snapshot, OldPineNpcDefinitions.SILVER_ITEM_ID)
	_assert_true(candidate.inventory_state().is_direct_child(silver_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, short_sword_id)), "nested corpse content parent survives")
	_assert_true(fat.character_state.equipment == result.preparation.item_domain.equipment_state(fat.character_id), "dead runtime receives exact restored empty EquipmentState")
	_assert_true(fat.armor == result.preparation.item_domain.armor_state(fat.character_id), "dead runtime receives exact restored empty ArmorState")
	_free_node(candidate)
	await tree.process_frame


func _test_strict_position_and_cross_reference_failures(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1201, 1202, 1203)
	var base: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	var corpse_snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.with_fat_bandit_corpse(base)
	_free_node(source)
	await tree.process_frame

	var wrong_zone_player: Values.PlayerRuntimeSnapshot = _player_with_location(
		base.player,
		Values.WorldLocationSnapshot.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID,
			OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID,
		),
		base.player.map_position,
	)
	var wrong_zone: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_copy_snapshot(base, wrong_zone_player), tree.root,
	)
	_assert_eq(wrong_zone.outcome, OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "wrong saved zone fails without fallback")
	_assert_true(wrong_zone.candidate == null, "invalid position exposes no partial candidate")

	var collision_player: Values.PlayerRuntimeSnapshot = _player_with_location(
		base.player,
		Values.WorldLocationSnapshot.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID,
			OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID,
		),
		Values.MapPositionSnapshot.new(125.0, -180.0),
	)
	var collision: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_copy_snapshot(base, collision_player), tree.root,
	)
	_assert_eq(collision.outcome, OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "collision coordinate fails strictly")

	var missing_corpse_item: GameSaveSnapshot = GameSaveSnapshot.new(
		corpse_snapshot.metadata, corpse_snapshot.session_kind,
		corpse_snapshot.item_id_allocator, corpse_snapshot.player,
		corpse_snapshot.npc_spawn_states, corpse_snapshot.corpses,
		base.items, corpse_snapshot.combat_rng,
		corpse_snapshot.npc_initialization_rng,
		corpse_snapshot.world_interaction_rng,
	)
	var missing: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		missing_corpse_item, tree.root,
	)
	_assert_eq(missing.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_CORPSE_STATE, "missing corpse item cross-reference fails")
	_assert_true(missing.candidate == null, "corpse failure discards fresh reconstruction")

	var incomplete_npcs: Array[Values.NpcSpawnStateSnapshot] = base.npc_spawn_states
	incomplete_npcs.remove_at(incomplete_npcs.size() - 1)
	var incomplete: GameSaveSnapshot = GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		incomplete_npcs, [], base.items, base.combat_rng,
		base.npc_initialization_rng, base.world_interaction_rng,
	)
	var incomplete_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(incomplete, tree.root)
	)
	_assert_eq(incomplete_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "missing authored spawn slot fails")
	_assert_true(incomplete_result.candidate == null, "spawn-ledger failure exposes no candidate")


func _test_cave_restore_and_candidate_activation(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1301, 1302, 1303)
	var cave_location: Values.WorldLocationSnapshot = Values.WorldLocationSnapshot.new(
		OldPineWorldDefinitions.REGION_ID,
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
	)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(
		source,
		cave_location,
		Values.MapPositionSnapshot.new(0.0, 120.0),
	)
	_free_node(source)
	await tree.process_frame
	var result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	_assert_eq(result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "Cave save constructs a candidate")
	var candidate: OldPineWorldSessionController = result.candidate
	_assert_eq(candidate.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "Cave activity derives solely from Player map")
	_assert_true(candidate.cave_map().get_parent() == candidate.active_map_slot, "Cave alone is attached")
	_assert_true(candidate.outdoor_map().get_parent() == null, "restored Outdoor remains detached/frozen")
	_assert_eq(candidate.outdoor_map().process_mode, Node.PROCESS_MODE_DISABLED, "inactive restored Outdoor remains frozen")
	_assert_eq(candidate.outdoor_map().npc_runtimes().size(), 5, "inactive Outdoor retains restored NPC ledger")
	_assert_eq(candidate.cave_map().player_body.global_position, Vector2(0.0, 120.0), "Cave Player exact position survives")
	_assert_false(candidate.cave_map().player_body.player_controlled, "staged Cave input is disabled")
	_assert_true(_all_areas_disabled(candidate.cave_map()), "staged Cave Areas are disabled")
	_assert_random_equal(candidate.combat_random_source().capture_random_state(), snapshot.combat_rng, "Cave restore leaves Combat RNG unchanged")
	_assert_random_equal(candidate.npc_random_source().capture_random_state(), snapshot.npc_initialization_rng, "Cave restore leaves NPC RNG unchanged")
	_assert_random_equal(candidate.world_interaction_random_source().capture_random_state(), snapshot.world_interaction_rng, "Cave restore leaves World RNG unchanged")
	_assert_true(candidate.activate_restore_candidate(), "QA-only candidate activation succeeds")
	_assert_false(candidate.is_restore_candidate_staged(), "activated candidate leaves staging")
	_assert_true(candidate.cave_map().player_body.player_controlled, "activated restored Player accepts gameplay input")
	_assert_true((candidate.cave_map().player_body.get_node("Camera2D") as Camera2D).enabled, "activated restored camera owns the view")
	_assert_true(candidate.cave_map().south_exit.monitoring, "activated authored Area monitoring resumes")
	_free_node(candidate)
	await tree.process_frame


func _test_new_game_regression(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new_game(tree, 1401, 1402, 1403)
	_assert_eq(session.bootstrap_mode(), OldPineWorldSessionController.BootstrapMode.NEW_GAME, "default Session remains NEW_GAME")
	_assert_eq(session.inventory_state().registered_item_ids().size(), 12, "NEW_GAME still creates twelve bootstrap items")
	_assert_eq(session.outdoor_map().npc_runtimes().size(), 5, "NEW_GAME still creates five authored NPCs")
	_assert_eq(session.outdoor_map().corpse_states().size(), 0, "NEW_GAME creates no corpse")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "NEW_GAME still starts Outdoor")
	_assert_true(session.outdoor_map().player_body.player_controlled, "NEW_GAME control remains active")
	_assert_eq(session.item_id_allocator().next_dynamic_sequence, 0, "NEW_GAME bootstrap consumes no dynamic ID")
	_free_node(session)
	await tree.process_frame


func _new_game(
	tree: SceneTree,
	npc_seed: int,
	combat_seed: int,
	world_seed: int,
) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.deterministic_npc_seed = true
	session.npc_seed = npc_seed
	session.deterministic_combat_seed = true
	session.combat_seed = combat_seed
	session.deterministic_world_interaction_seed = true
	session.world_interaction_seed = world_seed
	tree.root.add_child(session)
	return session


func _copy_snapshot(
	base: GameSaveSnapshot,
	player: Values.PlayerRuntimeSnapshot,
) -> GameSaveSnapshot:
	return GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, player,
		base.npc_spawn_states, base.corpses, base.items, base.combat_rng,
		base.npc_initialization_rng, base.world_interaction_rng,
	)


func _player_with_location(
	base: Values.PlayerRuntimeSnapshot,
	location: Values.WorldLocationSnapshot,
	position: Values.MapPositionSnapshot,
) -> Values.PlayerRuntimeSnapshot:
	return Values.PlayerRuntimeSnapshot.new(
		base.character_id, base.character, base.life_status,
		base.exists_in_world, base.combat_available, base.maximum_encumbrance,
		location, position,
	)


func _npc_by_definition(
	snapshot: GameSaveSnapshot,
	definition_id: StringName,
) -> Values.NpcSpawnStateSnapshot:
	for npc: Values.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		if npc.npc_definition_id == definition_id:
			return npc
	return null


func _loadout_id_for_definition(
	snapshot: GameSaveSnapshot,
	npc: Values.NpcSpawnStateSnapshot,
	definition_id: StringName,
) -> StringName:
	for item_id: StringName in npc.live_loadout_item_ids:
		for record: NativeItemRecord in snapshot.items.item_records:
			if record.item_instance_id == item_id and record.item_definition_id == definition_id:
				return item_id
	return &""


func _body_for(
	outdoor: OldPineOutdoorController,
	character_id: StringName,
) -> WorldCharacterBody2D:
	for node: Node in outdoor.get_node("Characters").get_children():
		var body: WorldCharacterBody2D = node as WorldCharacterBody2D
		if body != null and body.character_id == character_id:
			return body
	return null


func _all_areas_disabled(root: Node) -> bool:
	for node: Node in root.find_children("*", "Area2D", true, false):
		var area: Area2D = node as Area2D
		if area != null and (area.monitoring or area.monitorable or area.input_pickable):
			return false
	return true


func _assert_random_equal(
	actual: RandomStreamSnapshot,
	expected: RandomStreamSnapshot,
	message: String,
) -> void:
	_assert_true(
		actual.adapter_id == expected.adapter_id
		and actual.seed == expected.seed
		and actual.state == expected.state,
		message,
	)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
