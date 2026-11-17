extends RefCounted

## 势力线第二批 晚月 B (计划 势力线第二批_计划.md §3 晚月 B, §7 第 2、6 行; DECISIONS「晚月 B」「总是只能击倒」
## 「收东西看几枚印记」): after the 宝衣, the 老妇's 心事 — her daughter, the 蒙面杀手. With no night (the 宝衣 left with
## 瑷伦) she is in the 内书房; after the night she hides in the bamboo grove by night. Asked「娘」she tells her story
## (the 北麓 道观, 六阴剑, 东方神教, 朱鸿雪 sending her home) and gives her 令牌: to her mother (the thanks once) or
## back to 朱鸿雪 (还令). Then 蓝止萍's scene in the 大厅 and the split: 庄规 (蓝止萍 takes her; 晚月庄 votes 颜违;
## the 老妇 speaks no more) or her mother's daughter (she stays unmasked in the 内书房; 晚月庄 votes the old 盟主).
## 执事 for 晚月庄's own; 晚月庄守岸 among the 终章's helpers; 第四章's night killer only knocked down.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.latemoon"
const MASTER: StringName = &"common.npc.dancer.master"
const OLD: StringName = &"latemoon.npc.room.old"
const KILLER: StringName = &"latemoon.npc.room.killer"
const NIGHT_KILLER: StringName = &"native.npc.cult_killer"
const GROVE_DAUGHTER: StringName = &"native.npc.latemoon_daughter"
const HOME_DAUGHTER: StringName = &"native.npc.latemoon_daughter_home"
const GOD: StringName = &"cloud.npc.god"
const TOKEN: StringName = &"es2:d/latemoon/room/npc/obj/token"
const WHIP_BOOK: StringName = &"es2:d/latemoon/room/npc/obj/whip_book"
const HALL: StringName = &"latemoon.latemoon1"
const HALL_POINT: StringName = &"latemoon.latemoon1.dance_arrival"
const STUDY: StringName = &"latemoon.room.lstudio"
const GROVE: StringName = &"latemoon.bamboo"
const GROVE_POINT: StringName = &"latemoon.bamboo.north_arrival"
const YARD: StringName = &"cloud.god2"
const YARD_POINT: StringName = &"cloud.god2.god.1"
const OUTSIDE: StringName = &"cloud.wroad0"
const OUTSIDE_POINT: StringName = &"cloud.wroad0.latemoon_return"
const LAKESIDE: StringName = &"village.lakeside"
const LAKE_POINT: StringName = &"village.lakeside.boat_return"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Array in [[_test_no_night_rule, CharacterState.GENDER_FEMALE], [_test_night_home, CharacterState.GENDER_MALE], [_test_night_fight, CharacterState.GENDER_MALE], [_test_thanks_once, CharacterState.GENDER_MALE]]:
		var session: WorldSessionController = await _session(tree, test[1])
		await (test[0] as Callable).call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"lost", &"score", &"shrine", &"robe_way", &"robe", &"heart", &"where", &"find_study", &"find_grove", &"token", &"split"], "its steps: %s" % [ids])
	_check(quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) == 2 and quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) == 1, "two small choices (the robe, the 令牌), one split")
	var where: StoryQuestDefinition.Step = quest.step(&"where")
	_check(where.weight == StoryQuestDefinition.WEIGHT_ROUTE and quest.step(&"find_study").only_after == &"study" and quest.step(&"find_grove").only_after == &"grove", "where she is: a route by 第四章's night")
	_check(quest.step(&"find_study").keeps.has(KILLER) and quest.step(&"find_grove").keeps.has(GROVE_DAUGHTER) and quest.step(&"split").keeps.has(KILLER) and quest.step(&"token").keeps.has(KILLER), "she is kept while the line needs her")
	_check(quest.step(&"find_grove").objective.contains("入夜"), "the grove by night is said")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.options.all(func(option: StoryQuestDefinition.Option) -> bool: return option.reward.rank_title == "执事" and option.reward.rank_family == &"family.latemoon" and not option.reward.deed.is_empty()), "both sides: 执事 for 晚月庄's own, a deed")
	_check(split.objective.contains("颜违") and split.objective.contains("旧盟主") and quest.step(&"token").objective.contains("只给一次"), "what each way costs is said before the choice")
	var master: NpcDefinition = catalog.npc(MASTER)
	var old: NpcDefinition = catalog.npc(OLD)
	_check(master.talk().ask_confirm("庄规").contains("颜违") and old.talk().ask_confirm("女儿").contains("旧盟主"), "庄规 and 女儿 are asked first, the vote said")
	_check(catalog.npc(GOD).talk().ask_confirm("还令").contains("谢礼"), "还令 is asked first")
	var gifts: Array = old.dealings().object_rules
	_check(gifts.any(func(rule: NpcObjectRule) -> bool: return not rule.ask.is_empty() and rule.giver_marks == ["她说了来历"]), "the 令牌 given to her mother is asked first (giver_marks)")
	var hooks: NpcHooks = catalog.npc(NIGHT_KILLER).hooks()
	_check(hooks.always_kept and hooks.spared_leave and hooks.spared_drop == TOKEN, "第四章's night killer: only knocked down, then she drops the 令牌 and flees")
	for npc_id: StringName in [&"common.npc.taoist.taolord", &"native.npc.xuan_mingzi_cliff"]:
		var talk: NpcTalk = catalog.npc(npc_id).talk()
		_check(not talk.listed_for("道童", {}) and talk.listed_for("道童", {"她说了来历": 1}), "%s: 道童 for one who heard her story" % npc_id)
	for key: String in ["latemoon.night", "latemoon.split", "latemoon.rule_day"]:
		_check(catalog.conditions().has(key), "the named condition %s" % key)
	var epilogue: String = FileAccess.get_file_as_string("res://data/story/epilogue.json")
	_check(epilogue.contains("内书房的老妇再没有开过口") and epilogue.contains("不再蒙面"), "the 尾声's 晚月庄 card: both sides")
	var finale: String = FileAccess.get_file_as_string("res://data/story/finale.json")
	_check(finale.contains("晚月庄（蓝止萍）守岸") and finale.contains("晚月庄（老妇母女）守岸"), "the 点将: 晚月庄守岸")


