extends RefCounted

## 势力线第一批 天邪 B (计划 build/plans/势力线第一批_计划.md §4; DECISIONS「天邪 B」「代收」): after the 镖单,
## 潘军禅's 「盟主」 — what he pieced together (白衣武官, 兵部's blade, the clue in the 尚书府), said as the
## main story stands (卫沧澜 out, the 京师 chapter over without him, or neither: the line waits on the main
## story). Then the 正厅 scene before the 太师椅: 颜违 comes down, four 局面 (告发 or 保密 × 卫沧澜 back or
## not) and what the spy and the 镖单 left; the split (颜违 or 潘军禅, 执事 either way, each one's word
## after), the 声望 page, 南危水's disappointment, the finale's 水烟阁 band (潘军禅 where neither 南危水 nor
## 卫沧澜 comes). And the gap at the door: with both masters gone 潘军禅 takes the oath himself.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const PAN: StringName = &"common.npc.fighter.executioner"
const YAN: StringName = &"waterfog.npc.elder7"
const NAN: StringName = &"waterfog.npc.elder5"
const WEI: StringName = &"native.npc.wei_canglan"
const PAN_LAKE: StringName = &"native.npc.pan_junchan_lake"
const QUEST: StringName = &"faction.celestial"
const HALL: StringName = &"waterfog.guildhall"
const HALL_POINT: StringName = &"waterfog.guildhall.executioner.1"
const YARD: StringName = &"waterfog.frontyard"
const YARD_POINT: StringName = &"waterfog.frontyard.gate_return"
const FOREHALL: StringName = &"waterfog.forehall"
const LAKE: StringName = &"village.lakeside"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_waits, _test_back_with_yan, _test_empty_with_pan, _test_four_scenes, _test_letter_read, _test_lapsed, _test_take_in]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"hear", &"watch", &"report", &"escort", &"trace", &"leader", &"rescue", &"chair", &"split"], "its steps: %s" % [ids])
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == StoryQuestDefinition.WEIGHT_BIG and split.options.size() == 2, "the chair is the line's one big split, of two")
	for option: StoryQuestDefinition.Option in split.options:
		_check(not option.reward.deed.is_empty() and option.reward.rank_title == "执事" and option.reward.rank_family == &"family.celestial", "%s: a deed and 执事" % option.option_id)
	_check(split.objective.contains("问他「椅子」") and split.objective.contains("颜违会记下你") and split.objective.contains("只同你谈公事"), "what either side costs is said before the choice")
	_check(quest.step(&"rescue").objective.contains("白衣武官") and quest.step(&"rescue").objective.contains("尚书府"), "the clue: 白衣武官, the 尚书府")
	_check(not catalog.npc(PAN).talk().ask_confirm("椅子").is_empty() and not catalog.npc(YAN).talk().ask_confirm("椅子").is_empty(), "both sides are asked first")
	_check(catalog.npc(PAN).talk().ask_confirm("椅子").contains("大分裂") and catalog.npc(YAN).talk().ask_confirm("椅子").contains("选了不能改"), "and say it is the split, for good")
	var teaching: NpcTeaching = catalog.npc(PAN).teaching()
	_check(teaching != null and teaching.family_id == &"family.celestial" and teaching.apprentice != null and teaching.apprentice.kind == NpcTeaching.Kind.OATH and teaching.when != null, "潘军禅 can take the oath, under a condition (DECISIONS「代收」)")
	var letters: Array = catalog.npc(PAN).dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == &"native:waterfog/spy_letter" and rule.mark_giver == "值守回了话")
	_check(letters.size() == 3 and letters.all(func(rule: NpcObjectRule) -> bool: return rule.marks_giver.size() == 1), "the letter read writes how it was read (颜违's 账房 or 兵部)")
	var spawn: NpcSpawnDefinition = catalog.spawn(&"native.lakeside.pan_junchan")
	_check(spawn != null and spawn.npc_definition_id == PAN_LAKE and spawn.zone_id == LAKE, "潘军禅 has a place by the lake")
	for id: String in ["celestial.leader_settled", "celestial.chair", "celestial.split"]:
		_check(catalog.conditions().has(id), "named condition %s" % id)
	var scene: Array = catalog.npc(PAN).hooks().calls.filter(func(call: NpcHooks.Call) -> bool: return call.scene)
	_check(scene.size() >= 8 and scene.all(func(call: NpcHooks.Call) -> bool: return call.act.when != null), "the 正厅 scene is 潘军禅's, every line asks that it still runs (%d)" % scene.size())


