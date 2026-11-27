extends RefCounted

## 势力线第二批 振远 A (计划 势力线第二批_计划.md §4 振远 A; DECISIONS「振远 A」「车马行不拉」): the line shows
## for one who saw the 镖单 and for 振远's own; 陈剑秋 speaks first and「走镖」is asked first; 老周 and his barrow
## follow every way once told「上路」, and no 车马行 takes them; on the 碎石小路 贺平 stops the cart (two lines,
## then he and his two men fight), comes back at the player who lost, and spared talks: 交官府 (the 官府's gold
## through 陈天星) or 走吧 (his father's letter, which tells 陈天星 the route 兵部 named). In 京师 the cart
## comes in at the door: 镖头 for 振远's own, 振远's card for everyone, good at the 相国府's gate and to 韦执中 while
## 第九章 runs. Leaving 振远 ends the line of one who took the 镖 as 振远's own.

const MapPlaces := preload("res://tests/support/map_places.gd")
const FollowerWalk := preload("res://tests/support/follower_walk.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RealFight := preload("res://tests/support/real_fight.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const QUEST: StringName = &"faction.zhenyuan"
const JIANQIU: StringName = &"cloud.npc.b_header"
const TIANXING: StringName = &"city.npc.chen"
const CARTER: StringName = &"native.npc.escort_runner"
const SON: StringName = &"native.npc.he_ping"
const ROBBER: StringName = &"native.npc.road_robber"
const WEI: StringName = &"native.npc.wei_zhizhong"
const CARD: StringName = &"native:city/zhenyuan_card"
const LETTER: StringName = &"native:city/he_letter"
const BUREAU: StringName = &"cloud.biaoju"
const BUREAU_POINT: StringName = &"cloud.biaoju.eroad2_entry"
const ROAD: StringName = &"canyon.road"
const ROAD_POINT: StringName = &"canyon.road.snow_arrival"
const HQ: StringName = &"city.biaoju"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_stranger, _test_handed, _test_fight_again, _test_freed_disciple]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.starts.when == JournalEntryDefinition.When.ANY, "faction.zhenyuan: a 势力 line that begins with the 镖单 or 拜师")
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(0, 6) == [&"take", &"road", &"robber", &"deliver", &"letter", &"ledger"], "its steps: %s" % [ids])
	var robber: StoryQuestDefinition.Step = quest.step(&"robber")
	_check(robber.is_branch() and robber.weight == StoryQuestDefinition.WEIGHT_SMALL and robber.options.size() == 2 and robber.options.all(func(option: StoryQuestDefinition.Option) -> bool: return not option.reward.deed.is_empty()), "the robber is a small choice of two, each a deed")
	_check(robber.objective.contains("家信") and robber.objective.contains("赏金"), "what either way costs is said before the choice")
	_check(quest.step(&"deliver").reward.rank_title == "镖头" and quest.step(&"deliver").reward.rank_family == &"family.zhenyuan" and not quest.step(&"deliver").reward.deed.is_empty(), "the 镖 delivered: 镖头 for 振远's own, a deed")
	_check(quest.step(&"letter").only_after == &"free", "the letter only for one who let him go")
	_check(quest.step(&"road").keeps.has(CARTER) and quest.step(&"road").keeps.has(SON) and quest.step(&"deliver").keeps.has(CARTER), "老周 and 贺平 are only knocked down while the 镖 is on the road")
	_check(quest.step(&"road").objective.contains("车马行不拉镖车"), "the road says the 车马行 will not take it")
	var carter: NpcDefinition = catalog.npc(CARTER)
	_check(carter.hooks().follows_every_way and carter.hooks().refuses_coach.contains("{npc}") and carter.hooks().moods.has("going"), "老周 follows every way, and no 车马行 takes his cart")
	var son: NpcDefinition = catalog.npc(SON)
	_check(son.hooks().spared_mark == "劫镖的后生倒了" and son.hooks().spared_mood == "beaten" and son.hooks().scene_mark == "见过劫镖", "贺平 spared: he talks")
	_check(son.talk().ask_confirm("交官府").contains("信") and son.talk().ask_confirm("走吧").contains("家信"), "both ways are asked first")
	for spawn_id: StringName in [&"native.biaoju.escort_runner", &"native.road.he_ping", &"native.road.robbers"]:
		_check(catalog.spawn(spawn_id) != null, "%s exists" % spawn_id)
	_check(catalog.spawn(&"native.road.he_ping").zone_id == ROAD and catalog.spawn(&"native.road.robbers").summoned, "贺平 on the 碎石小路, his two men summoned")
	for id: StringName in [CARD, LETTER]:
		_check(catalog.item(id) != null and catalog.item(id).quest_item, "%s is a quest item" % id)
	var gate: String = FileAccess.get_file_as_string("res://data/city/world.json")
	_check(gate.contains("\"mark\": \"有振远的名帖\"") and gate.contains("振远的名帖敲开了相国府") and gate.contains("骆家的名帖敲开了相国府"), "the 相国府's gate knows 振远's card")


