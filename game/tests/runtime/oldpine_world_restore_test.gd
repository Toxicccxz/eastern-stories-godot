extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const OldPineWorldSaveFixture := preload(
	"res://tests/support/oldpine_world_save_fixture.gd"
)
const GameSaveTestFixture := preload(
	"res://tests/support/game_save_test_fixture.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_character_reconstruction_exact()
	await _test_outdoor_restore_and_identity_injection(tree)
	await _test_unconscious_lifecycle_restores_independently(tree)
	await _test_dead_tombstone_and_corpse_graph(tree)
	await _test_player_death_corpse_graph(tree)
	await _test_spawn_ledger_adversarial_cases(tree)
	await _test_strict_position_and_cross_reference_failures(tree)
	await _test_all_or_nothing_failure_matrix(tree)
	await _test_cave_restore_and_candidate_activation(tree)
	await _test_new_game_regression(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_character_reconstruction_exact() -> void:
	var snapshot: Values.CharacterStateSnapshot = (
		GameSaveTestFixture.substantial().player.character
	)
	var equipment: EquipmentState = EquipmentState.new()
	var state: CharacterState = CharacterStateSnapshotRestorer.restore(
		snapshot,
		equipment,
	)
	_assert_true(state != null, "substantial CharacterState snapshot restores")
	_assert_true(state.equipment == equipment, "Character restore injects the exact EquipmentState")
	_assert_eq(state.gender, &"女性", "gender restores exactly")
	_assert_eq(state.attributes.strength, 21, "strength restores exactly")
	_assert_eq(state.attributes.karma, 28, "karma restores exactly")
	_assert_eq(state.attributes.force_factor, -3, "force factor restores without clamping")
	_assert_eq(state.attributes.bellicosity, 151, "bellicosity restores exactly")
	_assert_eq(state.essence.current, 91, "gin current restores exactly")
	_assert_eq(state.essence.effective, 93, "gin effective restores exactly")
	_assert_eq(state.essence.maximum, 100, "gin maximum restores exactly")
	_assert_eq(state.vitality.current, 82, "kee current restores exactly")
	_assert_eq(state.spirit.current, -1, "legacy negative sen current restores exactly")
	_assert_eq(state.recovery.inner_force.current, 45, "force current restores exactly")
	_assert_eq(state.recovery.mana.current, -2, "legacy negative mana restores exactly")
	_assert_eq(state.recovery.atman.maximum, 90, "max_atman restores exactly")
	_assert_eq(state.recovery.food, 1234, "food restores exactly")
	_assert_eq(state.recovery.water, -5, "legacy negative water restores exactly")
	_assert_eq(state.progression.combat_experience, 9223372036854775807, "int64 progression restores losslessly")
	_assert_eq(state.progression.potential, 5432, "potential restores exactly")
	_assert_eq(state.progression.potential_spent, -9, "legacy negative potential spent restores exactly")
	_assert_eq(state.skills.raw_level(&"force"), 37, "raw skill restores")
	_assert_eq(state.skills.learned_progress(&"force"), 88, "learned progress restores")
	_assert_eq(state.skills.mapped_skill(&"force"), &"force", "skill mapping restores after raw target")
	_assert_true(state.skills.remove_skill(&"missing"), "present skills mapping remains observably present")
	_assert_eq(state.conditions.size(), 2, "typed condition collection restores exactly")
	var bandaged: DurationConditionPayload = state.conditions.get_condition(&"bandaged") as DurationConditionPayload
	var poison: PoisonConditionPayload = state.conditions.get_condition(&"open-poison") as PoisonConditionPayload
	_assert_true(bandaged != null and bandaged.remaining == 3, "duration condition payload restores exactly")
	_assert_true(poison != null and poison.damage == 11 and poison.remaining == -1 and poison.legacy_message == "毒性仍在。", "poison condition payload restores exactly")
	_assert_eq(state.family.family_id, &"family:oldpine", "family identity restores")
	_assert_eq(state.family.generation, 4, "family generation restores")
	_assert_eq(state.apprenticeship.master_teacher_id, &"teacher:master", "master identity restores")
	_assert_eq(state.apprenticeship.legacy_master_name, "師父", "legacy master name restores")
	_assert_eq(state.apprenticeship.betrayer_count, 2, "betrayer count restores")

	var absent_skills: Values.SkillStateSnapshot = Values.SkillStateSnapshot.new(
		false, false, [], [], [],
	)
	var absent_snapshot: Values.CharacterStateSnapshot = Values.CharacterStateSnapshot.new(
		snapshot.gender, snapshot.attributes, snapshot.gin, snapshot.kee,
		snapshot.sen, snapshot.internal_resources, snapshot.progression,
		absent_skills, snapshot.conditions, snapshot.family,
		snapshot.apprenticeship,
	)
	var absent_state: CharacterState = CharacterStateSnapshotRestorer.restore(
		absent_snapshot,
		EquipmentState.new(),
	)
	_assert_true(absent_state != null, "absent skill mappings restore")
	_assert_false(absent_state.skills.remove_skill(&"missing"), "absent skills mapping remains observably absent")


func _test_outdoor_restore_and_identity_injection(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1001, 1002, 1003)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	_assert_true(snapshot != null, "fixture captures a complete New Game graph")
	var source_scope: StringName = snapshot.item_id_allocator.scope
	var source_player_object_id: int = source.player_runtime().get_instance_id()
	var source_state_object_id: int = source.player_runtime().state.get_instance_id()
	var source_body_object_id: int = source.outdoor_map().player_body.get_instance_id()
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
	_assert_eq(candidate.process_mode, Node.PROCESS_MODE_DISABLED, "staged Session processing is disabled")
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
	_assert_true(player.get_instance_id() != source_player_object_id, "restored Player runtime has fresh Godot identity")
	_assert_true(player.state.get_instance_id() != source_state_object_id, "restored CharacterState has fresh Godot identity")
	_assert_true(candidate.outdoor_map().player_body.get_instance_id() != source_body_object_id, "restored Player body has fresh Godot identity")
	_assert_eq(candidate.outdoor_map().player_body.character_id, snapshot.player.character_id, "fresh Player body binds by stable CharacterId")
	_assert_true(player.state.equipment == result.preparation.item_domain.equipment_state(player.character_id), "Player receives exact Phase 10B2 EquipmentState")
	_assert_true(player.armor == result.preparation.item_domain.armor_state(player.character_id), "Player receives exact Phase 10B2 ArmorState")
	_assert_eq(player.state.skills.raw_level(&"force"), snapshot.player.character.skills.raw_levels[0].value, "raw skill restores before mapping")
	_assert_eq(player.state.skills.mapped_skill(&"force"), &"force", "skill mapping restores against raw target")
	_assert_eq(player.state.skills.learned_progress(&"force"), 7, "learned progress restores exactly")
	_assert_eq(candidate.outdoor_map().player_body.global_position, Vector2(snapshot.player.map_position.x, snapshot.player.map_position.y), "Player exact map-local position survives")
	_assert_false(candidate.outdoor_map().player_body.player_controlled, "staged Player control stays disabled")
	_assert_false((candidate.outdoor_map().player_body.get_node("Camera2D") as Camera2D).enabled, "staged camera stays disabled")
	_assert_true(_all_areas_disabled(candidate.outdoor_map()), "staged authored Areas are disabled")
	_assert_true(_all_areas_disabled(candidate.cave_map()), "detached resident Areas remain disabled")
	_assert_true(candidate.outdoor_map().opportunity_timer.is_stopped(), "staged combat cadence is stopped")
	_assert_eq(candidate.outdoor_map().aggression_adapter().pending_count(), 0, "staged restore has no pending aggression observation")
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
	_assert_eq(_body_count_for(candidate.outdoor_map(), fat.character_id), 1, "dead spawn slot binds exactly one authored body")
	var second_result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		snapshot,
		tree.root,
	)
	_assert_eq(second_result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "same semantic save reconstructs an independent second graph")
	var second_candidate: OldPineWorldSessionController = second_result.candidate
	_assert_true(second_candidate.outdoor_map().player_body.get_instance_id() != candidate.outdoor_map().player_body.get_instance_id(), "independent restores do not share Player body objects")
	_assert_true(second_candidate.outdoor_map().corpse_view_for(corpse.corpse_item_instance_id).get_instance_id() != candidate.outdoor_map().corpse_view_for(corpse.corpse_item_instance_id).get_instance_id(), "independent restores do not share CorpseView objects")
	_assert_eq(second_candidate.outdoor_map().corpse_states()[0].corpse_item_instance_id, corpse.corpse_item_instance_id, "fresh corpse objects retain the same semantic ItemInstanceId")
	_free_node(second_candidate)
	_free_node(candidate)
	await tree.process_frame


func _test_player_death_corpse_graph(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1151, 1152, 1153)
	var base: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.with_player_corpse(base)
	_assert_true(snapshot != null, "Player corpse fixture represents current death facts")
	_free_node(source)
	await tree.process_frame
	var result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		snapshot,
		tree.root,
	)
	_assert_eq(result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "dead Player/corpse snapshot restores")
	var candidate: OldPineWorldSessionController = result.candidate
	var player: WorldPlayerRuntimeState = candidate.player_runtime()
	_assert_eq(player.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "Player committed DEAD status restores")
	_assert_false(player.exists_in_world, "dead Player remains absent from the world")
	_assert_false(candidate.outdoor_map().player_body.visible, "dead Player body is not active presentation")
	_assert_eq(candidate.outdoor_map().corpse_states().size(), 1, "Player victim creates exactly one restored corpse")
	var corpse_snapshot: Values.CorpseSnapshot = snapshot.corpses[0]
	var corpse: CorpseState = candidate.outdoor_map().corpse_states()[0]
	_assert_eq(corpse.victim_character_id, snapshot.player.character_id, "Player CharacterId is a valid corpse victim")
	_assert_eq(corpse.victim_age, 20, "Player corpse uses the current runtime death age")
	_assert_eq(corpse.corpse_item_instance_id, corpse_snapshot.corpse_item_instance_id, "Player corpse semantic ID survives")
	_assert_eq(candidate.inventory_state().registered_item_ids().size(), 13, "Player corpse restore creates no duplicate defaults")
	_assert_true(player.state.equipment == result.preparation.item_domain.equipment_state(player.character_id), "dead Player receives exact restored EquipmentState")
	_assert_true(player.armor == result.preparation.item_domain.armor_state(player.character_id), "dead Player receives exact restored ArmorState")

	var wrong_age: Values.CorpseSnapshot = Values.CorpseSnapshot.new(
		corpse_snapshot.corpse_item_instance_id,
		corpse_snapshot.victim_character_id,
		corpse_snapshot.victim_display_name,
		corpse_snapshot.victim_gender,
		21,
		corpse_snapshot.decay_stage,
		corpse_snapshot.maximum_contents_encumbrance,
		corpse_snapshot.worn_items,
		corpse_snapshot.world_location,
		corpse_snapshot.map_position,
	)
	var wrong_age_snapshot: GameSaveSnapshot = GameSaveSnapshot.new(
		snapshot.metadata, snapshot.session_kind, snapshot.item_id_allocator,
		snapshot.player, snapshot.npc_spawn_states, [wrong_age], snapshot.items,
		snapshot.combat_rng, snapshot.npc_initialization_rng,
		snapshot.world_interaction_rng,
	)
	var wrong_age_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(wrong_age_snapshot, tree.root)
	)
	_assert_eq(wrong_age_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_CORPSE_STATE, "Player corpse age is validated against runtime death semantics")
	_assert_true(wrong_age_result.candidate == null, "invalid Player corpse exposes no candidate")
	_free_node(candidate)
	await tree.process_frame


