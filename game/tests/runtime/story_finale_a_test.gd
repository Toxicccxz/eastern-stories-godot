extends RefCounted

## 终章 A 点将 (owner's plan build/plans/终章_计划.md, 2026-11-08「按推荐的做」; DECISIONS「终章 A」「任务清单」
## 「步骤条件」「决战前存档」), from 第十章's ledger (StoryFixtures.chapter10_done) with the choices' marks set
## (TEST-ONLY):
## - The data: main.finale's four steps (lake, gather, shore, depths), the gather step's checklist, the
##   people of the lakeside, the 鬼卒 held by those who came, the home spawns away while they stand there.
## - A kind ledger (seal kept, 旋芒 in hand, every 帮手): at the lakeside the 点将 — each one who came says a
##   line, 能灭它; the checklist ticks all three 器 and 7／3 帮手; 等到天黑 asked first (the 决战前 save
##   asked for), the night, every place held, no 鬼卒 on the shore; the boat, the dive asked first, down to
##   the ice cave, the depths next; the hand-over to B's fixture (StoryFixtures.finale_dived).
## - A hard ledger (the deal, the sword drawn from the lake, the robe taken off and left, no 帮手): only the
##   farmwife and 庾子建; the scene says 只能再封 and 庾子建 asks for the sword; the checklist says what is
##   missing; the sword given to him (asked first), gone from the bag; the night: nobody keeps the shore,
##   the 鬼卒 come at the player.
## - The 皇叔's ledger: 於兰天武 at the lake with 旋芒 (and still at the 养心殿: 终章 C); 瑷伦 called from 晚月庄
##   (湖底) and at the lake after, her line once.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const QuestPageScript := preload("res://ui/world/quest_page.gd")
const SWORD: StringName = &"native:lancheng/xuanmang"
const LAKESIDE: StringName = &"village.lakeside"
const ARRIVAL: StringName = &"village.lakeside.boat_return"
const TABLE: Array[String] = ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冰龙倒了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密", "卫沧澜出了尚书府", "瑷伦守到决战", "带走了宝衣"]
const KIND: Array[String] = ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for kind: String in ["kind", "hard", "uncle"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"kind": await _test_kind(tree, session)
			"hard": await _test_hard(tree, session)
			"uncle": await _test_uncle(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.finale")
	_check(quest != null and quest.requires == [&"main.chapter10"] and quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id).slice(0, 4) == [&"lake", &"gather", &"shore", &"hall"], "main.finale: lake, gather, shore, then the 冰龙厅 (终章 B) after 第十章")
	var gather: StoryQuestDefinition.Step = quest.step(&"gather")
	_check(gather.checklist.size() == 22 and gather.checklist.filter(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.counts).size() == 1, "the 点将 checklist: twenty-two rows (封山 B: 封山守渡口, either 宗), one count")
	var count: StoryQuestDefinition.CheckRow = gather.checklist.filter(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.counts)[0]
	_check(count.condition.when == JournalEntryDefinition.When.AT_LEAST and count.condition.amount == 3 and count.condition.parts.size() == 8, "帮手: three of eight (封山 B added 封山守渡口)")
	var wait: ServiceDefinition = catalog.service(&"village.lakeside.wait")
	var first: ScriptedAct = wait.act.acts[0]
	_check(first.steps[0].kind == ScriptedAct.Kind.KEEP_SAVE and first.steps[1].kind == ScriptedAct.Kind.MARK and first.steps[1].flag == "下了决战" and not first.ask.is_empty(), "等到天黑 on the finale: the 决战前 save first, asked first")
	_check(wait.act.acts.size() == 9 and wait.act.acts.slice(0, 3).all(func(act: ScriptedAct) -> bool: return act.steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.UNTIL_PHASE)), "three branches by the day's phase (each crosses into the night), the 第八章 ones after")
	var held: Array[ScriptedAct.Step] = first.steps.filter(func(step: ScriptedAct.Step) -> bool: return step.only_when != null)
	_check(held.size() == 9 and held[0].kind == ScriptedAct.Kind.MARK and held[0].flag == "能灭它", "能灭它 marked by a step's own when; eight lines of who keeps where (封山 B: the 渡口, either 宗)")
	for spawn_id: StringName in [&"native.lakeside.finale_runners", &"native.road1.finale_runners", &"native.field.finale_runners"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.cleared_mark.ends_with("又退了") and spawn.until != null and spawn.until.when == JournalEntryDefinition.When.ANY, "%s: up with the night, held by who came or beaten" % spawn_id)
	var home: NpcSpawnDefinition = catalog.spawn(&"imperial.front_hall.yulan_tianwu")
	_check(home != null and home.until == null, "於兰天武 stays at the 养心殿 (终章 C: one off the stage would never come back; only who stays in the ice leaves home)")