## Neither the 镖单 nor 振远: no line, 陈剑秋 says nothing first, no cart in the yard.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	session.record_journal()
	_check(not state.quests.has("faction.zhenyuan#started"), "no 镖单, no family: the line has not begun")
	var bureau: WorldMapController = MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 3)
	_check(not state.marks.has("陈剑秋说了走镖") and _count_in(session, BUREAU, CARTER) == 0, "陈剑秋 does not speak first; no cart")
	_ask(bureau, _first(session, BUREAU, JIANQIU), "走镖")
	_check(not state.marks.has("接了振远的镖"), "走镖 asked by a stranger: no 镖")


## The 镖单 seen: the 镖 taken, the cart refused by the 车马行, the robbery (two lines and the fight), 贺平
## handed to the 官府, the 镖 in 京师 (the gold, the card; no rank for one not of 振远); the card at the 相国府.
func _test_handed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	state.marks["看过镖单"] = 1 # TEST-ONLY: 第二章
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan#started") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"take", "the 镖单 seen: the line begins")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("振远镖局"), "the 势力 column has the line")
	var bureau: WorldMapController = MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 3)
	_check(state.marks.get("陈剑秋说了走镖", 0) == 1, "陈剑秋 speaks first: a 镖 to 京师")
	_check(_count_in(session, BUREAU, CARTER) == 1, "老周 and his barrow in the yard")
	var jianqiu: NpcRuntimeState = _first(session, BUREAU, JIANQIU)
	_check(jianqiu.definition().talk().confirm_applies("走镖", state.marks) and jianqiu.definition().talk().ask_confirm("走镖").contains("车马行不拉镖车"), "走镖 is asked first, and says the road")
	_check(_said(_ask(bureau, jianqiu, "走镖"), "上路") and state.marks.get("接了振远的镖", 0) == 1 and not state.marks.has("以本局弟子走镖"), "the 镖 taken")
	_check(not jianqiu.definition().talk().confirm_applies("走镖", state.marks), "not asked again")
	var carter: NpcRuntimeState = _first(session, BUREAU, CARTER)
	_check(_said(_ask(bureau, carter, "上路"), "一步一步") and carter.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "上路: 老周 follows")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/take") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"road", "step take done; the road next")
	var taken: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.zhenyuan_taken)
	_check(taken.is_empty(), "the 镖 taken leaves what zhenyuan_taken writes: %s" % [taken])
	# No 车马行 takes the cart: out of the 镖局's door (老周 behind), at the 车马行 by the town's mouth.
	_check(await MapPlaces.take_passage(tree, bureau, &"cloud.biaoju.north"), "out of the 镖局")
	await _settle(tree)
	var town: WorldMapController = session.active_map() as WorldMapController
	_check(town != null and _count_in(session, &"cloud.eroad2", CARTER) == 1, "老周 came out behind: %s" % [_where(session, CARTER)])
	for visited: String in ["cloud.outdoor", "snow.outdoor"]:
		state.visited_maps[visited] = 1 # TEST-ONLY: been there
	town.give_new_item_to_player(&"es2:obj/money/silver") # TEST-ONLY: the fare
	_check(await _go_with(tree, session, &"cloud.entrance", CARTER) == town, "through the town to its mouth: %s" % FollowerWalk.failure)
	carter = _first(session, &"cloud.entrance", CARTER)
	_check(carter != null, "老周 came along to the town's mouth: %s" % [_where(session, CARTER)])
	var coach: CoachService = town.service(&"cloud.entrance.coach") as CoachService
	_check(coach != null and await MapPlaces.drive(tree, town, MapPlaces.service_spot(town, &"cloud.entrance.coach")) and coach.in_reach(), "at the 车马行")
	var rides: Array[CoachLines.Ride] = [] if coach == null else coach.rides()
	_check(not rides.is_empty(), "a ride to take")
	if not rides.is_empty():
		var refused: String = coach.choose(rides[0])
		_check(refused.contains("拉不起") and refused.contains("老周") and not ui.is_asking(), "the 车马行 will not take the cart: %s" % refused)
		_check(_said(_ask(town, carter, "等着"), "上路") and not carter.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "等着: 老周 stays with the cart")
		_check(coach.choose(rides[0]).is_empty() and ui.is_asking(), "without the cart following them the 车马行 asks as ever")
		ui.confirm_prompt.cancel_button.pressed.emit()
		await _settle(tree)
		_ask(town, carter, "上路")
	# The road walked, 老周 behind: north to 雪亭镇, along the 青石官道 to the 碎石小路.
	_check(await _to_road(tree, session) != null, "on the 碎石小路: %s" % FollowerWalk.failure)
	_check(_count_in(session, ROAD, CARTER) == 1 and _count_in(session, ROAD, SON) == 1, "老周 came along; 贺平 waits")
	# DECISIONS「势力线的仗」: the three fought with real numbers — a character who also explored, at
	# 第三章's arrival (the 镖单 is 第二章's; the cart walked to the road after it), a sword in hand; let go where they fall, dead where the sword kills outright.
	RealFight.ready_player(session, Arrival.exploring(&"main.chapter3"))
	await _until_fight(tree, session)
	_check(state.marks.get("见过劫镖", 0) == 1 and _count_in(session, ROAD, ROBBER) == 2, "his two lines, then his two men")
	_check(session.combat_encounter_coordinator().has_active_encounter(), "and the fight: robbers %s son %s abort %s" % [_all(session, ROAD, ROBBER).map(func(n: NpcRuntimeState) -> Array: return [n.flags().keys(), n.relationship.is_fighting()]), _all(session, ROAD, SON).map(func(n: NpcRuntimeState) -> Array: return [n.flags().keys()]), session.combat_encounter_coordinator().last_abort_detail()])
	_check(StoryKeeps.holds(state, SON, catalog.story_quests()) and StoryKeeps.holds(state, CARTER, catalog.story_quests()), "贺平 and 老周 can only be knocked down")
	var steps: int = RealFight.fight_out(session)
	await _settle(tree)
	_check(steps < RealFight.MAX_STEPS and RealFight.player_stands(session), "the fight to its end, the player standing (%d steps; 气 %d/%d)" % [steps, state.vitality.current, state.vitality.maximum])
	var road: WorldMapController = session.active_map() as WorldMapController
	var son: NpcRuntimeState = _first(session, ROAD, SON)
	_check(state.marks.get("劫镖的后生倒了", 0) == 1, "spared: 劫镖的后生倒了")
	# Knocked down (he can only be knocked down), he comes to on his own time: a player waits by him.
	var waited: int = RealFight.wait_until_up(session, son)
	await _settle(tree)
	_check(waited >= 0, "贺平 comes to (%d s)" % waited)
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/road") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"robber", "the road done; the choice next")
	_check(road.select_npc(son.character_id) and road.ask_topics_selected().has("爹") and road.ask_topics_selected().has("交官府"), "spared, he has something to say")
	_check(_said(_ask(road, son, "爹"), "兵部的人在岭上等着") and state.marks.get("贺平说了他爹", 0) == 1, "爹: 贺长庚, and the line of the letter")
	_check(son.definition().talk().confirm_applies("交官府", state.marks), "交官府 is asked first")
	_check(_said(_ask(road, son, "交官府"), "一伙的") and state.marks.get("劫镖的交了官", 0) == 1, "handed to the 官府")
	_check(_count_in(session, ROAD, SON) == 0 and session.player_held_item_ids().get(LETTER, false) == false, "taken away; no letter")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/robber/hand") and DeedLog.done(state, "把碎石小路上劫镖的后生交了官"), "the choice and its deed")
	# 京师: the cart comes in at the door.
	_check(await _down_to_hq(tree, session) != null, "down the 铁索 and on to the 振远总局: %s" % FollowerWalk.failure)
	_check(_count_in(session, HQ, CARTER) == 1, "老周 and the cart came in")
	var before: int = ui.log_lines().size()
	await _beats(tree, session, 3)
	_check(state.marks.get("镖交到了总局", 0) == 1 and state.marks.get("有振远的名帖", 0) == 1, "陈天星 takes the 镖: 镖交到了总局, 振远的名帖")
	_check(session.player_held_item_ids().get(CARD, false) == true and _count_in(session, HQ, CARTER) == 0, "the card in hand; 老周 gone to the back")
	_check(_bubbled(session, ui, before, "赏金"), "the 官府's gold, through 振远")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/deliver") and DeedLog.done(state, "替振远押了一趟镖到京师总局") and state.affiliation.family_title != "镖头", "deliver done; no 镖头 for one not of 振远")
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"ledger", "next: the 旧账 (振远 B); the letter step passed over")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.zhenyuan_delivered.bind(false))
	_check(missing.is_empty(), "played leaves what zhenyuan_delivered(hand) writes: %s" % [missing])
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("一路押到京师总局") and ui.standing_page.shown_text().contains("交给了官府"), "the 声望 page: %s" % ui.standing_page.shown_text())
	# The card at the 相国府's gate, before 第九章: the gate opens, 韦执中 has no business yet.
	var city: WorldMapController = MapPlaces.enter(session, &"city.xiangguo_gate", &"city.xiangguo_gate.yard_return")
	var knock: ActService = null if city == null else city.service(&"city.xiangguo_gate.knock") as ActService
	_check(knock != null and await MapPlaces.drive(tree, city, MapPlaces.service_spot(city, &"city.xiangguo_gate.knock")) and knock.in_reach(), "at the 相国府's gate")
	if knock != null:
		knock.interact()
		await _settle(tree)
	_check(state.marks.get("相国府开了门", 0) == 1 and state.marks.get("振远的名帖敲开了相国府", 0) == 1 and not state.marks.has("骆家的名帖敲开了相国府"), "the card opens the gate")
	var yard: WorldMapController = MapPlaces.enter(session, &"city.xiangguo_hall", &"city.xiangguo_hall.wei_zhizhong.1")
	await _settle(tree)
	var wei: NpcRuntimeState = _first(session, &"city.xiangguo_hall", WEI)
	_check(_said(_ask(yard, wei, "振远"), "没有镖要押") and not state.marks.has("相国见了名帖"), "before 第九章: 韦执中 has no business")
	state.marks["湖底一章"] = 1 # TEST-ONLY: 第九章 open
	_check(_said(_ask(yard, wei, "振远"), "他荐的人，老夫见") and state.marks.get("相国见了名帖", 0) == 1, "第九章: 振远's card is as good as 骆家's")
	state.marks["程不平写了信"] = 1 # TEST-ONLY: 第五章
	_check(_said(_ask(yard, wei, "奏本"), "本子老夫写了") and state.marks.get("相国写了奏本", 0) == 1, "and the 公文's way goes on")