func _test_spawn_ledger_adversarial_cases(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1171, 1172, 1173)
	var base: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(source)
	var corpse_base: GameSaveSnapshot = OldPineWorldSaveFixture.with_fat_bandit_corpse(base)
	_free_node(source)
	await tree.process_frame
	var original: Values.NpcSpawnStateSnapshot = base.npc_spawn_states[0]

	var duplicate_npcs: Array[Values.NpcSpawnStateSnapshot] = base.npc_spawn_states
	duplicate_npcs.append(original)
	var duplicate_result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_snapshot_with_npcs(base, duplicate_npcs), tree.root,
	)
	_assert_eq(duplicate_result.outcome, OldPineWorldRestoreResult.Outcome.INVALID_SNAPSHOT, "duplicate spawn-point slot is rejected")
	_assert_true(duplicate_result.candidate == null, "duplicate slot exposes no candidate")

	var wrong_definition: Values.NpcSpawnStateSnapshot = _npc_copy(
		original, original.spawn_id, &"unknown.npc", original.character_id,
		original.world_location, original.live_loadout_item_ids,
	)
	var wrong_definition_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_replacing_npc(base, 0, wrong_definition), tree.root,
		)
	)
	_assert_eq(wrong_definition_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "wrong NPC definition is rejected")

	var wrong_character: Values.NpcSpawnStateSnapshot = _npc_copy(
		original, original.spawn_id, original.npc_definition_id,
		&"wrong.character", original.world_location,
		original.live_loadout_item_ids,
	)
	var wrong_character_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_replacing_npc(base, 0, wrong_character), tree.root,
		)
	)
	_assert_eq(wrong_character_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "wrong authored CharacterId is rejected")

	var cave_location: Values.WorldLocationSnapshot = Values.WorldLocationSnapshot.new(
		OldPineWorldDefinitions.REGION_ID,
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
	)
	var wrong_location: Values.NpcSpawnStateSnapshot = _npc_copy(
		original, original.spawn_id, original.npc_definition_id,
		original.character_id, cave_location, original.live_loadout_item_ids,
	)
	var wrong_location_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_replacing_npc(base, 0, wrong_location), tree.root,
		)
	)
	_assert_eq(wrong_location_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "NPC in wrong authored map is rejected")

	var player_weapon_id: StringName = _equipment_primary_for(
		base,
		base.player.character_id,
	)
	var wrong_loadout: Values.NpcSpawnStateSnapshot = _npc_copy(
		original, original.spawn_id, original.npc_definition_id,
		original.character_id, original.world_location, [player_weapon_id],
	)
	var wrong_loadout_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_replacing_npc(base, 0, wrong_loadout), tree.root,
		)
	)
	_assert_eq(wrong_loadout_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "wrong NPC loadout reference is rejected")

	var incomplete_live: Values.NpcSpawnStateSnapshot = _npc_copy(
		original, original.spawn_id, original.npc_definition_id,
		original.character_id, original.world_location,
		[original.live_loadout_item_ids[0]],
	)
	var incomplete_live_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_replacing_npc(base, 0, incomplete_live), tree.root,
		)
	)
	_assert_eq(incomplete_live_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "living NPC requires complete authored loadout")

	var dead_fat: Values.NpcSpawnStateSnapshot = _npc_by_definition(
		corpse_base,
		OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID,
	)
	var surviving_subset: Array[StringName] = [dead_fat.live_loadout_item_ids[0]]
	var partial_dead: Values.NpcSpawnStateSnapshot = Values.NpcSpawnStateSnapshot.new(
		dead_fat.spawn_id, dead_fat.spawn_point_id, dead_fat.npc_definition_id,
		dead_fat.character_id, false, &"dead", dead_fat.combat_available,
		dead_fat.character, dead_fat.age, dead_fat.body_weight,
		dead_fat.maximum_encumbrance, dead_fat.world_location,
		dead_fat.map_position, surviving_subset,
	)
	var dead_index: int = _npc_index_by_character(corpse_base, dead_fat.character_id)
	var partial_dead_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_replacing_npc(corpse_base, dead_index, partial_dead),
			tree.root,
		)
	)
	_assert_eq(partial_dead_result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "dead tombstone accepts represented surviving loadout subset")
	_assert_eq(partial_dead_result.candidate.outdoor_map().npc_runtimes().size(), 5, "partial dead loadout still occupies exactly one authored slot")
	_assert_false(_body_for(partial_dead_result.candidate.outdoor_map(), dead_fat.character_id).visible, "dead tombstone body remains inactive")
	_free_node(partial_dead_result.candidate)

	var empty_tombstone_snapshot: GameSaveSnapshot = (
		_dead_fat_tombstone_without_items(base)
	)
	var empty_tombstone_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			empty_tombstone_snapshot,
			tree.root,
		)
	)
	_assert_eq(empty_tombstone_result.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "dead tombstone restores after every former loadout item is gone")
	_assert_eq(empty_tombstone_result.candidate.outdoor_map().npc_runtimes().size(), 5, "itemless dead tombstone remains in the five-slot ledger")
	_assert_eq(empty_tombstone_result.candidate.outdoor_map().corpse_states().size(), 0, "dead tombstone does not require a surviving corpse")
	_assert_eq(empty_tombstone_result.candidate.inventory_state().registered_item_ids().size(), 9, "destroyed former loadout items are not recreated")
	_assert_false(_body_for(empty_tombstone_result.candidate.outdoor_map(), dead_fat.character_id).visible, "itemless tombstone never respawns its body")
	_free_node(empty_tombstone_result.candidate)
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

	var boundary_player: Values.PlayerRuntimeSnapshot = _player_with_location(
		base.player,
		Values.WorldLocationSnapshot.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
			OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		),
		Values.MapPositionSnapshot.new(450.0, 0.0),
	)
	var boundary_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_copy_snapshot(base, boundary_player), tree.root,
		)
	)
	_assert_eq(boundary_result.outcome, OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "exact touching-zone boundary is not silently assigned")

	var outside_player: Values.PlayerRuntimeSnapshot = _player_with_location(
		base.player,
		base.player.world_location,
		Values.MapPositionSnapshot.new(5000.0, 5000.0),
	)
	var outside_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_copy_snapshot(base, outside_player), tree.root,
		)
	)
	_assert_eq(outside_result.outcome, OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "position outside every zone is rejected")

	var corpse: Values.CorpseSnapshot = corpse_snapshot.corpses[0]
	var wrong_victim: Values.CorpseSnapshot = Values.CorpseSnapshot.new(
		corpse.corpse_item_instance_id, corpse_snapshot.player.character_id,
		corpse.victim_display_name, corpse.victim_gender, corpse.victim_age,
		corpse.decay_stage, corpse.maximum_contents_encumbrance,
		corpse.worn_items, corpse.world_location, corpse.map_position,
	)
	var wrong_victim_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_with_corpses(corpse_snapshot, [wrong_victim]), tree.root,
		)
	)
	_assert_eq(wrong_victim_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_CORPSE_STATE, "corpse victim must resolve to the dead non-existent character")

	var wrong_worn: Values.CorpseSnapshot = Values.CorpseSnapshot.new(
		corpse.corpse_item_instance_id, corpse.victim_character_id,
		corpse.victim_display_name, corpse.victim_gender, corpse.victim_age,
		corpse.decay_stage, corpse.maximum_contents_encumbrance,
		[Values.CorpseWornItemSnapshot.new(&"armor", corpse.worn_items[0].item_instance_id)],
		corpse.world_location, corpse.map_position,
	)
	var wrong_worn_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_with_corpses(corpse_snapshot, [wrong_worn]), tree.root,
		)
	)
	_assert_eq(wrong_worn_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_CORPSE_STATE, "corpse worn projection type is cross-validated")

	var invalid_decay: Values.CorpseSnapshot = Values.CorpseSnapshot.new(
		corpse.corpse_item_instance_id, corpse.victim_character_id,
		corpse.victim_display_name, corpse.victim_gender, corpse.victim_age,
		CorpseState.Stage.FINAL + 1, corpse.maximum_contents_encumbrance,
		corpse.worn_items, corpse.world_location, corpse.map_position,
	)
	var invalid_decay_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_with_corpses(corpse_snapshot, [invalid_decay]), tree.root,
		)
	)
	_assert_eq(invalid_decay_result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_CORPSE_STATE, "out-of-domain corpse decay stage is rejected")

	var invalid_corpse_position: Values.CorpseSnapshot = Values.CorpseSnapshot.new(
		corpse.corpse_item_instance_id, corpse.victim_character_id,
		corpse.victim_display_name, corpse.victim_gender, corpse.victim_age,
		corpse.decay_stage, corpse.maximum_contents_encumbrance,
		corpse.worn_items, corpse.world_location,
		Values.MapPositionSnapshot.new(125.0, -180.0),
	)
	var invalid_corpse_position_result: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_snapshot_with_corpses(corpse_snapshot, [invalid_corpse_position]),
			tree.root,
		)
	)
	_assert_eq(invalid_corpse_position_result.outcome, OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "corpse uses its own footprint for collision validation")

	var overlap_session: OldPineWorldSessionController = _new_game(
		tree, 1211, 1212, 1213,
	)
	var overlap_map: OldPineOutdoorController = overlap_session.outdoor_map()
	var south_zone: Area2D = overlap_map.get_node("Zones/SouthSlopeZone") as Area2D
	south_zone.global_position = Vector2(450.0, 300.0)
	_assert_false(
		OldPineMapPlacementValidator.is_valid_character_position(
			overlap_map,
			OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
			Vector2(450.0, 300.0),
		),
		"position belonging to two zones is rejected as ambiguous",
	)
	_free_node(overlap_session)
	await tree.process_frame