## Before the 京师 chapter: 潘军禅 tells what he knows and the line waits on the main story; no scene yet.
func _test_waits(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.celestial_escorted(session)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"leader", "the 镖单 settled: 盟主的下落 is next")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	_check(pan != null and hall.select_npc(pan.character_id) and not hall.ask_topics_selected().has("椅子"), "no 椅子 before the scene")
	var told: Array[String] = _ask(hall, pan, "盟主")
	_check(_said(told, "白衣") and _said(told, "兵部的刀") and _said(told, "尚书府") and _said(told, "改走了老松岭") and state.marks.get("潘军禅说了盟主的下落", 0) == 1, "潘军禅's telling (the 刑堂 route): %s" % [told])
	session.record_journal()
	_check(state.quests.has("faction.celestial/leader") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"rescue", "the line waits on the main story")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("线索在京师尚书府"), "the 势力 column says where the clue is")
	_check(_said(_ask(hall, pan, "盟主"), "我出不了水烟阁"), "asked again, a reminder")
	await _reenter(tree, session)
	_check(not session.scene_held() and _count_in(session, HALL, YAN) == 0, "no scene while the 盟主's fate is open; 颜违 stays upstairs")
	# The 京师 chapter done with 卫沧澜 still there: the step closes, the chair waits (empty).
	state.marks["皇城一章"] = 1 # TEST-ONLY
	session.record_journal()
	_check(state.quests.has("faction.celestial/rescue") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"chair", "the 京师 chapter over: the chair is next")


