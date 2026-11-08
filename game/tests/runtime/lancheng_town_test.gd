extends RefCounted

## 第十章 B 白石街与风铃阁 (owner's plan build/plans/第十章_计划.md, 2026-11-07「接着做 B」: Q1–Q3 默认;
## DECISIONS「第十章 B」), from the eighth chapter's ledger with the ninth's marks (TEST-ONLY):
## - The trust table: each of the ten great bells in the 风铃阁 is two pieces in one box, the dark one `until`
##   and the bright one `present` the same marks, and the bell's landmark answers to exactly those marks.
## - 伏地 brings one up into the town at the 白石门; the 白石门's 出城 (asked first) puts one back in the
##   hollow the wind stopped in.
## - The town's people: 岚童 asks whose bell brought you and knows 萧辟尘's; 老蔺 made it; the sweeper says
##   where the town has stopped by the route drawn; the 萧家 hook.
## - Up the street to the 风铃阁 (the quest's city step), 岚翁's greeting under the bells (见过岚翁), 旋芒 asked
##   (the elder step); ten bells bright for a ledger of every trust, two for a hard one.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const BELL: StringName = &"native:lancheng/wind_bell"
const LAN_WENG: StringName = &"native.npc.lan_weng"
## Every bell's marks: a ledger with all of them rings all ten.
const KIND: Array[String] = ["放过了刘安禄", "安葬无名人", "替南危水保密", "霍铮回了寨", "宝衣给了安妮儿", "陈显祖作了证", "王府干净", "火前说了真话", "查清了封物", "冯策随你下湖"]
## A hard ledger: 关北 and 玉螺湖村 trust anyone who went through them.
const HARD: Array[String] = ["关北的骑兵欠你一阵", "村口的鬼卒退了", "告发了南危水", "带走了宝衣", "放走了陈显祖", "私了了庾子建"]
## Every mark of the trust table (计划 §4).
const TABLE: Array[String] = ["放过了刘安禄", "安葬无名人", "替南危水保密", "卫沧澜出了尚书府", "霍铮回了寨", "宝衣给了安妮儿", "瑷伦守到决战", "陈显祖作了证", "关北的骑兵欠你一阵", "王府干净", "火前说了真话", "大秦人留下了", "查清了封物", "村口的鬼卒退了", "冯策随你下湖", "皇叔入朝"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_table()
	for kind: String in ["town", "kind", "hard"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"town": await _test_town(tree, session)
			"kind": await _test_bells(tree, session, KIND, 10)
			"hard": await _test_bells(tree, session, HARD, 2)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## The layout's bells (the scene's Furnishings) and the bell landmarks name the same marks, bell by bell
## along the rack: each bell's dark piece `until` and bright piece `present` the same marks, the landmark
## standing over it its looks' marks, and all of them together the plan's table (计划 §4).
func _test_table() -> void:
	var scene: Node = (load("res://scenes/world/lancheng/lancheng_pavilion.tscn") as PackedScene).instantiate()
	var bright: Dictionary[int, Array] = {}
	var dark: Dictionary[int, Array] = {}
	for node: Node in scene.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look", {})
		if String(look.get("kind", "")) != "temple_bell":
			continue
		var x: int = roundi((node as Node2D).position.x)
		if look.has("present"):
			bright[x] = _sorted(_marks_of(look["present"]))
		elif look.has("until"):
			dark[x] = _sorted(_marks_of(look["until"]))
	var heard: Dictionary[int, Array] = {}
	for node: Node in scene.get_node("Interactions").get_children():
		var landmark_id: StringName = node.get("landmark_id")
		if not String(landmark_id).contains(".landmark.bell_"):
			continue
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		var marks: Array = []
		for look: WorldLandmarkDefinition.Look in landmark.looks():
			marks.append_array(look.marks)
		heard[roundi((node as Node2D).position.x)] = _sorted(marks)
	scene.free()
	_check(bright.size() == 10 and dark.size() == 10 and heard.size() == 10, "ten bells, each dark and bright, ten bell landmarks: %d / %d / %d" % [bright.size(), dark.size(), heard.size()])
	var xs: Array = bright.keys()
	xs.sort()
	var spots: Array = heard.keys()
	spots.sort()
	var every: Array = []
	for i: int in mini(xs.size(), spots.size()):
		var x: int = xs[i]
		_check(dark.get(x, []) == bright[x], "bell %d: dark until and bright present the same marks: %s / %s" % [i, dark.get(x, []), bright[x]])
		_check(heard[spots[i]] == bright[x], "bell %d: its landmark answers to its marks: %s / %s" % [i, heard[spots[i]], bright[x]])
		every.append_array(bright[x])
	_check(_sorted(every) == _sorted(TABLE), "all the bells together are the plan's table: %s" % [every])


func _sorted(marks: Array) -> Array:
	var copy: Array = marks.duplicate()
	copy.sort()
	return copy


func _marks_of(condition: Dictionary) -> Array:
	var marks: Array = []
	for part: Dictionary in condition.get("any", [condition]):
		marks.append(String(part.get("mark", "")))
	return marks


func _ninth_done(session: WorldSessionController) -> void:
	StoryFixtures.chapter8_done(session, false, true, false)
	var state: CharacterState = session.player_runtime().state
	for mark: String in ["中了武状元", "宫门放行", "候了殿试", "殿试过", "进了皇城", "见了福安", "见了皇帝", "翻过樟木匣", "对出了原令", "见过卫沧澜", "宋朴传了话", "私了了庾子建"]:
		state.marks[mark] = 1 # TEST-ONLY: as 第九章 A–D write them (the deal)
	session.record_journal()


func _test_town(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ninth_done(session)
	for mark: String in ["风眼在西", "风眼在东"]:
		state.marks.erase(mark)
	state.marks["风眼在北"] = 1 # TEST-ONLY: the north route drawn
	state.marks["到了岚城"] = 1 # TEST-ONLY: as 伏地 writes it (lancheng_wind_test walks it)
	session.record_journal()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter10")
	_check(StoryQuestLog.current_step(state, quest).step_id == &"city", "the 风铃阁 next")
	var street: WorldMapController = MapPlaces.enter(session, &"lancheng.white_gate", &"lancheng.white_gate.arrival") # TEST-ONLY: as 伏地 puts one
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("岚童问过你", 0) == 1 and _said(ui.log_lines(), "谁的铃"), "岚童: whose bell brought you?")
	var child: NpcRuntimeState = _first(session, &"lancheng.white_gate", &"native.npc.lan_child")
	_check(child != null and street.select_npc(child.character_id) and _said(street.ask_selected("铃"), "人人一只"), "岚童 on 铃, no bell shown")
	_check(not street.give_new_item_to_player(BELL).is_empty() and child != null and street.select_npc(child.character_id) and _said(street.ask_selected("铃"), "尘哥哥"), "岚童, the bell shown: 是尘哥哥的")
	street = MapPlaces.enter(session, &"lancheng.white_street", &"lancheng.white_street.sweeper.1") # TEST-ONLY: beside the sweeper
	await _settle(tree)
	var sweeper: NpcRuntimeState = _first(session, &"lancheng.white_street", &"native.npc.lan_sweeper")
	_check(sweeper != null and street.select_npc(sweeper.character_id) and _said(street.ask_selected("城"), "湖"), "the sweeper: today the town is over a lake (the north route)")
	street = MapPlaces.enter(session, &"lancheng.bellsmith", &"lancheng.bellsmith.bellsmith.1") # TEST-ONLY: in the bellsmith's yard
	await _settle(tree)
	var smith: NpcRuntimeState = _first(session, &"lancheng.bellsmith", &"native.npc.lan_bellsmith")
	_check(smith != null and street.select_npc(smith.character_id) and _said(street.ask_selected("铃"), "是我打的"), "老蔺: 是我打的")
	_check(smith != null and _said(street.ask_selected("萧家"), "空钩"), "老蔺 on 萧家: the empty hook")
	var hook: WorldLandmarkDefinition = GameContent.catalog().landmark(&"lancheng.xiao_house.landmark.hook")
	_check(hook != null and hook.looks().size() == 1 and hook.looks()[0].marks == ["石匣开了"], "the 萧家 hook: the bell's knot matches it once the box is opened")
	# Out by the 白石门 and back in by 伏地.
	street = MapPlaces.enter(session, &"lancheng.white_gate", &"lancheng.white_gate.arrival") # TEST-ONLY
	await _settle(tree)
	var out: ActService = street.service(&"lancheng.white_gate.out") as ActService
	_check(out != null and await MapPlaces.drive(tree, street, MapPlaces.service_spot(street, &"lancheng.white_gate.out")) and out.in_reach(), "at the 白石门")
	out.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("重新寻风"), "出城 asked first: the town will drift")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.active_map().map_id() == &"lancheng.wilds" and session.player_runtime().world_location().zone_id == &"lancheng.calm_north", "out: in the north hollow, where the wind stopped")
	await _settle(tree)
	_check(["风眼在西", "风眼在北", "风眼在东"].filter(func(mark: String) -> bool: return state.marks.get(mark, 0) != 0).size() == 1, "the town drifted: the route drawn afresh on the way out")
	for mark: String in ["风眼在西", "风眼在东"]:
		state.marks.erase(mark)
	state.marks["风眼在北"] = 1 # TEST-ONLY: drawn north again, for the way back in
	var wilds: WorldMapController = session.active_map() as WorldMapController
	var lie: ActService = wilds.service(&"lancheng.calm_north.lie_down") as ActService
	_check(lie != null and await MapPlaces.drive(tree, wilds, MapPlaces.service_spot(wilds, &"lancheng.calm_north.lie_down")) and lie.in_reach(), "at the hollow's 伏地")
	lie.interact()
	await _settle(tree)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.active_map().map_id() == &"lancheng.street" and session.player_runtime().world_location().zone_id == &"lancheng.white_gate", "伏地: back up into the town")
	# Up the street to the 风铃阁.
	street = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, street, &"lancheng.street_top"), "up the street to its top")
	_check(await MapPlaces.take_passage(tree, street, &"lancheng.street_top.north") and session.active_map().map_id() == &"lancheng.pavilion", "into the 风铃阁")
	await _settle(tree)
	var hall: WorldMapController = session.active_map() as WorldMapController
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"elder", "the city step done: 岚翁 next")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("见过岚翁", 0) == 1 and _said(ui.log_lines(), "有人信你的地方"), "岚翁 under the bells: 响的那几口，是有人信你的地方")
	var weng: NpcRuntimeState = _first(session, &"lancheng.bell_hall", LAN_WENG)
	_check(weng != null and hall.select_npc(weng.character_id) and _said(hall.ask_selected("旋芒"), "寒於氏"), "岚翁 on 旋芒: 寒於氏的剑")
	_check(weng != null and _said(hall.ask_selected("谁拔"), "一半"), "岚翁 on 谁拔: half the bells, or someone the wind will fetch")
	_check(weng != null and _said(hall.ask_selected("萧辟尘"), "回得来"), "岚翁 on 萧辟尘, the bell carried: 他还回得来")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"elder") or StoryQuestLog.current_step(state, quest) == null or StoryQuestLog.current_step(state, quest).step_id != &"elder", "the elder step done")
	_check(weng != null and weng.definition().dealings().is_fight_deferred() and weng.definition().dealings().fight_deferred.contains("按了回去"), "岚翁 cannot be fought: a wind holds the hand back")


func _test_bells(tree: SceneTree, session: WorldSessionController, marks: Array[String], bright: int) -> void:
	var state: CharacterState = session.player_runtime().state
	_ninth_done(session)
	for mark: String in TABLE:
		state.marks.erase(mark) # TEST-ONLY: the earlier chapters' fixture marks cleared
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY: a ledger's choices
	var hall: WorldMapController = MapPlaces.enter(session, &"lancheng.bell_hall", &"lancheng.bell_hall.street_arrival") # TEST-ONLY
	await _settle(tree)
	var lit: int = 0
	var dark: int = 0
	for node: Node in hall.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look", {})
		if String(look.get("kind", "")) != "temple_bell" or node.get_meta("staged_off", false):
			continue
		if look.has("present"):
			lit += 1
		else:
			dark += 1
	_check(lit == bright and dark == 10 - bright, "%d bells bright, %d dark (got %d / %d)" % [bright, 10 - bright, lit, dark])
	var guanbei: WorldLandmarkDefinition = GameContent.catalog().landmark(&"lancheng.bell_hall.landmark.bell_guanbei")
	_check(guanbei != null and guanbei.looks().size() == 2, "关北's bell answers to either of its two marks")


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
