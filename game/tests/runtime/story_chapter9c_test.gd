extends RefCounted

## 第九章 C 养心殿与御书房, 尚书府 (owner's plan, 2026-11-06「按你的推荐来」; DECISIONS「第九章 C」), from the
## eighth chapter's ledger and the A/B package's way in (TEST-ONLY: written as the 殿试 / the well writes it):
## - day (exam × raid): the 养心门 shut to one not sent for, open to 见了福安; the hall's scene (见了皇帝) and
##   槐阳王反了 (the raid); the 御书房 locked till then; the 樟木匣 gives the two decrees; the 御案 compares
##   them — 学过印色 (the 第六章 lesson): 对出了原令 and the woodcutter's page; the quest's audience and
##   decree done, the choice next. 钟嬷嬷 reads the copy (钟嬷嬷认过字). The 尚书府: the 花匠's new word; the
##   护院 outside the 帘子 stops one, down he lets them by; 庾清尘's scene (见过清尘), 密道 (the stone known,
##   the 障眼符); 卫沧澜's three lines, 白衣武官 (卫沧澜作证), 走 (gone: 卫沧澜出了尚书府); the 小屋's
##   courier falls on the player and goes to smoke, the 密信 on the floor.
## - night (sneak, kept): the 西暖阁's window shut to one 钟嬷嬷 has not told, open to one she has; the
##   sneak's scene (杀朕的人不翻窗).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const ORIGINAL: StringName = &"native:imperial/original_decree"
const COPY: StringName = &"native:imperial/war_ministry_copy"
const RECORD: StringName = &"native:imperial/woodcutter_record"
const CHARM: StringName = &"native:city/blinding_charm"
const LETTER: StringName = &"native:city/courier_letter"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var day: WorldSessionController = await _session(tree)
	await _test_day(tree, day)
	await _test_mansion(tree, day)
	day.free()
	await tree.process_frame
	var night: WorldSessionController = await _session(tree)
	await _test_night(tree, night)
	night.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter9")
	_check(quest.steps.size() == 4 and quest.steps[2].step_id == &"decree" and quest.steps[3].step_id == &"choice", "第九章: way, audience, decree, choice")
	var desk: ServiceDefinition = catalog.service(&"imperial.study.desk")
	_check(desk != null and desk.act.verb == "比对" and desk.act.acts.size() == 6, "御案 · 比对: done, nothing yet, 印色, 印模, 钟嬷嬷, none of them")
	for id: StringName in [&"native.npc.night_guard_lanes", &"native.npc.night_guard_gate", &"native.npc.night_guard_garden"]:
		var watch: NpcWatch = catalog.npc(id).dealings().watch
		_check(watch.dim_when != null and watch.dim_scale_percent == 60, "%s: the 障眼符 shortens his eye" % id)