## 保密, 卫沧澜 brought out first, the spy taken (兵部's), the route found: the scene with 卫沧澜 in the hall;
## for 颜违: 执事, 潘军禅 only on business, 南危水's word.
func _test_back_with_yan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.celestial_escorted(session, true, true)
	for mark: String in ["替南危水保密", "卫沧澜出了尚书府"]:
		state.marks[mark] = 1 # TEST-ONLY: 第二章 kept, 第九章 C's 走
	state.quests["main.chapter2/choice/keep"] = state.quests.size() + 1 # TEST-ONLY
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_count_in(session, HALL, WEI) == 1, "卫沧澜 sits in the 正厅")
	var told: Array[String] = _ask(hall, _first(session, HALL, PAN), "盟主")
	_check(_said(told, "是你从尚书府带出来的") and _said(told, "陈天星查清了") and _said(told, "出去走一走") and not _said(told, "线索在京师"), "with 卫沧澜 back, the telling: %s" % [told])
	session.record_journal()
	_check(state.quests.has("faction.celestial/rescue") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"chair", "the 盟主's step passes on the spot")
	var lines: Array[String] = await _scene(tree, session)
	_check(_count_in(session, HALL, YAN) == 1, "颜违 came down")
	_check(_said(lines, "这把椅子一直空着") and not _said(lines, "「代」字"), "保密: 颜违 is still 七长老, the empty chair: %s" % [lines.slice(0, 3)])
	_check(_said(lines, "矮凳") and _said(lines, "二十年没管过事"), "卫沧澜 in the hall, and 颜违's word on him")
	_check(_said(lines, "是兵部的人") and _said(lines, "朝廷就多一天的念想"), "the spy taken while 庾子建 sits: 兵部's")
	_check(_said(lines, "兵部点名改走老松岭") and _said(lines, "旧案到此为止"), "the route found, and 颜违's answer to it")
	_check(_said(lines, "由他自己说") and _said(lines, "水烟阁的执事有你一个") and _said(lines, "椅子就能换人"), "潘军禅 waits on the 盟主; both ask the player")
	_check(state.marks.get("正厅的话说完了", 0) == 1, "the scene is told")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "the split is next")
	var yan: NpcRuntimeState = _first(session, HALL, YAN)
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	_check(hall.select_npc(yan.character_id) and hall.ask_topics_selected().has("椅子") and hall.select_npc(pan.character_id) and hall.ask_topics_selected().has("椅子"), "now 椅子 can be asked of both")
	_check(catalog.npc(YAN).talk().confirm_applies("椅子", state.marks), "and is asked first")
	_check(_said(_ask(hall, yan, "椅子"), "识时务") and state.marks.get("站了颜违", 0) == 1, "for 颜违")
	_check(_said(_ask(hall, pan, "椅子"), "你站到七长老那边去了") and not state.marks.has("站了潘军禅"), "the other side is closed")
	_check(not catalog.npc(PAN).talk().confirm_applies("椅子", state.marks), "and asks nothing more")
	session.record_journal()
	_check(state.quests.has("faction.celestial/split/side_yan") and StoryQuestLog.is_done(state, catalog.story_quest(QUEST)) and DeedLog.done(state, "在水烟阁正厅站到了颜违一边"), "the choice, its deed, and the line ends")
	_check(state.affiliation.family_title == "执事" and player.shown_title() == "天邪派第十七代执事", "执事: %s" % player.shown_title())
	_check(_said(_ask(hall, pan, "盟主"), "七长老做主了"), "潘军禅 speaks only of business")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("你站在颜违一边") and ui.standing_page.shown_text().contains("挂兵部刀的白衣武官"), "the 声望 page: %s" % ui.standing_page.shown_text().replace("
", " | "))
	# 南危水, still in the 前厅 before the sixth chapter: one disappointed word.
	MapPlaces.enter(session, FOREHALL, &"waterfog.forehall.elder5.1")
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("南危水说过椅子", 0) == 1 and _said(_recent(ui, 8), "守的就是那把椅子"), "南危水's word: %s" % [_recent(ui, 4)])
	# The 水烟阁's band is 卫沧澜's (he came out); 潘军禅 stays home.
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	state.quests["main.finale#started"] = state.quests.size() + 1 # TEST-ONLY
	MapPlaces.enter(session, LAKE, &"village.lakeside.finale.pan")
	await _settle(tree)
	_check(_count_in(session, LAKE, PAN_LAKE) == 0 and _count_in(session, LAKE, &"native.npc.nan_weishui_lake") == 1, "南危水 by the lake (保密), not 潘军禅")
	_check(helpers != null, "finale.helpers")
	# The fixture is what playing it wrote.
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.celestial_split.bind(true, true, true), ["卫沧澜出了尚书府", "替南危水保密", "南危水说过椅子"])
	_check(missing.is_empty(), "celestial_split writes nothing the play did not: %s" % [missing])


