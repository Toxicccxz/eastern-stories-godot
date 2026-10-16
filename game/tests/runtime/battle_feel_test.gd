extends RefCounted

## 现代化修正 III B2「手感：战斗」(DECISIONS「手感」): the 战斗速度 setting changes only how
## many real seconds a fight's own clock takes (BattlePace): its rounds, and 朱鸿雪's task
## time while it runs, count the same at 慢, 标准 and 快. The settings keep it (schema 3;
## older files read as 标准). The battle panel tells a round's lines one after another,
## moves and flashes the cards after them, and holds a finished fight's last lines with
## the world held before the result. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _ui: BattlePresentationController
var _coordinator: CombatEncounterCoordinator


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_pace()
	_test_settings()
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	_coordinator = _session.combat_encounter_coordinator()
	await _test_fight_clock(tree)
	await _test_lines(tree)
	await _test_end_hold(tree)
	_test_card(tree)
	BattlePace.speed = BattlePace.Speed.NORMAL
	BattlePace.hit_flash = true
	TestFeel.restore()
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_pace() -> void:
	TestFeel.use()
	var percents: Array[int] = [BattlePace.percent(BattlePace.Speed.SLOW), BattlePace.percent(BattlePace.Speed.NORMAL), BattlePace.percent(BattlePace.Speed.FAST)]
	_check(percents == [150, 100, 60], "pacing.json: 慢 a round in 150 %%, 快 in 60 %%: %s" % [percents])
	BattlePace.speed = BattlePace.Speed.SLOW
	_check(is_equal_approx(BattlePace.fight_seconds(1.5), 1.0) and is_equal_approx(BattlePace.real_seconds(1.0), 1.5), "慢: 1.5 real seconds are one second of the fight")
	BattlePace.speed = BattlePace.Speed.FAST
	_check(is_equal_approx(BattlePace.fight_seconds(0.6), 1.0), "快: 0.6 real seconds are one")
	TestFeel.restore()
	_check(BattlePace.percent() == 100, "the feel off: every speed is the round itself")
	BattlePace.speed = BattlePace.Speed.NORMAL
	_check(BattlePace.from_storage("slow") == BattlePace.Speed.SLOW and BattlePace.storage_value(BattlePace.Speed.FAST) == "fast" and BattlePace.from_storage("brisk") == -1, "stored as slow / normal / fast")


func _test_settings() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=2\nwindow_mode=\"windowed\"\nlanguage=\"zh_CN\"\n".to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().battle_speed() == BattlePace.Speed.NORMAL and old.snapshot().hit_flash() and old.snapshot().language() == "zh_CN", "a version 2 file: 标准, the flash on, its language kept")
	var written: ApplicationSettingsResult = repository.write(ApplicationSettingsSnapshot.defaults().with_battle(BattlePace.Speed.FAST, false))
	var back: ApplicationSettingsResult = repository.load()
	_check(written.succeeded() and back.succeeded() and back.snapshot().battle_speed() == BattlePace.Speed.FAST and not back.snapshot().hit_flash() and back.snapshot().version() == 3, "written and read back: 快, no flash (schema 3)")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=3\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"brisk\"\nhit_flash=true\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "an unknown speed is refused")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=3\nwindow_mode=\"windowed\"\nlanguage=\"\"\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a version 3 file without them is refused")
	ApplicationSettingsService._apply_battle(back.snapshot())
	_check(BattlePace.speed == BattlePace.Speed.FAST and not BattlePace.hit_flash, "applied: the fight's clock and the cards follow them")
	BattlePace.speed = BattlePace.Speed.NORMAL
	BattlePace.hit_flash = true


## The fight's own clock: three real seconds are two rounds at 慢, five at 快, three at 标准;
## the task loses two, five and three seconds of its time.
func _test_fight_clock(tree: SceneTree) -> void:
	TestFeel.use()
	var map: WorldMapController = _session.active_map() as WorldMapController
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.2")
	_check(_beside(map, &"snow.school2", &"snow.school2.trainee.2"), "beside a trainee")
	await tree.physics_frame
	map.select_npc(trainee.character_id)
	_player.state.quest.assign(QuestDefinition.new("疯狗", QuestDefinition.KILL, 300, 20, 10, 5), 1) # TEST-ONLY: a task running
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "an attack starts")
	# TEST-ONLY: neither falls for a while.
	for state: CharacterState in [_player.state, trainee.character_state]:
		state.vitality = CharacterResourceState.new(100000, 100000, 100000)
		state.essence = CharacterResourceState.new(100000, 100000, 100000)
		state.spirit = CharacterResourceState.new(100000, 100000, 100000)
	var counted: Array[Array] = []
	for speed: int in [BattlePace.Speed.SLOW, BattlePace.Speed.FAST, BattlePace.Speed.NORMAL]:
		BattlePace.speed = speed
		var scheduler: CombatEncounterScheduler = _coordinator.active_scheduler()
		var rounds: int = scheduler.logical_cycle
		var task: int = _player.state.quest.remaining_ms
		for step: int in 30:
			_session._process(0.1)
		counted.append([scheduler.logical_cycle - rounds, task - _player.state.quest.remaining_ms])
	var per_round: bool = counted.all(func(pair: Array) -> bool: return absi(int(pair[1]) - int(pair[0]) * 1000) <= 1)
	_check(counted.map(func(pair: Array) -> int: return pair[0]) == [2, 5, 3] and per_round, "3 s: 慢 2 rounds, 快 5, 标准 3; the task a second a round (to the ms): %s" % [counted])
	BattlePace.speed = BattlePace.Speed.NORMAL
	_player.state.quest.clear_task()
	TestFeel.restore()