func _test_all_or_nothing_failure_matrix(tree: SceneTree) -> void:
	var current: OldPineWorldSessionController = _new_game(tree, 1251, 1252, 1253)
	var base: GameSaveSnapshot = OldPineWorldSaveFixture.from_new_game(current)
	var current_player: WorldPlayerRuntimeState = current.player_runtime()
	var current_inventory: InventoryState = current.inventory_state()
	var current_outdoor: OldPineOutdoorController = current.outdoor_map()
	var current_position: Vector2 = current_outdoor.player_body.global_position
	var current_root_children: int = tree.root.get_child_count()
	var current_combat_rng: RandomStreamSnapshot = current.combat_random_source().capture_random_state()
	var current_npc_rng: RandomStreamSnapshot = current.npc_random_source().capture_random_state()
	var current_world_rng: RandomStreamSnapshot = current.world_interaction_random_source().capture_random_state()

	var contradictory_player: Values.PlayerRuntimeSnapshot = Values.PlayerRuntimeSnapshot.new(
		base.player.character_id, base.player.character, &"dead", true,
		base.player.combat_available, base.player.maximum_encumbrance,
		base.player.world_location, base.player.map_position,
	)
	var root_failure: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_copy_snapshot(base, contradictory_player), tree.root,
	)
	_assert_eq(root_failure.outcome, OldPineWorldRestoreResult.Outcome.INVALID_SNAPSHOT, "dead/existing root contradiction fails typed validation")
	_assert_true(root_failure.candidate == null, "root failure exposes no candidate")

	var altered_records: Array[NativeItemRecord] = base.items.item_records
	var first_record: NativeItemRecord = altered_records[0]
	altered_records[0] = NativeItemRecord.new(
		first_record.item_instance_id, &"unknown.item.definition",
		first_record.own_weight, first_record.direct_parent,
	)
	var invalid_items: NativeItemStateSnapshot = NativeItemStateSnapshot.new(
		base.items.schema_version, altered_records,
		base.items.combined_stack_records,
		base.items.character_equipment_records,
		base.items.character_armor_records,
	)
	var item_failure: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_snapshot_with_items(base, invalid_items), tree.root,
	)
	_assert_eq(item_failure.outcome, OldPineWorldRestoreResult.Outcome.ITEM_RESTORE_FAILED, "item reconstruction failure is typed")
	_assert_true(item_failure.candidate == null, "item failure exposes no candidate")

	var wrong_capacity_player: Values.PlayerRuntimeSnapshot = Values.PlayerRuntimeSnapshot.new(
		base.player.character_id, base.player.character, base.player.life_status,
		base.player.exists_in_world, base.player.combat_available,
		base.player.maximum_encumbrance + 1, base.player.world_location,
		base.player.map_position,
	)
	var character_failure: OldPineWorldRestoreResult = (
		OldPineWorldRestoreService.build_candidate(
			_copy_snapshot(base, wrong_capacity_player), tree.root,
		)
	)
	_assert_eq(character_failure.outcome, OldPineWorldRestoreResult.Outcome.CHARACTER_RESTORE_FAILED, "Character derived-fact failure is typed")
	_assert_true(character_failure.candidate == null, "Character failure exposes no candidate")

	var missing_npcs: Array[Values.NpcSpawnStateSnapshot] = base.npc_spawn_states
	missing_npcs.remove_at(0)
	var ledger_failure: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_snapshot_with_npcs(base, missing_npcs), tree.root,
	)
	_assert_eq(ledger_failure.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "NPC ledger failure is typed")
	_assert_true(ledger_failure.candidate == null, "NPC ledger failure exposes no candidate")

	var invalid_rng_snapshot: GameSaveSnapshot = GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		base.npc_spawn_states, base.corpses, base.items,
		RandomStreamSnapshot.new(&"unsupported", 1, 2),
		base.npc_initialization_rng, base.world_interaction_rng,
	)
	var rng_failure: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		invalid_rng_snapshot, tree.root,
	)
	_assert_eq(rng_failure.outcome, OldPineWorldRestoreResult.Outcome.INVALID_SNAPSHOT, "unsupported RNG snapshot fails before reconstruction")
	_assert_true(rng_failure.candidate == null, "RNG failure exposes no candidate")

	var late_player: Values.PlayerRuntimeSnapshot = _player_with_location(
		base.player,
		Values.WorldLocationSnapshot.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID,
			OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID,
		),
		Values.MapPositionSnapshot.new(125.0, -180.0),
	)
	var late_failure: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		_copy_snapshot(base, late_player), tree.root,
	)
	_assert_eq(late_failure.outcome, OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION, "post-body-binding physical failure is typed")
	_assert_true(late_failure.candidate == null, "late body/view-stage failure discards candidate")

	_assert_true(current.player_runtime() == current_player, "failed builds do not replace current Player authority")
	_assert_true(current.inventory_state() == current_inventory, "failed builds do not replace current Inventory authority")
	_assert_true(current.outdoor_map() == current_outdoor, "failed builds do not replace current resident map")
	_assert_eq(current.inventory_state().registered_item_ids().size(), 12, "failed builds do not mutate current item graph")
	_assert_eq(current.outdoor_map().npc_runtimes().size(), 5, "failed builds do not mutate current NPC ledger")
	_assert_eq(current.outdoor_map().corpse_states().size(), 0, "failed builds do not create current corpses")
	_assert_eq(current.outdoor_map().player_body.global_position, current_position, "failed builds do not move current Player")
	_assert_true(current.outdoor_map().player_body.player_controlled, "failed builds leave current input active")
	_assert_eq(tree.root.get_child_count(), current_root_children, "failed builds leak no candidate node")
	_assert_random_equal(current.combat_random_source().capture_random_state(), current_combat_rng, "failed builds consume no current Combat RNG")
	_assert_random_equal(current.npc_random_source().capture_random_state(), current_npc_rng, "failed builds consume no current NPC RNG")
	_assert_random_equal(current.world_interaction_random_source().capture_random_state(), current_world_rng, "failed builds consume no current World RNG")
	_free_node(current)
	await tree.process_frame