## A woman of 晚月庄, the 宝衣 left with 瑷伦 (no night): she is in the 内书房; her story; the 令牌 to her mother (the
## thanks once); the 大厅's scene; 庄规: she is taken, 执事, 晚月庄 votes 颜违, the 老妇 silent.
func _test_no_night_rule(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter3_rescued(session)
	StoryFixtures.latemoon_joined(session)
	StoryFixtures.chapter4_kept(session)
	StoryFixtures.latemoon_robe_settled(session)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"heart", "the 老妇's 心事 next")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_count_in(session, HALL, NIGHT_KILLER) == 0, "no night: nobody in the 前厅")
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 2)
	var old: NpcRuntimeState = _first(session, STUDY, OLD)
	var killer: NpcRuntimeState = _first(session, STUDY, KILLER)
	_check(old != null and killer != null, "the 老妇 and the 蒙面杀手 in the 内书房")
	if old == null or killer == null:
		return
	_check(not NpcInquiry.topics(killer.definition(), killer.forgotten_topics(), state.marks).has("娘"), "娘 not yet")
	var said: Array[String] = _ask(hall, old, "心事")
	_check(_said(said, "私生女") and _said(said, "就在这屋里") and state.marks.get("老妇说了女儿", 0) == 1, "心事: ES2's words, then: ask her「娘」, she is in this room: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.latemoon/where/study") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"find_study", "no night: find her in the 内书房")
	_check(StoryKeeps.keeps(state, catalog.npc(KILLER), catalog.story_quests()) and hall.story_keeps(killer.character_id), "she can only be knocked down now")
	_check(NpcInquiry.topics(killer.definition(), killer.forgotten_topics(), state.marks).has("娘"), "娘 listed")
	said = _ask(hall, killer, "娘")
	_check(_said(said, "北麓") and _said(said, "六阴追魂剑") and _said(said, "朱鸿雪派我回晚月庄") and _said(said, "住了三年") and not _said(said, "是我杀的"), "her story (no night): %s" % [said])
	_check(state.marks.get("她说了来历", 0) == 1 and session.player_held_item_ids().get(TOKEN, false) == true, "her 令牌 in hand")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"token", "the 令牌 next")
	_check(_said(_ask(hall, old, "令牌"), "为证她还活着"), "令牌: give it me")
	_check(hall.select_npc(old.character_id) and hall.give_to_selected(_carried(session, TOKEN)) != null, "given to her")
	_check(state.marks.get("令牌给了老妇", 0) == 1 and state.marks.get("老妇谢过令牌", 0) == 1 and session.player_held_item_ids().get(TOKEN, false) == false, "taken, the thanks given")
	hall.give_new_item_to_player(TOKEN) # TEST-ONLY: another (梦玉楼's)
	hall.select_npc(old.character_id)
	hall.give_to_selected(_carried(session, TOKEN))
	_check(session.player_held_item_ids().get(TOKEN, false) == true and _said(_recent(session.shared_ui(), 3), "已经在我这里"), "a second is refused")
	_check(not catalog.npc(GOD).talk().confirm_applies("还令", state.marks), "还令 asks no more")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/token/mother") and DeedLog.done(state, "把蒙面杀手的令牌交给了她娘") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "the 令牌: her mother; the split next")
	var lines: Array[String] = await _scene(tree, session)
	_check(_said(lines, "住了三年") and _said(lines, "攥得更紧") and _said(lines, "她是我女儿") and _said(lines, "问我「庄规」") and not _said(lines, "前厅死了两个丫头"), "the 大厅 (no night): %s" % [lines])
	hall = session.active_map() as WorldMapController
	_check(_said(lines, "往内书房走") and _count_in(session, STUDY, OLD) == 1 and _count_in(session, STUDY, KILLER) == 1, "the 老妇 and her daughter came to the 大厅 and walked home")
	var master: NpcRuntimeState = _first(session, HALL, MASTER)
	_check(catalog.npc(MASTER).talk().confirm_applies("庄规", state.marks) and NpcInquiry.topics(catalog.npc(OLD), [], state.marks).has("女儿"), "庄规 and 女儿 now")
	said = _ask(hall, master, "庄规")
	_check(_said(said, "带走") and state.marks.get("晚月庄依了庄规", 0) == 1 and _count_in(session, STUDY, KILLER) == 0, "庄规: she is taken away from the 内书房 at once: %s" % [said])
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 1)
	_check(not catalog.npc(OLD).talk().confirm_applies("女儿", state.marks) and _said(_ask(hall, _first(session, STUDY, OLD), "女儿"), "没有开口") and not state.marks.has("她回了晚月庄"), "the other way is closed; the 老妇 silent")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/split/by_rule") and StoryQuestLog.is_done(state, catalog.story_quest(QUEST)) and state.affiliation.family_title == "执事", "庄规: the line done, 执事 (%s)" % state.affiliation.family_title)
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	_check(_holds("assembly.latemoon.yan", state, held) and _holds("assembly.latemoon.stated", state, held) and not _holds("assembly.latemoon.old", state, held), "晚月庄 votes 颜违")
	# Next visit: the 老妇 silent in the 内书房, her daughter gone.
	MapPlaces.enter(session, OUTSIDE, OUTSIDE_POINT)
	await _settle(tree)
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 3)
	old = _first(session, STUDY, OLD)
	_check(old != null and old.has_flag(StringName(NpcMood.FLAG_PREFIX + "silent")) and _count_in(session, STUDY, KILLER) == 0 and _count_in(session, STUDY, HOME_DAUGHTER) == 0, "the 老妇 silent; nobody beside her")
	_check(_said(_ask(hall, old, "心事"), "没有开口"), "心事: no answer")
	# 虹台: 蓝止萍 gives the vote to one who kept 庄规.
	state.marks["终章"] = 1 # TEST-ONLY
	_check(hall.place_player(HALL, MapPlaces.zone_spot(hall, HALL)), "TEST-ONLY: back in the 大厅")
	await _beats(tree, session, 1)
	said = _ask(hall, _first(session, HALL, MASTER), "虹台")
	_check(_said(said, "投颜违") and state.marks.get("晚月庄肯听你的", 0) == 1, "虹台: 颜违, and the vote is yours if you want it: %s" % [said])
	state.marks["晚月庄肯改投"] = 1 # TEST-ONLY: told before the split that the vote could change
	_check(not catalog.npc(MASTER).talk().confirm_applies("改投", state.marks) and _said(_ask(hall, _first(session, HALL, MASTER), "改投"), "跟着庄规走"), "改投: no change after the split")
	state.marks.erase("晚月庄肯改投")
	_ask(hall, _first(session, HALL, MASTER), "这一票")
	held = session.player_held_item_ids()
	_check(_holds("assembly.latemoon.self", state, held) and not _holds("assembly.latemoon.yan", state, held), "这一票: 晚月庄 backs you")
	# The 终章's helpers: 晚月庄守岸 counts (TEST-ONLY: a player with 霍铮 and the 冰龙 untouched, two bands).
	var bands := CharacterState.new()
	bands.marks["霍铮回了寨"] = 1
	_check(not _holds("finale.helpers", bands, held), "two bands are not enough")
	for mark: String in ["晚月庄依了庄规", "她回了晚月庄"]:
		bands.marks[mark] = 1
		_check(_holds("finale.helpers", bands, held), "晚月庄守岸 (%s) is the third band" % mark)
		bands.marks.erase(mark)
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.latemoon_settled.bind(true), ["终章", "晚月庄肯听你的", "晚月庄听你的", "晚月庄表了态", "老妇不说话了"])
	_check(missing.is_empty(), "played leaves what latemoon_settled(rule) writes: %s" % [missing])


