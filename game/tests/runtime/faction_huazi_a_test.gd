extends RefCounted

## 势力线第二批 花紫会 A (计划 势力线第二批_计划.md §5 花紫会 A; DECISIONS「花紫会 A」「带着才问」): the line shows for
## one who beat the 县衙's drum and for 花紫会's own; 陆得财's 差事 (and 偷窃 taught to the one he sent); the 兵部 clerk
## in the 福林酒楼 stolen from — taken, or caught (thief + 1, the fight; beaten he throws the 卖身契 down and runs);
## the 契 to 陆得财 (五结弟子 for 花紫会's own), who is a stand-in; the knots one more each (雪亭 20, 绮云 21) to the
## 真龙头 with 23 below the 尚书府's back wall; the 密信 to him (the 揭发 cannot count it) or to 程不平 (the 揭发
## counts it; the line ends).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.huazi"
const MASTER: StringName = &"common.npc.beggar.master"
const JUDGE: StringName = &"choyin.npc.judgeman"
const STEWARD: StringName = &"native.npc.levy_steward"
const SNOW: StringName = &"native.npc.lu_decai_snow"
const CLOUD: StringName = &"native.npc.lu_decai_cloud"
const HEAD: StringName = &"native.npc.lu_decai_true"
const DEEDS: StringName = &"native:choyin/indentures"
const LETTER: StringName = &"native:city/courier_letter"
const STREET: StringName = &"choyin.n_street1"
const GATE: StringName = &"choyin.n_gate"
const GATE_POINT: StringName = &"choyin.n_gate.road_arrival"
const HOTEL: StringName = &"choyin.hotel2"
const HOTEL_POINT: StringName = &"choyin.hotel2.stairs_arrival"
const SQUARE: StringName = &"snow.square"
const SQUARE_POINT: StringName = &"snow.square.inn_entry"
const DUKOU: StringName = &"cloud.dukou"
const DUKOU_POINT: StringName = &"cloud.dukou.river_return"
const WALL: StringName = &"city.street3"
const WALL_POINT: StringName = &"city.street3.wall_return"
const HALL: StringName = &"choyin.yamen"
const HALL_POINT: StringName = &"choyin.yamen.hall_entry"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for test: Callable in [_test_stranger, _test_to_huazi, _test_caught, _test_to_court]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.starts.when == JournalEntryDefinition.When.ANY, "faction.huazi: a 势力 line that begins with the drum or 拜师")
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"errand", &"steal", &"deeds", &"snow", &"cloud", &"head", &"letter", &"rescue"], "its steps: %s" % [ids])
	var letter: StoryQuestDefinition.Step = quest.step(&"letter")
	_check(letter.is_branch() and letter.weight == StoryQuestDefinition.WEIGHT_SMALL and letter.options.size() == 2 and letter.options.all(func(option: StoryQuestDefinition.Option) -> bool: return not option.reward.deed.is_empty()), "the 密信 is a small choice of two, each a deed")
	_check(letter.objective.contains("官府那条线就断了") and letter.objective.contains("花紫会这条线就断了") and letter.objective.contains("不能拿去朝上揭发"), "what either way costs is said before the choice")
	_check(quest.step(&"deeds").reward.rank_title == "五结弟子" and quest.step(&"deeds").reward.rank_family == &"family.huazi" and not quest.step(&"deeds").reward.deed.is_empty(), "the 契 handed over: 五结弟子 for 花紫会's own, a deed")
	_check(quest.step(&"steal").objective.contains("随手摸一样") and quest.step(&"steal").objective.contains("巡捕"), "the steal says how, and what failing costs")
	for id: StringName in [DEEDS, LETTER]:
		_check(catalog.item(id) != null and catalog.item(id).quest_item, "%s is a quest item" % id)
	var steward: NpcDefinition = catalog.npc(STEWARD)
	_check(steward.resource_overrides().spirit().maximum() == 40, "the clerk is half drunk: his 神 is low, a raw hand has a chance")
	_check(steward.hooks().always_kept and steward.hooks().spared_drop == DEEDS and steward.hooks().spared_leave and steward.hooks().spared_mark == "管事挨了打", "the clerk: only knocked down; then he throws the 契 down and runs")
	for pair: Array in [[SNOW, "二十个"], [CLOUD, "二十一个"], [HEAD, "二十三个"]]:
		var npc: NpcDefinition = catalog.npc(pair[0])
		_check(npc != null and npc.display_name == "陆得财" and npc.description.contains(pair[1]) and npc.dealings().is_fight_deferred(), "%s: 陆得财, %s knots, not to be fought" % pair)
	for spawn_id: StringName in [&"native.hotel2.levy_steward", &"native.square.lu_decai", &"native.dukou.lu_decai", &"native.street3.lu_decai"]:
		_check(catalog.spawn(spawn_id) != null, "%s exists" % spawn_id)
	var head: NpcDefinition = catalog.npc(HEAD)
	_check(head.talk().ask_confirm("密信").contains("这封信再也要不回来") and head.talk().ask_confirm("密信").contains("官府那条线就断了") and catalog.npc(JUDGE).talk().ask_confirm("密信").contains("花紫会那条线就断了"), "both ways are asked first, and say which line ends")
	var marks: Dictionary = {"见了真龙头": 1}
	_check(head.talk().confirm_applies("密信", marks, &"", ["密信"]) and not head.talk().confirm_applies("密信", marks, &"", []), "asked first only of one who carries the letter (confirm_carries)")
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	var state := CharacterState.new()
	state.marks["对出了原令"] = 1
	state.marks["陈显祖作了证"] = 1
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	_check(not JournalLog.holds(expose.act.acts[2].when, state, temps, held), "揭发: one proof is not enough")
	state.marks["密信给了花紫会"] = 1
	_check(not JournalLog.holds(expose.act.acts[2].when, state, temps, held), "揭发: the 密信 given to 花紫会 does not count")
	state.marks["密信给了官府"] = 1
	_check(JournalLog.holds(expose.act.acts[2].when, state, temps, held), "揭发: the 密信 in 程不平's hands counts")
	held[LETTER] = true
	state.marks.erase("密信给了官府")
	_check(JournalLog.holds(expose.act.acts[2].when, state, temps, held), "揭发: the 密信 carried counts as before")


