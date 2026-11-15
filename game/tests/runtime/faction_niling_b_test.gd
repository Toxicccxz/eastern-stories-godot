extends RefCounted

## 势力线第一批 卧底 B (计划 build/plans/势力线第一批_计划.md §6 逆灵宫 B, §8「一枚令牌三家要」, §9 第 12 条, §11 Q6;
## DECISIONS「卧底 B」): 林忌's word on the dungeon — three new captives, one jailer by day who lets nobody near the
## cells. The key three ways: a skin of wine (or 蒙汗药 in his jar) and he sleeps it off, the nail over his bench at
## 子时, or 第三章's key still carried (the cells still wait for him to look away). Opened, each captive says a word
## and goes by the 货栈's side door. The 名册's original in the 账房's iron box, taken (asked first: a 疑点, one more
## proof for the 揭发, 程不平's once 京师 is settled) or left and told to 林忌. Where 玄冥子 lives on the cliff: the
## 逆灵天书's lower half from under the master's desk at 子时, past the 巡殿 and the barred 北门 — for a 六阴剑谱 read to
## 40 and the hour he means to take 商玦's place; where he does not, that step is routed past.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const QUEST: StringName = &"faction.niling"
const LIN: StringName = &"common.npc.taoist.taolord"
const XUAN: StringName = &"native.npc.xuan_mingzi_cliff"
const WARD: StringName = &"native.npc.niling_jailer_ward"
const DOZER: StringName = &"native.npc.niling_jailer_dozing"
const KEYED: StringName = &"native.npc.niling_jailer_keyed"
const PATROL: StringName = &"native.npc.niling_patrol"
const WIFE: StringName = &"native.npc.niling_captive_wife"
const PEDDLER: StringName = &"native.npc.niling_captive_peddler"
const HERBALIST: StringName = &"native.npc.niling_captive_herbalist"
const JUDGE: StringName = &"choyin.npc.judgeman"
const CROWN: StringName = &"native:niling/black_crown"
const KEY: StringName = &"native:niling/cell_key"
const REGISTER: StringName = &"native:niling/offering_register"
const SCRIPTURE: StringName = &"native:niling/scripture_lower"
const MANUAL: StringName = &"native:niling/six_chaos_manual"
const WINESKIN: StringName = &"es2:obj/example/wineskin"
const DRUG: StringName = &"es2:obj/slumber_drug"
const TEMPLE: StringName = &"temple.temple1"
const TEMPLE_POINT: StringName = &"temple.temple1.taolord.1"
const CORRIDOR: StringName = &"niling.corridor"
const CORRIDOR_POINT: StringName = &"niling.corridor.stairs_arrival"
const COUNTING: StringName = &"niling.counting"
const COUNTING_POINT: StringName = &"niling.counting.ledger.1"
const FRONT: StringName = &"niling.front"
const FRONT_POINT: StringName = &"niling.front.yard_entry"
const MASTER: StringName = &"niling.master"
const MASTER_POINT: StringName = &"niling.master.altar_entry"
const CLIFF: StringName = &"niling.cliff_path"
const CLIFF_POINT: StringName = &"niling.cliff_path.door_arrival"
## The three cells, their doors and who is in them.
const CELLS: Array = [
	[&"niling.cell_huo", &"niling.cell_huo.door", WIFE, "放了槐阳的妇人"],
	[&"niling.cell_shitou", &"niling.cell_shitou.door", PEDDLER, "放了货郎"],
	[&"niling.cell_others", &"niling.cell_others.door", HERBALIST, "放了采药人"],
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_wine, _test_nail, _test_old_key_and_drug, _test_ledger_taken, _test_ledger_left, _test_scripture, _test_no_xuan, _test_killed_xuan]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"gate", &"hire", &"chores", &"listen", &"copy", &"deliver", &"word", &"cells", &"ledger", &"scripture", &"next"], "its steps, B's after A's: %s" % [ids])
	var ledger: StoryQuestDefinition.Step = quest.step(&"ledger")
	_check(ledger.is_branch() and ledger.weight == StoryQuestDefinition.WEIGHT_SMALL and ledger.options.map(func(option: StoryQuestDefinition.Option) -> StringName: return option.option_id) == [&"take", &"leave"], "the 名册 is the line's second small choice: take or leave")
	_check(ledger.objective.contains("那是一条疑点") and ledger.objective.contains("程不平"), "what taking it costs and is worth is said before the choice")
	var scripture: StoryQuestDefinition.Step = quest.step(&"scripture")
	_check(scripture.is_branch() and scripture.weight == StoryQuestDefinition.WEIGHT_ROUTE and scripture.keeps.is_empty(), "the 天书 is no choice: routed by whether 玄冥子 lives; he is not kept (a keep would reach back into 第三章's duel)")
	_check(not StoryKeeps.holds(CharacterState.new(), XUAN, catalog.story_quests()), "a new game: nothing keeps 玄冥子 — 第三章's duel may still end in 了结")
	_check(quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) == 2 and quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) == 0, "two small choices so far (the door, the 名册); the split is 逆灵宫 C's")
	_check(quest.step(&"cells").checklist.size() == 3 and quest.step(&"cells").keeps.size() == 3, "three captives ticked off, none killed for good while they wait")
	_check(quest.checklist.size() == 6 and quest.checklist[0].condition.parts.size() == 5, "the 疑点 of five now, 名册不见了 among them")
	for id: StringName in [&"niling.counting.box", &"niling.corridor.nail", &"niling.corridor.jars", &"niling.front.bar", &"niling.master.desk"]:
		_check(catalog.service(id) != null and catalog.service(id).act != null, "act %s" % id)
	for cell: Array in CELLS:
		var rules: Array = catalog.exit_rules_between(CORRIDOR, cell[0]).filter(func(rule: ZoneExitRuleDefinition) -> bool: return rule.present_npc_id == WARD)
		_check(rules.size() == 1, "the jailer bars %s while he stands awake" % cell[0])
	_check(catalog.item(REGISTER).give_to == [JUDGE] and catalog.item(SCRIPTURE).give_to == [XUAN], "the 名册 to 程不平, the 天书 to 玄冥子")
	var manual: ItemContentDefinition = catalog.item(MANUAL)
	_check(manual != null and manual.no_drop and manual.study != null and manual.study.skill_id == &"six-chaos-sword" and manual.study.max_skill == 40, "《六阴剑谱》 reads 六阴追魂剑 to 40")
	var judge: Array = catalog.npc(JUDGE).dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == REGISTER)
	_check(judge.size() == 2 and (judge[0] as NpcObjectRule).accept and (judge[0] as NpcObjectRule).giver_mark == "皇城一章" and not (judge[1] as NpcObjectRule).accept, "程不平 takes the 名册 once 京师 is settled, not before")
	_check(FileAccess.get_file_as_string("res://data/story/epilogue.json").contains("名册交给了程不平"), "the 乔阴 card has a line for it")
	# The 揭发: the 名册 is one more proof.
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	var branch: Array = [] if expose == null else expose.act.acts.filter(func(act: ScriptedAct) -> bool: return not act.ask.is_empty())
	var state := CharacterState.new()
	state.marks["陈显祖作了证"] = 1
	var held: Dictionary[StringName, bool] = {}
	_check(branch.size() == 1 and not JournalLog.holds((branch[0] as ScriptedAct).when, state, {}, held), "one proof is not enough")
	held[REGISTER] = true
	_check(branch.size() == 1 and JournalLog.holds((branch[0] as ScriptedAct).when, state, {}, held), "the 名册 makes two (DECISIONS「卧底 B」)")


