extends RefCounted

## 第九章 原令, 第九章 A (owner's plan, 2026-11-06「按你的推荐来」; DECISIONS「第九章 A」), from the
## eighth chapter's ledger (StoryFixtures.chapter8_done), two sessions:
## - exam (kept, escorted × kept): the chapter open with the 午门 its target; the 铁门 shut to one
##   without leave (守门禁军), 午门 · 候旨 with nothing to wait for; the 南门 notice's new slip; at
##   the 校武场 the first 校尉 will not spar before 葛升 writes the name (报了武举), then the three
##   bouts in order, each won writing its mark (spar_won_mark) and the next refusing till then;
##   葛升's 午门候旨; 候旨 asked first, the clock to dawn (宫门放行, 候了殿试); through the 铁门 (进了皇城)
##   over the bridges and the square into the 太和殿, where the 殿试 plays: the 腰牌 given,
##   福安's word (殿试过, 见了福安); the quest's way taken by the exam, the 养心殿 next.
## - memorial (pulled, escorted × raid): 骆云舟's 京城 gives the 名帖 (程不平写了信); 相国府's gate
##   shut to the knock without it, open with it; 韦执中 takes the card (相国见了名帖) and writes the
##   奏本 on the 程不平 letter (相国写了奏本); 候旨 to dawn (随相国上朝); the 早朝 in the 太和殿 with
##   庾子建's 槐阳王反了 (the raid ledger) and 福安's word (早朝过); the way taken by the memorial.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"main.chapter9"
const TOKEN: StringName = &"native:imperial/guard_token"
const CARD: StringName = &"native:choyin/luo_card"
const GE: StringName = &"native.npc.ge_sheng"
const LT1: StringName = &"native.npc.exam_lieutenant_1"
const LT2: StringName = &"native.npc.exam_lieutenant_2"
const DENG: StringName = &"native.npc.deng_xiao"
const WEI: StringName = &"native.npc.wei_zhizhong"
const LUO: StringName = &"common.npc.scholar.master"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var exam: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_exam(tree, exam)
	exam.free()
	await tree.process_frame
	var memorial: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_memorial(tree, memorial)
	memorial.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.steps.size() >= 2 and quest.steps[0].step_id == &"way" and quest.steps[0].options.size() == 3 and quest.steps[1].step_id == &"audience", "第九章: the way in (exam, memorial, sneak) and the 养心殿")
	for id: StringName in [LT1, LT2, DENG]:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and npc.hooks() != null and not npc.hooks().spar_won_mark.is_empty() and npc.fight_rules().size() == 3 and npc.fight_rules()[0].marks.size() == 1 and not npc.fight_rules()[0].not_mark.is_empty(), "%s: a bout of the 武考, in its turn, its mark won" % id)
	var gate: ZoneExitRuleDefinition = null
	for rule: ZoneExitRuleDefinition in catalog.exit_rules():
		if rule.rule_id == &"city.wumen.iron_gate":
			gate = rule
	_check(gate != null and gate.mark == "宫门放行", "the 铁门: 宫门放行 or nothing")
	var wait: ServiceDefinition = catalog.service(&"city.wumen.wait")
	_check(wait != null and wait.act.verb == "候旨" and wait.act.acts.size() == 4, "午门 · 候旨: open, the 殿试, the 早朝, nothing")
	var emperor: NpcDefinition = catalog.npc(&"native.npc.yulan_zhao")
	_check(emperor != null and emperor.hooks().scene_mark == "殿试过" and emperor.dealings().is_fight_deferred() and emperor.age == 16 if emperor != null else false, "於兰昭: sixteen, the 殿试's scene, not to be fought")


