extends RefCounted

## 势力线第一批 天邪 A (计划 build/plans/势力线第一批_计划.md §4; DECISIONS「天邪 A」「拿错了人」): the line
## begins with 拜师; 守山 — 潘军禅's word, three on the platform before 水烟阁 (there only for the watch),
## the spy who asks「哪一位」and whose 路引's 印色 is wrong (兵部's while 庾子建 sits, 颜违's after), 拿下
## asked first: the right one fights and is taken (his letter read by 潘军禅), a wrong one is held while
## the spy slips away; the report and 大弟子. Then the 镖单 (the small choice): for one who never played
## 第二章 a 手令 to 陈剑秋 first; to 潘军禅 (the 刑堂) or to 陈天星, who finds the route 兵部 named — one of
## the 揭发's proofs while 第九章 is open. Leaving the family ends the line.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const PAN: StringName = &"common.npc.fighter.executioner"
const SPY: StringName = &"native.npc.waterfog_spy"
const HOPEFUL: StringName = &"native.npc.waterfog_hopeful"
const COURIER: StringName = &"native.npc.waterfog_courier"
const JIANQIU: StringName = &"cloud.npc.b_header"
const TIANXING: StringName = &"city.npc.chen"
const LETTER: StringName = &"native:waterfog/spy_letter"
const WARRANT: StringName = &"native:waterfog/pan_warrant"
const NOTE: StringName = &"native:cloud/escort_note"
const QUEST: StringName = &"faction.celestial"
const HALL: StringName = &"waterfog.guildhall"
const HALL_POINT: StringName = &"waterfog.guildhall.executioner.1"
const YARD: StringName = &"waterfog.frontyard"
const YARD_POINT: StringName = &"waterfog.frontyard.gate_return"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_stranger, _test_caught, _test_wrong_man, _test_yan_spy, _test_proof, _test_lapse]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.starts.when == JournalEntryDefinition.When.FAMILY and quest.starts.key == "family.celestial", "faction.celestial: a 势力 quest that begins with 拜师")
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"hear", &"watch", &"report", &"escort", &"trace", &"next"], "its steps: %s" % [ids])
	var escort: StoryQuestDefinition.Step = quest.step(&"escort")
	_check(escort.is_branch() and escort.weight == StoryQuestDefinition.WEIGHT_SMALL and escort.options.size() == 2 and not escort.options[0].reward.deed.is_empty() and not escort.options[1].reward.deed.is_empty(), "the 镖单 is a small choice of two, each a deed")
	_check(escort.objective.contains("到此为止") and escort.objective.contains("查到底"), "the cost of either way is said before the choice")
	_check(quest.step(&"trace").only_after == &"chen", "陈天星's finding only after the 镖单 went to him")
	_check(quest.step(&"report").reward.rank_title == "大弟子" and quest.step(&"report").reward.rank_family == &"family.celestial", "守山 told: 大弟子")
	_check(quest.step(&"watch").keeps.has(SPY) and quest.step(&"watch").keeps.has(HOPEFUL) and quest.step(&"watch").keeps.has(COURIER), "the three at the gate are only knocked down while the watch lasts")
	_check(FileAccess.get_file_as_string("res://data/story/faction_celestial.json").contains("\"lapses\""), "leaving 天邪派 ends the line (DECISIONS「线断了」)")
	for spawn_id: StringName in [&"native.frontyard.spy", &"native.frontyard.hopeful", &"native.frontyard.courier"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.zone_id == YARD and spawn.map_id == &"waterfog.mountain", "%s stands before 水烟阁" % spawn_id)
	var spy: NpcDefinition = catalog.npc(SPY)
	_check(spy.hooks().spared_mark == "拿下了探子" and spy.hooks().spared_drop == LETTER and spy.hooks().spared_leave and spy.hooks().die_item_id == LETTER, "the spy taken: led off, his letter on the ground")
	_check(spy.talk().ask_confirm("拿下").contains("赔不是") and spy.talk().ask_confirm("拿下").contains("趁乱走掉"), "拿下 says what a wrong man costs")
	var expose: String = FileAccess.get_file_as_string("res://data/imperial/world.json")
	_check(expose.count("\"mark\": \"镖路查清了\"") == 4, "the 揭发 counts 镖路查清了 in both its lists, and says so: %d" % expose.count("\"mark\": \"镖路查清了\""))
	for id: StringName in [LETTER, WARRANT]:
		_check(catalog.item(id) != null, "%s exists" % id)


