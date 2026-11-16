extends RefCounted

## 势力线第二批 晚月 A (计划 势力线第二批_计划.md §3 晚月 A, §2 第 1 条, §7 第 3 行; DECISIONS「晚月 A」「问话给头衔」): the line
## shows for 晚月庄's own and for a 晚月庄护法 — 蓝止萍's word (asked first, never of her own disciples) to one who stood
## 瑷伦's three lashes and saw the 宝衣 through. 沧海龙吟: 蓝止萍 names it, the 图 in the 书房 and the 舞曲谱 put
## together, danced before 区冥 in the 佛堂 — by a woman herself, for a man by 芳绫 who follows or 莫欣芳 who comes
## (大弟子 for 晚月庄's own; 区冥 no longer stares the dancer down). The 宝衣 after 第四章: carried out and brought home
## (瑷伦 守衣人 again, the 凤凰 back, the 老妇 eased, 湖底 asked as of one who left it with her, the readers of
## latemoon.robe_home) or kept; left with 瑷伦 or given to 安妮儿, the step passes with a line. Leaving 晚月庄 ends the
## line of its own.

const MapPlaces := preload("res://tests/support/map_places.gd")
const OldPineTestMap := preload("res://tests/support/oldpine_test_map.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.latemoon"
const MASTER: StringName = &"common.npc.dancer.master"
const ELON: StringName = &"latemoon.npc.room.elon"
const ANNIE: StringName = &"latemoon.npc.room.annihi"
const OLD: StringName = &"latemoon.npc.room.old"
const GIRL: StringName = &"latemoon.npc.girl"
const FUNLIN: StringName = &"latemoon.npc.funlin"
const SHINFUN: StringName = &"latemoon.npc.upstar.shinfun"
const STATUE: StringName = &"latemoon.npc.upstar.statue"
const FIREANGEL: StringName = &"latemoon.npc.room.fireangel"
const ROBE: StringName = &"native:latemoon/cold_robe"
const BOOK: StringName = &"es2:d/latemoon/obj/book"
const HALL: StringName = &"latemoon.latemoon1"
const HALL_POINT: StringName = &"latemoon.latemoon1.dance_arrival"
const SHRINE: StringName = &"latemoon.upstar.uproom"
const UPPER_POINT: StringName = &"latemoon.upstar.upstar1.stairs_arrival"
const DANCE: StringName = &"latemoon.upstar.uproom.dance"
const PROXY: StringName = &"latemoon.upstar.uproom.proxy_dance"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Array in [[_test_guardian_home, CharacterState.GENDER_MALE], [_test_disciple, CharacterState.GENDER_FEMALE], [_test_kept_on, CharacterState.GENDER_MALE], [_test_given_to_annie, CharacterState.GENDER_FEMALE]]:
		var session: WorldSessionController = await _session(tree, test[1])
		await (test[0] as Callable).call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.starts.when == JournalEntryDefinition.When.ANY, "faction.latemoon: a 势力 line that begins with 拜师 or the 护法")
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"lost", &"score", &"shrine", &"robe_way", &"robe", &"heart"], "its steps: %s" % [ids])
	if quest == null:
		return
	_check(quest.step(&"shrine").reward.rank_title == "大弟子" and quest.step(&"shrine").reward.rank_family == &"family.latemoon" and not quest.step(&"shrine").reward.deed.is_empty(), "沧海龙吟 danced: 大弟子 for 晚月庄's own, a deed")
	_check(quest.step(&"score").reward.marks == ["沧海龙吟的步子"], "the 图 and the 谱 together teach the dance")
	var way: StoryQuestDefinition.Step = quest.step(&"robe_way")
	_check(way.weight == StoryQuestDefinition.WEIGHT_ROUTE and way.options.size() == 4 and way.objective.contains("第四章"), "where the 宝衣 is: a route the main story picks, waiting on 第四章")
	var robe: StoryQuestDefinition.Step = quest.step(&"robe")
	_check(robe.weight == StoryQuestDefinition.WEIGHT_SMALL and robe.only_after == &"carried" and robe.options.size() == 2 and robe.options.all(func(option: StoryQuestDefinition.Option) -> bool: return not option.reward.deed.is_empty()), "the robe home or kept: a small choice of two, each a deed, only for one who carries it")
	_check(robe.objective.contains("寒气") and robe.objective.contains("凤凰"), "what either way costs is said before the choice")
	_check(quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) == 1 and quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) == 0, "晚月 A: one small choice; the split is 晚月 B's")
	_check(catalog.conditions().has("latemoon.robe_home"), "the named condition latemoon.robe_home")
	var master: NpcDefinition = catalog.npc(MASTER)
	_check(master.talk().ask_confirm("护法").contains("不授辈分") and master.talk().confirm_applies("护法", {"宝衣一章": 1, "接下了瑷伦三鞭": 1}) and not master.talk().confirm_applies("护法", {"宝衣一章": 1, "接下了瑷伦三鞭": 1}, &"family.latemoon"), "护法 is asked first, but not of 晚月庄's own")
	var elon: NpcDefinition = catalog.npc(ELON)
	_check(elon.talk().confirm_applies("湖底", {"宝衣回了庄": 1, "岚城一章": 1}) and elon.talk().confirm_applies("湖底", {"瑷伦守到决战": 1, "岚城一章": 1}) and not elon.talk().confirm_applies("湖底", {"带走了宝衣": 1, "岚城一章": 1}), "湖底 is asked first of one whose robe 瑷伦 keeps, either way it came to her")
	_check(elon.talk().ask_confirm("还衣").contains("寒气") and elon.talk().ask_confirm("留着").contains("护佑"), "还衣 and 留着 are asked first")
	_check(catalog.service(DANCE) != null and catalog.service(PROXY) != null, "the 佛堂's dance and 请人替跳")
	var epilogue: String = FileAccess.get_file_as_string("res://data/story/epilogue.json")
	_check(epilogue.contains("又被人送了回来") and epilogue.contains("\"cond\": \"latemoon.robe_home\""), "the 尾声's 晚月庄 card reads the robe home")
	var finale: String = FileAccess.get_file_as_string("res://data/story/finale.json")
	_check(finale.contains("\"cond\": \"latemoon.robe_home\""), "the 点将's 宝衣在瑷伦身上 reads the robe home")


