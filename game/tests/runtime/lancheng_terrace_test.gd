extends RefCounted

## 第十章 C 云台与旋芒 (owner's plan build/plans/第十章_计划.md, 2026-11-08「继续做」: Q1–Q3 默认;
## DECISIONS「第十章 C」), from B's end (StoryFixtures.chapter10_asked: 岚翁 asked of 旋芒 in the 风铃阁, the elder
## step) and up its west stair to the 云台:
## - 你拔 (a ledger of every trust: ten bells): asked first, 接风三刃 offered, stood, the sword drawn; the
##   other two say the sword has its hand; the whirl is gone; the chapter done, its mark, the finale's stub
##   next; 乘风 (asked first) to 天驼关's mirror, the wind's route cleared; 萧辟尘 says 是你。好.
## - A hard ledger (two bells, the deal): 你拔 says how many bells short; 请皇叔 says he is not at court;
##   让萧辟尘拔 wants his bell — carried, asked first, the bell taken, 萧辟尘 brought by the wind and gone,
##   the sword his; down by the wind, 宋朴 at the mirror once, then gone; 萧辟尘 at the 水烟阁 on 湖底.
## - The uncle's ledger (皇叔入朝, ten bells): one who chose to draw himself and then asks the 皇叔 has the
##   trial withdrawn; 於兰天武 brought by the wind, the sword his; at the 养心殿 he says so.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const BELL: StringName = &"native:lancheng/wind_bell"
const SWORD: StringName = &"native:lancheng/xuanmang"
const LAN_WENG: StringName = &"native.npc.lan_weng"
const LAN_WENG_TERRACE: StringName = &"native.npc.lan_weng_terrace"
const KIND: Array[String] = ["放过了刘安禄", "安葬无名人", "替南危水保密", "霍铮回了寨", "宝衣给了安妮儿", "陈显祖作了证", "王府干净", "火前说了真话", "查清了封物", "冯策随你下湖"]
const HARD: Array[String] = ["关北的骑兵欠你一阵", "村口的鬼卒退了", "告发了南危水", "带走了宝衣", "放走了陈显祖"]
const TABLE: Array[String] = ["放过了刘安禄", "安葬无名人", "替南危水保密", "卫沧澜出了尚书府", "霍铮回了寨", "宝衣给了安妮儿", "瑷伦守到决战", "陈显祖作了证", "关北的骑兵欠你一阵", "王府干净", "火前说了真话", "大秦人留下了", "查清了封物", "村口的鬼卒退了", "冯策随你下湖", "皇叔入朝"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for kind: String in ["self", "xiao", "uncle"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"self": await _test_self(tree, session)
			"xiao": await _test_xiao(tree, session)
			"uncle": await _test_uncle(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_self(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	await _to_terrace(tree, session, KIND + ["卫沧澜作证"], "expose")
	var terrace: WorldMapController = session.active_map() as WorldMapController
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter10")
	_check(terrace != null and terrace.map_id() == &"lancheng.terrace" and StoryQuestLog.current_step(state, quest).step_id == &"choice", "up the stair to the 云台: who draws next")
	var weng: NpcRuntimeState = _first(session, &"lancheng.whirl", LAN_WENG_TERRACE)
	_check(weng != null and terrace.npc_life.story_trials_offered(weng).is_empty(), "岚翁 on the 云台; no trial before one chooses to draw")
	_check(_whirl_shown(terrace), "the whirlwind turns, 旋芒 in it")
	await _act(tree, terrace, &"lancheng.whirl.self")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("接风三刃"), "自己拔 asked first: the trial named")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(state.marks.get("要自己拔旋芒", 0) == 1 and state.marks.get("旋芒在你手里", 0) == 0, "chosen; not drawn yet")
	await _act(tree, terrace, &"lancheng.whirl.self")
	_check(_said(_recent(ui), "先接三刃") and state.marks.get("旋芒在你手里", 0) == 0, "again before the trial: 先接三刃")
	var trials: Array[NpcTrial] = terrace.npc_life.story_trials_offered(weng)
	_check(trials.size() == 1 and trials[0].label == "接风三刃" and trials[0].confirm.contains("是真打"), "接风三刃 a row of the popup, asked first")
	state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: stand the blows
	var result: NpcApprenticeTrial.Result = terrace.npc_life.take_story_trial(weng, trials[0])
	await _told(tree, session, terrace, weng)
	_check(result.outcome == NpcApprenticeTrial.Outcome.PASSED and result.blows == 3 and state.marks.get("接下了接风三刃", 0) == 1 and DeedLog.done(state, "在岚城的云台上接下了岚翁的接风三刃"), "three blows stood: the mark and the deed")
	_check(terrace.npc_life.story_trials_offered(weng).is_empty(), "not offered twice")
	_blow_under_100(terrace, weng, trials[0], state)
	await _act(tree, terrace, &"lancheng.whirl.self")
	session.record_journal()
	_check(state.marks.get("旋芒在你手里", 0) == 1 and session.player_held_item_ids().has(SWORD), "the sword drawn: in one's hand")
	_check(_said(_recent(ui), "不扰民的剑"), "岚翁: 不扰民的剑，你们先帝要对了")
	_check(StoryQuestLog.took(state, quest, &"self") and StoryQuestLog.is_done(state, quest) and state.marks.get("岚城一章", 0) == 1 and DeedLog.done(state, "在岚城的云台上拔了旋芒"), "the chapter done on the self side: its deed, 岚城一章")
	var finale: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	_check(finale != null and StoryQuestLog.is_active(state, finale) and StoryQuestLog.current_step(state, finale).step_id == &"lake" and StoryQuestLog.objective(state, GameContent.catalog().story_quests()).begins_with("回到湖底"), "the finale's stub next: 回到湖底")
	for other: StringName in [&"lancheng.whirl.uncle", &"lancheng.whirl.xiao"]:
		await _act(tree, terrace, other)
		_check(_said(_recent(ui, 3), "剑已经有人了"), "%s: the sword has its hand" % other)
	var item: ItemContentDefinition = GameContent.catalog().item(SWORD)
	_check(item != null and item.weapon_definition() != null and item.no_drop and item.no_drop_line.contains("不能丢"), "旋芒 a sword, kept")
	# The whirl gone once one comes again (down the stair and up).
	var hall: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, terrace, &"lancheng.deck.down") and session.active_map().map_id() == &"lancheng.pavilion", "down the stair into the 风铃阁")
	await _settle(tree)
	hall = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, hall, &"lancheng.bell_hall.up"), "and up again")
	await _settle(tree)
	terrace = session.active_map() as WorldMapController
	_check(not _whirl_shown(terrace) and _calm_ring_shown(terrace), "the whirl gone: the worn ring left")
	# 乘风 to the mirror.
	state.marks["风眼在北"] = 1 # TEST-ONLY: a route drawn on the way in
	await _act(tree, terrace, &"lancheng.cloud_edge.ride")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("镜子"), "乘风 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.active_map().map_id() == &"canyon.pass" and session.player_runtime().world_location().zone_id == &"canyon.stone_forest3", "down by the wind: at 天驼关's mirror")
	_check(["风眼在西", "风眼在北", "风眼在东"].all(func(mark: String) -> bool: return state.marks.get(mark, 0) == 0), "the town drifted: the route cleared")
	_check(_first(session, &"canyon.stone_forest3", &"native.npc.song_pu_mirror") == null, "no 宋朴: not the deal's ledger")
	var master: String = await _ask_at(tree, session, &"waterfog.guildhall", &"waterfog.guildhall.master.1", &"common.npc.fighter.master", "旋芒")
	_check(master.contains("是你。好"), "萧辟尘: 是你。好 (%s)" % master)
	# 章与章之间的衔接: what this chapter played out holds what the next suite's fixture writes (but for
	# the earlier chapters' choices, which _to_terrace() sets as the ledger's, TEST-ONLY).
	var handoff: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.chapter10_done.bind("self", "expose", false, true, false), TABLE)
	_check(handoff.is_empty(), "旋芒 played (drawn yourself) leaves what chapter10_done(self) writes: %s" % [handoff])