## No disciple: no line, nobody at the gate, 潘军禅 keeps the 执法使's business to the house.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	session.record_journal()
	_check(not state.quests.has("faction.celestial#started"), "no family: the line has not begun")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	_check(_said(_ask(hall, pan, "山门"), "不劳外人") and not state.marks.has("潘军禅说了山门"), "潘军禅 to a stranger: 不劳外人")
	_check(_said(_ask(hall, pan, "镖单"), "什么镖单"), "and of the 镖单: nothing")
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(_count_in(session, YARD, SPY) + _count_in(session, YARD, HOPEFUL) + _count_in(session, YARD, COURIER) == 0, "nobody waits at the gate")


## The spy taken (兵部's, the 印色 read), his letter to 潘军禅, 大弟子; then the 镖单 for one who never
## played 第二章: the 手令, 陈剑秋, and 陈天星, who finds the route.
func _test_caught(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.celestial_joined(session)
	state.marks["学过印色"] = 1 # TEST-ONLY: 第六章's 印色
	session.record_journal()
	_check(state.quests.has("faction.celestial#started") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"hear", "拜师: the line begins, 潘军禅 first")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("天邪派 · 水烟阁"), "the 势力 column has the line")
	# Before his word, nobody at the gate.
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(_count_in(session, YARD, SPY) == 0, "before 潘军禅's word: nobody at the gate")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	_check(_said(_ask(hall, pan, "山门"), "新面孔") and state.marks.get("潘军禅说了山门", 0) == 1, "潘军禅 to his own: a watch at the gate")
	session.record_journal()
	_check(state.quests.has("faction.celestial/hear"), "step hear done")
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(_count_in(session, YARD, SPY) == 1 and _count_in(session, YARD, HOPEFUL) == 1 and _count_in(session, YARD, COURIER) == 1, "three wait at the gate")
	var spy: NpcRuntimeState = _first(session, YARD, SPY)
	var boy: NpcRuntimeState = _first(session, YARD, HOPEFUL)
	var courier: NpcRuntimeState = _first(session, YARD, COURIER)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the spy leaves the player alone until found out")
	_check(_said(_ask(yard, boy, "盟主"), "卫盟主") and _said(_ask(yard, courier, "盟主"), "卫盟主"), "the boy and the courier know one 盟主")
	_check(_said(_ask(yard, spy, "盟主"), "哪一位") and _said(_ask(yard, spy, "盟主"), "在不在"), "the spy asks which, and whether he lives")
	_check(_said(_ask(yard, spy, "路引"), "兵部") and _said(_ask(yard, courier, "路引"), "没什么不对"), "learnt in 关北: the spy's 印色 is 兵部's; the courier's is a post's")
	_check(yard.select_npc(spy.character_id) and yard.ask_topics_selected().has("拿下"), "拿下 is on the list of one on watch")
	_check(spy.definition().talk().confirm_applies("拿下", state.marks), "and is asked first")
	_check(_said(_ask(yard, spy, "拿下"), "好眼力") and state.marks.get("认出了探子", 0) == 1, "拿下: found out")
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if session.combat_encounter_coordinator().has_active_encounter():
			break
	_check(session.combat_encounter_coordinator().has_active_encounter(), "found out, he fights")
	await _flee(tree, session)
	# TEST-ONLY: beaten and spared (keeps: he cannot be killed while the watch lasts), as 放过 does.
	session.npc_spared(spy)
	yard.npcs.leave_for_good(spy)
	_check(state.marks.get("拿下了探子", 0) == 1, "spared: 拿下了探子")
	_check(_said(_ask(yard, boy, "拿下"), "原来是他"), "the boy sees who it was")
	session.record_journal()
	_check(state.quests.has("faction.celestial/watch"), "step watch done")
	yard.give_new_item_to_player(LETTER) # TEST-ONLY: picked up where he lay
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	pan = _first(session, HALL, PAN)
	_check(_said(_ask(hall, pan, "山门"), "给我看看") and not state.marks.has("值守回了话"), "潘军禅 asks for the letter")
	_check(hall.select_npc(pan.character_id), "潘军禅 selected")
	var read: ItemHandlingResult = hall.give_to_selected(_carried(session, LETTER))
	_check(read != null and _said(read.lines, "兵部的公文纸") and state.marks.get("值守回了话", 0) == 1 and _carried(session, LETTER).is_empty(), "the letter read: 兵部's (%s)" % [[] if read == null else read.lines])
	session.record_journal()
	_check(state.quests.has("faction.celestial/report") and state.affiliation.family_title == "大弟子" and DeedLog.done(state, "替水烟阁在山门值过一班"), "step report done: 大弟子 (%s), the deed" % state.affiliation.family_title)
	_check(_recent(ui, 14).any(func(line: String) -> bool: return line.contains("【晋阶】")), "the rise is told")
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"escort", "next: the 镖单")
	MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(_count_in(session, YARD, HOPEFUL) + _count_in(session, YARD, COURIER) + _count_in(session, YARD, SPY) == 0, "the watch over, the gate is quiet")
	_check(StoryFixtures.missing_after_play(session, StoryFixtures.celestial_watched.bind(true), ["学过印色"]).is_empty(), "守山 played leaves what celestial_watched(caught) writes: %s" % [StoryFixtures.missing_after_play(session, StoryFixtures.celestial_watched.bind(true), ["学过印色"])])
	# The 镖单, for one who never played 第二章: the 手令 first.
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	pan = _first(session, HALL, PAN)
	_check(_said(_ask(hall, pan, "镖单"), "手令") and not _carried(session, WARRANT).is_empty() and state.marks.get("潘军禅说了镖单", 0) == 1, "no 镖单 seen: 潘军禅 writes a 手令")
	var bureau: WorldMapController = MapPlaces.enter(session, &"cloud.biaoju", &"cloud.biaoju.eroad2_entry")
	await _settle(tree)
	var jianqiu: NpcRuntimeState = _first(session, &"cloud.biaoju", JIANQIU)
	_check(_said(_ask(bureau, jianqiu, "失镖"), "拿来我看"), "陈剑秋 wants to see the 手令")
	_check(bureau.select_npc(jianqiu.character_id), "陈剑秋 selected")
	var traded: ItemHandlingResult = bureau.give_to_selected(_carried(session, WARRANT))
	_check(_carried(session, WARRANT).is_empty() and not _carried(session, NOTE).is_empty() and state.marks.get("看过镖单", 0) == 1, "the 手令 for the 镖单: %s" % [[] if traded == null else traded.lines])
	# To 陈天星.
	var capital: WorldMapController = MapPlaces.enter(session, &"city.biaoju", &"city.biaoju.street1_entry")
	await _settle(tree)
	var tianxing: NpcRuntimeState = _first(session, &"city.biaoju", TIANXING)
	_check(_said(_ask(capital, tianxing, "镖单"), "拿来我看"), "陈天星 knows the 镖单 for what it is")
	var asked: Array = tianxing.definition().dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == NOTE and rule.accept)
	_check(asked.size() == 1 and (asked[0] as NpcObjectRule).ask.contains("查到底") and (asked[0] as NpcObjectRule).ask.contains("只有一张"), "giving it to him is asked first, and says it does not come back")
	_check(capital.select_npc(tianxing.character_id), "陈天星 selected")
	var given: ItemHandlingResult = capital.give_to_selected(_carried(session, NOTE))
	_check(given != null and _said(given.lines, "过些日子") and state.marks.get("镖单给了陈天星", 0) == 1 and _carried(session, NOTE).is_empty(), "the 镖单 with 陈天星")
	session.record_journal()
	_check(state.quests.has("faction.celestial/escort/chen") and DeedLog.done(state, "把二十年前的镖单带去京师交给了陈天星"), "the choice and its deed are recorded")
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"trace", "next: what he finds")
	# The next time in: he has found it.
	MapPlaces.enter(session, HALL, HALL_POINT) # TEST-ONLY: away a while
	await _settle(tree)
	capital = MapPlaces.enter(session, &"city.biaoju", &"city.biaoju.street1_entry")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var said: Array = []
	for step: ScriptedAct.Step in catalog.npc(TIANXING).hooks().calls[0].act.steps:
		said.append("" if step.line == null else step.line.text)
	_check(state.marks.get("镖路查清了", 0) == 1, "the next time in, he has found it: 镖路查清了")
	_check(str(said).contains("兵部来人点名") and str(said).contains("满朝文武"), "what he says: the route 兵部 named, and he will say it at court while 第九章 is open: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.celestial/trace") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"next" and StoryQuestLog.is_active(state, catalog.story_quest(QUEST)), "trace done; the line waits on 天邪 B")
	ui.standing_page.fill(session.quest_condition_test())
	var standing: String = ui.standing_page.shown_text()
	_check(standing.contains("拿下了一个打听盟主的探子") and standing.contains("是兵部点名改走的老松岭"), "the 声望 page: %s" % standing)


