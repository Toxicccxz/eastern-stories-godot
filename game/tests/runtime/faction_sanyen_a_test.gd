extends RefCounted

## 势力线第三批 山烟寺 A (计划 势力线第三批_计划.md §6 山烟寺 A, §2「谁能走」「互斥」, §8 第 7 行; DECISIONS「山烟寺 A」):
## the line shows for 玄智's own and for a 流云轩的帮手 (after 第五章, one who asks the 药僧「病人」; a woman too, not
## shaved), never for one who took 朱鸿雪's order (山烟寺 and 东方神教 exclude each other: the 药僧 says nothing, and
## 朱鸿雪 keeps her 令 from 山烟寺's own and from the 帮手). The 樵夫 老葛 in 流云轩; 玄智's three herbs (附子 from the
## 药圃, 麝香 from 杨掌柜, 鬼臼 by the 树王坟, a 鬼卒 there while it is wanted); the 药僧's 汤药 that does not drive the
## cold out (知客 for 山烟寺's own); the small choice: the 独眼头陀 led into 流云轩 (he follows once, 老葛 healed on
## the spot, 不守寺规, no rank) or the rule kept (老葛's life kept, his arm lost); 番坊 said either way; the stub `west`.
## The 头陀 is only knocked down while the line runs, and 朱鸿雪 does not send anyone after him then.

