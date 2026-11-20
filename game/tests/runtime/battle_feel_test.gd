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
	# 战斗演出 B: the settings above set 战斗开场 back to 全程; this suite pins the fight's own
	# feel, so its fights lay the stage at once (battle_stage_test has the opening).
	BattlePace.opening = BattlePace.Opening.OFF
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	_coordinator = _session.combat_encounter_coordinator()
	await _test_fight_clock(tree)
	await _test_lines(tree)
	await _test_end_hold(tree)
	await _test_scene_input(tree)
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
	var written: ApplicationSettingsResult = repository.write(ApplicationSettingsSnapshot.defaults().with_battle(BattlePace.Speed.FAST, false, BattlePace.AfterKnockout.ASK))
	var back: ApplicationSettingsResult = repository.load()
	_check(written.succeeded() and back.succeeded() and back.snapshot().battle_speed() == BattlePace.Speed.FAST and not back.snapshot().hit_flash() and back.snapshot().version() == ApplicationSettingsSnapshot.SCHEMA_VERSION, "written and read back: 快, no flash")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=3\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"brisk\"\nhit_flash=true\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "an unknown speed is refused")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=3\nwindow_mode=\"windowed\"\nlanguage=\"\"\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a version 3 file without them is refused")
	ApplicationSettingsService._apply_battle(back.snapshot())
	_check(BattlePace.speed == BattlePace.Speed.FAST and not BattlePace.hit_flash, "applied: the fight's clock and the cards follow them")
	BattlePace.speed = BattlePace.Speed.NORMAL
	BattlePace.hit_flash = true
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH # the suites run ES2 (run_suite.gd)


## The fight's own clock: three real seconds are two rounds at 慢, five at 快, three at 标准;
## the task loses two, five and three seconds of its time.
func _test_fight_clock(tree: SceneTree) -> void:
	TestFeel.use()
	var map: WorldMapController = await _beside(tree, &"snow.school2", &"snow.school2.trainee.2")
	_check(map != null, "beside a trainee")
	var trainee: NpcRuntimeState = MapPlaces.npc_at(_session, &"snow.school2.trainee.2")
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
	# 战斗拍数 B: under 自动 the lines come at the 快 pace; the pin below is 手动's.
	var manual_before: bool = BattlePace.manual_turns
	BattlePace.manual_turns = true
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
	BattlePace.manual_turns = false
	_ui.refresh_projection()
	_ui._line_queue.clear()
	_ui._told.clear()
	_ui._line_wait = 0.0
	var quick: Array[BattleNarrationLine] = []
	for index: int in 3:
		quick.append(BattleNarrationLine.new("快%d句" % index))
	_ui._queue_lines(quick)
	_check(_ui._projection.beats_shown() and is_equal_approx(_ui._line_spacing, 0.12 * float(BattlePace.percent(BattlePace.Speed.FAST)) / 100.0), "自动 with the beats: the lines at the 快 pace (%.3f s)" % _ui._line_spacing)
	BattlePace.manual_turns = manual_before
	_ui.refresh_projection()
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


