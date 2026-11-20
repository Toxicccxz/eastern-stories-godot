extends RefCounted

## 势力线第一批 卧底 C (计划 build/plans/势力线第一批_计划.md §6 逆灵宫 C 第 7–9 条 and「主线打完才进来的人」, §8;
## DECISIONS「卧底 C」): 收网 — once 第十章 is over 林忌 asks which night and which way. 前夜倒戈: the hour and the way to
## 茅山, two of 商玦's four in the 冰龙厅, 茅山 a band at the 点将 (林忌 on the bank), the 黑冠 spent. 潜伏到底 (fewer
## than three 疑点): down the lake in the crown, the first blow from behind (商玦 drawn with half his kee gone), his four
## on the player first whatever the dragons. Three 疑点 any time: the line lapses, and in the 前院 玄冥子 (or the 领诵
## where he does not live) waits with his 第三章 words — the crown no more, the 道观 on them, three 道士 at the 野羊山
## turn after. The 黑衣人 card at the end; after the 终章, 林忌 asks of the 余孽 (大会 A's).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RealFight := preload("res://tests/support/real_fight.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const QUEST: StringName = &"faction.niling"
const LIN: StringName = &"common.npc.taoist.taolord"
const CROWN: StringName = &"native:niling/black_crown"
const TEMPLE: StringName = &"temple.temple1"
const TEMPLE_POINT: StringName = &"temple.temple1.taolord.1"
const YARD: StringName = &"niling.yard"
const YARD_POINT: StringName = &"niling.yard.hall_return"
const GUARD: StringName = &"native.npc.niling_gate_guard"
const XUAN_YARD: StringName = &"native.npc.xuan_mingzi_unmasking"
const CHANTER_YARD: StringName = &"native.npc.niling_lead_chanter_unmasking"
const XUAN_CLIFF: StringName = &"native.npc.xuan_mingzi_cliff"
const PURSUER: StringName = &"native.npc.niling_pursuer"
const TURN: StringName = &"goathill.mroad4"
const TURN_POINT: StringName = &"goathill.mroad4.rope_return"
const HALL: StringName = &"village.lakebottom2"
const HALL_POINT: StringName = &"village.lakebottom2.pool_return"
const TAOIST_LAKE: StringName = &"native.npc.niling_taoist_lake"
const SHANG_FIGHTING: StringName = &"native.npc.shang_jue_fighting"
## The 道观's own people, who let the crown pass while it holds.
const PALACE: Array[StringName] = [
	&"native.npc.niling_gatekeeper", &"native.npc.niling_gate_guard", &"native.npc.niling_store_taoist", &"native.npc.niling_chanter",
	&"native.npc.niling_lead_chanter", &"native.npc.niling_steward", &"native.npc.niling_jailer", &"native.npc.niling_jailer_keyed",
	&"native.npc.niling_patrol", &"native.npc.niling_jailer_ward",
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_turn, _test_deep_chosen, _test_unmasked_xuan, _test_unmasked_chanter, _test_after_unmasked, _test_missed, _test_after_finale, _test_hall_turn, _test_hall_deep, _test_hall_deep_dragons, _test_hall_deep_bare]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(-5) == [&"hour", &"split", &"hall_turn", &"hall_deep", &"aftermath"], "C's steps after B's: %s" % [ids])
	_check(quest.step(&"hour").weight == StoryQuestDefinition.WEIGHT_ROUTE, "收网 or the 余孽: routed by the main story, no choice")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.weight == StoryQuestDefinition.WEIGHT_BIG and split.only_after == &"net" and split.options.map(func(option: StoryQuestDefinition.Option) -> StringName: return option.option_id) == [&"turn", &"deep", &"missed"], "the line's one split: 倒戈 or 潜伏 (or the night let pass)")
	_check(quest.branches_of(StoryQuestDefinition.WEIGHT_BIG) == 2 and quest.branches_of(StoryQuestDefinition.WEIGHT_SMALL) == 2, "1 big on each way the main story routes (收网; after the 终章 大会 A's 余孽), 2 small (owner 2026-11-09)")
	_check(split.objective.contains("疑点不到三条") and split.objective.contains("四个道士会先扑你") and split.objective.contains("黑冠从此没用"), "both sides' costs said before the choice")
	_check(quest.step(&"hall_turn").only_after == &"turn" and quest.step(&"hall_deep").only_after == &"deep" and quest.step(&"aftermath").only_after == &"remnant", "each way its own last step")
	_check(quest.lapses != null and quest.lapsed_mark == "疑点满了" and quest.lapsed_text.contains("下回戴着冠进前院") and quest.lapsed_text.contains("不必打") and quest.lapsed_text.contains("剑谱也还在你手里"), "three 疑点: the line lapses, what was done still counts")
	for id: StringName in PALACE:
		var when: JournalEntryDefinition = catalog.npc(id).dealings().ignores_when
		_check(when != null and when.when == JournalEntryDefinition.When.ALL and when.parts.size() == 3, "%s minds the crown only while it holds (niling.crown_holds)" % id)
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	_check(helpers.amount == 3 and helpers.parts.any(func(part: JournalEntryDefinition) -> bool: return part.when == JournalEntryDefinition.When.MARK and part.key == "前夜倒戈"), "茅山 one band more; three still enough")
	var talk: NpcTalk = catalog.npc(LIN).talk()
	_check(talk.ask_confirm("倒戈").contains("只剩两个道士") and talk.ask_confirm("倒戈").contains("黑冠从此没用"), "倒戈 asked first, its cost said")
	_check(talk.ask_confirm("潜伏").contains("四个道士会先扑你") and talk.ask_confirm("潜伏").contains("满了三条疑点的"), "潜伏 asked first, its cost said")
	# The ending: the 黑衣人 card, and the 野羊山 card's man in the snow named.
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var cards: Dictionary = {}
	for card: EpilogueDefinition.Card in ending.cards:
		cards[card.card_id] = card
	_check(cards.has(&"black_robe") and (cards[&"black_robe"] as EpilogueDefinition.Card).lines.size() == 3, "the 黑衣人 card, a line for each end")
	_check((cards[&"goathill"] as EpilogueDefinition.Card).lines.any(func(line: EpilogueDefinition.Line) -> bool: return line.text.contains("见过商玦")), "the man in the north snow is named 商玦")
	for end: Array in [["前夜倒戈", "截在北麓"], ["被识破", "茅山的眼线"]]:
		var state := CharacterState.new()
		state.marks[end[0]] = 1
		var shown: Array[String] = (cards[&"black_robe"] as EpilogueDefinition.Card).shown(func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, {}, {}))
		_check(shown.size() == 1 and shown[0].contains(end[1]), "%s: one line (%s)" % [end[0], shown])
	var deep := CharacterState.new()
	for mark: String in ["潜伏到底", "潜伏那一剑", "商玦倒了"]:
		deep.marks[mark] = 1
	var deep_shown: Array[String] = (cards[&"black_robe"] as EpilogueDefinition.Card).shown(func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, deep, {}, {}))
	_check(deep_shown.size() == 1 and deep_shown[0].contains("从商玦背后来的"), "潜伏到底: the first blow (%s)" % [deep_shown])