## Neither the drum nor 花紫会: no line, no 差事, no clerk.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	session.record_journal()
	_check(not state.quests.has("faction.huazi#started"), "no drum, no family: the line has not begun")
	var street: WorldMapController = await _to_lu(tree, session)
	await _settle(tree)
	_check(_said(_ask(street, _first(session, STREET, MASTER), "差事"), "鼓都没敲过") and not state.marks.has("陆得财说了差事"), "差事 asked by a stranger: not for him")
	_check(GameContent.catalog().npc(MASTER).teaching().recognize(&"", state.marks, &"stealing") == null, "no 偷窃 for a stranger")
	MapPlaces.enter(session, HOTEL, HOTEL_POINT)
	await _settle(tree)
	_check(_count_in(session, HOTEL, STEWARD) == 0, "no clerk upstairs")


## The drum beaten: the 差事, 偷窃 taught; the 契 taken; to 陆得财 (no rank for one not of 花紫会), a stand-in; the
## knots in order (asked out of order, nothing); the 真龙头; the 密信 before 第九章 (the 小屋 empty), then carried and
## handed to him: 花紫会's; 程不平 hears it went to the 叫花子.
func _test_to_huazi(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	state.marks["击了鼓"] = 1 # TEST-ONLY: 第五章
	session.record_journal()
	_check(state.quests.has("faction.huazi#started") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"errand", "the drum beaten: the line begins")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("花紫会"), "the 势力 column has the line")
	var street: WorldMapController = await _to_lu(tree, session)
	await _settle(tree)
	var lu: NpcRuntimeState = _first(session, STREET, MASTER)
	_check(_said(_ask(street, lu, "差事"), "卖身契") and state.marks.get("陆得财说了差事", 0) == 1, "差事: the 兵部 clerk's 卖身契")
	_check(catalog.npc(MASTER).teaching().recognize(&"", state.marks, &"stealing") != null and catalog.npc(MASTER).teaching().recognize(&"", state.marks, &"spicyclaw") == null, "陆得财 teaches the one he sent 偷窃, and only that")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"steal", "the steal next")
	var hotel: WorldMapController = MapPlaces.enter(session, HOTEL, HOTEL_POINT)
	await _settle(tree)
	var steward: NpcRuntimeState = _first(session, HOTEL, STEWARD)
	_check(steward != null, "the clerk upstairs: %s" % [_where(session, STEWARD)])
	if steward == null:
		return
	await _beside(tree, hotel, steward)
	_check(hotel.select_npc(steward.character_id) and hotel.thefts.can_steal_selected() and hotel.thefts.seen_items(steward).is_empty(), "偷窃 on him: nothing seen on him")
	# 随手摸一样: the pick (one thing: the 契), then random(sp + dp) > dp; then improve_skill's random(int) and the onlookers' random(sp).
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 100000, 0, 0])) # TEST-ONLY
	_check(hotel.thefts.begin(steward, &""), "the hand waits")
	hotel.npc_life._advance_ambience(3.1)
	session.configure_world_interaction_random_source(original)
	_check(session.player_held_item_ids().get(DEEDS, false) == true and ui.log_lines().has("得手了！"), "得手了！ the 卖身契 is the player's: %s" % [ui.log_lines().slice(-3)])
	session.record_journal()
	_check(state.quests.has("faction.huazi/steal") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"deeds", "stolen; to 陆得财 next")
	await _to_lu(tree, session)
	await _settle(tree)
	MapPlaces.enter(session, HOTEL, HOTEL_POINT)
	await _settle(tree)
	_check(_count_in(session, HOTEL, STEWARD) == 0, "back upstairs: the clerk has gone")
	street = await _to_lu(tree, session)
	await _settle(tree)
	lu = _first(session, STREET, MASTER)
	_check(_said(_ask(street, lu, "差事"), "递给我"), "差事 with the 契: hand it over")
	_check(street.select_npc(lu.character_id), "陆得财 selected")
	var given: ItemHandlingResult = street.give_to_selected(_carried(session, DEEDS))
	_check(given != null and _said(given.lines, "二十二个") and state.marks.get("卖身契还了", 0) == 1 and state.marks.get("陆得财说了替身", 0) == 1 and session.player_held_item_ids().get(DEEDS, false) == false, "the 契 taken: he is a stand-in, twenty-two knots")
	session.record_journal()
	_check(state.quests.has("faction.huazi/deeds") and DeedLog.done(state, "从兵部的管事身上摸回了槐阳八户的卖身契") and state.affiliation.family_title != "五结弟子", "deeds done, a deed; no 五结弟子 for one not of 花紫会")
	street.give_new_item_to_player(DEEDS) # TEST-ONLY: a second 叠 (stolen, then he was beaten too)
	var again: ItemHandlingResult = street.give_to_selected(_carried(session, DEEDS))
	_check(again != null and _said(again.lines, "收过了") and not _said(again.lines, "二十二个"), "a second 叠: taken and burnt, the stand-in's story not told again")
	var missing: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.huazi_returned)
	_check(missing.is_empty(), "played leaves what huazi_returned writes: %s" % [missing])
	# The knots: 京师 first is nothing; then 雪亭, 绮云, 京师.
	var city: WorldMapController = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	_check(_said(_ask(city, _first(session, WALL, HEAD), "龙头"), "晒太阳") and not state.marks.has("见了真龙头"), "the 真龙头 asked out of turn: a beggar in the sun")
	var square: WorldMapController = MapPlaces.enter(session, SQUARE, SQUARE_POINT)
	await _settle(tree)
	_check(_said(_ask(square, _first(session, SQUARE, SNOW), "龙头"), "二十个") and state.marks.get("雪亭的替身指了路", 0) == 1, "雪亭: twenty, the 渡口 next")
	var dukou: WorldMapController = MapPlaces.enter(session, DUKOU, DUKOU_POINT)
	await _settle(tree)
	_check(_said(_ask(dukou, _first(session, DUKOU, CLOUD), "龙头"), "二十一个") and state.marks.get("绮云的替身指了路", 0) == 1, "绮云: twenty-one, the 尚书府's back wall next")
	city = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	var head: NpcRuntimeState = _first(session, WALL, HEAD)
	_check(_said(_ask(city, head, "龙头"), "二十三个") and state.marks.get("见了真龙头", 0) == 1, "the 真龙头: twenty-three")
	_check(city.select_npc(head.character_id) and city.ask_topics_selected().has("密信"), "密信 on his list")
	_check(_said(_ask(city, head, "密信"), "还空着") and state.marks.get("真龙头要密信", 0) == 1, "before 第九章: the 小屋 is still empty")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"letter", "the letter next")
	missing = StoryFixtures.missing_after_play(session, StoryFixtures.huazi_found)
	_check(missing.is_empty(), "played leaves what huazi_found writes: %s" % [missing])
	state.marks["湖底一章"] = 1 # TEST-ONLY: 第九章
	_check(_said(_ask(city, head, "密信"), "见人就动手"), "第九章: the 小屋's courier has the letter")
	_check(not city.give_new_item_to_player(LETTER).is_empty(), "TEST-ONLY: the 密信, as the 小屋 drops it")
	state.marks["小屋的信使倒了"] = 1 # TEST-ONLY
	_check(head.definition().talk().confirm_applies("密信", state.marks, &"", city.acts.facts().carried), "with the letter, asked first")
	_check(_said(_ask(city, head, "密信"), "不敢清乔阴的巷子") and state.marks.get("密信给了花紫会", 0) == 1 and session.player_held_item_ids().get(LETTER, false) == false, "given to 花紫会: the letter is his")
	session.record_journal()
	_check(StoryQuestLog.took(state, catalog.story_quest(QUEST), &"huazi") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"rescue" and not state.quests.has("faction.huazi#lapsed"), "the choice and its deed; the stub next (花紫会 B)")
	missing = StoryFixtures.missing_after_play(session, StoryFixtures.huazi_letter)
	_check(missing.is_empty(), "played leaves what huazi_letter writes: %s" % [missing])
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("二十三个结") and ui.standing_page.shown_text().contains("交给了真龙头"), "the 声望 page: %s" % ui.standing_page.shown_text())
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_said(_ask(hall, _first(session, HALL, JUDGE), "密信"), "给了叫花子") and not state.marks.has("密信给了官府"), "程不平: the letter went to the 叫花子")