## 战斗拍数 C: the scene's show and the strip's pauses never lock the input — a beat told
## still (the lines queued, the figures moving), the next order is taken; the figures are
## the view's and the show moves their models, not the bodies; the sounds record what played.
func _test_scene_input(tree: SceneTree) -> void:
	TestFeel.use()
	var manual_before: bool = BattlePace.manual_turns
	BattlePace.manual_turns = true
	# After the end hold (the last fight over, trainee.2 dead): a fresh trainee.
	var map: WorldMapController = await _beside(tree, &"snow.school2", &"snow.school2.trainee.1")
	_check(map != null, "beside a trainee")
	var trainee: NpcRuntimeState = MapPlaces.npc_at(_session, &"snow.school2.trainee.1")
	trainee.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: outlast the test
	_player.state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	map.select_npc(trainee.character_id)
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks (%d)" % started.outcome)
	var waited: float = 0.0
	while not _coordinator.waiting_for_player() and _coordinator.has_active_encounter() and waited < 5.0:
		await tree.process_frame
		waited += 0.05
	_ui.refresh_projection()
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	_check(_ui.scene_show.view == view and view != null, "the show plays in the map's voxel view")
	# 战斗特效: the show has the fight's base to answer the blows, and a 死斗's dark chips.
	_check(_ui.scene_show.stage != null and _ui.scene_show.stage == _ui.opening.arena and _ui.scene_show.blood_chips == BattleSceneShow.blood_for(CombatEncounterMode.Value.LETHAL) and _ui.scene_show.blood_chips > 0, "the show holds the fight's base and a 死斗's dark chips (%s, %d)" % [_ui.scene_show.stage, _ui.scene_show.blood_chips])
	# 战斗演出 B: the opening stages the camera (here at once: 关); the show leaves it there.
	_check(view.staged and is_equal_approx(view.zoom(), float(_ui.opening.frame()[2])) and view.zoom() < 1.0, "the fight began: the opening drew the camera in (%.2f)" % view.zoom())
	await _test_special_moment(tree, trainee)
	var body_before: Vector2 = map.runtime_body_for_character(trainee.character_id).global_position
	# A move of one beat (a 重 costs the round's two, and the second press must afford one).
	var cheap: StringName = &""
	for move: CombatActionDefinition in _coordinator.player_moves():
		if _coordinator.move_cost(move.action_id) == 1 and not _coordinator.locked_moves().has(move.action_id):
			cheap = move.action_id
			break
	_check(_coordinator.waiting_for_player() and not cheap.is_empty() and _coordinator.choose_attack(cheap), "the first beat ordered")
	# The round runs on the next advance: the beat, the trainee's, then it waits on the
	# player's second beat while the strip is still telling the first.
	_coordinator.advance_scheduler(1.0)
	_ui.refresh_projection()
	var showing: bool = not _ui._line_queue.is_empty() or not _ui.scene_show._tweens.is_empty()
	_check(showing, "the beat's lines are still being told, the figures moving (%d lines queued, %d figures in a show)" % [_ui._line_queue.size(), _ui.scene_show._tweens.size()])
	# 节拍填格: pressed on the panel, the beat fills its slot at once — the input never waits on it.
	_check(_coordinator.waiting_for_player(), "waiting on the next beat while the first is told (%d lines queued)" % _ui._line_queue.size())
	_ui._choose_move(cheap)
	_check(_coordinator.player_choice() == cheap and _ui.action_panel.chips.pending_count() == 1 and _ui.action_panel.beat_fill.playing(), "and the next beat is taken all the same, its slot filling at once: the input is never locked (choice %s, held %d)" % [_coordinator.player_choice(), _ui.action_panel.chips.pending_count()])
	# The last beat resolves the next frame and closes the round; the strip waits for the fill.
	for frame: int in 3:
		await tree.process_frame
	_ui.refresh_projection()
	_check(_ui.action_panel.beat_fill.playing() and _ui.action_panel.chips.frozen() and _ui.action_panel.chips.pending_count() == 1, "a few frames on, the fill still plays over its slot (playing %s, frozen %s, held %d)" % [_ui.action_panel.beat_fill.playing(), _ui.action_panel.chips.frozen(), _ui.action_panel.chips.pending_count()])
	await tree.create_timer(0.6).timeout
	_ui.refresh_projection()
	_check(not _ui.action_panel.beat_fill.playing() and not _ui.action_panel.chips.frozen(), "full: the strip takes the fight's record again")
	# The suite runs the fight's clock itself: once the beat is resolved its slot is the record's.
	_coordinator.advance_scheduler(1.0)
	_ui.refresh_projection()
	_check(_ui.action_panel.chips.pending_count() == 0, "the beat resolved: nothing held")
	await tree.create_timer(1.5).timeout
	_ui.refresh_projection()
	_check(map.runtime_body_for_character(trainee.character_id).global_position == body_before, "the 2D body never moved: the show moved the model only")
	_check(_ui.sounds.played_kinds().has(BattleSounds.CLAPPER), "the clap of the beats played: %s" % [_ui.sounds.played_kinds()])
	# The fight ends as the end hold's does (TEST-ONLY: the trainee falls to the next blow).
	trainee.character_state.vitality = CharacterResourceState.new(1, 1, 100000)
	_player.state.progression.combat_experience = 100000
	BattlePace.manual_turns = false
	for step: int in 600:
		if not _coordinator.has_active_encounter():
			break
		_coordinator.advance_scheduler(1.0)
	_ui.refresh_projection()
	_check(not _coordinator.has_active_encounter() and _ui._holding() and _ui.scene_show.view != null, "over: the panel holds, the show still on the scene")
	# 战斗肢体: killed by a blow the strip has yet to tell, the trainee's figure stands where it
	# stood and nothing lies there; once the hold is over it has fallen and what lies there is
	# the trainee as it was dressed, on its back.
	var killed: StringName = trainee.character_id
	var lying_before: int = _lying(view)
	await tree.process_frame
	await tree.process_frame
	var figure_killed: Node3D = view.actors[killed]
	_check(trainee.life_status == CharacterRuntimeLifeStatus.Value.DEAD and figure_killed.visible and view._lingering.has(killed) and is_zero_approx(float(figure_killed.get_child(0).get("limp"))) and _lying(view) == lying_before, "killed, its blow not told: the figure still stands, nothing lies there (life %d, shown %s, lingering %s, limp %s, lying %d/%d)" % [trainee.life_status, figure_killed.visible, view._lingering.has(killed), figure_killed.get_child(0).get("limp"), _lying(view), lying_before])
	await tree.create_timer(2.5).timeout
	_ui.refresh_projection()
	await tree.process_frame
	_check(not figure_killed.visible and view._lingering.is_empty() and view.fall_holds.is_empty() and _lying(view) == lying_before + 1, "the blow told, the hold over: the figure fell and is gone, the trainee lies there dressed (shown %s, lingering %d, held %d, lying %d/%d)" % [figure_killed.visible, view._lingering.size(), view.fall_holds.size(), _lying(view), lying_before])
	# One knocked senseless outside a fight topples over the fall's time, and rises as slowly.
	var other: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and view.actors.has(npc.character_id) and view.actors[npc.character_id].get_child(0).get("limp") != null:
			other = npc
			break
	if _check(other != null, "someone else stands in the hall"):
		var figure: Node3D = view.actors[other.character_id].get_child(0)
		other.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
		_check(float(figure.get("limp")) > 0.0 and float(figure.get("limp")) < 1.0, "knocked senseless: on its way down, not down at once (%.2f)" % float(figure.get("limp")))
		await tree.create_timer(0.6).timeout
		_check(is_equal_approx(float(figure.get("limp")), 1.0), "down (%.2f)" % float(figure.get("limp")))
		other.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
		await tree.create_timer(0.6).timeout
		_check(is_zero_approx(float(figure.get("limp"))), "awake: up again (%.2f)" % float(figure.get("limp")))
	_check(not _ui._holding() and _ui.scene_show.view == null and is_equal_approx(view.zoom(), 1.0), "the hold over: the show is over, the camera back (holding %s, zoom %.2f)" % [_ui._holding(), view.zoom()])
	_check(not _ui.action_panel.beat_fill.playing() and _ui.action_panel.chips.pending_count() == 0, "no fill left playing, nothing held")
	_player.state.progression.combat_experience = 100
	BattlePace.manual_turns = manual_before
	TestFeel.restore()
	await tree.process_frame