func _test_xiao(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	await _to_terrace(tree, session, HARD, "deal")
	var terrace: WorldMapController = session.active_map() as WorldMapController
	await _act(tree, terrace, &"lancheng.whirl.self")
	_check(not ui.is_asking() and _said(_recent(ui, 3), "响了两口铃，还差四口"), "two bells: four short (six wanted) (%s)" % [_recent(ui, 3)])
	await _act(tree, terrace, &"lancheng.whirl.uncle")
	_check(not ui.is_asking() and _said(_recent(ui, 3), "通缉") and _said(_recent(ui, 3), "手诏送到他手里的那一边"), "the 皇叔 not at court: 还在通缉里, only the side that sent him the 手诏")
	await _act(tree, terrace, &"lancheng.whirl.xiao")
	_check(not ui.is_asking() and _said(_recent(ui, 3), "风认铃"), "no bell: 风认铃，不认人")
	_check(not terrace.give_new_item_to_player(BELL).is_empty(), "TEST-ONLY: the bell from the 石匣")
	await _act(tree, terrace, &"lancheng.whirl.xiao")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("可能回不来"), "让萧辟尘拔 asked first: he may not come back")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter10")
	_check(state.marks.get("旋芒在萧辟尘手里", 0) == 1 and not session.player_held_item_ids().has(BELL) and not session.player_held_item_ids().has(SWORD), "the sword his; his bell gone back to him")
	_check(_said(_recent(ui, 16), "城还是这个样子") and _first(session, &"lancheng.whirl", &"native.npc.xiao_pichen_home") == null, "萧辟尘 brought by the wind (城还是这个样子) and gone")
	_check(StoryQuestLog.took(state, quest, &"xiao") and StoryQuestLog.is_done(state, quest) and DeedLog.done(state, "在岚城的云台上，看着旋芒落进萧辟尘手里"), "the chapter done on 萧辟尘's side")
	var weng: NpcRuntimeState = _first(session, &"lancheng.whirl", LAN_WENG_TERRACE)
	_check(weng != null and terrace.select_npc(weng.character_id) and _said(terrace.ask_selected("旋芒"), "萧家的孩子"), "岚翁: it went with 萧家的孩子")
	_check(weng != null and _said(terrace.ask_selected("谁拔"), "萧家的孩子拔的"), "岚翁 on 谁拔: 萧家的孩子拔的")
	var hook: WorldLandmarkDefinition = GameContent.catalog().landmark(&"lancheng.xiao_house.landmark.hook")
	_check(hook != null and hook.looks()[0].marks == ["旋芒在萧辟尘手里"] and hook.looks()[0].long.contains("萧家的铃回来了"), "the 萧家 hook: the bell hangs on it")
	await _act(tree, terrace, &"lancheng.cloud_edge.ride")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.active_map().map_id() == &"canyon.pass", "down by the wind")
	var song: NpcRuntimeState = _first(session, &"canyon.stone_forest3", &"native.npc.song_pu_mirror")
	_check(song != null, "宋朴 at the mirror: the deal's ledger")
	var gate: Dictionary = {}
	for spawn: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://data/native/spawns.json"))["spawns"]:
		if String(spawn["id"]) == "native.wumen.song_pu":
			gate = spawn
	_check(gate.get("until", {}) == {"mark": "岚城一章"}, "and no longer at the 午门: one 宋朴 at a time")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("宋朴看见了旋芒", 0) == 1 and _said(ui.log_lines(), "剑在谁手里") and _first(session, &"canyon.stone_forest3", &"native.npc.song_pu_mirror") == null, "宋朴: 尚书大人问，剑在谁手里; then gone")
	var master: String = await _ask_at(tree, session, &"waterfog.guildhall", &"waterfog.guildhall.master.1", &"common.npc.fighter.master", "湖底")
	_check(master.contains("我拿旋芒去"), "萧辟尘 at the 水烟阁 on 湖底 (%s)" % master)
	# 章与章之间的衔接: what this chapter played out holds what the next suite's fixture writes (but for
	# the earlier chapters' choices, which _to_terrace() sets as the ledger's, TEST-ONLY).
	var handoff: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.chapter10_done.bind("xiao", "deal", false, true, false), TABLE)
	_check(handoff.is_empty(), "旋芒 played (萧辟尘) leaves what chapter10_done(xiao) writes: %s" % [handoff])