## The chase (玄冥子 spared, the scroll to him): B done, 收网 waits on 第十章; then 林忌 asks; 倒戈. The crown is spent:
## the 前院's two fall on the one wearing it.
func _test_turn(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_scripture(session, "xuan", false)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"hour" and state.marks.get("后山的事了了", 0) == 1, "B done: 收网 next")
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "那一夜才会来") and not state.marks.has("林忌说了收网"), "before 第十章 is over: the night has not come")
	_check(temple.select_npc(lin.character_id) and not temple.ask_topics_selected().has("倒戈") and not temple.ask_topics_selected().has("潜伏"), "neither way on his list yet")
	state.marks["岚城一章"] = 1 # TEST-ONLY: 第十章 over
	_check(_said(_ask(temple, lin, "逆灵宫"), "倒戈，还是潜伏，你定") and state.marks.get("林忌说了收网", 0) == 1, "林忌: which night, which way")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"net") and StoryQuestLog.current_step(state, quest).step_id == &"split", "收网: the split next")
	var talk: NpcTalk = lin.definition().talk()
	_check(temple.select_npc(lin.character_id) and temple.ask_topics_selected().has("倒戈") and temple.ask_topics_selected().has("潜伏") and talk.confirm_applies("倒戈", state.marks) and talk.confirm_applies("潜伏", state.marks), "both listed, both asked first")
	_check(_said(_ask(temple, lin, "倒戈"), "北麓下湖的路上有茅山的人") and state.marks.get("前夜倒戈", 0) == 1, "倒戈: the hour and the way to 茅山")
	_check(not talk.confirm_applies("潜伏", state.marks) and _said(_ask(temple, lin, "潜伏"), "那顶冠，没用了") and not state.marks.has("潜伏到底"), "and 潜伏 is gone")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"turn") and StoryQuestLog.current_step(state, quest).step_id == &"hall_turn" and DeedLog.done(state, "唤首前夜，把逆灵宫下湖的时辰和路交给了茅山"), "倒戈 taken: the 冰龙厅 next")
	var ui: SharedGameplayUI = session.shared_ui()
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("交给了茅山"), "the 声望 page: %s" % ui.standing_page.shown_text())
	# The crown, spent.
	session.wear_player_item(temple.give_new_item_to_player(CROWN))
	var gate: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(_first(session, YARD, XUAN_YARD) == null and _first(session, YARD, CHANTER_YARD) == null, "turned: nobody waits in the 前院")
	await _until_fight(tree, session, gate)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "in the crown, the 前院's guards fall on them")


