extends RefCounted

## 青石村 A (d/green): the 39 rooms on three maps and the way in from Snow's 山坳; the
## spawns and items as imported; the exits as data: the 迷阵's passages (to itself, back,
## on, into 绝地), eight7.c's 八卦阵 mark, entrance.c's 100000 combat_exp, outdoor.c's
## seal, the two one-way ways; closed.c's push and the native way out (放弃); water.c's
## search; house3.c's web; rope.c's hang. Walks go through the passages with the move
## actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const ROPE: StringName = &"es2:d/green/obj/rope"
const WINDSWORD: StringName = &"es2:d/green/obj/windsword"
const MASTER: StringName = &"common.npc.juechen.master"
const VILLAGE: Array[String] = [
	"path6", "path5", "station0", "path4", "shop0", "path3", "house0", "path8", "house1", "field0",
	"house2", "house4", "field1", "house3", "station1", "path2", "temple0", "path1", "path0",
]
const MOUNTAIN: Array[String] = ["cave0", "cave1", "cave2", "mpath0", "mpath1", "mpath2", "entrance", "outdoor", "cavehall", "stoneroom", "water"]
const MAZE: Array[String] = ["eight0", "eight1", "eight2", "eight3", "eight4", "eight5", "eight6", "eight7", "closed"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_maze_exits()
	_test_exit_rules()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_test_the_way_in(session)
	await _test_village(tree, session)
	await _test_web(tree, session)
	await _test_rope(tree, session)
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY
	await _test_maze(tree, session)
	await _test_stone_rooms(tree, session)
	await _test_closed(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary[StringName, int] = {}
	for room: String in VILLAGE + MOUNTAIN + MAZE:
		var room_id := StringName("es2:d/green/" + room)
		var zone: ZoneDefinition = catalog.zone(StringName("green." + room))
		_check(catalog.room(room_id) != null and zone != null and zone.room_ids() == [room_id], "%s: a zone of its own" % room)
		if zone != null:
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
	_check(maps == {&"green.village": 19, &"green.mountain": 11, &"green.maze": 9}, "19 rooms in the village, 11 in the mountain, 9 in the 迷阵: %s" % maps)
	_check(catalog.room(&"es2:d/green/path6").outdoors and not catalog.room(&"es2:d/green/field0").outdoors and not catalog.room(&"es2:d/green/house0").outdoors, "set(\"outdoors\") as authored: the road yes, the square and the houses not")
	for room: String in MAZE.slice(0, 8):
		_check(catalog.zone(StringName("green." + room)).distinct, "%s has its own say (every 迷阵 room is named 迷阵)" % room)
	var spawns: Dictionary[StringName, int] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if String(spawn.zone_id).begins_with("green."):
			spawns[spawn.npc_definition_id] = spawns.get(spawn.npc_definition_id, 0) + spawn.spawn_point_ids().size()
	_check(spawns == {
		&"green.npc.worker2": 5, &"green.npc.shen": 1, &"green.npc.woman1": 2, &"green.npc.woman2": 1,
		&"green.npc.kid3": 2, &"green.npc.worker1": 1, &"green.npc.oldman": 1, &"green.npc.oldwoman": 1,
		&"green.npc.oldman2": 1, &"green.npc.kid1": 1, &"green.npc.kid2": 2, &"green.npc.kid4": 2, &"green.npc.spider": 3,
	}, "twenty villagers of twelve kinds, three spiders the web calls in; 绝尘子 waits for package C: %s" % spawns)
	_check(catalog.spawn(&"green.village.house3.spiders").summoned, "the spiders are summoned (house3.c call_spider())")
	_check(catalog.item(ROPE).hang and catalog.item(ROPE).value == 5, "绳子: hang")
	var sword: ItemContentDefinition = catalog.item(WINDSWORD)
	_check(sword != null and sword.weapon_damage == 70 and sword.weapon_apply == {&"attack": 5, &"courage": 10} and sword.value == 1000000, "追风剑: sword 70, attack 5, courage 10")
	_check(catalog.item(&"es2:d/green/npc/obj/knife").weapon_skill_type == &"blade" and catalog.item(&"es2:d/green/obj/hammer").weapon_damage == 10, "菜刀 and 铁锤")
	var well: ServiceDefinition = catalog.service(&"green.station0.well")
	_check(well != null and well.zone_id == &"green.station0", "the station's well: a water service (resource/water)")
	var web: WorldLandmarkDefinition = catalog.landmark(&"green.house3.landmark.web")
	_check(web.policy == &"look_spawn" and web.setting("limit") == 3 and web.spawn_id == &"green.village.house3.spiders" and web.action_label.is_empty(), "the web: looked at, three a reset")
	var stone: WorldLandmarkDefinition = catalog.landmark(&"green.closed.landmark.stone")
	_check(stone.policy == &"push_stone" and stone.setting("force") == 560 and stone.setting("max_force") == 560 and stone.setting("force_factor") == 40 and stone.setting("random") == 3 and stone.portal_id == &"green.closed.push", "绝地's stone: closed.c's numbers")
	var water: WorldLandmarkDefinition = catalog.landmark(&"green.water.landmark.water")
	_check(water.policy == &"search" and water.mark == "八卦阵" and water.item("reward") == WINDSWORD and water.setting("random") == 2, "the stream: search with the mark")
	_check(catalog.portal(&"green.eight7.south").set_mark == "八卦阵" and catalog.portal(&"green.eight6.north").set_mark.is_empty(), "only leaving 乾 south marks the player")


## Every 迷阵 room's four exits are passages to where its LPC exits lead, at the opposite side.
func _test_maze_exits() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var opposite: Dictionary[String, String] = {"north": "south", "south": "north", "west": "east", "east": "west"}
	for room: String in MAZE.slice(0, 8):
		var exits: Dictionary[String, StringName] = catalog.room(StringName("es2:d/green/" + room)).exits()
		_check(exits.size() == 4, "%s: four exits" % room)
		for direction: String in exits:
			var portal: PortalDefinition = catalog.portal(StringName("green.%s.%s" % [room, direction]))
			var target: String = String(exits[direction]).trim_prefix("es2:d/green/")
			_check(portal != null and portal.destination_zone_id == StringName("green." + target), "%s %s leads to %s" % [room, direction, target])
			if portal != null and target.begins_with("eight"):
				_check(String(portal.destination_spawn_point_id).ends_with(opposite[direction] + "_arrival"), "%s %s arrives on %s's %s side" % [room, direction, target, opposite[direction]])


func _test_exit_rules() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var wind: ZoneExitRuleDefinition = catalog.exit_rules_between(&"green.entrance", &"green.eight0")[0]
	_check(wind.refuses(ZoneExitRuleDefinition.Leaver.new(false, 99999), false) and not wind.refuses(ZoneExitRuleDefinition.Leaver.new(false, 100000), false), "the wind turns back anyone below 100000 combat_exp")
	var seal: ZoneExitRuleDefinition = catalog.exit_rules_between(&"green.outdoor", &"green.cavehall")[0]
	_check(seal.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, &"common.npc.fighter.master"), false) and not seal.refuses(ZoneExitRuleDefinition.Leaver.new(false, 0, MASTER), false), "the hall is sealed but to 绝尘子's apprentices")
	_check(catalog.exit_rules_between(&"green.cavehall", &"green.outdoor").is_empty(), "nothing keeps anyone in")
	# cavehall.c places CLASS_D("juechen") + "/master": the importer names it common.npc.juechen.master.
	_check(seal.npc_id == StringName("common.npc." + "daemon/class/juechen/master.c".trim_prefix("daemon/class/").trim_suffix(".c").replace("/", ".")), "the seal names the master cavehall.c places")
	# REMINDER (fails once package C adds 绝尘子): then make ContentCatalogBuilder check that a
	# not_apprentice_of rule's npc exists, and drop this line.
	_check(catalog.npc(seal.npc_id) == null, "绝尘子 comes with package C: validate the seal's npc in the builder then")


