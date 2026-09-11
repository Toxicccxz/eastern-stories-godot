extends RefCounted

const V := preload("res://core/persistence/game_save_value_types.gd")
var _count: int = 0
var _failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var source: OldPineWorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	_check(source.configure_source_entry("续雪", CharacterState.GENDER_FEMALE), "configure source")
	source.deterministic_combat_seed = true
	source.deterministic_npc_seed = true
	source.deterministic_world_interaction_seed = true
	tree.root.add_child(source)
	var player: WorldPlayerRuntimeState = source.player_runtime()
	player.state.recovery.food = 123
	player.state.recovery.water = 234
	player.state.skills.set_raw_level(&"unarmed", 128)
	player.state.skills.set_learned_progress(&"unarmed", 16641)
	var effects: SkillImprovementEffectRegistry = SkillImprovementEffectRegistry.new()
	effects.register_legacy_defaults()
	var improvement: SkillImprovementResult = player.state.skills.improve_skill(&"unarmed", 1, 30, false, true)
	effects.apply(player.state, improvement)
	_check(player.state.attributes.strength == 32 and player.body_facts.body_weight == 80000, "registered level129 effect changes strength only")
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(source, &"test", "2026-09-11T00:00:00Z")
	_check(captured.succeeded(), "source capture: " + captured.path + captured.detail)
	if not captured.succeeded():
		source.free()
		return {"assertions": _count, "failures": _failures}
	var snapshot: GameSaveSnapshot = captured.snapshot
	await _repository_and_host(tree, source, snapshot)
	_check(snapshot.metadata.schema_version == 2 and snapshot.world_content_revision == WorldContentRevision.Value.SOURCE_ENTRY_V1, "normal writer v2 explicit revision")
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded(), "v2 encode")
	var raw: Dictionary = JSON.parse_string(encoded.text)
	# Unsupported old header only; no historical writer or migration fixture.
	var unsupported: Dictionary = raw.duplicate(true)
	unsupported.metadata.schema_version = 1
	_check(GameSaveJsonCodec.decode(JSON.stringify(unsupported)).outcome == GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, "schema1 rejects cleanly")
	unsupported.metadata.schema_version = 3
	_check(GameSaveJsonCodec.decode(JSON.stringify(unsupported)).outcome == GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, "unknown schema rejects cleanly")
	_check(raw.player.has("identity") and raw.player.has("body_facts") and not raw.player.has("maximum_encumbrance"), "v2 strict shape and single capacity")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(decoded.succeeded(), "v2 decode")
	for key: String in ["world_content_revision", "identity", "body_facts"]:
		var invalid: Dictionary = raw.duplicate(true)
		if key == "world_content_revision": invalid.erase(key)
		else: invalid.player.erase(key)
		_check(not GameSaveJsonCodec.decode(JSON.stringify(invalid)).succeeded(), "missing " + key + " rejects")
	for revision: String in ["UNKNOWN", "LEGACY_OLDPINE_V1"]:
		var invalid: Dictionary = raw.duplicate(true)
		invalid.world_content_revision = revision
		_check(not GameSaveJsonCodec.decode(JSON.stringify(invalid)).succeeded(), "unknown/incompatible revision rejects")
	for target: String in ["root", "identity", "body_facts"]:
		var invalid: Dictionary = raw.duplicate(true)
		if target == "root": invalid["unknown"] = 1
		else: invalid.player[target]["unknown"] = 1
		_check(not GameSaveJsonCodec.decode(JSON.stringify(invalid)).succeeded(), "unknown field rejects " + target)
	var invalid_race: Dictionary = raw.duplicate(true)
	invalid_race.player.identity.race_id = "monster"
	_check(not GameSaveJsonCodec.decode(JSON.stringify(invalid_race)).succeeded(), "unsupported race rejects")
	var locations: Array[V.WorldLocationSnapshot] = [V.WorldLocationSnapshot.new(&"snow", &"snow.inn", &"snow.inn.main_floor", &"snow.inn.main_floor")]
	var positions: Array[Vector2] = [Vector2(90, 20)]
	# Read the production scene's existing zone geometry for test placements.
	var snow: WorldResidentMapController = source.resident_map(SnowWorldDefinitions.OUTDOOR_MAP_ID)
	for node: Node in snow.get_node("Zones").get_children():
		var zone: WorldPhysicalZoneArea2D = node as WorldPhysicalZoneArea2D
		var location: WorldLocationState = snow.location_for_zone(zone.zone_id)
		locations.append(V.WorldLocationSnapshot.new(location.region_id, location.map_id, location.zone_id, location.combat_location_id))
		positions.append(zone.position)
	locations.append(V.WorldLocationSnapshot.new(&"oldpine", OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID))
	positions.append(Vector2(450, -350))
	locations.append(V.WorldLocationSnapshot.new(&"oldpine", OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID))
	positions.append(Vector2.ZERO)
	for index: int in range(locations.size()):
		var placed: GameSaveSnapshot = _placed(snapshot, locations[index], positions[index])
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(placed, tree.root)
		_check(restored.succeeded(), "restore " + String(locations[index].zone_id) + " " + restored.path)
		if not restored.succeeded(): continue
		var candidate: OldPineWorldSessionController = restored.candidate
		_check(candidate.resident_map_count() == 4 and candidate.active_map().map_id() == locations[index].map_id, "exact four maps, only saved map active")
		_check(candidate.active_map().runtime_player_body().global_position == positions[index], "exact non-spawn position")
		var fresh: WorldPlayerRuntimeState = candidate.player_runtime()
		_check(fresh != player and fresh.state != player.state and fresh.facts != player.facts and fresh.body_facts != player.body_facts, "fresh Player/Character/identity/body authorities")
		_check(fresh.state.equipment == restored.preparation.item_domain.equipment_state(fresh.character_id) and fresh.armor == restored.preparation.item_domain.armor_state(fresh.character_id), "exact restored equipment/armor injection")
		_check(fresh.facts.display_name == "续雪" and fresh.facts.title == "普通百姓" and fresh.facts.age == 14 and fresh.state.gender == CharacterState.GENDER_FEMALE, "identity and gender exact")
		_check(fresh.state.attributes.strength == 32 and fresh.body_facts.body_weight == 80000 and fresh.maximum_encumbrance == 150000, "independent body restored without derivation")
		_check(fresh.state.recovery.food == 123 and fresh.state.recovery.water == 234, "resources not filled")
		_check(fresh.state.equipment.are_both_hands_empty() and fresh.armor.occupied_slots() == [&"cloth"], "cloth worn; no weapon granted")
		_check(candidate.inventory_state().registered_item_ids() == source.inventory_state().registered_item_ids() and candidate.inventory_state() != source.inventory_state(), "fresh inventory exact semantic IDs")
		_check(candidate.item_id_allocator().next_dynamic_sequence == source.item_id_allocator().next_dynamic_sequence and candidate.item_id_allocator().scope == source.item_id_allocator().scope, "allocator exact without draw")
		_check(candidate.combat_random_source().capture_random_state().state == snapshot.combat_rng.state and candidate.npc_random_source().capture_random_state().state == snapshot.npc_initialization_rng.state and candidate.world_interaction_random_source().capture_random_state().state == snapshot.world_interaction_rng.state, "all three RNG states exact")
		_check(candidate.outdoor_map().npc_runtimes().size() == 5, "off-map five NPC ledger retained")
		_check(candidate.activate_restore_candidate(), "activate saved map")
		var again: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(candidate, &"test", "2026-09-11T00:00:00Z")
		_check(again.succeeded(), "restored source resave succeeds " + again.path)
		if again.succeeded():
			var roundtrip: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(again.snapshot).text)
			var next: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(roundtrip.snapshot, tree.root)
			_check(next.succeeded() and next.candidate.active_map().runtime_player_body().global_position == positions[index], "saved restored graph cold roundtrip exact")
			if next.candidate != null: next.candidate.free()
		for id: StringName in candidate.inventory_state().registered_item_ids():
			_check(candidate.item_instance_index().resolve(id) != source.item_instance_index().resolve(id), "same item ID, fresh object")
		candidate.free()
	for position: Vector2 in [Vector2(INF, 0), Vector2(999999, 0)]:
		var bad: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(_placed(snapshot, locations[0], position), tree.root)
		_check(not bad.succeeded(), "invalid position rejects")
		if bad.candidate != null: bad.candidate.free()
	var corpse_fixture: RefCounted = load("res://tests/support/oldpine_world_save_fixture.gd").new()
	var corpse_save: GameSaveSnapshot = corpse_fixture.with_fat_bandit_corpse(snapshot)
	var corpse_restore: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(corpse_save, tree.root)
	_check(corpse_restore.succeeded(), "off-map corpse restores while Player stays Snow: " + corpse_restore.path)
	if corpse_restore.succeeded():
		var cold: OldPineWorldSessionController = corpse_restore.candidate
		_check(cold.active_map().map_id() == SnowWorldDefinitions.INN_MAP_ID and cold.outdoor_map().corpse_states().size() == 1, "Snow active, detached outdoor corpse retained")
		_check(cold.outdoor_map().npc_runtimes().size() == 5, "dead NPC remains tombstone, no replacement")
		_check(cold.inventory_state().registered_item_ids().size() == corpse_save.items.item_records.size(), "corpse nested graph exact")
		_check(cold.activate_restore_candidate(), "corpse candidate activation")
		var corpse_capture: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(cold, &"test", "2026-09-11T00:00:00Z")
		_check(corpse_capture.succeeded() and corpse_capture.snapshot.corpses.size() == 1, "source off-active corpse capture preserved")
		if corpse_capture.succeeded():
			var before: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(corpse_save).text)
			var after: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(corpse_capture.snapshot).text)
			_check(before.npc_spawn_states == after.npc_spawn_states and before.corpses == after.corpses and before.items == after.items, "entire NPC/dead tombstone/corpse/item records exact")
		cold.free()
	source.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}

