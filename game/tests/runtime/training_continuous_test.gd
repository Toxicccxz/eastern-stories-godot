extends RefCounted

## Continuous 请教, 练习 and 打坐 in a running Snow session (DECISIONS「连续修炼」): a run
## is the same commands one by one (the whole save, RNG included, equals the single
## buttons pressed as often), told in a summary instead of each step's lines; it stops
## on gin about to be spent for nothing, too little combat_exp, potential spent, a level,
## kee short, practice progress full, no gain, the bottleneck, a maximum up, a fall,
## a fight, 停止 / B and the page going away; the buttons grey and the focus stays on 停止
## while it runs; under the pseudo-locale every line and label is translated.
## TEST-ONLY fixtures, marked where used: gin/kee/sen, combat_exp, potential and skill
## levels set directly.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SCHOOL: StringName = &"snow.school_compound.schoolhall.master"

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _school: TeacherService


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_state = _player.state
	_hud = _session.shared_ui()
	var map: WorldMapController = MapPlaces.enter(_session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	_check(map != null and _beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	await tree.physics_frame
	# The HUD binds the hall's map on its next frame (it closes what is open on a new map).
	await tree.process_frame
	await tree.process_frame
	_school = map.service(SCHOOL) as TeacherService
	_school.request_apprentice()
	_check(_state.family.family_id == &"family.fonxan", "apprenticed to 柳淳风")
	# The 拜师 card over the world (前两小时 A) would hold world time and take the focus until 继续.
	_hud.life_overlay.go_on()
	_test_learn_until_gin_would_be_wasted()
	await _test_same_as_single_learns(tree)
	_test_learn_stops()
	_test_interrupted_and_cancelled()
	_test_practice()
	_test_cultivation()
	await _test_while_running(tree)
	_test_pseudo_locale()
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## 连续请教 on the panel: three lessons, then it stops before the fourth would take the
## gin left for nothing; one summary in the log.
func _test_learn_until_gin_would_be_wasted() -> void:
	_lesson_ready(&"sword", 10)
	var cost: int = _cost()
	_state.essence.current = cost * 3 + 5 # TEST-ONLY: three lessons and 5 over
	var spent: int = _state.progression.potential_spent
	var learned: int = _state.skills.learned_progress(&"sword")
	var logged: int = _hud.log_lines().size()
	_school.interact()
	_check(_school.ui.panel.visible and _school.ui.run_buttons.has(&"sword") and _school.ui.run_buttons[&"sword"].text == "连续请教", "连续请教 beside 请教基本剑法（一次）")
	_school.ui.run_buttons[&"sword"].pressed.emit()
	_check(_state.essence.current == 5 and _state.progression.potential_spent == spent + 3, "three lessons, the last 5 gin kept (learn.c would take them): gin %d" % _state.essence.current)
	var gain: int = _state.skills.learned_progress(&"sword") - learned
	var expected: Array[String] = [
		"你向柳淳风请教「基本剑法」3 次：基本剑法进度 +%d，精 -%d，潜能 -3。" % [gain, cost * 3],
		"停下：精不够了。请教一次耗精 %d，精须多于此数（你还有 5）；再请教只会白白累垮，先休息吧。" % cost,
	]
	_check(_hud.log_lines().slice(logged) == expected, "the log has the summary and why it stopped, no lesson's lines: %s" % [_hud.log_lines().slice(logged)])
	_check(_school.ui.feedback.text == "\n".join(expected), "the panel repeats them")
	_check(not _school.ui.progress.running() and _school.ui.progress.status.text == "\n".join(expected) and not _school.ui.progress.bar.visible, "the run is over, its lines under the row")
	_check(not _school.ui.run_buttons[&"sword"].disabled, "the buttons back")
	_school.ui.close_panel()


## A run changes the world exactly as the single 请教 pressed as many times: the whole
## save (skills, gin, potential, the teacher's sen, the RNG) is the same.
func _test_same_as_single_learns(tree: SceneTree) -> void:
	_lesson_ready(&"sword", 15)
	_state.essence.current = _cost() * 6 + 1 # TEST-ONLY
	# Continue is ES2's login and recomputes the maxima (race/human.c): applied first.
	CharacterDerivedValues.refresh_human_player_maxima(_state, _player.facts.age)
	var before: GameSaveSnapshot = Work.capture(_session)
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	run.run_to_end()
	var taken: int = run.training.steps + (1 if run.training.stop == TrainingRun.Stop.REFUSED else 0)
	_check(taken == 6 and run.training.stop == TrainingRun.Stop.WASTE_ESSENCE, "six lessons: %d, stop %d" % [taken, run.training.stop])
	var after: GameSaveSnapshot = Work.capture(_session)
	var fresh: WorldSessionController = _restored(tree, before)
	_check(fresh != null, "the save before the run restores")
	if fresh == null:
		return
	var teacher := (fresh.active_map() as WorldMapController).service(SCHOOL) as TeacherService
	for lesson: int in taken:
		teacher.request_learn(&"sword")
	var singles: GameSaveSnapshot = Work.capture(fresh)
	_check(GameSaveJsonCodec.encode(singles).text == GameSaveJsonCodec.encode(after).text, "the run's save is the single lessons' save")
	_check(Work.rng_state(fresh) == Work.rng_state(_session), "the same draws")
	fresh.free()
	# This session's HUD binds its map again.
	await tree.process_frame
	await tree.process_frame


func _test_learn_stops() -> void:
	# A level: the next lesson's gain passes (10 + 1)^2.
	_lesson_ready(&"sword", 10)
	_state.skills.set_learned_progress(&"sword", 121) # TEST-ONLY
	var lines: Array[String] = _learn_run(&"sword")
	_check(_state.skills.raw_level(&"sword") == 11 and lines.size() == 2 and lines[0].begins_with("你向柳淳风请教「基本剑法」1 次：基本剑法 10→11 级，精 -") and lines[1] == "你的「基本剑法」进步了！", "a level stops the run: %s" % [lines])
	# Potential: two lessons, then learn.c's own line.
	_lesson_ready(&"sword", 11)
	_state.progression.potential_spent = _state.progression.potential - 2 # TEST-ONLY
	lines = _learn_run(&"sword")
	_check(lines.size() == 2 and lines[0].begins_with("你向柳淳风请教「基本剑法」2 次：") and lines[1] == "你的潜能已经发挥到极限了，没有办法再成长了。", "potential spent: %s" % [lines])
	# combat_exp below 11^3/10 = 133: no lesson, no gin.
	_lesson_ready(&"sword", 11)
	_state.progression.combat_experience = 132 # TEST-ONLY
	var gin: int = _state.essence.current
	lines = _learn_run(&"sword")
	_check(lines == ["停下：实战经验不足。「基本剑法」11 级要再学，须实战经验 ≥ 133（你 132）。"] and _state.essence.current == gin, "too little combat_exp, gin kept: %s" % [lines])
	_state.progression.combat_experience = 2000 # TEST-ONLY


func _test_interrupted_and_cancelled() -> void:
	_lesson_ready(&"sword", 11)
	var run := PlayerTrainingRun.learn(_session, _school, &"sword")
	_check(run.step(), "a lesson")
	_check(_player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS), "the player falls")
	_check(not run.step() and run.training.stop == TrainingRun.Stop.INTERRUPTED and run.training.steps == 1, "a fall stops the run")
	_player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_check(ColoredLine.texts(run.finish()).back() == "停下：你被打断了。", "and says so")
	run = PlayerTrainingRun.learn(_session, _school, &"sword")
	_player.relationship.add_opponent(&"opponent")
	_check(not run.step() and run.training.stop == TrainingRun.Stop.INTERRUPTED and run.training.steps == 0, "a fight: no lesson")
	_player.relationship.remove_opponent(&"opponent")
	run = PlayerTrainingRun.learn(_session, _school, &"sword")
	run.step()
	run.cancel()
	_check(not run.step() and run.training.steps == 1 and ColoredLine.texts(run.finish()).back() == "你停了下来。", "停止 after a lesson")


## 连续练习 on the 武学 page: 柳家拳 until kee is short (its own line); in weak mode with this
## level's progress full, nothing (kee kept).
func _test_practice() -> void:
	_state.skills.set_raw_level(&"unarmed", 20) # TEST-ONLY
	_state.skills.set_raw_level(&"liuh-ken", 10) # TEST-ONLY
	_state.skills.set_learned_progress(&"liuh-ken", 0)
	_state.skills.map_skill(&"unarmed", &"liuh-ken")
	_heal()
	_state.vitality.current = 100 # TEST-ONLY: three practices of 30
	_hud.open_martial_arts()
	var page: MartialArtsPage = _hud.martial_arts_page()
	_check(page.buttons.has("practice_run:unarmed") and page.buttons["practice_run:unarmed"].text == "连续练习", "连续练习 beside 练习")
	page.buttons["practice_run:unarmed"].pressed.emit()
	var lines: Array[String] = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines.size() == 2 and lines[0] == "你练习柳家拳 3 次：柳家拳进度 +15，气 -90。" and lines[1] == "你的体力不够了，休息一下再练吧。", "three practices of 20/5 + 1, then liuh-ken's line: %s" % [lines])
	_check(page.feedback.text == "\n".join(lines), "the page repeats them")
	_state.skills.set_raw_level(&"unarmed", 10) # TEST-ONLY: weak mode
	_state.skills.set_learned_progress(&"liuh-ken", 122)
	_heal()
	var kee: int = _state.vitality.current
	page.buttons["practice_run:unarmed"].pressed.emit()
	lines = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines == ["停下：「柳家拳」这一级的进度已经攒满。先把基本拳脚提高到 11 级，再练才有长进。"] and _state.vitality.current == kee, "weak mode, progress full: %s" % [lines])
	# Too little kee as well: the single practice's own refusal comes first.
	_state.vitality.current = 10 # TEST-ONLY
	page.buttons["practice_run:unarmed"].pressed.emit()
	lines = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines == ["你的体力不够了，休息一下再练吧。"], "kee short before progress full: %s" % [lines])
	_hud.dismiss_current_panel()


