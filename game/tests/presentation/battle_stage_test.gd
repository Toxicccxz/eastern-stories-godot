extends RefCounted

## 战斗演出 B (DECISIONS「战斗演出 B」): a fight's opening. The stepped base's plan (three steps,
## each a brick narrower all round, every brick on one below, a table's or a wall's cell left
## open, the edges hand-laid and the same each time at one place, a crowd too far apart centred
## on the player); which opening a fight gets (全程 first few of a run, then 简短; 简短 / 关 by the
## setting; 自动 short; a feel with no times is instant); the setting's round trip; and one real
## fight on a built map — the camera staged lower and nearer, the exit arrows and the quest
## marker away, the panel's lines waiting, the base laid in rows under the fighters, the player
## stepping up onto it, the panel back in place, a key putting the next opening in place at
## once, the base taken down and the camera given back at the end. Rules are untouched.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_plan()
	_kinds()
	_setting()
	_weapon_sounds()
	await _voices(tree)
	await _fight(tree)
	BattlePace.opening = BattlePace.Opening.OFF
	BattlePace.manual_turns = false
	BattleStageOpening.fights_opened = 0
	TestFeel.restore()
	return {"assertions": _count, "failures": _failures}


func _plan() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fighters: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 1)]
	var all_free := func(_cell: Vector2i) -> bool: return true
	var steps: Array[Dictionary] = BattleArena.plan(fighters, Vector2i(0, 0), all_free, 3, 2, Vector2i(28, 20), 0.18, rng)
	_check(steps.size() == 3, "three steps")
	var nested: bool = true
	for index: int in range(1, steps.size()):
		for cell: Vector2i in steps[index]:
			nested = nested and steps[index - 1].has(cell)
	_check(nested, "every brick lies on one below")
	_check(steps[0].size() > steps[1].size() and steps[1].size() > steps[2].size(), "each step smaller than the one below: %d %d %d" % [steps[0].size(), steps[1].size(), steps[2].size()])
	_check(steps[2].has(Vector2i(0, 0)) and steps[2].has(Vector2i(4, 1)), "the fighters stand on the top")
	# The top's box: the fighters' box grown by the margin (a jittered edge may lose or gain one).
	var box := Rect2i(steps[2].keys()[0], Vector2i.ONE)
	for cell: Vector2i in steps[2]:
		box = box.expand(cell).expand(cell + Vector2i.ONE)
	_check(box.size.x >= 8 and box.size.x <= 10 and box.size.y >= 5 and box.size.y <= 7, "the top: the fighters plus two bricks each way: %s" % box.size)
	var full: int = 13 * 10
	_check(steps[0].size() != full or steps[1].size() != 11 * 8, "the edges hand-laid (not a ruled rectangle)")
	var again := RandomNumberGenerator.new()
	again.seed = 11
	var second: Array[Dictionary] = BattleArena.plan(fighters, Vector2i(0, 0), all_free, 3, 2, Vector2i(28, 20), 0.18, again)
	_check(second[0].keys() == steps[0].keys() and second[2].keys() == steps[2].keys(), "the same place, the same base")
	var table := func(cell: Vector2i) -> bool: return not (cell.x >= 6 and cell.x <= 7 and cell.y >= -1 and cell.y <= 0)
	rng.seed = 11
	var around: Array[Dictionary] = BattleArena.plan(fighters, Vector2i(0, 0), table, 3, 2, Vector2i(28, 20), 0.18, rng)
	var open: bool = true
	for step: Dictionary in around:
		open = open and not step.has(Vector2i(6, 0)) and not step.has(Vector2i(7, -1))
	_check(open, "a table's cells stay open on every step")
	rng.seed = 11
	var far: Array[Dictionary] = BattleArena.plan([Vector2i(0, 0), Vector2i(60, 40)], Vector2i(0, 0), all_free, 3, 2, Vector2i(28, 20), 0.0, rng)
	var top := Rect2i(far[2].keys()[0], Vector2i.ONE)
	for cell: Vector2i in far[2]:
		top = top.expand(cell).expand(cell + Vector2i.ONE)
	_check(top.size.x <= 28 and top.size.y <= 20 and far[2].has(Vector2i(0, 0)) and not far[2].has(Vector2i(60, 40)), "too far apart: the top at most 28 × 20 round the player, the far one off it: %s" % top.size)
	_check(BattleArena.look_for(CombatEncounterMode.Value.SPAR) == "spar" and BattleArena.look_for(CombatEncounterMode.Value.LESSON) == "lesson" and BattleArena.look_for(CombatEncounterMode.Value.LETHAL) == "lethal" and BattleArena.look_for(CombatEncounterMode.Value.SCRIPTED) == "lethal", "the look by mode")
	var looks: Dictionary = BattleArena.data().get("looks", {})
	_check(looks.get("spar", {}).get("corners") == "flag" and looks.get("lethal", {}).get("corners") == "brazier" and int(looks.get("lethal", {}).get("rubble", 0)) > 0, "切磋 flags, 死斗 braziers and rubble")