func _test_uncle(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	await _to_terrace(tree, session, KIND + ["皇叔入朝"], "uncle")
	var terrace: WorldMapController = session.active_map() as WorldMapController
	await _act(tree, terrace, &"lancheng.whirl.self")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	var weng: NpcRuntimeState = _first(session, &"lancheng.whirl", LAN_WENG_TERRACE)
	_check(state.marks.get("要自己拔旋芒", 0) == 1 and weng != null and terrace.npc_life.story_trials_offered(weng).size() == 1, "chosen to draw oneself: the trial offered")
	await _act(tree, terrace, &"lancheng.whirl.uncle")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("於兰天武"), "请皇叔 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter10")
	_check(state.marks.get("旋芒在皇叔手里", 0) == 1 and state.marks.get("要自己拔旋芒", 0) == 0 and terrace.npc_life.story_trials_offered(weng).is_empty(), "the sword the 皇叔's; the trial withdrawn")
	_check(_said(_recent(ui, 16), "这一把，我来") and _first(session, &"lancheng.whirl", &"native.npc.yulan_tianwu_wind") == null, "於兰天武 brought by the wind (这一把，我来) and gone")
	_check(StoryQuestLog.took(state, quest, &"uncle") and not StoryQuestLog.took(state, quest, &"self") and StoryQuestLog.is_done(state, quest), "the chapter done on the 皇叔's side, one option only")
	await _act(tree, terrace, &"lancheng.whirl.self")
	_check(not ui.is_asking() and _said(_recent(ui, 3), "剑已经有人了"), "自己拔 after: the sword has its hand")
	var uncle: String = await _ask_at(tree, session, &"imperial.front_hall", &"imperial.front_hall.uncle.1", &"common.npc.fighter.champion", "旋芒")
	_check(uncle.contains("在老夫手里"), "於兰天武 at the 养心殿: 在老夫手里 (%s)" % uncle)
	# 章与章之间的衔接: what this chapter played out holds what the next suite's fixture writes (but for
	# the earlier chapters' choices, which _to_terrace() sets as the ledger's, TEST-ONLY).
	var handoff: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.chapter10_done.bind("uncle", "uncle", false, true, false), TABLE)
	_check(handoff.is_empty(), "旋芒 played (皇叔) leaves what chapter10_done(uncle) writes: %s" % [handoff])