func _test_exam(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	StoryFixtures.chapter8_done(session, false)
	session.record_journal()
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.current_step(state, quest).step_id == &"way" and StoryQuestLog.target(state, catalog.story_quests()).zone_id == &"city.wumen", "exam: the chapter open, the 午门 its target")
	var city: WorldMapController = MapPlaces.enter(session, &"city.wumen", &"city.wumen.palace_return") # TEST-ONLY: before the 午门
	await _settle(tree)
	_check(_count_in(session, &"city.wumen", &"native.npc.wumen_guard") == 2, "exam: two 禁军 before the 铁门")
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.take_passage(tree, city, &"city.wumen.north", 240) and session.active_map() == city, "exam: the 铁门 does not let one through")
	_check(ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("宫门重地")), "exam: 宫门重地，闲人止步")
	var wait: ActService = city.service(&"city.wumen.wait") as ActService
	_check(wait != null and await MapPlaces.drive(tree, city, MapPlaces.service_spot(city, &"city.wumen.wait")) and wait.in_reach(), "exam: at the 午门")
	before = ui.log_lines().size()
	wait.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("铁门关着")), "exam: 候旨 with nothing to wait for")
	var notice: WorldLandmarkDefinition = catalog.landmark(&"city.southdoor.landmark.notice")
	_check(notice != null and notice.description_for(state.marks).contains("校武场报名"), "exam: the 南门's notice has the 武举's slip")
	# The 校武场.
	_check(await MapPlaces.drive_to_zone(tree, city, &"city.jiaowu"), "exam: south to the 校武场")
	await _settle(tree)
	for id: StringName in [GE, LT1, LT2, DENG, &"native.npc.feng_ce"]:
		_check(_count_in(session, &"city.jiaowu", id) == 1, "exam: %s on the 校武场" % id)
	var lt1: NpcRuntimeState = _first(session, &"city.jiaowu", LT1)
	var lt2: NpcRuntimeState = _first(session, &"city.jiaowu", LT2)
	var deng: NpcRuntimeState = _first(session, &"city.jiaowu", DENG)
	if lt1 == null or lt2 == null or deng == null:
		return
	_check(not city.spar_consent(lt1).accepted, "exam: 赵勇 sends one not on the list to 葛升")
	var ge: NpcRuntimeState = _first(session, &"city.jiaowu", GE)
	_check(ge != null and city.select_npc(ge.character_id) and city.ask_selected("武举").any(func(line: String) -> bool: return line.contains("三场")) and state.marks.get("报了武举", 0) == 1, "exam: 葛升 writes the name (报了武举)")
	_check(city.spar_consent(lt1).accepted and not city.spar_consent(lt2).accepted and not city.spar_consent(deng).accepted, "exam: the first bout open, the others not yet")
	_strong(state)
	for bout: Array in [[lt1, "胜了第一场", lt2], [lt2, "胜了第二场", deng], [deng, "中了武状元", null]]:
		var npc: NpcRuntimeState = bout[0]
		_heal(state)
		_check(await MapPlaces.drive(tree, city, MapPlaces.spot(city, &"city.jiaowu", city.runtime_body_for_character(npc.character_id).global_position, 56.0)), "exam: up to %s" % npc.definition().display_name)
		city.select_npc(npc.character_id)
		_check(city.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "exam: 切磋 with %s" % npc.definition().display_name)
		_run(session)
		await _settle(tree)
		_check(state.marks.get(bout[1], 0) == 1, "exam: %s won (%s)" % [npc.definition().display_name, bout[1]])
		_check(not city.spar_consent(npc).accepted, "exam: %s will not spar again" % npc.definition().display_name)
		if bout[2] != null:
			_check(city.spar_consent(bout[2]).accepted, "exam: the next bout open")
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("葛升说了殿试", 0) == 1, "exam: 葛升's 午门候旨")
	# The 殿试.
	_check(await MapPlaces.drive_to_zone(tree, city, &"city.wumen") and await MapPlaces.drive(tree, city, MapPlaces.service_spot(city, &"city.wumen.wait")), "exam: back to the 午门")
	wait.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("殿试"), "exam: 候到天亮 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.day_phase_id() == &"dawn" and state.marks.get("宫门放行", 0) == 1 and state.marks.get("候了殿试", 0) == 1, "exam: dawn, the 铁门 open (%s)" % session.day_phase_id())
	_check(await MapPlaces.take_passage(tree, city, &"city.wumen.north") and session.active_map().map_id() == &"imperial.meridian" and state.marks.get("进了皇城", 0) == 1, "exam: through the 铁门 (进了皇城)")
	await _settle(tree)
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"imperial.throne_hall")
	_check(hall != null and hall.map_id() == &"imperial.taihe_hall", "exam: over the bridges and the square into the 太和殿")
	if hall == null:
		return
	_check(_count_in(session, &"imperial.throne_hall", &"native.npc.yulan_zhao") == 1 and _count_in(session, &"imperial.throne_hall", &"native.npc.yu_zijian_court") == 1 and _count_in(session, &"imperial.throne_hall", &"native.npc.court_official") == 4, "exam: the boy on the throne, 庾子建, the officials")
	for second: int in 60:
		if state.marks.get("见了福安", 0) == 1 and not hall.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not hall.scene_running() and state.marks.get("殿试过", 0) == 1 and state.marks.get("见了福安", 0) == 1 and session.player_held_item_ids().get(TOKEN, false), "exam: the 殿试 played, the 腰牌 given, 福安's word")
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("今夜养心殿")), "exam: 今夜养心殿")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"exam") and StoryQuestLog.current_step(state, quest).step_id == &"audience", "exam: the way taken by the 武举, the 养心殿 next")