const MapPlaces := preload("res://tests/support/map_places.gd")
const FollowerWalk := preload("res://tests/support/follower_walk.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RealFight := preload("res://tests/support/real_fight.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const QUEST: StringName = &"faction.sanyen"
const XUANZHI: StringName = &"common.npc.bonze.master"
const MONK: StringName = &"sanyen.npc.monk"
const DRUG: StringName = &"sanyen.npc.drug_bonze"
const YANG: StringName = &"snow.npc.herbalist"
const GOD: StringName = &"cloud.npc.god"
const SICK: StringName = &"native.npc.sick_woodcutter"
const HOME: StringName = &"native.npc.woodcutter_home"
const GHOUL: StringName = &"native.npc.hell_runner_tomb"
const FUZI: StringName = &"native:sanyen/fuzi"
const MUSK: StringName = &"native:snow/musk"
const GUIJIU: StringName = &"native:choyin/guijiu"
const BREW: StringName = &"native:sanyen/decoction"
const FIELD_ACT: StringName = &"sanyen.drug_field.herbs"
const TOMB_ACT: StringName = &"choyin.tree_tomb.guijiu"
const HEAL: StringName = &"sanyen.heal_room"
const HEAL_POINT: StringName = &"sanyen.heal_room.inner_yard_entry"
const HALL: StringName = &"sanyen.temple"
const HALL_POINT: StringName = &"sanyen.temple.road1_entry"
const ROAD1: StringName = &"sanyen.road1"
const ROAD1_POINT: StringName = &"sanyen.road1.temple_return"
const DRUG_FIELD: StringName = &"sanyen.drug_field"
const SHOP: StringName = &"snow.herbshop"
const SHOP_POINT: StringName = &"snow.herbshop.herbshop_entry"
const TOMB: StringName = &"choyin.tree_tomb"
const TOMB_POINT: StringName = &"choyin.tree_tomb.hole_return"
const N_GATE: StringName = &"choyin.n_gate"
const N_GATE_POINT: StringName = &"choyin.n_gate.road_arrival"
const YARD: StringName = &"cloud.god2"
const YARD_POINT: StringName = &"cloud.god2.god.1"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_order, _test_helper, _test_disciple]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_helper else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.title == "山烟寺", "faction.sanyen: a 势力 line")
	if quest == null:
		return
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"rx", &"field", &"shop", &"tomb", &"brew", &"feed", &"monk", &"west", &"leaf", &"meet", &"split"], "山烟寺 A's steps, then 山烟寺 B's: %s" % [ids])
	_check(quest.excludes.has(&"faction.dongfang") and catalog.story_quest(&"faction.dongfang").excludes.has(QUEST), "山烟寺 and 东方神教 exclude each other, both ways written")
	var feed: StoryQuestDefinition.Step = quest.step(&"feed")
	_check(feed.reward.rank_title == "知客" and feed.reward.rank_family == &"family.sanyen" and not feed.reward.deed.is_empty(), "the 汤药 fed: 知客 for 山烟寺's own, a deed")
	var monk_step: StoryQuestDefinition.Step = quest.step(&"monk")
	_check(monk_step.is_branch() and monk_step.weight == &"small" and monk_step.options.size() == 2, "the 头陀: the line's one small choice, two ways")
	_check(monk_step.options.all(func(option: StoryQuestDefinition.Option) -> bool: return option.reward.rank_title.is_empty()), "neither way of it ranks")
	_check(quest.steps.filter(func(step: StoryQuestDefinition.Step) -> bool: return step.weight == &"big").map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id) == [&"split"], "no big split in 山烟寺 A: the one big is 山烟寺 B's")
	_check(quest.step(&"west").target.npc_ids.has(&"fanfang.npc.lama_master"), "then on to 龙若法王 in 番坊 (山烟寺 B)")
	for id: StringName in [FUZI, MUSK, GUIJIU, BREW]:
		var item: ItemContentDefinition = catalog.item(id)
		_check(item != null and item.quest_item and item.no_drop, "%s: a quest item, kept" % id)
	_check(catalog.item(BREW).give_to.has(SICK), "the 汤药 is given to 老葛")
	var monk: NpcDefinition = catalog.npc(MONK)
	_check(monk.hooks() != null and monk.hooks().kept_when != null and not monk.hooks().always_kept, "the 头陀 is kept while the line runs, not always")
	_check(monk.talk().listed_for("病人", {"喂了樵夫药": 1}) and not monk.talk().listed_for("病人", {}), "the 头陀 speaks only once the 汤药 did not help")
	_check(monk.talk().listed_for("领路", {"头陀说了病人": 1}) and catalog.npc(XUANZHI).talk().listed_for("寺规", {"头陀说了病人": 1}), "两边: 领路 to the 头陀, 寺规 to 玄智")
	var drug: NpcTalk = catalog.npc(DRUG).talk()
	var ch5: Dictionary = {"宝衣一章": 1}
	_check(drug.ask_confirm("病人").contains("朱鸿雪的令") and drug.confirm_applies("病人", ch5) and not drug.confirm_applies("病人", ch5, &"family.sanyen") and not drug.confirm_applies("病人", {"宝衣一章": 1, "接了朱鸿雪的令": 1}), "the 帮手 asked first (the 神教's door shuts); not 山烟寺's own, not one of 朱鸿雪's")
	var god: NpcTalk = catalog.npc(GOD).talk()
	_check(god.ask_confirm("接令").contains("山烟寺流云轩的门") and not god.confirm_applies("接令", {"朱鸿雪说了令牌": 1, "流云轩的帮手": 1}) and not god.confirm_applies("接令", {"朱鸿雪说了令牌": 1}, &"family.sanyen"), "接令 asked first says 山烟寺's door shuts; not put to a 帮手 or 山烟寺's own")
	for topic: String in ["领路", "寺规"]:
		var talk: NpcTalk = catalog.npc(MONK if topic == "领路" else XUANZHI).talk()
		_check(not talk.ask_confirm(topic).is_empty() and talk.confirm_applies(topic, {"头陀说了病人": 1}) and not talk.confirm_applies(topic, {"头陀说了病人": 1, "头陀跟你去了流云轩": 1}), "%s asked first, once" % topic)
	_check(catalog.npc(SICK).hooks().always_kept and catalog.npc(HOME).hooks().always_kept, "老葛 can only be knocked down")
	_check(NpcLifeBook.entry(SICK).pose == "lie", "老葛 lies on his pallet")
	for spawn_id: StringName in [&"native.heal_room.woodcutter", &"native.n_gate.woodcutter", &"native.tree_tomb.herb_ghoul"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.staged, "%s is on the story's stage" % spawn_id)
	_check(catalog.service(FIELD_ACT) != null and catalog.service(TOMB_ACT) != null, "the 药圃 and the 树王坟's stones")