## The fight lost (stopped where it stood): away and back, 贺平 falls on the player again.
func _test_fight_again(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.zhenyuan_taken(session)
	session.record_journal()
	MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 1)
	var bureau: WorldMapController = session.active_map() as WorldMapController
	_ask(bureau, _first(session, BUREAU, CARTER), "上路")
	_check(await _to_road(tree, session) != null, "on the 碎石小路: %s" % FollowerWalk.failure)
	_check(_count_in(session, ROAD, CARTER) == 1, "老周 came along: %s" % [_where(session, CARTER)])
	await _until_fight(tree, session)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "the fight")
	session.combat_encounter_coordinator().stop_where_it_stands() # TEST-ONLY: the player beaten off
	_check(not state.marks.has("劫镖的后生倒了"), "贺平 still stands")
	MapPlaces.enter(session, &"snow.sroad4", &"snow.sroad4.canyon_return") # TEST-ONLY: away
	await _settle(tree)
	MapPlaces.enter(session, ROAD, ROAD_POINT)
	await _until_fight(tree, session)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "back on the road: he falls on the player again")
	session.combat_encounter_coordinator().stop_where_it_stands()


## 振远's own, without the 镖单: the line from 拜师; the robber let go with the letter; 镖头; the letter to 陈天星
## (镖路查清了 without the 天邪 line); leaving 振远 ends the line.
func _test_freed_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.zhenyuan_joined(session)
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan#started") and not state.marks.has("看过镖单"), "拜师: the line begins without the 镖单")
	var bureau: WorldMapController = MapPlaces.enter(session, BUREAU, BUREAU_POINT)
	await _beats(tree, session, 3)
	_check(_said(_ask(bureau, _first(session, BUREAU, JIANQIU), "走镖"), "镖头") and state.marks.get("以本局弟子走镖", 0) == 1, "陈剑秋 to his own: 回来你就是镖头")
	_ask(bureau, _first(session, BUREAU, CARTER), "上路")
	state.marks["见过劫镖"] = 1 # TEST-ONLY: the robbery seen before
	_check(await _to_road(tree, session) != null and _count_in(session, ROAD, CARTER) == 1, "on the 碎石小路, 老周 behind: %s" % FollowerWalk.failure)
	await _beats(tree, session, 2)
	var road: WorldMapController = session.active_map() as WorldMapController
	var son: NpcRuntimeState = _first(session, ROAD, SON)
	session.npc_spared(son) # TEST-ONLY
	# On to 京师 before he is handed over or let go: 陈天星 does not take the 镖 yet.
	_check(await _down_to_hq(tree, session) != null, "in the 振远总局 too soon: %s" % FollowerWalk.failure)
	await _beats(tree, session, 3)
	var early: WorldMapController = session.active_map() as WorldMapController
	_check(not state.marks.has("镖交到了总局") and _count_in(session, HQ, CARTER) == 1, "the robber not settled: no delivery, 老周 waits with the cart")
	_check(_said(_ask(early, _first(session, HQ, TIANXING), "镖车"), "还没给个了结"), "陈天星: settle the robber first")
	_check(await _up_to_road(tree, session) != null and _count_in(session, ROAD, CARTER) == 1, "back up the 铁索 to the 碎石小路, 老周 behind: %s" % FollowerWalk.failure)
	await _beats(tree, session, 2)
	road = session.active_map() as WorldMapController
	son = _first(session, ROAD, SON)
	_check(son != null and not session.combat_encounter_coordinator().has_active_encounter(), "贺平 sits there; no scene again, no fight")
	_check(son.definition().talk().confirm_applies("走吧", state.marks), "走吧 is asked first")
	_check(_said(_ask(road, son, "走吧"), "拿给陈天星看") and state.marks.get("放走了劫镖的", 0) == 1 and session.player_held_item_ids().get(LETTER, false) == true, "let go: his father's letter")
	_check(not son.definition().talk().confirm_applies("交官府", state.marks), "the other way is closed")
	_check(await _down_to_hq(tree, session) != null and _count_in(session, HQ, CARTER) == 1, "in the 振远总局, 老周 behind: %s" % FollowerWalk.failure)
	await _beats(tree, session, 3)
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/deliver") and state.affiliation.family_title == "镖头", "振远's own: 镖头 (%s)" % state.affiliation.family_title)
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"letter", "next: the letter")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.zhenyuan_delivered.bind(true))
	_check(missing.is_empty(), "played leaves what zhenyuan_delivered(free) writes: %s" % [missing])
	var hq: WorldMapController = session.active_map() as WorldMapController
	var chen: NpcRuntimeState = _first(session, HQ, TIANXING)
	_check(hq.select_npc(chen.character_id), "陈天星 selected")
	var given: ItemHandlingResult = hq.give_to_selected(_carried(session, LETTER))
	_check(given != null and _said(given.lines, "背了二十年的锅") and state.marks.get("家信给了陈天星", 0) == 1 and state.marks.get("镖路查清了", 0) == 1, "the letter: 镖路查清了 without the 天邪 line")
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan/letter") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"ledger", "letter done; the 旧账 next")
	StoryFixtures.fonxan_joined(session) # TEST-ONLY: 改投封山
	session.record_journal()
	_check(state.quests.has("faction.zhenyuan#lapsed") and state.marks.get("振远的线断了", 0) == 1, "left 振远: the line lapsed")