func _test_the_way_in(session: OldPineWorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var east: PortalDefinition = catalog.portal(&"snow.crossroad.east")
	var west: PortalDefinition = catalog.portal(&"green.path6.west")
	_check(east != null and east.destination_zone_id == &"green.path6" and east.legacy_command == "east", "山坳 east to 青石村's stone road")
	_check(west != null and west.destination_zone_id == &"snow.crossroad" and west.destination_spawn_point_id == &"snow.crossroad.green_return", "and back west")
	var snow: WorldMapController = session.resident_map(&"snow.outdoor") as WorldMapController
	_check(snow.spawn_matches_zone(&"snow.crossroad.green_return", &"snow.crossroad"), "Snow's return marker on the col")


## In from 山坳, down the stone road to the square and the quarry yard; the well.
func _test_village(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"snow.outdoor", &"snow.crossroad", &"snow.crossroad", &"snow.crossroad.green_return").succeeded(), "on the col")
	await tree.physics_frame
	await tree.physics_frame
	var snow: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, snow, &"snow.crossroad.east"), "east off the col")
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(map.map_id() == &"green.village" and session.player_runtime().world_location().zone_id == &"green.path6", "on 青石村's stone road")
	_check(map.resident_npcs().size() == 21, "twenty villagers, the spiders waiting in the web: %d" % map.resident_npcs().size())
	var visible: int = 0
	for npc: NpcRuntimeState in map.resident_npcs():
		visible += 1 if npc.exists_in_map else 0
	_check(visible == 18, "eighteen in sight (three spiders absent): %d" % visible)
	_check(await MapPlaces.drive_through(tree, map, [&"green.path5", &"green.path4", &"green.path3", &"green.path8", &"green.field0", &"green.field1"]), "up the street, along the lane, across the square to the quarry yard")
	_check(session.player_runtime().world_location().zone_id == &"green.field1", "in the yard")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"green.station0.well")), "to the well")
	_check(session.player_runtime().world_location().zone_id == &"green.station0", "the station's well")