func _test_memorial(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	StoryFixtures.chapter8_done(session, true, true, true)
	session.record_journal()
	_check(state.marks.get("程不平写了信", 0) == 1 and state.marks.get("踏平了工地", 0) == 1, "memorial: the letter written, the 工地 raided (the ledger)")
	# 骆云舟's card.
	var luo_zone: StringName = _zone_of_spawned(LUO)
	_check(not luo_zone.is_empty(), "memorial: 骆云舟 somewhere in 乔阴")
	if luo_zone.is_empty():
		return
	var town: WorldMapController = MapPlaces.enter(session, luo_zone, _point_of(LUO)) # TEST-ONLY: beside 骆云舟
	await _settle(tree)
	var luo: NpcRuntimeState = _first(session, luo_zone, LUO)
	_check(luo != null and town.select_npc(luo.character_id) and town.ask_selected("京城").any(func(line: String) -> bool: return line.contains("相国府")) and session.player_held_item_ids().get(CARD, false) and state.marks.get("骆云舟给了名帖", 0) == 1, "memorial: 骆云舟's 京城 gives the 名帖")
	# 相国府.
	var city: WorldMapController = MapPlaces.enter(session, &"city.xiangguo_gate", &"city.xiangguo_gate.yard_return") # TEST-ONLY: before 相国府's gate
	await _settle(tree)
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.take_passage(tree, city, &"city.xiangguo_gate.west", 240) and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("大门关着")), "memorial: 相国府's gate shut")
	var knock: ActService = city.service(&"city.xiangguo_gate.knock") as ActService
	_check(knock != null and await MapPlaces.drive(tree, city, MapPlaces.service_spot(city, &"city.xiangguo_gate.knock")) and knock.in_reach(), "memorial: at the gate")
	knock.interact()
	await _settle(tree)
	_check(state.marks.get("相国府开了门", 0) == 1, "memorial: the card opens the gate (相国府开了门)")
	_check(await MapPlaces.take_passage(tree, city, &"city.xiangguo_gate.west") and session.active_map().map_id() == &"city.xiangguo", "memorial: in through the gate")
	var house: WorldMapController = await MapPlaces.go_to(tree, session, &"city.xiangguo_hall")
	_check(house != null and house.map_id() == &"city.xiangguo", "memorial: into 相国府's hall")
	if house == null:
		return
	var wei: NpcRuntimeState = _first(session, &"city.xiangguo_hall", WEI)
	_check(wei != null and house.select_npc(wei.character_id) and house.ask_selected("奏本").any(func(line: String) -> bool: return line.contains("什么人")), "memorial: 韦执中 will not write for a stranger")
	var given: ItemHandlingResult = house.give_to_selected(_carried(session, CARD))
	_check(given.done() and state.marks.get("相国见了名帖", 0) == 1, "memorial: the 名帖 taken (相国见了名帖): %s %s" % [given.outcome, given.lines])
	_check(house.ask_selected("奏本").any(func(line: String) -> bool: return line.contains("午门")) and state.marks.get("相国写了奏本", 0) == 1, "memorial: the 奏本 written on 程不平's letter")
	# The 早朝.
	var front: WorldMapController = MapPlaces.enter(session, &"city.wumen", &"city.wumen.palace_return") # TEST-ONLY: back before the 午门
	await _settle(tree)
	var wait: ActService = front.service(&"city.wumen.wait") as ActService
	_check(wait != null and await MapPlaces.drive(tree, front, MapPlaces.service_spot(front, &"city.wumen.wait")), "memorial: at the 午门")
	wait.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("相国"), "memorial: 候到天亮 with the 相国, asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(state.marks.get("随相国上朝", 0) == 1 and state.marks.get("宫门放行", 0) == 1, "memorial: through the 铁门 behind the 相国")
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"imperial.throne_hall")
	_check(hall != null, "memorial: into the 太和殿")
	if hall == null:
		return
	_check(_count_in(session, &"imperial.throne_hall", WEI) == 1, "memorial: 韦执中 at the 早朝")
	for second: int in 60:
		if state.marks.get("见了福安", 0) == 1 and not hall.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("早朝过", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("槐阳王反了")), "memorial: the 早朝, 庾子建's 槐阳王反了 (the raid)")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"memorial") and StoryQuestLog.current_step(state, quest).step_id == &"audience", "memorial: the way taken by the 奏本")


func _strong(state: CharacterState) -> void:
	state.progression.combat_experience = 3000000 # TEST-ONLY: the 武考 is won
	for skill: StringName in [&"unarmed", &"dodge", &"parry", &"force"]:
		state.skills.set_raw_level(skill, 260) # TEST-ONLY


func _heal(state: CharacterState) -> void:
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum # TEST-ONLY: rested between bouts
		resource.current = resource.maximum


func _run(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	coordinator.set_manual_turns(false) # TEST-ONLY: the bout runs without the player's hand
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 3000:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			found += 1
	return found


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


func _zone_of_spawned(definition_id: StringName) -> StringName:
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		if spawn.npc_definition_id == definition_id:
			return spawn.zone_id
	return &""


func _point_of(definition_id: StringName) -> StringName:
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		if spawn.npc_definition_id == definition_id:
			return spawn.spawn_point_ids()[0]
	return &""


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", gender)
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