## TEST-ONLY: the player walks to `zone_id` through the doors and ways out of town, waiting at each for
## `follower_id` to come up (FollowerWalk: go.c follow_me(), no handoff that carries him along for the suite).
func _go_with(tree: SceneTree, session: WorldSessionController, zone_id: StringName, follower_id: StringName) -> WorldMapController:
	var map: WorldMapController = await FollowerWalk.go_with(tree, session, zone_id, follower_id)
	await _settle(tree)
	return map


## From 绮云镇 north to 雪亭镇 and along the 青石官道 to the 碎石小路, 老周 behind. TEST-ONLY: the crazy dog of
## sroad4 would start a fight on the way (canyon_test's, snow_south_road_test's): sent off for good first (knocked
## down, it is up again long before the player has walked from 绮云镇).
func _to_road(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var snow: WorldMapController = session.world_map_of(&"snow.outdoor")
	var dog: NpcRuntimeState = null if snow == null else snow.find_resident_npc(&"snow.sroad4.crazy_dog.1.character")
	if dog != null and dog.exists_in_map:
		snow.npcs.leave_for_good(dog)
	return await _go_with(tree, session, ROAD, CARTER)


## From the 碎石小路 down the 铁索 to 天驼关 (the act, a way the player leads), then south along the 黄土大道
## to 京师's 振远总局, 老周 behind all the way (the road step's objective).
func _down_to_hq(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	if await FollowerWalk.act_with(tree, session, &"canyon.road.chain", CARTER) == null:
		return null
	return await _go_with(tree, session, HQ, CARTER)


## Back from 京师 to the 碎石小路: north to 天驼关's foot of the 铁索 and up it, 老周 behind.
func _up_to_road(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	if await _go_with(tree, session, &"canyon.canyon1", CARTER) == null:
		return null
	var road: WorldMapController = await FollowerWalk.act_with(tree, session, &"canyon.canyon1.chain", CARTER)
	await _settle(tree)
	return road


func _until_fight(tree: SceneTree, session: WorldSessionController) -> void:
	await _settle(tree)
	for second: int in 16:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if session.combat_encounter_coordinator().has_active_encounter():
			return


func _beats(tree: SceneTree, session: WorldSessionController, seconds: int) -> void:
	await _settle(tree)
	for second: int in seconds:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


## A line said since `before`, in the log or over someone's head.
func _bubbled(session: WorldSessionController, ui: SharedGameplayUI, before: int, part: String) -> bool:
	var lines: Array[String] = ui.log_lines()
	if lines.slice(mini(before, lines.size())).any(func(line: String) -> bool: return line.contains(part)):
		return true
	return session.player_runtime().state.marks.has("劫镖的交了官") and session.player_held_item_ids().get(&"es2:obj/money/gold", false) == true


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


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
				found.append([npc.world_location().zone_id, npc.exists_in_map, npc.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), npc.life_status])
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
	session.configure_source_entry("振远", CharacterState.GENDER_MALE)
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