## 连续打坐: the kee runs short; a maximum up; no gain; the bottleneck.
func _test_cultivation() -> void:
	_state.skills.set_raw_level(&"force", 5) # TEST-ONLY
	_state.skills.set_raw_level(&"fonxanforce", 1)
	_state.skills.map_skill(&"force", &"fonxanforce")
	_state.attributes.constitution = 25 # TEST-ONLY: 30 kee gains 30 * 30 / 300 = 3
	_state.recovery.inner_force.maximum = 1000
	_state.recovery.inner_force.current = 0
	_heal()
	_state.vitality.current = 95 # TEST-ONLY
	_hud.open_martial_arts()
	var page: MartialArtsPage = _hud.martial_arts_page()
	page.exercise_amount.value = 30
	page.exercise_run_button.pressed.emit()
	var lines: Array[String] = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines == ["你打坐 3 次：气 -90，内力 +54。", "你现在的气太少了，无法产生内息运行全身经脉。"], "three sittings then exercise.c's line: %s" % [lines])
	_heal()
	_state.recovery.inner_force.maximum = 49 # TEST-ONLY: below the cap of (5 + 3 / 5) * 10 = 50
	_state.recovery.inner_force.current = 98
	page.exercise_run_button.pressed.emit()
	lines = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines == ["你打坐 1 次：气 -30，内力 -48。", "你的内力增强了！"] and _state.recovery.inner_force.maximum == 50, "a maximum up stops the run: %s" % [lines])
	_heal()
	_state.recovery.inner_force.current = 100 # TEST-ONLY: twice the maximum, at the cap
	var force: int = _state.recovery.inner_force.current
	page.exercise_run_button.pressed.emit()
	lines = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines == ["停下：内力的修为已到瓶颈（上限 50），再打坐，内力只会回落到 50。先提高基本内功吧。"] and _state.recovery.inner_force.current == force, "the bottleneck: %s" % [lines])
	_state.recovery.inner_force.current = 0
	var kee: int = _state.vitality.current
	page.exercise_amount.value = 10
	_state.attributes.constitution = 10 # TEST-ONLY: 10 * 15 / 300 = 0
	page.exercise_run_button.pressed.emit()
	lines = ColoredLine.texts(_session.martial_arts().last_lines)
	_check(lines == ["停下：每次只花 10 点气，打坐不会有任何长进；多花一些再试。"] and _state.vitality.current == kee, "no gain: %s" % [lines])
	page.exercise_amount.value = 30
	_hud.dismiss_current_panel()