## One who took 朱鸿雪's order: the 药僧 says nothing; a 山烟寺 man then knelt: no line (东方神教 excludes it).
func _test_order(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.marks["宝衣一章"] = 1 # TEST-ONLY: 第五章
	state.marks["接了朱鸿雪的令"] = 1 # TEST-ONLY: 东方神教 A
	session.record_journal()
	_check(state.quests.has("faction.dongfang#started"), "the 神教 line runs")
	var heal: WorldMapController = await _enter(tree, session, HEAL, HEAL_POINT)
	var said: Array[String] = _ask(heal, _first(session, HEAL, DRUG), "病人")
	_check(_said(said, "一句话也不说") and not state.marks.has("流云轩的帮手"), "the 药僧 says nothing to one of 朱鸿雪's (%s)" % [said])
	_check(_first(session, HEAL, SICK) != null, "老葛 lies there from 第五章")
	_join(session)
	session.record_journal()
	_check(not state.quests.has("faction.sanyen#started"), "a 山烟寺 man who took 朱鸿雪's order: no line")
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall, _first(session, HALL, XUANZHI), "流云轩"), "神教的血腥气") and not state.marks.has("玄智开了方子"), "玄智: not for one of the 神教")


## A woman of no family: the 流云轩的帮手 after 第五章; the three herbs (the 鬼卒 by the 树王坟), the 汤药 (no rank),
## the rule kept; the 药僧's 番坊; 老葛 home with his arm lost; 朱鸿雪's 令 shut to her; the stub.
func _test_helper(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var heal: WorldMapController = await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_first(session, HEAL, SICK) == null, "before 第五章 nobody lies in 流云轩")
	_check(not catalog.npc(DRUG).talk().listed_for("病人", state.marks), "the 药僧's 病人 waits for 第五章")
	state.marks["宝衣一章"] = 1 # TEST-ONLY: 第五章 began
	await _enter(tree, session, HALL, HALL_POINT)
	heal = await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_first(session, HEAL, SICK) != null, "老葛 on his pallet from 第五章")
	_check(_said(_ask(heal, _first(session, HEAL, SICK), "伤"), "冷到骨头里"), "老葛: the 鬼卒 by the 树王坟, the cold wound")
	var said: Array[String] = _ask(heal, _first(session, HEAL, DRUG), "病人")
	_check(_said(said, "你肯帮忙") and state.marks.get("流云轩的帮手", 0) == 1, "the 药僧's 病人: a 帮手 (%s)" % [said])
	session.record_journal()
	_check(state.quests.has("faction.sanyen#started") and _step(session) == &"rx", "her line begins: ask 玄智")
	_check(_said(_ask(heal, _first(session, HEAL, DRUG), "病人"), "去前殿问方丈"), "the 药僧 sends her to 玄智")
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	said = _ask(hall, _first(session, HALL, XUANZHI), "流云轩")
	_check(_said(said, "帮手不必落发") and _said(said, "鬼臼") and state.marks.get("玄智开了方子", 0) == 1, "玄智's prescription for a 帮手, not shaved (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"field" and _target(session).zone_id == DRUG_FIELD, "first the 药圃")
	# 附子 from the 药圃.
	var grounds: WorldMapController = await _enter(tree, session, ROAD1, ROAD1_POINT)
	_check(_act(grounds, FIELD_ACT, DRUG_FIELD) and _carried(session, FUZI) != &"" and state.marks.get("采了附子", 0) == 1, "the 药圃: a 附子")
	_check(_act(grounds, FIELD_ACT, DRUG_FIELD) and _said(_recent(session, 2), "已经挖了一块"), "only one")
	session.record_journal()
	_check(_step(session) == &"shop" and _target(session).zone_id == SHOP, "then 杨掌柜")
	# 麝香 from 杨掌柜.
	var shop: WorldMapController = await _enter(tree, session, SHOP, SHOP_POINT)
	said = _ask(shop, _first(session, SHOP, YANG), "山烟寺")
	_check(_said(said, "不收钱") and _carried(session, MUSK) != &"" and state.marks.get("杨掌柜给了麝香", 0) == 1, "杨掌柜: the 麝香, no money (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"tomb" and _target(session).zone_id == TOMB, "then the 树王坟")
	# 鬼臼 by the 树王坟, a 鬼卒 there.
	var town: WorldMapController = await _enter(tree, session, TOMB, TOMB_POINT)
	_check(_first(session, TOMB, GHOUL) != null, "a 鬼卒 by the 树王坟 while the 鬼臼 is wanted")
	_check(_act(town, TOMB_ACT, TOMB) and _said(_recent(session, 2), "先得打发了它") and _carried(session, GUIJIU) == &"", "the 鬼卒 stands over the stones")
	# DECISIONS「势力线的仗」: fought with real numbers — a character who also explored, at 第五章's
	# arrival (流云轩 wants 「宝衣一章」), a sword in hand.
	var before: int = state.progression.combat_experience
	RealFight.ready_player(session, Arrival.exploring(&"main.chapter5"))
	var ghoul: NpcRuntimeState = _first(session, TOMB, GHOUL)
	for second: int in 4:
		if session.combat_encounter_coordinator().has_active_encounter():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		town.hostilities.process_pending_aggression()
	if not session.combat_encounter_coordinator().has_active_encounter() and ghoul != null and town.select_npc(ghoul.character_id):
		town.attack_selected()
	var steps: int = RealFight.fight_out(session, true)
	await _settle(tree)
	WorldSpawnClearings.note(session)
	_check(steps > 0 and steps < RealFight.MAX_STEPS and RealFight.player_stands(session) and state.marks.get("树王坟的鬼卒倒了", 0) == 1, "the 鬼卒 fought to the end, the player standing (%d steps; 气 %d/%d)" % [steps, state.vitality.current, state.vitality.maximum])
	state.progression.combat_experience = before # TEST-ONLY: as the rest of the walk had it
	await _enter(tree, session, N_GATE, N_GATE_POINT)
	await _enter(tree, session, HEAL, HEAL_POINT)
	town = await _enter(tree, session, TOMB, TOMB_POINT)
	_check(_first(session, TOMB, GHOUL) == null, "beaten, it is gone for good")
	_check(_act(town, TOMB_ACT, TOMB) and _carried(session, GUIJIU) != &"" and state.marks.get("采了鬼臼", 0) == 1, "the 鬼臼 from the stones")
	session.record_journal()
	_check(_step(session) == &"brew", "three herbs: to the 药僧")
	# The 汤药.
	heal = await _enter(tree, session, HEAL, HEAL_POINT)
	said = _ask(heal, _first(session, HEAL, DRUG), "煎药")
	_check(_said(said, "齐了") and _carried(session, BREW) != &"" and _carried(session, FUZI) == &"" and _carried(session, MUSK) == &"" and _carried(session, GUIJIU) == &"", "the 药僧 takes the three, brews the 汤药 (%s)" % [said])
	session.record_journal()
	_check(_step(session) == &"feed", "feed it to 老葛")
	var sick: NpcRuntimeState = _first(session, HEAL, SICK)
	_check(heal.select_npc(sick.character_id) and heal.give_to_selected(_carried(session, BREW)).done() and state.marks.get("喂了樵夫药", 0) == 1, "the 汤药 given to 老葛")
	_check(_said(_recent(session, 8), "寒气退不下去"), "the cold stays")
	session.record_journal()
	_check(_step(session) == &"monk" and state.affiliation.family_title != "知客", "on to the 头陀; no rank for a 帮手")
	# The 头陀: the rule kept.
	grounds = await _enter(tree, session, ROAD1, ROAD1_POINT)
	var monk: NpcRuntimeState = _first(session, ROAD1, MONK)
	_check(monk != null, "the 头陀 outside the 金门")
	said = _ask(grounds, monk, "病人")
	_check(_said(said, "我能") and state.marks.get("头陀说了病人", 0) == 1, "the 头陀 speaks for the first time (%s)" % [said])
	hall = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall, _first(session, HALL, XUANZHI), "头陀"), "他不是本寺的人"), "玄智: not of this temple")
	said = _ask(hall, _first(session, HALL, XUANZHI), "寺规")
	_check(_said(said, "三天三夜") and state.marks.get("守了寺规", 0) == 1 and not state.marks.has("不守寺规"), "寺规: 玄智 keeps him himself (%s)" % [said])
	session.record_journal()
	_check(state.quests.has("faction.sanyen/monk/rule") and _step(session) == &"west", "the rule's way; on to 番坊")
	grounds = await _enter(tree, session, ROAD1, ROAD1_POINT)
	_check(_said(_ask(grounds, _first(session, ROAD1, MONK), "领路"), "不理你") and not state.marks.has("头陀跟你去了流云轩"), "the 头陀 turns away from her")
	heal = await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_first(session, HEAL, SICK) == null, "老葛 gone home")
	var lines: Array[String] = await _scene(tree, session, heal)
	_check(_said(lines, "番坊的日陀罗寺") and state.marks.get("听说了番坊的经", 0) == 1, "the 药僧: the 头陀's 经 is from 番坊 (%s)" % [lines.slice(-4)])
	town = await _enter(tree, session, N_GATE, N_GATE_POINT)
	_check(_first(session, N_GATE, HOME) != null, "老葛 by 乔阴's 北门")
	lines = await _scene(tree, session, town)
	_check(_said(lines, "用左手") and state.marks.get("老葛谢过你", 0) == 1, "老葛, his right arm lost (%s)" % [lines.slice(-4)])
	_check(_said(_ask(town, _first(session, N_GATE, HOME), "伤"), "右手废了"), "老葛's 伤")
	# 朱鸿雪's 令 shut to a 帮手.
	state.progression.combat_experience = 5000 # TEST-ONLY
	var yard: WorldMapController = await _enter(tree, session, YARD, YARD_POINT)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "令牌"), "流云轩的药味") and not state.marks.has("朱鸿雪说了令牌"), "朱鸿雪: no 令 for a 帮手")
	state.marks["朱鸿雪说了令牌"] = 1 # TEST-ONLY: told before she helped
	_check(_said(_ask(yard, god, "接令"), "流云轩的药味") and not state.marks.has("接了朱鸿雪的令"), "接令: not for a 帮手")
	session.record_journal()
	_check(not state.quests.has("faction.dongfang#started"), "no 神教 line")
	_check(StoryKeeps.keeps(state, catalog.npc(MONK), catalog.story_quests()) and not WorldQuestTargets.at_hand(session, "独眼头陀"), "while the line runs the 头陀 is kept: 朱鸿雪 sends nobody after him")


