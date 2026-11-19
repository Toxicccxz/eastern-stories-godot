extends RefCounted

## 练功演出 (DECISIONS「练功演出」): a continuous 练习 / 打坐 is seen on the map — its window stands
## aside once a step is taken, the player's own figure strikes or sits, a band carries the count,
## and the window is back when it is over — and a gain is marked for a moment (GrowthWatch reads
## it off the player's state, GrowthMoments shows it). growth.json names only what the game can
## draw; with the feel off nothing of it happens; nothing of it changes a step, a cost or the
## state.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_data()
	_check_forms()
	await _check_person(tree)
	await _check_in_a_session(tree)
	return {"assertions": assertions, "failures": failures}


## growth.json names only what the game can draw and play.
func _check_data() -> void:
	var training: Dictionary = GrowthFx.training()
	var moments: Dictionary = GrowthFx.moments()
	check(not training.is_empty() and not moments.is_empty(), "growth.json has its two parts")
	check(float(training.get("zoom", 0.0)) > 0.0 and float(training.get("zoom", 0.0)) <= 1.0 and float(training.get("round", 0.0)) >= 0.5 and float(training.get("min_seconds", 0.0)) > 0.0, "training: a push-in, a round a stroke fits in, a least time")
	var forms: Dictionary = training.get("forms", {})
	var forms_fine: int = 0
	for use: String in forms:
		var form: Dictionary = forms[use]
		var fine: bool = TrainingShow.FORMS.has(String(form.get("form", "")))
		if form.get("form", "") == TrainingShow.FORM_REACT:
			fine = fine and Person.REACTIONS.has(String(form.get("react", "")))
		if form.has("colour"):
			fine = fine and Color.html_is_valid(String(form["colour"]))
		forms_fine += 1 if fine else 0
	check(forms.has("default") and forms_fine == forms.size(), "every form is one the show plays (%d of %d)" % [forms_fine, forms.size()])
	var cultivation: Dictionary = training.get("cultivation", {})
	check(cultivation.has("exercise") and cultivation.has("meditate") and cultivation.has("respirate"), "打坐, 冥思 and 修行 each have their colour")
	check(BattleArts.KINDS.has(String(training.get("sit", {}).get("art", ""))), "the art about one seated is one the library draws")
	var kinds: Dictionary = moments.get("kinds", {})
	var tiers: Dictionary = moments.get("tiers", {})
	for kind: StringName in GrowthWatch.KINDS:
		var look: Dictionary = kinds.get(String(kind), {})
		var tier: Dictionary = tiers.get(String(look.get("tier", "")), {})
		var pose: String = String(look.get("pose", ""))
		check(
			not look.is_empty() and float(tier.get("seconds", 0.0)) > 0.0 and (tier.get("size", []) as Array).size() == 2 and int(tier.get("font", 0)) >= 20
			and BattleArts.KINDS.has(String(look.get("art", ""))) and Color.html_is_valid(String(look.get("stroke", ""))) and Color.html_is_valid(String(look.get("ink", ""))) and Color.html_is_valid(String(look.get("colour", "")))
			and BattleSounds.FILES.has(StringName(String(look.get("sound", "")))) and (pose.is_empty() or Person.REACTIONS.has(pose)),
			"moment %s: a tier, an art, colours, a sound the fight has, a pose the figure has" % kind,
		)
	check(kinds.size() == GrowthWatch.KINDS.size(), "no moment the watch never tells")
	var feel: FeelDefinition = TestFeel.production
	check(feel.training_stage_seconds > 0.0 and feel.growth_moment_seconds > 0.0, "pacing.json turns both on")
	check(is_zero_approx(FeelDefinition.new().training_stage_seconds) and is_zero_approx(FeelDefinition.new().growth_moment_seconds), "and both are off where the feel is (the suites)")


