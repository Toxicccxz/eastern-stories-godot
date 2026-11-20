extends RefCounted

## 自动歇 (成长曲线 B; DECISIONS「连续修炼」「歇到回满」): with pacing's training_auto_rest a continuous
## 请教 / 练习 / 打坐 that comes to a step 精, 气 or 神 is short for rests by itself — the page stays
## open, the world runs rest_world_scale times as fast behind it (the window's hold lifted while the
## rest lasts), nothing is said meanwhile — and goes on with the same run once the three are full:
## on to potential spent, a level, a maximum up. A rest at its longest with something come back goes
## on too. A rest broken off (掉血 here; 有人来袭 is the same path) ends the run with the rest's own
## line; 停止 stops the rest with the run; with no water, or 朱鸿雪's task against its time, the run
## stops and says why; full already and still short, it stops as without 自动歇. Only the window's
## own hold is lifted. The summary tells the steps' own 精 (not what came back). run_to_end() never
## rests. The knobs: pacing.json's 40 times and 60 ms a step (150 for a run that does not rest);
## left out, ES2's (no 自动歇).
## TEST-ONLY fixtures, marked where used: gin/kee/sen, water, potential and skill levels set directly.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SCHOOL: StringName = &"snow.school_compound.schoolhall.master"
## Seconds of one hand-driven frame of the session (world time while resting: 40 times as much).
const FRAME: float = 0.1

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _school: TeacherService
var _ended: Array[int] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_knobs()
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
	await _test_learn_rests_and_goes_on(tree)
	await _test_rest_broken_off(tree)
	await _test_stopped_while_resting(tree)
	_test_no_water()
	_test_task_holds_rest_back()
	await _test_wound_goes_on_at_the_limit(tree)
	_test_limit_with_nothing_back()
	_test_run_to_end_never_rests()
	await _test_practice(tree)
	await _test_exercise(tree)
	_test_step_seconds()
	await _test_pseudo_locale(tree)
	TestDay.restore()
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_knobs() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_check(pacing.training_auto_rest and pacing.rest_world_scale == 40, "pacing.json: runs rest by themselves, 40 times as fast")
	_check(pacing.copy().training_auto_rest, "a copy keeps it")
	_check(is_equal_approx(TestFeel.production.training_auto_step_seconds, 0.06) and is_equal_approx(TestFeel.production.training_step_seconds, 0.15), "pacing.json's feel: 60 ms a step resting by itself, 150 otherwise")
	var errors: Array[String] = []
	var left_out: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors))
	_check(errors.is_empty() and not left_out.training_auto_rest, "left out: ES2, a run stops for 精")
	var broken: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "training_auto_rest": true}, "p", broken))
	_check(broken.size() == 1 and broken[0].contains("training_auto_rest"), "resting by itself needs 歇到回满: %s" % [broken])