func _kinds() -> void:
	TestFeel.use()
	var full: int = GameContent.catalog().pacing().feel.opening_full_fights
	_check(full == 3, "pacing.json: the first three fights of a run open in full")
	BattlePace.opening = BattlePace.Opening.FULL
	BattleStageOpening.fights_opened = 0
	_check(BattleStageOpening.next_kind(false) == BattleStageOpening.Kind.FULL and BattleStageOpening.next_kind(true) == BattleStageOpening.Kind.SHORT, "the first: in full; under 自动, short")
	BattleStageOpening.fights_opened = full
	_check(BattleStageOpening.next_kind(false) == BattleStageOpening.Kind.SHORT, "after the first three: short")
	BattlePace.opening = BattlePace.Opening.SHORT
	BattleStageOpening.fights_opened = 0
	_check(BattleStageOpening.next_kind(false) == BattleStageOpening.Kind.SHORT, "简短: always short")
	BattlePace.opening = BattlePace.Opening.OFF
	_check(BattleStageOpening.next_kind(false) == BattleStageOpening.Kind.OFF and BattleStageOpening.next_instant(false), "关: off, at once")
	BattlePace.opening = BattlePace.Opening.FULL
	_check(not BattleStageOpening.next_instant(false), "全程 with the feel's times: not at once")
	TestFeel.restore()
	_check(BattleStageOpening.next_instant(false), "the suites' feel (no times): at once")
	var feel: FeelDefinition = TestFeel.production
	_check(feel.arena_brick_seconds > 0.0 and feel.arena_build_max_seconds > 0.0 and feel.opening_camera_seconds > 0.0 and feel.opening_slide_seconds > 0.0 and feel.arena_take_down_seconds > 0.0 and feel.arena_restyle_seconds > 0.0, "pacing.json carries the opening's times")


func _setting() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	var written: ApplicationSettingsResult = repository.write(ApplicationSettingsSnapshot.defaults().with_battle_opening(BattlePace.Opening.SHORT))
	var back: ApplicationSettingsResult = repository.load()
	_check(written.succeeded() and back.succeeded() and back.snapshot().battle_opening() == BattlePace.Opening.SHORT, "简短 round-trips")
	_check(ApplicationSettingsSnapshot.defaults().battle_opening() == BattlePace.Opening.FULL, "the default: 全程")
	var text: String = files.files[ApplicationSettingsRepository.SETTINGS_PATH].get_string_from_utf8()
	var older: String = text.replace("schema_version=%d" % ApplicationSettingsSnapshot.SCHEMA_VERSION, "schema_version=10")
	var lines := PackedStringArray()
	for line: String in older.split("\n"):
		if not line.begins_with("battle_opening="):
			lines.append(line)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "\n".join(lines).to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().battle_opening() == BattlePace.Opening.FULL, "a version 10 file reads as 全程")
	_check(not ApplicationSettingsSnapshot.defaults().with_battle_opening(9).is_valid(), "no such opening: invalid")