## house3.c's web: three spiders a reset, then only the web.
func _test_web(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_to_zone(tree, map, &"green.house3"), "into the empty house")
	_check(map.select_landmark(&"green.house3.landmark.web"), "the web selected")
	hud.refresh_live_state()
	_check(not hud.portal_action_is_enabled(), "only looked at")
	var spiders: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == &"green.npc.spider":
			spiders.append(npc)
	for n: int in 3:
		map.inspect_selected()
		_check(hud.inspection_text.text.begins_with("蜘蛛网\n突然你觉得头上有个阴影"), "look %d: a spider drops: %s" % [n + 1, hud.inspection_text.text])
		hud.dismiss_current_panel()
		var present: int = 0
		for spider: NpcRuntimeState in spiders:
			present += 1 if spider.exists_in_map else 0
		_check(present == n + 1, "%d spider(s) here" % (n + 1))
	map.inspect_selected()
	_check(hud.inspection_text.text == "蜘蛛网\n一个很大的蜘蛛网.", "the fourth look: only the web: %s" % hud.inspection_text.text)
	hud.dismiss_current_panel()
	_check(not GameContent.catalog().npc(&"green.npc.spider").can_speak(), "a beast: no 打听, no 切磋")
	# reset(): num_of_spider = 3 again, but the three still stand here: no fourth.
	session.reset_room("d/green/house3.c")
	map.select_landmark(&"green.house3.landmark.web")
	map.inspect_selected()
	_check(hud.inspection_text.text == "蜘蛛网\n一个很大的蜘蛛网.", "after the reset the three are still here: only the web")
	hud.dismiss_current_panel()
	var dead: NpcRuntimeState = spiders[0]
	dead.character_state.vitality.apply_wound(dead.character_state.vitality.effective + 1) # TEST-ONLY
	dead.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("好大的 ..... 蜘蛛"), "one dead: a new one drops")
	hud.dismiss_current_panel()
	var fresh: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.spawn_point_id == dead.spawn_point_id and npc != dead:
			fresh = npc
	_check(fresh != null and fresh.exists_in_map and fresh.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and fresh.character_id != dead.character_id, "a new spider (the next generation) stands on the dead one's point")


## rope.c: outdoors nowhere to hang it; indoors, asked first, then death.
func _test_rope(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var rope: StringName = _give(session, ROPE)
	_check(await MapPlaces.drive_to_zone(tree, map, &"green.field1"), "out in the yard (outdoors)")
	_check(not map.can_hang_here() and not map.hang_with(rope), "nowhere to hang it")
	_check(WorldMapController.zone_outdoors(&"oldpine.tree.canopy") and not WorldMapController.zone_outdoors(&"green.house3"), "a zone of rooms that disagree (the pine's canopy, tree3 outdoors) counts as outdoors")
	_check(hud.log_lines()[-1] == "你四处看看, 实在找不到地方挂绳子说...", "rope.c's line: " + hud.log_lines()[-1])
	_check(await MapPlaces.drive_to_zone(tree, map, &"green.house3"), "back indoors")
	hud._hang_with(rope)
	_check(hud.is_asking() and hud.confirm_prompt.confirm_button.text == "确定上吊", "deadly: asked first")
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "取消: nothing happens")
	hud._hang_with(rope)
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.process_frame
	_check(hud.log_lines().has("你把绳子一端挂好, 另一端往脖子上一套....."), "the line")
	_check(session.player_runtime().life_status == CharacterRuntimeLifeStatus.Value.DEAD, "and the player dies")


