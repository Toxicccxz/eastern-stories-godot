extends RefCounted

## 晚月庄 A (d/latemoon): all 74 rooms on five maps — the halls, the two secret rooms
## (one way in from 内厅穿堂), the 湘园, the front tower's upper floor, the paths and the
## bamboo grove beyond the back gate (sroad1.c repaired: owner, plan Q1) — and the way in
## from 绮云镇's west end; the fourteen doors, shut as create_door() leaves them; the
## look-only things; the dances in the two 密室 (the dances the player heard named, one of
## their own; a dance that would knock them out asked first); no_drop. Walks use the move
## actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {
	&"latemoon.manor": 36, &"latemoon.secret": 2, &"latemoon.garden": 16, &"latemoon.upper": 10, &"latemoon.hills": 10,
}
const DOORS: Array[StringName] = [
	&"latemoon.entrance.door", &"latemoon.latemoon4.door", &"latemoon.latemoon5.door", &"latemoon.latemoon7.door",
	&"latemoon.room.twoc.door", &"latemoon.room.eroad1.door", &"latemoon.room.wroad2.door", &"latemoon.room.corridor7.door",
	&"latemoon.room.flower1.door", &"latemoon.miroom2.door", &"latemoon.upstar.upcenter.door", &"latemoon.upstar.upstar4.door",
	&"latemoon.upstar.upstar3.door", &"latemoon.upstar.upstarc.door",
]
const OUT_LINE: String = "你在卦象中跳起舞来..一曲「 西出阳关 」突然..."
const CLUMSY: String = "你在卦象中跳起舞来。但似乎不得要领！"
const TIRED: String = "你现在的神太少了，无法专注跳出舞步！"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_waiting()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_way_in(tree, session)
	await _test_halls(tree, session)
	await _test_dances(tree, session)
	await _test_paths(tree, session)
	await _test_garden(tree, session)
	await _test_tower(tree, session)
	await _test_secret_rooms(tree, session)
	_test_no_drop(session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("latemoon."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "74 rooms on five maps: %s" % maps)
	var sroad1: RoomDefinition = catalog.room(&"es2:d/latemoon/sroad1")
	_check(sroad1 != null and sroad1.exits().get("north") == &"es2:d/latemoon/park/moondoor" and sroad1.exits().get("southeast") == &"es2:d/latemoon/sroad2", "sroad1.c repaired: north to the back gate, south-east down the path")
	for door: StringName in DOORS:
		_check(catalog.door(door) != null and not catalog.door(door).starts_open, "%s: DOOR_CLOSED" % door)
	_check(catalog.door(&"latemoon.room.eroad1.door").display_name == "雕饰厢门", "the east wing's door named from the corridor")
	var west: PortalDefinition = catalog.portal(&"cloud.wroad0.west")
	_check(west != null and west.destination_zone_id == &"latemoon.entrance" and catalog.portal(&"latemoon.entrance.east").destination_zone_id == &"cloud.wroad0", "绮云镇's west end to the cobbled path, and back")
	_check(catalog.portal(&"latemoon.room.flower1.south") != null and catalog.portal(&"latemoon.miroom2.north") == null, "into the secret rooms one way (miroom2.c has no north exit)")
	_check(catalog.portal(&"latemoon.bamboo1.west").destination_zone_id == &"latemoon.bamboo1", "bamboo1's west leads back into itself")
	var picture: WorldLandmarkDefinition = catalog.landmark(&"latemoon.latebook.landmark.picture")
	_check(picture.policy == &"look" and picture.teaches == ["dance_out", "dance_yu_fong"], "the 湘绣舞曲图 names both dances")
	var floor_8: DanceDefinition = catalog.service(&"latemoon.latemoon8.dance").dance
	_check(floor_8.steps.size() == 2 and floor_8.cost_for("男性").at_least == 100 and floor_8.cost_for("女性").sen == 30 and floor_8.steps[0].sen == 50, "latemoon8.c: 男 100/50, 女 50/30; 有凤来仪 50 more")
	var floor_mi: DanceDefinition = catalog.service(&"latemoon.miroom.dance").dance
	_check(floor_mi.steps.size() == 1 and floor_mi.cost_for("男性").sen == 80 and floor_mi.cost_for("女性").sen == 50, "miroom.c: only 西出阳关; 男 100/80, 女 50/50")
	_check(catalog.service(&"latemoon.latemoon3.tea").kind == &"water" and catalog.service(&"latemoon.room.bathroom.pool").kind == &"water", "resource/water: the teapot, the pool")


## Reminders: what 晚月庄 B, C and D port is not there yet. Each check fails once its
## package lands, which must replace it with the real one.
func _test_waiting() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# B: the women's quarters and the rooms' own commands.
	for id: StringName in [&"latemoon.npc.room.shinyu", &"latemoon.npc.room.shaoin", &"latemoon.npc.room.yuchoun", &"latemoon.npc.room.yushou", &"latemoon.npc.room.fireangel", &"latemoon.npc.upstar.statue"]:
		_check(not catalog.npc(id).talk().has_greeting(), "B waits: %s's greeting() (kick, powder, closing the door, the stare)" % id)
	_check(catalog.landmark(&"latemoon.park.moonc.landmark.flower").policy == &"look" and catalog.landmark(&"latemoon.latemoon2.landmark.closet").policy == &"look", "B waits: pick flower, take cloth")
	_check(catalog.exit_rules_between(&"latemoon.room.bathroom1", &"latemoon.room.flower1").is_empty(), "B waits: the changing room's powder (valid_leave)")
	_check(not catalog.item(&"es2:d/latemoon/obj/skirt").female_only, "B waits: the skirts' own wear() (only a 女性)")
	# C: the secrets.
	for id: StringName in [&"latemoon.npc.funlin", &"latemoon.npc.shaowei", &"latemoon.npc.room.old"]:
		_check(catalog.npc(id).dealings().object_rules.is_empty(), "C waits: %s's accept_object()" % id)
	_check(not catalog.npc(&"latemoon.npc.upstar.shinfun").talk().inquiry_topics().has("舞曲谱"), "C waits: 莫欣芳's 舞曲谱")
	# D: 晚月庄.
	_check(catalog.npc(&"common.npc.dancer.master").teaching().apprentice == null and catalog.npc(&"latemoon.npc.room.elon").teaching().apprentice == null, "D waits: 蓝止萍's and 瑷伦's attempt_apprentice()")


func _test_way_in(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.wroad0", &"cloud.wroad0", &"cloud.wroad0.latemoon_return").succeeded(), "at 绮云镇's west end")
	var cloud: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, cloud, &"cloud.wroad0.west"), "west onto the cobbled path")
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(map.map_id() == &"latemoon.manor" and session.player_runtime().world_location().zone_id == &"latemoon.entrance", "the cobbled path")
	_check(not await MapPlaces.drive_to_zone(tree, map, &"latemoon.gate"), "the arch is shut")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.entrance.door", &"latemoon.entrance")) and map.open_door(&"latemoon.entrance.door"), "the arch opens")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.gate", &"latemoon.front_yard", &"latemoon.latemoon1"]), "past the lanterns, through the front garden into the hall")
	_check(Work.capture(session) != null, "Save in the hall")
	map.select_landmark(&"latemoon.gate.landmark.lantern")


