extends RefCounted

## 第九章 D 三选一 (owner's plan, 2026-11-06「按你的推荐来」Q3; DECISIONS「第九章 D」), from C's end
## (StoryFixtures.chapter9_compared: the way, audience and decree done, the decrees in hand), each choice
## ending on the hand-over to chapter9_done (the fixture 第九章 E and 第十章 start from):
## - expose (raid): the 揭发 refused on two proofs after the 关北 raid ("三样"), taken on three (the 密信 added):
##   asked first, dawn, into the 太和殿; the accusation scene with 槐阳王反了 and 拿下; 庾子建 draws, 冯策
##   beside the player; down, he goes to prison (庾子建下狱, 冯策随你下湖); the quest's expose, the chapter done
##   (皇城一章); the 东二门's notice torn; the other two shut (已经定了).
## - deal: 宋朴 in the lane (宋朴传了话); 庾子建 in his 客厅 takes the 原令 (asked first) into his brazier and
##   gives the late emperor's reading (私了了庾子建); the quest's deal, the chapter done.
## - uncle: the 手诏 asked first (皇叔的通缉解了), the notice 前诏作废; at the 水烟阁 於兰天武 takes it and goes
##   (皇叔入朝), gone from the guildhall, at the boy's side in the 养心殿; the quest's uncle and its road.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const ORIGINAL: StringName = &"native:imperial/original_decree"
const LETTER: StringName = &"native:city/courier_letter"
const READING: StringName = &"native:imperial/late_emperor_reading"
const EDICT: StringName = &"native:imperial/edict_for_uncle"
const CHAMPION: StringName = &"common.npc.fighter.champion"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for kind: String in ["expose", "deal", "uncle"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"expose": await _test_expose(tree, session)
			"deal": await _test_deal(tree, session)
			"uncle": await _test_uncle(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter9")
	var choice: StoryQuestDefinition.Step = quest.steps[3]
	_check(choice.step_id == &"choice" and choice.options.size() == 3 and quest.steps[4].step_id == &"uncle_road", "第九章: the three-way choice and the 手诏's road")
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	_check(expose != null and expose.act.acts.size() == 5 and expose.act.acts[2].when != null and expose.act.acts[2].when.when == JournalEntryDefinition.When.ANY, "朝上揭发: decided, no decree, enough (at_least), the raid's three, two")
	var state := CharacterState.new()
	var held: Dictionary[StringName, bool] = {}
	var three := JournalEntryDefinition.new()
	var errors: Array[String] = []
	JournalEntryDefinition.read_when(ContentRecordReader.new({"when": {"at_least": {"n": 2, "of": [{"mark": "a"}, {"mark": "b"}, {"item": "x"}]}}}, "test", errors), three, "when")
	_check(errors.is_empty() and not JournalLog.holds(three, state, {}, held), "at_least 2 of 3: none held")
	state.marks["a"] = 1
	_check(not JournalLog.holds(three, state, {}, held), "at_least 2 of 3: one")
	held[&"x"] = true
	_check(JournalLog.holds(three, state, {}, held), "at_least 2 of 3: two")
	var negated := JournalEntryDefinition.new()
	JournalEntryDefinition.read_when(ContentRecordReader.new({"when": {"not": {"mark": "a"}}}, "test", errors), negated, "when")
	_check(errors.is_empty() and not JournalLog.holds(negated, state, {}, held) and JournalLog.holds(negated, CharacterState.new(), {}, held), "not: the mark held, then not")


## C done (StoryFixtures.chapter9_compared): with `witness` 卫沧澜 heard and gone from the 尚书府.
func _ready_for_choice(session: WorldSessionController, raid: bool, witness: bool = false) -> void:
	StoryFixtures.chapter9_compared(session, witness, false, true, raid)
	session.record_journal()


## 章与章之间的衔接: what this package played out holds what the next suites' fixture (chapter9_done) writes.
func _handoff(session: WorldSessionController, side: String, raid: bool) -> void:
	var handoff: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.chapter9_done.bind(side, false, true, raid))
	_check(handoff.is_empty(), "第九章 D played (%s) leaves what chapter9_done(%s) writes: %s" % [side, side, handoff])


func _test_expose(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter9")
	_ready_for_choice(session, true, true)
	_check(StoryQuestLog.current_step(state, quest).step_id == &"choice", "expose: the choice is next")
	_check(state.marks.get("陈显祖作了证", 0) == 1 and state.marks.get("卫沧澜作证", 0) == 1, "expose: two witnesses on the ledger (陈显祖, 卫沧澜)")
	var hall: WorldMapController = MapPlaces.enter(session, &"imperial.front_hall", &"imperial.front_hall.emperor.1") # TEST-ONLY
	await _settle(tree)
	var expose: ActService = hall.service(&"imperial.front_hall.expose") as ActService
	_check(expose != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"imperial.front_hall.expose")) and expose.in_reach(), "expose: at the boy's side")
	_drop_ledger(session, hall)
	var before: int = ui.log_lines().size()
	expose.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("三样")), "expose: two proofs are not enough after the raid (三样)")
	_check(not hall.give_new_item_to_player(LETTER).is_empty(), "expose: the 密信 (TEST-ONLY: given, as the 小屋 drops it)")
	await _settle(tree)
	_strong(state)
	expose.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("庾子建不会束手"), "expose: asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	await _settle(tree)
	_check(state.marks.get("要在朝上揭发", 0) == 1 and session.day_phase_id() == &"dawn" and session.active_map().map_id() == &"imperial.taihe_hall", "expose: dawn, into the 太和殿 (%s %s)" % [session.day_phase_id(), session.active_map().map_id()])
	var throne: WorldMapController = session.active_map() as WorldMapController
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for second: int in 80:
		if coordinator.has_active_encounter():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		throne.hostilities.process_pending_aggression()
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("槐阳王反了")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("拿下")), "expose: 槐阳王反了, and 拿下")
	_check(state.marks.get("冯策随你下湖", 0) == 1 and coordinator.has_active_encounter(), "expose: 庾子建 draws; 冯策 will go down to the lake")
	coordinator.set_manual_turns(false) # TEST-ONLY
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 3000:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	ui.dismiss_current_panel()
	await _settle(tree)
	session.record_journal()
	_check(state.marks.get("庾子建下狱", 0) == 1 and StoryQuestLog.took(state, quest, &"expose") and StoryQuestLog.is_done(state, quest) and state.marks.get("皇城一章", 0) == 1, "expose: 庾子建下狱, the chapter done")
	var notice: WorldLandmarkDefinition = GameContent.catalog().landmark(&"city.eastdoor2.landmark.notice")
	_check(notice.description_for(state.marks).contains("辑拿要犯——」"), "expose: the 东二门's warrant torn")
	var back: WorldMapController = MapPlaces.enter(session, &"imperial.front_hall", &"imperial.front_hall.emperor.1") # TEST-ONLY
	await _settle(tree)
	var uncle: ActService = back.service(&"imperial.front_hall.uncle") as ActService
	_check(await MapPlaces.drive(tree, back, MapPlaces.service_spot(back, &"imperial.front_hall.uncle")), "expose: back to the boy")
	before = ui.log_lines().size()
	uncle.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("已经定了")), "expose: the others shut (已经定了)")
	_handoff(session, "expose", true)


