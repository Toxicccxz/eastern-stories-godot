extends RefCounted

## 主线 B (owner, 2026-10-29; DECISIONS「第二章旧案」): 旧案 end to end from 伪墓's end with the
## bones buried (StoryFixtures) — 柳淳风's letter, 陈剑秋's 镖单, the two inscriptions, 南危水
## speaking first to the one who buried 阿岭, 潘军禅 with the letter, telling 颜违 (his seat,
## 南危水's cold greeting), the quest's end and the save.

const LETTER: StringName = &"native:snow/letter_to_pan"
const NOTE: StringName = &"native:cloud/escort_note"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_chapter(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_chapter(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter2")
	StoryFixtures.chapter1_done(session, true)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(&"main.chapter1")) and StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests) == "回雪亭镇淳风武馆，把山洞里的事告诉柳淳风。", "旧案 begins as 伪墓 ends: %s" % [state.quests])
	# 柳淳风: the letter.
	var school: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.gate_entry")
	_check(school != null, "at the 武馆")
	await _settle(tree)
	var liu: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.schoolhall.master.1")
	_check(liu != null and school.place_player(&"snow.schoolhall", school.runtime_body_for_character(liu.character_id).global_position + Vector2(0, 60)), "beside 柳淳风")
	await _settle(tree)
	_check(school.select_npc(liu.character_id) and school.ask_topics_selected().has("水烟阁"), "水烟阁 to ask")
	var said: Array[String] = school.ask_selected("水烟阁")
	_check(said.size() >= 5 and said.any(func(line: String) -> bool: return line.contains("潘军禅")) and state.marks.get("柳淳风的引荐信", 0) == 1 and not _carried(session, LETTER).is_empty(), "he writes the letter: %s" % [said])
	_check(state.quests.has("main.chapter2/liu") and StoryQuestLog.objective(state, quests) == "去绮云镇振远镖局，问陈剑秋二十年前的失镖。", "recorded at the ask; 振远镖局 is next")
	# 陈剑秋: the 镖单.
	var biaoju: WorldMapController = MapPlaces.enter(session, &"cloud.biaoju", &"cloud.biaoju.eroad2_entry")
	_check(biaoju != null, "in the 镖局")
	await _settle(tree)
	var chen: NpcRuntimeState = MapPlaces.npc_at(session, &"cloud.biaoju.b_header.1")
	_check(chen != null and biaoju.place_player(&"cloud.biaoju", biaoju.runtime_body_for_character(chen.character_id).global_position + Vector2(0, 60)), "beside 陈剑秋")
	await _settle(tree)
	_check(biaoju.select_npc(chen.character_id), "陈剑秋 in reach")
	said = biaoju.ask_selected("失镖")
	_check(said.any(func(line: String) -> bool: return line.contains("盟主印")) and state.marks.get("看过镖单", 0) == 1 and not _carried(session, NOTE).is_empty(), "the 镖单 handed over: %s" % [said])
	_check(state.quests.has("main.chapter2/escort") and StoryQuestLog.objective(state, quests) == "上水烟阁的山，看葬剑亭里的碑。", "recorded; the mountain is next")
	# The two inscriptions.
	var mountain: WorldMapController = MapPlaces.enter(session, &"waterfog.sroad1", &"waterfog.sroad1.snow_entry")
	_check(mountain != null, "on the mountain")
	await _settle(tree)
	_check(mountain.place_player(&"waterfog.swordtomb", MapPlaces.zone_spot(mountain, &"waterfog.swordtomb")), "at the 葬剑亭")
	await _settle(tree)
	_check(mountain.select_landmark(&"waterfog.swordtomb.landmark.monolith") and mountain.inspect_selected() and state.marks.get("看过葬剑亭碑", 0) == 1, "the monolith read")
	session.record_journal()
	_check(state.quests.has("main.chapter2/tomb"), "recorded")
	_check(mountain.place_player(&"waterfog.wpath2", MapPlaces.zone_spot(mountain, &"waterfog.wpath2")), "at the 虹谷石台")
	await _settle(tree)
	_check(mountain.select_landmark(&"waterfog.wpath2.landmark.stone") and mountain.inspect_selected() and state.marks.get("看过石台碑", 0) == 1, "the stone read")
	session.record_journal()
	_check(state.quests.has("main.chapter2/stone") and StoryQuestLog.objective(state, quests) == "上楼找五长老南危水，拿证据问他山洞里的骸骨。", "recorded; 南危水 is next")
	# 南危水 speaks first to the one who buried 阿岭 (his call), before any question.
	var upstairs: WorldMapController = MapPlaces.enter(session, &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival")
	_check(upstairs != null, "upstairs")
	await _settle(tree)
	var nan: NpcRuntimeState = MapPlaces.npc_at(session, &"waterfog.forehall.elder5.1")
	_check(nan != null and upstairs.place_player(&"waterfog.forehall", upstairs.runtime_body_for_character(nan.character_id).global_position + Vector2(0, 60)), "beside 南危水")
	await _settle(tree)
	var log_before: int = ui.log_lines().size()
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
	_check(ui.log_lines().slice(log_before).any(func(line: String) -> bool: return line.contains("是你埋了阿岭")) and state.marks.get("南危水承认了", 0) == 1, "he speaks first: 阿岭, the ambush, twenty years: %s" % [ui.log_lines().slice(log_before)])
	session.record_journal()
	_check(state.quests.has("main.chapter2/nan") and StoryQuestLog.objective(state, quests) == "拿着引荐信到前厅找执法使潘军禅，问「邪剑穿灵」。", "recorded; 潘军禅 is next")
	_check(upstairs.select_npc(nan.character_id) and upstairs.ask_selected("山洞的骸骨").any(func(line: String) -> bool: return line.contains("老夫都说了")), "asked again, he has said it all")
	# 潘军禅 with the letter.
	var pavilion: WorldMapController = MapPlaces.enter(session, &"waterfog.entrance", &"waterfog.entrance.yard_arrival")
	_check(pavilion != null, "in the pavilion")
	await _settle(tree)
	var pan: NpcRuntimeState = MapPlaces.npc_at(session, &"waterfog.guildhall.executioner.1")
	_check(pan != null and pavilion.place_player(&"waterfog.guildhall", pavilion.runtime_body_for_character(pan.character_id).global_position + Vector2(0, 60)), "beside 潘军禅")
	await _settle(tree)
	_check(pavilion.select_npc(pan.character_id), "潘军禅 in reach")
	said = pavilion.ask_selected("邪剑穿灵")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("野羊山北麓")) and state.marks.get("潘军禅说了鱼饵", 0) == 1 and state.quests.has("main.chapter2/pan") and StoryQuestLog.objective(state, quests) == "替南危水保密，还是告诉七长老颜违？", "the bait, the taoist, the north slope: %s" % [said])
	# The choice: tell 颜违. His seat; 南危水's cold greeting.
	upstairs = MapPlaces.enter(session, &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival")
	await _settle(tree)
	var yan: NpcRuntimeState = MapPlaces.npc_at(session, &"waterfog.forehall.elder7.1")
	_check(yan != null and upstairs.place_player(&"waterfog.forehall", upstairs.runtime_body_for_character(yan.character_id).global_position + Vector2(0, 60)), "beside 颜违")
	await _settle(tree)
	_check(upstairs.select_npc(yan.character_id) and upstairs.ask_topics_selected().has("南危水的事"), "南危水的事 to tell")
	var deeds_before: int = state.deeds.size()
	said = upstairs.ask_selected("南危水的事")
	_check(said.any(func(line: String) -> bool: return line.contains("代行盟主之职")) and state.marks.get("告发了南危水", 0) == 1 and yan.short_name().contains("水烟阁代盟主"), "颜违 takes the seat: %s / %s" % [said, yan.short_name()])
	session.record_journal()
	_check(state.quests.has("main.chapter2/choice/tell") and StoryQuestLog.is_done(state, quest), "told: the choice recorded, 旧案 done: %s" % [state.quests])
	_check(state.deeds.size() == deeds_before + 2 and state.deeds[-2].did == "把五长老南危水装死二十年的事告诉了七长老颜违" and state.deeds[-1].did == "查清了二十年前水烟阁五长老的旧案", "its deeds")
	_check(state.milestones.has("quest/main.chapter2"), "the 历练")
	_check(upstairs.select_npc(nan.character_id) and upstairs.ask_selected("保密").any(func(line: String) -> bool: return line.contains("保什么密")), "保密 is no longer his to grant")
	# 南危水's greeting for one who told: the player comes in again.
	MapPlaces.enter(session, &"waterfog.entrance", &"waterfog.entrance.yard_arrival")
	await _settle(tree)
	upstairs = MapPlaces.enter(session, &"waterfog.west_2f", &"waterfog.west_2f.stairs_arrival")
	await _settle(tree)
	upstairs.place_player(&"waterfog.forehall", upstairs.runtime_body_for_character(nan.character_id).global_position + Vector2(0, 50))
	await _settle(tree)
	# The log is capped (SharedGameplayUI.MAX_LOG_LINES): its tail, not a slice from an old size.
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
	_check(ui.log_lines().slice(-4).any(func(line: String) -> bool: return line.contains("看了你一眼，没有说话")), "南危水's greeting is a cold look: %s" % [ui.log_lines().slice(-4)])
	# The 任务 page and the save.
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var page: String = ui.quest_page.shown_text()
	_check(page.contains("旧案 · 水烟阁 · 已完成") and page.contains("· 你把南危水的事告诉了七长老颜违。"), "the 任务 page: " + page.left(300))
	var snapshot: GameSaveSnapshot = _capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(snapshot != null and decoded.snapshot != null and decoded.snapshot.player.character.quests == state.quests and decoded.snapshot.player.character.marks.get("告发了南危水", 0) == 1, "saved and read back: %s" % [decoded.detail])


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("旧案", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	for id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-29T00:00:00Z")
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