## The night door (霍铮 freed; 关北 救了一半): 林忌's word; by day the jailer alone, 第三章's two gone, the cells locked
## and barred; a skin of wine, he sleeps where he sits and the key is yours; each captive her word and gone.
func _test_wine(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_delivered(session, "night")
	state.marks["救了一半"] = 1 # TEST-ONLY: 关北's sneak
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"word", "delivered: 林忌's word next")
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "新关了三个人") and state.marks.get("林忌说了地牢", 0) == 1, "林忌: three new captives, the key on the jailer, the 名册 in the iron box")
	_check(_said(_ask(temple, lin, "逆灵宫"), "那人好酒"), "and again: the key, the wine")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"cells" and _shown(session).contains("西牢房：槐阳来的妇人 ✗"), "the cells next, the three on the page: %s" % _shown(session))
	session.wear_player_item(temple.give_new_item_to_player(CROWN))
	var wine: StringName = temple.give_new_item_to_player(WINESKIN)
	# By day: the one jailer.
	var dungeon: WorldMapController = MapPlaces.enter(session, CORRIDOR, CORRIDOR_POINT)
	await _settle(tree)
	var ward: NpcRuntimeState = _first(session, CORRIDOR, WARD)
	_check(ward != null and _count_in(session, CORRIDOR, KEYED) == 0 and _count_in(session, CORRIDOR, DOZER) == 0, "by day one jailer keeps the passage; 第三章's two are gone")
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the crown: he minds nobody")
	for cell: Array in CELLS:
		_check(_count_in(session, cell[0], cell[2]) == 1, "%s in %s" % [cell[2], cell[0]])
	_check(await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, &"niling.cell_huo.door", CORRIDOR)) and not dungeon.open_door(&"niling.cell_huo.door"), "no key: the iron door stays shut")
	_check(dungeon.select_npc(ward.character_id), "the jailer selected")
	var given: ItemHandlingResult = dungeon.give_to_selected(wine)
	_check(given != null and _said(given.lines, "比宫里的烈") and state.marks.get("灌醉了狱卒", 0) == 1 and not _carried(session, KEY).is_empty(), "the wine: he drinks, sleeps, the key is yours (%s)" % [given.lines if given != null else []])
	_check(ward.has_flag(&"mood/drunk"), "he lies drunk")
	await _free_all(tree, session, dungeon)
	_check(_said(_recent(session.shared_ui(), 40), "王石头"), "the woman is 王石头's mother (关北 救了一半)")
	session.record_journal()
	_check(state.quests.has("faction.niling/cells") and DeedLog.done(state, "放走了逆灵宫地牢里新关的三个人") and StoryQuestLog.current_step(state, quest).step_id == &"ledger", "the cells done; the 名册 next")
	var ui: SharedGameplayUI = session.shared_ui()
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("地牢里新关的三个人，是你放出来的"), "the 声望 page: %s" % ui.standing_page.shown_text())
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.niling_cells_emptied.bind("night"), ["灌醉了狱卒", "救了一半"])
	_check(missing.is_empty(), "played as niling_cells_emptied(night) writes: %s" % [missing])
	# Left the map and back: the jailer gone with the captives.
	MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	MapPlaces.enter(session, CORRIDOR, CORRIDOR_POINT)
	await _settle(tree)
	_check(_count_in(session, CORRIDOR, WARD) == 0, "the cells empty, the jailer is off the stage")


