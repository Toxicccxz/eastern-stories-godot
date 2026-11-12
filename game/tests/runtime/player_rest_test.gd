extends RefCounted

## 歇到回满 (DECISIONS「歇到回满」): the 请教 page offers it when a continuous 请教 stops for want
## of 精 (and gives it the focus); pressed, the page closes, the world runs pacing's
## rest_world_scale times as fast by its own beats (the clock, recovery, food and water), and the
## rest ends with 精, 气 and 神 full, the page open again and a line saying how long it took. An
## aggressive NPC noticing the player cuts it short and the fight comes as ever; the menu holds
## it; no rest in a fight, full or without water; rest_limit_seconds bounds it; a save right
## after restores exactly.
## TEST-ONLY fixtures, marked where used: gin/kee/sen, water, skill levels set directly.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SCHOOL: StringName = &"snow.school_compound.schoolhall.master"
## Seconds of one hand-driven frame (world time while resting: 20 times as much).
const FRAME: float = 0.1
const GATE: StringName = &"city.eastdoor1"

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _school: TeacherService
var _ended: Array[int] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_knob()
	TestDay.use() # the clock runs here: a rest is time going by
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_state = _player.state
	_hud = _session.shared_ui()
	_session.rest_ended.connect(func(outcome: int, _line: String) -> void: _ended.append(outcome))
	var map: WorldMapController = MapPlaces.enter(_session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	_check(map != null and _beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	await tree.physics_frame
	await tree.process_frame
	await tree.process_frame
	_school = map.service(SCHOOL) as TeacherService
	_school.request_apprentice()
	_hud.life_overlay.go_on()
	await _test_rest_from_teacher(tree)
	_test_refusals()
	await _test_menu_holds(tree)
	_test_limit()
	await _test_save_after_rest(tree)
	await _test_attacker(tree)
	TestDay.restore()
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_knob() -> void:
	var errors: Array[String] = []
	var left_out: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors))
	_check(errors.is_empty() and left_out.rest_world_scale == 0 and left_out.rest_limit_seconds == 0, "left out: ES2, no rest")
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "rest_world_scale": 20}, "p", broken))
	_check(broken.size() == 1 and broken[0].contains("rest_limit_seconds"), "a rest needs a longest rest: %s" % [broken])
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_check(pacing.rest_world_scale == 20 and pacing.rest_limit_seconds == 600, "pacing.json: 20 times as fast, 600 world seconds at most")
	_check(pacing.copy().rest_world_scale == 20 and pacing.copy().rest_limit_seconds == 600, "a copy keeps them")


## 连续请教 stops for 精: 歇到回满 shows and has the focus; pressed, the page closes and the
## player rests; the clock moves 60 game seconds a world second (a day of 24 real minutes), food
## goes down by the heal_up()s that ran, 精 comes back full, and the page opens again.
func _test_rest_from_teacher(tree: SceneTree) -> void:
	_lesson_ready(&"sword", 10)
	_state.essence.current = _cost() * 2 + 3 # TEST-ONLY: two lessons and 3 over
	_school.interact()
	await tree.process_frame
	_check(not _school.ui.rest_button.visible or _state.essence.current < _state.essence.maximum, "the rest shows only while something is below full")
	_school.ui.run_buttons[&"sword"].pressed.emit()
	await tree.process_frame
	_check(_school.ui.progress.last_stop == TrainingRun.Stop.WASTE_ESSENCE, "the run stopped for want of 精")
	_check(_school.ui.rest_button.visible and not _school.ui.rest_button.disabled and _school.ui.rest_button.text == "歇到回满", "歇到回满 offered")
	_check(_school.ui.rest_button.has_focus(), "and it has the focus")
	_check(_hud.log_lines().any(func(line: String) -> bool: return line.contains("歇到回满")), "the stop line says how to rest")
	var gin_before: int = _state.essence.current
	var day_before: int = _session.day_clock().day_seconds()
	var food_before: int = _state.recovery.food
	_school.ui.rest_button.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	_check(not _school.ui.panel.visible and _session.resting() and not _session.world_time_held(), "the page closed, the player rests, world time runs")
	_check(_hud.rest_overlay.shown(), "the rest's band shows")
	_check(_session.active_map().runtime_player_body().walk_paused, "no walking while resting")
	var world_seconds: float = await _rest_out(tree)
	_check(_ended == [RestRules.Outcome.RESTED], "ended full: %s" % [_ended])
	_check(_state.essence.current == _state.essence.maximum and _state.essence.current > gin_before and RestRules.rested(_state), "精, 气 and 神 full")
	var game_seconds: int = posmod(_session.day_clock().day_seconds() - day_before, DayClock.DAY_SECONDS)
	_check(absi(game_seconds - roundi(world_seconds * 60.0)) <= 60, "the clock went %d game seconds for %.1f world seconds" % [game_seconds, world_seconds])
	_check(world_seconds >= 10.0 and _state.recovery.food < food_before, "heal_up()s ran on the beat: food %d -> %d over %.1f s" % [food_before, _state.recovery.food, world_seconds])
	var minutes: int = RestRules.game_minutes(world_seconds, GameContent.catalog().pacing().day_length_minutes)
	var said: String = _hud.log_lines()[-1] if not _hud.log_lines().is_empty() else ""
	_check(_hud.log_lines().has(RestLines.ended(RestRules.Outcome.RESTED, minutes)), "the line says how long: %s" % said)
	await tree.process_frame
	_check(_school.ui.panel.visible, "the 请教 page opens again")
	_check(not _session.active_map().runtime_player_body().walk_paused, "walking again")
	_school.ui.close_panel()
	await tree.process_frame
	await tree.process_frame