func _test_kind(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "self", "expose", false, KIND)
	var lake: WorldMapController = await _to_lake(tree, session)
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	_check(lake != null and StoryQuestLog.current_step(state, quest).step_id == &"gather", "at the lakeside: the 点将 next")
	for npc_id: StringName in [&"native.npc.woman_lakeside", &"native.npc.huo_zheng_lake", &"native.npc.guo_cheng_lake", &"native.npc.shield_swordsman_lake", &"native.npc.feng_ce_lake", &"native.npc.annie_lake", &"native.npc.nan_weishui_lake"]:
		_check(_first(session, LAKESIDE, npc_id) != null, "%s at the lake" % npc_id)
	for npc_id: StringName in [&"native.npc.wei_canglan_lake", &"native.npc.yulan_tianwu_lake", &"native.npc.xiao_pichen_lake", &"native.npc.elon_lake", &"native.npc.yu_zijian_lake"]:
		_check(_first(session, LAKESIDE, npc_id) == null, "no %s on this ledger" % npc_id)
	await _beats(tree, session, 8)
	var said: Array[String] = ui.log_lines()
	for part: String in ["湖底那盏灯", "野羊寨的弟兄", "关北的骑兵欠你一阵", "盾顶着", "三十个人", "宝衣在我身上", "替我挡了一刀", "今夜能灭它"]:
		_check(_said(said, part), "the 点将: %s" % part)
	_check(not _said(said, "只能再封") and not _said(said, "剑交给朝廷") and state.marks.get("点过将", 0) == 1, "nothing of the hard side; the 点将 seen once")
	var rows: String = _rows(session)
	for part: String in ["穿灵钉在封坛上 ✓", "旋芒在你手里 ✓", "宝衣在安妮儿身上，她在岸边 ✓", "帮手：7／3 ✓", "冰龙没有动过", "三器都在，帮手也够：能灭它"]:
		_check(rows.contains(part), "the checklist: %s (%s)" % [part, rows])
	_check(not rows.contains("只能再封") and not rows.contains("庾子建"), "nothing missing")
	# 等到天黑: asked first, the 决战前 save asked for, the night, every place held.
	var asked: Array[int] = [0]
	# The 决战前 save as the host takes it the moment it is asked for (GameAutosave.begin() on the keep slot).
	var kept: Array[GameSaveSnapshot] = [null]
	session.keep_save_requested.connect(func() -> void:
		asked[0] += 1
		kept[0] = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-11T00:00:00Z", null, GameSaveSnapshot.KEEP_SLOT_ID, false).snapshot)
	session.day_clock().set_day_seconds(43200) # TEST-ONLY: the day
	await _act(tree, lake, &"village.lakeside.wait")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("决战前"), "等到天黑 asked first: the 决战前 save named")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	_check(asked[0] == 1 and state.marks.get("下了决战", 0) == 1 and state.marks.get("能灭它", 0) == 1, "the 决战前 save asked for once; 下了决战, 能灭它")
	_check(session.day_phase_id() == &"night" and _said(ui.log_lines(), "关北的马") and _said(ui.log_lines(), "黄土道") and _said(ui.log_lines(), "圆盾"), "the night: the three places held")
	await _settle(tree)
	_check(_first(session, LAKESIDE, &"native.npc.hell_runner_finale") == null, "no 鬼卒 on the shore: the riders keep it")
	_check(StoryQuestLog.current_step(state, quest).step_id == &"shore", "the shore next: down the lake")
	# Out on the boat and down.
	await _act(tree, lake, &"village.lakeside.paddle")
	var middle: WorldMapController = session.active_map() as WorldMapController
	_check(middle != null and middle.map_id() == &"village.midlake", "out on the boat")
	await _act(tree, middle, &"village.lake.dive")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("岸上的人替你守着"), "the dive asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	_check(session.active_map().map_id() == &"village.icecave" and state.marks.get("终章下了湖底", 0) == 1 and StoryQuestLog.current_step(state, quest).step_id == &"hall", "down into the ice cave: the 冰龙厅 next")
	# 章与章之间的衔接: what this package played out holds what B's fixture writes (but for the earlier
	# chapters' choices, which _ledger() sets, TEST-ONLY).
	var handoff: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.finale_dived.bind("self", "expose", false), TABLE)
	_check(handoff.is_empty(), "终章 A played leaves what finale_dived writes: %s" % [handoff])
	# The 决战前 save taken out and read back (Continue from the keep slot): the lakeside before the battle.
	if not _check(kept[0] != null and kept[0].metadata.slot_id == GameSaveSnapshot.KEEP_SLOT_ID, "the 决战前 save was taken the moment it was asked for"):
		return
	var text: String = GameSaveJsonCodec.encode(kept[0]).text
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(text).snapshot, tree.root)
	if not _check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "the 决战前 save restores: %s" % restored.path):
		if is_instance_valid(restored.candidate):
			restored.candidate.free()
		return
	var before: WorldSessionController = restored.candidate
	var again: GameSaveSnapshot = OldPineWorldSaveCapture.new().capture(before, &"test", "2026-09-11T00:00:00Z", null, GameSaveSnapshot.KEEP_SLOT_ID, false).snapshot
	_check(again != null and before.player_runtime().world_location().zone_id == LAKESIDE and before.active_map_id() == MapPlaces.map_of(LAKESIDE), "Continue from it: at the lakeside (%s)" % before.player_runtime().world_location().zone_id)
	var before_quest: StoryQuestDefinition.Step = StoryQuestLog.current_step(before.player_runtime().state, quest)
	_check(before_quest != null and before_quest.step_id in [&"gather", &"shore"] and before.player_runtime().state.marks.get("点过将", 0) == 1, "before the battle: the 点将 done, the shore ahead (%s)" % [before_quest.step_id if before_quest != null else &""])
	_check(again != null and GameSaveJsonCodec.encode(again).text == text, "read back exactly as it was kept")
	before.free()
	await tree.process_frame