func _test_cave_restore_and_candidate_activation(tree: SceneTree) -> void:
	var source: OldPineWorldSessionController = _new_game(tree, 1301, 1302, 1303)
	var cave_location: Values.WorldLocationSnapshot = Values.WorldLocationSnapshot.new(
		OldPineWorldDefinitions.REGION_ID,
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
	)
	var snapshot: GameSaveSnapshot = OldPineWorldSaveFixture.with_fat_bandit_corpse(
		OldPineWorldSaveFixture.from_new_game(
		source,
		cave_location,
		Values.MapPositionSnapshot.new(0.0, 120.0),
		),
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
	_assert_eq(candidate.outdoor_map().corpse_states().size(), 1, "inactive Outdoor retains restored corpse ledger")
	_assert_eq(candidate.inventory_state().registered_item_ids().size(), 13, "Cave-active staging retains exact restored item count")
	_assert_eq(candidate.item_id_allocator().next_dynamic_sequence, 1, "Cave-active staging retains allocator continuation")
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
	_assert_eq(candidate.inventory_state().registered_item_ids().size(), 13, "immediate activation creates no item or corpse")
	_assert_eq(candidate.outdoor_map().corpse_states().size(), 1, "immediate activation preserves the one restored corpse")
	_assert_eq(candidate.item_id_allocator().next_dynamic_sequence, 1, "immediate activation allocates no second corpse ID")
	_assert_random_equal(candidate.combat_random_source().capture_random_state(), snapshot.combat_rng, "immediate activation consumes zero Combat RNG")
	_assert_random_equal(candidate.npc_random_source().capture_random_state(), snapshot.npc_initialization_rng, "immediate activation consumes zero NPC RNG")
	_assert_random_equal(candidate.world_interaction_random_source().capture_random_state(), snapshot.world_interaction_rng, "immediate activation consumes zero World RNG")
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


func _snapshot_with_npcs(
	base: GameSaveSnapshot,
	npcs: Array[Values.NpcSpawnStateSnapshot],
) -> GameSaveSnapshot:
	return GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		npcs, base.corpses, base.items, base.combat_rng,
		base.npc_initialization_rng, base.world_interaction_rng,
	)


