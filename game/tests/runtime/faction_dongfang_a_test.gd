extends RefCounted

## 势力线第一批 东方神教 A (计划 build/plans/势力线第一批_计划.md §5; DECISIONS「东方神教 A」): two ways in — a
## 杀手令牌 carried and 朱鸿雪 asked「令牌」, or after 第四章 (安妮儿 remembered the player, or has the 宝衣) 朱鸿雪
## speaking first — then「接令」, asked first (逆灵宫's door shuts); ES2's「还不快滚」below 1000 combat_exp; and
## the 逆灵宫 line the other way round (林忌, 霍铮). 西厢的客人: 安妮儿's「等谁」by where the 宝衣 is, told 朱鸿雪 as it
## is or kept for her (the small choice). 接令: the reeds of the 玉螺湖畔 — by day nothing, by night the dead man
## and two 鬼卒, only while the order stands — the 黑木令 shown 朱鸿雪 (持黑木令) and the cult's killers take
## the one carrying it for their own. A 教主's blood ends the line.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.dongfang"
const NILING: StringName = &"faction.niling"
const GOD: StringName = &"cloud.npc.god"
const ANNIE: StringName = &"latemoon.npc.room.annihi"
const LIN: StringName = &"common.npc.taoist.taolord"
const HUO: StringName = &"native.npc.huo_zheng"
const KILLER: StringName = &"native.npc.cult_killer"
const RUNNER: StringName = &"native.npc.hell_runner"
const TOKEN: StringName = &"es2:d/latemoon/room/npc/obj/token"
const CORPSE: StringName = &"native:village/reed_corpse"
const YARD: StringName = &"cloud.god2"
const YARD_POINT: StringName = &"cloud.god2.god.1"
const WEST: StringName = &"latemoon.room.westroom"
const WEST_POINT: StringName = &"latemoon.room.westroom.annihi.1"
const TEMPLE: StringName = &"temple.temple1"
const TEMPLE_POINT: StringName = &"temple.temple1.taolord.1"
const HUT: StringName = &"goathill.temple1"
const HUT_POINT: StringName = &"goathill.temple1.huo_zheng.1"
const SHORE: StringName = &"village.lakeside"
const SHORE_POINT: StringName = &"village.lakeside.boat_return"
const REEDS: StringName = &"village.lakeside.reeds"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_token_door, _test_walk, _test_cover, _test_refused, _test_lapse]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.starts.when == JournalEntryDefinition.When.MARK and quest.starts.key == "接了朱鸿雪的令", "faction.dongfang: a 势力 quest that begins with 接令")
	_check(quest.excludes == [NILING, &"faction.sanyen"] and catalog.story_quest(NILING).excludes == [QUEST], "the two secret lines exclude each other, both ways; 山烟寺 too (DECISIONS「山烟寺 A」)")
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(0, 4) == [&"west", &"report", &"token", &"names"], "its steps begin west, report, token, names (东方神教 B goes on): %s" % [ids])
	var report: StoryQuestDefinition.Step = quest.step(&"report")
	_check(report.is_branch() and report.weight == StoryQuestDefinition.WEIGHT_SMALL and report.options.size() == 2 and not report.options[0].reward.deed.is_empty() and not report.options[1].reward.deed.is_empty(), "the report is a small choice of two, each a deed")
	_check(report.objective.contains("朱鸿雪会记住这句话") and report.objective.contains("安妮儿欠你一回"), "the cost of either way is said before the choice")
	_check(quest.step(&"token").objective.contains("入夜") and quest.step(&"token").objective.contains("「令牌」"), "接令: by night, then 朱鸿雪 again")
	_check(quest.lapses != null and quest.lapsed_mark == "神教的线断了" and quest.lapsed_text.contains("教主的血"), "a 教主's blood ends the line")
	_check(catalog.npc(GOD).hooks().die_marks_killer == "杀了神教的教主" and catalog.npc(ANNIE).hooks().die_marks_killer == "杀了神教的教主", "either 教主 killed marks the killer")
	var god: NpcTalk = catalog.npc(GOD).talk()
	_check(god.ask_confirm("接令").contains("逆灵宫那边的门就不再为你开"), "接令 asked first: 逆灵宫's door shuts")
	for npc_id: StringName in [LIN, HUO]:
		var talk: NpcTalk = catalog.npc(npc_id).talk()
		_check(talk.ask_confirm("眼线").contains("东方神教那边的门") and not talk.confirm_applies("眼线", {"林忌说了逆灵宫": 1, "霍铮说了茅山": 1, "接了朱鸿雪的令": 1}), "%s: 眼线 is not put to one who took the order" % npc_id)
	var runners: NpcSpawnDefinition = catalog.spawn(&"native.lakeside.reed_runners")
	_check(runners != null and runners.npc_definition_id == RUNNER and runners.spawn_point_ids().size() == 2 and runners.zone_id == SHORE, "two 鬼卒 in the reeds")
	var corpse: ItemSpawnDefinition = null
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(&"village.main"):
		if spawn.item_definition_id == CORPSE:
			corpse = spawn
	_check(corpse != null and corpse.zone_id == SHORE and corpse.staged, "the dead man lies on the shore, on the stage")
	_check(catalog.item(CORPSE) != null and catalog.item(CORPSE).no_get, "and cannot be picked up")
	var when: JournalEntryDefinition = catalog.npc(KILLER).dealings().ignores_when
	_check(when != null and _holds_part(when, JournalEntryDefinition.When.MARK, "持黑木令") and _holds_part(when, JournalEntryDefinition.When.ITEM, String(TOKEN)), "the cult's killer minds the 黑木令 (dongfang.token_holds: 持黑木令 and the token carried)")