## A man of no family, the robe carried out (第四章): 护法 (the title), 沧海龙吟 put together and danced by 芳绫, the
## robe home: 瑷伦 守衣人, the 凤凰 back, the 老妇 eased, 湖底, latemoon.robe_home.
func _test_guardian_home(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter4_taken(session)
	session.record_journal()
	_check(not state.quests.has("faction.latemoon#started"), "a man of no family: no line yet")
	var hall: WorldMapController = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _beats(tree, session, 2)
	var master: NpcRuntimeState = _first(session, HALL, MASTER)
	_check(master != null and master.definition().talk().confirm_applies("护法", state.marks, state.family.family_id), "护法 asked first of him")
	_check(_said(_ask(hall, master, "庄里的事"), "不劳外人") and not state.marks.has("蓝止萍说了沧海龙吟"), "庄里的事 is not his yet")
	var said: Array[String] = _ask(hall, master, "护法")
	_check(_said(said, "男人都不是好东西") and _said(said, "三鞭") and state.marks.get("晚月庄护法", 0) == 1, "护法: %s" % [said])
	_check((session.player_runtime() as WorldPlayerRuntimeState).shown_title() == "晚月庄护法", "the title: %s" % (session.player_runtime() as WorldPlayerRuntimeState).shown_title())
	_check(not master.definition().talk().confirm_applies("护法", state.marks, state.family.family_id), "not asked again")
	session.record_journal()
	_check(state.quests.has("faction.latemoon#started") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"lost", "the line begins")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("晚月庄"), "the 势力 column has the line")
	said = _ask(hall, master, "庄里的事")
	_check(_said(said, "沧海龙吟") and _said(said, "请芳绫或者欣芳") and state.marks.get("蓝止萍说了沧海龙吟", 0) == 1, "庄里的事: the lost dance, and for a man who dances it: %s" % [said])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"score", "the 图 and the 谱 next")
	# The 图 in the 书房 (昭仪 points at it) and the 谱 (TEST-ONLY: in hand, as 莫欣芳's chain gives it).
	_check(hall.place_player(&"latemoon.latebook", MapPlaces.zone_spot(hall, &"latemoon.latebook")), "TEST-ONLY: in the 书房")
	await _beats(tree, session, 1)
	_check(_said(_ask(hall, _first(session, &"latemoon.latebook", GIRL), "沧海龙吟"), "仔细看那几位姐姐的姿势"), "昭仪: the steps are on the 图")
	_check(hall.select_landmark(&"latemoon.latebook.landmark.picture") and hall.inspect_selected() and state.marks.get("看过沧海龙吟图", 0) == 1, "the 图 looked at")
	ui.dismiss_current_panel()
	session.record_journal()
	_check(not state.quests.has("faction.latemoon/score"), "the 图 alone is not the dance")
	hall.give_new_item_to_player(BOOK) # TEST-ONLY: the 舞曲谱 (莫欣芳 asked, the 石床 searched)
	session.record_journal()
	_check(state.quests.has("faction.latemoon/score") and state.marks.get("沧海龙吟的步子", 0) == 1, "the 图 and the 谱: the dance known")
	# 芳绫 follows to the 佛堂 (TEST-ONLY: brought up the stairs as she would walk).
	var funlin: NpcRuntimeState = _first(session, &"latemoon.latemoon6", FUNLIN)
	_check(hall.place_player(&"latemoon.latemoon6", MapPlaces.zone_spot(hall, &"latemoon.latemoon6")), "TEST-ONLY: at the 禁闭房")
	await _beats(tree, session, 1)
	said = _ask(hall, funlin, "替跳")
	_check(_said(said, "沧海龙吟") and funlin.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "芳绫 follows for 沧海龙吟 (she danced the 冰匣 open before): %s" % [said])
	state.spirit = CharacterResourceState.new(300, 300, 300) # TEST-ONLY
	var upper: WorldMapController = MapPlaces.enter(session, &"latemoon.upstar.upstar1", UPPER_POINT)
	await _settle(tree)
	if _count_in(session, &"latemoon.upstar.upstar1", FUNLIN) == 0:
		_check(session.bring_npc_onto(funlin, hall, upper, &"latemoon.upstar.upstar1"), "TEST-ONLY: 芳绫 brought along (she follows every way)")
	var shrine: WorldMapController = await _into_shrine(tree, session, upper)
	_check(state.spirit.current == 280, "区冥 stares down one not of the dancers: 20 sen (%d)" % state.spirit.current)
	funlin = _first(session, &"latemoon.upstar.upstar1", FUNLIN)
	if funlin != null:
		funlin.set_world_location(shrine.location_for_zone(SHRINE)) # TEST-ONLY: she followed in (the suite does not walk her)
	var floor_dance: DanceService = shrine.service(DANCE) as DanceService
	_check(_stand(shrine, DANCE) and floor_dance.in_reach(), "before the 神位")
	_check(floor_dance.known_steps().size() == 1 and floor_dance.known_steps()[0].name == "沧海龙吟", "沧海龙吟 offered")
	var clumsy: DanceDefinition.Result = floor_dance.dance(floor_dance.known_steps()[0])
	_check(clumsy.act == null and _said(clumsy.lines, "不得要领") and not state.marks.has("跳成了沧海龙吟"), "a man's own 沧海龙吟: 不得要领")
	var proxy: ActService = shrine.service(PROXY) as ActService
	_check(_stand(shrine, PROXY) and proxy.in_reach() and proxy.verb() == "请人替跳", "请人替跳 in reach")
	proxy.interact()
	await _settle(tree)
	var lines: Array[String] = _recent(ui)
	_check(_said(lines, "看我的") and _said(lines, "眉间亮了一下") and state.marks.get("跳成了沧海龙吟", 0) == 1, "芳绫 dances 沧海龙吟: %s" % [lines])
	session.record_journal()
	_check(state.quests.has("faction.latemoon/shrine") and DeedLog.done(state, "在区冥的神位前跳回了失传的沧海龙吟") and state.affiliation.family_title != "大弟子", "danced: the deed; no rank for a 护法")
	var danced: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.latemoon_danced, ["晚月庄护法", "芳绫跟你去了"])
	_check(danced.is_empty(), "played leaves what latemoon_danced writes: %s" % [danced])
	# The robe on him: the step goes to 瑷伦's question.
	_check(state.quests.has("faction.latemoon/robe_way/carried") and state.marks.get("该问瑷伦还衣", 0) == 1 and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"robe", "the robe on him: 瑷伦 asks")
	# 区冥 again: no stare for one who danced before her.
	state.spirit = CharacterResourceState.new(300, 300, 300) # TEST-ONLY
	shrine = MapPlaces.enter(session, &"latemoon.upstar.upstar1", UPPER_POINT)
	shrine = await _into_shrine(tree, session, shrine)
	await _beats(tree, session, 4) # a greeting that harms nobody waits its turn
	_check(state.spirit.current == 300 and shrine.npc_life.ambience._greetings.is_empty(), "区冥 greeted the dancer and stared nobody down (her look is a line over her head): %d" % state.spirit.current)
	# The manor after the night (TEST-ONLY: from outside the gate, as the night comes on the next visit).
	MapPlaces.enter(session, &"cloud.wroad0", &"cloud.wroad0.latemoon_return")
	await _settle(tree)
	hall = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _beats(tree, session, 1)
	_check(_count_in(session, &"latemoon.room.bathroom", FIREANGEL) == 0, "the night: the 凤凰 dark")
	_check(hall.place_player(&"latemoon.room.eastroom", MapPlaces.zone_spot(hall, &"latemoon.room.eastroom")), "TEST-ONLY: in the 东厢")
	await _beats(tree, session, 2)
	var elon: NpcRuntimeState = _first(session, &"latemoon.room.eastroom", ELON)
	_check(elon != null and elon.definition().talk().confirm_applies("还衣", state.marks) and NpcInquiry.topics(elon.definition(), elon.forgotten_topics(), state.marks).has("还衣"), "还衣 listed and asked first")
	_check(hall.select_npc(elon.character_id) and hall.give_to_selected(_carried(session, ROBE)) != null and session.player_held_item_ids().get(ROBE, false) == true, "given by hand: she wants it said")
	OldPineTestMap.remove(hall, _carried(session, &"es2:obj/cloth")) # TEST-ONLY: the robe on instead of the cloth
	_check(OldPineTestMap.wear(hall, _carried(session, ROBE)).succeeded and session.player_worn_item_ids().get(ROBE, false) == true, "the robe worn")
	said = _ask(hall, elon, "还衣")
	_check(session.player_worn_item_ids().get(ROBE, false) == false, "taken off his back too")
	_check(_said(said, "可它回来了") and state.marks.get("宝衣回了庄", 0) == 1 and session.player_held_item_ids().get(ROBE, false) == false, "还衣: the robe taken back: %s" % [said])
	_check(elon.has_flag(StringName(NpcMood.FLAG_PREFIX + "keeping")), "瑷伦 守衣人 again")
	_check(_said(_ask(hall, elon, "宝衣"), "又回来了") and _said(_ask(hall, elon, "留着"), "回来了"), "宝衣 and 留着 after")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/robe/home") and DeedLog.done(state, "把带出庄的寒於宝衣送回了晚月庄") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"heart", "the robe home; the 老妇's 心事 next (晚月 B)")
	_check(JournalLog.holds(catalog.conditions()["latemoon.robe_home"], state, {}, session.player_held_item_ids()), "latemoon.robe_home holds")
	state.marks["岚城一章"] = 1 # TEST-ONLY: 第十章
	_check(elon.definition().talk().confirm_applies("湖底", state.marks) and _said(_ask(hall, elon, "湖底"), "湖边等你") and state.marks.get("叫来了瑷伦", 0) == 1, "湖底: she comes down to the lake as one who kept it")
	state.marks.erase("岚城一章")
	state.marks.erase("叫来了瑷伦")
	# Next visit: the 凤凰 by the pool, the 老妇 eased.
	MapPlaces.enter(session, &"cloud.wroad0", &"cloud.wroad0.latemoon_return")
	await _settle(tree)
	hall = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _beats(tree, session, 1)
	_check(_count_in(session, &"latemoon.room.bathroom", FIREANGEL) == 1, "the 凤凰 back by the pool: %s" % [_where(session, FIREANGEL)])
	_check(hall.place_player(&"latemoon.room.lstudio", MapPlaces.zone_spot(hall, &"latemoon.room.lstudio")), "TEST-ONLY: in the 内书房")
	await _beats(tree, session, 3)
	var old: NpcRuntimeState = _first(session, &"latemoon.room.lstudio", OLD)
	_check(state.marks.get("老妇说了衣回", 0) == 1 and old != null and old.has_flag(StringName(NpcMood.FLAG_PREFIX + "eased")), "the 老妇: 衣回来了")
	_check(hall.place_player(HALL, MapPlaces.zone_spot(hall, HALL)), "TEST-ONLY: back in the 前厅")
	await _beats(tree, session, 1)
	_check(_said(_ask(hall, _first(session, HALL, MASTER), "庄里的事"), "凤凰又亮了"), "蓝止萍 knows")
	var settled: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.latemoon_robe_settled.bind(true), ["晚月庄护法", "芳绫跟你去了", "老妇说了衣回", "瑷伦叹过", "老妇说了拦", "安妮儿记下了"])
	_check(settled.is_empty(), "played leaves what latemoon_robe_settled(home) writes: %s" % [settled])