func _snapshot_replacing_npc(
	base: GameSaveSnapshot,
	index: int,
	npc: Values.NpcSpawnStateSnapshot,
) -> GameSaveSnapshot:
	var npcs: Array[Values.NpcSpawnStateSnapshot] = base.npc_spawn_states
	npcs[index] = npc
	return _snapshot_with_npcs(base, npcs)


func _snapshot_with_corpses(
	base: GameSaveSnapshot,
	corpses: Array[Values.CorpseSnapshot],
) -> GameSaveSnapshot:
	return GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		base.npc_spawn_states, corpses, base.items, base.combat_rng,
		base.npc_initialization_rng, base.world_interaction_rng,
	)


func _snapshot_with_items(
	base: GameSaveSnapshot,
	items: NativeItemStateSnapshot,
) -> GameSaveSnapshot:
	return GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		base.npc_spawn_states, base.corpses, items, base.combat_rng,
		base.npc_initialization_rng, base.world_interaction_rng,
	)


func _npc_copy(
	base: Values.NpcSpawnStateSnapshot,
	spawn_id: StringName,
	npc_definition_id: StringName,
	character_id: StringName,
	location: Values.WorldLocationSnapshot,
	loadout_ids: Array[StringName],
) -> Values.NpcSpawnStateSnapshot:
	return Values.NpcSpawnStateSnapshot.new(
		spawn_id, base.spawn_point_id, npc_definition_id, character_id,
		base.exists_in_world, base.life_status, base.combat_available,
		base.character, base.age, base.body_weight, base.maximum_encumbrance,
		location, base.map_position, loadout_ids,
	)


