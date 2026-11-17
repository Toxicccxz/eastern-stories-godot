extends RefCounted

## 势力线第二批 官府 A (计划 势力线第二批_计划.md §6 官府 A; DECISIONS「官府 A」「问话看偷窃记录」): the line shows once
## 程不平 wrote his letter, to one not of 花紫会; 程不平's 捕快 (asked first; a 惯窃 or one of 花紫会 refused) gives
## the 腰牌; the two men collecting a toll under an 官府告示 (雪亭's 路口, 绮云镇口) are only there for the case and
## only knocked down — beaten, each drops a 叠 of 路引 and runs; 程不平 reads the 天驼关 seal on them; the stub
## `seal` points at 天驼关 (官府 B fills it). The 荐书 waives the 武举's first bout before 第九章's way is taken; the 小屋's 密信 given
## to 花紫会 ends the line.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.court"
const JUDGE: StringName = &"choyin.npc.judgeman"
const GE: StringName = &"native.npc.ge_sheng"
const HEAD: StringName = &"native.npc.lu_decai_true"
const TOLL_SNOW: StringName = &"native.npc.toll_man_snow"
const TOLL_CLOUD: StringName = &"native.npc.toll_man_cloud"
const BADGE: StringName = &"native:choyin/constable_badge"
const PASSES: StringName = &"native:canyon/road_passes"
const LETTER: StringName = &"native:city/courier_letter"
const HALL: StringName = &"choyin.yamen"
const HALL_POINT: StringName = &"choyin.yamen.hall_entry"
const ROAD: StringName = &"snow.sroad4"
const ROAD_POINT: StringName = &"snow.sroad4.canyon_return"
const GATE: StringName = &"cloud.entrance"
const GATE_POINT: StringName = &"cloud.entrance.coach_arrival"
const SCHOOL: StringName = &"city.jiaowu"
const SCHOOL_POINT: StringName = &"city.jiaowu.ge_sheng.1"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_refused, _test_case, _test_exam, _test_letter_to_huazi]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.title == "官府", "faction.court: a 势力 line")
	if quest == null:
		return
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(0, 5) == [&"badge", &"toll_snow", &"toll_cloud", &"passes", &"seal"], "its steps begin with 官府 A's (the rest are 官府 B's): %s" % [ids])
	_check(quest.steps.slice(0, 5).all(func(step: StoryQuestDefinition.Step) -> bool: return not step.is_branch()), "no choice in 官府 A's steps: the split is 官府 B's")
	_check(not quest.step(&"passes").reward.deed.is_empty() and quest.step(&"passes").reward.rank_title.is_empty(), "the 路引 read: a deed, no rank (the 官府 gives none)")
	_check(quest.step(&"badge").objective.contains("惯窃") and quest.step(&"badge").objective.contains("花紫会"), "who is refused is said")
	_check(quest.step(&"seal").target.map_id == &"canyon.camp" and quest.step(&"seal").objective.contains("天驼关"), "the stub points at 天驼关")
	_check(quest.checklist.size() == 2, "two rows: the 荐书 and the 密信")
	for id: StringName in [BADGE, PASSES]:
		_check(catalog.item(id) != null and catalog.item(id).quest_item, "%s is a quest item" % id)
	for pair: Array in [[TOLL_SNOW, "雪亭路口收钱的倒了"], [TOLL_CLOUD, "绮云镇口收钱的倒了"]]:
		var npc: NpcDefinition = catalog.npc(pair[0])
		_check(npc != null and npc.hooks().always_kept and npc.hooks().spared_drop == PASSES and npc.hooks().spared_leave and npc.hooks().spared_mark == pair[1], "%s: only knocked down; beaten, he drops the 路引 and runs" % pair[0])
	for spawn_id: StringName in [&"native.sroad4.toll_man", &"native.entrance.toll_man"]:
		_check(catalog.spawn(spawn_id) != null, "%s exists" % spawn_id)
	var judge: NpcDefinition = catalog.npc(JUDGE)
	_check(judge.talk().ask_confirm("捕快").contains("官府这条线就断了") and judge.talk().ask_confirm("捕快").contains("惯窃"), "捕快 is asked first, and says what ends the line and who is refused")
	var marks: Dictionary = {"程不平写了信": 1}
	_check(judge.talk().confirm_applies("捕快", marks) and not judge.talk().confirm_applies("捕快", marks, &"family.huazi") and not judge.talk().confirm_applies("捕快", {}), "asked first of one he wrote for, not of 花紫会's own")
	var head: NpcDefinition = catalog.npc(HEAD)
	_check(head.talk().ask_confirm("密信").contains("官府那条线就断了") and not head.talk().ask_confirm("密信").contains("程不平就拿不到了"), "the 真龙头's 密信: the 官府 line ends")
	_check(catalog.story_quest(&"faction.huazi").step(&"letter").objective.contains("官府那条线就断了"), "花紫会's letter step says the 官府 line ends")
	# 问话看偷窃记录: a rule wanting a 惯窃 matches only more than ten caught steals.
	var rule := NpcInquiryRule.new()
	rule.asker_thief_above = 10
	var none: Dictionary[String, int] = {}
	_check(not rule.matches(none, &"", &"", 0, {}, [], &"", 10) and rule.matches(none, &"", &"", 0, {}, [], &"", 11), "asker_thief_above: 10 is not a 惯窃, 11 is")
	_check(NpcInquiryRule.new().matches(none, &"", &"", 0, {}, [], &"", 50), "a rule without it does not look")


