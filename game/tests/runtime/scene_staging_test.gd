extends RefCounted

## 过场演出 B (DECISIONS「过场动作」): what a scene's steps show besides their words — in the 逆灵宫
## 后殿, with 商玦 and 玄冥子 standing there (the 唤首 scene itself stopped before its first line,
## then played whole at the end):
## - every action word: where it starts and where it ends (the 2D body for what moves, the pose
##   told to the view for the rest), the player's own figure turning to whoever speaks;
## - one press takes a line on and everything under way is at its end; a line that goes on by
##   itself waits for its action; actions after the last line hold the world, then the scene goes on;
## - who walked is back where it stood when the scene is over, unless told to stay; cut short
##   (the box shut, the map left, a fight) everyone is where they belong at once and who was to
##   leave has left;
## - the shots (near, two, look, wide), their light, and a fight keeping the camera;
## - a 主线场面 named by a step plays once, with its step, and its own trigger still works alone;
## - the feel off: nothing is shown and every step is as it was;
## - 唤首 pressed through: each beat shown, the same people gone and come as before.

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
const SHANG: StringName = &"native.npc.shang_jue"
const XUAN: StringName = &"native.npc.xuan_mingzi"
const SHADE: StringName = &"native.npc.headless_shade"
const RUNNER: StringName = &"native.npc.hell_runner"
const KEY: StringName = &"native:niling/cell_key"
const ALTAR: StringName = &"niling.altar"
const SOUTH_DOOR: StringName = &"niling.altar.door"
const NORTH_DOOR: StringName = &"niling.master.door"
const BEHIND: StringName = &"niling.altar.master_return"
const SCENE_MARK: String = "见过唤首"

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	TestFeel.use()
	var session: WorldSessionController = await _altar(tree, true)
	if session != null:
		_check_words(session)
		_check_things(session)
		await _check_moves(tree, session)
		_check_press(session)
		await _check_auto(tree, session)
		await _check_home(tree, session)
		await _check_shots(tree, session)
		await _check_figures(tree, session)
		await _check_fx(tree, session)
		await _check_come_and_go(tree, session)
		# (It frees this session and goes on in a fresh one: its people are spent by then.)
		await _check_cut_short(tree, session)
	await tree.process_frame
	await _check_fight(tree)
	await _check_the_scene(tree)
	TestFeel.restore()
	await _check_feel_off(tree)
	return {"assertions": assertions, "failures": failures}


# --- each word, where it starts and ends ---


## The words that pose a figure: the pose told to the view, how far, and what is kept after.
func _check_words(session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var me: StringName = session.player_runtime().character_id
	var player: WorldCharacterBody2D = map.player_body
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	# face: he turns to the player; the player turns to whoever speaks, by themselves.
	_tell(map, xuan, [{"say": "一", "do": {"act": "face", "toward": "player"}}])
	_check(box.is_open() and stage.busy(), "a staged line is read in the box")
	_check(xuan_body.facing.is_equal_approx(_toward(xuan_body.global_position, player.global_position)), "face: 玄冥子 looks at the player: %s" % xuan_body.facing)
	_check(player.facing.is_equal_approx(_toward(player.global_position, xuan_body.global_position)), "the player turns to who speaks: %s" % player.facing)
	_check(is_equal_approx(stage.left_seconds(), SceneStage.seconds(&"face")) and stage.left_seconds() > 0.0, "the turn takes its time: %s" % stage.left_seconds())
	stage.advance(SceneStage.seconds(&"face") + 0.01)
	_check(is_zero_approx(stage.left_seconds()) and stage.busy(), "then it is over; the page is still read")
	_check(session.presentation_frozen() and not stage.between(), "the world held by the page, not by the staging")
	box.advance()
	_check(not box.is_open() and not stage.busy() and not stage.between(), "read out with nothing under way: nothing held")
	# bow: down and up again, toward the one bowed to.
	_tell(map, xuan, [{"say": "二", "do": {"act": "bow", "toward": String(SHANG)}}])
	_check(xuan_body.facing.is_equal_approx(_toward(xuan_body.global_position, shang_body.global_position)), "bow: turned to 商玦")
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_BOW and is_zero_approx(stage.pose_amount(xuan.character_id)), "bow begins upright")
	stage.advance(SceneStage.seconds(&"bow") * 0.5)
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_BOW and is_equal_approx(stage.pose_amount(xuan.character_id), 1.0), "half-way it is bent low: %s" % stage.pose_amount(xuan.character_id))
	stage.advance(SceneStage.seconds(&"bow") * 0.5 + 0.01)
	_check(stage.pose(xuan.character_id).is_empty() and is_zero_approx(stage.pose_amount(xuan.character_id)), "and up again when it is over")
	box.advance()
	# kneel stays until rise; the player's figure kneels when told to.
	_tell(map, xuan, [
		{"say": "三", "do": ["kneel", {"who": "player", "act": "kneel"}]},
		{"say": "四"},
		{"say": "五", "do": ["rise", {"who": "player", "act": "rise"}]},
	])
	stage.advance(SceneStage.seconds(&"kneel") * 0.5)
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_KNEEL and stage.pose_amount(xuan.character_id) > 0.3 and stage.pose_amount(xuan.character_id) < 0.7, "kneel: on the way down: %s" % stage.pose_amount(xuan.character_id))
	_check(stage.pose(me) == WorldMapStaging.POSE_KNEEL, "the player's figure kneels too")
	stage.advance(SceneStage.seconds(&"kneel"))
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_KNEEL and is_equal_approx(stage.pose_amount(xuan.character_id), 1.0) and is_zero_approx(stage.left_seconds()), "down, and it stays down")
	box.advance()
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_KNEEL and stage.pose(me) == WorldMapStaging.POSE_KNEEL, "still kneeling on the next line")
	box.advance()
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_KNEEL and is_equal_approx(stage.pose_amount(xuan.character_id), 1.0), "rise begins from the knees")
	stage.advance(SceneStage.seconds(&"rise") + 0.01)
	_check(stage.pose(xuan.character_id).is_empty() and stage.pose(me).is_empty(), "rise: both up")
	box.advance()
	# draw keeps the weapon out until sheathe.
	_tell(map, shang, [{"say": "六", "do": "draw"}, {"say": "七", "do": "sheathe"}])
	_check(stage.pose(shang.character_id) == WorldMapStaging.POSE_GUARD and stage.weapon_of(shang.character_id) == String(shang.character_state.equipment.primary_weapon_skill_type()), "draw: on guard, its own weapon: '%s'" % stage.weapon_of(shang.character_id))
	stage.advance(SceneStage.seconds(&"draw") + 0.01)
	_check(stage.pose(shang.character_id) == WorldMapStaging.POSE_GUARD, "the weapon stays out")
	box.advance()
	_check(stage.pose(shang.character_id).is_empty() and stage.left_seconds() > 0.0, "sheathe: put away, over its time")
	stage.advance(SceneStage.seconds(&"sheathe") + 0.01)
	box.advance()
	# fall lies until rise.
	_tell(map, xuan, [{"say": "八", "do": "fall"}, {"say": "九", "do": "rise"}])
	stage.advance(SceneStage.seconds(&"fall") + 0.01)
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_FALL and is_equal_approx(stage.pose_amount(xuan.character_id), 1.0), "fall: down on its back, and stays")
	_check(xuan.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the picture only: he is not felled")
	box.advance()
	stage.advance(SceneStage.seconds(&"rise") + 0.01)
	_check(stage.pose(xuan.character_id).is_empty(), "rise: up from lying")
	box.advance()
	# startle, shiver, reach.
	_tell(map, xuan, [
		{"say": "十", "do": ["startle", {"who": "player", "act": "shiver"}]},
		{"say": "十一", "do": {"act": "reach", "hold": true}},
		{"say": "十二", "do": {"act": "shiver", "hold": true}},
		{"say": "十三", "do": {"act": "face", "toward": "player"}},
	])
	_check(stage.hops(xuan.character_id) == 1 and stage.shivers(me) and not stage.shivers(xuan.character_id), "startle: one start; the player shivers")
	stage.advance(SceneStage.seconds(&"shiver") + 0.01)
	_check(not stage.shivers(me), "a shiver passes")
	box.advance()
	stage.advance(SceneStage.seconds(&"reach") + 0.01)
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_REACH and is_equal_approx(stage.pose_amount(xuan.character_id), 1.0), "reach, kept up: hands still out")
	box.advance()
	_check(stage.pose(xuan.character_id).is_empty() and stage.shivers(xuan.character_id), "the next action lets the hands go; he shivers")
	stage.advance(SceneStage.seconds(&"shiver") + 0.01)
	_check(stage.shivers(xuan.character_id), "a shiver kept up goes on")
	box.advance()
	_check(not stage.shivers(xuan.character_id), "until his next action")
	box.advance()
	_check(stage.directed(xuan.character_id) and stage.directed(shang.character_id), "the scene's people are its own until it is over")
	_end(map, box)
	_check(not stage.shows() and not stage.directed(xuan.character_id) and stage.hops(xuan.character_id) == 0, "over: every pose let go, nobody directed")