## A round's lines one after another: the first at once, then 0.12 s apart; more than a
## round can tell come closer, all before the next.
func _test_lines(tree: SceneTree) -> void:
	TestFeel.use()
	_ui.refresh_projection()
	_ui._line_queue.clear()
	_ui._told.clear()
	_ui._line_wait = 0.0
	var lines: Array[BattleNarrationLine] = []
	for index: int in 3:
		lines.append(BattleNarrationLine.new("第%d句" % index))
	_ui._queue_lines(lines)
	var told: Array[int] = [_ui._told.size()]
	_ui._tell_lines(0.1)
	told.append(_ui._told.size())
	_ui._tell_lines(0.03)
	told.append(_ui._told.size())
	_ui._tell_lines(0.12)
	told.append(_ui._told.size())
	_check(told == [1, 1, 2, 3], "told at 0, 0.12, 0.24 s: %s" % [told])
	var many: Array[BattleNarrationLine] = []
	for index: int in 20:
		many.append(BattleNarrationLine.new("句%d" % index))
	_ui._queue_lines(many)
	var waited: float = 0.0
	while not _ui._line_queue.is_empty() and waited < 3.0:
		_ui._tell_lines(0.01)
		waited += 0.01
	_check(waited < 0.95, "twenty lines told within the round: %.2f s" % waited)
	TestFeel.restore()
	await tree.process_frame


## The fight's end: its last lines stay on the panel 0.8 s with the world held; then the
## result, the world and the HUD.
func _test_end_hold(tree: SceneTree) -> void:
	TestFeel.use()
	var map: WorldMapController = _session.active_map() as WorldMapController
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.2")
	trainee.character_state.vitality = CharacterResourceState.new(1, 1, 100000) # TEST-ONLY: the next blow ends it
	_player.state.progression.combat_experience = 100000 # TEST-ONLY: it lands
	var lines_before: int = _session.shared_ui().log_lines().size()
	for step: int in 600:
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_ui.refresh_projection()
	_check(not _coordinator.has_active_encounter() and _ui._holding() and _ui.visible and _session.world_time_held(), "over: the panel holds, the world held")
	_check(_session.shared_ui().log_lines().size() == lines_before, "no result yet")
	_player.busy.start_busy(3) # TEST-ONLY: busy and a task running through the hold
	_player.state.quest.assign(QuestDefinition.new("疯狗", QuestDefinition.KILL, 300, 20, 10, 5), 1)
	var task: int = _player.state.quest.remaining_ms
	for step: int in 5:
		_session._process(0.1)
	_check(_session.presentation_frozen() and _player.busy.busy_value == 3 and _player.state.quest.remaining_ms == task, "the hold takes nobody's time: busy %d, task %d ms less" % [_player.busy.busy_value, task - _player.state.quest.remaining_ms])
	_ui._process(0.5)
	_check(_ui._holding(), "still at 0.5 s")
	_ui._process(0.4)
	_check(not _ui._holding() and not _ui.visible and not _session.world_time_held() and _session.shared_ui().log_lines().size() > lines_before, "at 0.9 s: the result, the world, the HUD: %s" % [_session.shared_ui().log_lines().slice(lines_before)])
	while _player.busy.is_busy():
		_player.busy.advance()
	_player.state.quest.clear_task()
	TestFeel.restore()
	await tree.process_frame


## A card's 气 bar moves to a lower value and the card flashes; without 受击闪红 it does not.
func _test_card(tree: SceneTree) -> void:
	TestFeel.use()
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	card._vitality.max_value = 100
	card._show_vitality(&"a", 100)
	card._show_vitality(&"a", 60)
	_check(card.vitality_shown() > 60.0 and card.self_modulate != Color.WHITE, "the bar on its way down, the card red")
	BattlePace.hit_flash = false
	card.self_modulate = Color.WHITE
	card._show_vitality(&"a", 30)
	_check(card.self_modulate == Color.WHITE, "受击闪红 off: no flash")
	BattlePace.hit_flash = true
	card._show_vitality(&"b", 10)
	_check(card.vitality_shown() == 10.0, "someone else on the card: at once")
	card.free()
	TestFeel.restore()


func _to_snow(tree: SceneTree) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
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


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