## Caught at it: thief + 1 and the fight; beaten, he lies there and a hand on him cannot fail (ES2). Attacked and
## spared (he is only knocked down) he throws the 契 down and runs.
func _test_caught(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.marks["击了鼓"] = 1 # TEST-ONLY
	state.marks["陆得财说了差事"] = 1 # TEST-ONLY
	session.record_journal()
	var hotel: WorldMapController = MapPlaces.enter(session, HOTEL, HOTEL_POINT)
	await _settle(tree)
	var steward: NpcRuntimeState = _first(session, HOTEL, STEWARD)
	if steward == null:
		_check(false, "the clerk upstairs")
		return
	await _beside(tree, hotel, steward)
	var thief: int = CrimeRecord.thief(state)
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 0, 0])) # TEST-ONLY: both rolls low
	hotel.thefts.begin(steward, &"")
	hotel.npc_life._advance_ambience(3.1)
	session.configure_world_interaction_random_source(original)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter() and CrimeRecord.thief(state) == thief + 1 and session.player_held_item_ids().get(DEEDS, false) == false, "caught: a fight, thief + 1, no 契")
	_check(StoryKeeps.keeps(state, GameContent.catalog().npc(STEWARD), GameContent.catalog().story_quests()), "the clerk can only be knocked down")
	coordinator.stop_where_it_stands() # TEST-ONLY: the fight over
	steward.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: beaten
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0])) # TEST-ONLY: the pick; no roll on one out cold
	_check(hotel.thefts.begin(steward, &""), "a hand on him as he lies there")
	hotel.npc_life._advance_ambience(3.1)
	session.configure_world_interaction_random_source(original)
	_check(session.player_held_item_ids().get(DEEDS, false) == true, "out cold: the 契 taken")
	hotel.acts.take_from_player(DEEDS) # TEST-ONLY: as if never taken, for the other way
	session.npc_spared(steward) # TEST-ONLY: attacked and spared (kept: 放过 is all there is)
	hotel.npcs.leave_for_good(steward)
	_check(state.marks.get("管事挨了打", 0) == 1 and not hotel.floor_item_of(DEEDS, HOTEL).is_empty(), "spared: he ran, the 契 on the floor")
	await _to_lu(tree, session)
	await _settle(tree)
	MapPlaces.enter(session, HOTEL, HOTEL_POINT)
	await _settle(tree)
	_check(_count_in(session, HOTEL, STEWARD) == 0, "he does not come back")
	state.marks["密信给了官府"] = 1 # TEST-ONLY: the letter given to 程不平 before the 真龙头 was found
	session.record_journal()
	_check(state.quests.has("faction.huazi#lapsed") and not state.quests.has("faction.huazi/letter/court"), "the letter to 程不平 before the 真龙头: the line ends there, no choice taken")