func _test_deal(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter9")
	_ready_for_choice(session, false)
	var lanes: WorldMapController = MapPlaces.enter(session, &"imperial.lanes_south", &"imperial.lanes_south.song_pu.1") # TEST-ONLY: beside 宋朴
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("宋朴传了话", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("过府一叙")), "deal: 宋朴: 尚书大人请你过府一叙")
	var house: WorldMapController = MapPlaces.enter(session, &"city.shangshu.keting", &"city.shangshu.keting.shangshu.1") # TEST-ONLY: in the 客厅
	await _settle(tree)
	var original: StringName = hall_item(house, ORIGINAL)
	_check(not original.is_empty(), "deal: the 原令 in hand (out of the chest in C)")
	var yu: NpcRuntimeState = _first(session, &"city.shangshu.keting", &"city.npc.shangshu.shangshu")
	_check(yu != null and house.select_npc(yu.character_id), "deal: 庾子建 in his 客厅")
	if yu == null:
		return
	var given: ItemHandlingResult = house.give_to_selected(original)
	await _settle(tree)
	if ui.is_asking():
		_check(ui.confirm_prompt.message.text.contains("寻风"), "deal: asked first")
		ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
	else:
		_check(given.done(), "deal: given (%s %s)" % [given.outcome, given.lines])
	session.record_journal()
	_check(state.marks.get("私了了庾子建", 0) == 1 and session.player_held_item_ids().get(READING, false) and not session.player_held_item_ids().get(ORIGINAL, false), "deal: the 原令 into the brazier, the reading in hand")
	_check(StoryQuestLog.took(state, quest, &"deal") and StoryQuestLog.is_done(state, quest), "deal: the quest's deal, the chapter done")
	_handoff(session, "deal", false)