## A woman of 晚月庄 before 第四章: the line from 拜师; 护法 is not for her; she dances 沧海龙吟 herself (大弟子); the
## robe waits on 第四章, then passes as left with 瑷伦; leaving 晚月庄 ends the line.
func _test_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter3_rescued(session)
	StoryFixtures.latemoon_joined(session)
	session.record_journal()
	_check(state.quests.has("faction.latemoon#started"), "拜师: the line begins before 第四章")
	var hall: WorldMapController = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _beats(tree, session, 2)
	var master: NpcRuntimeState = _first(session, HALL, MASTER)
	state.marks["宝衣一章"] = 1 # TEST-ONLY: as if 第四章 were done, for 护法
	state.marks["接下了瑷伦三鞭"] = 1
	_check(not master.definition().talk().confirm_applies("护法", state.marks, state.family.family_id) and _said(_ask(hall, master, "护法"), "本庄的弟子") and not state.marks.has("晚月庄护法"), "护法 is not for her own")
	state.marks.erase("宝衣一章")
	state.marks.erase("接下了瑷伦三鞭")
	_check(_said(_ask(hall, master, "庄里的事"), "大弟子"), "庄里的事 to her own: 跳成了，你就是晚月庄的大弟子")
	state.marks["看过沧海龙吟图"] = 1 # TEST-ONLY: the 图 seen
	hall.give_new_item_to_player(BOOK) # TEST-ONLY: the 谱
	session.record_journal()
	state.spirit = CharacterResourceState.new(300, 300, 300) # TEST-ONLY
	var upper: WorldMapController = MapPlaces.enter(session, &"latemoon.upstar.upstar1", UPPER_POINT)
	var shrine: WorldMapController = await _into_shrine(tree, session, upper)
	_check(state.spirit.current == 300, "区冥 does not stare down her own (a dancer)")
	var floor_dance: DanceService = shrine.service(DANCE) as DanceService
	_check(_stand(shrine, DANCE) and floor_dance.in_reach(), "before the 神位")
	var result: DanceDefinition.Result = floor_dance.dance(floor_dance.known_steps()[0])
	await _settle(tree)
	_check(result.act != null and state.marks.get("跳成了沧海龙吟", 0) == 1 and state.spirit.current == 240 and _said(_recent(session.shared_ui()), "眉间亮了一下"), "she dances it herself: 30 + 30 sen, the 神像 glows (%d)" % state.spirit.current)
	_check(floor_dance.known_steps().is_empty(), "not offered again")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/shrine") and state.affiliation.family_title == "大弟子", "大弟子 (%s)" % state.affiliation.family_title)
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"robe_way" and StoryQuestLog.objective(state, [catalog.story_quest(QUEST)]).contains("第四章"), "the robe waits on 第四章")
	StoryFixtures.chapter4_kept(session)
	session.record_journal()
	_check(state.quests.has("faction.latemoon/robe_way/kept") and not state.quests.has("faction.latemoon/robe/home") and not state.quests.has("faction.latemoon/robe/keep") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"heart", "left with 瑷伦: the robe step passes with a line")
	StoryFixtures.fonxan_joined(session) # TEST-ONLY: 改投封山
	session.record_journal()
	_check(state.quests.has("faction.latemoon#lapsed") and state.marks.get("晚月庄的线断了", 0) == 1, "left 晚月庄: the line lapsed")