## The 玄冥子 door (关北 踏平): at 子时 the jailer asleep on the bench, the key on the nail over his head.
func _test_nail(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	await _told(tree, session, "xuan")
	state.marks["踏平了工地"] = 1 # TEST-ONLY: 关北's raid
	_check(session.wait_until_phase([&"midnight"]), "子时")
	var dungeon: WorldMapController = MapPlaces.enter(session, CORRIDOR, CORRIDOR_POINT)
	await _settle(tree)
	_check(_first(session, CORRIDOR, DOZER) != null and _count_in(session, CORRIDOR, WARD) == 0, "子时: the jailer asleep, nobody awake")
	_check(await _use(tree, dungeon, &"niling.corridor.nail") and state.marks.get("摘了钉上的钥匙", 0) == 1 and not _carried(session, KEY).is_empty(), "the key off the nail")
	_check(await _use(tree, dungeon, &"niling.corridor.nail") and _said(_recent(session.shared_ui(), 2), "已经在你身上"), "not twice")
	await _free_all(tree, session, dungeon)
	_check(_said(_recent(session.shared_ui(), 40), "城外八户"), "the woman of one of the eight households (关北 踏平)")
	_check(state.marks.get("放了采药人", 0) == 1, "all three out")


## The 林忌 door: 第三章's key still carried — the doors open, but the jailer awake bars the cells; 蒙汗药 in his jar.
func _test_old_key_and_drug(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var temple: WorldMapController = await _told(tree, session, "lin")
	temple.give_new_item_to_player(KEY) # TEST-ONLY: kept since 第三章
	temple.give_new_item_to_player(DRUG) # TEST-ONLY: from 青石村
	var dungeon: WorldMapController = MapPlaces.enter(session, CORRIDOR, CORRIDOR_POINT)
	await _settle(tree)
	_check(_first(session, CORRIDOR, WARD) != null, "the jailer by day")
	_check(await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, &"niling.cell_huo.door", CORRIDOR)) and dungeon.open_door(&"niling.cell_huo.door"), "the old key opens the door")
	await MapPlaces.drive(tree, dungeon, MapPlaces.zone_spot(dungeon, &"niling.cell_huo"))
	_check(session.player_runtime().world_location().zone_id == CORRIDOR and _said(_recent(session.shared_ui(), 4), "谁也不许近") and state.marks.get("放了槐阳的妇人", 0) == 0, "but he bars the cell while he stands awake")
	_check(await _use(tree, dungeon, &"niling.corridor.jars") and state.marks.get("灌醉了狱卒", 0) == 1 and _carried(session, DRUG).is_empty() and _carried_count(session, KEY) == 1, "蒙汗药 in his jar: he drinks and sleeps; no second key (%d)" % _carried_count(session, KEY))
	_check(_first(session, CORRIDOR, WARD).has_flag(&"mood/drunk"), "he lies drunk")
	await _free_all(tree, session, dungeon)
	_check(state.marks.get("放了槐阳的妇人", 0) == 1 and state.marks.get("放了货郎", 0) == 1, "the cells open to one now")