## hand and toss: the thing in the air between two, nothing given by it.
func _check_things(session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var me: StringName = session.player_runtime().character_id
	var held: int = session.player_inventory_rows().size()
	var look: Dictionary = SceneStage.part("flight")
	for word: String in ["toss", "hand"]:
		_tell(map, shang, [{"emote": "抛", "do": {"act": word, "item": String(KEY), "to": String(XUAN)}}])
		var whole: float = SceneStage.seconds(StringName(word))
		_check(stage.flights().is_empty() and stage.pose(shang.character_id) == WorldMapStaging.POSE_GIVE, "%s begins with the giver's arm, the thing still in hand" % word)
		stage.advance(whole * (float(look["from"]) + float(look["to"])) / 2.0)
		var flying: Array[Array] = stage.flights()
		_check(flying.size() == 1 and flying[0][0] == shang.character_id and flying[0][1] == xuan.character_id and flying[0][2] == KEY and flying[0][3] == StringName(word), "%s: the key in the air from 商玦 to 玄冥子: %s" % [word, flying])
		_check(flying.size() == 1 and float(flying[0][4]) > 0.3 and float(flying[0][4]) < 0.7, "half-way across")
		_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_CATCH, "the other's hand comes up for it")
		stage.advance(whole)
		_check(stage.flights().is_empty() and stage.pose(shang.character_id).is_empty() and stage.pose(xuan.character_id).is_empty(), "%s over: nothing in the air, both at ease" % word)
		box.advance()
	# To the player too; nothing changes hands by it (a `give` step does that).
	_tell(map, shang, [{"emote": "递", "do": {"act": "hand", "item": String(KEY), "to": "player"}}])
	stage.advance(SceneStage.seconds(&"hand") * 0.5)
	_check(stage.flights().size() == 1 and stage.flights()[0][1] == me and stage.pose(me) == WorldMapStaging.POSE_CATCH, "handed to the player: their hand comes up")
	box.advance()
	_check(session.player_inventory_rows().size() == held, "the picture only: the player's pack is as it was")
	_end(map, box)