## With the feel on: steps come apart, the buttons grey, 停止 holds the focus, B stops the
## run; leaving the 武学 tab stops 连续打坐.
func _test_while_running(tree: SceneTree) -> void:
	TestFeel.use()
	_lesson_ready(&"sword", 11)
	_school.interact()
	var panel: TeacherPanel = _school.ui
	panel.run_buttons[&"sword"].grab_focus()
	panel.run_buttons[&"sword"].pressed.emit()
	_check(panel.progress.running() and panel.progress.visible, "the run goes on")
	_check(panel.get_viewport().gui_get_focus_owner() == panel.progress.stop_button, "停止 has the focus")
	_check(panel.learn_buttons[&"sword"].disabled and panel.run_buttons[&"sword"].disabled and panel.apprentice_button.disabled, "the other buttons are grey")
	_check(panel.progress.get_index() == panel.learn_buttons[&"sword"].get_parent().get_index() + 1, "the progress shows under the skill's row")
	for frame: int in 30:
		await tree.process_frame
	_check(panel.progress.status.text.begins_with("连续请教「基本剑法」：已做 "), "it counts: " + panel.progress.status.text)
	_check(panel.get_viewport().gui_get_focus_owner() == panel.progress.stop_button, "停止 keeps the focus")
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	panel.progress._input(back)
	_check(not panel.progress.running() and panel.progress.status.text.ends_with("你停了下来。") and not panel.progress.stop_button.visible, "B stops it")
	_check(panel.feedback.text.ends_with("你停了下来。") and not panel.run_buttons[&"sword"].disabled, "stopped, the buttons back: " + panel.feedback.text)
	_check(panel.get_viewport().gui_get_focus_owner() == panel.run_buttons[&"sword"], "the focus back on 连续请教")
	# The pause: the panel closes (its NPC out of reach while the tree is paused, as
	# before), so the run stops there, after the steps it took; none is lost.
	panel.run_buttons[&"sword"].pressed.emit()
	tree.paused = true
	await tree.process_frame
	_check(not panel.progress.running() and panel.feedback.text.ends_with("你停了下来。"), "the pause closes the panel and stops the run")
	tree.paused = false
	await tree.process_frame
	panel.close_panel()
	_heal()
	_hud.open_martial_arts()
	var page: MartialArtsPage = _hud.martial_arts_page()
	_state.recovery.inner_force.maximum = 1000 # TEST-ONLY
	_state.recovery.inner_force.current = 0
	page.exercise_run_button.pressed.emit()
	_check(page.progress.running() and page.exercise_button.disabled and not page.exercise_amount.editable, "连续打坐 runs, 打坐 and its amount grey")
	_hud.menu.show_tab(GameMenu.Tab.CHARACTER)
	_check(not page.progress.running() and ColoredLine.texts(_session.martial_arts().last_lines).back() == "你停了下来。", "another tab stops it")
	# A run started further down shows under its own row (the bar sat above it).
	_hud.menu.show_tab(GameMenu.Tab.MARTIAL_ARTS)
	_heal()
	page.meditate_run_button.pressed.emit()
	_check(page.progress.running() and page.progress.get_index() == page.meditate_amount.get_parent().get_index() + 1, "连续冥思's bar under 冥思's row")
	page.progress.stop()
	_hud.dismiss_current_panel()
	TestFeel.restore()


