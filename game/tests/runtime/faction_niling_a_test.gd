extends RefCounted

## 势力线第一批 卧底 A (计划 build/plans/势力线第一批_计划.md §6 逆灵宫 A, §2 第 5、6 条; DECISIONS「卧底 A」
## 「任务级清单」): nobody kneels to 逆灵宫 — one who finished 第三章 tells 林忌 (or 霍铮, who was freed) yes,
## asked first and told the other secret door shuts. Three doors in: the 残卷 back to 玄冥子 (no 疑点), to 林忌
## who burns it (残卷没回宫), or the night the dungeon was emptied (那一夜丢了人). Then the 管事's three chores
## (coal, the boxes and their seals, the chant: the next line of three), the 通铺 to 子时, the 巡殿 who walks the
## 前殿 at 子时 (caught: the 前院 till dawn, a 疑点; again, another), the 北门 barred while he walks and listened
## at, the 名单 copied at the 管事's desk as he sleeps over it — its names as the main story stands — and handed
## to 林忌 or 霍铮; the next cart lies overturned at the turn. The quest stays first in its column, 「疑点：x／3」
## and each 疑点 a sentence under it the whole way.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const QUEST: StringName = &"faction.niling"
const LIN: StringName = &"common.npc.taoist.taolord"
const HUO: StringName = &"native.npc.huo_zheng"
const HWANG: StringName = &"goathill.npc.bandit_hwang"
const XUAN: StringName = &"native.npc.xuan_mingzi_cliff"
const STEWARD: StringName = &"native.npc.niling_steward"
const LEAD: StringName = &"native.npc.niling_lead_chanter"
const PATROL: StringName = &"native.npc.niling_patrol"
const CROWN: StringName = &"native:niling/black_crown"
const SCROLL: StringName = &"native:niling/scroll_fragment"
const LIST: StringName = &"native:niling/offering_list"
const TEMPLE: StringName = &"temple.temple1"
const TEMPLE_POINT: StringName = &"temple.temple1.taolord.1"
const HUT: StringName = &"goathill.temple1"
const HUT_POINT: StringName = &"goathill.temple1.huo_zheng.1"
const COUNTING: StringName = &"niling.counting"
const COUNTING_POINT: StringName = &"niling.counting.ledger.1"
const ALCHEMY: StringName = &"niling.alchemy"
const ALCHEMY_POINT: StringName = &"niling.alchemy.stairs_return"
const STORE: StringName = &"niling.store"
const STORE_POINT: StringName = &"niling.store.side_entry"
const FRONT: StringName = &"niling.front"
const FRONT_POINT: StringName = &"niling.front.yard_entry"
const CLIFF: StringName = &"niling.cliff_path"
const CLIFF_POINT: StringName = &"niling.cliff_path.door_arrival"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_stranger, _test_night_door, _test_back_to_xuan, _test_burnt, _test_killed_xuan, _test_chased_without_scroll, _test_list_names]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.requires == [&"main.chapter3"] and quest.starts != null and quest.starts.key == "答应了做眼线", "faction.niling: a 势力 quest after 第三章, begun on a yes")
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"gate", &"hire", &"chores", &"listen", &"copy", &"deliver", &"next"], "its steps: %s" % [ids])
	_check(quest.pinned and quest.checklist.size() == 5 and quest.checklist[0].counts and quest.checklist[0].condition.amount == 3 and quest.checklist[0].condition.parts.size() == 4, "pinned; 疑点 counted of three, four of them in A (DECISIONS「任务级清单」)")
	var gate: StoryQuestDefinition.Step = quest.step(&"gate")
	_check(gate.is_branch() and gate.weight == StoryQuestDefinition.WEIGHT_SMALL and gate.options.map(func(option: StoryQuestDefinition.Option) -> StringName: return option.option_id) == [&"xuan", &"lin", &"night"], "the door in is the line's small choice: 玄冥子, 林忌, or the night")
	_check(gate.options.all(func(option: StoryQuestDefinition.Option) -> bool: return not option.reward.deed.is_empty()), "each door a deed")
	_check(gate.objective.contains("那是一条疑点") and gate.objective.contains("他当你是他的人"), "what either way costs is said before the choice")
	_check(quest.step(&"chores").checklist.size() == 3, "the three chores ticked off on the 任务 page")
	_check(catalog.npc(LIN).talk().ask_confirm("眼线").contains("东方神教") and catalog.npc(HUO).talk().ask_confirm("眼线").contains("东方神教"), "the yes is asked first, and says the other secret door shuts (计划 §11 Q1)")
	var watch: NpcWatch = catalog.npc(PATROL).dealings().watch
	_check(watch != null and watch.route.size() == 3 and watch.when != null and watch.mark == "子时在后殿外被撞见" and watch.again_mark == "子时在后殿外又被撞见" and watch.release_zone_id == &"niling.yard" and watch.until_phase == [&"dawn"], "the 巡殿 keeps a 子时 watch; caught, the 前院 till dawn, a 疑点 each time")
	var spawn: NpcSpawnDefinition = catalog.spawn(&"native.front.patrol")
	_check(spawn != null and spawn.zone_id == FRONT and spawn.present != null, "the 巡殿 on the stage at 子时 only")
	var barred: Array = catalog.exit_rules_between(FRONT, &"niling.altar").filter(func(rule: ZoneExitRuleDefinition) -> bool: return rule.present_npc_id == PATROL)
	_check(barred.size() == 1, "the 北门 barred while he walks")
	for id: StringName in [&"niling.alchemy.coal", &"niling.store.crates", &"niling.front.chant", &"niling.store.bunk", &"niling.front.listen", &"niling.counting.desk"]:
		_check(catalog.service(id) != null and catalog.service(id).act != null, "act %s" % id)
	_check(catalog.item(LIST) != null and catalog.item(LIST).give_to.has(LIN) and catalog.item(LIST).give_to.has(HUO), "the 名单 goes to 林忌 or 霍铮")
	_check(catalog.item(SCROLL).give_to.has(LIN) and catalog.item(SCROLL).give_to.has(XUAN), "the 残卷 to 林忌 or 玄冥子")
	_check(catalog.conditions().has("niling.suspicion"), "named condition niling.suspicion")