func _repository_and_host(tree: SceneTree, source: OldPineWorldSessionController, snapshot: GameSaveSnapshot) -> void:
	var files: SaveFileOperations = load("res://tests/runtime/game_save_repository_test.gd").MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("nge5a-memory")
	var repository := GameSaveRepository.new(profile, files)
	var coordinator := OldPineSessionLoadCoordinator.new(repository)
	_check(coordinator.save_current(source).succeeded(), "production source save coordinator")
	var primary: PackedByteArray = files.read_bytes(profile.canonical_path(), 16777216).bytes
	var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
	host.configure_manual_before_start(profile, files)
	tree.root.add_child(host)
	_check(host.request_continue(), "normal Host Continue accepts source slot")
	await tree.process_frame
	_check(host.last_load_result() != null and host.last_load_result().succeeded(), "normal Host Continue restores source")
	var current: OldPineWorldSessionController = host.current_session()
	if current != null:
		_check(current.world_content_revision() == WorldContentRevision.Value.SOURCE_ENTRY_V1 and current.player_runtime().facts.display_name == "续雪", "Host adopts exact source identity/profile")
	_check(files.read_bytes(profile.canonical_path(), 16777216).bytes == primary, "Continue does not rewrite source file")
	var bad: Dictionary = JSON.parse_string(primary.get_string_from_utf8())
	bad.world_content_revision = "UNKNOWN"
	files.write_bytes(profile.canonical_path(), JSON.stringify(bad).to_utf8_buffer())
	var failed: OldPineRuntimeSaveLoadResult = coordinator.load_replacing(current, host.session_slot, host.staging_slot)
	_check(not failed.succeeded() and host.current_session() == current and is_instance_valid(current), "unknown revision leaves current Session alive")
	files.write_bytes(profile.canonical_path(), primary)
	var old_header: Dictionary = JSON.parse_string(primary.get_string_from_utf8())
	old_header.metadata.schema_version = 1
	var old_bytes: PackedByteArray = JSON.stringify(old_header).to_utf8_buffer()
	files.write_bytes(profile.canonical_path(), old_bytes)
	failed = coordinator.load_replacing(current, host.session_slot, host.staging_slot)
	_check(not failed.succeeded() and failed.repository.outcome == GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA and host.current_session() == current, "unsupported schema keeps current Session safe")
	_check(files.read_bytes(profile.canonical_path(), 16777216).bytes == old_bytes, "unsupported file is not deleted or rewritten")
	files.write_bytes(profile.canonical_path(), primary)
	_check(repository.save(snapshot).succeeded(), "establish valid primary/backup")
	var backup: PackedByteArray = files.read_bytes(profile.backup_path(), 16777216).bytes
	var invalid_player: V.PlayerRuntimeSnapshot = snapshot.player
	invalid_player.identity.race_id = &"unsupported"
	var invalid: GameSaveSnapshot = GameSaveSnapshot.new(snapshot.metadata, snapshot.session_kind, snapshot.item_id_allocator, invalid_player, snapshot.npc_spawn_states, snapshot.corpses, snapshot.items, snapshot.combat_rng, snapshot.npc_initialization_rng, snapshot.world_interaction_rng, snapshot.world_content_revision)
	_check(not repository.save(invalid).succeeded() and files.read_bytes(profile.backup_path(), 16777216).bytes == backup, "invalid v2 leaves backup intact")
	_check(host.request_end_session(), "end source Session")
	await tree.process_frame
	await tree.process_frame
	_check(host.current_session() == null, "old Session destroyed before cold continuation")
	_check(host.request_continue(), "cold Continue request")
	await tree.process_frame
	_check(host.last_load_result().succeeded() and host.current_session() != current, "cold Continue creates new graph")
	host.free()
	var technical: OldPineWorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	tree.root.add_child(technical)
	var legacy: GameSaveSnapshot = OldPineWorldSaveCapture.new().capture(technical, &"test", "2026-09-11T00:00:00Z").snapshot
	_check(repository.save(legacy).succeeded(), "current technical v2 file")
	primary = files.read_bytes(profile.canonical_path(), 16777216).bytes
	technical.free()
	var legacy_host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
	legacy_host.configure_manual_before_start(profile, files)
	tree.root.add_child(legacy_host)
	legacy_host.request_continue()
	await tree.process_frame
	_check(legacy_host.last_load_result().succeeded(), "normal Host Continue current technical v2")
	_check(legacy_host.current_session().resident_map_count() == 2 and legacy_host.current_session().resident_map(SnowWorldDefinitions.INN_MAP_ID) == null, "technical profile has no Snow")
	_check(files.read_bytes(profile.canonical_path(), 16777216).bytes == primary, "technical Continue does not rewrite bytes")
	legacy_host.request_save()
	await tree.process_frame
	_check(legacy_host.last_save_result().succeeded() and repository.load().snapshot.metadata.schema_version == 2 and repository.load().snapshot.world_content_revision == WorldContentRevision.Value.LEGACY_OLDPINE_V1, "technical resave remains schema2 technical profile")
	legacy_host.free()
	await tree.process_frame

func _placed(base: GameSaveSnapshot, location: V.WorldLocationSnapshot, position: Vector2) -> GameSaveSnapshot:
	var player: V.PlayerRuntimeSnapshot = base.player
	player.world_location = location
	player.map_position = V.MapPositionSnapshot.new(position.x, position.y)
	return GameSaveSnapshot.new(base.metadata, base.session_kind, base.item_id_allocator, player, base.npc_spawn_states, base.corpses, base.items, base.combat_rng, base.npc_initialization_rng, base.world_interaction_rng, base.world_content_revision)

func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("NGE5A: " + label)