## No rest in a fight, full, or without water; each says why.
func _test_refusals() -> void:
	_heal()
	_check(_session.rest_refusal() == RestLines.REFUSE_RESTED and _session.begin_rest() == RestLines.REFUSE_RESTED, "full: no rest")
	_state.essence.current = 10 # TEST-ONLY
	var water: int = _state.recovery.water
	_state.recovery.water = 0 # TEST-ONLY
	_check(_session.begin_rest() == RestLines.REFUSE_THIRSTY and not _session.resting(), "no water: no rest, told to drink")
	_state.recovery.water = water


## The menu holds world time, and the rest with it; closed, it goes on.
func _test_menu_holds(tree: SceneTree) -> void:
	_state.essence.current = 10 # TEST-ONLY
	_check(_session.begin_rest() == "", "a rest begins")
	_session.hold_world_time(&"menu")
	var day: int = _session.day_clock().day_seconds()
	var gin: int = _state.essence.current
	for _i: int in 20:
		_session._process(FRAME)
	_check(_session.resting() and _session.day_clock().day_seconds() == day and _state.essence.current == gin, "held: the rest waits, nothing moves")
	_state.essence.current -= 3 # TEST-ONLY: spent in the window (a 练习), not a hurt
	_session._process(FRAME)
	_session.release_world_time(&"menu")
	_session._process(FRAME)
	_check(_session.day_clock().day_seconds() != day, "released: time runs again")
	_check(_session.resting(), "what was spent under the window does not end the rest as a hurt")
	_session.stop_rest()
	_check(_ended[-1] == RestRules.Outcome.CANCELLED and not _session.resting(), "起身: stopped")
	await tree.process_frame


## A wound too deep for one rest: it stops at rest_limit_seconds and says so.
func _test_limit() -> void:
	var essence: CharacterResourceState = _state.essence
	var saved: Vector3i = Vector3i(essence.current, essence.effective, essence.maximum)
	essence.maximum = 5000 # TEST-ONLY: a wound that takes far longer than 600 s
	essence.effective = 10
	essence.current = 10
	_check(_session.begin_rest() == "", "a rest begins")
	var seconds: float = 0.0
	while _session.resting() and seconds < 1000.0:
		_session._process(FRAME)
		seconds += FRAME * 20.0
	_check(_ended[-1] == RestRules.Outcome.LIMIT and absf(seconds - 600.0) <= 2.0 * FRAME * 20.0, "stopped at the longest rest: %.1f world seconds" % seconds)
	essence.maximum = saved.z
	essence.effective = saved.y
	essence.current = saved.x


## Right after a rest, a save restores exactly (the rest itself is not saved).
func _test_save_after_rest(tree: SceneTree) -> void:
	_heal()
	_state.essence.current = 20 # TEST-ONLY
	_check(_session.begin_rest() == "", "a rest begins")
	await _rest_out(tree)
	var snapshot: GameSaveSnapshot = Work.capture(_session)
	var restored: WorldSessionController = _restored(tree, snapshot)
	_check(restored != null and not restored.resting(), "restored, standing")
	if restored != null:
		var again: GameSaveSnapshot = Work.capture(restored)
		_check(again != null and GameSaveJsonCodec.encode(again).text == GameSaveJsonCodec.encode(snapshot).text, "the save after a rest restores exactly")
		_check(restored.player_runtime().state.essence.current == _state.essence.current and restored.day_clock().day_seconds() == _session.day_clock().day_seconds(), "精 and the clock as they were")
		restored.free()
		await tree.process_frame


