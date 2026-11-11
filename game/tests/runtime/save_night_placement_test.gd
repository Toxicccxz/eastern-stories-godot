extends RefCounted

## 全项目审查「存档与读档」「会话与外壳控制器」: four saves the game took and then refused, or read
## back wrong.
## - the street's idle folk indoors at night (DECISIONS「夜里冷清」): alive and off the map, a save
##   takes them (the save's check, its own check, Continue's check: one rule) and Continue keeps
##   them in till dawn; a map left at night and saved by day elsewhere saves too.
## - corpses, NPCs and dropped things: a corpse falling on any NPC's spot of the world lies where
##   Continue accepts it (MapPlacementValidator, the one check both ends use); a thing saved off
##   such a spot is saved on the nearest one; Continue moves one a save put wrong (an old save)
##   instead of refusing the save.
## - a save taken at night comes back at night: the 西长街's night guard out, the day's 太监 not
##   (the hour is restored before the stage is judged).

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const TRAVELLER: StringName = &"snow.npc.trav_blade"
const NIGHT_GUARD_POINT: StringName = &"imperial.lanes_south.night_guard.1"
const EUNUCH_POINT: StringName = &"imperial.lanes_south.eunuch.1"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_night_home(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_every_corpse_spot(tree, session)
	await _test_placed_on_save_and_continue(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_night_stage_on_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = Work.create_session(tree)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or changes room
	return session


## Night falls on 雪亭镇's square: the travellers go in; Save is allowed, the save is whole, and
## Continue has them indoors still, out again at dawn. Off to another map at night, then day there:
## Save is allowed and Continue reads it.
func _test_night_home(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.square")
	if not _check(map != null, "out on the square"):
		return
	var travellers: Array[StringName] = _travellers(map)
	_check(travellers.size() >= 2, "travellers on the square (%d)" % travellers.size())
	_check(session.wait_until_phase([&"night"]) and session.day_phase_id() == &"night", "night falls (%s)" % session.day_phase_id())
	await tree.physics_frame
	var indoors: bool = true
	for id: StringName in travellers:
		indoors = indoors and not map.find_resident_npc(id).exists_in_map
	_check(indoors, "the travellers are indoors for the night")
	var eligible: OldPineSaveEligibilityResult = OldPineSaveEligibility.inspect(session)
	_check(eligible.allowed(), "Save is allowed with the street's idle folk indoors: %s %s" % [eligible.outcome, eligible.subject_id])
	var candidate: WorldSessionController = await _continue(tree, session, "at night on the square")
	if candidate != null:
		var restored: WorldMapController = candidate.active_map() as WorldMapController
		_check(candidate.day_phase_id() == &"night", "Continue: still night (%s)" % candidate.day_phase_id())
		var still_in: bool = true
		for id: StringName in travellers:
			var npc: NpcRuntimeState = restored.find_resident_npc(id)
			still_in = still_in and npc != null and not npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		_check(still_in, "Continue: the travellers are indoors still, alive")
		candidate.set_process(false)
		_check(candidate.wait_until_phase([&"dawn"]), "the night passes")
		await tree.physics_frame
		var out: bool = true
		for id: StringName in travellers:
			out = out and restored.find_resident_npc(id).exists_in_map
		_check(out, "dawn after Continue: the travellers are out again")
		candidate.free()
		await tree.process_frame
	# Away from the square while they are in, and day there.
	var inn: WorldMapController = MapPlaces.enter(session, &"snow.inn.main_floor", &"snow.inn.main_floor.square_return") # TEST-ONLY: through the inn's door
	if not _check(inn != null and inn.map_id() != map.map_id(), "into the inn at night"):
		return
	await tree.physics_frame
	_check(session.wait_until_phase([&"morning"]), "morning, in the inn")
	await tree.physics_frame
	var left: OldPineSaveEligibilityResult = OldPineSaveEligibility.inspect(session)
	_check(left.allowed(), "by day on another map, the square left at night: Save is allowed: %s %s" % [left.outcome, left.subject_id])
	var later: WorldSessionController = await _continue(tree, session, "by day in the inn")
	if later != null:
		later.free()
		await tree.process_frame


## Every NPC spot of the world: a corpse falling there lies where Continue accepts it (the review
## found 13 of 806 that did not, 严廷殷 in the 将军帐 among them).
func _test_every_corpse_spot(_tree: SceneTree, session: WorldSessionController) -> void:
	var bad: Array[String] = []
	var spots: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
			var location: WorldLocationState = npc.world_location()
			if body == null or location == null or location.map_id != map.map_id():
				continue
			spots += 1
			var lies: Vector2 = map.corpses.corpse_position(body.global_position, location)
			if not MapPlacementValidator.is_valid_corpse_position(map, location.zone_id, lies):
				bad.append("%s at %s" % [npc.character_id, body.global_position])
	_check(spots >= 700, "the world's NPC spots (%d)" % spots)
	_check(bad.is_empty(), "a corpse on every NPC spot lies where Continue accepts it; not: %s" % [bad])


## A thing saved where Continue would not accept it is saved on the nearest spot that it would;
## an old save with one off such a spot is read, the thing moved.
func _test_placed_on_save_and_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null
	var body: WorldCharacterBody2D = null
	var wall: Vector2 = Vector2.INF
	for each: NpcRuntimeState in map.npc_runtimes():
		var each_body: WorldCharacterBody2D = map.runtime_body_for_character(each.character_id)
		if each_body == null or not each.exists_in_map or each.world_location().map_id != map.map_id():
			continue
		var into: Vector2 = _just_off(map, each.world_location().zone_id, each_body.global_position)
		if into.is_finite():
			npc = each
			body = each_body
			wall = into
			break
	if not _check(npc != null, "an NPC beside something it cannot stand in"):
		return
	var zone_id: StringName = npc.world_location().zone_id
	var stood: Vector2 = body.global_position
	body.global_position = wall # TEST-ONLY: pushed a few pixels into a wall
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-11-10T00:00:00Z")
	body.global_position = stood
	if not _check(captured.outcome == OldPineWorldCaptureResult.Outcome.SUCCESS, "Save takes the world: %s %s %s" % [captured.outcome, captured.path, captured.detail]):
		return
	var saved: GameSaveValueTypes.NpcSpawnStateSnapshot = _npc_record(captured.snapshot, npc.character_id)
	var at: Vector2 = Vector2(saved.map_position.x, saved.map_position.y)
	_check(at != wall and MapPlacementValidator.is_valid_character_position(map, zone_id, at) and at.distance_to(wall) <= MapPlacementValidator.NEAREST_REACH_PX, "saved on the nearest spot Continue accepts (%s, pushed to %s)" % [at, wall])
	# An old save holding it in the wall: Continue moves it, and reads the save.
	var record: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(captured.snapshot).text)
	var moved_in: bool = false
	for entry: Dictionary in record["npc_spawn_states"]:
		if entry["character_id"] == String(npc.character_id):
			entry["map_position"] = {"x": wall.x, "y": wall.y}
			moved_in = true
	_check(moved_in, "(the old save has it in the wall)")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(record, "", false, true))
	if not _check(decoded.succeeded(), "the old save decodes: %s" % decoded.outcome):
		return
	var result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(result.succeeded(), "Continue reads a save with an NPC a few pixels in a wall: %s" % result.outcome)
	if result.candidate != null:
		var restored: WorldMapController = result.candidate.world_map_of(map.map_id())
		var restored_body: WorldCharacterBody2D = restored.runtime_body_for_character(npc.character_id)
		_check(restored_body != null and restored_body.global_position != wall and MapPlacementValidator.is_valid_character_position(restored, zone_id, restored_body.global_position), "and stands it on the nearest spot it may (%s)" % (restored_body.global_position if restored_body != null else Vector2.INF))
		result.candidate.free()
		await tree.process_frame


## 皇城's 西长街 at night: the night guard out, the 太监 not; Save, Continue: the same.
func _test_night_stage_on_continue(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.wait_until_phase([&"night"]), "night falls")
	var map: WorldMapController = MapPlaces.enter(session, &"imperial.lanes_south", &"imperial.lanes_south.square_arrival") # TEST-ONLY: onto the 西长街 at night
	if not _check(map != null, "on the 西长街 at night"):
		return
	await tree.physics_frame
	var guard: NpcRuntimeState = map.npcs.npc_at_point(NIGHT_GUARD_POINT)
	var eunuch: NpcRuntimeState = map.npcs.npc_at_point(EUNUCH_POINT)
	_check(guard != null and guard.exists_in_map and eunuch != null and not eunuch.exists_in_map, "at night the guard walks the lane, the 太监 is gone")
	var candidate: WorldSessionController = await _continue(tree, session, "at night on the 西长街")
	if candidate == null:
		return
	var restored: WorldMapController = candidate.active_map() as WorldMapController
	var restored_guard: NpcRuntimeState = restored.npcs.npc_at_point(NIGHT_GUARD_POINT)
	var restored_eunuch: NpcRuntimeState = restored.npcs.npc_at_point(EUNUCH_POINT)
	_check(candidate.day_phase_id() == &"night", "Continue: night (%s)" % candidate.day_phase_id())
	_check(restored_guard != null and restored_guard.exists_in_map, "Continue at night: the guard walks the lane")
	_check(restored_eunuch != null and not restored_eunuch.exists_in_map, "Continue at night: no 太监")
	candidate.free()
	await tree.process_frame


## Save (the save's own check included), the file's text, then Continue's candidate, activated;
## null when any of it is refused.
func _continue(tree: SceneTree, session: WorldSessionController, label: String) -> WorldSessionController:
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-11-10T00:00:00Z")
	if not _check(captured.outcome == OldPineWorldCaptureResult.Outcome.SUCCESS, "%s: the save is taken: %s %s %s" % [label, captured.outcome, captured.path, captured.detail]):
		return null
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(captured.snapshot).text)
	if not _check(decoded.succeeded(), "%s: the save's text reads: %s" % [label, decoded.outcome]):
		return null
	var result: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	if not _check(result.succeeded(), "%s: Continue reads it: %s %s %s" % [label, result.outcome, result.path, result.detail]):
		if result.candidate != null:
			result.candidate.free()
		return null
	result.candidate.set_process(false)
	if not _check(result.candidate.activate_restore_candidate(), "%s: Continue's world starts" % label):
		result.candidate.free()
		return null
	await tree.physics_frame
	return result.candidate


func _travellers(map: WorldMapController) -> Array[StringName]:
	var ids: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == TRAVELLER and npc.exists_in_map:
			ids.append(npc.character_id)
	return ids


## A spot a few pixels from `at` where a character may not stand but one near it may; INF if none.
static func _just_off(map: WorldMapController, zone_id: StringName, at: Vector2) -> Vector2:
	for distance: int in range(8, 41, 4):
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var spot: Vector2 = at + direction * distance
			if map.physical_zone(zone_id).contains_center(spot) and not MapPlacementValidator.is_valid_character_position(map, zone_id, spot):
				return spot
	return Vector2.INF


static func _npc_record(snapshot: GameSaveSnapshot, character_id: StringName) -> GameSaveValueTypes.NpcSpawnStateSnapshot:
	for record: GameSaveValueTypes.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		if record.character_id == character_id:
			return record
	return null


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append(label)
	return ok