## The night door, no 疑点 caught, the 名册 left: one 疑点; 潜伏 chosen.
func _test_deep_chosen(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_scripture(session, "night", false)
	state.marks["岚城一章"] = 1 # TEST-ONLY
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"none") and StoryQuestLog.current_step(state, quest).step_id == &"hour", "no 玄冥子: routed past, 收网 next")
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_ask(temple, lin, "逆灵宫")
	_check(_said(_ask(temple, lin, "潜伏"), "站在他身后的是你") and state.marks.get("潜伏到底", 0) == 1, "潜伏到底")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"deep") and StoryQuestLog.current_step(state, quest).step_id == &"hall_deep" and _shown(session).contains("第一剑是你的"), "潜伏 taken: the 冰龙厅 next: %s" % _shown(session))
	_check(JournalLog.holds(GameContent.catalog().conditions()["niling.deep"], state, {}, {}), "niling.deep holds")
	# The crown still holds in the 道观.
	session.wear_player_item(temple.give_new_item_to_player(CROWN))
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter() and _first(session, YARD, GUARD) != null, "潜伏: the guards mind nobody in the crown")
	# A 疑点 more after the choice, and two more: the line lapses, 潜伏 no more.
	for mark: String in ["子时在后殿外被撞见", "名册不见了"]:
		state.marks[mark] = 1 # TEST-ONLY
	session.record_journal()
	_check(StoryQuestLog.is_lapsed(state, quest) and state.marks.get("疑点满了", 0) == 1, "three 疑点 after all: lapsed")
	_check(not JournalLog.holds(GameContent.catalog().conditions()["niling.deep"], state, {}, {}), "and the 冰龙厅 no longer the 潜伏 one")