## 花紫会's own: no line; 程不平 will not have them. A 惯窃: refused until the streets forget.
func _test_refused(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.huazi_joined(session)
	state.marks["程不平写了信"] = 1 # TEST-ONLY: 第五章
	session.record_journal()
	_check(not state.quests.has("faction.court#started"), "花紫会's own: no 官府 line")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var judge: NpcRuntimeState = _first(session, HALL, JUDGE)
	_check(hall.select_npc(judge.character_id) and hall.ask_topics_selected().has("捕快"), "捕快 listed once he wrote the letter")
	_check(_said(_ask(hall, judge, "捕快"), "叫花子堆") and not state.marks.has("做了乔阴捕快") and session.player_held_item_ids().get(BADGE, false) == false, "花紫会's own: refused")
	state.family = FamilyState.new(&"", 0) # TEST-ONLY: left 花紫会
	session.record_journal()
	_check(state.quests.has("faction.court#started"), "out of 花紫会: the line begins")
	CrimeRecord.add_thief(state, 11) # TEST-ONLY: caught eleven times
	_check(_said(_ask(hall, judge, "捕快"), "惯窃当捕快") and not state.marks.has("做了乔阴捕快"), "a 惯窃: refused")
	CrimeRecord.reset(state) # TEST-ONLY: obj/user.c reset() — one forgotten
	_check(_said(_ask(hall, judge, "捕快"), "腰牌带在身上") and state.marks.get("做了乔阴捕快", 0) == 1 and session.player_held_item_ids().get(BADGE, false) == true, "ten caught steals is not a 惯窃: the 腰牌")


## The drum and the letter (第五章): the line; 捕快, the 腰牌 (and the 荐书 told); the two men, there only now; beaten,
## the 路引; 程不平 with one 叠 and with both men down; the stub. The fixtures match what was played.
func _test_case(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	var road: WorldMapController = MapPlaces.enter(session, ROAD, ROAD_POINT)
	await _settle(tree)
	_check(_count_in(session, ROAD, TOLL_SNOW) == 0, "nobody collects on the 路口 before the 腰牌")
	state.marks["程不平写了信"] = 1 # TEST-ONLY: 第五章
	session.record_journal()
	_check(state.quests.has("faction.court#started") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"badge", "程不平 wrote his letter: the line begins")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("官府"), "the 势力 column has the line")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var judge: NpcRuntimeState = _first(session, HALL, JUDGE)
	_check(hall.select_npc(judge.character_id) and not hall.ask_topics_selected().has("路引"), "路引 not listed before the 腰牌")
	_check(judge.definition().talk().confirm_applies("捕快", state.marks, state.family.family_id), "捕快 asked first")
	var said: Array[String] = _ask(hall, judge, "捕快")
	_check(_said(said, "腰牌带在身上") and _said(said, "第一场免考") and _said(said, "收过路费") and state.marks.get("做了乔阴捕快", 0) == 1 and session.player_held_item_ids().get(BADGE, false) == true, "the 腰牌, the 荐书 told, the first case: %s" % [said])
	_check(not judge.definition().talk().confirm_applies("捕快", state.marks, state.family.family_id), "not asked first again")
	_check(_said(_ask(hall, judge, "捕快"), "拿下，搜身"), "捕快 again: the case")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"toll_snow", "the 路口 next")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.court_joined)
	_check(missing.is_empty(), "played leaves what court_joined writes: %s" % [missing])
	_check(_said(_ask(hall, judge, "路引"), "先把收过路费的两个人拿下"), "路引 before either is down")
	# 雪亭's 路口.
	road = MapPlaces.enter(session, ROAD, ROAD_POINT)
	await _settle(tree)
	var snow: NpcRuntimeState = _first(session, ROAD, TOLL_SNOW)
	_check(snow != null, "钱贵 on the 路口: %s" % [_where(session, TOLL_SNOW)])
	if snow == null:
		return
	_check(_said(_ask(road, snow, "告示"), "乔阴的捕快"), "the 告示 to one with the 腰牌: 乔阴's 官 cannot reach the road")
	_check(_said(_ask(road, snow, "过路费"), "黄金一两"), "过路费: 黄金一两")
	_check(StoryKeeps.keeps(state, catalog.npc(TOLL_SNOW), catalog.story_quests()), "钱贵 can only be knocked down")
	session.npc_spared(snow) # TEST-ONLY: attacked and beaten (kept: 放过 is all there is)
	road.npcs.leave_for_good(snow)
	_check(state.marks.get("雪亭路口收钱的倒了", 0) == 1 and not road.floor_items.floor_item_of(PASSES, ROAD).is_empty(), "beaten: he ran, the 路引 on the road")
	_check(await _take_floor(tree, session, road, PASSES, ROAD), "the 路引 picked up")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"toll_cloud", "绮云镇口 next")
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	judge = _first(session, HALL, JUDGE)
	_check(_said(_ask(hall, judge, "路引"), "绮云镇口还有一个") and not state.marks.has("程不平看了路引"), "one 叠: the other man first")
	road = MapPlaces.enter(session, ROAD, ROAD_POINT)
	await _settle(tree)
	_check(_count_in(session, ROAD, TOLL_SNOW) == 0, "钱贵 does not come back")
	# 绮云镇口.
	var gate: WorldMapController = MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	var cloud: NpcRuntimeState = _first(session, GATE, TOLL_CLOUD)
	_check(cloud != null, "牛四 under the 公告: %s" % [_where(session, TOLL_CLOUD)])
	if cloud == null:
		return
	_check(_said(_ask(gate, cloud, "告示"), "县太爷"), "牛四's 告示: an old one")
	session.npc_spared(cloud) # TEST-ONLY: beaten
	gate.npcs.leave_for_good(cloud)
	_check(state.marks.get("绮云镇口收钱的倒了", 0) == 1 and not gate.floor_items.floor_item_of(PASSES, GATE).is_empty(), "牛四 ran too, his 路引 on the ground")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"passes", "both down: to 程不平")
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_said(_ask(hall, _first(session, HALL, JUDGE), "捕快"), "路引带来本县看"), "捕快 with both down: bring the 路引")
	MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	missing = StoryFixtures.missing_after_play(session, StoryFixtures.court_tolls)
	_check(missing.is_empty(), "played leaves what court_tolls writes: %s" % [missing])
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	judge = _first(session, HALL, JUDGE)
	_check(hall.select_npc(judge.character_id) and hall.ask_topics_selected().has("路引"), "路引 listed to his 捕快")
	_check(_said(_ask(hall, judge, "路引"), "天驼关铁卫营") and state.marks.get("程不平看了路引", 0) == 1 and session.player_held_item_ids().get(PASSES, false) == true, "程不平 reads the seal; the 路引 stay with the player")
	session.record_journal()
	_check(state.quests.has("faction.court/passes") and DeedLog.done(state, "拿下了官道上挂着官府告示收过路费的人，搜出了盖着天驼关大印的路引") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"seal", "a deed; 天驼关 next (官府 B)")
	missing = StoryFixtures.missing_after_play(session, StoryFixtures.court_reported)
	_check(missing.is_empty(), "played leaves what court_reported writes: %s" % [missing])
	_check(_said(_ask(hall, judge, "捕快"), "去天驼关"), "捕快 now: to 天驼关")
	ui.standing_page.fill(session.quest_condition_test())
	var standing: String = ui.standing_page.shown_text()
	_check(standing.contains("乔阴县的捕快") and standing.contains("是你拿下的") and standing.contains("铁卫营"), "the 声望 page: %s" % standing)
	# The 腰牌 lost: another.
	hall.acts.take_from_player(BADGE)
	_check(session.player_held_item_ids().get(BADGE, false) == false, "TEST-ONLY: the 腰牌 taken away")
	_check(_said(_ask(hall, judge, "捕快"), "丢了") and session.player_held_item_ids().get(BADGE, false) == true, "the 腰牌 lost: another")