## 告发, the 京师 chapter over without 卫沧澜, the spy run off (颜违's man), the 刑堂: the empty chair; for
## 潘军禅; 潘军禅 and the 红衣武士 by the lake.
func _test_empty_with_pan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.celestial_escorted(session, false, false)
	for mark: String in ["告发了南危水", "庾子建下狱", "皇城一章"]:
		state.marks[mark] = 1 # TEST-ONLY: 第二章 told, 第九章 揭发
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var told: Array[String] = _ask(hall, _first(session, HALL, PAN), "盟主")
	_check(_said(told, "盟主没有回来") and _said(told, "出去走一走") and not _said(told, "线索在京师"), "the 京师 chapter over without him: %s" % [told])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"chair", "on to the chair")
	var lines: Array[String] = await _scene(tree, session)
	_check(_said(lines, "「代」字") and not _said(lines, "这把椅子一直空着"), "告发: 颜违 would drop the 代")
	_check(_said(lines, "盟主还没回来") and _said(lines, "人要是回得来") and not _said(lines, "矮凳"), "the chair empty, nobody on the stool")
	_check(_said(lines, "没有白跑") and not _said(lines, "是兵部的人"), "the spy run off was 颜违's: he has his count")
	_check(_said(lines, "有些旧案，到此为止最好") and _said(lines, "不是替谁结案"), "the 刑堂")
	_check(_said(lines, "等他回来"), "潘军禅 waits on the 盟主")
	session.record_journal()
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	var yan: NpcRuntimeState = _first(session, HALL, YAN)
	_check(catalog.npc(PAN).talk().confirm_applies("椅子", state.marks), "潘军禅's side is asked first")
	_check(_said(_ask(hall, pan, "椅子"), "门规里没有哪一条") and state.marks.get("站了潘军禅", 0) == 1, "for 潘军禅")
	_check(_said(_ask(hall, yan, "椅子"), "本座记性好") and not state.marks.has("站了颜违"), "颜违 remembers")
	session.record_journal()
	_check(state.quests.has("faction.celestial/split/side_pan") and DeedLog.done(state, "在水烟阁正厅站到了潘军禅一边：等盟主回来") and player.shown_title() == "天邪派第十七代执事", "the choice: %s" % player.shown_title())
	# 颜违's greeting the next time.
	await _reenter(tree, session)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	if _first(session, HALL, YAN) == null:
		MapPlaces.enter(session, FOREHALL, &"waterfog.forehall.elder7.1")
		await _settle(tree)
		for second: int in 3:
			session.advance_npc_heartbeat(1.0)
			await _settle(tree)
	_check(_count_in(session, HALL, YAN) + _count_in(session, FOREHALL, YAN) == 1, "one 颜违, wherever he went")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("你站在潘军禅一边"), "the 声望 page: %s" % ui.standing_page.shown_text().replace("
", " | "))
	# The finale: neither 南危水 (told) nor 卫沧澜 (still in the 尚书府) — 潘军禅 and the 红衣武士 come.
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	state.marks["冰龙倒了"] = 1 # TEST-ONLY: the 冰龙 is no band
	state.marks["霍铮回了寨"] = 1 # TEST-ONLY
	_check(not bool(session.quest_condition_test().call(helpers)), "野羊寨 and the 水烟阁: two bands")
	state.marks["大秦人留下了"] = 1 # TEST-ONLY
	_check(bool(session.quest_condition_test().call(helpers)), "the 水烟阁 counts for one who stood with 潘军禅: three bands")
	state.quests["main.finale#started"] = state.quests.size() + 1 # TEST-ONLY
	MapPlaces.enter(session, LAKE, &"village.lakeside.finale.pan")
	await _settle(tree)
	_check(_count_in(session, LAKE, PAN_LAKE) == 1 and _count_in(session, LAKE, &"native.npc.nan_weishui_lake") + _count_in(session, LAKE, &"native.npc.wei_canglan_lake") == 0, "潘军禅 by the lake, alone of the 水烟阁")
	var finale: StoryQuestDefinition = catalog.story_quest(&"main.finale")
	var rows: Array[String] = []
	for step: StoryQuestDefinition.Step in finale.steps:
		for row: StoryQuestDefinition.CheckRow in step.checklist:
			if row.shown_if != null and bool(session.quest_condition_test().call(row.shown_if)):
				rows.append(row.label)
	_check(rows.has("水烟阁（潘军禅）守潭口"), "the 点将 checklist names him: %s" % [rows])


## The four 局面 of the scene: 告发 or 保密, 卫沧澜 back or not.
func _test_four_scenes(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.celestial_escorted(session)
	state.marks["潘军禅说了盟主的下落"] = 1 # TEST-ONLY: told
	for told: bool in [true, false]:
		for back: bool in [true, false]:
			for mark: String in ["告发了南危水", "替南危水保密", "卫沧澜出了尚书府", "皇城一章", "正厅撞见了", "正厅的话说完了"]:
				state.marks.erase(mark)
			state.marks["告发了南危水" if told else "替南危水保密"] = 1
			state.marks["卫沧澜出了尚书府" if back else "皇城一章"] = 1
			var lines: Array[String] = await _scene(tree, session)
			var key: String = "%s/%s" % ["告发" if told else "保密", "回来了" if back else "没回来"]
			_check(_said(lines, "「代」字") == told and _said(lines, "这把椅子一直空着") == not told, "%s: 颜违's opening" % key)
			_check(_said(lines, "二十年没管过事") == back and _said(lines, "人要是回得来") == not back, "%s: the chair: %s" % [key, lines.slice(0, 4)])
			_check(_said(lines, "椅子就能换人") and state.marks.get("正厅的话说完了", 0) == 1, "%s: told to the end" % key)


## The spy's letter read as 兵部's before 庾子建 fell: the scene says what 潘军禅 said then, not what is true now.
func _test_letter_read(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.celestial_escorted(session)
	for mark: String in ["潘军禅说了盟主的下落", "皇城一章", "信是兵部的", "庾子建下狱"]:
		state.marks[mark] = 1 # TEST-ONLY
	var read: Array[String] = await _scene(tree, session)
	_check(_said(read, "是兵部的人") and not _said(read, "七长老账房里的人"), "the letter as 潘军禅 read it: 兵部's: %s" % [read])


## One who left 天邪派 sees no scene.
func _test_lapsed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.celestial_escorted(session)
	for mark: String in ["潘军禅说了盟主的下落", "卫沧澜出了尚书府"]:
		state.marks[mark] = 1 # TEST-ONLY
	session.record_journal()
	StoryFixtures.fonxan_joined(session) # TEST-ONLY: 改投封山
	session.record_journal()
	_check(state.marks.get("天邪的线断了", 0) == 1, "the line lapsed")
	await _reenter(tree, session)
	_check(not session.scene_held() and not state.marks.has("正厅撞见了"), "no scene for one who left")


## Both masters gone (皇叔入朝, 萧辟尘留在了冰里): 潘军禅 takes the oath; before that he takes nobody.
func _test_take_in(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	var service: TeacherService = _teacher(hall, pan)
	_check(service != null and not service.in_reach() and not service.takes_apprentices(), "with the masters at home 潘军禅 offers no teaching, no 拜师")
	_check(not MapAtlas.takes_students(catalog.npc(PAN), state), "and no 师 mark on the 沙盘")
	state.marks["皇叔入朝"] = 1 # TEST-ONLY: 第九章 D
	_check(not service.takes_apprentices(), "one master gone: still not")
	state.marks["萧辟尘留在了冰里"] = 1 # TEST-ONLY: 终章
	await _reenter(tree, session)
	hall = session.world_map_of(&"waterfog.pavilion")
	pan = _first(session, HALL, PAN)
	service = _teacher(hall, pan)
	_check(_first(session, HALL, &"common.npc.fighter.master") == null and _first(session, HALL, &"common.npc.fighter.champion") == null, "neither master in the 正厅")
	_check(service != null and service.in_reach() and service.takes_apprentices() and MapAtlas.takes_students(catalog.npc(PAN), state), "both gone: 潘军禅 takes students")
	var asked: NpcApprenticeship.Outcome = service.request_apprentice()
	_check(asked == NpcApprenticeship.Outcome.ASKED and _said(service.last_lines, "代收") and service.awaits_oath(), "拜师: he asks for the oath in the masters' stead: %s" % [service.last_lines])
	var sworn: NpcApprenticeship.Outcome = service.swear_oath()
	_check(sworn == NpcApprenticeship.Outcome.RECRUITED and state.family.family_id == &"family.celestial" and state.family.generation == 17 and NpcApprenticeship.is_master_of(state, catalog.npc(PAN)), "sworn: of 天邪派's seventeenth generation, his apprentice")
	session.record_journal()
	_check(state.quests.has("faction.celestial#started"), "and the line begins")
	_check(_said(_ask(hall, pan, "山门"), "新面孔"), "潘军禅 sends them to the gate as any other")


func _scene(tree: SceneTree, session: WorldSessionController) -> Array[String]:
	var ui: SharedGameplayUI = session.shared_ui()
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var before: int = ui.log_lines().size()
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.scene_held() and hall.scene_running() and session.player_runtime().state.marks.get("正厅撞见了", 0) == 1, "the scene holds the player as they come in, and is marked seen")
	for second: int in 60:
		if not hall.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not hall.scene_running() and not session.scene_held(), "the scene is over")
	return ui.log_lines().slice(before)


func _reenter(tree: SceneTree, session: WorldSessionController) -> void:
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)


func _teacher(map: WorldMapController, npc: NpcRuntimeState) -> TeacherService:
	for service: WorldService in map.service_nodes:
		if service is TeacherService and npc != null and (service as TeacherService).npc.character_id == npc.character_id:
			return service as TeacherService
	return null


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("天邪", CharacterState.GENDER_MALE)
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