## A man, the 宝衣 carried out and brought home (the night): the grove by night; her story of that night; the 令牌
## back to 朱鸿雪 (a way into 东方神教 for one not of it); the scene; her mother's daughter: unmasked in the 内书房.
func _test_night_home(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter4_taken(session)
	StoryFixtures.latemoon_guardian(session)
	var hall: WorldMapController = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _settle(tree)
	StoryFixtures.latemoon_robe_settled(session, true)
	session.record_journal()
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 2)
	_check(_count_in(session, STUDY, KILLER) == 0, "after the night the 内书房 has no 蒙面杀手")
	var said: Array[String] = _ask(hall, _first(session, STUDY, OLD), "心事")
	_check(_said(said, "私生女") and _said(said, "竹林") and state.marks.get("老妇说了女儿", 0) == 1, "心事: the bamboo grove by night: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.latemoon/where/grove") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"find_grove", "the night: find her in the grove")
	# By day nobody; by night she is there.
	if session.day_phase_id() != &"morning":
		_check(session.wait_until_phase([&"morning"]), "morning")
	MapPlaces.enter(session, GROVE, GROVE_POINT)
	await _settle(tree)
	_check(_count_in(session, GROVE, GROVE_DAUGHTER) == 0, "the grove by day: nobody")
	_check(session.wait_until_phase([&"night"]), "night")
	MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_count_in(session, HALL, NIGHT_KILLER) == 0, "the 前厅's killer is gone once the 老妇 spoke")
	var grove: WorldMapController = MapPlaces.enter(session, GROVE, GROVE_POINT)
	await _settle(tree)
	var daughter: NpcRuntimeState = _first(session, GROVE, GROVE_DAUGHTER)
	_check(daughter != null and StoryKeeps.keeps(state, daughter.definition(), catalog.story_quests()), "by night she is there, and kept")
	if daughter == null:
		return
	_check(grove.place_player(GROVE, grove.runtime_body_for_character(daughter.character_id).global_position + Vector2(0, 40)), "TEST-ONLY: beside her")
	await _settle(tree)
	said = _ask(grove, daughter, "娘")
	_check(_said(said, "北麓") and _said(said, "是我杀的") and _said(said, "回内书房") and state.marks.get("她说了来历", 0) == 1 and session.player_held_item_ids().get(TOKEN, false) == true, "her story of that night, her 令牌: %s" % [said])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"token", "the 令牌 next")
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_count_in(session, STUDY, KILLER) == 1, "she is back in the 内书房 beside her mother")
	# 朱鸿雪: 还令 — for one not of 东方神教, a way in.
	state.progression.combat_experience = maxi(state.progression.combat_experience, 2000) # TEST-ONLY: past god.c's 1000
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(god != null and catalog.npc(GOD).talk().confirm_applies("还令", state.marks) and NpcInquiry.topics(god.definition(), god.forgotten_topics(), state.marks).has("还令"), "还令 listed and asked first")
	said = _ask(yard, god, "还令")
	_check(_said(said, "她还活着") and state.marks.get("令牌还了神教", 0) == 1 and session.player_held_item_ids().get(TOKEN, false) == false, "还令: the 令 back: %s" % [said])
	_check(state.marks.get("朱鸿雪说了令牌", 0) == 1 and NpcInquiry.topics(god.definition(), god.forgotten_topics(), state.marks).has("接令"), "one not of the 神教 may take up the 令 now")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/token/cult") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "the 令牌: 神教; the split next")
	yard.give_new_item_to_player(TOKEN) # TEST-ONLY
	var lines: Array[String] = await _scene(tree, session)
	_check(_said(lines, "前厅死了两个丫头") and _said(lines, "你还给了神教") and _said(lines, "她是我女儿"), "the 大厅 (the night, the 令 returned): %s" % [lines])
	hall = session.active_map() as WorldMapController
	_check(_said(_ask(hall, _first(session, HALL, MASTER), "庄里的事"), "去内书房问老人家"), "蓝止萍 sends the player to the 内书房 for 女儿")
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 1)
	var old: NpcRuntimeState = _first(session, STUDY, OLD)
	hall.select_npc(old.character_id)
	hall.give_to_selected(_carried(session, TOKEN))
	_check(session.player_held_item_ids().get(TOKEN, false) == true, "her mother will not take another 令牌 now")
	said = _ask(hall, old, "女儿")
	_check(_said(said, "不送第二回") and state.marks.get("她回了晚月庄", 0) == 1, "女儿: she stays: %s" % [said])
	_check(_count_in(session, STUDY, HOME_DAUGHTER) == 1 and _count_in(session, STUDY, KILLER) == 0, "the mask off at once")
	_check(not catalog.npc(MASTER).talk().confirm_applies("庄规", state.marks), "庄规 is closed")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/split/brought_home") and StoryQuestLog.is_done(state, catalog.story_quest(QUEST)) and (session.player_runtime() as WorldPlayerRuntimeState).shown_title() == "晚月庄护法", "brought home: the line done; a 护法 has no 执事")
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	_check(_holds("assembly.latemoon.old", state, held) and not _holds("assembly.latemoon.yan", state, held), "晚月庄 votes the old 盟主")
	MapPlaces.enter(session, OUTSIDE, OUTSIDE_POINT)
	await _settle(tree)
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 3)
	old = _first(session, STUDY, OLD)
	_check(_count_in(session, STUDY, HOME_DAUGHTER) == 1 and _count_in(session, STUDY, KILLER) == 0 and old.has_flag(StringName(NpcMood.FLAG_PREFIX + "together")), "unmasked beside her mother: %s" % [_where(session, HOME_DAUGHTER)])
	# 站了朱鸿雪: she knows the 神教 lost one.
	state.marks["站了朱鸿雪"] = 1 # TEST-ONLY
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _beats(tree, session, 3)
	_check(state.marks.get("朱鸿雪说了少一个人", 0) == 1, "朱鸿雪: the 神教 is one short")
	# The 终章: 晚月庄守岸 — the mother and her daughter by the lake.
	state.quests["main.finale#started"] = state.quests.size() + 1 # TEST-ONLY
	MapPlaces.enter(session, LAKESIDE, LAKE_POINT)
	await _settle(tree)
	_check(_count_in(session, LAKESIDE, &"native.npc.old_woman_lake") == 1 and _count_in(session, LAKESIDE, &"native.npc.daughter_lake") == 1 and _count_in(session, LAKESIDE, &"native.npc.lan_zhiping_lake") == 0, "by the lake: the 老妇 and her daughter")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.latemoon_settled.bind(false), ["站了朱鸿雪", "朱鸿雪说了少一个人", "朱鸿雪说了令牌", "老妇说了回来", "晚月庄护法", "该问瑷伦还衣", "宝衣回了庄", "老妇说了衣回", "瑷伦叹过", "老妇说了拦", "安妮儿记下了"])
	_check(missing.is_empty(), "played leaves what latemoon_settled(home) writes: %s" % [missing])


