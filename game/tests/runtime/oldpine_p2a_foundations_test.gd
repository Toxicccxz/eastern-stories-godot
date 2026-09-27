extends "res://tests/runtime/combat_flee_test.gd"

const Memory := preload("res://tests/runtime/game_save_repository_test.gd")
const Failing := preload("res://tests/support/failing_combat_relationship_state.gd")

class RejectFreezeSession extends OldPineWorldSessionController:
	func freeze_world_for_encounter(_id: StringName) -> bool:
		return false

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _save_boundary(tree)
	for count: int in [0, 1, 4, 5]:
		await _group(tree, count, false)
	await _group(tree, 5, true)
	await _refusals(tree)
	await _rollback(tree)
	await _late_failure_and_death(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}

func _save_boundary(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.configure_source_entry("LakeTester", CharacterState.GENDER_FEMALE)
	tree.root.add_child(session)
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-26T00:00:00Z")
	_check(captured.succeeded(), "P2A current public capture")
	if not captured.succeeded():
		session.free()
		return
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("p2a-memory")
	var files := Memory.MemoryFiles.new()
	var repo := SourceEntrySaveRepository.new(profile, files)
	var snapshot: GameSaveSnapshot = captured.snapshot
	_check(repo.save(snapshot).succeeded() and repo.load().succeeded(), "current public roundtrip")
	_check(snapshot.world_content_revision == WorldContentRevision.CURRENT_PUBLIC and snapshot.npc_spawn_states.size() == 10, "current Lake marker and complete catalog")
	var raw: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(snapshot).text)
	for revision: String in ["LEGACY_OLDPINE_V1", "SOURCE_ENTRY_V1", "NOT_KNOWN"]:
		var changed: Dictionary = raw.duplicate(true)
		changed.world_content_revision = revision
		# Decode refusal precedes nested entities; no guess that corrupt current data is old.
		changed.player = null
		var expected: int = GameSaveResult.Outcome.UNKNOWN_WORLD_REVISION if revision == "NOT_KNOWN" else GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT
		for path: String in [profile.canonical_path(), profile.backup_path(), profile.temp_path()]:
			files.files[path] = JSON.stringify(changed).to_utf8_buffer()
		var before: Dictionary = files.files.duplicate(true)
		_check(repo.load().outcome == expected, "precise contract refusal " + revision)
		for recovery: int in [GameSaveRecoverySource.Value.BACKUP, GameSaveRecoverySource.Value.TEMP]:
			_check(repo.load_recovery(recovery).outcome == expected, "recovery same contract gate")
		_check(files.files == before, "refusal never writes any file")
		_check(repo.inspect_slot().recovery_sources().is_empty(), "unsupported recovery never offered")
		files.files[profile.backup_path()] = JSON.stringify(raw).to_utf8_buffer()
		_check(repo.load().outcome == expected, "valid backup does not mask canonical contract refusal")
		_check(ApplicationProductResultMapper.inspect_slot(repo.inspect_slot()).has_recovery_source(GameSaveRecoverySource.Value.BACKUP), "valid backup remains explicit UI choice")
		_check(repo.load_recovery(GameSaveRecoverySource.Value.BACKUP).succeeded(), "explicit current backup remains usable")
	for defect: String in ["missing", "extra", "duplicate", "identity", "body", "life"]:
		var changed: Dictionary = raw.duplicate(true)
		match defect:
			"missing": changed.npc_spawn_states.pop_back()
			"extra":
				var extra: Dictionary = changed.npc_spawn_states[0].duplicate(true)
				extra.spawn_point_id = "fake.point"
				extra.character_id = "fake.character"
				changed.npc_spawn_states.append(extra)
			"duplicate": changed.npc_spawn_states.append(changed.npc_spawn_states[0].duplicate(true))
			"identity": changed.npc_spawn_states[0].npc_definition_id = "fake.definition"
			"body": changed.npc_spawn_states[0].body_weight = "1"
			"life": changed.npc_spawn_states[0].life_status = "DEAD"
		for path: String in [profile.canonical_path(), profile.backup_path(), profile.temp_path()]:
			files.files[path] = JSON.stringify(changed).to_utf8_buffer()
		var before: Dictionary = files.files.duplicate(true)
		var result: GameSaveResult = repo.load()
		_check(not result.succeeded() and result.outcome not in [GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, GameSaveResult.Outcome.UNKNOWN_WORLD_REVISION], "corruption stays corruption " + defect)
		_check(not repo.load_recovery(GameSaveRecoverySource.Value.BACKUP).succeeded() and not repo.load_recovery(GameSaveRecoverySource.Value.TEMP).succeeded(), "corrupt ledger cannot recover")
		_check(files.files == before, "ledger refusal preserves files")
	var corpse_fixture: RefCounted = load("res://tests/support/oldpine_world_save_fixture.gd").new()
	var dead: GameSaveSnapshot = corpse_fixture.with_fat_bandit_corpse(snapshot)
	_check(repo.save(dead).succeeded(), "current dead slot plus independent corpse accepted")
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
	_check(restored.succeeded(), "fresh graph current public restore")
	if restored.succeeded():
		_check(restored.candidate.npc_random_source().capture_random_state().state == snapshot.npc_initialization_rng.state, "restore NPC RNG zero draws")
		_check(restored.candidate.combat_random_source().capture_random_state().state == snapshot.combat_rng.state, "restore Combat RNG zero draws")
		restored.candidate.free()
	_check(ApplicationMessageCatalog.text_for(&"save.incompatible_development") == "此存档来自不兼容的开发版本，请开始新游戏。", "explicit product message")
	session.free()
	await _settle(tree, 2)