## Under the pseudo-locale a run's lines and the panel's labels are all translated.
func _test_pseudo_locale() -> void:
	var translation: Translation = PseudoLocale.translation()
	var locale: String = TranslationServer.get_locale()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(PseudoLocale.CODE)
	_lesson_ready(&"sword", 11)
	_state.essence.current = _cost() * 2 + 1 # TEST-ONLY
	_school.interact()
	_school.ui.run_buttons[&"sword"].pressed.emit()
	var untranslated: Array[String] = []
	for line: String in _school.last_lines:
		if not PseudoLocale.untranslated(line).is_empty():
			untranslated.append(line)
	_check(_school.last_lines.size() == 2 and untranslated.is_empty(), "the run's lines are translated: %s" % [untranslated if not untranslated.is_empty() else _school.last_lines])
	_check(VisibleTextScan.untranslated(_school.ui.panel).is_empty(), "the panel's labels: %s" % [VisibleTextScan.untranslated(_school.ui.panel)])
	_school.ui.close_panel()
	_hud.open_martial_arts()
	_check(VisibleTextScan.untranslated(_hud.martial_arts_page()).is_empty(), "the 武学 page: %s" % [VisibleTextScan.untranslated(_hud.martial_arts_page())])
	_hud.dismiss_current_panel()
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(translation)


## learn <skill> from 柳淳风 again and again; the lines.
func _learn_run(skill_id: StringName) -> Array[String]:
	return ColoredLine.texts(PlayerTrainingRun.learn(_session, _school, skill_id).run_to_end())


## TEST-ONLY: the skill at `level` with no progress, gin/kee/sen full, the teacher rested,
## potential and combat_exp to spare.
func _lesson_ready(skill_id: StringName, level: int) -> void:
	_state.skills.set_raw_level(skill_id, level)
	_state.skills.set_learned_progress(skill_id, 0)
	_heal()
	var teacher: CharacterState = _school.npc.character_state
	teacher.spirit.current = teacher.spirit.maximum
	_state.progression.potential = 1000
	_state.progression.potential_spent = 0
	# learn.c gains random(int + combat_exp / (1000 + combat_exp / 1000)): about int with 2000.
	_state.progression.combat_experience = 2000


## learn.c's gin cost for a skill already begun.
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


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("training continuous: " + label)