## 第四章's night: the killer in the 前厅 falls and is spared — the 令牌 on the floor, she flees; she cannot be killed.
func _test_night_fight(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter4_taken(session)
	session.record_journal()
	_full(session.player_runtime())
	var hall: WorldMapController = MapPlaces.enter(session, &"latemoon.entrance", &"latemoon.entrance.cloud_entry")
	await _settle(tree)
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var killer: NpcRuntimeState = _first(session, HALL, NIGHT_KILLER)
	_check(killer != null and hall.story_keeps(killer.character_id), "the night killer stands in the 前厅, kept")
	if killer == null:
		return
	killer.character_state.vitality.current = 1 # TEST-ONLY: one blow is past her
	killer.character_state.vitality.effective = 1
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not coordinator.has_active_encounter():
		hall.select_npc(killer.character_id)
		hall.attack_selected()
	var rounds: int = _fight_out(session)
	await _settle(tree)
	_check(not coordinator.has_active_encounter(), "the fight over in %d rounds" % rounds)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("还有用")), "the battle says why the player stopped")
	session.record_journal()
	_check(state.marks.get("放过了神教杀手", 0) == 1 and state.marks.get("神教杀手倒了", 0) == 1, "she fell and was spared, not killed")
	await _beats(tree, session, 2)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("从窗口翻了出去")) and _count_in(session, HALL, NIGHT_KILLER) == 0 and not hall.floor_item_of(TOKEN, HALL).is_empty(), "she fled; her 令牌 lies on the floor")