## 玄智's own (a man, shaved and knelt): the line from the 拜师, waiting for 第五章; the prescription; the 汤药: 知客;
## the 头陀 led into 流云轩: he follows, heals 老葛 on the spot, 不守寺规 and no rank; he talks to him after; leaving
## 山烟寺 ends the line and the 头陀 can be killed again.
func _test_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	_check(not StoryKeeps.keeps(state, catalog.npc(MONK), catalog.story_quests()) and WorldQuestTargets.at_hand(session, "独眼头陀"), "from New Game the 头陀 is as ES2: 朱鸿雪 may send one after him")
	_join(session)
	session.record_journal()
	_check(state.quests.has("faction.sanyen#started") and _step(session) == &"rx", "山烟寺's own: the line shows")
	_check(_rows(state).any(func(label: String) -> bool: return label.contains("等主线第五章")), "before 第五章: wait")
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall, _first(session, HALL, XUANZHI), "流云轩"), "看病") and not state.marks.has("玄智开了方子"), "before 第五章: only his clinic")
	state.marks["宝衣一章"] = 1 # TEST-ONLY
	var said: Array[String] = _ask(hall, _first(session, HALL, XUANZHI), "流云轩")
	_check(_said(said, "附子回阳") and not _said(said, "帮手") and state.marks.get("玄智开了方子", 0) == 1 and not state.marks.has("流云轩的帮手"), "玄智's prescription for his own (%s)" % [said])
	for mark: String in ["采了附子", "杨掌柜给了麝香", "采了鬼臼"]:
		state.marks[mark] = 1 # TEST-ONLY: the three herbs (the 药僧 takes what is carried)
	var heal: WorldMapController = await _enter(tree, session, HEAL, HEAL_POINT)
	_ask(heal, _first(session, HEAL, DRUG), "煎药")
	var sick: NpcRuntimeState = _first(session, HEAL, SICK)
	_check(heal.select_npc(sick.character_id) and heal.give_to_selected(_carried(session, BREW)).done(), "the 汤药 to 老葛")
	session.record_journal()
	_check(state.affiliation.family_title == "知客" and _step(session) == &"monk", "the 汤药 fed: 知客")
	_check(StoryKeeps.keeps(state, catalog.npc(MONK), catalog.story_quests()), "the 头陀 kept while the line runs")
	var grounds: WorldMapController = await _enter(tree, session, ROAD1, ROAD1_POINT)
	var monk: NpcRuntimeState = _first(session, ROAD1, MONK)
	_ask(grounds, monk, "病人")
	said = _ask(grounds, monk, "领路")
	_check(_said(said, "走。") and state.marks.get("头陀跟你去了流云轩", 0) == 1 and monk.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "领路: the 头陀 follows (%s)" % [said])
	var hall2: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall2, _first(session, HALL, XUANZHI), "寺规"), "老衲不拦") and not state.marks.has("守了寺规"), "寺规 once he follows: 玄智 does not stop you")
	_check(await MapPlaces.go_to(tree, session, ROAD1) != null and _first(session, ROAD1, MONK) == monk, "back to the 金门, where he waits")
	heal = await _go_with(tree, session, HEAL, MONK)
	_check(heal != null, "led into 流云轩, he behind: %s" % FollowerWalk.failure)
	monk = _first(session, HEAL, MONK)
	_check(monk != null, "the 头陀 came along")
	var lines: Array[String] = await _scene(tree, session, heal)
	_check(_said(lines, "热乎了") and _said(lines, "番坊的日陀罗寺") and state.marks.get("头陀进了流云轩", 0) == 1 and state.marks.get("不守寺规", 0) == 1 and state.marks.get("听说了番坊的经", 0) == 1, "the 头陀 heals 老葛 (%s)" % [lines.slice(-6)])
	_check(monk != null and not monk.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "only this once: he follows no more")
	session.record_journal()
	_check(state.quests.has("faction.sanyen/monk/heal") and _step(session) == &"west" and state.affiliation.family_title == "知客", "the 头陀's way; no rank for it")
	_check(_said(_ask(heal, monk, "番坊"), "日陀罗寺"), "the 头陀 talks to him now")
	hall = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall, _first(session, HALL, XUANZHI), "流云轩"), "寺规，施主破了"), "玄智: the rule broken")
	heal = await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_first(session, HEAL, SICK) == null, "老葛 gone home, healed")
	var town: WorldMapController = await _enter(tree, session, N_GATE, N_GATE_POINT)
	lines = await _scene(tree, session, town)
	_check(_said(lines, "抡斧头") and state.marks.get("老葛谢过你", 0) == 1, "老葛 by the 北门, healed (%s)" % [lines.slice(-4)])
	state.family = FamilyState.new(&"family.latemoon", 3) # TEST-ONLY: left 山烟寺
	session.record_journal()
	_check(state.quests.has("faction.sanyen#lapsed") and state.marks.get("山烟寺的线断了", 0) == 1, "left 山烟寺: the line lapsed")
	_check(not StoryKeeps.keeps(state, catalog.npc(MONK), catalog.story_quests()), "and the 头陀 is as ES2 again")
	heal = await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_said(_ask(heal, _first(session, HEAL, DRUG), "病人"), "不劳施主") and not state.marks.has("流云轩的帮手"), "one who left: no 帮手 behind the 药僧's back")
	# 东方神教 can never start for one whose 山烟寺 line ran (excludes): 朱鸿雪 says so, nobody takes her order for nothing.
	state.progression.combat_experience = 5000 # TEST-ONLY
	state.marks["朱鸿雪说了令牌"] = 1 # TEST-ONLY
	var yard: WorldMapController = await _enter(tree, session, YARD, YARD_POINT)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "令牌"), "流云轩的药味") and _said(_ask(yard, god, "接令"), "流云轩的药味") and not state.marks.has("接了朱鸿雪的令"), "one who left 山烟寺: no 令 either")
	_check(not god.definition().talk().confirm_applies("接令", state.marks), "接令 not asked first of them")