func _test_hard(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "self", "deal", true, ["冰龙倒了", "带走了宝衣", "宋朴看见了旋芒"])
	var lake: WorldMapController = await _to_lake(tree, session)
	_check(_first(session, LAKESIDE, &"native.npc.woman_lakeside") != null and _first(session, LAKESIDE, &"native.npc.yu_zijian_lake") != null, "the farmwife and 庾子建 at the lake")
	_check(_first(session, LAKESIDE, &"native.npc.huo_zheng_lake") == null and _first(session, LAKESIDE, &"native.npc.annie_lake") == null, "nobody else came")
	await _beats(tree, session, 8)
	var said: Array[String] = ui.log_lines()
	_check(_said(said, "湖里那东西") and _said(said, "剑交给朝廷") and _said(said, "宋朴说，剑在你身上") and _said(said, "只能再封") and not _said(said, "今夜能灭它"), "the 点将 on the hard side: 庾子建 asks for the sword; only a seal again")
	var rows: String = _rows(session)
	for part: String in ["穿灵在你手里 ✓", "旋芒在你手里 ✓", "宝衣在你身上 ✗——带上它，下湖前穿上", "帮手：0／3 ✗", "岸上：庾子建来要剑", "这一回只能再封"]:
		_check(rows.contains(part), "the checklist: %s (%s)" % [part, rows])
	# The sword to 庾子建: asked first, gone from the bag.
	var yu: NpcRuntimeState = _first(session, LAKESIDE, &"native.npc.yu_zijian_lake")
	_check(yu != null and lake.select_npc(yu.character_id) and _said(lake.ask_selected("剑"), "交给本官"), "庾子建 on 剑")
	var sword: StringName = _carried(lake, SWORD)
	var rule: NpcObjectRule = yu.definition().dealings().object_rules[0] if yu != null and not yu.definition().dealings().object_rules.is_empty() else null
	_check(rule != null and rule.item == SWORD and rule.ask.contains("只能再封") and rule.accept, "giving the sword is asked first (the 给予 panel's question): only a seal again")
	var given: ItemHandlingResult = lake.give_to_selected(sword)
	await _settle(tree)
	if ui.is_asking():
		ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
	else:
		_check(given.done(), "the sword given (%s)" % [given.lines])
	session.record_journal()
	_check(state.marks.get("旋芒交给了庾子建", 0) == 1 and not session.player_held_item_ids().has(SWORD) and _rows(session).contains("旋芒在你手里 ✗——交给了庾子建"), "the sword his: the row says so")
	# The night: nobody keeps the shore.
	session.day_clock().set_day_seconds(43200) # TEST-ONLY
	await _act(tree, lake, &"village.lakeside.wait")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(state.marks.get("能灭它", 0) == 0 and _said(ui.log_lines(), "湖畔没人守") and _said(ui.log_lines(), "村口没人守") and _said(ui.log_lines(), "稻田边没人守"), "the night: nobody keeps anywhere")
	await _settle(tree)
	_check(_first(session, LAKESIDE, &"native.npc.hell_runner_finale") != null, "the 鬼卒 on the shore come at the player")