## The 名册 taken at night while the 管事 sleeps: asked first, a 疑点, the 任务 page says which.
func _test_ledger_taken(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_cells_emptied(session, "night")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"ledger", "the 名册 to settle")
	var map: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	session.wear_player_item(map.give_new_item_to_player(CROWN))
	map.give_new_item_to_player(KEY)
	# By day the 管事 keeps his hand on it.
	var hall: WorldMapController = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.counting.box") and _said(_recent(ui, 3), "宫主的东西") and not state.marks.has("看过名册的原本"), "by day: 这是宫主的东西")
	_check(session.wait_until_phase([&"night"]), "night")
	hall = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	hall = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.counting.box") and state.marks.get("看过名册的原本", 0) == 1 and _said(_recent(ui, 6), "兵部之印"), "opened: the stamps of who sent them")
	_check(await _use(tree, hall, &"niling.counting.box") and ui.is_asking() and ui.confirm_prompt.message.text.contains("那是一条疑点") and ui.confirm_prompt.confirm_button.text == "带走名册", "taking it is asked first, its 疑点 said")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(not _carried(session, REGISTER).is_empty() and state.marks.get("名册不见了", 0) == 1, "taken: 名册不见了")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"take") and _shown(session).contains("疑点：2／3") and _shown(session).contains("名册不见了"), "疑点 2／3 and which: %s" % _shown(session))
	_check(await _use(tree, hall, &"niling.counting.box") and _said(_recent(ui, 2), "铁匣空着"), "the box empty now")
	map = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(map, lin, "名册"), "带它上京"), "林忌: take it to the capital")
	state.marks["皇城一章"] = 1 # TEST-ONLY: 京师 settled
	_check(_said(_ask(map, lin, "名册"), "程不平"), "after it: to 程不平")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("宫里在找一本不见了的名册"), "the 声望 page: %s" % ui.standing_page.shown_text())


## The 名册 left: told to 林忌 (asked first), no 疑点.
func _test_ledger_left(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_cells_emptied(session, "lin")
	session.record_journal()
	var map: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	session.wear_player_item(map.give_new_item_to_player(CROWN))
	map.give_new_item_to_player(KEY)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(map.select_npc(lin.character_id) and not map.ask_topics_selected().has("名册"), "名册 not on 林忌's list before the box is opened")
	_check(session.wait_until_phase([&"night"]), "night")
	var hall: WorldMapController = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.counting.box") and state.marks.get("看过名册的原本", 0) == 1, "opened and read")
	map = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	lin = _first(session, TEMPLE, LIN)
	_check(map.select_npc(lin.character_id) and map.ask_topics_selected().has("名册") and lin.definition().talk().confirm_applies("名册", state.marks) and lin.definition().talk().ask_confirm("名册").contains("少了一样物证"), "名册 listed; leaving it is asked first")
	_check(_said(_ask(map, lin, "名册"), "看不出你") and state.marks.get("名册留在了匣里", 0) == 1, "left: 林忌 says they will not see you")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"leave") and _shown(session).contains("疑点：1／3") and not state.marks.has("名册不见了"), "no 疑点 for it: %s" % _shown(session))
	_check(not lin.definition().talk().confirm_applies("名册", state.marks), "asked once")
	hall = MapPlaces.enter(session, COUNTING, COUNTING_POINT)
	await _settle(tree)
	_check(await _use(tree, hall, &"niling.counting.box") and _said(_recent(ui, 2), "不动它") and _carried(session, REGISTER).is_empty(), "the box: you told 林忌 you would not")