## Before 第三章 is done: 林忌 has nothing to say of the 道观, and asks nothing.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.chapter3_dungeon_done(session)
	session.record_journal()
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "与你无关") and not state.marks.has("林忌说了逆灵宫"), "林忌 before 第三章 is done: 与你无关")
	_check(temple.select_npc(lin.character_id) and not temple.ask_topics_selected().has("眼线"), "眼线 is not on his list")
	_check(not state.quests.has("faction.niling#started"), "no line")
	# 第三章's 子时 in the 前殿: no 巡殿, the 北门 not barred (the watch is the line's).
	_check(session.wait_until_phase([&"midnight"]), "子时")
	var crown: StringName = temple.give_new_item_to_player(CROWN)
	session.wear_player_item(crown)
	var hall: WorldMapController = MapPlaces.enter(session, FRONT, FRONT_POINT)
	await _settle(tree)
	_check(_first(session, FRONT, PATROL) == null and GameContent.catalog().exit_rules_between(FRONT, &"niling.altar").size() == 1 and hall.door(&"niling.altar.door") != null, "第三章 at 子时: no 巡殿 in the 前殿")
	_check(await MapPlaces.drive(tree, hall, MapPlaces.door_spot(hall, &"niling.altar.door", FRONT)) and hall.open_door(&"niling.altar.door") and await MapPlaces.take_passage(tree, hall, &"niling.front.north"), "and the 北门 lets one through to the altar")
	_check(not state.marks.has("子时在后殿外被撞见"), "nobody caught")