## How each run is shown.
func _check_forms() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var sit: Dictionary = TrainingShow.form_for(TrainingRun.Kind.EXERCISE, null, &"")
	check(sit.get("form") == TrainingShow.FORM_SIT and sit.get("colour") != TrainingShow.form_for(TrainingRun.Kind.MEDITATE, null, &"").get("colour"), "打坐 sits; 冥思 in another colour")
	var sword: Dictionary = TrainingShow.form_for(TrainingRun.Kind.PRACTICE, catalog.skill(&"fonxansword"), &"sword", &"sword")
	check(sword.get("form") == TrainingShow.FORM_STRIKE and sword.get("weapon") == "sword" and Color(String(sword.get("colour", "000000"))).is_equal_approx(Color(BattleSceneShow.school_colour(&"fonxansword").to_html(false))), "练习剑法: strokes with a sword in the school's colour (%s)" % [sword])
	var fist: Dictionary = TrainingShow.form_for(TrainingRun.Kind.PRACTICE, catalog.skill(&"liuh-ken"), &"unarmed")
	check(fist.get("form") == TrainingShow.FORM_STRIKE and fist.get("weapon") == "", "练习拳脚: bare hands")
	var parry: Dictionary = TrainingShow.form_for(TrainingRun.Kind.PRACTICE, catalog.skill(&"fonxansword"), &"parry", &"sword")
	check(parry.get("form") == TrainingShow.FORM_REACT and parry.get("react") == "parry" and parry.get("weapon") == "sword", "练习招架: parries with what is in the hand")
	var dodge: Dictionary = TrainingShow.form_for(TrainingRun.Kind.PRACTICE, catalog.skill(&"chaos-steps"), &"dodge", &"sword")
	check(dodge.get("form") == TrainingShow.FORM_REACT and dodge.get("react") == "dodge" and dodge.get("weapon") == "", "练习轻功: dodges, nothing in the hand")
	# 请教: a basic skill is its own use, a school's skill the first use it serves.
	check(TrainingShow.form_for(TrainingRun.Kind.LEARN, catalog.skill(&"sword"), &"").get("weapon") == "sword", "请教基本剑法: strokes with a sword")
	check(TrainingShow.form_for(TrainingRun.Kind.LEARN, catalog.skill(&"fonxansword"), &"").get("form") == TrainingShow.FORM_STRIKE, "请教封山剑法: strokes")
	check(TrainingShow.form_for(TrainingRun.Kind.LEARN, catalog.skill(&"fonxanforce"), &"").get("form") == TrainingShow.FORM_SIT, "请教内功: seated")
	check(TrainingShow.form_for(TrainingRun.Kind.LEARN, catalog.skill(&"literate"), &"").get("form") == TrainingShow.FORM_STUDY, "请教读书识字: the master talks")


## The figure sits down and gets up, shows a gesture whatever its work, and bows.
func _check_person(tree: SceneTree) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var person := Person.new()
	person.configure({"coat": "397c87"})
	root.add_child(person)
	for step: int in 5:
		await tree.process_frame
	var standing: float = person.torso.position.y
	person.sitting = true
	for step: int in 60:
		await tree.process_frame
	check(person.torso.position.y < standing - 0.3 and is_equal_approx(person.legs[0].rotation.x, Person.POSE_LEGS["sit_ground"]) and person.arms[0].rotation.x < -0.5, "seated: the hips on the ground, the legs out, the hands in the lap (%.2f)" % person.torso.position.y)
	person.sitting = false
	for step: int in 60:
		await tree.process_frame
	check(absf(person.torso.position.y - standing) < 0.03 and absf(person.legs[0].rotation.x) < 0.01, "up again as it stood (%.2f)" % person.torso.position.y)
	# One attending to the player does not work; it still shows what it is asked to.
	person.working = false
	person.showing = "teach"
	var raised: float = 0.0
	for step: int in 30:
		await tree.process_frame
		raised = minf(raised, person.arms[1].rotation.x)
	check(raised < -0.9, "a master not at work still shows (%.2f)" % raised)
	person.showing = ""
	for step: int in 5:
		await tree.process_frame
	check(person.arms[1].rotation.x > -0.9, "and stops when it is over")
	person.take_guard("")
	person.react = "bow"
	person.react_amount = 1.0
	for step: int in 5:
		await tree.process_frame
	check(person.torso.rotation.x > 0.6 and person.arms[0].rotation.x < -0.9, "the bow: bent low, the hands before the breast (%.2f)" % person.torso.rotation.x)
	root.free()
	await tree.process_frame