## 玄冥子 lives on the cliff (the chase, spared, the 残卷 back to him): his errand; at 子时 the bar lifted past the 巡殿
## (once), the drawer under the master's desk; the 天书 for the 六阴剑谱 and the hour; the manual read to 40.
func _test_scripture(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_ledger(session, "xuan", false)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"scripture", "玄冥子 lives: the 天书 to do")
	var cliff: WorldMapController = MapPlaces.enter(session, CLIFF, CLIFF_POINT)
	await _settle(tree)
	session.wear_player_item(cliff.give_new_item_to_player(CROWN))
	var xuan: NpcRuntimeState = _first(session, CLIFF, XUAN)
	xuan.put_in_mood(xuan.definition().hooks().moods["owed"]) # TEST-ONLY: as the duel's 放过 left him
	_check(cliff.select_npc(xuan.character_id) and cliff.ask_topics_selected().has("天书"), "天书 on his list once 林忌 told of the dungeon")
	_check(_said(_ask(cliff, xuan, "天书"), "书案底下的暗格") and state.marks.get("玄冥子托你取天书", 0) == 1, "玄冥子: the lower half, under the master's desk at 子时; the bar")
	# By day the drawer is empty.
	var master: WorldMapController = MapPlaces.enter(session, MASTER, MASTER_POINT)
	await _settle(tree)
	_check(await _use(tree, master, &"niling.master.desk") and _said(_recent(ui, 2), "子时它才回到这里") and _carried(session, SCRIPTURE).is_empty(), "by day: on the 前殿's table, not here")
	# 子时: the 巡殿, the barred door, the bar lifted.
	_check(session.wait_until_phase([&"midnight"]), "子时")
	var hall: WorldMapController = MapPlaces.enter(session, FRONT, FRONT_POINT)
	await _settle(tree)
	var patrol: NpcRuntimeState = _first(session, FRONT, PATROL)
	_check(patrol != null, "the 巡殿 on his round")
	if patrol == null:
		return
	var body: WorldCharacterBody2D = hall.npcs.runtime_body_for_character(patrol.character_id)
	hall.npc_life.npc_walker().cancel(patrol.character_id) # TEST-ONLY: he stands still, looking away
	body.global_position = MapPlaces.zone_spot(hall, FRONT) + Vector2(-200, 80)
	body.facing = Vector2.LEFT
	_check(await _use(tree, hall, &"niling.front.bar") and state.marks.get("后殿的门闩开了", 0) == 1, "the bar lifted through the gap")
	_check(await MapPlaces.drive(tree, hall, MapPlaces.door_spot(hall, &"niling.altar.door", FRONT)) and hall.open_door(&"niling.altar.door"), "the 北门 opened")
	_check(await MapPlaces.take_passage(tree, hall, &"niling.front.north", 300) and not state.marks.has("后殿的门闩开了") and state.marks.get("子时在后殿外被撞见", 0) == 0, "through, unseen; the bar falls again behind")
	master = MapPlaces.enter(session, MASTER, MASTER_POINT)
	await _settle(tree)
	_check(await _use(tree, master, &"niling.master.desk") and not _carried(session, SCRIPTURE).is_empty() and state.marks.get("取了天书", 0) == 1, "the drawer: the lower half of the 逆灵天书")
	cliff = MapPlaces.enter(session, CLIFF, CLIFF_POINT)
	await _settle(tree)
	xuan = _first(session, CLIFF, XUAN)
	if not xuan.has_flag(&"mood/owed"):
		xuan.put_in_mood(xuan.definition().hooks().moods["owed"]) # TEST-ONLY
	_check(cliff.select_npc(xuan.character_id), "玄冥子 selected")
	var given: ItemHandlingResult = cliff.give_to_selected(_carried(session, SCRIPTURE))
	_check(given != null and _said(given.lines, "站在他身后的是我") and _said(given.lines, "是这里教的") and not _carried(session, MANUAL).is_empty(), "the 天书 for the 剑谱; the hour he means to strike; 晚月庄's killer was taught here (%s)" % [given.lines if given != null else []])
	_check(state.marks.get("天书给了玄冥子", 0) == 1 and state.marks.get("玄冥子要取代商玦", 0) == 1, "what 逆灵宫 C reads")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"book") and DeedLog.done(state, "替玄冥子取来了《逆灵天书》的下半部") and StoryQuestLog.current_step(state, quest).step_id == &"next", "the 天书 done; the line waits on 逆灵宫 C")
	# The manual: six-chaos-sword.c's valid_learn, read to 40.
	var manual_id: StringName = _carried(session, MANUAL)
	state.skills.set_raw_level(SkillIds.LITERATE, 10) # TEST-ONLY
	state.progression.combat_experience = 30000 # TEST-ONLY: 研读 wants it
	state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: the 神 it costs
	state.recovery.inner_force = CharacterInternalResourceState.new(0, 99) # TEST-ONLY
	state.equipment.wield(Martial.sword(), false) # TEST-ONLY: a sword in hand
	_check(session.martial_arts().study(manual_id).outcome != StudyResult.Outcome.STUDIED, "max_force 99: 内力不够 (six-chaos-sword.c)")
	state.recovery.inner_force = CharacterInternalResourceState.new(0, 100) # TEST-ONLY
	var first: StudyResult = session.martial_arts().study(manual_id)
	_check(first.outcome == StudyResult.Outcome.STUDIED and ui.log_lines()[-1].contains("六阴追魂剑"), "研读: 六阴追魂剑 begun: %s" % ui.log_lines()[-1])
	state.skills.set_raw_level(&"six-chaos-sword", 41) # TEST-ONLY: past what the book teaches
	_check(session.martial_arts().study(manual_id).outcome == StudyResult.Outcome.TOO_SHALLOW, "past 40 it is 太浅了")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("他教你的，是六阴剑"), "the 声望 page: %s" % ui.standing_page.shown_text())