## 花紫会's own without the drum: the line from 拜师, 五结弟子; the 密信 to 程不平: the 揭发 counts it, the line ends.
func _test_to_court(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.huazi_joined(session)
	session.record_journal()
	_check(state.quests.has("faction.huazi#started") and not state.marks.has("击了鼓"), "拜师: the line begins without the drum")
	var street: WorldMapController = await _to_lu(tree, session)
	await _settle(tree)
	_check(_said(_ask(street, _first(session, STREET, MASTER), "差事"), "卖身契") and state.marks.get("陆得财说了差事", 0) == 1, "差事 to his own")
	street.give_new_item_to_player(DEEDS) # TEST-ONLY: stolen
	session.record_journal()
	var lu: NpcRuntimeState = _first(session, STREET, MASTER)
	_check(street.select_npc(lu.character_id) and street.give_to_selected(_carried(session, DEEDS)) != null, "the 契 handed over")
	session.record_journal()
	_check(state.affiliation.family_title == "五结弟子", "花紫会's own: 五结弟子 (%s)" % state.affiliation.family_title)
	StoryFixtures.huazi_found(session)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"letter", "the letter next")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var judge: NpcRuntimeState = _first(session, HALL, JUDGE)
	_check(hall.select_npc(judge.character_id) and not hall.ask_topics_selected().has("密信"), "程不平: no 密信 before the 小屋")
	state.marks["小屋的信使倒了"] = 1 # TEST-ONLY
	hall.give_new_item_to_player(LETTER) # TEST-ONLY
	_check(hall.select_npc(judge.character_id) and hall.ask_topics_selected().has("密信") and judge.definition().talk().confirm_applies("密信", state.marks, state.family.family_id, hall.acts.facts().carried), "密信 listed and asked first")
	_check(_said(_ask(hall, judge, "密信"), "庾子建的字") and state.marks.get("密信给了官府", 0) == 1 and session.player_held_item_ids().get(LETTER, false) == false, "given to 程不平")
	session.record_journal()
	_check(StoryQuestLog.took(state, catalog.story_quest(QUEST), &"court") and DeedLog.done(state, "把尚书府小屋里的密信交给了乔阴知县程不平") and state.quests.has("faction.huazi#lapsed") and state.marks.get("花紫会的线断了", 0) == 1, "the choice taken (its deed too); the 花紫会 line ends: %s" % [state.quests.keys().filter(func(k: String) -> bool: return k.begins_with("faction.huazi"))])
	street = await _to_lu(tree, session)
	await _settle(tree)
	_check(_said(_ask(street, _first(session, STREET, MASTER), "差事"), "没有正事说"), "陆得财: no business with the 官府's")
	var city: WorldMapController = MapPlaces.enter(session, WALL, WALL_POINT)
	await _settle(tree)
	_check(_count_in(session, WALL, HEAD) == 0, "the 真龙头 is not below the wall for one whose line ended")


## TEST-ONLY: 乔阴's 北门 then up 福林大街 to 陆得财's side (his marker is on the street's north edge).
func _to_lu(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, GATE, GATE_POINT)
	await _settle(tree)
	if map == null:
		return null
	await MapPlaces.drive_to_zone(tree, map, STREET)
	await _settle(tree)
	return map


func _beside(tree: SceneTree, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var body: WorldCharacterBody2D = map.npcs.runtime_body_for_character(npc.character_id)
	if body != null:
		await MapPlaces.drive(tree, map, body.global_position + Vector2(24, 0))
	await _settle(tree)


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


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("花紫会", CharacterState.GENDER_MALE)
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