func _npc_index_by_character(
	snapshot: GameSaveSnapshot,
	character_id: StringName,
) -> int:
	for index: int in range(snapshot.npc_spawn_states.size()):
		if snapshot.npc_spawn_states[index].character_id == character_id:
			return index
	return -1


func _equipment_primary_for(
	snapshot: GameSaveSnapshot,
	character_id: StringName,
) -> StringName:
	for record: NativeCharacterEquipmentRecord in snapshot.items.character_equipment_records:
		if record.character_id == character_id:
			return record.primary_item_instance_id
	return &""


func _dead_fat_tombstone_without_items(
	base: GameSaveSnapshot,
) -> GameSaveSnapshot:
	var fat: Values.NpcSpawnStateSnapshot = _npc_by_definition(
		base,
		OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID,
	)
	var removed_ids: Dictionary[StringName, bool] = {}
	for item_id: StringName in fat.live_loadout_item_ids:
		removed_ids[item_id] = true
	var dead: Values.NpcSpawnStateSnapshot = Values.NpcSpawnStateSnapshot.new(
		fat.spawn_id, fat.spawn_point_id, fat.npc_definition_id,
		fat.character_id, false, &"dead", false, fat.character, fat.age,
		fat.body_weight, fat.maximum_encumbrance, fat.world_location,
		fat.map_position, [],
	)
	var npcs: Array[Values.NpcSpawnStateSnapshot] = base.npc_spawn_states
	npcs[_npc_index_by_character(base, fat.character_id)] = dead
	var records: Array[NativeItemRecord] = []
	for record: NativeItemRecord in base.items.item_records:
		if not removed_ids.has(record.item_instance_id):
			records.append(record)
	var stacks: Array[NativeCombinedStackRecord] = []
	for record: NativeCombinedStackRecord in base.items.combined_stack_records:
		if not removed_ids.has(record.item_instance_id):
			stacks.append(record)
	var equipment: Array[NativeCharacterEquipmentRecord] = []
	for record: NativeCharacterEquipmentRecord in base.items.character_equipment_records:
		equipment.append(
			NativeCharacterEquipmentRecord.new(record.character_id)
			if record.character_id == fat.character_id
			else record
		)
	var armor: Array[NativeCharacterArmorRecord] = []
	for record: NativeCharacterArmorRecord in base.items.character_armor_records:
		armor.append(
			NativeCharacterArmorRecord.new(record.character_id)
			if record.character_id == fat.character_id
			else record
		)
	var items: NativeItemStateSnapshot = NativeItemStateSnapshot.new(
		base.items.schema_version, records, stacks, equipment, armor,
	)
	return GameSaveSnapshot.new(
		base.metadata, base.session_kind, base.item_id_allocator, base.player,
		npcs, [], items, base.combat_rng, base.npc_initialization_rng,
		base.world_interaction_rng,
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


func _body_count_for(
	outdoor: OldPineOutdoorController,
	character_id: StringName,
) -> int:
	var result: int = 0
	for node: Node in outdoor.get_node("Characters").get_children():
		var body: WorldCharacterBody2D = node as WorldCharacterBody2D
		if body != null and body.character_id == character_id:
			result += 1
	return result


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
