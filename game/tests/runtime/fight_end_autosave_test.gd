extends RefCounted

## A fight's autosave moment comes in the battle panel's end hold once its picture is still
## (review fixes R and X; DECISIONS「自动存档」): the capture's frame falls after the last lines
## are told and the 胜 stamp has landed, while nothing advances — not in the middle of the last
## blow, not on the player's first step after the fight. The world it takes is the one the
## player gets back when the hold ends, with what the fight changed written down (the rats'
## cleared mark and the 任务 page's step: a load does not announce them again); the moment comes
## again as the panel closes, and an autosave written at the first does not write twice.
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Repository := preload("res://tests/runtime/game_save_repository_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var opening: int = BattlePace.opening
	BattlePace.opening = BattlePace.Opening.OFF
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree, session)
	await _fight_end(tree, session)
	await _rats(tree, session)
	BattlePace.opening = opening
	TestFeel.restore()
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _fight_end(tree: SceneTree, session: WorldSessionController) -> void:
	TestFeel.use()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var map: WorldMapController = await _beside(tree, session, &"snow.school2", &"snow.school2.trainee.2")
	if not _check(map != null, "beside a trainee"):
		return
	var trainee: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school2.trainee.2")
	await tree.physics_frame
	var files := Repository.MemoryFiles.new()
	var profile := GameSaveStorageProfile.isolated_test("fight-end-autosave")
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	GameContent.catalog().set_pacing(pacing.copy().with_autosave(180)) # TEST-ONLY: the shipped interval
	var autosave := GameAutosave.new(SourceEntrySaveRepository.new(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID), files))
	autosave.restart_interval(-1)
	var moments: Array[Dictionary] = []
	session.autosave_moment.connect(func() -> void:
		moments.append({
			"holding": ui._holding(),
			"fighting": coordinator.has_active_encounter(),
			"allowed": OldPineSaveEligibility.inspect(session).allowed(),
			"why": "%d %s %s" % [OldPineSaveEligibility.inspect(session).outcome, OldPineSaveEligibility.inspect(session).subject_id, OldPineSaveEligibility.inspect(session).detail],
			"world": _world(session),
			"began": autosave.begin(session),
		}))
	map.select_npc(trainee.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "an attack starts")
	ui.refresh_projection()
	session._process(0.1)
	_check(ui.visible and moments.is_empty(), "the panel up, no moment while the fight runs")
	trainee.character_state.vitality = CharacterResourceState.new(1, 1, 100000) # TEST-ONLY: the next blow ends it
	player.state.progression.combat_experience = 100000 # TEST-ONLY: it lands
	for step: int in 600:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	ui.refresh_projection()
	_check(not coordinator.has_active_encounter() and ui._holding() and session.presentation_frozen(), "over: the panel holds its last lines, nothing advances (fighting %s, holding %s, frozen %s, visible %s, moments %s)" % [coordinator.has_active_encounter(), ui._holding(), session.presentation_frozen(), ui.visible, moments.map(func(m: Dictionary) -> Array: return [m["holding"], m["fighting"], m["allowed"], m["began"]])])
	session._process(0.1)
	_check(moments.is_empty(), "not while the last lines are still told: %d" % moments.size())
	ui._tell_lines(5.0)
	_check(ui.end_stamp.visible and ui.end_stamp.text == "胜", "the lines told, the 胜 stamp comes down: %s" % ui.end_stamp.text)
	session._process(0.1)
	_check(moments.is_empty(), "not while the stamp lands")
	ui._process(0.62)
	_check(ui._holding(), "the stamp landed, the panel still holds")
	session._process(0.1)
	_check(moments.size() == 1, "the still picture is the fight's moment, once: %d" % moments.size())
	if moments.is_empty():
		GameContent.catalog().set_pacing(pacing)
		return
	_check(bool(moments[0]["holding"]) and not bool(moments[0]["fighting"]), "taken while the panel holds, the fight over")
	_check(bool(moments[0]["allowed"]) and bool(moments[0]["began"]) and autosave.running(), "Save is allowed there and the autosave sets off: %s" % moments[0]["why"])
	for step: int in 3:
		session._process(0.1)
	_check(moments.size() == 1, "not again while the hold lasts")
	ui._process(0.5)
	ui._process(0.4)
	_check(not ui._holding() and not ui.visible, "the hold over, the panel gone")
	session._process(0.1)
	_check(moments.size() == 2, "the panel's closing is a moment too (it saves when the first could not)")
	if moments.size() < 2:
		autosave.wait()
		GameContent.catalog().set_pacing(pacing)
		return
	_check(not bool(moments[1]["began"]), "an autosave set off at the hold is not written twice")
	_check(moments[0]["world"] == moments[1]["world"], "the world taken at the hold is the one the player gets back")
	autosave.wait()
	var saved: GameSaveResult = autosave.take_finished()
	_check(saved != null and saved.succeeded(), "the autosave taken at the hold is written: %s" % ("none" if saved == null else str(saved.outcome)))
	var loaded: GameSaveResult = SourceEntrySaveRepository.new(profile.for_slot(GameSaveSnapshot.AUTO_SLOT_ID), files).load()
	_check(loaded.succeeded() and _drop_times(JSON.parse_string(GameSaveJsonCodec.encode(loaded.snapshot).text)) == moments[1]["world"], "and it reads back as the world after the hold")
	GameContent.catalog().set_pacing(pacing)
	TestFeel.restore()
	await tree.process_frame