## The night door (霍铮 freed): his word and his 眼线, 那一夜丢了人; the crown from 林忌; the chores; the 通铺; the
## 巡殿 (caught once: 2／3); the barred 北门; listened at; the 名单 copied and to 霍铮; the cart overturned.
func _test_night_door(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	StoryFixtures.chapter3_rescued(session)
	session.record_journal()
	_check(not state.quests.has("faction.niling#started"), "第三章 done: the line waits for a yes")
	var hut: WorldMapController = MapPlaces.enter(session, HUT, HUT_POINT)
	await _settle(tree)
	_check(_said(_ask(hut, _first(session, HUT, HWANG), "茅山"), "林忌真人") and state.marks.get("黄霸说了茅山", 0) == 1, "黄霸: 茅山 asked after the 道观")
	var huo: NpcRuntimeState = _first(session, HUT, HUO)
	_check(huo != null and hut.select_npc(huo.character_id) and not hut.ask_topics_selected().has("眼线"), "霍铮's 眼线 waits for his word")
	_check(_said(_ask(hut, huo, "茅山"), "进得去的人") and state.marks.get("霍铮说了茅山", 0) == 1, "霍铮: 林忌 wants one who gets in")
	_check(hut.select_npc(huo.character_id) and hut.ask_topics_selected().has("眼线") and huo.definition().talk().confirm_applies("眼线", state.marks), "眼线 listed, asked first")
	_check(_said(_ask(hut, huo, "眼线"), "只知道有人") and state.marks.get("答应了做眼线", 0) == 1 and state.marks.get("那一夜丢了人", 0) == 1, "yes: 那一夜丢了人")
	session.record_journal()
	_check(state.quests.has("faction.niling#started") and StoryQuestLog.took(state, quest, &"night") and StoryQuestLog.current_step(state, quest).step_id == &"hire", "the line begun by the night door; the 管事 next")
	_check(_shown(session).contains("疑点：1／3") and _shown(session).contains("那一夜丢了人"), "the 任务 page: 疑点 1／3 and which: %s" % _shown(session))
	# The crown, from 林忌 (one who never had one).
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "黑冠"), "截下来的") and not _carried(session, CROWN).is_empty(), "林忌 gives a crown")
	_check(_said(_ask(temple, lin, "黑冠"), "冠在你身上"), "and not twice")
	_check(session.wear_player_item(_carried(session, CROWN)).succeeded, "the crown on")
	# The 管事 by day.
	var hall: WorldMapController = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "in the crown, nobody in the 账房 minds")
	var steward: NpcRuntimeState = _first(session, COUNTING, STEWARD)
	_check(_said(_ask(hall, steward, "干活"), "地牢里少了人") and state.marks.get("管事派了活", 0) == 1, "干活: three chores")
	_check(_said(_ask(hall, steward, "干活"), "三样干完了再来"), "not done yet")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"chores" and _shown(session).contains("丹房添炭 ✗"), "the chores ticked off on the page: %s" % _shown(session))
	# 添炭.
	hall = MapPlaces.enter(session, ALCHEMY, ALCHEMY_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.alchemy.coal") and state.marks.get("添过炭", 0) == 1, "the coal")
	# 跟诵: a wrong line, then the three.
	hall = MapPlaces.enter(session, FRONT, FRONT_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.front.chant") and ui.is_asking() and ui.confirm_prompt.message.text.contains("逆灵者"), "跟诵: the first line")
	ui.confirm_prompt.choice_buttons[0].pressed.emit() # 顺天地之灵而养之 — wrong
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[2].pressed.emit()
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[0].pressed.emit()
	await _settle(tree)
	_check(not ui.is_asking() and _recent(ui, 4).any(func(line: String) -> bool: return line.contains("听他们诵熟了再来")) and not state.marks.has("跟诵过"), "a wrong line: back to the cushion")
	(hall.service(&"niling.front.chant") as ActService).interact()
	await _settle(tree)
	for answer: int in [1, 2, 0]:
		ui.confirm_prompt.choice_buttons[answer].pressed.emit()
		await _settle(tree)
	_check(not ui.is_asking() and state.marks.get("跟诵过", 0) == 1, "the three next lines: 跟诵过")
	# 点箱.
	var gate: WorldMapController = MapPlaces.enter(session, STORE, STORE_POINT)
	await _settle(tree)
	_check(await _use(tree, gate, &"niling.store.crates") and state.marks.get("点过箱", 0) == 1 and _recent(ui, 6).any(func(line: String) -> bool: return line.contains("兵部之印")), "the boxes, 兵部's seal on 关北's")
	hall = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(_said(_ask(hall, _first(session, COUNTING, STEWARD), "干活"), "通铺") and state.marks.get("管事许你留宿", 0) == 1, "the 管事: the 通铺")
	session.record_journal()
	_check(state.quests.has("faction.niling/chores") and DeedLog.done(state, "在逆灵宫干了三样杂活，管事许你留宿") and StoryQuestLog.current_step(state, quest).step_id == &"listen", "chores done; 子时 next")
	# The 通铺 to 子时.
	gate = MapPlaces.enter(session, STORE, STORE_POINT)
	await _settle(tree)
	_check(await _use(tree, gate, &"niling.store.bunk") and ui.is_asking() and ui.confirm_prompt.confirm_button.text == "睡到子时", "the 通铺, asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.day_phase_id() == &"midnight", "子时 (%s)" % session.day_phase_id())
	# The 前殿 at 子时: the 巡殿, the barred door.
	hall = MapPlaces.enter(session, FRONT, FRONT_POINT)
	await _settle(tree)
	var patrol: NpcRuntimeState = _first(session, FRONT, PATROL)
	_check(patrol != null, "the 巡殿 on his round")
	if patrol == null:
		return
	var body: WorldCharacterBody2D = hall.npcs.runtime_body_for_character(patrol.character_id)
	var watch: NpcWatch = patrol.definition().dealings().watch
	hall.npc_life.npc_walker().cancel(patrol.character_id) # TEST-ONLY: he stands still for the looking
	var far: Vector2 = body.global_position
	body.global_position = MapPlaces.zone_spot(hall, FRONT) + Vector2(-200, 80) # TEST-ONLY: at the far end of his round, looking away
	body.facing = Vector2.LEFT
	_check(await MapPlaces.drive(tree, hall, MapPlaces.door_spot(hall, &"niling.altar.door", FRONT)) and hall.open_door(&"niling.altar.door"), "the 北门 opened by hand")
	var through: bool = await MapPlaces.take_passage(tree, hall, &"niling.front.north", 200)
	_check(not through and _recent(ui, 3).any(func(line: String) -> bool: return line.contains("从里面闩上了")) and state.marks.get("子时在后殿外被撞见", 0) == 0, "the 北门 barred while he walks")
	# Caught.
	body.global_position = far
	body.facing = Vector2.DOWN
	var player: WorldCharacterBody2D = hall.runtime_player_body()
	player.global_position = body.global_position + Vector2(0, 60) # TEST-ONLY: in front of him
	await _settle(tree)
	_check(hall.watches.sees(patrol, body, watch), "in front of him: seen")
	player.global_position = body.global_position + Vector2(0, -60) # TEST-ONLY: behind him
	await _settle(tree)
	_check(not hall.watches.sees(patrol, body, watch), "behind him: not seen")
	player.global_position = body.global_position + Vector2(0, 60)
	await _settle(tree)
	hall.watches.tick(2.0)
	await _settle(tree)
	_check(state.marks.get("子时在后殿外被撞见", 0) == 1 and session.day_phase_id() == &"dawn" and session.player_runtime().world_location().zone_id == &"niling.yard", "caught: the 前院 till dawn (%s, %s)" % [session.day_phase_id(), session.player_runtime().world_location().zone_id])
	_check(_shown(session).contains("疑点：2／3") and _shown(session).contains("子时在后殿外被撞见过"), "疑点 2／3: %s" % _shown(session))
	# The next 子时, unseen at the door.
	_check(session.wait_until_phase([&"midnight"]), "the next 子时")
	hall = MapPlaces.enter(session, FRONT, FRONT_POINT)
	await _settle(tree)
	patrol = _first(session, FRONT, PATROL)
	if patrol == null:
		_check(false, "the 巡殿 again")
		return
	body = hall.npcs.runtime_body_for_character(patrol.character_id)
	hall.npc_life.npc_walker().cancel(patrol.character_id)
	body.global_position = MapPlaces.zone_spot(hall, FRONT) + Vector2(-200, 80) # TEST-ONLY: at the far end of his round, looking away
	body.facing = Vector2.LEFT
	player = hall.runtime_player_body()
	player.global_position = MapPlaces.service_spot(hall, &"niling.front.listen") # TEST-ONLY: by the door
	await _settle(tree)
	_check((hall.service(&"niling.front.listen") as ActService).in_reach(), "at the 北门")
	(hall.service(&"niling.front.listen") as ActService).interact()
	await _settle(tree)
	_check(state.marks.get("后殿外听到了", 0) == 1 and _recent(ui, 8).any(func(line: String) -> bool: return line.contains("唤首的时辰")) and _recent(ui, 8).any(func(line: String) -> bool: return line.contains("名单在账房")), "listened: the hour of the 唤首, the 名单 in the 账房")
	_check(state.marks.get("子时在后殿外又被撞见", 0) == 0, "unseen")
	# The desk, the 管事 asleep over it.
	hall = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.counting.desk") and state.marks.get("抄了名单", 0) == 1 and not _carried(session, LIST).is_empty(), "the 名单 copied")
	_check(_recent(ui, 14).any(func(line: String) -> bool: return line.contains("伏在案头睡着了")) and _recent(ui, 14).any(func(line: String) -> bool: return line.contains("「补」")), "the 管事 asleep; 石头 struck out, 补")
	# To 霍铮.
	hut = MapPlaces.enter(session, HUT, HUT_POINT)
	await _settle(tree)
	huo = _first(session, HUT, HUO)
	_check(hut.select_npc(huo.character_id), "霍铮 selected")
	var given: ItemHandlingResult = hut.give_to_selected(_carried(session, LIST))
	_check(given != null and _said(given.lines, "还要补一个") and state.marks.get("名单递出去了", 0) == 1 and _carried(session, LIST).is_empty(), "the 名单 to 霍铮")
	session.record_journal()
	_check(state.quests.has("faction.niling/deliver") and DeedLog.done(state, "把逆灵宫的祭品名单递给了茅山") and StoryQuestLog.current_step(state, quest).step_id == &"next", "delivered; the line waits on 逆灵宫 B")
	_check(StoryFixtures.missing_after_play(session, StoryFixtures.niling_delivered.bind("night", 1), ["黄霸说了茅山", "霍铮说了茅山", "门房道士打过招呼"]).is_empty(), "played as niling_delivered(night, 1) writes: %s" % [StoryFixtures.missing_after_play(session, StoryFixtures.niling_delivered.bind("night", 1), ["黄霸说了茅山", "霍铮说了茅山", "门房道士打过招呼"])])
	# The turn: the cart overturned, its escort gone.
	var turn: WorldMapController = MapPlaces.enter(session, &"goathill.mroad4", &"goathill.mroad4.rope_return")
	await _settle(tree)
	_check(not turn.floor_item_of(&"native:goathill/overturned_cart", &"goathill.mroad4").is_empty() and turn.floor_item_of(&"native:goathill/tribute_cart", &"goathill.mroad4").is_empty(), "the turn: the next cart overturned, the old one gone")
	_check(_count_in(session, &"goathill.mroad4", &"native.npc.tribute_taoist") == 0, "its escort gone")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("祭品名单，是你抄出来递给茅山的") and ui.standing_page.shown_text().contains("巡殿的道士撞见过你"), "the 声望 page: %s" % ui.standing_page.shown_text())
	_check(Work.capture(session) != null, "Save at the turn")


## The 残卷 back to 玄冥子 on the cliff: no 疑点; the 管事 knows him.
func _test_back_to_xuan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	await _chased(tree, session, true)
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "茅山盯了它两年") and _said(_ask(temple, lin, "眼线"), "你定") and state.marks.get("答应了做眼线", 0) == 1 and not state.marks.has("残卷没回宫"), "林忌: the 残卷 is yours to place")
	session.record_journal()
	_check(state.quests.has("faction.niling#started") and StoryQuestLog.current_step(state, quest).step_id == &"gate" and _shown(session).contains("疑点：0／3"), "begun at the door: 疑点 0／3")
	var cliff: WorldMapController = MapPlaces.enter(session, CLIFF, CLIFF_POINT)
	await _settle(tree)
	var xuan: NpcRuntimeState = _first(session, CLIFF, XUAN)
	xuan.put_in_mood(xuan.definition().hooks().moods["owed"]) # TEST-ONLY: as the duel's 放过 left him
	_check(_said(_ask(cliff, xuan, "六阴剑"), "残卷带来了"), "玄冥子 asks for it")
	var asked: Array = xuan.definition().dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == SCROLL and rule.accept)
	_check(asked.size() == 1 and (asked[0] as NpcObjectRule).ask.contains("林忌不会高兴"), "giving it back is asked first")
	_check(cliff.select_npc(xuan.character_id), "玄冥子 selected")
	var given: ItemHandlingResult = cliff.give_to_selected(_carried(session, SCROLL))
	_check(given != null and _said(given.lines, "你是我的人") and state.marks.get("残卷给了玄冥子", 0) == 1 and _carried(session, SCROLL).is_empty(), "the 残卷 back with him")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"xuan") and _shown(session).contains("疑点：0／3"), "the door 玄冥子: no 疑点")
	cliff.give_new_item_to_player(CROWN)
	session.wear_player_item(_carried(session, CROWN))
	var hall: WorldMapController = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(_said(_ask(hall, _first(session, COUNTING, STEWARD), "干活"), "大弟子打过招呼") and state.marks.get("管事派了活", 0) == 1, "the 管事: 大弟子打过招呼")
	temple = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	_check(_said(_ask(temple, _first(session, TEMPLE, LIN), "逆灵宫"), "禁书回了宫里"), "林忌, a shade colder")