func _test_halls(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.latemoon3", &"latemoon.latemoon1", &"latemoon.latemoonc", &"latemoon.latemoon7", &"latemoon.latebook"]), "the reception room, the plum courtyard, the gallery, the study")
	_check(session.player_runtime().state.marks.get("dance_out", 0) == 0, "no dance known yet")
	_check(map.select_landmark(&"latemoon.latebook.landmark.picture"), "the 湘绣舞曲图")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("『西出阳关』"), "its text: %s" % hud.inspection_text.text)
	hud.dismiss_current_panel()
	var marks: Dictionary[String, int] = session.player_runtime().state.marks
	_check(marks.get("dance_out", 0) == 1 and marks.get("dance_yu_fong", 0) == 1, "looking at it, both dances are known")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon7"), "back to the gallery")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.latemoon7.door", &"latemoon.latemoon7")) and map.open_door(&"latemoon.latemoon7.door"), "the stone door opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon8"), "into the 密室")


func _test_dances(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	var floor_8: DanceService = map.service(&"latemoon.latemoon8.dance") as DanceService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"latemoon.latemoon8.dance")) and floor_8.in_reach(), "on the 八卦图")
	var names: Array[String] = []
	for step: DanceDefinition.Step in floor_8.known_steps():
		names.append(step.name)
	_check(names == ["有凤来仪", "西出阳关"], "both dances offered: %s" % [names])
	state.spirit = CharacterResourceState.new(40, 200, 200) # TEST-ONLY: a woman needs 50
	var refused: DanceDefinition.Result = floor_8.dance(null)
	_check(refused.refused and hud.log_lines()[-1] == TIRED and state.spirit.current == 40, "too tired: refused, nothing spent")
	state.spirit = CharacterResourceState.new(150, 200, 200) # TEST-ONLY
	var clumsy: DanceDefinition.Result = floor_8.dance(null)
	_check(not clumsy.refused and clumsy.portal_id.is_empty() and hud.log_lines()[-1] == CLUMSY and state.spirit.current == 120, "a dance of one's own: 不得要领, and the 30 sen are gone")
	state.spirit = CharacterResourceState.new(60, 200, 200) # TEST-ONLY: 30 + 50 would take 60 below 0
	floor_8.choose(floor_8.known_steps()[0])
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("80 点神"), "有凤来仪 would knock her out: asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not hud.is_asking() and state.spirit.current == 60 and session.active_map_id() == &"latemoon.manor", "取消: nothing danced")
	state.spirit = CharacterResourceState.new(150, 200, 200) # TEST-ONLY
	floor_8.choose(floor_8.known_steps()[0])
	await tree.process_frame
	_check(session.active_map_id() == &"latemoon.secret" and session.player_runtime().world_location().zone_id == &"latemoon.miroom" and state.spirit.current == 70, "「有凤来仪」: 30 + 50 sen, into the other 密室")
	var secret: WorldMapController = session.active_map() as WorldMapController
	var floor_mi: DanceService = secret.service(&"latemoon.miroom.dance") as DanceService
	_check(await MapPlaces.drive(tree, secret, MapPlaces.service_spot(secret, &"latemoon.miroom.dance")) and floor_mi.known_steps().size() == 1, "its 八卦图: only 西出阳关")
	floor_mi.choose(floor_mi.known_steps()[0])
	await tree.process_frame
	_check(session.active_map_id() == &"latemoon.hills" and session.player_runtime().world_location().zone_id == &"latemoon.bamboo" and state.spirit.current == 20, "「西出阳关」: 50 sen, out into the bamboo grove")
	_check(hud.log_lines().has(OUT_LINE), "its line")