## A real session: the watch on the player's own state, then the runs and the moments shown.
func _check_in_a_session(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	var map := session.active_map() as WorldMapController
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	if not check(view != null, "the session's map has its voxel view"):
		session.free()
		return
	var me: StringName = session.player_runtime().character_id
	for step: int in 400:
		await tree.process_frame
		if view.actors.has(me):
			break
	var state: CharacterState = session.player_runtime().state
	var hud: SharedGameplayUI = session.shared_ui()
	if not check(view.actors.has(me) and is_instance_valid(hud.growth_moments), "the player's figure stands, the HUD has its moments"):
		session.free()
		return
	var model: Person = view.actors[me].get_child(0) as Person
	_check_watch(state)
	# TEST-ONLY: a school's fist to practise, 气 for three practices of 30.
	state.skills.set_raw_level(&"unarmed", 20)
	state.skills.set_raw_level(&"liuh-ken", 10)
	state.skills.set_learned_progress(&"liuh-ken", 0)
	state.skills.map_skill(&"unarmed", &"liuh-ken")
	_heal(state)
	state.vitality.current = 100
	hud.open_martial_arts()
	var page: MartialArtsPage = hud.martial_arts_page()
	var progress: TrainingProgress = page.progress
	var window: Control = hud.menu.root
	# The feel off (the suites): all at once in the page, nothing shown.
	page.buttons["practice_run:unarmed"].pressed.emit()
	check(not progress.running() and not progress.staged() and progress.show_stage == null and is_equal_approx(window.modulate.a, 1.0) and hud.growth_moments.shown.is_empty(), "feel off: the run is over in the page, no stage, no moment")
	check(state.vitality.current == 10, "TEST-ONLY: three practices were paid for (%d)" % state.vitality.current)

	TestFeel.use()
	var zoom_before: float = view.zoom()
	# A run refused at its first step shows nothing.
	page.buttons["practice_run:unarmed"].pressed.emit()
	var staged_ever: bool = false
	for step: int in 40:
		await tree.process_frame
		staged_ever = staged_ever or progress.staged()
	check(not progress.running() and not staged_ever and is_equal_approx(window.modulate.a, 1.0) and not model.fighting, "refused at once (气 short): the window stays, the figure does nothing")
	# A run of three steps: the window aside once the first is taken, the figure at it.
	_heal(state)
	state.vitality.current = 100
	page.buttons["practice_run:unarmed"].pressed.emit()
	check(progress.running() and not progress.staged(), "begun: not aside before a step is taken")
	for step: int in 60:
		await tree.process_frame
		if progress.staged():
			break
	check(progress.staged() and progress.band.visible and progress.band_status.text.begins_with("连续练习柳家拳：已做 ") and progress.show_stage.showing(), "a step taken: the band with the count, the show on (%s)" % progress.band_status.text)
	check(progress.show_stage.form.get("form") == TrainingShow.FORM_STRIKE and model.fighting and model.armed.is_empty(), "the player's figure on guard, bare-handed")
	check(tree.root.gui_get_focus_owner() == progress.band_stop, "停止 on the band has the keys")
	var swung: float = 0.0
	var faded: float = 1.0
	var nearest: float = 1.0
	for step: int in 400:
		await tree.process_frame
		swung = maxf(swung, absf(model.swing))
		faded = minf(faded, window.modulate.a)
		nearest = minf(nearest, view.zoom())
		if not progress.running():
			break
	check(swung > 0.9 and progress.show_stage.rounds >= 1, "it strikes (swing %.2f, %d rounds)" % [swung, progress.show_stage.rounds])
	check(faded < 0.05, "the window faded out meanwhile (%.2f)" % faded)
	check(nearest < zoom_before - 0.1, "the camera nearer (%.2f from %.2f)" % [nearest, zoom_before])
	check(not progress.running() and not progress.staged() and not progress.band.visible and state.vitality.current == 10, "over: the band gone, the same three practices paid for (%d)" % state.vitality.current)
	check(progress.status.text.begins_with("你练习柳家拳 3 次") and progress.is_visible_in_tree(), "the run's lines in the page as ever: %s" % progress.status.text.get_slice("\n", 0))
	await tree.create_timer(0.6).timeout
	check(is_equal_approx(window.modulate.a, 1.0) and not model.fighting and is_equal_approx(view.zoom(), zoom_before) and absf(model.swing) < 0.01, "the window back, the figure at ease, the camera where it was")
	var stage_time: float = float(GrowthFx.training().get("min_seconds", 0.0))
	check(stage_time >= float(GrowthFx.training().get("round", 0.0)) + TrainingShow.SETTLE, "the least time fits a whole stroke")

	# A run that ends on a level: its moment over the stage, the art on the figure.
	_heal(state)
	state.skills.set_learned_progress(&"liuh-ken", 11 * 11 - 4)
	hud.growth_moments.look_now()
	var told_before: int = hud.growth_moments.shown.size()
	page.buttons["practice_run:unarmed"].pressed.emit()
	var art_seen: bool = false
	var banner_seen: String = ""
	var aside_with_banner: bool = false
	for step: int in 400:
		await tree.process_frame
		for child: Node in view.actors[me].get_children():
			art_seen = art_seen or child.has_meta(&"growth")
		if hud.growth_moments.banner.showing():
			banner_seen = hud.growth_moments.banner.shown_text()
			aside_with_banner = aside_with_banner or progress.staged()
		if not progress.running():
			break
	check(state.skills.raw_level(&"liuh-ken") == 11 and progress.last_stop == TrainingRun.Stop.LEVEL_UP, "TEST-ONLY: the run ended on the level")
	check(hud.growth_moments.shown.size() == told_before + 1 and hud.growth_moments.shown[-1] == [GrowthWatch.SKILL_LEVEL, "柳家拳　11 级"], "the level is told once: %s" % [hud.growth_moments.shown.slice(told_before)])
	check(banner_seen == "柳家拳　11 级" and aside_with_banner and art_seen, "its words over the stage while the window is aside, its art on the figure (%s)" % banner_seen)
	await tree.create_timer(1.5).timeout
	var left: int = 0
	for child: Node in view.actors[me].get_children():
		left += 1 if child.has_meta(&"growth") else 0
	check(left == 0 and not hud.growth_moments.banner.showing(), "and gone when over")

	# 连续打坐: seated while it runs; the player's own stop brings the window back at once.
	state.skills.set_raw_level(&"force", 5)
	state.skills.set_raw_level(&"fonxanforce", 1)
	state.skills.map_skill(&"force", &"fonxanforce")
	state.recovery.inner_force.maximum = 1000
	state.recovery.inner_force.current = 0
	_heal(state)
	# TEST-ONLY: the set-up is taken in by the watch itself, so none of it is told as a gain.
	hud.growth_moments.watch.look(state)
	page.refresh()
	page.exercise_amount.value = 10
	page.exercise_run_button.pressed.emit()
	for step: int in 60:
		await tree.process_frame
		if progress.staged():
			break
	check(progress.staged() and progress.show_stage.form.get("form") == TrainingShow.FORM_SIT and model.sitting, "打坐: seated")
	var risings: int = 0
	for step: int in 120:
		await tree.process_frame
		for child: Node in view.actors[me].get_children():
			risings += 1 if child.has_meta(&"growth") else 0
		if not progress.running():
			break
	check(risings > 0, "the 气 rises about it")
	if progress.running():
		progress.stop()
	check(not progress.running() and not progress.staged() and not model.sitting, "stopped (or spent): back at once, no longer seated")
	hud.dismiss_current_panel()
	await tree.create_timer(0.5).timeout

	# Gains that no run made: read off the state, told one at a time.
	hud.growth_moments.watch.look(state)
	told_before = hud.growth_moments.shown.size()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quests()[0]
	state.quests[StoryQuestLog.key_done(quest)] = 1 # TEST-ONLY
	state.skills.set_raw_level(&"literate", 1) # TEST-ONLY
	hud.growth_moments.look_now()
	check(hud.growth_moments.waiting() == 2 or (hud.growth_moments.waiting() == 1 and hud.growth_moments.shown.size() == told_before + 1), "two gains wait their turn (%d waiting)" % hud.growth_moments.waiting())
	await tree.create_timer(GameContent.catalog().pacing().feel.growth_moment_seconds * 4.5).timeout
	var told: Array = hud.growth_moments.shown.slice(told_before)
	check(told == [[GrowthWatch.SKILL_LEARNED, "习得　读书识字"], [GrowthWatch.QUEST_DONE, "任务完成　%s" % quest.title]], "a skill learned, then a quest ended: %s" % [told])
	# A master taken: the words, and the figure bows.
	told_before = hud.growth_moments.shown.size()
	state.apprenticeship.master_teacher_id = &"test.master" # TEST-ONLY
	state.apprenticeship.legacy_master_name = "柳淳风"
	var bowed: float = 0.0
	for step: int in 200:
		await tree.process_frame
		if model.react == "bow":
			bowed = maxf(bowed, model.react_amount)
	check(hud.growth_moments.shown.size() == told_before + 1 and hud.growth_moments.shown[-1][0] == GrowthWatch.APPRENTICED and bowed > 0.9, "a master taken: %s, the figure bows (%.2f)" % [hud.growth_moments.shown[-1], bowed])
	await tree.create_timer(1.5).timeout
	check(not model.fighting and is_zero_approx(model.react_amount), "and stands at ease after")
	state.apprenticeship.master_teacher_id = &""
	state.apprenticeship.legacy_master_name = ""
	# During a fight a gain waits for its end (the fight's own show has the screen).
	told_before = hud.growth_moments.shown.size()
	session.player_runtime().relationship.add_opponent(&"test.foe") # TEST-ONLY
	state.skills.set_raw_level(&"literate", 2) # TEST-ONLY
	await tree.create_timer(1.0).timeout
	check(hud.growth_moments.shown.size() == told_before and hud.growth_moments.waiting() == 1, "fighting: the gain waits (%d waiting)" % hud.growth_moments.waiting())
	session.player_runtime().relationship.remove_opponent(&"test.foe")
	await tree.create_timer(0.5).timeout
	check(hud.growth_moments.shown.size() == told_before + 1 and hud.growth_moments.shown[-1] == [GrowthWatch.SKILL_LEVEL, "读书识字　2 级"], "the fight over: it is told (%s)" % [hud.growth_moments.shown[-1]])
	await tree.create_timer(1.5).timeout
	TestFeel.restore()
	# The feel off again: nothing more is looked at.
	told_before = hud.growth_moments.shown.size()
	state.skills.set_raw_level(&"literate", 3) # TEST-ONLY
	await tree.create_timer(0.6).timeout
	check(hud.growth_moments.shown.size() == told_before and hud.growth_moments.waiting() == 0, "feel off: nothing told")
	session.free()
	await tree.process_frame


## GrowthWatch on the player's own state (a watch of its own; nothing is shown).
func _check_watch(state: CharacterState) -> void:
	var watch := GrowthWatch.new()
	check(watch.look(state, [&"some.thing"]).is_empty(), "the first look only takes the state in")
	check(watch.look(state, [&"some.thing"]).is_empty(), "nothing changed: nothing told")
	var skill: StringName = &"dodge"
	var had: bool = state.skills.has_raw_level(skill)
	var level: int = state.skills.raw_level(skill)
	state.skills.set_raw_level(skill, level + 1) # TEST-ONLY
	var found: Array[GrowthWatch.Moment] = watch.look(state, [&"some.thing"])
	check(found.size() == 1 and found[0].kind == (GrowthWatch.SKILL_LEVEL if had else GrowthWatch.SKILL_LEARNED) and found[0].subject == skill and found[0].value == level + 1, "a level gained (or the skill learned) is told with its level")
	state.skills.set_raw_level(skill, level + 2) # TEST-ONLY
	found = watch.look(state, [&"some.thing"])
	check(found.size() == 1 and found[0].kind == GrowthWatch.SKILL_LEVEL and found[0].value == level + 2, "the next level: a level")
	state.skills.set_raw_level(skill, level) # TEST-ONLY: a loss (a death's penalty)
	check(watch.look(state, [&"some.thing"]).is_empty(), "a loss is taken in without a word")
	state.skills.set_raw_level(skill, level + 1) # TEST-ONLY
	found = watch.look(state, [&"some.thing"])
	check(found.size() == 1 and found[0].kind == GrowthWatch.SKILL_LEVEL, "and the level won back is a gain again")
	if had:
		state.skills.set_raw_level(skill, level)
	else:
		state.skills.remove_skill(skill)
	watch.look(state, [&"some.thing"])
	# A maximum.
	var force: int = state.recovery.inner_force.maximum
	state.recovery.inner_force.maximum = force + 10 # TEST-ONLY
	found = watch.look(state, [&"some.thing"])
	check(found.size() == 1 and found[0].kind == GrowthWatch.MAXIMUM_UP and found[0].subject == GrowthWatch.INNER_FORCE and found[0].value == force + 10, "内力's maximum raised")
	state.recovery.inner_force.maximum = force
	check(watch.look(state, [&"some.thing"]).is_empty(), "lowered: nothing")
	# A story's thing: told the first time it is held, not when it is picked up again.
	found = watch.look(state, [&"some.thing", &"another.thing"])
	check(found.size() == 1 and found[0].kind == GrowthWatch.KEY_ITEM and found[0].subject == &"another.thing", "a story's thing first held")
	check(watch.look(state, [&"some.thing"]).is_empty() and watch.look(state, [&"some.thing", &"another.thing"]).is_empty(), "put down and picked up: no gain")
	# A quest ended.
	state.quests["test.quest#done"] = 1 # TEST-ONLY
	state.quests["test.quest/step"] = 1
	found = watch.look(state, [&"some.thing"])
	check(found.size() == 1 and found[0].kind == GrowthWatch.QUEST_DONE and found[0].subject == &"test.quest", "a quest ended (its steps are no gain)")
	state.quests.erase("test.quest#done")
	state.quests.erase("test.quest/step")
	# Many of a kind at once: a set-up, none told; the others still are.
	var many: Array[StringName] = [&"test.a", &"test.b", &"test.c", &"test.d"]
	for id: StringName in many:
		state.skills.set_raw_level(id, 1) # TEST-ONLY
	state.recovery.inner_force.maximum = force + 5 # TEST-ONLY
	found = watch.look(state, [&"some.thing"], 3)
	check(found.size() == 1 and found[0].kind == GrowthWatch.MAXIMUM_UP, "four skills at once are a set-up: only the maximum is told (%d)" % found.size())
	for id: StringName in many:
		state.skills.remove_skill(id)
	state.recovery.inner_force.maximum = force
	# reset(): the next look takes the state in afresh.
	watch.reset()
	state.recovery.inner_force.maximum = force + 1 # TEST-ONLY
	check(watch.look(state, []).is_empty(), "after reset() the first look tells nothing")
	state.recovery.inner_force.maximum = force
	check(GrowthMoments.text_of(GrowthWatch.Moment.new(GrowthWatch.MAXIMUM_UP, GrowthWatch.MANA, 40)) == "法力上限　40", "the words of a moment: " + GrowthMoments.text_of(GrowthWatch.Moment.new(GrowthWatch.MAXIMUM_UP, GrowthWatch.MANA, 40)))
	var taken := GrowthWatch.Moment.new(GrowthWatch.APPRENTICED, &"test.master")
	taken.family_id = &"family.fonxan"
	check(GrowthMoments.text_of(taken) == "拜入　" + GameContent.catalog().family(&"family.fonxan").display_name, "拜入 with the family's name: " + GrowthMoments.text_of(taken))


## TEST-ONLY: 精, 气 and 神 full.
static func _heal(state: CharacterState) -> void:
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(message)
	return condition