# Isolated source-derived test bodies, not a production catalog or Lake geometry.
func _snakes(session: OldPineWorldSessionController, count: int) -> Array[NpcRuntimeState]:
	var result: Array[NpcRuntimeState] = []
	var map: OldPineOutdoorController = session.outdoor_map()
	for index: int in count:
		var id := StringName("qa.p2a.snake.%d" % index)
		var npc: NpcRuntimeState = NpcCharacterStateFactory.new().create_one(OldPineNpcDefinitions.serpent_definition(), id, &"qa.group", id, session.player_runtime().world_location(), session.inventory_state(), session.stack_collection(), session.npc_random_source(), [])
		var body := WorldCharacterBody2D.new()
		body.name = "QA_P2A_%d" % index
		body.position = map.player_body.position + Vector2(45, index * 4)
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(36, 36)
		shape.shape = rectangle
		body.add_child(shape)
		var label := Label.new()
		label.name = "NameLabel"
		body.add_child(label)
		var area := Area2D.new()
		area.name = "AggressionPresence"
		area.collision_layer = 0
		var circle := CircleShape2D.new()
		circle.radius = 90
		var contact := CollisionShape2D.new()
		contact.name = "CollisionShape2D"
		contact.shape = circle
		area.add_child(contact)
		body.add_child(area)
		map.get_node("Characters").add_child(body)
		_check(map.register_npc_body(npc, body, area, CombatSliceContentProfile.new()), "isolated registration")
		result.append(npc)
	return result

