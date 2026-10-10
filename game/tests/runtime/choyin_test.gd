extends RefCounted

## 乔阴 A (d/choyin): sixty-one rooms on fourteen maps — the town, the 县府衙门's courts, the
## temple's terrace and the 福林楼's floors, the hollow under the 树王坟 and the 西大街's lion
## cave, the east (桐柏山, 云梦大泽, the hermit's hall and the furnace) and 姑射山 with the rooms
## only its verbs reach (乔阴 B) — the way in from 泓水南岸's foot of the hill (the 北门's
## north stays shut, as ES2), the gates and stairs, the well (drink, fill), the 桃林 behind
## 骆云舟 (no_mark), the vendors' lists, the crone's relay_ask() (owner: said as meant). Walks
## use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {
	&"choyin.town": 30, &"choyin.yamen_compound": 3, &"choyin.temple_altar": 1, &"choyin.hotel_2f": 1, &"choyin.hotel_3f": 1,
	&"choyin.tree_hollow": 3, &"choyin.lion_cave": 1, &"choyin.east": 10, &"choyin.furnace": 1, &"choyin.guye": 3,
	&"choyin.crown": 1, &"choyin.cliff_cave": 1, &"choyin.summit": 1, &"choyin.valley": 4,
}
## Each map's way in for the handoff check: zone and spawn point.
const ENTRIES: Dictionary = {
	&"choyin.yamen_compound": [&"choyin.yamen", &"choyin.yamen.hall_entry"],
	&"choyin.tree_hollow": [&"choyin.tomb1", &"choyin.tomb1.hole_arrival"],
	&"choyin.lion_cave": [&"choyin.lionroom", &"choyin.lionroom.fall_arrival"],
	&"choyin.furnace": [&"choyin.stove", &"choyin.stove.platform_arrival"],
	&"choyin.crown": [&"choyin.craneroom", &"choyin.craneroom.climb_arrival"],
	&"choyin.cliff_cave": [&"choyin.halfhole", &"choyin.halfhole.vine_arrival"],
	&"choyin.summit": [&"choyin.platform", &"choyin.platform.crane_arrival"],
	&"choyin.valley": [&"choyin.hollow", &"choyin.hollow.fall_arrival"],
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_way_in(tree, session)
	await _test_main_street(tree, session)
	await _test_well(tree, session)
	await _test_talk(tree, session)
	await _test_taolin(tree, session)
	await _test_floors(tree, session)
	await _test_outskirts(tree, session)
	await _test_unreached_maps(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("choyin."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "61 rooms on fourteen maps: %s" % maps)
	_check(catalog.zone_of_room(&"es2:d/choyin/stonehole") == null, "the 石室 has no way in: not placed")
	_check(catalog.region(&"choyin").display_name == "乔阴县城" and catalog.region(&"choyin_east").display_name == "乔阴东郊" and catalog.region(&"guye").display_name == "姑射山", "乔阴县城, 乔阴东郊, 姑射山")
	_check(catalog.portal(&"sunhill.road1.east").destination_zone_id == &"choyin.n_gate" and catalog.portal(&"choyin.n_gate.west").destination_zone_id == &"sunhill.road1", "the foot of the hill east to the 北门, and back")
	var north: Array[PortalDefinition] = []
	for portal: PortalDefinition in catalog.portals_for_map(&"choyin.town"):
		if portal.source_zone_id == &"choyin.n_gate" and portal.legacy_command == "north":
			north.append(portal)
	_check(north.is_empty() and not catalog.room(&"es2:d/choyin/n_gate").exits().has("north"), "the 北门's road north goes nowhere (both ends commented out in ES2; owner: as ES2)")
	_check(catalog.portal(&"choyin.yamen_yard.south").destination_zone_id == &"choyin.court1" and catalog.room(&"es2:d/choyin/court1").exits().keys() == ["south"], "the 衙门's courts lead out to its gate, none lead in (court1.c has no north)")
	_check(catalog.portal(&"choyin.tomb1.up").destination_zone_id == &"choyin.tree_tomb", "the hollow climbs back up to the 树王坟 (the way down is 乔阴 B)")
	var rule: ZoneExitRuleDefinition = catalog.exit_rules_between(&"choyin.entrance", &"choyin.taolin")[0]
	var stranger := ZoneExitRuleDefinition.Leaver.new()
	var asked := ZoneExitRuleDefinition.Leaver.new()
	asked.marks = {"书生": 1}
	_check(rule.refuses(stranger, false) and not rule.refuses(asked, false) and rule.lines == ["东行的道路被骆云舟挡住了."], "east into the 桃林 only with marks/书生")
	for id: StringName in [&"choyin.yamen.door", &"choyin.fence.door", &"choyin.club.door"]:
		_check(catalog.door(id) != null and not catalog.door(id).starts_open, "%s shut" % id)
	var statue: WorldLandmarkDefinition = catalog.landmark(&"choyin.w_street1.landmark.statue")
	_check(statue.policy == &"lift" and statue.description.contains("「举」字") and not statue.description.contains("□"), "the stone lion's 「举」 (默认), lifted (乔阴 B)")
	_check(catalog.service(&"choyin.s_street1.well").kind == &"water" and catalog.service(&"choyin.cloudpool.water").kind == &"water", "the well and the marsh fill a wineskin")
	var soul: NpcSpawnDefinition = catalog.spawn(&"choyin.town.entrance.sword_soul")
	_check(soul != null and soul.summoned and soul.npc_definition_id == &"common.npc.scholar.sword_soul", "风泉剑灵 waits absent by 骆云舟")
	for id: StringName in [&"es2:d/choyin/obj/denotation"]:
		_check(catalog.item(id).max_encumbrance == 10000 and catalog.item(id).no_get, "the 功德箱 takes donations (insert_object() never runs)")


## 泓水南岸: east from the foot of the hill to the 北门.
func _test_way_in(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"sunhill.mountain", &"sunhill.road1", &"sunhill.road1", &"sunhill.road1.choyin_return").succeeded(), "at the foot of the hill")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, map, &"sunhill.road1.east"), "east to 乔阴")
	var town: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(town.map_id() == &"choyin.town" and location.zone_id == &"choyin.n_gate", "the 北门: %s" % location.zone_id)
	_check(session.place_name(location) == "乔阴县城 · 乔阴县城北门", "乔阴县城 · 乔阴县城北门: %s" % session.place_name(location))
	_check(Work.capture(session) != null, "Save at the 北门")
	_check(await MapPlaces.take_passage(tree, town, &"choyin.n_gate.west"), "west back to 泓水南岸")
	_check(session.active_map_id() == &"sunhill.mountain" and session.player_runtime().world_location().zone_id == &"sunhill.road1", "the foot of the hill")
	map = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, map, &"sunhill.road1.east"), "and into the town again")