## The chase, the scroll burnt (残卷没回宫), the 名册 taken, caught once: three 疑点. The line lapses; 林忌 sends nobody
## back; in the 前院 玄冥子 waits: his words, what gave the player away, the crown no more. Then the turn.
func _test_unmasked_xuan(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_ledger(session, "lin", true, 1)
	session.record_journal()
	_check(StoryQuestLog.is_lapsed(state, quest) and state.marks.get("疑点满了", 0) == 1 and not StoryQuestLog.is_active(state, quest), "three 疑点: the line lapses")
	var ui: SharedGameplayUI = session.shared_ui()
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("下回戴着冠进前院") and ui.quest_page.shown_text().contains("出了前院的门就算逃过了"), "the 任务 page says what comes, and that it is an escape: %s" % ui.quest_page.shown_text())
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	state.marks["林忌说了收网"] = 1 # TEST-ONLY: as if asked before the third
	var talk: NpcTalk = lin.definition().talk()
	_check(not talk.confirm_applies("潜伏", state.marks) and _said(_ask(temple, lin, "潜伏"), "走不得") and not state.marks.has("潜伏到底"), "three 疑点: 潜伏 cannot be chosen")
	_check(_said(_ask(temple, lin, "逆灵宫"), "破绽太多"), "林忌: do not go back")
	state.marks.erase("林忌说了收网") # TEST-ONLY
	var unmasking: JournalEntryDefinition = GameContent.catalog().conditions()["niling.unmasking"]
	_check(not JournalLog.holds(unmasking, state, {}, {}) and JournalLog.holds(unmasking, state, {}, {}, &"", {CROWN: true}), "the 前院's scene waits for one who comes in wearing the crown")
	session.wear_player_item(temple.give_new_item_to_player(CROWN))
	# DECISIONS「势力线的仗」: an escape, played with real numbers — the earliest arrival of the line
	# (第三章 done), a sword in hand, 玄冥子 and the 前院 as the data makes them.
	RealFight.ready_player(session, Arrival.main_story(&"main.chapter4"))
	var gate: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var xuan: NpcRuntimeState = _first(session, YARD, XUAN_YARD)
	_check(xuan != null and _first(session, YARD, CHANTER_YARD) == null, "玄冥子 waits in the 前院")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	# The scene, then a moment before he strikes: whoever comes in (the patrol's too) can still go.
	var struck_at: int = -1
	for second: int in 12:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		gate.hostilities.process_pending_aggression()
		if struck_at < 0 and xuan != null and coordinator.has_active_encounter() and coordinator.active_encounter().participant_for(xuan.character_id) != null:
			struck_at = second + 1
	var said: Array[String] = ui.log_lines()
	_check(_said(said, "你戴着我们的冠，却不是我们的人") and _said(said, "那卷残卷没有回宫") and _said(said, "铁匣里那本名册") and _said(said, "北门外听的") and not _said(said, "地牢空了"), "his 第三章 words and what gave them away")
	_check(_said(said, "这一仗你打不过") and _said(said, "逃得出去，就算过了这一关"), "the act says plainly: run")
	# The gate guards turn at once (the crown no more); 玄冥子 himself waits (and joins no fight under way).
	_check(struck_at < 0 or struck_at >= 5, "a moment to run before he strikes (struck at second %d)" % struck_at)
	_check(state.marks.get("被识破", 0) == 1 and coordinator.has_active_encounter(), "被识破: the 道观 on them")
	_check(not JournalLog.holds(GameContent.catalog().conditions()["niling.crown_holds"], state, {}, {}, &"", {CROWN: true}), "the crown no more")
	# 逃跑, then out of the 前院's gate and down: alive is through.
	var encounter_id: StringName = coordinator.active_encounter().encounter_id if coordinator.has_active_encounter() else &""
	for attempt: int in 6:
		if not coordinator.has_active_encounter():
			break
		coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), coordinator.active_encounter().encounter_id, session.player_runtime().character_id, CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE))
		for step: int in 20:
			if not coordinator.has_active_encounter():
				break
			coordinator.advance_scheduler(1.0)
	session.shared_ui().dismiss_current_panel()
	_check(not encounter_id.is_empty() and not coordinator.has_active_encounter() and RealFight.player_stands(session), "逃跑 gets the player out of the fight on their feet")
	MapPlaces.enter(session, &"niling.goods_path", &"niling.goods_path.gate_return")
	for second: int in 8:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not coordinator.has_active_encounter() and RealFight.player_stands(session), "out of the 前院 and down the path: alive, nobody on them")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(StoryQuestLog.is_lapsed(state, quest) and ui.quest_page.shown_text().contains("出了前院的门就算逃过了"), "the 任务 page: the line lapsed, nothing owed: %s" % ui.quest_page.shown_text())
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("你被识破了"), "the 声望 page: %s" % ui.standing_page.shown_text())