## The 迷阵 through its passages: the wind first; then 坤 west back into itself, the way on
## to 乾 and south out of it, marked.
func _test_maze(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(session.handoff_to(&"green.mountain", &"green.entrance", &"green.entrance", &"green.entrance.maze_return").succeeded(), "at the mountain road's end")
	await tree.physics_frame
	await tree.physics_frame
	var mountain: WorldMapController = session.active_map() as WorldMapController
	_check(not await MapPlaces.take_passage(tree, mountain, &"green.entrance.east", 240), "below 100000 the wind turns the player back")
	_check(player.world_location().zone_id == &"green.entrance" and hud.log_lines().has("你向石洞走去，忽然一阵狂风涌至，你抵受不住，只好退了回来"), "still at the road's end, told why")
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	_check(await MapPlaces.take_passage(tree, mountain, &"green.entrance.east"), "into the cave")
	var maze: WorldMapController = session.active_map() as WorldMapController
	_check(maze.map_id() == &"green.maze" and player.world_location().zone_id == &"green.eight0", "in 坤")
	_check(maze.select_landmark(&"green.eight0.landmark.sign"), "the 路牌")
	maze.inspect_selected()
	_check(hud.inspection_text.text.contains("坤为地，遇青龙而生"), "it reads 坤: " + hud.inspection_text.text)
	hud.dismiss_current_panel()
	await tree.physics_frame # the panel's movement quarantine ends with the frame
	await tree.physics_frame
	_check(await MapPlaces.take_same_map_passage(tree, maze, &"green.eight0.west"), "west: 白虎而困")
	_check(player.world_location().zone_id == &"green.eight0" and maze.spawn_matches_zone(&"green.eight0.east_arrival", &"green.eight0"), "back in 坤, from its east side")
	_check(hud.log_lines()[-1].begins_with("【迷阵】从这里向四周望去，只见一片无垠的绿野"), "the room again: " + hud.log_lines()[-1])
	for step: Array in [["green.eight0.east", "green.eight1"], ["green.eight1.north", "green.eight2"], ["green.eight2.west", "green.eight3"], ["green.eight3.east", "green.eight4"], ["green.eight4.north", "green.eight5"], ["green.eight5.west", "green.eight6"], ["green.eight6.north", "green.eight7"]]:
		_check(await MapPlaces.take_same_map_passage(tree, maze, StringName(step[0])), "%s" % step[0])
		_check(player.world_location().zone_id == StringName(step[1]), "on to %s" % step[1])
		var camera: Camera2D = maze.runtime_player_body().get_node("Camera2D") as Camera2D
		_check(camera.get_screen_center_position().distance_to(_clamped(camera, camera.get_target_position())) < 64.0, "the camera is where it should be at once (no glide across the map): %s" % step[1])
	hud.describe_arrival()
	_check(hud.log_lines()[-1].begins_with("【迷阵】从这里向四周望去，只见长天一碧"), "乾's own words (a 迷阵 room is distinct): " + hud.log_lines()[-1])
	_check(not player.state.marks.has("八卦阵"), "no mark yet")
	_check(await MapPlaces.take_passage(tree, maze, &"green.eight7.south"), "south out of 乾 (朱雀而生)")
	_check(session.active_map().map_id() == &"green.mountain" and player.world_location().zone_id == &"green.stoneroom", "in the east stone room")
	_check(player.state.marks.get("八卦阵", 0) == 1, "marked 八卦阵 (eight7.c valid_leave())")


## The stream's search, the secret door, the one-way ways and the hall's seal.
func _test_stone_rooms(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var door: WorldDoor = map.door(&"green.stoneroom.door")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"green.stoneroom.door", &"green.stoneroom")), "before the secret door")
	_check(door != null and map.open_door(&"green.stoneroom.door"), "the 密门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"green.water"), "out to the stream")
	_check(map.select_landmark(&"green.water.landmark.water"), "the water")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([1, 0])) # TEST-ONLY: found, then nothing
	map.traverse_selected_portal()
	_check(hud.log_lines().slice(-2) == ["你跳入溪水之中，开始仔细寻找....", "你竟从水中找出一把追风剑!"], "random(2) 1: the 追风剑: %s" % [hud.log_lines().slice(-2)])
	_check(not _carried(session, player.character_id, WINDSWORD).is_empty() and player.state.marks.get("八卦阵", 0) == 1, "in hand; the mark stays")
	map.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你在水中忙了半天，结果一无所获。" and not player.state.marks.has("八卦阵"), "random(2) 0: nothing, and the mark is gone")
	map.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你在水中忙了半天，结果一无所获。", "without it, nothing")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"green.water.west"), "west through the bushes")
	_check(player.world_location().zone_id == &"green.outdoor", "into the stone room behind the great door (one way)")
	var hall: WorldPhysicalZoneArea2D = map.physical_zone(&"green.cavehall")
	var room: Rect2 = map.physical_zone(&"green.outdoor").global_rect()
	map.runtime_player_body().global_position = Vector2(MapPlaces.doorway(map, &"green.outdoor", &"green.cavehall").x, room.position.y - 8) # TEST-ONLY: just past the edge
	_check(not map.accept_zone_presence(hall) and hud.log_lines()[-1] == "入口被魔法封住了！", "the hall's seal")
	player.state.apprenticeship.master_teacher_id = MASTER # TEST-ONLY: 绝尘子's apprentice
	map.runtime_player_body().global_position = Vector2(MapPlaces.doorway(map, &"green.outdoor", &"green.cavehall").x, room.position.y - 8)
	_check(map.accept_zone_presence(hall) and player.world_location().zone_id == &"green.cavehall", "an apprentice passes")
	player.state.apprenticeship.master_teacher_id = &""
	_check(await MapPlaces.drive_to_zone(tree, map, &"green.outdoor"), "back out (nothing keeps anyone in)")
	_check(not MapPlaces.doorway(map, &"green.cavehall", &"green.stoneroom").is_finite(), "no walk between the hall and the east room")