## The 福林大街 south round the 树王坟 to the 南门广场; the 西大街 and the 东大街.
func _test_main_street(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.n_street1", &"choyin.n_street2", &"choyin.n_street3", &"choyin.tree_tomb"]), "down the 福林大街 to the 树王坟")
	_check(map.select_landmark(&"choyin.tree_tomb.landmark.hole"), "the hole in the stump")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("这个洞连人也进得去"), "这个洞连人也进得去: %s" % hud.inspection_text.text.left(30))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.w_street3", &"choyin.w_street2", &"choyin.w_street1"]), "west along the 西大街 to the stone lion")
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.w_street2", &"choyin.w_street4", &"choyin.nw_street", &"choyin.n_street3", &"choyin.tree_tomb", &"choyin.e_street1", &"choyin.e_gate"]), "round the flagstones and east to the 东城门")
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.e_street1", &"choyin.tree_tomb", &"choyin.s_street3", &"choyin.s_street2", &"choyin.s_street1"]), "south to the 南门广场")
	_check(session.place_name(session.player_runtime().world_location()) == "乔阴县城 · 南门广场", "the square")


## s_street1.c do_drink(): below the capacity the cup's line and water + 20; full, its refusal.
func _test_well(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var drink: ActService = map.service(&"choyin.s_street1.drink") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"choyin.s_street1.drink")) and drink.in_reach(), "by the well")
	var capacity: int = CharacterRecovery.maximum_water_capacity(player.body_facts.body_weight)
	player.state.recovery.water = capacity - 5 # TEST-ONLY: a little thirsty
	drink.interact()
	_check(hud.log_lines()[-1] == "你在井边用杯子舀起井水喝了几口。" and player.state.recovery.water == capacity + 15, "a few sips: + 20 (add(), past the capacity): %d" % player.state.recovery.water)
	drink.interact()
	_check(hud.log_lines()[-1] == "你已经再也喝不下一滴水了。" and player.state.recovery.water == capacity + 15, "full: not a drop more")
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"choyin.s_street1.well")) and (map.service(&"choyin.s_street1.well") as WaterService).available(), "the well fills a wineskin too")


