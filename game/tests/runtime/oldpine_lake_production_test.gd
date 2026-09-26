extends "res://tests/runtime/combat_flee_test.gd"

const Water := preload("res://tests/runtime/snow_water_test.gd")
const Memory := preload("res://tests/runtime/game_save_repository_test.gd")

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.configure_source_entry("Lake", CharacterState.GENDER_FEMALE)
	session.deterministic_npc_seed = true
	session.deterministic_combat_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	session.set_process(false)
	var map: OldPineOutdoorController = session.outdoor_map()
	map.set_process(false)
	_check(session.is_initialized(), "Lake public composition initializes")
	_check(session.world_content_revision() == WorldContentRevision.Value.SOURCE_ENTRY_LAKE_V1, "published Lake contract")
	_check(session.active_map_id() == SnowWorldDefinitions.INN_MAP_ID, "source birth still Inn")
	_check(session.player_recovery_cadence() != null, "source recovery consumer retained")
	_check(map.npc_runtimes().size() == 10, "ten complete production slots")
	var ids: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes().slice(5):
		_check(not ids.has(npc.character_id), "distinct production serpent identity")
		ids.append(npc.character_id)
		_check(npc.definition().definition_id == OldPineNpcDefinitions.SERPENT_DEFINITION_ID, "source Beast definition")
		_check(map.runtime_body_for_character(npc.character_id)._npc == npc, "exact authored physical binding")
		_check(npc.body_weight == 62000, "source Beast body preserved")
		_check(npc.loadout_items().is_empty(), "no invented serpent loot")
	var initial_rng: int = session.npc_random_source().capture_random_state().state
	_roundtrip(tree, session, "birth")
	# Typed setup for integration, not a claim of player traversal/cold restart.
	_check(session.handoff_to(map.map_id(), OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID, &"oldpine.outdoor.north_approach.snow_entry").succeeded(), "resident Outdoor activation")
	_check(map.initialization_count() == 1, "activation never respawns")
	_check(session.npc_random_source().capture_random_state().state == initial_rng, "handoff consumes no NPC draws")
	for y: float in [2199.0, 2200.0, 2201.0]:
		var expected: StringName = OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID if y < 2200 else OldPineWorldDefinitions.LAKE_ZONE_ID
		_check(map.lake_route_zone_at(Vector2(1440, y)) == expected, "half-open river/Lake center ownership " + str(y))
		_check(OldPineMapPlacementValidator.is_valid_character_position(map, expected, Vector2(1440, y)), "seam is walkable and save-valid " + str(y))
	for position: Vector2 in [Vector2(1090,2625), Vector2(1510,2600), Vector2(1200,3020)]:
		_check(not OldPineMapPlacementValidator.is_valid_character_position(map, OldPineWorldDefinitions.LAKE_ZONE_ID, position), "water/perimeter rejected " + str(position))
	_place(session, Vector2(1440,2199))
	_check(map.process_pending_aggression().is_empty(), "river never pulls Lake enemies")
	_place(session, Vector2(1390,2520))
	var starts: Array[CombatSliceInitiationResult] = map.process_pending_aggression()
	_check(starts.size() == 1, "one production complete-set admission")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter(), "production contact starts encounter")
	if coordinator.has_active_encounter():
		var encounter: CombatEncounter = coordinator.active_encounter()
		_check(encounter.participants().size() == 6, "all five actual contacts included")
		_check(coordinator.change_player_target(CombatTargetRequest.new(encounter.encounter_id, session.player_runtime().character_id, ids[4])).code == CombatTargetResult.Code.CHANGED, "fifth production target accepted")
		_flee(session)
		_check(map.process_pending_aggression().is_empty(), "thaw cannot replay consumed contacts")
	_place(session, Vector2(1440,2199))
	map._process(0) # World-owned observation of actual separation.
	_place(session, Vector2(1390,2520))
	_check(map.select_npc(ids[4]), "manual fifth selection")
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "manual production entry")
	if coordinator.has_active_encounter():
		_check(coordinator.active_encounter().participants().size() == 6, "manual entry cannot isolate fifth")
		# Representative lifecycle setup; use the existing scheduler/death authority.
		var fifth: NpcRuntimeState = map.npc_runtimes()[9]
		fifth.character_state.vitality.current = -1
		fifth.character_state.vitality.effective = -1
		for npc: NpcRuntimeState in map.npc_runtimes().slice(5):
			npc.busy.start_busy(20)
		coordinator.advance_scheduler(0)
		_check(fifth.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "fifth death retained in production slot")
		_check(map.corpse_states().size() == 1, "independent production corpse")
		_flee(session)
		for npc: NpcRuntimeState in map.npc_runtimes().slice(5):
			while npc.busy.busy_value > 0: npc.busy.advance()
			npc.busy.advance()
	map.npc_runtimes()[5].character_state.vitality.current = 1000
	map.npc_runtimes()[5].character_state.vitality.effective = 1500
	_place(session, Vector2(1100,2325))
	_roundtrip(tree, session, "wounded/dead/corpse")
	# Supply fixture uses the existing source purchase service, no new liquid engine.
	var ctx: MoneyInventoryContext = Water.Food.context(session)
	Water.Finance.add_money(ctx, Water.Food.SILVER, 1, &"lake-silver")
	Water.Finance.add_money(ctx, Water.Food.COIN, 100, &"lake-test")
	var bought: WineskinPurchaseResult = Water.purchase(session)
	_check(bought.delivered, "source wineskin purchase fixture")
	if bought.delivered:
		var panel: HeldLiquidPanel = session.get_node("HeldLiquidUI")
		panel._process(0)
		_check(session.fill_water_available(), "bounded Lake source available")
		_check(panel.request_fill().outcome == LiquidUseResult.Outcome.FILLED, "existing Fill UI path at Lake")
		_check(session.liquid_collection().state(bought.item_id).remaining == 15, "same container filled15")
		_place(session, Vector2(1440,2220))
		_check(panel.request_fill().outcome == LiquidUseResult.Outcome.NO_WATER_SOURCE, "remote Lake Fill refused")
		map.player_body.global_position = map.get_node("WaterfallWaterPoint").global_position
		map.player_body.set_world_location(map.location_for_zone(OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID))
		_check(panel.request_fill().outcome == LiquidUseResult.Outcome.FILLED, "Waterfall Fill regression")
	session.free()
	await _settle(tree, 2)
	return {"assertions": _assertions, "failures": _failures.duplicate()}