func _test_day(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter9")
	StoryFixtures.chapter8_done(session, false, true, true)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"way", "the way still to take")
	for mark: String in ["中了武状元", "宫门放行", "候了殿试", "殿试过", "进了皇城"]:
		state.marks[mark] = 1 # TEST-ONLY: as the 武举 and the 殿试 write them (story_chapter9_test)
	var lanes: WorldMapController = MapPlaces.enter(session, &"imperial.yangxin_gate", &"imperial.yangxin_gate.yard_return") # TEST-ONLY: before the 养心门
	await _settle(tree)
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.take_passage(tree, lanes, &"imperial.yangxin_gate.east", 200) and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("门闩在里头")), "the 养心门 shut to one not sent for")
	state.marks["见了福安"] = 1 # TEST-ONLY: 福安's 今夜养心殿
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"exam") and StoryQuestLog.current_step(state, quest).step_id == &"audience", "the way taken (the 殿试), the audience next")
	_check(await MapPlaces.take_passage(tree, lanes, &"imperial.yangxin_gate.east") and session.active_map().map_id() == &"imperial.yangxin_hall", "the 养心门 opens to one sent for")
	await _settle(tree)
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"imperial.front_hall")
	_check(hall != null, "into the 养心殿")
	if hall == null:
		return
	for second: int in 40:
		if state.marks.get("皇帝说了槐阳王", 0) == 1 and not hall.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("见了皇帝", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("白天殿上，朕不敢说话")), "the boy's scene (见了皇帝)")
	_check(state.marks.get("皇帝说了槐阳王", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("槐阳王反了")), "槐阳王反了 — he asks the one from 关北 (the raid)")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"decree", "the 御书房 next")
	_check(await MapPlaces.drive_to_zone(tree, hall, &"imperial.study"), "into the 御书房 (open now)")
	var chest: ActService = hall.service(&"imperial.study.chest") as ActService
	_check(chest != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"imperial.study.chest")) and chest.in_reach(), "at the 樟木匣")
	chest.interact()
	await _settle(tree)
	_check(session.player_held_item_ids().get(ORIGINAL, false) and session.player_held_item_ids().get(COPY, false) and state.marks.get("翻过樟木匣", 0) == 1, "the 原令 and the 兵部抄本 out of the chest")
	var desk: ActService = hall.service(&"imperial.study.desk") as ActService
	_check(desk != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"imperial.study.desk")) and desk.in_reach(), "at the 御案")
	state.marks["学过印色"] = 1 # TEST-ONLY: the 第六章 lesson (the ledger's)
	desk.interact()
	await _settle(tree)
	_check(state.marks.get("对出了原令", 0) == 1 and session.player_held_item_ids().get(RECORD, false) and ui.log_lines().any(func(line: String) -> bool: return line.contains("拓了模子")), "the seals compared: 对出了原令, the woodcutter's page")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"choice", "the choice next (D)")
	# 钟嬷嬷 reads the copy.
	var cold: WorldMapController = MapPlaces.enter(session, &"imperial.cold_room", &"imperial.cold_room.zhong_momo.1") # TEST-ONLY: beside her
	await _settle(tree)
	var zhong: NpcRuntimeState = _first(session, &"imperial.cold_room", &"native.npc.zhong_momo")
	_check(zhong != null and cold.select_npc(zhong.character_id) and cold.ask_selected("寻剑令").any(func(line: String) -> bool: return line.contains("那一卷不是")) and state.marks.get("钟嬷嬷认过字", 0) == 1, "钟嬷嬷 reads the two: 那一卷不是")


