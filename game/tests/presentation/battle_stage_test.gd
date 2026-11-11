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
## 战斗演出 D (DECISIONS「战斗演出 D」): the stage the standard size for the fighters' places (the
## player left, their side behind, the other side right in ranks), raised over the map with the
## fighters' figures on it while their 2D bodies stay put, the map below a backdrop, all of it
## back at the end; a key puts the stage up at once.
## 战斗演出 E (DECISIONS「战斗演出 E」): the two sides — the stage's halves lit in their colours
## with a seam between, the player's card a side panel on the left with their bust, the target's
## on the right, each on a voxel banner let down as the panel opens and flapping when its side
## strikes; a name plate under each fighter's feet in their side's colour
## (a back rank's over the head), clicked to pick a target.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_plan()
	_formation()
	_ranks()
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


## 战斗演出 D: the places on the stage — a duel face to face across the gap, the player on the
## left; a helper behind the player; six foes in two ranks of three on the right, the back of each
## a little further out, no two in one place.
func _formation() -> void:
	var data: Dictionary = BattleArena.data().get("formation", {})
	var gap: float = float(data.get("gap", 2.4)) * VoxelMapGeometry.UNIT
	var duel: Dictionary[StringName, Vector2] = BattleArena.formation([&"p"], [&"n"], data)
	_check(duel[&"p"].x < 0.0 and duel[&"n"].x > 0.0 and is_equal_approx(duel[&"n"].x - duel[&"p"].x, gap) and is_zero_approx(duel[&"p"].y), "a duel: the player left, the foe right, the gap between: %s" % [duel])
	var foes: Array[StringName] = [&"a", &"b", &"c", &"d", &"e", &"f"]
	var crowd: Dictionary[StringName, Vector2] = BattleArena.formation([&"p", &"helper"], foes, data)
	_check(crowd[&"helper"].x < crowd[&"p"].x, "a helper stands behind the player")
	_check(foes.all(func(id: StringName) -> bool: return crowd[id].x > 0.0), "every foe on the right")
	var column: float = float(data.get("column", 1.15)) * VoxelMapGeometry.UNIT
	var pair: Dictionary[StringName, Vector2] = BattleArena.formation([&"p"], [&"a", &"b"], data)
	_check(absf(pair[&"a"].x - pair[&"b"].x) >= float(data.get("stagger", 0.45)) * 2.0 * VoxelMapGeometry.UNIT - 0.01, "two side by side: apart across the screen too")
	_check(is_equal_approx(crowd[&"a"].x, gap / 2.0) and is_equal_approx(crowd[&"d"].x, gap / 2.0 + column) and is_zero_approx(crowd[&"a"].y) and is_zero_approx(crowd[&"d"].y), "six foes in two ranks of three, each led from the middle")
	_check(crowd[&"b"].x > crowd[&"a"].x and crowd[&"b"].y < crowd[&"a"].y, "a rank's back row further out")
	var places: Dictionary = {}
	for id: StringName in crowd:
		places[crowd[id]] = true
	_check(places.size() == crowd.size(), "no two in one place")