## The night door (the 领诵, no 玄冥子), the 名册 taken, caught once: three 疑点; the 领诵 waits. After: the 野羊山 turn,
## three 道士 till they are down; the cliff's 玄冥子 not there (none on this door anyway: the chase's own is the xuan test).
func _test_unmasked_chanter(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.niling_ledger(session, "night", true, 1)
	session.record_journal()
	var map: WorldMapController = session.active_map() as WorldMapController
	session.wear_player_item(map.give_new_item_to_player(CROWN))
	var gate: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(_first(session, YARD, CHANTER_YARD) != null and _first(session, YARD, XUAN_YARD) == null, "no 玄冥子: the 领诵 waits")
	await _until_fight(tree, session, gate)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_said(said, "你戴着我们的冠，却不是我们的人") and _said(said, "大弟子那一夜在后殿就说过") and _said(said, "地牢空了"), "玄冥子's words in his mouth, and the night")
	_check(state.marks.get("被识破", 0) == 1, "被识破")


## 被识破 on the chase: off the cliff, the turn's three. (A session of its own: the 前院's fight is not fought out.)
func _test_after_unmasked(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.niling_ledger(session, "lin", true, 1)
	state.marks["被识破"] = 1 # TEST-ONLY: as the 前院's scene writes
	session.record_journal()
	MapPlaces.enter(session, &"niling.cliff_path", &"niling.cliff_path.door_arrival")
	await _settle(tree)
	_check(_first(session, &"niling.cliff_path", XUAN_CLIFF) == null, "found out: 玄冥子 is off the cliff")
	MapPlaces.enter(session, TURN, TURN_POINT)
	await _settle(tree)
	_check(_count_in(session, TURN, PURSUER) == 3, "three 道士 at the turn")


## Told of 收网, the lake's night comes and nothing chosen: the split is done unchosen (no line stuck), the topics closed.
func _test_missed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_scripture(session, "night", false)
	state.marks["岚城一章"] = 1 # TEST-ONLY
	session.record_journal()
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_ask(temple, lin, "逆灵宫")
	state.marks["下了决战"] = 1 # TEST-ONLY: the night of the battle
	var talk: NpcTalk = lin.definition().talk()
	_check(not talk.confirm_applies("倒戈", state.marks) and _said(_ask(temple, lin, "倒戈"), "来不及了") and not state.marks.has("前夜倒戈"), "the night come: too late to turn")
	_check(_said(_ask(temple, lin, "逆灵宫"), "茅山没等到你的话"), "林忌: the night passed")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"missed") and StoryQuestLog.is_done(state, quest), "the split let pass: the line over, nothing left hanging")


## After the 终章: 林忌 asks of the 余孽 (续灯), no 收网; the line waits on the 虹台大会.
func _test_after_finale(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.niling_scripture(session, "night", false)
	for mark: String in ["岚城一章", "下了决战", "商玦倒了", "终章"]:
		state.marks[mark] = 1 # TEST-ONLY: the main story over
	session.record_journal()
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "续灯") and state.marks.get("林忌说了余孽", 0) == 1 and not state.marks.has("林忌说了收网"), "after the 终章: the 余孽, 续灯")
	_check(temple.select_npc(lin.character_id) and not temple.ask_topics_selected().has("倒戈"), "no 收网 to choose")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"remnant") and StoryQuestLog.current_step(state, quest).step_id == &"aftermath", "the line waits on the 虹台大会")