func _group(tree: SceneTree, count: int, manual: bool) -> void:
	var session: OldPineWorldSessionController = _new(tree)
	var snakes: Array[NpcRuntimeState] = _snakes(session, count)
	var map: OldPineOutdoorController = session.outdoor_map()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rng: Setup.CountingRandom = session.combat_random_source()
	var npc_rng: int = session.npc_random_source().capture_random_state().state
	var cause: int = CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK if manual else CombatTriggerCause.Value.NPC_AGGRESSION
	var target: StringName = snakes[0].character_id if manual else &""
	var first: Array[CombatSliceCharacterBinding] = map.collect_complete_combat_entry(cause, target)
	map._all_npcs.reverse() # Container permutation, not a caller-supplied candidate list.
	var again: Array[CombatSliceCharacterBinding] = map.collect_complete_combat_entry(cause, target)
	_check(first.size() == again.size(), "order independent collection")
	for index: int in range(1, first.size()):
		_check(first[index].character_id == snakes[index - 1].character_id, "order is lexical text, not StringName allocation")
	for index: int in first.size():
		_check(first[index].character_id == again[index].character_id, "stable lexical order")
	var result: CombatSliceInitiationResult = coordinator.start_complete_production(cause, target)
	_check((result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED) == (count > 0), "0/1/4/5 admission")
	_check(rng.calls == 0 and session.npc_random_source().capture_random_state().state == npc_rng, "collection/start no RNG")
	if count > 0 and coordinator.has_active_encounter():
		var encounter: CombatEncounter = coordinator.active_encounter()
		var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
		_check(encounter.participants().size() == count + 1, "all and only eligible included")
		for npc: NpcRuntimeState in snakes:
			_check(npc.relationship.opponent_ids() == [session.player_runtime().character_id], "no serpent-serpent hostility")
		if count == 5:
			var fifth: StringName = snakes[4].character_id
			_check(coordinator.change_player_target(CombatTargetRequest.new(encounter.encounter_id, session.player_runtime().character_id, fifth)).code == CombatTargetResult.Code.CHANGED, "fifth actual target request")
			for npc: NpcRuntimeState in snakes:
				npc.busy.start_busy(3)
			coordinator.advance_scheduler(1.0)
			_check(scheduler.events().size() == 6, "six scheduler opportunities")
			_check(scheduler.events()[0].target_id == fifth and scheduler.events()[0].resolution != null, "fifth goes through real executor")
			for index: int in 6:
				_check(scheduler.events()[index].actor_id == encounter.participants()[index].participant_id, "stable opportunity order")
		var before: int = scheduler.events().size()
		var draws: int = rng.calls
		_check(coordinator.submit_player_action(_request(session)).accepted(), "real typed Flee request")
		coordinator.advance_scheduler(10000)
		_check(coordinator.last_completion() != null and coordinator.last_completion().succeeded() and session.world_simulation_gate().is_open(), "whole-set Flee completes")
		_check(scheduler.events().size() == before and rng.calls == draws, "Flee no subsequent ordinary opportunity")
		for npc: NpcRuntimeState in snakes:
			_check(npc.relationship.opponent_ids().is_empty() and npc.relationship.lethal_target_ids().is_empty(), "all enemy relationships cleared")
		_check(map.collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION).is_empty(), "thaw does not rearm same contact")
		map.player_body.position += Vector2(500, 0)
		map.collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION)
		map.player_body.position -= Vector2(500, 0)
		_check(map.collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION).size() == count + 1, "actual separated shapes then reentry rearm")
	session.free()
	await _settle(tree, 2)

func _refusals(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new(tree)
	var snakes: Array[NpcRuntimeState] = _snakes(session, 5)
	var map: OldPineOutdoorController = session.outdoor_map()
	var cause: int = CombatTriggerCause.Value.NPC_AGGRESSION
	snakes[0]._exists_in_map = false
	snakes[1]._combat_available = false
	snakes[2]._life_status = CharacterRuntimeLifeStatus.Value.DEAD
	map.runtime_body_for_character(snakes[3].character_id).position += Vector2(500, 0)
	_check(map.collect_complete_combat_entry(cause).size() == 2, "absent/unavailable/dead/non-contact excluded")
	# A foreign combat location is never fixed up by admission.
	snakes[4]._world_location = WorldLocationState.new(&"other", &"other", &"other", &"other")
	_check(map.collect_complete_combat_entry(cause).is_empty(), "different combat location excluded")
	session.free()
	await _settle(tree, 2)

func _rollback(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _new(tree)
	var snakes: Array[NpcRuntimeState] = _snakes(session, 5)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	player.relationship.add_opponent(snakes[2].character_id)
	player.relationship.add_opponent(snakes[0].character_id)
	var before: Array[StringName] = player.relationship.opponent_ids()
	var failing := Failing.new(snakes[3].character_id)
	failing.fail_add_id = player.character_id
	snakes[3]._relationship = failing
	_check(coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION).outcome != CombatSliceInitiationResult.Outcome.COMPLETED, "intermediate fourth relation failure")
	_check(player.relationship.opponent_ids() == before and player.relationship.lethal_target_ids().is_empty(), "whole rollback preserves original order")
	for npc: NpcRuntimeState in snakes:
		_check(npc.relationship.opponent_ids().is_empty() and npc.relationship.lethal_target_ids().is_empty(), "rollback every enemy including failing relation")
	_check(not coordinator.has_active_encounter() and coordinator.active_scheduler() == null and session.world_simulation_gate().is_open(), "no partial engine or freeze")
	failing.fail_add_id = &""
	snakes[4].relationship.add_opponent(&"unrelated")
	_check(coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION).outcome != CombatSliceInitiationResult.Outcome.COMPLETED, "third-party relation refuses full set")
	_check(snakes[4].relationship.opponent_ids() == [&"unrelated"] and player.relationship.opponent_ids() == before, "conflict never erased")
	session.free()
	await _settle(tree, 2)