func _test_paths(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	session.player_runtime().state.spirit = CharacterResourceState.new(200, 200, 200) # TEST-ONLY
	_check(await MapPlaces.take_same_map_passage(tree, map, &"latemoon.bamboo.west"), "west: into another clearing")
	_check(session.player_runtime().world_location().zone_id == &"latemoon.bamboo2", "bamboo.c west is bamboo2")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"latemoon.bamboo2.north"), "north")
	_check(session.player_runtime().world_location().zone_id == &"latemoon.bamboo3", "bamboo2.c north is bamboo3, by the path")
	_check(Work.capture(session) != null, "Save in the bamboo grove")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.sroad5", &"latemoon.sroad4", &"latemoon.sroad3", &"latemoon.sroad2", &"latemoon.sroad1"]), "up the path to the back gate")
	_check(await MapPlaces.take_passage(tree, map, &"latemoon.sroad1.north"), "through the back gate")
	_check(session.active_map_id() == &"latemoon.garden" and session.player_runtime().world_location().zone_id == &"latemoon.park.moondoor", "into the 湘园")
	_check(Work.capture(session) != null, "Save in the 湘园")


func _test_garden(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.park.paroad1", &"latemoon.park.bridge2", &"latemoon.park.pavilion1", &"latemoon.park.bridge1", &"latemoon.park.moonc"]), "over the bridges and through the pavilion to 翠嶂")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.park.moon2", &"latemoon.park.moon5", &"latemoon.park.moon3", &"latemoon.park.moroom"]), "the osmanthus garden to 紫翎小轩")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.park.moon3", &"latemoon.park.paroad2", &"latemoon.park.bridge2", &"latemoon.park.paroad1", &"latemoon.park.moon4"]), "稻香榭, the bridge and 暖香榭")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.park.bridge3", &"latemoon.park.moon1", &"latemoon.park.moonc", &"latemoon.park.flower2", &"latemoon.park.yard1"]), "the vermilion bridge, the rockery tunnel, the moon gate, the forecourt")
	_check(await MapPlaces.take_passage(tree, map, &"latemoon.park.yard1.north"), "north to the front garden")
	_check(session.active_map_id() == &"latemoon.manor" and session.player_runtime().world_location().zone_id == &"latemoon.front_yard", "back in the front garden")