## The wrong man held: the spy slips away at once; the line goes on.
func _test_wrong_man(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.chapter2_done(session)
	StoryFixtures.celestial_joined(session)
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_ask(hall, _first(session, HALL, PAN), "山门")
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var spy: NpcRuntimeState = _first(session, YARD, SPY)
	var boy: NpcRuntimeState = _first(session, YARD, HOPEFUL)
	var courier: NpcRuntimeState = _first(session, YARD, COURIER)
	_check(_said(_ask(yard, spy, "路引"), "看不出什么不对"), "without 印色 the spy's 路引 looks right: %s %s %s" % [spy, session.active_map().map_id() if session.active_map() != null else "", state.marks.keys()])
	var lines: Array[String] = _ask(yard, courier, "拿下")
	_check(_said(lines, "冤枉") and _said(lines, "赔了礼") and _said(lines, "不见了") and state.marks.get("探子跑了", 0) == 1, "the courier held, 潘军禅 apologises, the trader is gone: %s" % [lines])
	_check(_count_in(session, YARD, SPY) == 0 and _count_in(session, YARD, COURIER) == 1, "the spy left at once (also_leaves); the courier stays")
	_check(_said(_ask(yard, boy, "拿下"), "什么也没干") and not state.marks.has("认出了探子"), "a second 拿下 holds nobody")
	session.record_journal()
	_check(state.quests.has("faction.celestial/watch"), "the watch is over all the same")
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	_check(_said(_ask(hall, pan, "山门"), "人跑了") and state.marks.get("值守回了话", 0) == 1, "潘军禅: the man got away, 胆子不差")
	session.record_journal()
	_check(state.affiliation.family_title == "大弟子", "大弟子 all the same")
	_check(StoryFixtures.missing_after_play(session, StoryFixtures.celestial_watched.bind(false)).is_empty(), "守山 played (wrong man) leaves what celestial_watched(gone) writes")
	# 第二章 played: the 镖单 is in hand; to 潘军禅.
	_check(_said(_ask(hall, pan, "镖单"), "镖单只有一张") and state.marks.get("潘军禅说了镖单", 0) == 1, "潘军禅 puts the choice")
	var asked: Array = pan.definition().dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == NOTE and rule.accept)
	_check(asked.size() == 1 and asked[0].ask.contains("到此为止"), "the gift to him is asked first")
	_check(hall.select_npc(pan.character_id), "潘军禅 selected")
	var given: ItemHandlingResult = hall.give_to_selected(_carried(session, NOTE))
	_check(given != null and _said(given.lines, "锁进刑堂") and state.marks.get("镖单锁进了刑堂", 0) == 1, "the 镖单 locked in the 刑堂")
	session.record_journal()
	_check(state.quests.has("faction.celestial/escort/pan") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"next", "the choice recorded; trace skipped (only_after chen)")
	var bureau: WorldMapController = MapPlaces.enter(session, &"cloud.biaoju", &"cloud.biaoju.eroad2_entry")
	await _settle(tree)
	_check(_said(_ask(bureau, _first(session, &"cloud.biaoju", JIANQIU), "失镖"), "替我们留着"), "陈剑秋 breathes again")
	bureau.give_new_item_to_player(NOTE) # TEST-ONLY: a second 镖单
	var capital: WorldMapController = MapPlaces.enter(session, &"city.biaoju", &"city.biaoju.street1_entry")
	await _settle(tree)
	var tianxing: NpcRuntimeState = _first(session, &"city.biaoju", TIANXING)
	_check(capital.select_npc(tianxing.character_id), "陈天星 selected")
	capital.give_to_selected(_carried(session, NOTE))
	_check(not _carried(session, NOTE).is_empty() and not state.marks.has("镖单给了陈天星"), "the other way is closed: 陈天星 hands it back")
	var ui: SharedGameplayUI = session.shared_ui()
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("拿错了人") and ui.standing_page.shown_text().contains("锁在水烟阁的刑堂里"), "the 声望 page says so")