## No 玄冥子 on the cliff (the rescue; or 了结 on the chase): the 天书 step is routed past, the line goes on.
func _test_no_xuan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_ledger(session, "night", true)
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"none") and StoryQuestLog.current_step(state, quest).step_id == &"next", "the rescue: no 玄冥子, the line on to 逆灵宫 C")
	_check(_shown(session).contains("疑点：2／3"), "那一夜丢了人 and 名册不见了: %s" % _shown(session))


## The chase, 玄冥子 spared and then killed after all: routed past too.
func _test_killed_xuan(_tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_ledger(session, "lin", false)
	state.marks["了结了玄冥子"] = 1 # TEST-ONLY: as his die_marks_killer writes
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"none") and StoryQuestLog.current_step(state, quest).step_id == &"next", "玄冥子 killed: routed past too")
	_check(GameContent.catalog().npc(XUAN).hooks().die_marks_killer == "了结了玄冥子", "his killer is marked")


## 卧底 A delivered through `door`, then 林忌's word on the dungeon asked for: at the temple, the crown on.
func _told(tree: SceneTree, session: WorldSessionController, door: String) -> WorldMapController:
	StoryFixtures.niling_delivered(session, door)
	session.record_journal()
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	_ask(temple, _first(session, TEMPLE, LIN), "逆灵宫")
	session.record_journal()
	session.wear_player_item(temple.give_new_item_to_player(CROWN))
	return temple


## Opens each cell with the key carried and walks in: each captive says a word and goes.
func _free_all(tree: SceneTree, session: WorldSessionController, dungeon: WorldMapController) -> void:
	var state: CharacterState = session.player_runtime().state
	for cell: Array in CELLS:
		var door: WorldDoor = dungeon.door(cell[1])
		if door != null and not door.is_open():
			await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, cell[1], CORRIDOR))
			dungeon.open_door(cell[1])
		await MapPlaces.drive_to_zone(tree, dungeon, cell[0])
		session.advance_npc_heartbeat(0.5) # TEST-ONLY: the beat that fires a reaction (set_process off)
		await _settle(tree)
		_check(state.marks.get(cell[3], 0) == 1 and _count_in(session, cell[0], cell[2]) == 0, "%s: a word and gone by the side door" % cell[2])
		await MapPlaces.drive_to_zone(tree, dungeon, CORRIDOR)


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


func _carried_count(session: WorldSessionController, definition_id: StringName) -> int:
	var map: WorldMapController = session.active_map() as WorldMapController
	var found: int = 0
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			found += 1
	return found


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