## 战斗演出 C: a blow's sounds by what it was struck with — the player's own: the weapon's layer
## over a hit (a sword's slice, a hammer's thock, a whip's crack) and, quieter, over a parry; a
## whip's miss at its own pitch; a bare-handed 抓伤 the claw's slice; a blow between two others:
## the thud alone, its miss quieter.
func _weapon_sounds() -> void:
	var sword: BattleNarrationLine = _blow(&"p", &"n", CombatAttackResult.Outcome.HIT, &"sword", "刺伤")
	var cues: Array[Array] = BattleSounds.for_line(sword, false, false)
	_check(cues[0][0] == BattleSounds.SLICE and is_equal_approx(float(cues[0][1]), 1.0) and cues.any(func(cue: Array) -> bool: return cue[0] == BattleSounds.THUD), "a sword's hit: the slice over the thud: %s" % [cues])
	var hammer: Array[Array] = BattleSounds.for_line(_blow(&"p", &"n", CombatAttackResult.Outcome.HIT, &"hammer", "瘀伤"), false, false)
	_check(hammer[0][0] == BattleSounds.THOCK and is_equal_approx(float(hammer[0][1]), 0.8), "a hammer's: the thock, low")
	var whip_miss: Array[Array] = BattleSounds.for_line(_blow(&"p", &"n", CombatAttackResult.Outcome.DODGE, &"whip", "鞭伤"), false, false)
	_check(whip_miss == [[BattleSounds.WHOOSH, 1.5, 0.0]], "a whip's miss: its own whistle: %s" % [whip_miss])
	var parry: Array[Array] = BattleSounds.for_line(_blow(&"p", &"n", CombatAttackResult.Outcome.PARRY, &"blade", "割伤"), false, false)
	_check(parry.size() == 2 and parry[1][0] == BattleSounds.SLICE and float(parry[1][2]) < -6.0, "a blade parried: the clang and a quiet slice")
	var claw: Array[Array] = BattleSounds.for_line(_blow(&"p", &"n", CombatAttackResult.Outcome.HIT, &"", "抓伤"), false, false)
	_check(claw[0][0] == BattleSounds.SLICE and is_equal_approx(float(claw[0][1]), 1.3), "a bare-handed claw: a high slice")
	var fist: Array[Array] = BattleSounds.for_line(_blow(&"p", &"n", CombatAttackResult.Outcome.HIT, &"", "瘀伤"), false, false)
	_check(not fist.any(func(cue: Array) -> bool: return cue[0] in [BattleSounds.SLICE, BattleSounds.THOCK]), "a fist: no layer")
	var theirs: BattleNarrationLine = _blow(&"a", &"b", CombatAttackResult.Outcome.HIT, &"sword", "刺伤")
	_check(not BattleSounds.mine(theirs, &"p") and BattleSounds.for_line(theirs, false, false, false) == [[BattleSounds.THUD, 1.0, BattleSounds.PLAIN_HIT_DB]], "a blow between two others: the thud alone")
	_check(BattleSounds.for_line(_blow(&"a", &"b", CombatAttackResult.Outcome.DODGE, &"", ""), false, false, false)[0][2] == BattleSounds.OTHERS_MISS_DB, "their miss quieter")
	_check(BattleSounds.priority_of(theirs, false, &"p") == BattleSounds.PRIORITY_OTHERS and BattleSounds.priority_of(sword, false, &"p") == BattleSounds.PRIORITY_MINE and BattleSounds.priority_of(theirs, true, &"p") == BattleSounds.PRIORITY_KEPT, "priorities: theirs, mine, a felling blow kept")
	_check(sword.weapon_skill == &"sword" and sword.damage_type == "刺伤", "the line carries what it was struck with")