## A 杀手令牌 carried: 朱鸿雪「令牌」, then「接令」asked first; the line begins, 逆灵宫 shut (林忌 and 霍铮 say why).
func _test_token_door(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	state.progression.combat_experience = 2000 # TEST-ONLY
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(god != null, "朱鸿雪 in the 场院")
	_check(_said(_ask(yard, god, "令牌"), "没有我要看的东西") and not state.marks.has("朱鸿雪说了令牌"), "no token: nothing to see")
	_check(yard.select_npc(god.character_id) and not yard.ask_topics_selected().has("接令"), "接令 is not on her list yet")
	yard.give_new_item_to_player(TOKEN)
	_check(_said(_ask(yard, god, "令牌"), "火焰的图腾") and state.marks.get("朱鸿雪说了令牌", 0) == 1, "the token shown: 朱鸿雪 says what it is")
	_check(yard.select_npc(god.character_id) and yard.ask_topics_selected().has("接令") and god.definition().talk().confirm_applies("接令", state.marks), "接令 listed and asked first")
	_check(_said(_ask(yard, god, "接令"), "西厢") and state.marks.get("接了朱鸿雪的令", 0) == 1, "yes: the first errand, the 西厢")
	session.record_journal()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.current_step(state, quest).step_id == &"west", "the line begun; the 西厢 next")
	_check(_shown(session).contains("东方神教") and _shown(session).contains("等谁"), "the 势力 column has the line: %s" % _shown(session))
	_check(not god.definition().talk().confirm_applies("接令", state.marks) and _said(_ask(yard, god, "接令"), "已经接了"), "not twice")
	state.marks["逆灵宫一章"] = 1 # TEST-ONLY: 第三章 done
	_check(not StoryQuestLog.can_start(state, catalog.story_quest(NILING), catalog.story_quests()), "逆灵宫's line can no longer begin")
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "不能托你") and not state.marks.has("林忌说了逆灵宫"), "林忌 does not make the offer")
	state.marks["林忌说了逆灵宫"] = 1 # TEST-ONLY: heard before the order was taken
	_check(not lin.definition().talk().confirm_applies("眼线", state.marks) and _said(_ask(temple, lin, "眼线"), "两家") and not state.marks.has("答应了做眼线"), "眼线: not asked, refused")
	StoryFixtures.chapter3_rescued(session) # 霍铮 back at the 土地庙
	state.marks["霍铮说了茅山"] = 1 # TEST-ONLY: his word before the order was taken
	var hut: WorldMapController = MapPlaces.enter(session, HUT, HUT_POINT)
	await _settle(tree)
	var huo: NpcRuntimeState = _first(session, HUT, HUO)
	_check(huo != null and not huo.definition().talk().confirm_applies("眼线", state.marks) and _said(_ask(hut, huo, "眼线"), "一家的东西") and not state.marks.has("答应了做眼线"), "霍铮 the same")


