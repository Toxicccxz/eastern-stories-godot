extends RefCounted

## 主线修补 B1 (owner 2026-11-09「开始 B 包」; DECISIONS「主线修补 B」): the villain's moves between chapters.
## - 一→二: 柳淳风 tells of the fire on 老松寨 when he writes the letter.
## - 五→六: the 堂审's text has the 海捕文书; after the fifth chapter two white-clad toss 饮风客栈 (not before,
##   gone once beaten); 店小二 on them before and after.
## - 八→九: the nail kept, two 鬼卒 come up by the boats at night (not by day, not when the sword was pulled);
##   the fisher's wife on 老三.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const RAIDER: StringName = &"native.npc.inn_raider"
const RUNNER: StringName = &"native.npc.hell_runner"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _session(tree)
	await _test_inn(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_inn_after(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_lake(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.story_quest(&"main.chapter5").step(&"trial").text.contains("海捕文书"), "the 堂审 tells of the 海捕文书")
	_check(FileAccess.get_file_as_string("res://data/common/npcs.json").count("把门闩上") == 2, "柳淳风 tells of the fire on 老松寨 (both ways the letter is written)")
	_check(FileAccess.get_file_as_string("res://data/waterfog/npcs.json").contains("他们在找你") and FileAccess.get_file_as_string("res://data/common/npcs.json").contains("他们在找你"), "南危水 and 潘军禅 tell of the burnt 土地庙")
	_check(FileAccess.get_file_as_string("res://data/fanfang/world.json").contains("关北工地出事后的第三天"), "the 番坊 order dated after the 关北 dig")
	var raid: NpcSpawnDefinition = catalog.spawn(&"native.inn.raiders")
	_check(raid != null and raid.zone_id == &"snow.inn.main_floor" and raid.cleared_mark == "客栈的白衣人退了", "two white-clad in the inn until beaten")


func _test_inn(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_enter_inn(session)
	await _settle(tree)
	_check(_count_in(session, &"snow.inn.main_floor", RAIDER) == 0, "before the fifth chapter: nobody tossing the inn")
	state.quests["main.chapter5#done"] = state.quests.size() + 1 # TEST-ONLY
	state.marks["程不平写了信"] = 1 # TEST-ONLY
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") # TEST-ONLY: out and back in
	await _settle(tree)
	var inn: WorldMapController = _enter_inn(session)
	await _settle(tree)
	_check(_count_in(session, &"snow.inn.main_floor", RAIDER) == 2, "after the 堂审: two white-clad in the inn")
	_check(_first(session, &"snow.inn.main_floor", &"snow.npc.waiter") != null and inn != null, "the waiter still behind the counter")


## Beaten (a fresh session, the fight left out): the white-clad gone, 店小二 keeps the room for you.
func _test_inn_after(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.quests["main.chapter5#done"] = state.quests.size() + 1 # TEST-ONLY
	state.marks["程不平写了信"] = 1 # TEST-ONLY
	state.marks["客栈的白衣人退了"] = 1 # TEST-ONLY: as beating them writes it
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") # TEST-ONLY: from outside
	await _settle(tree)
	var inn: WorldMapController = _enter_inn(session)
	await _settle(tree)
	_check(_count_in(session, &"snow.inn.main_floor", RAIDER) == 0, "beaten: gone")
	var waiter: NpcRuntimeState = _first(session, &"snow.inn.main_floor", &"snow.npc.waiter")
	_check(waiter != null and inn.select_npc(waiter.character_id) and _said(inn.ask_selected("白衣人"), "往后不收钱"), "店小二: the room is yours")


func _test_lake(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.marks["查清了封物"] = 1 # TEST-ONLY: the nail kept
	session.day_clock().set_day_seconds(36000) # TEST-ONLY: morning
	MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.boat_return") # TEST-ONLY
	await _settle(tree)
	_check(_count_in(session, &"village.lakeside", RUNNER) == 0, "by day: no 鬼卒")
	var village: WorldMapController = session.active_map() as WorldMapController
	var woman: NpcRuntimeState = _first(session, &"village.lakeside", &"village.npc.fisher")
	_check(woman != null, "a fisher on the lakeside (the nail kept)")
	if woman != null:
		_check(village.select_npc(woman.character_id) and _said(village.ask_selected("老三"), "老三前夜下湖收网"), "a fisher: 老三 did not come back")
	session.day_clock().set_day_seconds(78000) # TEST-ONLY: night
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") # TEST-ONLY: away and back
	await _settle(tree)
	MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.boat_return") # TEST-ONLY
	await _settle(tree)
	_check(_count_in(session, &"village.lakeside", RUNNER) == 2, "at night, the nail kept: two 鬼卒 by the boats (%d)" % _count_in(session, &"village.lakeside", RUNNER))


func _enter_inn(session: WorldSessionController) -> WorldMapController:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(&"snow.inn.waiter")
	session.handoff_to(spawn.map_id, spawn.zone_id, spawn.zone_id, spawn.spawn_point_ids()[0]) # TEST-ONLY
	return session.active_map() as WorldMapController


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
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("反手", CharacterState.GENDER_MALE)
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