func _test_tower(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.latemoon1", &"latemoon.latemoonc", &"latemoon.latemoon4", &"latemoon.room.twoc"]), "through the hall and the 穿堂 to the 仪门")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.twoc.door", &"latemoon.room.twoc")) and map.open_door(&"latemoon.room.twoc.door"), "the rear hall's door opens")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.room.lcenter", &"latemoon.room.lroad3"]), "the rear hall, its west corridor")
	_check(await MapPlaces.take_passage(tree, map, &"latemoon.room.lroad3.northup"), "up the stairs")
	var upper: WorldMapController = session.active_map() as WorldMapController
	_check(upper.map_id() == &"latemoon.upper", "the front tower's upper floor")
	_check(Work.capture(session) != null, "Save upstairs")
	_check(await MapPlaces.drive_through(tree, upper, [&"latemoon.upstar.upstar4", &"latemoon.upstar.upstarc"]), "along the gallery to the 前堂楼")
	_check(await MapPlaces.drive(tree, upper, MapPlaces.door_spot(upper, &"latemoon.upstar.upstarc.door", &"latemoon.upstar.upstarc")) and upper.open_door(&"latemoon.upstar.upstarc.door"), "the tower door opens")
	_check(await MapPlaces.drive_to_zone(tree, upper, &"latemoon.upstar.uplook"), "onto the 观景台")
	_check(await MapPlaces.take_passage(tree, upper, &"latemoon.upstar.uplook.jump"), "jump")
	_check(session.active_map_id() == &"latemoon.garden" and session.player_runtime().world_location().zone_id == &"latemoon.park.yard1", "down into the 湘园's forecourt")
	var garden: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, garden, &"latemoon.park.yard1.north"), "north again")


func _test_secret_rooms(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.latemoon1", &"latemoon.latemoonc", &"latemoon.latemoon4", &"latemoon.room.twoc", &"latemoon.room.lcenter", &"latemoon.room.lroad3", &"latemoon.room.wroad1", &"latemoon.room.wroad2", &"latemoon.room.corridor7"]), "round to the 内厅")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.corridor7.door", &"latemoon.room.corridor7")) and map.open_door(&"latemoon.room.corridor7.door"), "the 垂花门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.flower1"), "the women's passage")
	_check(await MapPlaces.take_passage(tree, map, &"latemoon.room.flower1.south"), "south")
	var secret: WorldMapController = session.active_map() as WorldMapController
	_check(secret.map_id() == &"latemoon.secret" and session.player_runtime().world_location().zone_id == &"latemoon.miroom2", "the inner hall of the secret rooms (筱薇's)")
	_check(MapPlaces.passage(secret, &"latemoon.miroom2.north") == null, "no way back north")
	_check(await MapPlaces.drive(tree, secret, MapPlaces.door_spot(secret, &"latemoon.miroom2.door", &"latemoon.miroom2")) and secret.open_door(&"latemoon.miroom2.door"), "the 垂花门 opens")
	_check(await MapPlaces.drive_to_zone(tree, secret, &"latemoon.miroom"), "into the second 密室")
	_check(Work.capture(session) != null, "Save in the secret rooms")


## drop.c, give.c, put.c: set("no_drop") refuses each.
func _test_no_drop(session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hankie: StringName = map.give_new_item_to_player(&"es2:d/latemoon/obj/hankie") # TEST-ONLY: the 丝罗巾 lying in the 密室
	var dropped: ItemHandlingResult = map.floor_items.drop_item(hankie)
	_check(not dropped.done() and dropped.lines == ["这样东西不能随意丢弃。"], "drop.c: 这样东西不能随意丢弃。")


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