func _test_uncle(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "uncle", "uncle", false, ["瑷伦守到决战", "霍铮回了寨"])
	# 瑷伦 called from 晚月庄 before the lake.
	var manor: WorldMapController = MapPlaces.enter(session, &"latemoon.room.eastroom", &"latemoon.room.eastroom.elon.1") # TEST-ONLY
	await _settle(tree)
	var elon: NpcRuntimeState = _first(session, &"latemoon.room.eastroom", &"latemoon.npc.room.elon")
	_check(elon != null and manor.select_npc(elon.character_id) and _said(manor.ask_selected("湖底"), "我在湖边等你") and state.marks.get("叫来了瑷伦", 0) == 1, "瑷伦 on 湖底: called")
	var lake: WorldMapController = await _to_lake(tree, session)
	_check(_first(session, LAKESIDE, &"native.npc.yulan_tianwu_lake") != null and _first(session, LAKESIDE, &"native.npc.elon_lake") != null, "於兰天武 with 旋芒 and 瑷伦 at the lake")
	await _beats(tree, session, 10)
	_check(_said(ui.log_lines(), "剑在这儿") and _said(ui.log_lines(), "你叫了，我就来了"), "the 皇叔: 剑在这儿; 瑷伦: 你叫了，我就来了")
	var rows: String = _rows(session)
	_check(rows.contains("旋芒在皇叔手里，他在岸边 ✓") and rows.contains("宝衣在瑷伦身上 ✓") and rows.contains("帮手：2／3 ✗") and rows.contains("这一回只能再封"), "the checklist: the 皇叔, 瑷伦, two 帮手 (%s)" % rows)
	_check(lake != null and not await _absent_at(tree, session, &"imperial.front_hall", &"imperial.front_hall.uncle.1", &"common.npc.fighter.champion"), "於兰天武 still at the 养心殿 after the lake (终章 C)")


## The tenth chapter's ledger and the choices' marks (`marks`), the 旋芒 in hand when one drew it.
func _ledger(session: WorldSessionController, who: String, side: String, pulled: bool, marks: Array) -> void:
	StoryFixtures.chapter10_done(session, who, side, pulled)
	var state: CharacterState = session.player_runtime().state
	for mark: String in TABLE:
		state.marks.erase(mark) # TEST-ONLY: the earlier chapters' fixture marks cleared
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY: a ledger's choices
	var map: WorldMapController = session.active_map() as WorldMapController
	if who == "self":
		map.give_new_item_to_player(SWORD) # TEST-ONLY: as the 云台 gives it
	if pulled:
		map.give_new_item_to_player(&"native:village/soul_impaler") # TEST-ONLY: as the 封坛 gives it
	session.record_journal()


func _to_lake(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var lake: WorldMapController = MapPlaces.enter(session, LAKESIDE, ARRIVAL) # TEST-ONLY: come down the willows
	await _settle(tree)
	session.record_journal()
	return lake


func _rows(session: WorldSessionController) -> String:
	var lines: Array[String] = []
	var state: CharacterState = session.player_runtime().state
	for view: StoryQuestLog.Shown in StoryQuestLog.shown(state, GameContent.catalog().story_quests(), StoryQuestDefinition.LINE_MAIN, session.quest_condition_test()):
		for checked: StoryQuestLog.Checked in view.checklist:
			lines.append(QuestPageScript.checklist_text(checked))
	return "\n".join(lines)


func _absent_at(tree: SceneTree, session: WorldSessionController, zone_id: StringName, point_id: StringName, npc_id: StringName) -> bool:
	MapPlaces.enter(session, zone_id, point_id) # TEST-ONLY
	await _settle(tree)
	return _first(session, zone_id, npc_id) == null


func _beats(tree: SceneTree, session: WorldSessionController, seconds: int) -> void:
	for second: int in seconds:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _act(tree: SceneTree, map: WorldMapController, service_id: StringName) -> void:
	var service: ActService = map.service(service_id) as ActService
	var reached: bool = service != null and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, service_id)) and service.in_reach()
	_check(reached, "within reach of %s" % service_id)
	if reached:
		service.interact()
	await _settle(tree)


func _carried(map: WorldMapController, definition_id: StringName) -> StringName:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, map.session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _spawn_json(region: String, spawn_id: String) -> Dictionary:
	for spawn: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://data/%s/spawns.json" % region))["spawns"]:
		if String(spawn["id"]) == spawn_id:
			return spawn
	return {}


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
	session.configure_source_entry("终章", CharacterState.GENDER_MALE)
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


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