## 连续请教 with 精 for two lessons and potential for six: two, a rest with the page open and the
## world running behind it (nothing said), four more, then learn.c's potential line; one summary.
func _test_learn_rests_and_goes_on(tree: SceneTree) -> void:
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() * 2 + 3 # TEST-ONLY: two lessons and 3 over
	_state.progression.potential_spent = _state.progression.potential - 6 # TEST-ONLY: six lessons
	var learned: int = _state.skills.learned_progress(&"sword")
	var day_before: int = _session.day_clock().day_seconds()
	_check(await _open_teacher_page(tree), "the 请教 page in the popup, which holds world time")
	var panel: TeacherPanel = _school.ui
	var logged: int = _hud.log_lines().size()
	panel.run_buttons[&"sword"].pressed.emit()
	_check(panel.progress.running() and _session.resting_for_training(), "two lessons, then it rests by itself")
	_check(_state.progression.potential_spent == _state.progression.potential - 4, "two lessons taken first")
	_check(panel.panel.visible and not _session.world_time_held(), "the page stays open and the world runs behind it")
	_check(_session.active_map().runtime_player_body().walk_paused, "no walking while resting")
	_check(not _hud.rest_overlay.shown(), "no band over the world: the page tells it")
	await tree.process_frame
	_check(panel.progress.status.text.contains("歇息中"), "the run says it rests: " + panel.progress.status.text)
	await _drive(tree, panel.progress)
	_check(not panel.progress.running() and _state.progression.potential_spent == _state.progression.potential, "on to the potential spent")
	_check(_ended.size() >= 1 and _ended.back() == RestRules.Outcome.RESTED, "the rest ended full: %s" % [_ended])
	var said: Array[String] = _hud.log_lines().slice(logged)
	_check(not said.has(TranslationServer.translate(RestLines.BEGIN)) and not said.any(func(line: String) -> bool: return line.contains("精、气、神都回满了")), "the rest said nothing of its own: %s" % [said])
	var gain: int = _state.skills.learned_progress(&"sword") - learned
	var lines: Array[String] = ColoredLine.texts(_school.last_colored)
	_check(said.size() >= 2 and said.slice(-2) == lines, "the run's lines in the log: %s" % [said])
	_check(lines.size() == 2 and lines[0].begins_with("你向柳淳风请教「基本剑法」6 次（其间歇了 1 回，共") and lines[0].ends_with("）：基本剑法进度 +%d，精 -%d，潜能 -6。" % [gain, _cost() * 6]), "one summary, the rest in it, the six lessons' 精 (not what came back): %s" % [lines])
	_check(lines.size() == 2 and lines[1] == "你的潜能已经发挥到极限了，没有办法再成长了。", "then learn.c's own line: %s" % [lines])
	_check(panel.panel.visible and _session.world_time_held(), "the page holds the world again")
	_check(posmod(_session.day_clock().day_seconds() - day_before, DayClock.DAY_SECONDS) > 0, "the clock went on while resting")
	_check(not _session.active_map().runtime_player_body().walk_paused, "on one's feet again")
	await _close_teacher_page(tree)


## A hurt while resting (a hazard, poison) breaks the rest off, and the run with it: the rest's line.
func _test_rest_broken_off(tree: SceneTree) -> void:
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() + 3 # TEST-ONLY: one lesson
	_school.interact()
	await tree.process_frame
	var panel: TeacherPanel = _school.ui
	panel.run_buttons[&"sword"].pressed.emit()
	_check(_session.resting_for_training(), "one lesson, then a rest")
	_session._process(FRAME)
	_state.spirit.current -= 50 # TEST-ONLY: something hurts while resting (more than a heal_up() gives)
	_session._process(FRAME)
	_check(not _session.resting() and _ended.back() == RestRules.Outcome.HURT, "the rest is broken off: %s" % [_ended])
	await tree.process_frame
	var lines: Array[String] = ColoredLine.texts(_school.last_colored)
	_check(not panel.progress.running() and lines.size() == 2 and lines[0].begins_with("你向柳淳风请教「基本剑法」1 次（其间歇了 1 回") and lines[1].contains("身上一阵难受，歇不下去了"), "the run ends with the rest's line: %s" % [lines])
	_check(not lines.has("停下：你被打断了。"), "said once")
	panel.close_panel()
	await tree.process_frame


## 停止 (B) while the run rests stops the rest too. A hold that comes while it rests (a card,
## another window) holds the world as ever.
func _test_stopped_while_resting(tree: SceneTree) -> void:
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() + 3 # TEST-ONLY
	_check(await _open_teacher_page(tree), "the 请教 page again")
	var panel: TeacherPanel = _school.ui
	_session.hold_world_time(&"test_card") # TEST-ONLY: something else holds the world (a card)
	panel.run_buttons[&"sword"].pressed.emit()
	var day: int = _session.day_clock().day_seconds()
	_session._process(FRAME)
	_check(_session.resting_for_training() and panel.get_viewport().gui_get_focus_owner() == panel.progress.stop_button, "resting, 停止 has the focus")
	_check(_session.world_time_held() and _session.day_clock().day_seconds() == day, "only the popup's hold is lifted: another holds the world")
	_session.release_world_time(&"test_card")
	_session._process(FRAME)
	_check(not _session.world_time_held() and _session.day_clock().day_seconds() != day, "released: the rest goes on")
	_session.hold_world_time(&"test_card") # TEST-ONLY: and one that comes meanwhile
	day = _session.day_clock().day_seconds()
	_session._process(FRAME)
	_check(_session.world_time_held() and _session.day_clock().day_seconds() == day and _session.resting(), "a hold that came meanwhile holds it")
	_session.release_world_time(&"test_card")
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	panel.progress._input(back)
	_check(not panel.progress.running() and not _session.resting() and _ended.back() == RestRules.Outcome.CANCELLED, "B stops the run and the rest")
	_check(panel.progress.status.text.ends_with("你停了下来。") and _session.world_time_held(), "said so, the page holds the world again")
	await _close_teacher_page(tree)