## After 第四章 (the 宝衣 carried out: 安妮儿 remembered the name) 朱鸿雪 speaks first; 安妮儿's 等谁 for the 宝衣 taken;
## 照实说; the reeds by day and by night (the dead man and his 鬼卒, only while the order stands); the 黑木令 shown;
## the cult's killers take its bearer for their own.
func _test_walk(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	StoryFixtures.chapter4_taken(session)
	state.marks["安妮儿记下了"] = 1 # TEST-ONLY: her call when the 宝衣 went out
	state.progression.combat_experience = 2000 # TEST-ONLY
	session.record_journal()
	# Nobody in the reeds before the order.
	var shore: WorldMapController = MapPlaces.enter(session, SHORE, SHORE_POINT)
	_check(session.wait_until_phase([&"night"]), "night")
	shore = MapPlaces.enter(session, SHORE, SHORE_POINT)
	await _settle(tree)
	_check(_count_in(session, SHORE, RUNNER) == 0 and shore.floor_item_of(CORPSE, SHORE).is_empty(), "no order: nobody in the reeds at night")
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("朱鸿雪说了令牌", 0) == 1, "朱鸿雪 speaks first to one 安妮儿 remembered")
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "接令"), "西厢") and state.marks.get("接了朱鸿雪的令", 0) == 1, "接令")
	session.record_journal()
	# 西厢.
	var manor: WorldMapController = MapPlaces.enter(session, WEST, WEST_POINT)
	await _settle(tree)
	var annie: NpcRuntimeState = _first(session, WEST, ANNIE)
	_check(annie != null and manor.select_npc(annie.character_id) and manor.ask_topics_selected().has("等谁"), "安妮儿's 等谁 is listed for one who took the order")
	var waits: Array[String] = _ask(manor, annie, "等谁")
	_check(_said(waits, "跟着你走了") and _said(waits, "你可以照实说") and state.marks.get("安妮儿说了等谁", 0) == 1, "the 宝衣 taken: it went with you; 你可以照实说 (%s)" % [waits])
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"report", "the report next")
	# 照实说.
	yard = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	god = _first(session, YARD, GOD)
	_check(yard.select_npc(god.character_id) and yard.ask_topics_selected().has("照实说") and yard.ask_topics_selected().has("替她瞒"), "both answers listed")
	_check(god.definition().talk().confirm_applies("照实说", state.marks) and god.definition().talk().confirm_applies("替她瞒", state.marks), "both asked first")
	var told: Array[String] = _ask(yard, god, "照实说")
	_check(_said(told, "要的就是这个") and _said(told, "芦苇丛") and state.marks.get("如实回报了", 0) == 1, "照实说: 如实回报了, and the 黑木令 named (%s)" % [told])
	_check(not god.definition().talk().confirm_applies("替她瞒", state.marks) and _said(_ask(yard, god, "替她瞒"), "照实说过了") and not state.marks.has("替安妮儿瞒了"), "the other answer is gone")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"truth") and StoryQuestLog.current_step(state, quest).step_id == &"token", "truth taken; the 黑木令 next")
	_check(_said(_ask(yard, god, "令牌"), "别人身上"), "before the reeds: the token is still on someone else")
	# The reeds by day: nothing.
	_check(session.wait_until_phase([&"morning"]), "morning")
	shore = MapPlaces.enter(session, SHORE, SHORE_POINT)
	await _settle(tree)
	_check(_count_in(session, SHORE, RUNNER) == 0 and shore.floor_item_of(CORPSE, SHORE).is_empty(), "by day: nobody in the reeds")
	var before: int = session.shared_ui().log_lines().size()
	_check(await _use(tree, shore, REEDS) and not state.marks.has("取了黑木令") and _said(session.shared_ui().log_lines().slice(before), "说的是夜里"), "the reeds by day: 朱鸿雪 said night")
	# By night: the dead man and his two 鬼卒.
	_check(session.wait_until_phase([&"night"]), "night again")
	yard = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	shore = MapPlaces.enter(session, SHORE, SHORE_POINT)
	await _settle(tree)
	_check(_count_in(session, SHORE, RUNNER) == 2 and not shore.floor_item_of(CORPSE, SHORE).is_empty(), "by night: two 鬼卒 over the dead man")
	await _flee(tree, session)
	state.marks["芦苇丛的鬼卒退了"] = 1 # TEST-ONLY: both beaten
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	shore = MapPlaces.enter(session, SHORE, SHORE_POINT)
	await _settle(tree)
	_check(_count_in(session, SHORE, RUNNER) == 0 and not shore.floor_item_of(CORPSE, SHORE).is_empty(), "beaten: they stay gone; he still lies there")
	_check(await _use(tree, shore, REEDS) and state.marks.get("取了黑木令", 0) == 1 and not _carried(session, TOKEN).is_empty(), "the reeds parted: his 黑木令 taken from his fist")
	var test: Callable = session.quest_condition_test()
	_check(not test.call(catalog.conditions()["dongfang.token_holds"]), "not yet shown to 朱鸿雪: the killers do not know the bearer")
	# Shown to 朱鸿雪.
	yard = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	god = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "令牌"), "现在它是你的") and state.marks.get("持黑木令", 0) == 1 and not _carried(session, TOKEN).is_empty(), "现在它是你的: 持黑木令, the token back in hand")
	session.record_journal()
	_check(state.quests.has("faction.dongfang/token") and StoryQuestLog.current_step(state, quest).step_id == &"names" and StoryQuestLog.is_active(state, quest), "token done; the stub `names` next (东方神教 B)")
	test = session.quest_condition_test()
	_check(test.call(catalog.npc(KILLER).dealings().ignores_when), "the cult's killer takes the bearer for one of her own")
	# The reeds after: off the stage.
	shore = MapPlaces.enter(session, SHORE, SHORE_POINT)
	await _settle(tree)
	_check(shore.floor_item_of(CORPSE, SHORE).is_empty() and _count_in(session, SHORE, RUNNER) == 0, "after the token: the reeds are empty again")
	var faction: FactionDefinition = null
	for candidate: FactionDefinition in catalog.factions():
		if candidate.faction_id == &"dongfang":
			faction = candidate
	_check(faction != null and faction.shown(session.quest_condition_test()).has("朱鸿雪给过你一块黑木令。神教的杀手认得它。"), "the 声望 page: the 黑木令")