## 战斗演出 E: who stands in a back rank (their plate over their head): in each column of three,
## the two behind the nearest; the player and a lone helper never.
func _ranks() -> void:
	var opening := BattleStageOpening.new()
	opening._player_id = &"p"
	opening._mine = [&"p", &"h"]
	opening._theirs = [&"a", &"b", &"c", &"d"]
	opening._local = BattleArena.formation(opening._mine, opening._theirs, BattleArena.data().get("formation", {}))
	_check(not opening.back_rank(&"p") and not opening.back_rank(&"h"), "the player and a lone helper: front")
	_check(not opening.back_rank(&"c") and opening.back_rank(&"a") and opening.back_rank(&"b") and not opening.back_rank(&"d"), "three in a column: the nearest in front, the two behind it back; one alone in the next: front")
	opening.free()


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
		if not line.begins_with("battle_opening=") and not line.begins_with("graphics_quality=") and not line.begins_with("quality_hint_told="):
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
	var trainee_body: WorldCharacterBody2D = map.runtime_body_for_character(trainee.character_id)
	map.select_npc(trainee.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "an attack starts")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var opening: BattleStageOpening = ui.opening
	_check(opening.running() and opening.kind == BattleStageOpening.Kind.FULL, "the first fight opens in full")
	var arena: BattleArena = opening.arena
	_check(arena != null and arena.get_parent() == view.world and arena.laying(), "the base is being laid in the map's voxel world")
	var player_at: Vector2 = map.player_body.global_position
	var trainee_at: Vector2 = trainee_body.global_position
	_check(opening.backdrop != null and opening.backdrop.get_parent() == view.world and opening.risen() < 1.0, "the backdrop is there and the stage still rising")
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
	_check(arena.brick_count() > 40 and arena.steps.size() == 3, "a base of %d bricks in %d steps" % [arena.brick_count(), arena.steps.size()])
	var player_id: StringName = session.player_runtime().character_id
	var trainee_id: StringName = trainee.character_id
	_check(_stage_up(opening, view, arena), "the stage in the air, square to the camera, its own size")
	await tree.process_frame
	_check(_on_stage(opening, view, [player_id, trainee_id]), "the figures stand in their places on the stage")
	_check(map.player_body.global_position == player_at and trainee_body.global_position == trainee_at, "the 2D bodies have not moved")
	_check(view.camera.unproject_position(opening.spots()[player_id]).x < view.camera.unproject_position(opening.spots()[trainee_id]).x, "the player on the left, the trainee on the right")
	_check(opening.backdrop.visible and is_equal_approx(opening.backdrop.amount, 1.0) and float(opening.backdrop.parameter("darken")) > 0.0 and _holds_stage(opening.backdrop, arena), "the map round the stage a soft, darker backdrop; the stage's own space clear")
	_check(ui._shade.modulate.a < 1.0, "the panel's shade lighter: the backdrop darkens the map instead")
	# One who joins (a 天将 summoned) gets a place at the back of their side; the base grows to hold them.
	var joined: Dictionary[StringName, Vector2] = {player_id: player_at, trainee_id: trainee_at, &"test.joiner": trainee_at}
	opening.seat(joined, [trainee_id, &"test.joiner"])
	_check(opening.spots().has(&"test.joiner") and _stage_up(opening, view, arena) and view.placed_at(&"test.joiner") != null, "one who joins: a place on the stage, the base wide enough")
	var others_named: bool = view.labels.keys().any(func(id: StringName) -> bool: return id != player_id and id != trainee_id and view.labels[id].visible)
	_check(not others_named, "no name shown over those left on the map")
	# 战斗演出 E: the two sides on the stage, the side panels, the name plates.
	var glow: Array[float] = arena.glow_strengths()
	var lethal_glow: Dictionary = BattleArena.data().get("looks", {}).get("lethal", {}).get("glow", {})
	_check(arena.glowing_bricks() > 0 and arena.glowing_bricks() < arena.brick_count() / 3, "glowing bricks set among the stone: %d of %d" % [arena.glowing_bricks(), arena.brick_count()])
	_check(glow.size() == 2 and is_equal_approx(glow[0], float(lethal_glow.get("mine", -1))) and is_equal_approx(glow[1], float(lethal_glow.get("theirs", -1))), "a 死斗's stage: each half lit in its side's colour: %s" % [glow])
	var left: BattleParticipantCard = _panel_of(ui, 0)
	var right: BattleParticipantCard = _panel_of(ui, 1)
	_check(left != null and left.participant_id() == player_id and left.panel_style() == BattlePresentationController.PANEL_STYLE and left._portrait.texture != null and String(left._portrait.texture.resource_path).contains("player."), "the player's card the left panel, their bust chosen (shown where a whole multiple of its pixels fits)")
	_check(right != null and right.participant_id() == trainee_id and right.get_global_rect().position.x > left.get_global_rect().end.x, "the trainee's the right panel")
	await tree.process_frame
	var plates: Dictionary = ui.nameplates.shown()
	_check(plates.has(player_id) and plates.has(trainee_id), "a name plate for each: %s" % [plates.keys()])
	if plates.has(player_id) and plates.has(trainee_id):
		var mine: Rect2 = plates[player_id][0]
		var theirs: Rect2 = plates[trainee_id][0]
		var feet: Vector2 = view.camera.unproject_position(view.actors[player_id].global_position)
		_check(mine.end.x < theirs.position.x and not plates[player_id][1] and mine.position.y >= feet.y - 1.0, "the player's plate on the left, under their feet; the trainee's on the right")
	var picked: Array[StringName] = []
	ui.nameplates.target_requested.connect(func(id: StringName) -> void: picked.append(id))
	var plate: Control = ui.nameplates.plate(trainee_id)
	if plate != null:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		plate._gui_input(press)
	_check(picked == [trainee_id], "a click on the trainee's plate picks them")
	# The banners: voxel cloth on a pole, the target's ends gold; a strike flaps its side's.
	var mine_banner: BattleVoxelBanner = left.banner()
	var theirs_banner: BattleVoxelBanner = right.banner()
	_check(mine_banner.cloth_rows > 0 and mine_banner._mesh.multimesh.instance_count > BattleVoxelBanner.COLUMNS * mine_banner.cloth_rows and theirs_banner.current == (ui.current_projection().current_target_id == trainee_id) and not mine_banner.current, "voxel banners, the target's (when there is one) marked: rows %d bricks %s current %s/%s" % [mine_banner.cloth_rows, mine_banner._mesh.multimesh.instance_count if mine_banner._mesh.multimesh != null else -1, mine_banner.current, theirs_banner.current])
	_check(is_equal_approx(mine_banner.unfurled(), 1.0) and is_equal_approx(theirs_banner.unfurled(), 1.0), "let down by the time the opening is over")
	mine_banner.gust_now = 0.0
	theirs_banner.gust_now = 0.0
	ui._show_line(_blow(trainee_id, player_id, CombatAttackResult.Outcome.DODGE, &"", "瘀伤"))
	_check(theirs_banner.gust_now > 0.0 and is_zero_approx(mine_banner.gust_now), "the trainee strikes: their banner flaps, the player's still: %.2f / %.2f" % [theirs_banner.gust_now, mine_banner.gust_now])
	ui.move_titles.clear()
	_check(is_equal_approx(ui._head.modulate.a, 1.0) and is_equal_approx(ui.action_panel.modulate.a, 1.0), "the panel in place")
	_check(ui._told.size() == told + 1, "the waiting line told once it is done")
	_check(is_equal_approx(view.view_height(), float(frame[1])) and is_equal_approx(view.zoom(), float(frame[2])), "the camera where the opening put it")
	# A 切磋 look restained into a 死斗's (the stage's restyle; the fight here is a 死斗 already).
	arena.restyle(CombatEncounterMode.Value.SPAR, 0.0)
	_check(arena.look_key == "spar", "restained")
	# 战斗演出 C: the player's blow named over their head (a sword: pale gold); the trainee's at
	# the player too; a blow between two others named nowhere; never more than three.
	var titles: BattleMoveTitles = ui.move_titles
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
	for _frame: int in 60:
		if not ui.opening.landing():
			break
		await tree.process_frame
	await tree.process_frame
	_check(not ui.opening.landing() and not view.placing() and view.placed_at(player_id) == null, "everyone down again")
	_check(view.actors[player_id].position.is_equal_approx(VoxelMapGeometry.point(map.player_body.global_position, 0.02)) and view.actors[trainee_id].position.is_equal_approx(VoxelMapGeometry.point(trainee_body.global_position, 0.02)), "each figure back where its body stands")
	_check(view.world.get_children().all(func(node: Node) -> bool: return not node is VoxelBackdrop or node.is_queued_for_deletion()), "the backdrop gone")
	_check(is_equal_approx(ui._shade.modulate.a, 1.0), "the shade its own again")
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
	_check(is_equal_approx(ui.opening.risen(), 1.0) and _stage_up(ui.opening, view, ui.opening.arena) and is_equal_approx(ui.opening.backdrop.amount, 1.0), "a key: the stage up and the backdrop in at once")
	Multi.finish(session)
	for _frame: int in 60:
		ui.refresh_projection()
		await tree.process_frame
	session.free()
	await tree.process_frame