## No water: no rest begins (damage.c gives nothing back), the run stops and says why.
func _test_no_water() -> void:
	_lesson_ready(&"sword", 15)
	var cost: int = _cost()
	_state.essence.current = cost + 3 # TEST-ONLY
	var water: int = _state.recovery.water
	_state.recovery.water = 0 # TEST-ONLY
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	while run.step():
		pass
	var lines: Array[String] = ColoredLine.texts(run.finish())
	_check(not _session.resting() and lines.size() == 3, "one lesson, then no rest: %s" % [lines])
	if lines.size() == 3:
		_check(lines[1] == "停下：精不够了。请教一次耗精 %d，精须多于此数（你还有 3）。" % cost, "the stop without the 歇到回满 hint: %s" % lines[1])
		_check(lines[2] == RestLines.REFUSE_THIRSTY, "and why it could not rest: %s" % lines[2])
	_state.recovery.water = water


## 朱鸿雪's task against its time: the run does not rest by itself (a rest would spend the time
## unasked) and says so; the task's time is as it was.
func _test_task_holds_rest_back() -> void:
	_lesson_ready(&"sword", 15)
	var cost: int = _cost()
	_state.essence.current = cost + 3 # TEST-ONLY
	_state.quest.assign(QuestDefinition.new("疯狗", QuestDefinition.KILL, 300, 20, 10, 5), 1) # TEST-ONLY: a task running
	var left: int = _state.quest.remaining_ms
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	while run.step():
		pass
	var lines: Array[String] = ColoredLine.texts(run.finish())
	_check(not _session.resting() and lines.size() == 3 and lines[2] == TrainingLines.RUN_TASK_TIME, "no rest by itself, and why: %s" % [lines])
	_check(lines.size() == 3 and lines[1] == "停下：精不够了。请教一次耗精 %d，精须多于此数（你还有 3）。" % cost and _state.quest.remaining_ms == left, "the task's time untouched")
	_state.quest.clear_task()


## A wound too deep for one rest: at its longest, with 精 come back, the run goes on.
func _test_wound_goes_on_at_the_limit(tree: SceneTree) -> void:
	_lesson_ready(&"sword", 15)
	var essence: CharacterResourceState = _state.essence
	var saved: Vector3i = Vector3i(essence.current, essence.effective, essence.maximum)
	essence.maximum = 5000 # TEST-ONLY: a wound that takes far longer than 600 s
	essence.effective = 10
	essence.current = 10
	_state.progression.potential_spent = _state.progression.potential - 2 # TEST-ONLY: two lessons
	var before: int = _ended.size()
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	_check(run.step() and run.resting() and run.training.steps == 0, "short at once: it rests")
	var frames: int = 0
	while run.resting() and frames < 400:
		_session._process(FRAME)
		frames += 1
	_check(_ended.slice(before) == [RestRules.Outcome.LIMIT] and not run.training.stopped(), "at its longest, 精 back: on: %s" % [_ended.slice(before)])
	while run.step():
		if run.resting():
			break
	var lines: Array[String] = ColoredLine.texts(run.finish())
	_check(run.training.steps == 2 and run.training.rests == 1 and lines.back() == "你的潜能已经发挥到极限了，没有办法再成长了。", "two lessons after the rest, then potential: %s" % [lines])
	essence.maximum = saved.z
	essence.effective = saved.y
	essence.current = saved.x
	await tree.process_frame


## TEST-ONLY, a white box: a rest at its longest with nothing come back (cannot happen with water,
## heal_up() always gives something) leaves the stop standing, the rest's line after it.
func _test_limit_with_nothing_back() -> void:
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() # TEST-ONLY: not above the cost
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	run.training.auto_rest = false
	run.step()
	run.training.auto_rest = true
	_check(run.training.stop == TrainingRun.Stop.WASTE_ESSENCE and run.training.rest_mends(), "short of 精: a rest would mend it")
	run._resting = true # TEST-ONLY: as if resting since the three were as now
	run._rest_from = RestRules.currents(_state)
	run._on_rest_ended(RestRules.Outcome.LIMIT, "LIMIT")
	_check(run.training.stop == TrainingRun.Stop.WASTE_ESSENCE and not run.step(), "the stop stands")
	var lines: Array[String] = ColoredLine.texts(run.finish())
	_check(lines.size() == 2 and lines[1] == "LIMIT", "the rest's line after it: %s" % [lines])