func _place(session: OldPineWorldSessionController, position: Vector2) -> void:
	var map: OldPineOutdoorController = session.outdoor_map()
	map.player_body.global_position = position
	map._sync_lake_route_location()

func _flee(session: OldPineWorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.submit_player_action(_request(session)).accepted(), "production Flee queued")
	coordinator.advance_scheduler(0)
	_check(not coordinator.has_active_encounter(), "production Flee completes")
	_check(session.world_simulation_gate().is_open(), "production world control restored")

func _roundtrip(tree: SceneTree, session: OldPineWorldSessionController, label: String) -> void:
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-26T00:00:00Z")
	_check(captured.succeeded(), label + " current capture")
	if not captured.succeeded(): return
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("lake-memory")
	var files := Memory.MemoryFiles.new()
	var repo := SourceEntrySaveRepository.new(profile, files)
	_check(repo.save(captured.snapshot).succeeded(), label + " current repository Save")
	var candidate: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(repo.load().snapshot, tree.root)
	_check(candidate.succeeded(), label + " current restore with physical validation")
	if candidate.succeeded():
		var restored: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(candidate.candidate, &"test", "2026-09-26T00:00:00Z")
		_check(restored.succeeded(), label + " recapture")
		if restored.succeeded():
			_check(GameSaveJsonCodec.encode(captured.snapshot).text == GameSaveJsonCodec.encode(restored.snapshot).text, label + " complete state/identity/allocator/three-RNG equality")
		candidate.candidate.free()
	var raw: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(captured.snapshot).text)
	for old: String in ["SOURCE_ENTRY_V1", "LEGACY_OLDPINE_V1"]:
		raw.world_content_revision = old
		for path: String in [profile.canonical_path(), profile.backup_path(), profile.temp_path()]: files.files[path] = JSON.stringify(raw).to_utf8_buffer()
		var before: Dictionary = files.files.duplicate(true)
		_check(repo.load().outcome == GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, old + " refused")
		_check(repo.load_recovery(GameSaveRecoverySource.Value.BACKUP).outcome == GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, old + " backup refused")
		_check(repo.load_recovery(GameSaveRecoverySource.Value.TEMP).outcome == GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, old + " temp refused")
		_check(files.files == before, "old files unchanged")