## The last of the inn's rats knocked down in a fight: the cleared mark (客栈老鼠) and the
## 任务 page's step (snow.newcomer/rats) are in the world the moment takes, not found by the
## journal's next look half a second after it.
func _rats(tree: SceneTree, session: WorldSessionController) -> void:
	TestFeel.use()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var map: WorldMapController = await _beside(tree, session, &"snow.inn_2f", &"snow.inn_2f.rat.6")
	if not _check(map != null, "upstairs beside a rat"):
		return
	await tree.physics_frame
	var rats: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_id == &"snow.inn_upstairs.inn_2f.rats":
			rats.append(npc)
	if not _check(rats.size() == 6, "six rats upstairs: %d" % rats.size()):
		return
	var last: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.inn_2f.rat.6")
	for rat: NpcRuntimeState in rats:
		if rat != last:
			rat.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: five down
	session.record_journal()
	_check(not player.state.marks.has("客栈老鼠") and not player.state.journal.has("snow.newcomer/rats"), "one rat still stands: no mark, no step")
	var worlds: Array[String] = []
	var moment := func() -> void: worlds.append(JSON.stringify(_world(session)))
	session.autosave_moment.connect(moment)
	map.select_npc(last.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the last rat attacked")
	ui.refresh_projection()
	session._process(0.1)
	last.character_state.vitality = CharacterResourceState.new(1, 1, 100000) # TEST-ONLY: the next blow ends it
	player.state.progression.combat_experience = 100000 # TEST-ONLY: it lands
	for step: int in 600:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	ui.refresh_projection()
	ui._tell_lines(5.0)
	ui._process(0.62)
	session._process(0.1)
	if _check(worlds.size() == 1, "the rat fight's moment: %d" % worlds.size()):
		_check(worlds[0].contains("客栈老鼠"), "the cleared mark is in the world it takes")
		_check(worlds[0].contains("snow.newcomer/rats"), "and the 任务 page's step")
	_check(player.state.marks.get("客栈老鼠", 0) == 1 and player.state.journal.has("snow.newcomer/rats"), "the player has both")
	ui._process(0.5)
	ui._process(0.4)
	session._process(0.1)
	session.autosave_moment.disconnect(moment)
	TestFeel.restore()


## The world as a save holds it, without what the clock adds (the moment of saving, the
## seconds played, menus included).
func _world(session: WorldSessionController) -> Dictionary:
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-11-12T00:00:00Z", null, GameSaveSnapshot.AUTO_SLOT_ID, false)
	if not captured.succeeded():
		return {"failed": captured.path}
	return _drop_times(JSON.parse_string(GameSaveJsonCodec.encode(captured.snapshot).text))


func _drop_times(root: Variant) -> Dictionary:
	var world: Dictionary = root if root is Dictionary else {}
	world.erase("metadata")
	world.erase("played_seconds")
	return world


func _to_snow(tree: SceneTree, session: WorldSessionController) -> void:
	for _step: int in range(400):
		MapRoute.press_toward(session.active_map().runtime_player_body(), Vector2.RIGHT)
		await tree.physics_frame
		if session.active_map_id() == &"snow.outdoor":
			break
	MapPlaces.release()
	await tree.physics_frame
	session.set_process(false)
	_check(session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(tree: SceneTree, session: WorldSessionController, zone_id: StringName, point_id: StringName) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, zone_id, point_id)
	if map == null:
		return null
	await tree.physics_frame
	await tree.physics_frame
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return null
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return map if session.player_runtime().set_world_location(map.location_for_zone(zone_id)) else null
	return null


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