## run_to_end() takes every step at once: no rest (world time does not pass there), today's line.
func _test_run_to_end_never_rests() -> void:
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() + 3 # TEST-ONLY
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	var lines: Array[String] = ColoredLine.texts(run.run_to_end())
	_check(not _session.resting() and run.training.stop == TrainingRun.Stop.WASTE_ESSENCE and lines.back().contains("歇到回满"), "it stops for 精 as ever: %s" % [lines])


## 连续练习 柳家拳: three practices, kee short (liuh-ken's own line), a rest under the menu, the level.
func _test_practice(tree: SceneTree) -> void:
	_state.skills.set_raw_level(&"unarmed", 20) # TEST-ONLY
	_state.skills.set_raw_level(&"liuh-ken", 10) # TEST-ONLY
	_state.skills.set_learned_progress(&"liuh-ken", 106) # TEST-ONLY: four practices of 20/5 + 1 to the level
	_state.skills.map_skill(&"unarmed", &"liuh-ken")
	_heal()
	_state.vitality.current = 100 # TEST-ONLY: three practices of 30
	_hud.open_martial_arts()
	await tree.process_frame
	var page: MartialArtsPage = _hud.martial_arts_page()
	page.buttons["practice_run:unarmed"].pressed.emit()
	_check(page.progress.running() and _session.resting_for_training() and not _session.world_time_held(), "kee short: it rests, the menu open, the world running")
	await _drive(tree, page.progress)
	var lines: Array[String] = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(_state.skills.raw_level(&"liuh-ken") == 11 and not lines.is_empty() and lines[0].begins_with("你练习柳家拳 4 次（其间歇了 1 回") and lines.has("你的「柳家拳」进步了！"), "on to the level: %s" % [lines])
	_check(_session.world_time_held(), "the menu holds the world again")
	_hud.dismiss_current_panel()
	await tree.process_frame


## 连续打坐: three sittings, kee short (exercise.c's line), a rest, then two more to the maximum up.
func _test_exercise(tree: SceneTree) -> void:
	_state.skills.set_raw_level(&"force", 5) # TEST-ONLY
	_state.skills.set_raw_level(&"fonxanforce", 1)
	_state.skills.map_skill(&"force", &"fonxanforce")
	_state.attributes.constitution = 25 # TEST-ONLY: 30 kee gives 18 内力 (pacing's player_exercise_gain)
	_state.recovery.inner_force.maximum = 40 # TEST-ONLY: below the cap of (5 + 3 / 5) * 10 = 50
	_state.recovery.inner_force.current = 0
	_heal()
	_state.vitality.current = 95 # TEST-ONLY: three sittings of 30
	_hud.open_martial_arts()
	await tree.process_frame
	var page: MartialArtsPage = _hud.martial_arts_page()
	page.exercise_amount.value = 30
	page.exercise_target.select(0)
	page.exercise_run_button.pressed.emit()
	_check(page.progress.running() and _session.resting_for_training(), "kee short: it rests")
	await _drive(tree, page.progress)
	var lines: Array[String] = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(_state.recovery.inner_force.maximum == 41 and lines.size() == 2 and lines[0].begins_with("你打坐 5 次（其间歇了 1 回") and lines[1] == "你的内力增强了！", "on to the maximum up: %s" % [lines])
	_hud.dismiss_current_panel()
	await tree.process_frame


## A run resting by itself steps 60 ms apart; one that does not, 150.
func _test_step_seconds() -> void:
	TestFeel.use()
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	_check(is_equal_approx(run.step_seconds(), 0.06), "60 ms: %f" % run.step_seconds())
	run.auto_rest = false
	_check(is_equal_approx(run.step_seconds(), 0.15), "150 ms without 自动歇: %f" % run.step_seconds())
	TestFeel.restore()