func _late_failure_and_death(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.set_script(RejectFreezeSession)
	tree.root.add_child(session)
	session.set_process(false)
	session.outdoor_map().set_process(false)
	var snakes: Array[NpcRuntimeState] = _snakes(session, 5)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION).outcome == CombatSliceInitiationResult.Outcome.ENCOUNTER_START_FAILED, "late freeze refusal")
	_check(not coordinator.has_active_encounter() and coordinator.active_scheduler() == null and session.world_simulation_gate().is_open(), "late failure releases only owned gate")
	for npc: NpcRuntimeState in snakes:
		_check(npc.relationship.opponent_ids().is_empty() and npc.relationship.lethal_target_ids().is_empty(), "late failure restores every relationship")
	_check(session.player_runtime().relationship.opponent_ids().is_empty(), "late failure restores Player")
	session.free()
	await _settle(tree, 2)
	session = _new(tree)
	snakes = _snakes(session, 5)
	coordinator = session.combat_encounter_coordinator()
	var body: WorldCharacterBody2D = session.outdoor_map().runtime_body_for_character(snakes[4].character_id)
	body._npc = snakes[3]
	_check(coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION).outcome != CombatSliceInitiationResult.Outcome.COMPLETED, "fake fifth body binding refuses full set")
	body._npc = snakes[4]
	var gate: WorldSimulationGate = session.world_simulation_gate()
	gate.acquire(&"foreign")
	_check(coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION).outcome != CombatSliceInitiationResult.Outcome.COMPLETED and gate.freeze_owner_id() == &"foreign", "foreign freeze owner retained")
	gate.release(&"foreign")
	_check(coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION).outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "six start for lifecycle")
	var encounter: CombatEncounter = coordinator.active_encounter()
	var fifth: StringName = snakes[4].character_id
	coordinator.change_player_target(CombatTargetRequest.new(encounter.encounter_id, session.player_runtime().character_id, fifth))
	# Deterministic lifecycle boundary setup, not a claim about killing five at birth.
	for npc: NpcRuntimeState in snakes:
		npc.busy.start_busy(20)
	snakes[4].character_state.vitality.current = -1
	snakes[4].character_state.vitality.effective = -1
	coordinator.advance_scheduler(0)
	_check(snakes[4].life_status == CharacterRuntimeLifeStatus.Value.DEAD and not snakes[4].exists_in_map, "fifth death uses real lifecycle publication")
	_check(coordinator.has_active_encounter() and session.outdoor_map().corpse_states().size() == 1, "four remaining hostiles keep encounter active")
	_check(coordinator.change_player_target(CombatTargetRequest.new(encounter.encounter_id, session.player_runtime().character_id, fifth)).code == CombatTargetResult.Code.TARGET_UNAVAILABLE, "dead fifth stale target refused")
	coordinator.advance_scheduler(1)
	_check(encounter.current_target_for(session.player_runtime().character_id) == snakes[0].character_id, "stale target retargets stable first survivor")
	for npc: NpcRuntimeState in snakes.slice(0, 4):
		npc.character_state.vitality.current = -1
		npc.character_state.vitality.effective = -1
	coordinator.advance_scheduler(0)
	_check(not coordinator.has_active_encounter() and encounter.terminal_result != null and encounter.terminal_result.kind == CombatEncounterResultKind.Value.VICTORY, "completion waits for all five hostiles")
	_check(session.outdoor_map().corpse_states().size() == 5 and gate.is_open(), "five independent corpse identities and thaw")
	session.free()
	await _settle(tree, 2)