## An aggressive NPC noticing the player cuts the rest short; the fight then comes as ever:
## resting just inside 京师's east gate with the guards' grudge (garrison.c's vendetta).
func _test_attacker(tree: SceneTree) -> void:
	_state.vitality = CharacterResourceState.new(10000000, 10000000, 10000000) # TEST-ONLY: the fight is not the point
	_state.vendetta["authority"] = 1 # TEST-ONLY: the guards' grudge
	var map: WorldMapController = MapPlaces.enter(_session, &"city.nroad2", &"city.nroad2.village_arrival") # TEST-ONLY: at the city
	if not _check(map != null and map.map_id() == MapPlaces.map_of(GATE), "TEST-ONLY: on 京师's map"):
		return
	map.set_process(false) # TEST-ONLY: the map's frames by hand
	await tree.physics_frame
	var noticer: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition_id) == &"city.npc.guard" and npc.world_location().zone_id == GATE and npc.exists_in_map:
			if noticer == null or map.runtime_body_for_character(npc.character_id).global_position.x < map.runtime_body_for_character(noticer.character_id).global_position.x:
				noticer = npc
	if not _check(noticer != null, "a guard at the gate"):
		return
	_state.essence.current = 10 # TEST-ONLY
	map.runtime_player_body().global_position = MapPlaces.spot(map, GATE, Vector2(MapPlaces.zone_rect(map, GATE).position.x + 16.0, map.runtime_body_for_character(noticer.character_id).global_position.y), 24.0)
	_player.set_world_location(map.location_for_zone(GATE))
	await tree.physics_frame
	await tree.physics_frame
	_check(_session.begin_rest() == "", "a rest begins inside the gate")
	_session._process(FRAME)
	map._process(0.0)
	_session._process(FRAME)
	_check(not _session.resting() and _ended[-1] == RestRules.Outcome.ATTACKED, "cut short: %s" % [_ended])
	_check(_hud.log_lines().any(func(line: String) -> bool: return line.contains("有人来袭")), "told: someone came at you")
	_check(not map.runtime_player_body().walk_paused, "on one's feet again")
	for _i: int in 10:
		map._process(0.1)
	_check(_session.combat_encounter_coordinator().has_active_encounter(), "the fight comes as ever")
	_check(_session.begin_rest() == RestLines.REFUSE_FIGHTING, "no rest in a fight")
	await tree.process_frame


## Drives the resting world by hand until the rest ends: the world seconds it took.
func _rest_out(tree: SceneTree) -> float:
	var seconds: float = 0.0
	var frames: int = 0
	while _session.resting() and frames < 2000:
		_session._process(FRAME)
		seconds += FRAME * float(GameContent.catalog().pacing().rest_world_scale)
		frames += 1
		if frames % 50 == 0:
			await tree.process_frame
	return seconds


func _lesson_ready(skill_id: StringName, level: int) -> void:
	_state.skills.set_raw_level(skill_id, level)
	_state.skills.set_learned_progress(skill_id, 0)
	_heal()
	var teacher: CharacterState = _school.npc.character_state
	teacher.spirit.current = teacher.spirit.maximum
	_state.progression.potential = 1000
	_state.progression.potential_spent = 0
	_state.progression.combat_experience = 2000


func _cost() -> int:
	return LearnService.base_essence_cost(_school.npc.character_state.attributes.intelligence, _state.attributes.intelligence)


## TEST-ONLY: gin, kee and sen full.
func _heal() -> void:
	for resource: CharacterResourceState in [_state.essence, _state.vitality, _state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _restored(tree: SceneTree, snapshot: GameSaveSnapshot) -> WorldSessionController:
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
	if not decoded.succeeded():
		return null
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	if not restored.succeeded():
		return null
	var fresh: WorldSessionController = restored.candidate
	return fresh if fresh.activate_restore_candidate() else null


func _to_snow(tree: SceneTree) -> void:
	for _step: int in range(400):
		MapRoute.press_toward(_session.active_map().runtime_player_body(), Vector2.RIGHT)
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	MapPlaces.release()
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(map: WorldMapController, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return _player.set_world_location(map.location_for_zone(zone_id))
	return false


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append("player rest: " + label)
	return ok