## The 残卷 to 林忌: burnt before one's eyes, 残卷没回宫.
func _test_burnt(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	await _chased(tree, session, true)
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_ask(temple, lin, "逆灵宫")
	_ask(temple, lin, "眼线")
	session.record_journal()
	var asked: Array = lin.definition().dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == SCROLL and rule.accept)
	_check(asked.size() == 1 and (asked[0] as NpcObjectRule).ask.contains("那是一条疑点"), "the burning is asked first, its 疑点 said")
	_check(temple.select_npc(lin.character_id), "林忌 selected")
	var given: ItemHandlingResult = temple.give_to_selected(_carried(session, SCROLL))
	_check(given != null and _said(given.lines, "不该回那里去") and state.marks.get("林忌烧了残卷", 0) == 1 and state.marks.get("残卷没回宫", 0) == 1, "burnt: 残卷没回宫")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"lin") and _shown(session).contains("疑点：1／3") and _shown(session).contains("残卷没回宫"), "the door 林忌: 疑点 1／3")
	_pinned_first(session)


## 玄冥子 killed on the cliff, his 残卷 carried: 林忌 does not send one back to a dead man.
func _test_killed_xuan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	await _chased(tree, session, true)
	state.marks.erase("放过了玄冥子") # TEST-ONLY: 了结, not 放过
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_ask(temple, lin, "逆灵宫")
	var said: Array[String] = _ask(temple, lin, "眼线")
	_check(_said(said, "死在后山了") and not _said(said, "大弟子") and state.marks.get("答应了做眼线", 0) == 1, "玄冥子 dead: only 林忌's fire (%s)" % [said])