## B's end on the ninth chapter's ledger (`side`: expose, deal or uncle; StoryFixtures.chapter10_asked: the
## wind read, 岚翁 met and asked of 旋芒), the bells' marks given; in the 风铃阁, then up its west stair.
func _to_terrace(tree: SceneTree, session: WorldSessionController, marks: Array, side: String) -> void:
	StoryFixtures.chapter10_asked(session, side, false, true, false)
	var state: CharacterState = session.player_runtime().state
	for mark: String in TABLE:
		state.marks.erase(mark) # TEST-ONLY: the earlier chapters' fixture marks cleared
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY: a ledger's choices
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, &"lancheng.bell_hall", &"lancheng.bell_hall.street_arrival") # TEST-ONLY
	await _settle(tree)
	session.record_journal()
	var weng: NpcRuntimeState = _first(session, &"lancheng.bell_hall", LAN_WENG)
	_check(weng != null and hall.select_npc(weng.character_id) and _said(hall.ask_selected("谁拔"), "西墙那道梯子"), "岚翁 on 谁拔: the stair by the west wall")
	_check(await MapPlaces.take_passage(tree, hall, &"lancheng.bell_hall.up") and session.active_map().map_id() == &"lancheng.terrace", "up the stair to the 云台")
	await _settle(tree)


func _act(tree: SceneTree, map: WorldMapController, service_id: StringName) -> void:
	var service: ActService = map.service(service_id) as ActService
	var reached: bool = service != null and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, service_id)) and service.in_reach()
	_check(reached, "within reach of %s" % service_id)
	if reached:
		service.interact()
	await _settle(tree)


func _ask_at(tree: SceneTree, session: WorldSessionController, zone_id: StringName, point_id: StringName, npc_id: StringName, topic: String) -> String:
	var map: WorldMapController = MapPlaces.enter(session, zone_id, point_id) # TEST-ONLY: beside them
	await _settle(tree)
	var npc: NpcRuntimeState = _first(session, zone_id, npc_id)
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return "(not there)"
	return "\n".join(map.ask_selected(topic))


func _whirl_shown(map: WorldMapController) -> bool:
	return _pieces(map, false) == 1


func _calm_ring_shown(map: WorldMapController) -> bool:
	return _pieces(map, true) == 1


func _pieces(map: WorldMapController, calm: bool) -> int:
	var shown: int = 0
	for node: Node in map.get_node("Furnishings").get_children():
		var look: Dictionary = node.get_meta("look", {})
		if String(look.get("kind", "")) == "whirl" and bool(look.get("calm", false)) == calm and not node.get_meta("staged_off", false):
			shown += 1
	return shown


func _told(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	for beat: int in 12:
		if not map.npc_life.trial_running(npc):
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
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


## DECISIONS「姿态整记」: the trial's blow weighs its whole damage by its tag now; a landed blow still
## takes less than 100 气 from the character the suite plays (twenty landed blows sampled, nobody's
## kee, wound or force kept).
func _blow_under_100(map: WorldMapController, npc: NpcRuntimeState, trial: NpcTrial, state: CharacterState) -> void:
	var kee: CharacterResourceState = state.vitality
	var force: int = npc.character_state.recovery.inner_force.current
	var hardest: int = 0
	var landed: int = 0
	for sample: int in 60:
		if landed >= 20:
			break
		state.vitality = CharacterResourceState.new(100000, 100000, 100000)
		npc.character_state.recovery.inner_force.current = force
		if map.attack_player_outside_fight(npc, trial.blow_modifiers()) == null:
			break
		var lost: int = 100000 - mini(state.vitality.current, state.vitality.effective)
		if lost > 0:
			landed += 1
			hardest = maxi(hardest, lost)
	state.vitality = kee
	npc.character_state.recovery.inner_force.current = force
	_check(landed > 0 and hardest < 100, "%s's blow (%s): the hardest of %d landed took %d 气, under 100" % [npc.definition().display_name, trial.label, landed, hardest])