const Multi := preload("res://tests/support/cxr7_session_fixture.gd")


## The card in the side panel (0 left, 1 right), or null.
static func _panel_of(ui: BattlePresentationController, side: int) -> BattleParticipantCard:
	for child: Node in ui._flank_slots[side].get_children():
		var card := child as BattleParticipantCard
		if card != null and card.visible:
			return card
	return null


## The stage up in the air at its height, turned to the camera's yaw, every place on its top.
func _stage_up(opening: BattleStageOpening, view: WorldVoxelView, arena: BattleArena) -> bool:
	var height: float = float(BattleArena.data().get("arena", {}).get("float_height", 2.6))
	var yaw: float = -WorldVoxelView.VIEW_SIDE_ANGLE if view.left_view else WorldVoxelView.VIEW_SIDE_ANGLE
	if arena.position.y < height - 0.001 or not is_equal_approx(arena.rotation.y, yaw):
		_failures.append("battle stage: up at %.2f (want at least %.2f), turned %.2f (want %.2f)" % [arena.position.y, height, arena.rotation.y, yaw])
		return false
	for id: StringName in opening.spots():
		var local: Vector3 = arena.to_local(opening.spots()[id])
		if not arena.holds(Vector2(local.x, local.z) * VoxelMapGeometry.UNIT) or not is_equal_approx(local.y, arena.top_height()):
			_failures.append("battle stage: %s not on the top (%s)" % [id, local])
			return false
	return true


## The backdrop leaves the stage's own space clear: the base's footprint (and a little more), in
## the stage's frame as it stands now.
func _holds_stage(backdrop: VoxelBackdrop, arena: BattleArena) -> bool:
	var box: Vector4 = backdrop.parameter("box")
	var foot: Rect2 = arena.footprint(0.0)
	var inverse: Projection = backdrop.parameter("stage_inverse")
	var origin: Vector4 = inverse * Vector4(arena.global_position.x, arena.global_position.y, arena.global_position.z, 1.0)
	return box.x < foot.position.x and box.y < foot.position.y and box.z > foot.end.x and box.w > foot.end.y and Vector3(origin.x, origin.y, origin.z).is_zero_approx()


## Each of `ids` drawn at its place on the stage (its actor node there; the model on it).
func _on_stage(opening: BattleStageOpening, view: WorldVoxelView, ids: Array) -> bool:
	for id: StringName in ids:
		var spot: Variant = view.placed_at(id)
		if spot == null or not opening.spots().has(id) or not view.actors[id].position.is_equal_approx(spot):
			_failures.append("battle stage: %s at %s, placed %s" % [id, view.actors[id].position, spot])
			return false
	return true


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("battle stage: " + label)