## 安妮儿's other words (given her, kept by 瑷伦, burnt, not yet), and 替她瞒.
func _test_cover(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	StoryFixtures.dongfang_joined(session)
	session.record_journal()
	var manor: WorldMapController = MapPlaces.enter(session, WEST, WEST_POINT)
	await _settle(tree)
	var annie: NpcRuntimeState = _first(session, WEST, ANNIE)
	_check(_said(_ask(manor, annie, "等谁"), "不是交给神教"), "before 第四章: she will hand the 衣 to someone, not the cult")
	for case: Array in [["冰匣开了", "衣出了冰匣"], ["宝衣给了安妮儿", "衣在我这里"], ["瑷伦守到决战", "衣回了瑷伦身上"], ["宝衣烧了", "衣烧了"]]:
		state.marks[case[0]] = 1 # TEST-ONLY: where the 宝衣 went
		_check(_said(_ask(manor, annie, "等谁"), case[1]), "%s: %s" % case)
		state.marks.erase(case[0])
	session.record_journal()
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "替她瞒"), "我信你这一回") and state.marks.get("替安妮儿瞒了", 0) == 1 and not state.marks.has("如实回报了"), "替她瞒: 替安妮儿瞒了")
	_check(_said(_ask(yard, god, "照实说"), "上回已经说过了") and not state.marks.has("如实回报了"), "and the truth cannot follow")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"cover") and StoryQuestLog.current_step(state, quest).step_id == &"token", "cover taken; the 黑木令 next")