## The vendors' (: do_vendor_list :) topics write their goods; the crone answers her three
## topics and to any other says she is deaf (owner: relay_ask() as meant).
func _test_talk(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var seller: NpcRuntimeState = _npc(map, &"choyin.npc.cucurbit_seller")
	_check(seller != null and map.select_npc(seller.character_id), "the 糖葫芦 seller")
	var said: Array[String] = map.ask_selected("糖葫芦")
	_check(said == ["你向卖糖葫芦的打听有关『糖葫芦』的消息。", "你可以购买下列这些东西：", "糖葫芦：40文钱"], "his list: %s" % [said])
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.sw_road1", &"choyin.dragon_temple"]), "along the lake into the 火龙将军庙")
	var crone: NpcRuntimeState = _npc(map, &"choyin.npc.crone")
	_check(crone != null and map.select_npc(crone.character_id), "the crone")
	_check(map.ask_selected("年龄").has("乾瘪老太婆说道：老身今年七十有八啦。"), "her age")
	said = map.ask_selected("名字")
	_check(said.size() == 3 and said[1].begins_with("乾瘪老太婆说道：对不起，老婆子耳背，") and said[1].ends_with("您是想买东西吧？这儿有价钱 ....") and said[2] == "老太婆打开竹篓，盖子上贴了张纸片。", "deaf to her name: %s" % [said])
	var vendor: VendorDefinition = GameContent.catalog().vendor(crone.definition().dealings().vendor_id)
	_check(vendor.goods_keys().size() == 2 and vendor.item_definition_id("amulet") == &"es2:d/choyin/obj/amulet" and vendor.item_definition_id("red guay") == &"es2:d/choyin/npc/obj/red_guay", "平安符 and 红龟")
	_check(GameContent.catalog().item(&"es2:d/choyin/npc/obj/red_guay").display_name == "红龟", "红龟 (the room copy's 红龟□ is npc/obj's 红龟)")


## entrance.c valid_leave(): east only with marks/书生, which 骆云舟 gives; the 桃林's ways
## are choyin_school_test's.
func _test_taolin(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.sw_road1", &"choyin.s_street1", &"choyin.bridge1", &"choyin.bridge2", &"choyin.bridge3", &"choyin.bridge4", &"choyin.bridge5", &"choyin.entrance"]), "over the zigzag bridge to the 曼雩台")
	_check(_npc(map, &"common.npc.scholar.master").world_location().zone_id == &"choyin.entrance", "骆云舟 on the 曼雩台")
	_check(not await MapPlaces.take_same_map_passage(tree, map, &"choyin.entrance.east", 240), "the path east does not take the player")
	_check(player.world_location().zone_id == &"choyin.entrance" and hud.log_lines().has("东行的道路被骆云舟挡住了.") and not player.state.counters.has("taolin_steps"), "东行的道路被骆云舟挡住了.")
	player.state.marks["书生"] = 1 # TEST-ONLY: as 骆云舟's refusal does
	_check(await MapPlaces.take_same_map_passage(tree, map, &"choyin.entrance.east"), "with the mark, into the peach grove")
	_check(player.world_location().zone_id == &"choyin.taolin" and player.state.counters.get("taolin_steps", 0) == 3, "in the 桃林, the way out three steps off")
	# TEST-ONLY: back on the 曼雩台 without walking the grove.
	player.state.marks.erase("书生")
	player.state.counters.erase("taolin_steps")
	_check(map.relocate_player(&"choyin.entrance", &"choyin.entrance.grove_return"), "TEST-ONLY: back on the 曼雩台")
	await tree.physics_frame
	await tree.physics_frame


## The temple's terrace and the 福林楼's two floors.
func _test_floors(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.bridge5", &"choyin.bridge4", &"choyin.bridge3", &"choyin.bridge2", &"choyin.bridge1", &"choyin.s_street1", &"choyin.sw_road1", &"choyin.dragon_temple"]), "back to the temple")
	_check(await MapPlaces.take_passage(tree, map, &"choyin.dragon_temple.up"), "up the stairs")
	var altar: WorldMapController = session.active_map() as WorldMapController
	_check(altar.map_id() == &"choyin.temple_altar" and _npc(altar, &"choyin.npc.lady") != null, "the terrace, the lady praying")
	_check(await MapPlaces.take_passage(tree, altar, &"choyin.altar.down"), "down again")
	map = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.sw_road1", &"choyin.s_street1", &"choyin.s_street2", &"choyin.hotel1"]), "into the 福林楼")
	_check(_npc(map, &"choyin.npc.boss") != null and _npc(map, &"choyin.npc.sergeant") != null, "汤掌柜 and the 武官")
	_check(await MapPlaces.take_passage(tree, map, &"choyin.hotel1.up"), "upstairs")
	var second: WorldMapController = session.active_map() as WorldMapController
	_check(second.map_id() == &"choyin.hotel_2f" and _npc(second, &"choyin.npc.youngman") != null, "the 雅座, the young gentleman")
	_check(await MapPlaces.take_passage(tree, second, &"choyin.hotel2.up"), "up to the guest rooms")
	var third: WorldMapController = session.active_map() as WorldMapController
	var guards: int = 0
	for npc: NpcRuntimeState in third.resident_npcs():
		if npc.definition().definition_id == &"choyin.npc.guard":
			guards += 1
	_check(third.map_id() == &"choyin.hotel_3f" and guards == 3, "three 酒楼守卫: %d" % guards)
	_check(Work.capture(session) != null, "Save on the third floor")
	_check(await MapPlaces.take_passage(tree, third, &"choyin.hotel3.down"), "down")
	second = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, second, &"choyin.hotel2.down"), "down to the hall")
	_check(session.player_runtime().world_location().zone_id == &"choyin.hotel1", "the hall")


## East of the 东城门 to the marsh, the 青石峪 and the hermit's hall; south of the 南门 to
## the 绝壁.
func _test_outskirts(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.s_street2", &"choyin.s_street3", &"choyin.tree_tomb", &"choyin.e_street1", &"choyin.e_gate"]), "to the 东城门")
	_check(await MapPlaces.take_passage(tree, map, &"choyin.e_gate.east"), "out of the gate")
	var east: WorldMapController = session.active_map() as WorldMapController
	_check(east.map_id() == &"choyin.east" and session.player_runtime().world_location().zone_id == &"choyin.solidpath1", "the yellow-earth road")
	_check(await MapPlaces.drive_through(tree, east, [&"choyin.rockpath2", &"choyin.rockpath1", &"choyin.rockyu", &"choyin.tongbhill"]), "up to 桐柏山")
	_check(await MapPlaces.drive_through(tree, east, [&"choyin.rockyu", &"choyin.fence"]), "down into the bamboo")
	_check(await MapPlaces.drive(tree, east, MapPlaces.door_spot(east, &"choyin.fence.door", &"choyin.fence")) and east.open_door(&"choyin.fence.door"), "the wicket gate opens")
	_check(await MapPlaces.drive_to_zone(tree, east, &"choyin.club"), "the thatched hall")
	_check(east.select_landmark(&"choyin.club.landmark.books"), "the books on the low table")
	session.shared_ui().dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive_through(tree, east, [&"choyin.fence", &"choyin.rockyu", &"choyin.rockpath1", &"choyin.rockpath2", &"choyin.solidpath1"]), "back to the road")
	_check(await MapPlaces.take_passage(tree, east, &"choyin.solidpath1.west"), "back through the 东城门")
	map = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.e_street1", &"choyin.tree_tomb", &"choyin.s_street3", &"choyin.s_street2", &"choyin.s_street1", &"choyin.s_street4", &"choyin.s_street5", &"choyin.crossroad", &"choyin.court1"]), "west along the 承安街 to the 衙门's gate")
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.crossroad", &"choyin.s_gate"]), "the 南门")
	_check(await MapPlaces.take_passage(tree, map, &"choyin.s_gate.south"), "out of the 南门")
	var guye: WorldMapController = session.active_map() as WorldMapController
	_check(guye.map_id() == &"choyin.guye" and await MapPlaces.drive_through(tree, guye, [&"choyin.rockroad", &"choyin.guyehill"]), "up to the 绝壁")
	_check(session.place_name(session.player_runtime().world_location()) == "姑射山 · 绝壁", "姑射山 · 绝壁")
	_check(guye.select_landmark(&"choyin.guyehill.landmark.vine"), "the vines (hold is 乔阴 B)")
	session.shared_ui().dismiss_current_panel()
	await tree.physics_frame
	_check(Work.capture(session) != null, "Save under the cliff")


## The rooms only verbs reach (乔阴 B, C, D) are drawn: each map takes the player.
func _test_unreached_maps(tree: SceneTree, session: WorldSessionController) -> void:
	for map_id: StringName in ENTRIES:
		var entry: Array = ENTRIES[map_id]
		_check(session.handoff_to(map_id, entry[0], entry[0], entry[1]).succeeded(), "onto %s" % map_id)
		await tree.physics_frame
		_check(session.active_map_id() == map_id and session.player_runtime().world_location().zone_id == entry[0], "%s: in %s" % [map_id, entry[0]])
		_check(Work.capture(session) != null, "Save on %s" % map_id)


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("choyin: " + message)