## 战斗绝招 (DECISIONS「战斗绝招」): a special that strikes opens with a held moment — its name
## written over the fight, the map under the stage darker, the scene gathering — before its first
## line is told; inner work has none; seen a few times, the moment is short.
func _test_special_moment(tree: SceneTree, trainee: NpcRuntimeState) -> void:
	var me: StringName = _player.character_id
	BattlePresentationController.specials_seen.clear()
	var inner := BattleNarrationLine.new("你运功疗伤。").with_special(me, "疗伤").with_beat(1, me)
	var opener := BattleNarrationLine.new("你剑势一凝！").with_special(me, "封字诀").with_beat(1, me)
	var strike := BattleNarrationLine.new("x", -1).with_blow(me, trainee.character_id, "封", CombatAttackResult.Outcome.DODGE, -1).with_ring(&"", 0).with_arms(&"sword", "刺伤").with_special_blow().with_beat(1, me)
	# The fight's opening lines first.
	for step: int in 80:
		if _ui._line_queue.is_empty():
			break
		_ui._tell_lines(0.2)
	_check(_ui._line_queue.is_empty(), "nothing waits to be told (%d)" % _ui._line_queue.size())
	_ui._line_queue.append(inner)
	_check(is_zero_approx(_ui._special_hold(inner)), "inner work (no blow follows): no moment")
	_ui._tell_lines(0.01)
	_check(_ui._line_queue.is_empty() and not _ui.special_banner.showing(), "it is told at once, nothing written over the fight")
	# 战斗运功: told with its art, it shows in the scene — as a special's opening or as a plain line.
	var arts: Callable = func() -> int: return _ui.scene_show._effects.filter(func(effect: Node3D) -> bool: return is_instance_valid(effect) and effect.has_meta(&"art")).size()
	_check(arts.call() == 0, "an exert told without an art: none in the scene")
	_ui._line_queue.append(BattleNarrationLine.new("你深深吸了几口气。").with_special(me, "运功恢复气").with_art(me, &"exert/recover").with_beat(1, me))
	_ui._tell_lines(0.01)
	_check(_ui._line_queue.is_empty() and arts.call() == 1 and not _ui.special_banner.showing(), "an exert with its art: told at once, its figure in the scene, no banner (%d)" % arts.call())
	_ui._line_queue.append(BattleNarrationLine.new("x").with_art(trainee.character_id, &"exert/powerup").with_beat(1, trainee.character_id))
	for step: int in 20:
		if _ui._line_queue.is_empty():
			break
		_ui._tell_lines(0.2)
	_check(_ui._line_queue.is_empty() and arts.call() == 2, "an NPC's, told as a plain line: in the scene too (%d)" % arts.call())
	# The feel off (no time between lines): a special is told at once, nothing written.
	var spacing: float = _ui._line_spacing
	_ui._line_spacing = 0.0
	var quiet := BattleNarrationLine.new("你剑势一凝！").with_special(me, "缺字诀").with_beat(1, me)
	_ui._line_queue.append(quiet)
	_ui._line_queue.append(BattleNarrationLine.new("x", -1).with_blow(me, trainee.character_id, "封", CombatAttackResult.Outcome.DODGE, -1).with_ring(&"", 0).with_arms(&"sword", "刺伤").with_special_blow().with_beat(1, me))
	_ui._tell_lines(0.0)
	_check(_ui._line_queue.is_empty() and not _ui.special_banner.showing() and BattlePresentationController.specials_seen.is_empty(), "the feel off: told at once, no moment, nothing written")
	_ui._line_spacing = spacing
	_ui._line_queue.append(opener)
	_ui._line_queue.append(strike)
	var full: float = _ui._special_hold(opener)
	_check(full > 0.5, "a special that strikes: a moment of %.2f s" % full)
	_ui._line_wait = 0.0
	_ui._tell_lines(0.01)
	_check(_ui._line_queue.size() == 2 and _ui.special_banner.shown_text() == "封字诀" and BattlePresentationController.specials_seen.get("封字诀", 0) == 1, "the moment: its name written over the fight, its first line not told yet (%d waiting, '%s')" % [_ui._line_queue.size(), _ui.special_banner.shown_text()])
	_check(_ui.opening.dimmed() and _ui.scene_show.pushed(), "the map under the stage darker, the camera pushed in (dimmed %s, pushed %s)" % [_ui.opening.dimmed(), _ui.scene_show.pushed()])
	_ui._tell_lines(full * 0.5)
	_check(_ui._line_queue.size() == 2, "half way through: still held")
	_ui._tell_lines(full * 0.5 + 0.02)
	var over_heads: Array = _ui.move_titles.shown().map(func(entry: Array) -> String: return entry[0])
	_check(_ui._line_queue.size() < 2 and not over_heads.has("封字诀"), "the moment over: its line told, and its name not written a second time over the head (%s)" % [over_heads])
	for step: int in 40:
		if _ui._line_queue.is_empty():
			break
		_ui._tell_lines(0.2)
	_check(_ui._line_queue.is_empty(), "its blows told")
	BattlePresentationController.specials_seen["封字诀"] = int(BattleArena.data()["special"]["full_times"])
	_ui._line_queue.append(opener)
	_ui._line_queue.append(strike)
	_check(_ui._special_hold(opener) > 0.0 and _ui._special_hold(opener) < full * 0.6, "seen a few times: a short moment (%.2f against %.2f)" % [_ui._special_hold(opener), full])
	_ui._line_queue.clear()
	BattlePresentationController.specials_seen.clear()
	_ui.special_banner.clear()
	await tree.create_timer(1.2).timeout
	_check(not _ui.scene_show.pushed(), "the camera back where the fight had it")