## ES2's「还不快滚」below 1000 combat_exp; nobody speaks first to them; one who said yes to 林忌 is refused.
func _test_refused(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	state.progression.combat_experience = 500 # TEST-ONLY
	for mark: String in ["宝衣一章", "宝衣给了安妮儿"]:
		state.marks[mark] = 1 # TEST-ONLY: the 宝衣 given her
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not state.marks.has("朱鸿雪说了令牌"), "500 combat_exp: she does not speak first")
	yard.give_new_item_to_player(TOKEN)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	_check(_said(_ask(yard, god, "令牌"), "还不快滚") and not state.marks.has("朱鸿雪说了令牌"), "with the token, 500 combat_exp: 还不快滚 (god.c)")
	state.progression.combat_experience = 2000 # TEST-ONLY
	MapPlaces.enter(session, SHORE, SHORE_POINT) # TEST-ONLY: off the map and back in
	await _settle(tree)
	yard = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("朱鸿雪说了令牌", 0) == 1, "2000 combat_exp, the 宝衣 given 安妮儿: she speaks first")
	god = _first(session, YARD, GOD)
	state.marks.erase("朱鸿雪说了令牌") # TEST-ONLY: as before her word
	state.marks["杀了神教的教主"] = 1 # TEST-ONLY
	_check(_said(_ask(yard, god, "令牌"), "神教的血") and not state.marks.has("朱鸿雪说了令牌"), "a 教主's killer: no invitation")
	state.marks.erase("杀了神教的教主")
	StoryFixtures.niling_entered(session, "night")
	session.record_journal()
	_check(StoryQuestLog.is_active(state, catalog.story_quest(NILING)), "the 逆灵宫 line begun")
	_check(_said(_ask(yard, god, "令牌"), "替两家办事") and not state.marks.has("朱鸿雪说了令牌"), "one in 逆灵宫's crown: no order")
	state.marks["朱鸿雪说了令牌"] = 1 # TEST-ONLY: heard before the yes to 林忌
	_check(not god.definition().talk().confirm_applies("接令", state.marks) and _said(_ask(yard, god, "接令"), "替两家办事") and not state.marks.has("接了朱鸿雪的令"), "接令: not asked, refused")
	session.record_journal()
	_check(not state.quests.has("faction.dongfang#started") and not StoryQuestLog.can_start(state, catalog.story_quest(QUEST), catalog.story_quests()), "the line does not begin")


## A 教主's blood: the line lapses, 朱鸿雪 gives nothing more.
func _test_lapse(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.dongfang_reported(session, true)
	session.record_journal()
	state.marks["杀了神教的教主"] = 1 # TEST-ONLY: 安妮儿 killed
	session.record_journal()
	_check(state.quests.has("faction.dongfang#lapsed") and state.marks.get("神教的线断了", 0) == 1, "the line lapsed: 神教的线断了")
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var god: NpcRuntimeState = _first(session, YARD, GOD)
	yard.give_new_item_to_player(TOKEN)
	state.marks["取了黑木令"] = 1 # TEST-ONLY
	_check(_said(_ask(yard, god, "令牌"), "神教的血") and not state.marks.has("持黑木令"), "朱鸿雪: no order for one with a 教主's blood")
	_check(not session.quest_condition_test().call(GameContent.catalog().conditions()["dongfang.token_holds"]), "and the killers do not know them")


## Whether `condition` asks `kind` of `key` somewhere in it (dongfang.token_holds: the 黑木令 one of its tokens, 东方神教 B).
func _holds_part(condition: JournalEntryDefinition, kind: JournalEntryDefinition.When, key: String) -> bool:
	if condition.when == kind and condition.key == key:
		return true
	return condition.parts.any(func(part: JournalEntryDefinition) -> bool: return _holds_part(part, kind, key))


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


func _shown(session: WorldSessionController) -> String:
	var ui: SharedGameplayUI = session.shared_ui()
	ui.quest_page.fill(session.player_runtime().state, "小兄弟", "", session.quest_condition_test())
	return ui.quest_page.shown_text()


func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		for info: CombatTacticalActionInfo in coordinator.action_infos():
			if info.action_id == CombatFleeTacticalPolicy.ACTION_ID:
				coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame


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
	session.configure_source_entry("神教", CharacterState.GENDER_MALE)
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
