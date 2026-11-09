extends RefCounted

## 主线修补 A (owner 2026-11-09「按推荐做」; DECISIONS「主线修补 A」):
## - The 荐信: the first 官爷 asked, 店小二 hands back the letter left on the table (once); 柳淳风 knows
##   老岑's hand; 岚翁 reads its last line to the one who carries it; the 雪亭 card of the ending has the line.
## - 商玦's burnt palm; 卫沧澜 on why 庾子建 kept him; the emperor gives the errand (data).
## - 灭's cost: the ask says both sides; the 晚月庄 card follows 宝衣烧了.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const LETTER: StringName = &"native:snow/old_letter"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_letter(tree, session)
	session.free()
	await tree.process_frame
	_test_ending()
	_test_lines()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_letter(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(&"snow.inn.waiter")
	session.handoff_to(spawn.map_id, spawn.zone_id, spawn.zone_id, spawn.spawn_point_ids()[0]) # TEST-ONLY
	await _settle(tree)
	var map: WorldMapController = session.active_map() as WorldMapController
	var waiter: NpcRuntimeState = _first(session, spawn.zone_id, &"snow.npc.waiter")
	_check(waiter != null and map.select_npc(waiter.character_id), "店小二 in reach")
	var said: Array[String] = map.ask_selected("官爷")
	_check(_said(said, "来的那天傍晚") and _said(said, "这封信落在桌上") and _said(said, "外头广场上来了官爷") and _said(said, "旋芒宝剑"), "the letter handed back, then the officials: %s" % [said])
	_check(_carried(session, LETTER) == 1 and state.marks.get("拿回了荐信", 0) == 1, "the 荐信 carried, 拿回了荐信")
	said = map.ask_selected("官爷")
	_check(_carried(session, LETTER) == 1 and _said(said, "外头广场上来了官爷") and not _said(said, "这封信"), "asked again: the officials alone, no second letter: %s" % [said])
	# 柳淳风 knows the hand.
	var hall: WorldMapController = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1") # TEST-ONLY
	await _settle(tree)
	var liu: NpcRuntimeState = _first(session, &"snow.schoolhall", &"common.npc.swordsman.master")
	_check(liu != null and hall.select_npc(liu.character_id) and hall.ask_topics_selected().has("荐信"), "柳淳风: 荐信 to ask")
	said = hall.ask_selected("荐信")
	_check(_said(said, "老岑") and _said(said, "砍柴的老人") and state.marks.get("柳淳风认了荐信", 0) == 1 and _carried(session, LETTER) == 1, "柳淳风 knows 老岑's hand and gives it back: %s" % [said])
	# 岚翁 reads the last line.
	var bells: WorldMapController = MapPlaces.enter(session, &"lancheng.bell_hall", &"lancheng.bell_hall.street_arrival") # TEST-ONLY
	await _settle(tree)
	var weng: NpcRuntimeState = _first(session, &"lancheng.bell_hall", &"native.npc.lan_weng")
	_check(weng != null and bells.select_npc(weng.character_id), "岚翁 in reach")
	said = bells.ask_selected("荐信")
	_check(_said(said, "风停处，替我再看一眼") and _said(said, "那个砍柴的") and state.marks.get("读懂了荐信", 0) == 1, "岚翁 reads the wind script: %s" % [said])
	# The 雪亭 card of the ending.
	var shown: Array[Array] = GameContent.catalog().epilogue(&"ending").shown(session.quest_condition_test())
	_check(_card_says(shown, "雪亭镇", "老岑的坟前"), "the ending's 雪亭 card has 老岑's grave")


func _test_ending() -> void:
	var ending: EpilogueDefinition = GameContent.catalog().epilogue(&"ending")
	var burned: Callable = func(entry: JournalEntryDefinition) -> bool: return _holds(entry, ["宝衣给了安妮儿", "宝衣烧了"])
	var kept: Callable = func(entry: JournalEntryDefinition) -> bool: return _holds(entry, ["宝衣给了安妮儿"])
	_check(_card_says(ending.shown(burned), "晚月庄", "一捧灰") and not _card_says(ending.shown(burned), "晚月庄", "把宝衣带回了东方神教"), "灭: 安妮儿 brings back ashes")
	_check(_card_says(ending.shown(kept), "晚月庄", "把宝衣带回了东方神教") and not _card_says(ending.shown(kept), "晚月庄", "一捧灰"), "再封: 安妮儿 brings back the robe")
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	_check(quest.step(&"end").objective.contains("宝衣会烧掉"), "the 目标 row says the cost")


func _test_lines() -> void:
	var native: String = FileAccess.get_file_as_string("res://data/native/npcs.json")
	var imperial: String = FileAccess.get_file_as_string("res://data/imperial/npcs.json")
	_check(native.contains("掌心一片焦黑") and native.contains("寒於的剑认干净的手"), "商玦 shows the burnt palm")
	_check(imperial.contains("「盟主还活着」的念想"), "卫沧澜: why he was kept")
	_check(native.contains("封进石匣，埋回风停的地方") and native.contains("奉旨寻剑"), "白道长 buried the bell; 冯策: 奉旨寻剑")
	_check(FileAccess.get_file_as_string("res://data/imperial/world.json").count("朕交给你了") == 3, "the emperor gives the errand on all three ways in")


func _holds(entry: JournalEntryDefinition, marks: Array) -> bool:
	match entry.when:
		JournalEntryDefinition.When.MARK: return marks.has(entry.key)
		JournalEntryDefinition.When.NOT: return not _holds(entry.parts[0], marks)
		JournalEntryDefinition.When.ALL: return entry.parts.all(func(part: JournalEntryDefinition) -> bool: return _holds(part, marks))
		JournalEntryDefinition.When.ANY: return entry.parts.any(func(part: JournalEntryDefinition) -> bool: return _holds(part, marks))
	return false


func _card_says(shown: Array[Array], title: String, part: String) -> bool:
	for pair: Array in shown:
		var card: EpilogueDefinition.Card = pair[0]
		if card.title == title and (pair[1] as Array).any(func(line: String) -> bool: return line.contains(part)):
			return true
	return false


func _carried(session: WorldSessionController, definition_id: StringName) -> int:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var count: int = 0
	for item_id: StringName in context.inventory.direct_children(context.endpoint()):
		var item: ItemInstance = context.index.resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			count += 1
	return count


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("荐信", CharacterState.GENDER_MALE)
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