## The fight's end: its last lines stay on the panel 0.8 s with the world held; then the
## result, the world and the HUD.
func _test_end_hold(tree: SceneTree) -> void:
	TestFeel.use()
	var trainee: NpcRuntimeState = MapPlaces.npc_at(_session, &"snow.school2.trainee.2")
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
	# DECISIONS「战斗演出」: once the last lines are told, the 胜 stamp over the cards and the
	# 亡 on the trainee's card (killed by the last blow, after the cards' last refresh).
	_ui._hold_left = 0.1 # TEST-ONLY: as if the last lines took most of the hold to drain
	_ui._tell_lines(5.0)
	var fallen: Array[String] = []
	for card: BattleParticipantCard in _ui._cards:
		fallen.append(card.fallen_text())
	_check(_ui.end_stamp.visible and _ui.end_stamp.text == "胜" and fallen == ["", "亡"], "the end hold: 胜 over the cards, 亡 on the trainee's: %s '%s'" % [fallen, _ui.end_stamp.text])
	# The stamp's 0.6 s, and a moment after it for the autosave's capture on a still picture
	# (DECISIONS「等待的量」; review fix X).
	_check(is_equal_approx(_ui._hold_left, 0.6 + BattlePresentationController.STILL_TAIL_SECONDS), "the stamp keeps its 0.6 s of the hold when the lines drained most of it: %.2f" % _ui._hold_left)
	_player.busy.start_busy(3) # TEST-ONLY: busy and a task running through the hold
	_player.state.quest.assign(QuestDefinition.new("疯狗", QuestDefinition.KILL, 300, 20, 10, 5), 1)
	var task: int = _player.state.quest.remaining_ms
	for step: int in 5:
		_session._process(0.1)
	_check(_session.presentation_frozen() and _player.busy.busy_value == 3 and _player.state.quest.remaining_ms == task, "the hold takes nobody's time: busy %d, task %d ms less" % [_player.busy.busy_value, task - _player.state.quest.remaining_ms])
	_ui._process(0.5)
	_check(_ui._holding(), "still at 0.5 s")
	_ui._process(0.4)
	# The frame the picture is still keeps the hold one frame more (the autosave's moment comes in
	# the session's next frame; review fix X): the next frame ends it.
	_ui._process(0.05)
	_check(not _ui._holding() and not _ui.visible and not _session.world_time_held() and _session.shared_ui().log_lines().size() > lines_before, "at 0.95 s: the result, the world, the HUD: %s" % [_session.shared_ui().log_lines().slice(lines_before)])
	_check(not _ui.end_stamp.visible, "the stamp goes with the hold")
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


## How many of the view's things on the ground are a figure lying dressed (a fresh corpse).
static func _lying(view: WorldVoxelView) -> int:
	var count: int = 0
	for node: Node3D in view.objects.values():
		if is_instance_valid(node) and node.has_node("Body"):
			count += 1
	return count


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


## The player beside the NPC of a spawn point, on the map its zone lies on (the 武馆 is its own
## map since the remap); returns that map, or null.
func _beside(tree: SceneTree, zone_id: StringName, point_id: StringName) -> WorldMapController:
	# The hand-off itself is no part of the feel under test: no fade holds the world after it.
	TestFeel.restore()
	var map: WorldMapController = MapPlaces.enter(_session, zone_id, point_id)
	TestFeel.use()
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
			return map if _player.set_world_location(map.location_for_zone(zone_id)) else null
	return null


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