func _test_mansion(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var house: WorldMapController = MapPlaces.enter(session, &"city.shangshu.huayuan", &"city.shangshu.huayuan.neizhai_guard.1") # TEST-ONLY: in the garden
	await _settle(tree)
	var gardener: NpcRuntimeState = _first(session, &"city.shangshu.huayuan", &"city.npc.shangshu.gardener")
	_check(gardener != null and house.select_npc(gardener.character_id) and house.ask_selected("庾清尘").any(func(line: String) -> bool: return line.contains("帘子外头有人守着")), "the 花匠: 清尘出事了 — and what")
	var guard: NpcRuntimeState = _first(session, &"city.shangshu.huayuan", &"native.npc.neizhai_guard")
	_check(guard != null, "the 护院 outside the 帘子")
	house.set_door_open(&"city.shangshu.huayuan.door", true) # TEST-ONLY: the 帘子 drawn aside
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.drive_to_zone(tree, house, &"city.shangshu.neizhai") and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("小姐这几天不见人")), "he stops one at the 帘子")
	if guard != null:
		house.npcs.leave_for_good(guard) # TEST-ONLY: as one knocked down or gone
	_check(await MapPlaces.drive_to_zone(tree, house, &"city.shangshu.neizhai"), "past the 帘子")
	for second: int in 30:
		if state.marks.get("见过清尘", 0) == 1 and not house.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("见过清尘", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("冷宫的井")), "庾清尘's scene: the 祭坛, the bed, the well")
	var qing: NpcRuntimeState = _first(session, &"city.shangshu.neizhai", &"city.npc.shangshu.qing_chen")
	_check(qing != null and house.select_npc(qing.character_id) and house.ask_selected("密道").size() > 0 and session.player_held_item_ids().get(CHARM, false) and state.marks.get("清尘说了密道", 0) == 1 and state.marks.get("看过床底的石板", 0) == 1, "密道: the stone known, the 障眼符")
	# 卫沧澜.
	MapPlaces.enter(session, &"city.shangshu.kefang", &"city.shangshu.kefang.wei_canglan.1") # TEST-ONLY: in the 客房
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var wei: NpcRuntimeState = _first(session, &"city.shangshu.kefang", &"native.npc.wei_canglan")
	_check(wei != null and state.marks.get("见过卫沧澜", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("二十年，第一个")), "卫沧澜: 二十年，第一个不是庾家的人")
	_check(wei != null and house.select_npc(wei.character_id) and house.ask_selected("白衣武官").size() > 0 and state.marks.get("卫沧澜作证", 0) == 1, "白衣武官: he will be a witness")
	_check(wei != null and house.ask_selected("走").size() > 0 and state.marks.get("卫沧澜出了尚书府", 0) == 1, "走: he goes (卫沧澜出了尚书府)")
	await _settle(tree)
	_check(_first(session, &"city.shangshu.kefang", &"native.npc.wei_canglan") == null, "and is gone")
	# The 小屋's courier.
	var state_exp: int = state.progression.combat_experience
	state.progression.combat_experience = 3000000 # TEST-ONLY: the fight is won
	for skill: StringName in [&"unarmed", &"dodge", &"parry", &"force"]:
		state.skills.set_raw_level(skill, 260) # TEST-ONLY
	MapPlaces.enter(session, &"city.shangshu.xiaowu", &"city.shangshu.xiaowu.courier.1") # TEST-ONLY: into the dark
	await _settle(tree)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for frame: int in 60:
		house.hostilities.process_pending_aggression()
		if coordinator.has_active_encounter():
			break
		await tree.physics_frame
	_check(coordinator.has_active_encounter(), "the courier falls on the player")
	coordinator.set_manual_turns(false) # TEST-ONLY
	var rounds: int = 0
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	while coordinator.has_active_encounter() and rounds < 3000:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	session.shared_ui().dismiss_current_panel()
	await _settle(tree)
	_check(_first(session, &"city.shangshu.xiaowu", &"native.npc.niling_courier") == null and state.marks.get("小屋的信使倒了", 0) == 1, "he goes to smoke (小屋的信使倒了)")
	_check(_floor_has(house, LETTER), "the 密信 on the floor")
	state.progression.combat_experience = state_exp


func _test_night(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter8_done(session, true)
	for mark: String in ["从冷宫井上来", "钟嬷嬷见过你"]:
		state.marks[mark] = 1 # TEST-ONLY: as the well and 钟嬷嬷 write them (imperial_watch_test)
	session.record_journal()
	var lanes: WorldMapController = MapPlaces.enter(session, &"imperial.yangxin_gate", &"imperial.yangxin_gate.yard_return") # TEST-ONLY
	await _settle(tree)
	var before: int = ui.log_lines().size()
	_check(not await MapPlaces.take_passage(tree, lanes, &"imperial.yangxin_gate.window", 200) and ui.log_lines().slice(before).any(func(line: String) -> bool: return line.contains("不知道哪一扇是坏的")), "the windows shut to one not told")
	state.marks["钟嬷嬷说了窗闩"] = 1 # TEST-ONLY: her 养心殿 answer
	_check(await MapPlaces.take_passage(tree, lanes, &"imperial.yangxin_gate.window") and session.player_runtime().world_location().zone_id == &"imperial.west_room", "in through the 西暖阁's window")
	await _settle(tree)
	var hall: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_to_zone(tree, hall, &"imperial.front_hall"), "into the hall")
	for second: int in 40:
		if state.marks.get("皇帝看见了穿灵", 0) == 1 and not hall.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("见了皇帝", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("杀朕的人不翻窗")), "the sneak's scene: 杀朕的人不翻窗")
	_check(state.marks.get("皇帝看见了穿灵", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("你拔了它")), "the pulled sword: 你拔了它？")


func _floor_has(map: WorldMapController, definition_id: StringName) -> bool:
	for item_id: StringName in map.floor_items.item_views.keys():
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return true
	return false


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
