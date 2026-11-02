extends RefCounted

## The dialogue box (DECISIONS「对话框」): 打听 and what is told are read in it, line by line,
## the world holding still; chat stays in the bubbles; a fight shuts it and 消息 keeps all.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
var assertions: int = 0
var failures: Array[String] = []


## Two told sequences at once, whatever the map says.
class TwoTellers extends SharedUiWaits:
	var hurried: Array[StringName] = []

	func _collect() -> Array[WorldWait]:
		var waits: Array[WorldWait] = []
		for id: StringName in [&"first", &"second"]:
			var wait := WorldWait.new("", 0.0, func() -> bool:
				hurried.append(id)
				return true)
			wait.teller = id
			waits.append(wait)
		return waits


func run_all(tree: SceneTree) -> Dictionary:
	_check_own_wait()
	TestFeel.use()
	await _check_scene(tree)
	await _check_ask(tree)
	await _check_feel_off(tree)
	TestFeel.restore()
	return {"assertions": assertions, "failures": failures}


## Read out, a line brings on its own teller's next: not the first sequence on the card.
func _check_own_wait() -> void:
	var waits := TwoTellers.new(null)
	_check(waits.hurry_teller(&"second") and waits.hurried == [&"second"], "the second teller's sequence, though the first is listed first: %s" % [waits.hurried])
	_check(not waits.hurry_teller(&"") and not waits.hurry_teller(&"nobody") and waits.hurried.size() == 1, "nobody's line brings on nothing")