## After 庾子建 fell: the spy is 颜违's man, his 路引 the 阁's own ink, his letter in 颜违's 账房's hand.
func _test_yan_spy(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.celestial_watched(session)
	for mark: String in ["值守回了话", "认出了探子", "拿下了探子"]:
		state.marks.erase(mark)
	state.quests.erase("faction.celestial/watch")
	state.quests.erase("faction.celestial/report")
	state.marks["学过印色"] = 1 # TEST-ONLY
	state.marks["庾子建下狱"] = 1 # TEST-ONLY: 第九章 揭发
	session.record_journal()
	var yard: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	var spy: NpcRuntimeState = _first(session, YARD, SPY)
	_check(_said(_ask(yard, spy, "路引"), "山上的人开的"), "the 阁's own ink: 颜违's man")
	state.marks["拿下了探子"] = 1 # TEST-ONLY: taken
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	hall.give_new_item_to_player(LETTER) # TEST-ONLY
	var pan: NpcRuntimeState = _first(session, HALL, PAN)
	_check(hall.select_npc(pan.character_id), "潘军禅 selected")
	var read: ItemHandlingResult = hall.give_to_selected(_carried(session, LETTER))
	_check(read != null and _said(read.lines, "颜长老在数人头") and state.marks.get("值守回了话", 0) == 1, "the letter read: 颜违 counts heads")


## 镖路查清了 is one of the 揭发's proofs while 第九章 is open: with 陈显祖's word alone it is enough.
func _test_proof(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter9_compared(session, false, false, true, false)
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, &"imperial.front_hall", &"imperial.front_hall.emperor.1") # TEST-ONLY
	await _settle(tree)
	var ledger: StringName = _carried(session, &"native:niling/tribute_ledger")
	if not ledger.is_empty():
		hall.drop_item(ledger) # TEST-ONLY: one proof
	var expose: ActService = hall.service(&"imperial.front_hall.expose") as ActService
	_check(expose != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"imperial.front_hall.expose")) and expose.in_reach(), "at the boy's side")
	_check(state.marks.get("陈显祖作了证", 0) == 1 and not state.marks.has("卫沧澜作证"), "one proof: 陈显祖's word")
	var before: int = ui.log_lines().size()
	expose.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("两样")), "one is not enough")
	state.marks["镖路查清了"] = 1 # TEST-ONLY: 陈天星's finding
	before = ui.log_lines().size()
	expose.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("庾子建不会束手"), "with the route 兵部 named, two: the 揭发 is offered")
	ui.confirm_prompt.cancel_button.pressed.emit()
	await _settle(tree)


## Kneeling to another family ends the line; 潘军禅 no longer sends one who left.
func _test_lapse(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.celestial_joined(session)
	session.record_journal()
	StoryFixtures.fonxan_joined(session) # TEST-ONLY: 改投封山
	session.record_journal()
	_check(state.quests.has("faction.celestial#lapsed") and state.marks.get("天邪的线断了", 0) == 1, "the line lapsed: 天邪的线断了")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_said(_ask(hall, _first(session, HALL, PAN), "山门"), "不劳外人") and not state.marks.has("潘军禅说了山门"), "潘军禅 sends nobody")


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


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