func _join(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.sanyen", 26) # TEST-ONLY: shaved and knelt to 玄智
	state.apprenticeship.master_teacher_id = XUANZHI
	state.apprenticeship.legacy_master_name = "玄智"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"bonze"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


func _enter(tree: SceneTree, session: WorldSessionController, zone_id: StringName, point_id: StringName) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, zone_id, point_id)
	await _settle(tree)
	return map


## TEST-ONLY: the player walks to `zone_id` through the doors, waiting at each for `follower_id` to come up
## (FollowerWalk: go.c follow_me(), no handoff that carries him along for the suite).
func _go_with(tree: SceneTree, session: WorldSessionController, zone_id: StringName, follower_id: StringName) -> WorldMapController:
	var map: WorldMapController = await FollowerWalk.go_with(tree, session, zone_id, follower_id)
	await _settle(tree)
	return map


## The act service by its own spot: true when it ran.
func _act(map: WorldMapController, service_id: StringName, zone_id: StringName) -> bool:
	var service: ActService = map.service(service_id) as ActService
	if service == null or not map.place_player(zone_id, MapPlaces.service_spot(map, service_id, zone_id)):
		return false
	if not service.in_reach():
		return false
	service.interact()
	return true


## TEST-ONLY: a scene as one comes into its room, through to its end.
func _scene(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> Array[String]:
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(map.scene_running(), "a scene starts as the player comes in")
	for second: int in 60:
		if not map.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not map.scene_running(), "the scene is over")
	return _recent(session, 30)


func _rows(state: CharacterState) -> Array[String]:
	var rows: Array[String] = []
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, GameContent.catalog().story_quests(), StoryQuestDefinition.LINE_FACTION, func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, {}, {}))
	for view: StoryQuestLog.Shown in shown:
		if view.quest.quest_id == QUEST:
			for checked: StoryQuestLog.Checked in view.checklist:
				rows.append(checked.row.label)
	return rows


## Where the line's current step leads the player now.
func _target(session: WorldSessionController) -> StoryQuestDefinition.Target:
	var state: CharacterState = session.player_runtime().state
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, GameContent.catalog().story_quest(QUEST))
	return null if step == null else step.target_for(state.marks)


func _step(session: WorldSessionController) -> StringName:
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(session.player_runtime().state, GameContent.catalog().story_quest(QUEST))
	return &"" if step == null else step.step_id


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


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(session: WorldSessionController, count: int = 6) -> Array[String]:
	var lines: Array[String] = session.shared_ui().log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("山烟寺", gender)
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
	for frame: int in 3:
		await tree.process_frame
		await tree.physics_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