## The voices: a sound of theirs never takes the player's voice; the player's takes theirs.
func _voices(tree: SceneTree) -> void:
	var sounds := BattleSounds.new()
	tree.root.add_child(sounds)
	await tree.process_frame
	for index: int in BattleSounds.VOICES:
		sounds.play(BattleSounds.GONG, 1.0, -30.0, BattleSounds.PRIORITY_MINE)
	var busy: bool = sounds._players.all(func(player: AudioStreamPlayer) -> bool: return player.playing)
	if busy:
		var before: int = sounds.played.size()
		sounds.play(BattleSounds.THUD, 1.0, -30.0, BattleSounds.PRIORITY_OTHERS)
		_check(sounds.played.size() == before, "every voice the player's: a sound of theirs is not played")
		sounds.play(BattleSounds.DRUM, 1.0, -30.0, BattleSounds.PRIORITY_KEPT)
		_check(sounds.played.size() == before + 1 and sounds._voice_priority.has(BattleSounds.PRIORITY_KEPT), "a felling blow's drum takes the oldest of them")
	else:
		_check(sounds._voice_for(BattleSounds.PRIORITY_IDLE) >= 0, "the audio driver plays nothing: a free voice is always there")
	sounds.free()


static func _blow(actor: StringName, target: StringName, outcome: int, weapon: StringName, wound: String) -> BattleNarrationLine:
	return BattleNarrationLine.new("x").with_blow(actor, target, "金光泻地", outcome, -1).with_ring(CombatMoveTags.QUICK, 0).with_arms(weapon, wound)