## The 荐书: a 捕快 entering the 武举 has the first bout waived; one made 捕快 after 第九章's way was taken hears
## nothing of it.
func _test_exam(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.court_joined(session)
	_write(state, "main.chapter9#started") # TEST-ONLY: 第九章
	session.record_journal()
	var rows: Array = StoryQuestLog.checked_rows(catalog.story_quest(QUEST).checklist, session.quest_condition_test())
	_check(rows.any(func(row: StoryQuestLog.Checked) -> bool: return row.row.label.contains("武举的荐书")), "the 荐书 row shows in 第九章")
	var school: WorldMapController = MapPlaces.enter(session, SCHOOL, SCHOOL_POINT)
	await _settle(tree)
	var ge: NpcRuntimeState = _first(session, SCHOOL, GE)
	_check(ge != null, "葛升 at the 校武场")
	if ge == null:
		return
	_check(_said(_ask(school, ge, "武举"), "第一场免了") and state.marks.get("报了武举", 0) == 1 and state.marks.get("胜了第一场", 0) == 1 and state.marks.get("程不平荐了你", 0) == 1, "the 荐书: entered, the first bout waived")
	_check(_said(_ask(school, ge, "武举"), "名字已经写上了"), "asked again: entered already")
	rows = StoryQuestLog.checked_rows(catalog.story_quest(QUEST).checklist, session.quest_condition_test())
	_check(not rows.any(func(row: StoryQuestLog.Checked) -> bool: return row.row.label.contains("武举的荐书")), "the 荐书 row gone once entered")
	# Made 捕快 after 第九章's way was taken (the 早朝), never entered: no 荐书 in 程不平's words, none at the 校武场.
	for mark: String in ["做了乔阴捕快", "报了武举", "胜了第一场", "程不平荐了你"]:
		state.marks.erase(mark) # TEST-ONLY: as if never
	state.marks["早朝过"] = 1 # TEST-ONLY
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var said: Array[String] = _ask(hall, _first(session, HALL, JUDGE), "捕快")
	_check(_said(said, "腰牌带在身上") and not _said(said, "第一场免考") and state.marks.get("做了乔阴捕快", 0) == 1, "after the 早朝: the 腰牌, no 荐书: %s" % [said])
	school = MapPlaces.enter(session, SCHOOL, SCHOOL_POINT)
	await _settle(tree)
	said = _ask(school, _first(session, SCHOOL, GE), "武举")
	_check(not _said(said, "第一场免了") and state.marks.get("报了武举", 0) == 1 and not state.marks.has("胜了第一场"), "after the 早朝 the 校武场 enters a 捕快 like anyone: %s" % [said])


## The 小屋's 密信 to the 真龙头: the 官府 line ends; 程不平 has no case for the player; the men are not there.
func _test_letter_to_huazi(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.court_joined(session)
	session.record_journal()
	state.marks["密信给了花紫会"] = 1 # TEST-ONLY: given to the 真龙头
	session.record_journal()
	_check(state.quests.has("faction.court#lapsed") and state.marks.get("官府的线断了", 0) == 1, "the 密信 to 花紫会: the 官府 line ends")
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, catalog.story_quests(), StoryQuestDefinition.LINE_FACTION)
	var court: Array = shown.filter(func(view: StoryQuestLog.Shown) -> bool: return view.quest.quest_id == QUEST)
	_check(court.size() == 1 and court[0].lapsed and court[0].entries.has("程不平不再跟你说案子。官府的事，到此为止。"), "the 任务 page says it ended")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var judge: NpcRuntimeState = _first(session, HALL, JUDGE)
	_check(_said(_ask(hall, judge, "捕快"), "给了叫花子"), "程不平: no case for one who gave the letter to the 叫花子")
	_check(not judge.definition().talk().confirm_applies("捕快", state.marks, state.family.family_id), "nothing asked first")
	state.marks.erase("密信给了花紫会") # TEST-ONLY: the line ended some other way (拜了花紫会, then left)
	var badges: bool = session.player_held_item_ids().get(BADGE, false)
	_check(_said(_ask(hall, judge, "捕快"), "本县不跟你说了") and _said(_ask(hall, judge, "路引"), "本县不跟你说了") and session.player_held_item_ids().get(BADGE, false) == badges, "the line ended: no 腰牌 again, no case")
	state.marks["密信给了花紫会"] = 1 # TEST-ONLY
	MapPlaces.enter(session, ROAD, ROAD_POINT)
	await _settle(tree)
	_check(_count_in(session, ROAD, TOLL_SNOW) == 0, "no man on the 路口 once the line ended")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	_check(session.shared_ui().standing_page.shown_text().contains("你给了花紫会"), "the 声望 page says so")


## Beside the item lying in `zone_id`, then get.c on it. Whether the player holds one now.
func _take_floor(tree: SceneTree, session: WorldSessionController, map: WorldMapController, definition_id: StringName, zone_id: StringName) -> bool:
	var item_id: StringName = map.floor_items.floor_item_of(definition_id, zone_id)
	var view: WorldFloorItemView = null if item_id.is_empty() else map.floor_items.floor_item_view(item_id)
	if view == null or not map.place_player(zone_id, MapPlaces.spot(map, zone_id, view.global_position, 48.0)):
		return false
	await tree.physics_frame
	await tree.physics_frame
	if not map.floor_items.select_floor_item(item_id):
		return false
	map.floor_items.take_selected_floor_item()
	return session.player_held_item_ids().get(definition_id, false) == true


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _write(state: CharacterState, key: String) -> void:
	if not state.quests.has(key):
		state.quests[key] = state.quests.size() + 1


func _all(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found.append(npc)
	return found


func _where(session: WorldSessionController, definition_id: StringName) -> Array:
	var found: Array = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
				found.append([npc.world_location().zone_id, npc.exists_in_map, npc.life_status])
	return found


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	return _all(session, zone_id, definition_id).size()


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var found: Array[NpcRuntimeState] = _all(session, zone_id, definition_id)
	return null if found.is_empty() else found[0]


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("官府", CharacterState.GENDER_MALE)
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