## What moves the body: a step back, a walk to a spot and beside someone; the 2D map's own.
func _check_moves(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var player: WorldCharacterBody2D = map.player_body
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var stood: Vector2 = xuan_body.global_position
	var player_stood: Vector2 = player.global_position
	# step_back: away from the player, eyes on them; the player from whoever speaks.
	_tell(map, xuan, [{"say": "一", "do": ["step_back", {"who": "player", "act": "step_back"}]}])
	stage.advance(SceneStage.seconds(&"step_back") * 0.5)
	var half: float = xuan_body.global_position.distance_to(stood)
	_check(half > 4.0 and half < SceneStage.step_back_px() - 4.0, "step_back: half a step: %s" % half)
	stage.advance(SceneStage.seconds(&"step_back"))
	_check(is_equal_approx(xuan_body.global_position.distance_to(stood), SceneStage.step_back_px()) and xuan_body.global_position.distance_to(player_stood) > stood.distance_to(player_stood), "a step away from the player: %s" % xuan_body.global_position)
	_check(xuan_body.facing.is_equal_approx(_toward(stood, player_stood)) and not xuan_body.facing_held, "still looking at them")
	_check(is_equal_approx(player.global_position.distance_to(player_stood), SceneStage.step_back_px()) and player.global_position.distance_to(stood) > player_stood.distance_to(stood), "the player a step away from who speaks: %s" % player.global_position)
	_check(MapPlacementValidator.is_valid_character_position(map, ALTAR, xuan_body.global_position) and MapPlacementValidator.is_valid_character_position(map, ALTAR, player.global_position), "both stand where a body may stand")
	box.advance()
	_end(map, box)
	map.npc_life.npc_walker().finish_all()
	map.place_player(ALTAR, player_stood)
	xuan_body.global_position = stood
	await _physics(tree, 3)
	# Pressed half-way: the step is at its end, and the body's own next steps do not turn it.
	_tell(map, xuan, [{"say": "一", "do": ["step_back", {"who": "player", "act": "step_back"}]}, {"say": "二"}])
	stage.advance(SceneStage.seconds(&"step_back") * 0.3)
	await _physics(tree, 2)
	box.advance()
	_check(is_equal_approx(xuan_body.global_position.distance_to(stood), SceneStage.step_back_px()), "pressed: the step is whole")
	await _physics(tree, 3)
	_check(xuan_body.facing.is_equal_approx(_toward(stood, player_stood)) and not xuan_body.facing_held, "he still looks at the player after his body's own steps: %s" % xuan_body.facing)
	_check(player.facing.is_equal_approx(_toward(player_stood, stood)) and not player.facing_held, "and the player at him: %s" % player.facing)
	box.advance()
	_end(map, box)
	_check(xuan_body.global_position.is_equal_approx(stood) or map.npc_life.npc_walker().is_walking(xuan.character_id), "over: 玄冥子 back where he stood (or on his way)")
	map.npc_life.npc_walker().finish_all()
	_check(xuan_body.global_position.distance_to(stood) < 2.0, "at his spot again: %s" % xuan_body.global_position)
	_check(player.global_position.distance_to(player_stood) > 4.0, "the player is not walked back: theirs to walk")
	map.place_player(ALTAR, player_stood)
	# walk to a spawn point: over the walkable ground, at the staged speed, ending on it.
	var behind: Vector2 = map.resolve_spawn_marker(BEHIND).global_position
	var from: Vector2 = shang_body.global_position
	_tell(map, shang, [{"emote": "走", "do": {"act": "walk", "to": String(BEHIND)}}])
	var whole: float = stage.left_seconds()
	_check(whole * SceneStage.walk_speed() >= from.distance_to(behind) and whole > 1.5, "walk: a way round the altar, %.1f s at the staged speed" % whole)
	stage.advance(1.0)
	_check(is_equal_approx(stage.left_seconds(), whole - 1.0) and shang_body.global_position.distance_to(from) > 40.0 and shang_body.global_position.distance_to(from) <= SceneStage.walk_speed() + 0.5, "a second on: %s px along" % shang_body.global_position.distance_to(from))
	await _frames(tree, 2)
	_check((shang_body.get_node("CollisionShape2D") as CollisionShape2D).disabled, "walking, he goes through people as any walker does")
	_check(not (shang_body.get_node("AggressionPresence/CollisionShape2D") as CollisionShape2D).disabled, "his presence is left alone: he notices and forgets nobody by a scene's walk")
	# Another window's hold (the menu) stops the walk where it is; the page's own does not.
	var held_at: Vector2 = shang_body.global_position
	session.hold_world_time(&"menu")
	stage.advance(1.0)
	_check(shang_body.global_position.is_equal_approx(held_at), "the menu open: he stands where he was")
	session.release_world_time(&"menu")
	stage.advance(whole)
	_check(shang_body.global_position.distance_to(behind) < 1.0 and is_zero_approx(stage.left_seconds()), "there: %s" % shang_body.global_position)
	await _frames(tree, 2)
	_check(not (shang_body.get_node("CollisionShape2D") as CollisionShape2D).disabled, "standing again, he is solid again")
	_check(shang.world_location().zone_id == ALTAR, "his room is the map's own")
	box.advance()
	# walk beside someone: a free spot by them, on the side he came from.
	_tell(map, shang, [{"emote": "走", "do": {"act": "walk", "to": String(XUAN)}}])
	stage.advance(60.0)
	var gap: float = shang_body.global_position.distance_to(xuan_body.global_position)
	_check(gap >= 40.0 and gap <= 100.0 and MapPlacementValidator.is_valid_character_position(map, ALTAR, shang_body.global_position), "walk to someone ends beside them: %s px" % gap)
	box.advance()
	_end(map, box)
	map.npc_life.npc_walker().finish_all()
	_check(shang_body.global_position.distance_to(from) < 2.0, "over: 商玦 back at his spot")
	await _frames(tree, 2)


# --- the page and the action ---


## One press takes the line on: what is under way is at its end at once.
func _check_press(session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var behind: Vector2 = map.resolve_spawn_marker(BEHIND).global_position
	_tell(map, shang, [
		{"emote": "走", "do": [{"act": "walk", "to": String(BEHIND)}, {"who": String(XUAN), "act": "kneel"}, {"act": "toss", "item": String(KEY), "to": String(XUAN)}]},
		{"say": "二", "do": {"who": String(XUAN), "act": "bow"}},
		{"say": "三"},
	])
	stage.advance(0.3)
	_check(stage.left_seconds() > 1.0 and shang_body.global_position.distance_to(behind) > 60.0, "a walk, a kneel and a toss under way")
	box.advance()
	_check(shang_body.global_position.distance_to(behind) < 1.0, "pressed: he is at the walk's end, not half-way: %s" % shang_body.global_position)
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_BOW and stage.flights().is_empty(), "the kneel over (the next line's bow has begun), nothing left in the air")
	_check(is_equal_approx(stage.left_seconds(), SceneStage.seconds(&"bow")), "only the new line's action runs: %s" % stage.left_seconds())
	box.advance()
	_check(stage.pose(xuan.character_id) == WorldMapStaging.POSE_KNEEL and is_zero_approx(stage.left_seconds()), "pressed again: the bow over, he kneels as he was left")
	box.advance()
	_end(map, box)
	map.npc_life.npc_walker().finish_all()


## A line that goes on by itself waits for its action; what comes after the last line holds the
## world, and a press takes that to its end too.
func _check_auto(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var behind: Vector2 = map.resolve_spawn_marker(BEHIND).global_position
	var kept: FeelDefinition = GameContent.catalog().pacing().feel
	# pacing.json's reading (lines go on by themselves), the journey's start as the suites'.
	GameContent.catalog().pacing().feel = TestFeel.production.but({"map_loading_slice_ms": 0, "session_start_slice_ms": 0, "dialogue_press_guard_ms": 0})
	DialogueAuto.on = true
	_tell(map, shang, [{"emote": "走", "do": {"act": "walk", "to": String(BEHIND)}}, {"say": "到"}])
	var walk: float = stage.left_seconds()
	var read: float = box.auto_left()
	_check(read > 0.0 and walk > read + 0.5, "a short line (%.1f s to read) with a long walk (%.1f s)" % [read, walk])
	var seen: String = box.line()
	var waited: float = 0.0
	while box.is_open() and box.line() == seen and waited < walk + 3.0:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		if waited > read + 0.3 and waited < walk - 0.3:
			_check_quiet(box.line() == seen and stage.left_seconds() > 0.0, "read long ago, the line waits for the walk")
	_check(box.is_open() and box.line() != seen and waited >= walk - 0.1, "it went on by itself once he arrived: %.1f s" % waited)
	_check(shang_body.global_position.distance_to(behind) < 1.0, "and he is there")
	box.advance()
	_end(map, box)
	map.npc_life.npc_walker().finish_all()
	# After the last line: someone walks out. The world holds for it as for a page.
	var from: Vector2 = xuan_body.global_position
	_tell(map, xuan, [{"say": "走了"}, {"mark": "t.staged"}, {"emote": "走", "present": "t.nobody"}, {"by": String(XUAN), "do": {"act": "walk", "to": String(SOUTH_DOOR), "stay": true}}])
	_check(xuan_body.global_position.is_equal_approx(from) and is_zero_approx(stage.left_seconds()), "a cue after a line waits for the line to be read")
	_check(session.player_runtime().state.marks.has("t.staged"), "its step's rule was settled at once all the same")
	box.advance()
	_check(not box.is_open() and stage.between() and session.presentation_frozen() and map.player_body.walk_paused, "read out: his walk holds the world as a page did")
	var minutes: float = session.day_clock().day_minutes()
	await _frames(tree, 12)
	_check(xuan_body.global_position.distance_to(from) > 10.0 and is_equal_approx(session.day_clock().day_minutes(), minutes), "he walks; the world's clock stands")
	_press(hud)
	_check(not stage.between() and not session.presentation_frozen() and xuan_body.global_position.distance_to(map.door(SOUTH_DOOR).wall_shape().global_position) < 60.0, "a press between two lines takes the walk to its end: %s" % xuan_body.global_position)
	session.player_runtime().state.marks.erase("t.staged")
	_end(map, box)
	xuan_body.global_position = from
	DialogueAuto.on = true
	GameContent.catalog().pacing().feel = kept
	await _frames(tree, 2)


## Who walked is back where it stood when the scene is over; one told to stay stays.
func _check_home(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var shang_home: Vector2 = shang_body.global_position
	var xuan_home: Vector2 = xuan_body.global_position
	var behind: Vector2 = map.resolve_spawn_marker(BEHIND).global_position
	_tell(map, shang, [{"emote": "走", "do": [{"act": "walk", "to": String(BEHIND)}, {"who": String(XUAN), "act": "walk", "to": String(SOUTH_DOOR), "stay": true}, {"who": String(XUAN), "act": "kneel"}]}])
	stage.advance(60.0)
	var xuan_at: Vector2 = xuan_body.global_position
	box.advance()
	_check(map.scene_running() and shang_body.global_position.distance_to(behind) < 1.0, "the line read, the scene not yet over: they stand where they walked")
	# The scene ends by itself once nothing of it is told or under way (the world runs again).
	for _i: int in 30:
		await tree.process_frame
		if not map.scene_running():
			break
	_check(not map.scene_running() and not session.scene_held(), "the scene over")
	_check(map.npc_life.npc_walker().is_walking(shang.character_id) or shang_body.global_position.distance_to(shang_home) < 2.0, "商玦 walks back (not put back: the scene ended as it should)")
	_check(not map.npc_life.npc_walker().is_walking(xuan.character_id), "玄冥子, told to stay, does not")
	for _i: int in 600:
		await tree.process_frame
		if not map.npc_life.npc_walker().is_walking(shang.character_id):
			break
	_check(shang_body.global_position.distance_to(shang_home) < 2.0, "商玦 where he stood: %s" % shang_body.global_position)
	_check(xuan_body.global_position.distance_to(xuan_at) < 1.0 and xuan_at.distance_to(xuan_home) > 40.0, "玄冥子 where he was told to stay: %s" % xuan_body.global_position)
	_check(stage.pose(xuan.character_id).is_empty() and not stage.shows(), "nobody kneels on after the scene")
	xuan_body.global_position = xuan_home
	await _frames(tree, 2)


# --- the camera ---


func _check_shots(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var shots: Dictionary = SceneStage.part("shots")
	var wait: int = int(float(shots["seconds"]) * 60.0) + 12
	var rest: float = view.zoom()
	_check(is_equal_approx(rest, view.rest_zoom), "before: the map's own framing: %s" % rest)
	_tell(map, shang, [
		{"say": "一"},
		{"say": "二", "shot": "near"},
		{"say": "三", "shot": {"two": String(XUAN)}},
		{"say": "四", "shot": {"look": String(NORTH_DOOR)}},
		{"say": "五", "shot": "wide"},
		{"say": "六"},
	])
	await _frames(tree, wait)
	_check(stage.shot_frame().is_empty() and not stage.shot_anchor().is_finite() and map.view_anchor().is_equal_approx(shang_body.global_position) and is_equal_approx(view.zoom(), rest), "no shot: the camera on who speaks, as before")
	_check(not is_instance_valid(view.staging_show) or is_zero_approx(view.staging_show.light_energy()), "and no light of the scene's")
	box.advance()
	await _frames(tree, wait)
	_check(stage.shot_frame() == &"near" and map.view_anchor().is_equal_approx(shang_body.global_position), "near: still on who speaks")
	_check(is_equal_approx(view.zoom(), minf(rest, float(shots["near"]))) and view.zoom() < rest, "pushed in: %s" % view.zoom())
	_check(view.staging_show.light_energy() > 0.0 or not GraphicsQuality.stage_lights(), "a soft light over them: %s" % view.staging_show.light_energy())
	box.advance()
	await _frames(tree, wait)
	var middle: Vector2 = (shang_body.global_position + xuan_body.global_position) / 2.0
	_check(stage.shot_frame() == &"two" and stage.shot_points().size() == 2 and map.view_anchor().is_equal_approx(middle), "two: the camera between the two: %s" % map.view_anchor())
	_check(view.zoom() >= float(shots["two_min"]) and view.zoom() < rest, "framed to hold both: %s" % view.zoom())
	box.advance()
	await _frames(tree, wait)
	var door: Vector2 = map.door(NORTH_DOOR).wall_shape().global_position
	_check(stage.shot_frame() == &"look" and map.view_anchor().is_equal_approx(door), "look: the camera on the 黑门: %s" % map.view_anchor())
	_check(is_equal_approx(view.zoom(), minf(rest, float(shots["look"]))), "at its own push-in: %s" % view.zoom())
	box.advance()
	await _frames(tree, wait)
	_check(stage.shot_frame() == &"wide" and map.view_anchor().is_equal_approx(map.physical_zone(ALTAR).global_rect().get_center()), "wide: over the room's middle")
	_check(is_equal_approx(view.zoom(), maxf(rest, float(shots["wide"]))) and (is_zero_approx(view.staging_show.light_energy()) or not GraphicsQuality.stage_lights()), "the map's own framing, the light off: %s" % view.zoom())
	box.advance()
	await _frames(tree, wait)
	_check(stage.shot_frame().is_empty() and is_equal_approx(view.zoom(), rest) and map.view_anchor().is_equal_approx(shang_body.global_position), "a line without a shot: as before again")
	box.advance()
	_end(map, box)
	# A fight has the camera (its stage is up): a shot neither pushes in nor gives anything back.
	view.staged = true
	view.set_zoom(0.8)
	_tell(map, shang, [{"say": "一", "shot": "near"}, {"say": "二"}])
	await _frames(tree, wait)
	_check(is_equal_approx(view.zoom(), 0.8), "the fight's camera is left alone: %s" % view.zoom())
	box.advance()
	await _frames(tree, wait)
	_check(is_equal_approx(view.zoom(), 0.8), "and nothing is given back that was not taken: %s" % view.zoom())
	box.advance()
	_end(map, box)
	view.staged = false
	view.set_zoom(view.rest_zoom)
	# A shot that cuts is there at once.
	shots["move"] = "cut"
	_tell(map, shang, [{"say": "一", "shot": {"look": String(SOUTH_DOOR)}}])
	await _frames(tree, 3)
	var south: Vector3 = VoxelMapGeometry.point(map.door(SOUTH_DOOR).wall_shape().global_position, 0.7)
	_check(view.looked_at().distance_to(south) < 0.05 and is_equal_approx(view.zoom(), minf(rest, float(shots["look"]))), "cut: on the door within a frame or two: %s" % view.looked_at().distance_to(south))
	shots["move"] = "pan"
	box.advance()
	_end(map, box)
	await _frames(tree, wait)
	_check(is_equal_approx(view.zoom(), rest), "over: the camera its own again")


## What the view makes of it: the figure's pose, the thing in the air, the start.
func _check_figures(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var figure: Person = view.actors[xuan.character_id].get_child(0) as Person
	var giver: Person = view.actors[shang.character_id].get_child(0) as Person
	_tell(map, xuan, [{"say": "一", "do": "kneel"}, {"say": "二", "do": "draw"}, {"say": "三", "do": ["sheathe", "rise", "startle"]}, {"say": "四", "do": {"act": "shiver", "hold": true}}, {"say": "五", "do": "fall"}])
	await _frames(tree, int(SceneStage.seconds(&"kneel") * 60.0) + 6)
	_check(figure.staged == "kneel" and is_equal_approx(figure.staged_amount, 1.0), "the figure kneels: %s %s" % [figure.staged, figure.staged_amount])
	_check(figure.legs[0].rotation.x > 1.0 and figure.torso.position.y < -0.2, "its legs behind it, its body down: %s %s" % [figure.legs[0].rotation.x, figure.torso.position.y])
	box.advance()
	await _frames(tree, 4)
	_check(figure.fighting and figure.staged.is_empty(), "draw: the figure on guard")
	box.advance()
	await _frames(tree, 4)
	_check(not figure.fighting and int(view.staging_show.begun.get("hop", 0)) == 1, "sheathe: at ease again; the start shown once")
	box.advance()
	await _frames(tree, 4)
	_check(figure.staged_shiver > 0.0, "the figure trembles")
	box.advance()
	await _frames(tree, int(SceneStage.seconds(&"fall") * 60.0) + 6)
	_check(is_zero_approx(figure.staged_shiver) and figure.limp > 0.9, "fall: the figure flat on its back: %s" % figure.limp)
	box.advance()
	_end(map, box)
	await _frames(tree, 30)
	_check(is_zero_approx(figure.limp) and figure.staged.is_empty() and is_zero_approx(figure.staged_amount), "over: the figure stands as ever")
	_tell(map, shang, [{"emote": "抛", "do": {"act": "toss", "item": String(KEY), "to": String(XUAN)}}])
	var seen: int = 0
	var highest: float = -INF
	var hands: float = maxf(giver.hand(0).y, figure.hand(1).y)
	for _i: int in int(SceneStage.seconds(&"toss") * 60.0) + 6:
		await tree.process_frame
		for child: Node in view.staging_show.get_children():
			if child.name.begins_with("Flying"):
				seen += 1
				highest = maxf(highest, (child as Node3D).global_position.y)
	_check(seen > 5 and highest > hands + 0.5, "the key is drawn in the air, arcing over their hands: %d frames, %.2f over %.2f" % [seen, highest, hands])
	_check(not view.staging_show.get_children().any(func(child: Node) -> bool: return child.name.begins_with("Flying") and not child.is_queued_for_deletion()), "and gone when caught")
	box.advance()
	_end(map, box)
	await _frames(tree, 2)


# --- a 主线场面 named by a step ---


func _check_fx(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	await _frames(tree, 20)
	var story: VoxelStoryFx = view.story_node()
	_check(story != null and story.played.count("shade_called") == 0, "the shade's scene not played yet")
	_tell(map, shang, [{"say": "一"}, {"summon": "niling.altar.shade", "do": "emerge"}, {"line": "二", "fx": "shade_called"}, {"say": "三"}])
	var shade: NpcRuntimeState = _npc(map, SHADE)
	_check(shade != null and shade.exists_in_map and stage.unseen(shade.character_id), "summoned by the rule at once; not seen until its line")
	await _frames(tree, 40)
	_check(story.played.count("shade_called") == 0 and stage.fx_claimed().has("shade_called"), "its trigger holds (the shade stands) and stays quiet: the step will play it")
	_check(view.actors.has(shade.character_id) and not view.actors[shade.character_id].visible, "the figure unseen")
	box.advance()
	_check(not stage.unseen(shade.character_id) and stage.emerged(shade.character_id) < 0.1, "its line: it begins to rise")
	await _frames(tree, 6)
	var rising: Node3D = view.actors[shade.character_id].get_child(0) as Node3D
	_check(story.played.count("shade_called") == 1 and view.actors[shade.character_id].visible and rising.position.y < -0.5, "played with its line, the figure coming up from under the ground: %s" % rising.position.y)
	await _frames(tree, int(SceneStage.seconds(&"emerge") * 60.0) + 40)
	_check(story.played.count("shade_called") == 1 and is_zero_approx(rising.position.y) and is_equal_approx(stage.emerged(shade.character_id), 1.0), "once; the figure stands on the ground")
	box.advance()
	box.advance()
	_end(map, box)
	await _frames(tree, 40)
	_check(story.played.count("shade_called") == 1 and stage.fx_claimed().is_empty(), "the scene over: still once")
	# Its own trigger alone still plays it (no step names it): the shade gone and come again.
	map.npcs.vanish(shade)
	await _frames(tree, 20)
	story.reset()
	await _frames(tree, 20)
	_check(not map.summon(&"niling.altar.shade").is_empty(), "the shade made anew, by no scene")
	await _frames(tree, 30)
	_check(story.played.count("shade_called") == 2, "its trigger plays it as before: %s" % [story.played])
	map.npcs.vanish(_npc(map, SHADE))
	await _frames(tree, 20)
	# Claimed by a scene that is cut before its step: its own trigger plays it after all.
	story.reset()
	await _frames(tree, 20)
	_tell(map, shang, [{"say": "一"}, {"summon": "niling.altar.shade", "do": "emerge"}, {"line": "二", "fx": "shade_called"}])
	await _frames(tree, 30)
	_check(story.played.count("shade_called") == 2, "claimed: quiet while the first line is read")
	box.close()
	_end(map, box)
	await _frames(tree, 30)
	_check(story.played.count("shade_called") == 3, "the scene cut before its step: the trigger plays it: %s" % [story.played])
	map.npcs.vanish(_npc(map, SHADE))
	await _frames(tree, 20)
	# Under a shot the 主线场面's own push-in is left out, and nothing zooms out over the shot.
	story.reset()
	await _frames(tree, 20)
	var near: float = minf(view.rest_zoom, float(SceneStage.part("shots")["near"]))
	_tell(map, shang, [{"say": "一", "shot": "near", "fx": "shade_called"}, {"say": "二"}])
	await _frames(tree, 60)
	_check(story.played.count("shade_called") == 4 and is_equal_approx(view.zoom(), near), "played under a near shot: the shot's framing stands: %s" % view.zoom())
	await _frames(tree, 200)
	_check(is_equal_approx(view.zoom(), near), "and still stands when the 主线场面 is over: %s" % view.zoom())
	box.advance()
	await _frames(tree, 60)
	_check(is_equal_approx(view.zoom(), view.rest_zoom), "the next line, without a shot: the map's own framing")
	box.advance()
	_end(map, box)
	await _frames(tree, 4)


# --- who comes and who goes ---


func _check_come_and_go(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var south: Vector2 = map.door(SOUTH_DOOR).wall_shape().global_position
	# comes with enter: the rule puts him beside the player; he is shown walking in from the door.
	_tell(map, shang, [{"comes": String(XUAN), "from": String(ALTAR), "do": {"act": "enter", "from": String(SOUTH_DOOR)}}, {"say": "来"}])
	_check(xuan_body.global_position.distance_to(south) < 70.0 or stage.left_seconds() > 0.0, "he starts at the door: %s" % xuan_body.global_position)
	_check(stage.left_seconds() > 0.2, "and walks in: %.1f s" % stage.left_seconds())
	stage.advance(60.0)
	var beside: float = xuan_body.global_position.distance_to(map.player_body.global_position)
	_check(beside < 110.0 and MapPlacementValidator.is_valid_character_position(map, ALTAR, xuan_body.global_position), "to the player's side, where the rule put him: %s px" % beside)
	box.advance()
	_end(map, box)
	map.npc_life.npc_walker().finish_all()
	# leave with exit: he stays until his way out has been shown, then is gone for good.
	_tell(map, xuan, [{"say": "走了"}, {"leave": true, "do": {"act": "exit", "by": String(SOUTH_DOOR)}}])
	_check(xuan.exists_in_map and not xuan.has_flag(NpcDefinition.FLAG_GONE), "he stands there while his last line is read")
	box.advance()
	_check(stage.between() and xuan.exists_in_map and stage.left_seconds() > 0.2, "read out: he walks to the door, the world held")
	await _frames(tree, 6)
	_check(xuan.exists_in_map and view.actors[xuan.character_id].visible, "on his way, still seen")
	stage.advance(60.0)
	_check(not xuan.exists_in_map and xuan.has_flag(NpcDefinition.FLAG_GONE) and bool(xuan_body.get_meta(WorldMapNpcs.LEFT, false)), "at the door he is gone for good")
	_check(not stage.between() and not session.presentation_frozen(), "and the world runs again")
	await _frames(tree, 4)
	_check(not view.actors.has(xuan.character_id) or not view.actors[xuan.character_id].visible, "his figure is simply gone (it does not fall as one killed)")
	_end(map, box)
	# summon with emerge, leave with dissolve.
	_tell(map, shang, [{"summon": "niling.altar.shade", "do": "emerge"}, {"line": "现"}, {"leave": String(SHADE), "do": "dissolve"}, {"line": "散"}])
	var shade: NpcRuntimeState = _npc(map, SHADE)
	_check(shade != null and not stage.unseen(shade.character_id) and stage.emerged(shade.character_id) < 0.05, "a summon with no line before it rises at once")
	stage.advance(SceneStage.seconds(&"emerge") * 0.5)
	_check(stage.emerged(shade.character_id) > 0.3 and stage.emerged(shade.character_id) < 0.7, "half-way up: %s" % stage.emerged(shade.character_id))
	stage.advance(SceneStage.seconds(&"emerge"))
	_check(is_equal_approx(stage.emerged(shade.character_id), 1.0) and shade.exists_in_map and is_zero_approx(stage.dissolved(shade.character_id)), "up; its dissolve waits for the line before it")
	box.advance()
	_check(shade.exists_in_map and stage.left_seconds() > 0.0, "the line read: it thins away, still there by the rules")
	stage.advance(SceneStage.seconds(&"dissolve") * 0.5)
	_check(stage.dissolved(shade.character_id) > 0.3 and stage.dissolved(shade.character_id) < 0.7, "half gone: %s" % stage.dissolved(shade.character_id))
	await _frames(tree, 3)
	var thinning: Node3D = view.actors[shade.character_id].get_child(0) as Node3D
	_check(thinning.scale.y < 0.75 and int(view.staging_show.begun.get("puff", 0)) >= 1, "the figure sinks, its smoke rising: %s" % thinning.scale.y)
	stage.advance(SceneStage.seconds(&"dissolve"))
	_check(not shade.exists_in_map and shade.has_flag(NpcDefinition.FLAG_GONE), "gone when the last of it is")
	box.advance()
	_end(map, box)
	await _frames(tree, 4)


# --- cut short ---


func _check_cut_short(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var home: Vector2 = shang_body.global_position
	var facing: Vector2 = shang_body.facing
	var me: StringName = session.player_runtime().character_id
	# The box shut unread (as a fight or a fall shuts it): what was under way is at its end, what
	# had not begun is not shown, who was to leave has left, who was summoned is seen.
	_tell(map, shang, [
		{"emote": "走", "do": [{"act": "walk", "to": String(BEHIND)}, "kneel", {"who": "player", "act": "kneel"}]},
		{"summon": "niling.altar.hell_runners", "do": "emerge"},
		{"say": "二", "shot": "near", "fx": "shade_called"},
		{"leave": true, "do": {"act": "exit", "by": String(NORTH_DOOR)}},
	])
	stage.advance(0.4)
	var runners: Array[NpcRuntimeState] = _npcs(map, RUNNER)
	_check(runners.size() == 2 and stage.unseen(runners[0].character_id) and stage.unseen(runners[1].character_id), "two 鬼卒 summoned, not seen yet")
	_check(shang.exists_in_map and shang_body.global_position.distance_to(home) > 20.0 and stage.pose(me) == WorldMapStaging.POSE_KNEEL, "商玦 half-way, the player going down on their knees")
	box.close()
	_check(not stage.busy() and not stage.between() and not session.presentation_frozen(), "shut unread: nothing told, nothing under way, nothing held")
	_check(not shang.exists_in_map and shang.has_flag(NpcDefinition.FLAG_GONE), "商玦, who was to leave, has left")
	_check(not stage.unseen(runners[0].character_id) and not stage.unseen(runners[1].character_id) and runners[0].exists_in_map, "the 鬼卒 are seen: they are there")
	_check(stage.shot_frame().is_empty() and stage.take_fx().is_empty(), "no shot left, no 主线场面 owed")
	map.npc_life.end_scene()
	_check(stage.pose(me).is_empty() and not stage.shows(), "the scene ended: the player's figure up again")
	await _frames(tree, 3)
	_check(view.actors[runners[0].character_id].visible, "their figures show")
	# One who walked and is still there is put back at once when the scene is cut.
	for runner: NpcRuntimeState in runners:
		map.npcs.vanish(runner)
	var second: WorldSessionController = session
	var other: NpcRuntimeState = _npc(map, RUNNER)
	_check(other == null, "the 鬼卒 sent away (TEST-ONLY) before they fall on the player")
	await _frames(tree, 2)
	second.free()
	await tree.process_frame
	# Leaving the map (and a fight) on a fresh visit: who walked is back at once.
	var fresh: WorldSessionController = await _altar(tree, true)
	if fresh == null:
		return
	map = fresh.active_map() as WorldMapController
	stage = map.staging
	box = fresh.shared_ui().dialogue_box
	shang = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	shang_body = map.runtime_body_for_character(shang.character_id)
	home = shang_body.global_position
	facing = shang_body.facing
	# Cut as a fight or a fall cuts it (settle()), the scene itself not over: everyone is where
	# they belong at once — put back, standing, solid, looking where they looked.
	_tell(map, shang, [{"emote": "走", "do": [{"act": "walk", "to": String(BEHIND)}, {"who": String(XUAN), "act": "kneel"}, {"who": "player", "act": "step_back"}]}, {"say": "二", "shot": "near"}])
	stage.advance(1.0)
	await _physics(tree, 2)
	_check(shang_body.global_position.distance_to(home) > 60.0 and shang_body.global_position.distance_to(map.resolve_spawn_marker(BEHIND).global_position) > 60.0, "under way: 商玦 half-way")
	stage.settle()
	_check(shang_body.global_position.is_equal_approx(home) and stage.pose(xuan.character_id).is_empty() and not stage.shows() and stage.shot_frame().is_empty(), "cut: 商玦 back at his spot at once, nobody posed, no shot")
	_check(not stage.busy() and not stage.between() and not fresh.presentation_frozen() or box.is_open(), "nothing under way, nothing held by the staging")
	await _physics(tree, 3)
	_check(shang_body.facing.is_equal_approx(facing) and not shang_body.facing_held and not map.player_body.facing_held, "looking where he looked, after his body's own steps: %s" % shang_body.facing)
	_check(not (shang_body.get_node("CollisionShape2D") as CollisionShape2D).disabled, "solid again")
	_end(map, box)
	await _frames(tree, 2)
	facing = shang_body.facing
	_tell(map, shang, [{"emote": "走", "do": [{"act": "walk", "to": String(BEHIND)}, {"who": String(XUAN), "act": "kneel"}]}, {"by": String(XUAN)}, {"leave": true, "do": {"act": "exit", "by": String(SOUTH_DOOR)}}])
	stage.advance(1.0)
	_check(shang_body.global_position.distance_to(home) > 60.0 and xuan.exists_in_map, "under way again: 商玦 walking, 玄冥子 to leave after the line")
	var rear: WorldMapController = map
	_check(MapPlaces.enter(fresh, &"niling.front", &"niling.front.altar_return") != null and fresh.active_map() != rear, "the player off the map (TEST-ONLY: put in the 前殿)")
	_check(not rear.scene_running() and not stage.busy() and not stage.shows() and not stage.between(), "the scene did not follow them: over, nothing held by it")
	_check(shang_body.global_position.is_equal_approx(home) and shang_body.facing.is_equal_approx(facing), "商玦 put back where he stood, looking where he looked: %s" % shang_body.global_position)
	_check(not rear.npc_life.npc_walker().is_walking(shang.character_id), "put back, not walking (nobody watches)")
	_check(not xuan.exists_in_map and xuan.has_flag(NpcDefinition.FLAG_GONE), "玄冥子 has left, as his step said")
	# The 前殿's view is built before the session goes (its build works on a thread).
	var hall_view: WorldVoxelView = (fresh.active_map() as WorldMapController).get_node_or_null("MapView") as WorldVoxelView
	for _i: int in 600:
		await tree.process_frame
		if hall_view == null or hall_view.actors.has(fresh.player_runtime().character_id):
			break
	await _frames(tree, 4)
	fresh.free()
	await tree.process_frame


## A staged act whose lines are not read in the box (they are a `kill`'s opening lines): no page is
## waited for that will never show; the scene is over at once and nothing of it is left.
func _check_fight(tree: SceneTree) -> void:
	var session: WorldSessionController = await _altar(tree, true)
	if session == null:
		return
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var home: Vector2 = shang_body.global_position
	_tell(map, xuan, [
		{"say": "一", "do": [{"who": String(SHANG), "act": "walk", "to": String(BEHIND)}, "draw"]},
		{"say": "二", "do": {"act": "face", "toward": "player"}, "shot": "near"},
		{"kill": true},
	])
	_check(not box.is_open() and not stage.busy(), "its lines open the fight, they are no pages of the box: no page is waited for")
	# (玄冥子 fights nobody in the 后殿: the lines go to 消息 and no fight begins. The 鬼卒's fight at
	# the end of 唤首 is the cut by a fight, below.)
	_check(xuan != null and session.shared_ui().log_lines().any(func(line: String) -> bool: return line.contains("一")), "the lines are in 消息")
	await _frames(tree, 3)
	_check(not stage.busy() and not stage.between() and not stage.shows() and stage.shot_frame().is_empty(), "nothing of the scene is left")
	_check(not map.scene_running() and not session.scene_held(), "the scene is over: the player is not held for a page that never shows")
	map.npc_life.npc_walker().finish_all()
	_check(shang_body.global_position.distance_to(home) < 2.0, "商玦 back where he stood: %s" % shang_body.global_position)
	await _frames(tree, 4)
	session.free()
	await tree.process_frame


# --- 唤首, whole ---


## The scene as shipped, each line taken on by a press once its action has begun: what is shown
## at each beat, and the same people gone and come as the rules had it.
func _check_the_scene(tree: SceneTree) -> void:
	var session: WorldSessionController = await _altar(tree, false)
	if session == null:
		return
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var player: WorldCharacterBody2D = map.player_body
	var shade_spot: Vector2 = map.resolve_spawn_marker(&"niling.altar.shade.1").global_position
	var behind: Vector2 = map.resolve_spawn_marker(BEHIND).global_position
	var xuan_stood: Vector2 = xuan_body.global_position
	var story: VoxelStoryFx = null
	var lines: Array[String] = []
	var frames: Dictionary[int, StringName] = {}
	var seen: Dictionary[String, bool] = {}
	var seen_line: String = ""
	var between: int = 0
	var fought: bool = false
	for _i: int in 60 * 240:
		await tree.process_frame
		if session.combat_encounter_coordinator().has_active_encounter():
			fought = true
			break
		if stage.between():
			between += 1
			if xuan.exists_in_map and lines.size() == 13:
				seen["xuan walks out"] = seen.get("xuan walks out", false) or xuan_body.global_position.distance_to(xuan_stood) > 20.0
			continue
		if not box.is_open():
			continue
		var line: String = box.line()
		if line != seen_line:
			seen_line = line
			lines.append(line)
			frames[lines.size()] = stage.shot_frame()
			var shade: NpcRuntimeState = _npc(map, SHADE)
			match lines.size():
				3:
					seen["xuan turns"] = xuan_body.facing.is_equal_approx(_toward(xuan_body.global_position, player.global_position))
				4:
					seen["xuan reports"] = xuan_body.facing.is_equal_approx(_toward(xuan_body.global_position, shang_body.global_position)) and stage.shot_points().size() == 2
				5:
					seen["shade waits"] = shade != null and stage.unseen(shade.character_id)
				6:
					seen["shade rises"] = shade != null and not stage.unseen(shade.character_id) and stage.emerged(shade.character_id) < 0.2 and map.view_anchor().is_equal_approx(shade_spot)
					seen["shade reaches"] = shade != null and stage.pose(shade.character_id) == WorldMapStaging.POSE_REACH
				7:
					seen["shade stops"] = shade != null and stage.pose(shade.character_id).is_empty() and stage.shivers(session.player_runtime().character_id)
				9:
					seen["toss begins"] = stage.pose(shang.character_id) == WorldMapStaging.POSE_GIVE and stage.left_seconds() > SceneStage.seconds(&"toss") - 0.1
				11:
					seen["shade thins"] = shade != null and shade.exists_in_map and stage.dissolved(shade.character_id) < 0.2 and stage.left_seconds() > 0.0
				13:
					seen["shade gone, xuan stays"] = shade == null and xuan.exists_in_map
				14:
					seen["xuan gone"] = not xuan.exists_in_map and xuan.has_flag(NpcDefinition.FLAG_GONE)
					seen["shang sets out"] = stage.left_seconds() > 1.0
				15:
					seen["shang at the door"] = shang_body.global_position.distance_to(behind) < 1.0 and shang.exists_in_map
				16:
					var runners: Array[NpcRuntimeState] = _npcs(map, RUNNER)
					seen["runners rise"] = runners.size() == 2 and stage.emerged(runners[0].character_id) < 0.2
					seen["shang walks out"] = shang.exists_in_map and stage.left_seconds() > 0.0 and stage.directed(shang.character_id)
			continue
		if lines.size() == 9 and not stage.flights().is_empty():
			seen["key flies"] = stage.flights()[0][2] == KEY and stage.flights()[0][1] == xuan.character_id
		if lines.size() == 6 and is_instance_valid(view.story_fx) and view.story_fx.played.has("shade_called"):
			story = view.story_fx
		# Each line taken on once what it shows has had a moment (a toss, until the key is caught).
		var hold: bool = (lines.size() == 9 and stage.left_seconds() > 0.1) or (lines.size() == 6 and story == null)
		if not hold and not box.typing():
			_press(hud)
	_check(lines.size() == 16, "sixteen lines, as before: %d" % lines.size())
	_check(fought, "the 鬼卒 fall on the player when it is over")
	for beat: String in ["xuan turns", "xuan reports", "shade waits", "shade rises", "shade reaches", "shade stops", "toss begins", "key flies", "shade thins", "shade gone, xuan stays", "xuan gone", "shang sets out", "xuan walks out", "shang at the door", "runners rise", "shang walks out"]:
		_check(seen.get(beat, false), "the beat is shown: %s" % beat)
	_check(between > 3, "玄冥子's way out is walked between two lines, the world held: %d frames" % between)
	_check(frames.get(1, &"") == &"wide" and frames.get(2, &"") == &"near" and frames.get(4, &"") == &"two" and frames.get(6, &"") == &"look" and frames.get(9, &"") == &"two" and frames.get(16, &"") == &"look", "the shots: %s" % [frames])
	_check(story != null and story.played.count("shade_called") == 1, "the shade's 主线场面 played once, with its line")
	_check(session.player_runtime().state.marks.has(SCENE_MARK), "the scene's mark")
	_check(not shang.exists_in_map and shang.has_flag(NpcDefinition.FLAG_GONE) and not xuan.exists_in_map and _npc(map, SHADE) == null and _npcs(map, RUNNER).size() == 2, "商玦, 玄冥子 and the shade gone; two 鬼卒 there")
	await _frames(tree, 4)
	_check(not map.scene_running() and not session.scene_held() and not stage.shows(), "the scene is over when the fight has begun")
	_check(not stage.busy() and not stage.between() and stage.shot_frame().is_empty(), "the staging is done: %s %s" % [stage.busy(), stage.between()])
	for runner: NpcRuntimeState in _npcs(map, RUNNER):
		_check(view.actors.has(runner.character_id) and not stage.unseen(runner.character_id), "a 鬼卒 is seen in the fight")
	session.free()
	await tree.process_frame


# --- the feel off ---


## The suites' feel: nothing is staged, a leave leaves at once, a comer is put beside the player.
func _check_feel_off(tree: SceneTree) -> void:
	_check(not SceneStage.on(), "the feel off")
	var session: WorldSessionController = await _altar(tree, true)
	if session == null:
		return
	var map: WorldMapController = session.active_map() as WorldMapController
	var stage: WorldMapStaging = map.staging
	var box: WorldDialogueBox = session.shared_ui().dialogue_box
	var view: WorldVoxelView = map.get_node("MapView") as WorldVoxelView
	var shang: NpcRuntimeState = _npc(map, SHANG)
	var xuan: NpcRuntimeState = _npc(map, XUAN)
	var shang_body: WorldCharacterBody2D = map.runtime_body_for_character(shang.character_id)
	var xuan_body: WorldCharacterBody2D = map.runtime_body_for_character(xuan.character_id)
	var home: Vector2 = shang_body.global_position
	var facing: Vector2 = shang_body.facing
	_tell(map, shang, [
		{"say": "一", "do": [{"act": "walk", "to": String(BEHIND)}, "kneel", {"act": "face", "toward": "player"}], "shot": "near", "fx": "shade_called"},
		{"comes": String(XUAN), "from": String(ALTAR), "do": {"act": "enter", "from": String(SOUTH_DOOR)}},
		{"summon": "niling.altar.shade", "do": "emerge"},
		{"leave": true, "do": {"act": "exit", "by": String(SOUTH_DOOR)}},
	])
	_check(not stage.directs() and not stage.busy() and not stage.shows() and not box.is_open(), "nothing is staged, nothing read in a box")
	_check(shang_body.global_position.is_equal_approx(home) and shang_body.facing.is_equal_approx(facing) and stage.pose(shang.character_id).is_empty(), "商玦 neither walks nor kneels nor turns")
	_check(xuan_body.global_position.distance_to(map.player_body.global_position) < 110.0, "who comes is beside the player at once: %s" % xuan_body.global_position.distance_to(map.player_body.global_position))
	var shade: NpcRuntimeState = _npc(map, SHADE)
	_check(shade != null and shade.exists_in_map and not stage.unseen(shade.character_id), "who is summoned is there, seen")
	_check(not xuan.exists_in_map and xuan.has_flag(NpcDefinition.FLAG_GONE), "who leaves is gone at once")
	_check(stage.shot_frame().is_empty() and stage.fx_claimed().is_empty() and not map.view_anchor().is_equal_approx(Vector2.ZERO), "no shot, no 主线场面 claimed")
	await _frames(tree, 6)
	_check(not is_instance_valid(view.staging_show), "the view makes nothing for it")
	session.free()
	await tree.process_frame


# --- helpers ---


## A session in the 后殿 as chapter 3 comes to it (the story written by the fixture, the player put
## at the 北门's arrival point), its view built. `stopped`: the 唤首 scene is stopped before its
## first line, 商玦 and 玄冥子 left standing for the suite's own acts.
func _altar(tree: SceneTree, stopped: bool) -> WorldSessionController:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	StoryFixtures.chapter3_dungeon_done(session)
	session.record_journal()
	var map: WorldMapController = MapPlaces.enter(session, ALTAR, &"niling.altar.front_entry")
	_check(map != null and map.map_id() == &"niling.rear", "in the 后殿")
	if map == null:
		session.free()
		return null
	if stopped:
		for _i: int in 30:
			await tree.process_frame
			if map.scene_running():
				break
		_check(map.scene_running() and not session.shared_ui().dialogue_box.is_open(), "the 唤首 scene began; stopped before its first line (TEST-ONLY)")
		map.npc_life.npc_ambience().cancel_call(_npc(map, SHANG).character_id)
		map.npc_life.end_scene()
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	var me: StringName = session.player_runtime().character_id
	for _i: int in 600:
		if view != null and view.actors.has(me) and view.actors.has(_npc(map, SHANG).character_id) and view.actors.has(_npc(map, XUAN).character_id):
			break
		await tree.process_frame
	_check(view != null and view.actors.has(me) and _npc(map, SHANG) != null and _npc(map, XUAN) != null, "its view built, 商玦 and 玄冥子 standing")
	return session


## `npc` tells `steps` as a scene's call does: the scene held, the lines read in the box.
func _tell(map: WorldMapController, npc: NpcRuntimeState, steps: Array) -> void:
	var errors: Array[String] = []
	var act: ScriptedAct = ScriptedAct.from_record(ContentRecordReader.new({"steps": steps}, "t", errors))
	_check_quiet(errors.is_empty(), "the suite's act reads: %s" % [errors])
	var life: WorldMapNpcLife = map.npc_life
	if not life.scene_running():
		life._begin_scene(npc)
	life.teller = npc.character_id
	map.acts.run(act, npc, life.npc_ambience().random().legacy_random)
	life.teller = &""


## The suite's scene over: the box shut if it still shows, the scene ended as the map ends it.
func _end(map: WorldMapController, box: WorldDialogueBox) -> void:
	if box.is_open():
		box.close()
	map.npc_life.end_scene()


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	return map.npcs.first_npc_in_zone(definition_id, ALTAR, true)


func _npcs(map: WorldMapController, definition_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			found.append(npc)
	return found


## The way a body at `from` faces when it looks at `to` (one of eight).
func _toward(from: Vector2, to: Vector2) -> Vector2:
	return Vector2.from_angle(snappedf((to - from).angle(), PI / 4.0))


func _press(hud: SharedGameplayUI) -> void:
	var key := InputEventAction.new()
	key.action = &"interact"
	key.pressed = true
	hud._unhandled_input(key)


func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in count:
		await tree.process_frame


func _physics(tree: SceneTree, count: int) -> void:
	for _i: int in count:
		await tree.physics_frame


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)


## A check made many times over (once a frame): counted once, failing once.
var _quiet: Dictionary[String, bool] = {}
func _check_quiet(condition: bool, label: String) -> void:
	if not _quiet.has(label):
		_quiet[label] = true
		assertions += 1
	if not condition and not failures.has(label):
		failures.append(label)