## The 冰龙厅 for one who turned, the dragons beaten: two of his four; 商玦 whole.
func _test_hall_turn(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.finale_dived(session)
	state.marks["前夜倒戈"] = 1 # TEST-ONLY
	state.marks["冰龙倒了"] = 1 # TEST-ONLY
	session.record_journal()
	MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.fisher.1")
	await _settle(tree)
	_check(_first(session, &"village.lakeside", &"native.npc.lin_ji_lake") != null, "林忌 on the bank")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT) # TEST-ONLY
	await _settle(tree)
	await _until_fight(tree, session, hall)
	_check(_said(session.shared_ui().log_lines(), "只走出来两个黑冠道士") and _count_in(session, HALL, TAOIST_LAKE) == 2, "two of his four")
	var shang: NpcRuntimeState = _first(session, HALL, SHANG_FIGHTING)
	_check(shang != null and shang.character_state.vitality.effective == shang.character_state.vitality.maximum, "商玦 drawn whole")


## 潜伏到底, the dragons beaten: the first blow, his four on the player, 商玦 drawn with half his kee gone.
func _test_hall_deep(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.finale_dived(session)
	state.marks["潜伏到底"] = 1 # TEST-ONLY
	state.marks["冰龙倒了"] = 1 # TEST-ONLY
	session.record_journal()
	MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.fisher.1")
	await _settle(tree)
	_check(_first(session, &"village.lakeside", &"native.npc.lin_ji_lake") == null, "no 茅山 on this ledger")
	_wear_crown(session)
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT) # TEST-ONLY
	await _settle(tree)
	await _until_fight(tree, session, hall)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_said(said, "你的剑先到了") and _said(said, "先扑向了你") and _count_in(session, HALL, TAOIST_LAKE) == 4, "the first blow; his four on the player")
	_check(state.marks.get("潜伏那一剑", 0) == 1, "the blow is written down (the ending, the 声望 page)")
	var shang: NpcRuntimeState = _first(session, HALL, SHANG_FIGHTING)
	var kee: CharacterResourceState = null if shang == null else shang.character_state.vitality
	_check(kee != null and kee.effective * 2 <= kee.maximum + 1 and kee.current <= kee.effective and kee.effective > 0, "商玦 wounded: %s" % [[] if kee == null else [kee.current, kee.effective, kee.maximum]])


## 潜伏到底 with the dragons never touched: they do not fall on the crowns; the four come all the same.
func _test_hall_deep_dragons(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.finale_dived(session)
	state.marks["潜伏到底"] = 1 # TEST-ONLY
	state.marks.erase("冰龙倒了") # TEST-ONLY
	session.record_journal()
	_wear_crown(session)
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT) # TEST-ONLY
	await _settle(tree)
	await _until_fight(tree, session, hall)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_said(said, "又盘了回去") and not _said(said, "被卷进了冰缝里") and _count_in(session, HALL, TAOIST_LAKE) == 4, "the dragons hold off; the four come")


## 潜伏到底 but the crown taken off: the 冰龙厅 as it is for anyone (the dragons on his four), no blow.
func _test_hall_deep_bare(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.finale_dived(session)
	state.marks["潜伏到底"] = 1 # TEST-ONLY
	state.marks.erase("冰龙倒了") # TEST-ONLY
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT) # TEST-ONLY
	await _settle(tree)
	await _until_fight(tree, session, hall)
	var said: Array[String] = session.shared_ui().log_lines()
	_check(_said(said, "被卷进了冰缝里") and not _said(said, "你的剑先到了") and not state.marks.has("潜伏那一剑") and _count_in(session, HALL, TAOIST_LAKE) == 0, "no crown on: the hall as for anyone")


func _wear_crown(session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	session.wear_player_item(map.give_new_item_to_player(CROWN)) # TEST-ONLY


func _until_fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for second: int in 30:
		if coordinator.has_active_encounter():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		map.hostilities.process_pending_aggression()


func _shown(session: WorldSessionController) -> String:
	var ui: SharedGameplayUI = session.shared_ui()
	ui.quest_page.fill(session.player_runtime().state, "小兄弟", "", session.quest_condition_test())
	return ui.quest_page.shown_text()


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
				found += 1
	return found


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
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