## Under the pseudo-locale a resting run's line on the page and a rested run's lines (the rests,
## the stop without the hint, why no rest) are all translated.
func _test_pseudo_locale(tree: SceneTree) -> void:
	var translation: Translation = PseudoLocale.translation()
	var locale: String = TranslationServer.get_locale()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(PseudoLocale.CODE)
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() + 3 # TEST-ONLY: one lesson, then a rest
	_school.interact()
	await tree.process_frame
	var panel: TeacherPanel = _school.ui
	panel.run_buttons[&"sword"].pressed.emit()
	await tree.process_frame
	var resting: String = panel.progress.status.text
	_check(_session.resting_for_training() and PseudoLocale.untranslated(resting).is_empty(), "the resting line is translated: %s" % resting)
	var water: int = _state.recovery.water
	_state.recovery.water = 0 # TEST-ONLY: the rest ends (thirsty), and no other begins
	_session._process(FRAME)
	await tree.process_frame
	_state.recovery.water = water
	var untranslated: Array[String] = []
	for line: String in ColoredLine.texts(_school.last_colored):
		if not PseudoLocale.untranslated(line).is_empty():
			untranslated.append(line)
	_check(_school.last_colored.size() == 2 and untranslated.is_empty(), "the run's lines are translated: %s" % [untranslated if not untranslated.is_empty() else ColoredLine.texts(_school.last_colored)])
	var run := TrainingRun.new(TrainingRun.Kind.LEARN, &"sword", _state)
	run.auto_rest = true
	run.cost = 30
	run.have = 13
	run.took_step(_state)
	run.rested(240.0, 240)
	run.end(TrainingRun.Stop.WASTE_ESSENCE)
	run.rest_line = RestLines.refusal(RestRules.Outcome.THIRSTY)
	untranslated.clear()
	var lines: Array[String] = ColoredLine.texts(TrainingLines.run(run, GameContent.catalog().skill(&"sword"), _school.display_name()))
	_check(lines.size() == 3, "a summary with its rests, the stop, why no rest: %s" % [lines])
	for line: String in lines:
		if not PseudoLocale.untranslated(line).is_empty():
			untranslated.append(line)
	_check(untranslated.is_empty(), "the stop without the hint and why no rest: %s" % [untranslated])
	panel.close_panel()
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(translation)
	await tree.process_frame


## The 请教 page as the player opens it: the popup on 柳淳风 (E), then its 请教 row; the popup
## holds world time while it shows, its pages too.
func _open_teacher_page(tree: SceneTree) -> bool:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_hud.nearby.refresh()
	for thing: WorldNearbyThing in map.selection.nearby():
		if not thing.services.has(_school):
			continue
		_hud.open_interaction(thing)
		for option: InteractionOption in _hud.nearby.options_for(map, thing):
			if option.label == _school.verb():
				option.action.call()
		break
	await tree.process_frame
	await tree.process_frame
	return _school.ui.panel.visible and _hud.interaction_open() and _session.world_time_held()


func _close_teacher_page(tree: SceneTree) -> void:
	_school.ui.close_panel()
	await tree.process_frame
	_hud.dismiss_current_panel()
	await tree.process_frame
	await tree.process_frame
	_check(not _hud.interaction_open() and not _session.world_time_held(), "the popup closed")


## Runs `progress` to its end: the world by hand while its run rests, frames otherwise.
func _drive(tree: SceneTree, progress: TrainingProgress) -> void:
	var frames: int = 0
	while progress.running() and frames < 4000:
		frames += 1
		if _session.resting_for_training():
			_session._process(FRAME)
			if frames % 50 == 0:
				await tree.process_frame
		else:
			await tree.process_frame
	_check(not progress.running(), "the run came to its end")


func _lesson_ready(skill_id: StringName, level: int) -> void:
	_state.skills.set_raw_level(skill_id, level)
	_state.skills.set_learned_progress(skill_id, 0)
	_heal()
	var teacher: CharacterState = _school.npc.character_state
	teacher.spirit.current = teacher.spirit.maximum
	_state.progression.potential = 1000
	_state.progression.potential_spent = 0
	_state.progression.combat_experience = 2000
	_state.recovery.water = maxi(_state.recovery.water, 200) # TEST-ONLY: rests drink
	_state.recovery.food = maxi(_state.recovery.food, 200)


func _cost() -> int:
	return LearnService.base_essence_cost(_school.npc.character_state.attributes.intelligence, _state.attributes.intelligence)


## TEST-ONLY: gin, kee and sen full.
func _heal() -> void:
	for resource: CharacterResourceState in [_state.essence, _state.vitality, _state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


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
		_failures.append("training auto rest: " + label)
	return ok