## A chaser without the 残卷 (killed 玄冥子, or never picked it up): it never came back — 残卷没回宫.
func _test_chased_without_scroll(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	await _chased(tree, session, false)
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_ask(temple, lin, "逆灵宫")
	_check(_said(_ask(temple, lin, "眼线"), "当它没回宫") and state.marks.get("残卷没回宫", 0) == 1 and state.marks.get("林忌请你再进去", 0) == 1, "no 残卷: 残卷没回宫")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"night") and _shown(session).contains("疑点：1／3"), "in by 林忌's word, 疑点 1／3")


## The 名单's names as the main story stands: 关北 (踏平 / 救了一半 / not yet), 石头 (freed / used), 老三 (拔了 /
## 查清了 / not yet), and the last line's night (唤首, or 续灯 after the 终章).
func _test_list_names(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter3_rescued(session)
	var map: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var list: StringName = map.give_new_item_to_player(LIST) # TEST-ONLY: as the desk gives it
	var cases: Array = [
		[{}, ["关北河工逃役若干名", "「补」", "行三，待取", "唤首之夜"]],
		[{"救了一半": 1, "查清了封物": 1}, ["王石头之母", "行三，已取", "唤首之夜"]],
		[{"踏平了工地": 1, "拔了穿灵": 1}, ["槐阳城外八户", "湖里的东西先下了手", "唤首之夜"]],
	]
	for case: Array in cases:
		for mark: String in ["救了一半", "踏平了工地", "查清了封物", "拔了穿灵"]:
			state.marks.erase(mark)
		for mark: String in case[0]:
			state.marks[mark] = 1
		var before: int = ui.log_lines().size()
		_check(map.act_with_item(list), "翻看 the 名单")
		var read: Array[String] = ui.log_lines().slice(before)
		for part: String in case[1]:
			_check(read.any(func(line: String) -> bool: return line.contains(part)), "%s: 「%s」 (%s)" % [case[0], part, read])
	state.marks.erase("救出了霍铮") # TEST-ONLY: the chase's ledger
	state.quests["main.finale#started"] = state.quests.size() + 1 # TEST-ONLY: after the 终章
	state.quests["main.finale#done"] = state.quests.size() + 1
	var before: int = ui.log_lines().size()
	map.act_with_item(list)
	var read: Array[String] = ui.log_lines().slice(before)
	_check(read.any(func(line: String) -> bool: return line.contains("已用")) and read.any(func(line: String) -> bool: return line.contains("续灯之夜")) and not read.any(func(line: String) -> bool: return line.contains("唤首之夜")), "the chase: 石头 已用; after the 终章: 续灯 (%s)" % [read])


## 第三章 done by the chase (玄冥子 spared), `scroll`: the 残卷 picked up where he dropped it.
func _chased(tree: SceneTree, session: WorldSessionController, scroll: bool) -> void:
	StoryFixtures.chapter3_chased(session)
	session.record_journal()
	var map: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	if scroll:
		map.give_new_item_to_player(SCROLL) # TEST-ONLY: picked up on the cliff path


func _pinned_first(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, GameContent.catalog().story_quests(), StoryQuestDefinition.LINE_FACTION, session.quest_condition_test())
	_check(not shown.is_empty() and shown[0].quest.quest_id == QUEST and shown[0].pinned, "pinned: first in the 势力 column")


func _shown(session: WorldSessionController) -> String:
	var ui: SharedGameplayUI = session.shared_ui()
	ui.quest_page.fill(session.player_runtime().state, "小兄弟", "", session.quest_condition_test())
	return ui.quest_page.shown_text()


## Drives to an act's spot and uses it.
func _use(tree: SceneTree, map: WorldMapController, service_id: StringName) -> bool:
	var service: ActService = map.service(service_id) as ActService
	if service == null or not await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, service_id)) or not service.in_reach():
		return false
	service.interact()
	await _settle(tree)
	return true


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


## The instance id of the first of `definition_id` the player carries ("" when none).
func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return &""
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


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
	session.configure_source_entry("黑冠", CharacterState.GENDER_MALE)
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