## 寻剑令's scene at 黄石隘口: each line waits in the box, the world stands still while it is
## read, E goes on and the next line comes at once; the scene ends after the last.
func _check_scene(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var map: WorldMapController = await _begin_scene(tree, session)
	_check(map != null and map.map_id() == &"canyon.pass", "on the pass")
	if map == null:
		session.free()
		return
	for _i: int in 900:
		await tree.process_frame
		if box.is_open():
			break
	_check(map.scene_running(), "the scene runs")
	_check(box.is_open() and box.speaker().is_empty(), "what happens is told by nobody: no name over 一名武官捧出石匣: %s" % box.speaker())
	_check(hud._presentation_layout.toasts.lift > 0.0, "the toasts stand on the box")
	var focus: StringName = map.npc_life.scene_focus_id
	_check(hud.speech_bubbles.text_of(focus).is_empty(), "no bubble says it too")
	_check(session.presentation_frozen() and map.player_body.walk_paused, "the world holds still while it is read")
	var first: String = box.line()
	_check(not first.contains("道："), "without who says it: %s" % first)
	_check(hud.log_lines().any(func(line: String) -> bool: return line.contains(first)), "消息 has it")
	var minutes: float = session.day_clock().day_minutes()
	await tree.create_timer(0.4).timeout
	_check(box.line() == first and is_equal_approx(session.day_clock().day_minutes(), minutes), "it waits for the player")
	var read: int = 1
	var spoken: Array[String] = []
	for _i: int in 200:
		if not box.is_open() and not map.scene_running():
			break
		if box.is_open():
			var at: String = box.line()
			_press(hud)
			_press(hud)
			await _frames(tree, 3)
			if box.is_open() and box.line() != at:
				read += 1
				spoken.append(box.speaker())
		else:
			await tree.process_frame
	_check(read >= 5, "line after line, without waiting out the seconds: %d" % read)
	_check(spoken.has(tr("白道长")) and spoken.has(tr("冯策")), "each line under who says it: %s" % [spoken])
	_check(not map.scene_running() and not session.scene_held() and not session.presentation_frozen(), "over, and the world runs again")
	_check(hud._presentation_layout.toasts.lift == 0.0, "the toasts back at the foot")
	session.free()
	await _frames(tree, 2)


## 打听 from the popup: the box takes over from it, topics under the text, the answer in
## place; 告辞 leaves it, the world running again.
func _check_ask(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = _askable(map)
	_check(npc != null, "someone to ask")
	if npc == null:
		session.free()
		return
	map.select_npc(npc.character_id)
	hud.open_ask()
	await _frames(tree, 2)
	_check(box.hosting() and box.speaker() == tr(npc.definition().display_name), "打听 opens in the box")
	_check(not hud.panel_open(), "not in the shared frame")
	var topics: Array[String] = hud.ask_topics_shown()
	_check(not topics.is_empty(), "the topics: %s" % [topics])
	_check(session.presentation_frozen(), "the world holds still")
	await tree.create_timer(0.3).timeout
	_check(map.selected_npc() == npc, "the box holds the selection while the HUD refreshes")
	var topic: Button = box.hosted().find_child("Topic", true, false) as Button
	topic.pressed.emit()
	# The answer typing out, the next press only finishes it: nothing is asked again.
	var asked: int = hud.log_lines().size()
	topic.pressed.emit()
	_check(hud.log_lines().size() == asked, "the press that finishes the typing asks nothing")
	await _frames(tree, 2)
	_check(box.hosting() and not box.line().is_empty() and box.line() != tr("你可以打听这些事情："), "the answer shows above the topics: %s" % box.line())
	_check(not box.line().contains("打听有关"), "from the answer, not ask.c's own line")
	var waited: float = session.day_clock().day_minutes()
	await _frames(tree, 3)
	_check(hud.ask_answer_text() != "" and is_equal_approx(session.day_clock().day_minutes(), waited), "the answer stays, time does not pass")
	box.answer_as_written(["你说道：必有妖孽"])
	_check(box.line() == "你说道：必有妖孽", "the player's own line is not taken for the speaker's")
	(box.hosted().find_child("Leave", true, false) as Button).pressed.emit()
	await _frames(tree, 2)
	_check(not box.is_open() and not session.presentation_frozen(), "告辞: back in the world")
	# Chat stays over the head; what is told is read; a fight shuts the box.
	var said: Array[ColoredLine] = [ColoredLine.new("%s说道：今天天气不错。" % npc.definition().display_name)]
	hud.npc_says(npc, said, ["%s说道：今天天气不错。" % npc.definition().display_name])
	_check(not box.is_open() and hud.speech_bubbles.text_of(npc.character_id) == "今天天气不错。", "chat: a bubble, no box")
	hud.speech_bubbles.forget(npc.character_id)
	map.npc_life.teller = npc.character_id
	hud.npc_says(npc, said, ["%s说道：今天天气不错。" % npc.definition().display_name, "%s说道：第二句。" % npc.definition().display_name])
	map.npc_life.teller = &""
	_check(box.is_open() and box.line() == "今天天气不错。" and box.pages_left() == 1, "a told line: a page each")
	_check(hud.speech_bubbles.text_of(npc.character_id).is_empty(), "told: no bubble")
	map.attack_selected()
	await _frames(tree, 3)
	_check(not box.is_open() and box.pages_left() == 0, "a fight shuts the box")
	session.free()
	await _frames(tree, 2)


## The suites' feel: no box, as before.
func _check_feel_off(tree: SceneTree) -> void:
	TestFeel.restore()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = _askable(map)
	if npc != null:
		map.select_npc(npc.character_id)
		hud.open_ask()
		await _frames(tree, 2)
		_check(hud.panel_open() and not hud.dialogue_box.is_open(), "the feel off: 打听 in the shared frame")
	session.free()
	await _frames(tree, 2)
	TestFeel.use()


## Up 寻剑令 as far as 黄石隘口, as sword_decree_test walks it, onto the pass.
func _begin_scene(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var state: CharacterState = session.player_runtime().state
	PlayerEssenceMagic.meet(state, _npc_of(session, &"snow.npc.waiter"), false)
	session.record_journal()
	var map: WorldMapController = session.active_map() as WorldMapController
	map.place_player(&"snow.inn.main_floor", MapPlaces.spot(map, &"snow.inn.main_floor", map.runtime_body_for_character(_npc_of(session, &"snow.npc.waiter").character_id).global_position))
	await _frames(tree, 3)
	map.select_npc(_npc_of(session, &"snow.npc.waiter").character_id)
	map.ask_selected("官爷")
	map = MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry")
	if map == null:
		return null
	await _frames(tree, 3)
	var feng: NpcRuntimeState = _npc_of(session, &"native.npc.feng_ce")
	map.place_player(&"snow.square", MapPlaces.spot(map, &"snow.square", map.runtime_body_for_character(feng.character_id).global_position))
	await _frames(tree, 3)
	map.select_npc(feng.character_id)
	map.ask_selected("寻剑")
	return MapPlaces.enter(session, &"canyon.canyon1", &"canyon.canyon1.chain_arrival")


func _npc_of(session: WorldSessionController, id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == id and npc.exists_in_map:
				return npc
	return null


func _askable(map: WorldMapController) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.exists_in_map and not npc.definition().talk().inquiry_topics().is_empty():
			return npc
	return null


func _press(hud: SharedGameplayUI) -> void:
	var key := InputEventAction.new()
	key.action = &"interact"
	key.pressed = true
	hud._unhandled_input(key)


func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in count:
		await tree.process_frame


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