## 绝地: too weak to move the stone; the push and its roll; 放弃 wakes the player in the Inn.
func _test_closed(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(session.handoff_to(&"green.maze", &"green.eight0", &"green.eight0", &"green.eight0.west_arrival").succeeded(), "in 坤 again")
	await tree.physics_frame
	await tree.physics_frame
	var maze: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_same_map_passage(tree, maze, &"green.eight0.north"), "north: 玄武而死")
	hud.describe_arrival()
	_check(player.world_location().zone_id == &"green.closed" and hud.log_lines()[-1].begins_with("【绝地】这是一块绝地"), "in 绝地: %s" % hud.log_lines()[-1])
	for portal: PortalDefinition in GameContent.catalog().portals_for_map(&"green.maze"):
		_check(portal.source_zone_id != &"green.closed" or portal.portal_id in [&"green.closed.push", &"green.closed.give_up"], "no way out but the stone and giving up: %s" % portal.portal_id)
	_check(maze.select_landmark(&"green.closed.landmark.stone"), "the stone")
	maze.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你出力不太够喔！" and player.world_location().zone_id == &"green.closed", "too weak")
	player.state.recovery.inner_force = CharacterInternalResourceState.new(600, 600) # TEST-ONLY
	player.state.attributes.force_factor = 40
	player.state.vitality = CharacterResourceState.new(1000, 1000, 1000)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([1, 0])) # TEST-ONLY: not yet, then it rolls
	maze.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你用力推活动的大岩石,大岩石动了一下" and player.state.vitality.current == 940 and player.world_location().zone_id == &"green.closed", "a push: gin 20, kee 60, sen 20; random(3) 1, it holds")
	maze.traverse_selected_portal()
	await tree.physics_frame
	await tree.physics_frame
	_check(hud.log_lines().has("大岩石滚开了,你从大岩石后面的小洞钻了出去") and session.active_map().map_id() == &"green.mountain" and player.world_location().zone_id == &"green.entrance", "random(3) 0: out through the hole to the road's end")
	_check(session.handoff_to(&"green.maze", &"green.closed", &"green.closed", &"green.closed.arrival").succeeded(), "TEST-ONLY: back in 绝地")
	await tree.physics_frame
	await tree.physics_frame
	maze = session.active_map() as WorldMapController
	_check(maze.select_landmark(&"green.closed.landmark.fog"), "绝地 itself")
	maze.traverse_selected_portal()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map().map_id() == &"snow.inn" and player.world_location().zone_id == &"snow.inn.main_floor", "放弃: in the Inn, as ES2's quit and login")
	_check(hud.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("醒来时，你已经躺在雪亭镇的饮风客栈里")), "told so: %s" % [hud.log_lines().slice(-3)])


## Where a camera centred on `target` stands inside its limits.
func _clamped(camera: Camera2D, target: Vector2) -> Vector2:
	var half: Vector2 = camera.get_viewport_rect().size / camera.zoom / 2.0
	return Vector2(
		clampf(target.x, camera.limit_left + half.x, maxf(camera.limit_left + half.x, camera.limit_right - half.x)),
		clampf(target.y, camera.limit_top + half.y, maxf(camera.limit_top + half.y, camera.limit_bottom - half.y)),
	)


func _carried(session: OldPineWorldSessionController, character_id: StringName, definition_id: StringName) -> StringName:
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


## TEST-ONLY: a carried item.
func _give(session: OldPineWorldSessionController, definition_id: StringName) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, content.own_weight))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, destination).succeeded)
	return item.item_instance_id


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