func _fight(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	var map: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.trainee.2")
	_check(map != null, "beside a trainee in the 武馆")
	if map == null:
		session.free()
		return
	await tree.physics_frame
	var view := map.get_node_or_null("MapView") as WorldVoxelView
	for _frame: int in 600:
		if view != null and view._built:
			break
		await tree.process_frame
	_check(view != null and view._built, "the map's voxel world is built")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	TestFeel.use()
	BattlePace.opening = BattlePace.Opening.FULL
	BattlePace.manual_turns = true
	BattleStageOpening.fights_opened = 0
	var trainee: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school2.trainee.2")
	for state: CharacterState in [session.player_runtime().state, trainee.character_state]:
		state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: nobody falls
	map.select_npc(trainee.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "an attack starts")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var opening: BattleStageOpening = ui.opening
	_check(opening.running() and opening.kind == BattleStageOpening.Kind.FULL, "the first fight opens in full")
	var arena: BattleArena = opening.arena
	_check(arena != null and arena.get_parent() == view.world and arena.laying(), "the base is being laid in the map's voxel world")
	_check(view.staged, "the camera is staged")
	var frame: Array = opening.frame()
	var pitch: float = rad_to_deg(atan(float(frame[1]) / WorldVoxelView.VIEW_RADIUS))
	_check((is_equal_approx(snappedf(pitch, 0.1), 26.0) or is_equal_approx(snappedf(pitch, 0.1), 33.0)) and float(frame[2]) >= 0.4 and float(frame[2]) <= 0.85, "lower (%.1f°) and nearer (%.2f)" % [pitch, float(frame[2])])
	await tree.process_frame # The view hides them on its next frame.
	var quest_hidden: bool = view.quest_marker == null or not view.quest_marker.visible
	var arrows_hidden: bool = view.arrows.values().all(func(arrow: Node3D) -> bool: return not arrow.visible)
	_check(quest_hidden and arrows_hidden, "the quest marker and the exit arrows away: marker hidden %s, arrows shown %s" % [quest_hidden, view.arrows.keys().filter(func(id: StringName) -> bool: return view.arrows[id].visible)])
	_check(is_zero_approx(ui._head.modulate.a) or ui._head.modulate.a < 1.0, "the panel waits hidden")
	var told: int = ui._told.size()
	ui._queue_lines([BattleNarrationLine.new("等开场")])
	_check(ui._told.size() == told, "a line waits while the opening runs")
	for _frame: int in 240:
		if not opening.running():
			break
		await tree.process_frame
	_check(not opening.running() and not arena.laying(), "the opening is done in time")
	_check(arena.brick_count() > 40 and (arena.steps.size() == 3 or arena.steps.size() == 2), "a base of %d bricks in %d steps" % [arena.brick_count(), arena.steps.size()])
	var player_id: StringName = session.player_runtime().character_id
	_check(arena.holds(map.player_body.global_position) and is_equal_approx(ui.scene_show.lift_of(player_id), arena.top_height()), "the player stands on the top step (%.2f)" % ui.scene_show.lift_of(player_id))
	_check(is_equal_approx(ui._head.modulate.a, 1.0) and is_equal_approx(ui.action_panel.modulate.a, 1.0), "the panel in place")
	_check(ui._told.size() == told + 1, "the waiting line told once it is done")
	_check(is_equal_approx(view.view_height(), float(frame[1])) and is_equal_approx(view.zoom(), float(frame[2])), "the camera where the opening put it")
	# A 切磋 look restained into a 死斗's (the stage's restyle; the fight here is a 死斗 already).
	arena.restyle(CombatEncounterMode.Value.SPAR, 0.0)
	_check(arena.look_key == "spar", "restained")
	# 战斗演出 C: the player's blow named over their head (a sword: pale gold); the trainee's at
	# the player too; a blow between two others named nowhere; never more than three.
	var titles: BattleMoveTitles = ui.move_titles
	var trainee_id: StringName = trainee.character_id
	ui._show_line(_blow(player_id, trainee_id, CombatAttackResult.Outcome.HIT, &"sword", "刺伤"))
	_check(titles.shown().size() == 1 and titles.shown()[0] == ["金光泻地", player_id], "the player's move over their head: %s" % [titles.shown()])
	var label: Label = titles.get_child(titles.get_child_count() - 1) as Label
	_check(label != null and label.get_theme_color("font_color") == Color("efc77b"), "a thrust's name pale gold")
	var player_card: BattleParticipantCard = ui._cards[0]
	_check(not player_card.stage.title.visible, "and not on the card")
	ui._show_line(_blow(trainee_id, &"someone.else", CombatAttackResult.Outcome.HIT, &"", "瘀伤"))
	_check(titles.shown().size() == 1, "a blow between two others: no name over a head")
	for index: int in 4:
		ui._show_line(_blow(trainee_id, player_id, CombatAttackResult.Outcome.DODGE, &"", "瘀伤"))
	_check(titles.shown().size() == 3, "three names at most: %d" % titles.shown().size())
	titles.clear()
	# The fight ends: the base comes down and the camera goes back.
	_check(Multi.finish(session), "the fight ends")
	for _frame: int in 200:
		ui.refresh_projection()
		if not is_instance_valid(arena) and not view.staged and is_equal_approx(view.view_height(), WorldVoxelView.VIEW_HEIGHT):
			break
		await tree.process_frame
	_check(not is_instance_valid(arena), "the base taken down")
	_check(not view.staged and is_equal_approx(view.view_height(), WorldVoxelView.VIEW_HEIGHT) and is_equal_approx(view.zoom(), 1.0), "the camera given back (height %.2f, zoom %.2f)" % [view.view_height(), view.zoom()])
	# Later fights open short; a key puts one in place at once.
	BattleStageOpening.fights_opened = GameContent.catalog().pacing().feel.opening_full_fights
	for _frame: int in 60:
		await tree.process_frame
	map.select_npc(trainee.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a second fight")
	for _frame: int in 3:
		await tree.process_frame
	_check(ui.opening.running() and ui.opening.kind == BattleStageOpening.Kind.SHORT, "the fourth fight of the run opens short")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	ui.opening._input(key)
	_check(not ui.opening.running() and ui.opening.arena != null and not ui.opening.arena.laying() and is_equal_approx(ui._head.modulate.a, 1.0), "a key: everything in place at once")
	Multi.finish(session)
	for _frame: int in 60:
		ui.refresh_projection()
		await tree.process_frame
	session.free()
	await tree.process_frame


const Multi := preload("res://tests/support/cxr7_session_fixture.gd")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("battle stage: " + label)