func _test_uncle(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter9")
	_ready_for_choice(session, false)
	var hall: WorldMapController = MapPlaces.enter(session, &"imperial.front_hall", &"imperial.front_hall.emperor.1") # TEST-ONLY
	await _settle(tree)
	var uncle: ActService = hall.service(&"imperial.front_hall.uncle") as ActService
	_check(uncle != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"imperial.front_hall.uncle")) and uncle.in_reach(), "uncle: at the boy's side")
	uncle.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("手诏"), "uncle: asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	_check(state.marks.get("皇叔的通缉解了", 0) == 1 and session.player_held_item_ids().get(EDICT, false) and StoryQuestLog.took(state, quest, &"uncle") and StoryQuestLog.current_step(state, quest).step_id == &"uncle_road", "uncle: the 手诏 in hand, its road next")
	_check(GameContent.catalog().landmark(&"city.eastdoor2.landmark.notice").description_for(state.marks).contains("前诏作废"), "uncle: the 东二门's notice: 前诏作废")
	var guildhall: WorldMapController = MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.champion.1") # TEST-ONLY: at the 水烟阁
	await _settle(tree)
	var champion: NpcRuntimeState = _first(session, &"waterfog.guildhall", CHAMPION)
	_check(champion != null and guildhall.select_npc(champion.character_id), "uncle: 於兰天武 in the guildhall")
	if champion == null:
		return
	_check(guildhall.give_to_selected(hall_item(guildhall, EDICT)).done() and state.marks.get("皇叔入朝", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("老夫回京")), "uncle: he reads it and goes home (皇叔入朝)")
	session.record_journal()
	_check(StoryQuestLog.is_done(state, quest), "uncle: the chapter done")
	var back: WorldMapController = MapPlaces.enter(session, &"imperial.front_hall", &"imperial.front_hall.emperor.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"imperial.front_hall", CHAMPION) != null, "uncle: at the boy's side in the 养心殿")
	_handoff(session, "uncle", false)


func _drop_ledger(session: WorldSessionController, map: WorldMapController) -> void:
	var ledger: StringName = hall_item(map, &"native:niling/tribute_ledger")
	if not ledger.is_empty():
		map.drop_item(ledger) # TEST-ONLY: two proofs, not three


func hall_item(map: WorldMapController, definition_id: StringName) -> StringName:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, map.session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _strong(state: CharacterState) -> void:
	state.progression.combat_experience = 3000000 # TEST-ONLY: the fight is won
	for skill: StringName in [&"unarmed", &"dodge", &"parry", &"force"]:
		state.skills.set_raw_level(skill, 260) # TEST-ONLY


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", CharacterState.GENDER_MALE)
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