## The 令牌 given before the line (ES2's chain): the thanks once; a second token refused, given back.
func _test_thanks_once(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(hall.place_player(STUDY, MapPlaces.zone_spot(hall, STUDY)), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 2)
	var old: NpcRuntimeState = _first(session, STUDY, OLD)
	hall.give_new_item_to_player(TOKEN) # TEST-ONLY: 梦玉楼's, or the 蒙面杀手's corpse
	hall.select_npc(old.character_id)
	hall.give_to_selected(_carried(session, TOKEN))
	_check(session.player_held_item_ids().get(WHIP_BOOK, false) == true and state.marks.get("老妇谢过令牌", 0) == 1 and not state.marks.has("令牌给了老妇"), "ES2's thanks: the 寒雪鞭法 book (not the line's 令牌)")
	hall.give_new_item_to_player(TOKEN) # TEST-ONLY
	hall.select_npc(old.character_id)
	hall.give_to_selected(_carried(session, TOKEN))
	_check(session.player_held_item_ids().get(TOKEN, false) == true and _said(_recent(session.shared_ui(), 3), "只给一回"), "a second: refused (ES2 thanked every time)")
	state.marks["该问老妇心事"] = 1 # TEST-ONLY: the line at the 老妇
	state.marks["老妇说了女儿"] = 1
	hall.select_npc(old.character_id)
	hall.give_to_selected(_carried(session, TOKEN))
	_check(session.player_held_item_ids().get(TOKEN, false) == true and _said(_recent(session.shared_ui(), 3), "你见过她了么"), "before her story: not the 令牌, her")


## TEST-ONLY: from outside the manor into the 大厅 (the scene starts as the player comes in), and through to its end.
func _scene(tree: SceneTree, session: WorldSessionController) -> Array[String]:
	var ui: SharedGameplayUI = session.shared_ui()
	MapPlaces.enter(session, OUTSIDE, OUTSIDE_POINT)
	await _settle(tree)
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.scene_held() and hall.scene_running() and session.player_runtime().state.marks.get("大厅说起了庄规", 0) == 1, "the scene holds the player as they come in, and is marked seen")
	for second: int in 60:
		if not hall.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not hall.scene_running() and not session.scene_held(), "the scene is over")
	return _recent(ui, 30)


## TEST-ONLY: the 东方神教杀手 the night left in the 前厅 sent off, so nobody fights in the hall.
func _quiet(session: WorldSessionController, map: WorldMapController) -> WorldMapController:
	for killer: NpcRuntimeState in _all(session, HALL, NIGHT_KILLER):
		map.npcs.leave_for_good(killer)
	return map


func _holds(condition: String, state: CharacterState, held: Dictionary[StringName, bool]) -> bool:
	return JournalLog.holds(GameContent.catalog().conditions()[condition], state, {}, held)


func _fight_out(session: WorldSessionController) -> int:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 1500:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	return rounds


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = maxi(player.state.progression.combat_experience, 10000000) # TEST-ONLY: the blows land


func _beats(tree: SceneTree, session: WorldSessionController, seconds: int) -> void:
	await _settle(tree)
	for second: int in seconds:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


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
				found.append([npc.world_location().zone_id, npc.exists_in_map, npc.life_status])
	return found


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	return _all(session, zone_id, definition_id).size()


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var found: Array[NpcRuntimeState] = _all(session, zone_id, definition_id)
	return null if found.is_empty() else found[0]


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("晚月", gender)
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