## A 护法 who keeps the robe: 留着 answers by what he told 瑷伦 in 第四章; 莫欣芳 comes to dance for him; the robe
## stays his, the 凤凰 stays dark.
func _test_kept_on(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter4_taken(session)
	StoryFixtures.latemoon_guardian(session)
	session.record_journal()
	for mark: String in ["蓝止萍说了沧海龙吟", "看过沧海龙吟图"]:
		state.marks[mark] = 1 # TEST-ONLY
	var hall: WorldMapController = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _settle(tree)
	hall.give_new_item_to_player(BOOK) # TEST-ONLY
	session.record_journal()
	var upper: WorldMapController = MapPlaces.enter(session, &"latemoon.upstar.upstar1", UPPER_POINT)
	var shrine: WorldMapController = await _into_shrine(tree, session, upper)
	var proxy: ActService = shrine.service(PROXY) as ActService
	_check(_count_in(session, &"latemoon.upstar.uproom2", SHINFUN) == 1, "莫欣芳 in the 翠湘阁")
	_check(_stand(shrine, PROXY) and proxy.in_reach(), "请人替跳 in reach")
	proxy.interact()
	await _settle(tree)
	var lines: Array[String] = _recent(ui)
	_check(_said(lines, "这一支我来跳") and state.marks.get("跳成了沧海龙吟", 0) == 1 and _count_in(session, SHRINE, SHINFUN) == 1, "莫欣芳 comes and dances: %s" % [lines])
	proxy.interact()
	await _settle(tree)
	_check(_said(_recent(ui, 2), "已经在神位前跳过了"), "danced once")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/robe_way/carried"), "the robe on him")
	hall = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	_check(hall.place_player(&"latemoon.room.eastroom", MapPlaces.zone_spot(hall, &"latemoon.room.eastroom")), "TEST-ONLY: in the 东厢")
	await _beats(tree, session, 2)
	var elon: NpcRuntimeState = _first(session, &"latemoon.room.eastroom", ELON)
	_check(elon.definition().talk().confirm_applies("留着", state.marks), "留着 asked first")
	var said: Array[String] = _ask(hall, elon, "留着")
	_check(_said(said, "你说过你不知道") and state.marks.get("宝衣留在了身上", 0) == 1 and session.player_held_item_ids().get(ROBE, false) == true, "留着 (he answered 不知道 in 第四章): the robe stays: %s" % [said])
	_check(not elon.definition().talk().confirm_applies("还衣", state.marks) and _said(_ask(hall, elon, "还衣"), "你说过留着") and session.player_held_item_ids().get(ROBE, false) == true, "the other way is closed")
	_check(_said(_ask(hall, elon, "宝衣"), "你说留着"), "宝衣: 别丢了它")
	session.record_journal()
	_check(state.quests.has("faction.latemoon/robe/keep") and DeedLog.done(state, "对守衣人说，寒於宝衣留在自己身上") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"heart", "kept: the 老妇 next")
	_check(not JournalLog.holds(catalog.conditions()["latemoon.robe_home"], state, {}, session.player_held_item_ids()), "latemoon.robe_home does not hold")
	MapPlaces.enter(session, &"cloud.wroad0", &"cloud.wroad0.latemoon_return")
	await _settle(tree)
	_quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _beats(tree, session, 1)
	_check(_count_in(session, &"latemoon.room.bathroom", FIREANGEL) == 0, "the 凤凰 stays dark")


## A woman of another family who gave the robe to 安妮儿: 护法; the robe step passes; 蓝止萍 sends her to ask for it back,
## and 安妮儿 does not give it.
func _test_given_to_annie(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter3_rescued(session)
	for key: String in [
		"main.chapter4#started", "main.chapter4/lead/pan", "main.chapter4/manor", "main.chapter4/annie", "main.chapter4/keeper",
		"main.chapter4/lashes", "main.chapter4/question/for_annie", "main.chapter4/chest", "main.chapter4/choice/to_annie", "main.chapter4#done",
	]:
		state.quests[key] = state.quests.size() + 1 # TEST-ONLY: 第四章 by 交给安妮儿
	for mark: String in ["潘军禅说了宝衣", "安妮儿说了等", "瑷伦说了三鞭", "接下了瑷伦三鞭", "答瑷伦：给安妮儿", "瑷伦说了冰匣", "dance_yu_fong", "冰匣开了", "宝衣给了安妮儿", "宝衣一章"]:
		state.marks[mark] = 1
	StoryFixtures.fonxan_joined(session) # TEST-ONLY: 封山's
	session.record_journal()
	var hall: WorldMapController = _quiet(session, MapPlaces.enter(session, HALL, HALL_POINT))
	await _beats(tree, session, 2)
	var master: NpcRuntimeState = _first(session, HALL, MASTER)
	_check(master.definition().talk().confirm_applies("护法", state.marks, state.family.family_id), "护法 asked first of a woman of 封山")
	var said: Array[String] = _ask(hall, master, "护法")
	_check(_said(said, "不抢人") and state.marks.get("晚月庄护法", 0) == 1, "护法 for a woman of another family: %s" % [said])
	_check((session.player_runtime() as WorldPlayerRuntimeState).shown_title() == "晚月庄护法", "her title over 封山's: %s" % (session.player_runtime() as WorldPlayerRuntimeState).shown_title())
	_check(_said(_ask(hall, master, "庄里的事"), "区冥会记得你") and state.marks.get("蓝止萍说了沧海龙吟", 0) == 1, "庄里的事 to a woman 护法: she dances it herself")
	StoryFixtures.latemoon_danced(session)
	session.record_journal()
	_check(state.quests.has("faction.latemoon/robe_way/annie") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"heart", "the robe with 安妮儿: the step passes")
	said = _ask(hall, master, "庄里的事")
	_check(_said(said, "她不会给") and state.marks.get("蓝止萍要回宝衣", 0) == 1, "蓝止萍: go and ask for it: %s" % [said])
	_check(hall.place_player(&"latemoon.room.westroom", MapPlaces.zone_spot(hall, &"latemoon.room.westroom")), "TEST-ONLY: in the 西厢")
	await _beats(tree, session, 2)
	said = _ask(hall, _first(session, &"latemoon.room.westroom", ANNIE), "宝衣")
	_check(_said(said, "蓝止萍让你来要") and state.marks.get("安妮儿不还宝衣", 0) == 1, "安妮儿 does not give it: %s" % [said])
	StoryFixtures.fonxan_joined(session)
	session.record_journal()
	_check(not state.quests.has("faction.latemoon#lapsed"), "a 护法 of another family: the line stands")


## TEST-ONLY: from the upper floor's stairs into the 佛堂 (through its door, as the player walks), a beat for 区冥's look.
func _into_shrine(tree: SceneTree, session: WorldSessionController, upper: WorldMapController) -> WorldMapController:
	await _settle(tree)
	_check(upper != null and upper.place_player(SHRINE, MapPlaces.zone_spot(upper, SHRINE)), "TEST-ONLY: into the 佛堂")
	await _beats(tree, session, 1)
	return upper


## TEST-ONLY: the 东方神教杀手 the night left in the 前厅 sent off (晚月 B's matter), so nobody fights in the hall.
func _quiet(session: WorldSessionController, map: WorldMapController) -> WorldMapController:
	for killer: NpcRuntimeState in _all(session, HALL, &"native.npc.cult_killer"):
		map.npcs.leave_for_good(killer)
	return map


func _stand(map: WorldMapController, service_id: StringName) -> bool:
	return map.place_player(map.service(service_id).definition.zone_id, MapPlaces.service_spot(map, service_id))


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
