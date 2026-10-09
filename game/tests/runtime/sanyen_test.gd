extends RefCounted

## 山烟寺 A (u/cloud/sunhill, d/sanyen): all 26 rooms on two maps — the ford across 泓水
## and 日照山 up to the 山门 and the tunnel, and the temple inside its gate — the ways in
## from 江北渡口 (waded, as ES2's river was) and from 晚月庄's tunnel; the boatman's boat
## (owner, plan Q1: his fare takes the payer to 江南渡口); the 金门, open as the road side
## leaves it; the plaques, the pot and the steamer (open, take: refused while the cook is
## there, five a reset). Walks use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"sunhill.mountain": 13, &"sanyen.grounds": 13}
const COIN: StringName = &"es2:obj/money/coin"
const MAINTAL: StringName = &"es2:d/sanyen/obj/maintal"
const COOK: StringName = &"sanyen.npc.cook_bonze"
const FARE_LINES: Array[String] = ["船夫说：客官可以过江啦！", "船夫拉过条小船，你走了上去。"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_ferry(tree, session)
	await _test_ford(tree, session)
	await _test_climb(tree, session)
	await _test_temple(tree, session)
	await _test_kitchen(tree, session)
	await _test_tunnel(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("sanyen.") or String(zone.zone_id).begins_with("sunhill."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "26 rooms on two maps: %s" % maps)
	_check(catalog.region(&"sunhill").display_name == "日照山" and catalog.region(&"sanyen").display_name == "山烟寺", "日照山 and 山烟寺")
	var south: PortalDefinition = catalog.portal(&"cloud.dukou.south")
	_check(south != null and south.destination_zone_id == &"sunhill.northriver" and catalog.portal(&"sunhill.northriver.north").destination_zone_id == &"cloud.dukou", "江北渡口 into the river, and back")
	_check(catalog.portal(&"latemoon.sroad5.east").destination_zone_id == &"sanyen.tunnel" and catalog.portal(&"sanyen.tunnel.west").destination_zone_id == &"latemoon.sroad5", "晚月庄's tunnel opens both ways")
	_check(catalog.zone_of_room(&"es2:d/choyin/n_gate") == null, "乔阴县城's north gate waits for #9")
	var gold_door: DoorDefinition = catalog.door(&"sanyen.road1.door")
	_check(gold_door != null and gold_door.display_name == "金门" and gold_door.starts_open, "the 金门 open (road1.c creates it so; 两扇敞开的金门)")
	var yard: Array[NpcSpawnDefinition] = []
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if spawn.zone_id == &"sanyen.front_yard":
			yard.append(spawn)
	_check(yard.size() == 1 and yard[0].npc_definition_id == &"cloud.npc.monk_guard" and yard[0].legacy_quantity == 2, "front_yard.c repaired: two 护寺武僧 (owner, plan Q2)")
	var steamer: WorldLandmarkDefinition = catalog.landmark(&"sanyen.kitchen.landmark.steampot")
	_check(steamer.policy == &"take" and steamer.setting("limit") == 5 and steamer.guard_npc_id == COOK and steamer.item("reward") == MAINTAL, "the steamer: five 馒头 a reset, the cook guards it")
	var plaque: WorldLandmarkDefinition = catalog.landmark(&"sanyen.heal_room.landmark.plaque")
	_check(plaque.policy == &"look" and plaque.description.contains("妙  手  回  春") and plaque.description.contains("克某某") and not plaque.description.contains("□"), "the plaques, word for word; the lost name 克某某")
	var rules: Array[NpcObjectRule] = catalog.npc(&"cloud.npc.boater").dealings().object_rules
	_check(NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(1)) != null and not NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(1)).accept, "one coin is too little")
	var fare: NpcObjectRule = NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(2))
	_check(fare.accept and fare.move_zone_id == &"sunhill.dukou" and fare.move_point_id == &"sunhill.dukou.ferry_arrival", "two coins are the fare: the boat to 江南渡口")


## boater.c accept_object(): anything worth 2 coins (his 过江 answer says five taels) and the
## boat takes the payer across (owner, plan Q1; ES2 left them on the dock); less, his say().
func _test_ferry(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.dukou", &"cloud.dukou", &"cloud.dukou.river_return").succeeded(), "at 江北渡口")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var boater: NpcRuntimeState = _npc(map, &"cloud.npc.boater")
	_check(boater != null and map.select_npc(boater.character_id) and map.selected_npc_takes_gifts(), "the boatman")
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 10, &"test.ferry.coin") # TEST-ONLY
	var said: int = hud.log_lines().size()
	var little: ItemHandlingResult = map.give_to_selected(_carried(session, COIN), 1)
	_check(not little.done() and hud.log_lines().slice(said).has("这么少？我还要养家呀！") and Finance.amount(money, CurrencyDenomination.Value.COIN) == 10, "one coin: 这么少？, kept")
	said = hud.log_lines().size()
	var paid: ItemHandlingResult = map.give_to_selected(_carried(session, COIN), 2)
	var lines: Array[String] = hud.log_lines().slice(said)
	_check(paid.done() and lines.has(FARE_LINES[0]) and lines.has(FARE_LINES[1]) and lines.find(FARE_LINES[0]) < lines.find(FARE_LINES[1]), "two coins: his lines: %s" % [lines])
	_check(Finance.amount(money, CurrencyDenomination.Value.COIN) == 8, "the fare is his")
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(session.active_map_id() == &"sunhill.mountain" and location.zone_id == &"sunhill.dukou", "the boat puts in at 江南渡口: %s" % location.zone_id)
	_check(session.place_name(location) == "日照山 · 江南渡口", "日照山 · 江南渡口: %s" % session.place_name(location))
	_check(Work.capture(session) != null, "Save on the south bank")


## ES2's river is waded: 江南渡口 north through the three rooms of 泓水 to 江北渡口, and back.
func _test_ford(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"sunhill.southriver", &"sunhill.midriver", &"sunhill.northriver"]), "north across the ford")
	_check(await MapPlaces.take_passage(tree, map, &"sunhill.northriver.north"), "up onto 江北渡口")
	var cloud: WorldMapController = session.active_map() as WorldMapController
	_check(cloud.map_id() == &"cloud.outdoor" and session.player_runtime().world_location().zone_id == &"cloud.dukou", "绮云镇's dock")
	_check(await MapPlaces.take_passage(tree, cloud, &"cloud.dukou.south"), "south into 泓水")
	map = session.active_map() as WorldMapController
	_check(map.map_id() == &"sunhill.mountain" and session.player_runtime().world_location().zone_id == &"sunhill.northriver", "泓水北侧")
	_check(await MapPlaces.drive_through(tree, map, [&"sunhill.midriver", &"sunhill.southriver", &"sunhill.dukou"]), "waded back to 江南渡口")


## The path up 日照山 to the 山门, past the closed road to 乔阴县城.
func _test_climb(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"sunhill.road1", &"sunhill.road2", &"sunhill.road3", &"sunhill.road4", &"sanyen.sroad1", &"sanyen.sroad2", &"sanyen.gate"]), "up the winding path to the 山门")
	var greeters: int = 0
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == &"sanyen.npc.greeting" and npc.world_location().zone_id == &"sanyen.gate":
			greeters += 1
	_check(greeters == 2, "two 知客僧 at the gate: %d" % greeters)
	_check(await MapPlaces.take_passage(tree, map, &"sanyen.gate.north"), "north through the gate")


func _test_temple(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(map.map_id() == &"sanyen.grounds" and session.player_runtime().world_location().zone_id == &"sanyen.front_yard", "the yard inside the gate")
	var guards: int = 0
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == &"cloud.npc.monk_guard" and npc.world_location().zone_id == &"sanyen.front_yard":
			guards += 1
	_check(guards == 2, "two 护寺武僧 train there: %d" % guards)
	_check(map.door(&"sanyen.road1.door").is_open(), "the 金门 stands open")
	_check(await MapPlaces.drive_through(tree, map, [&"sanyen.door", &"sanyen.road1", &"sanyen.temple"]), "through the gate house, up the flagstones, into the hall")
	_check(_npc(map, &"common.npc.bonze.master") != null and _npc(map, &"common.npc.bonze.master").world_location().zone_id == &"sanyen.temple", "玄智和尚 in the hall")
	_check(await MapPlaces.drive_through(tree, map, [&"sanyen.inner_yard", &"sanyen.heal_room"]), "the garden and 流云轩")
	_check(map.select_landmark(&"sanyen.heal_room.landmark.plaque"), "the plaques")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("华  陀  再  世"), "华陀再世: %s" % hud.inspection_text.text.left(40))
	hud.dismiss_current_panel()
	await tree.physics_frame
	_check(await MapPlaces.drive_through(tree, map, [&"sanyen.inner_yard", &"sanyen.temple", &"sanyen.corridor", &"sanyen.back_temple", &"sanyen.tower"]), "behind the curtain to the 后殿 and the 塔林")
	_check(await MapPlaces.drive_through(tree, map, [&"sanyen.back_temple", &"sanyen.corridor", &"sanyen.temple", &"sanyen.road1", &"sanyen.road2", &"sanyen.drug_field"]), "out to the herb garden")
	_check(Work.capture(session) != null, "Save in the temple")


## kitchen.c do_open() and do_take(): while the cook stands there he refuses both (默认: one
## lying unconscious says nothing); without him the steamer's lines, five 馒头 a reset and
## then 梦忆柔's voice.
func _test_kitchen(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, map, [&"sanyen.road2", &"sanyen.road1", &"sanyen.temple", &"sanyen.corridor", &"sanyen.corridor1", &"sanyen.kitchen"]), "round to the 香积厨")
	var steamer: ActService = map.service(&"sanyen.kitchen.steampot") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"sanyen.kitchen.steampot")) and steamer.in_reach(), "by the stoves")
	steamer.interact()
	_check(hud.log_lines()[-1] == "烧饭僧说:阿弥陀佛 !! 施主请勿动手动脚, 妨碍贫僧煮饭。", "the cook stops the lid: %s" % hud.log_lines()[-1])
	_check(map.select_landmark(&"sanyen.kitchen.landmark.steampot"), "the 蒸笼")
	var guarded: TakeLandmarkPolicy.Result = map.traverse_selected_portal() as TakeLandmarkPolicy.Result
	_check(guarded.guarded and guarded.taken_item_id.is_empty() and hud.log_lines()[-1] == "烧饭僧说:阿弥陀佛 !! 施主偷东西是不好的行为哦!!!", "and the 馒头")
	var cook: NpcRuntimeState = _npc(map, COOK)
	cook.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: knocked out, as a fight would leave him
	steamer.interact()
	var lines: Array[String] = hud.log_lines()
	_check(lines[-1].contains("又白又Ｑ的大馒头(maintal)"), "a cook lying there says nothing (默认): the lid lifts: %s" % [lines.slice(-2)])
	var taken: int = 0
	for _i: int in 5:
		if not (map.traverse_selected_portal() as TakeLandmarkPolicy.Result).taken_item_id.is_empty():
			taken += 1
	_check(taken == 5 and hud.log_lines()[-1] == "你从蒸笼里拿出一粒热乎乎的馒头。", "five 馒头")
	var empty: TakeLandmarkPolicy.Result = map.traverse_selected_portal() as TakeLandmarkPolicy.Result
	_check(empty.empty and hud.log_lines()[-1] == "突然房间里好像传来梦忆柔的声音说拿太多小心吃到噎著哦!!", "then 梦忆柔's voice")
	cook.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY: he comes to
	_check((map.traverse_selected_portal() as TakeLandmarkPolicy.Result).guarded, "standing again, he guards it before the count")
	map.reset_room("d/sanyen/kitchen.c")
	cook.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY
	_check(not (map.traverse_selected_portal() as TakeLandmarkPolicy.Result).taken_item_id.is_empty(), "the room's reset fills the steamer again")
	_check(not _carried(session, MAINTAL).is_empty(), "the 馒头 carried")
	hud.dismiss_current_panel()
	await tree.physics_frame


## West of the gate the tunnel through the cliff to 晚月庄's bamboo hills, and back.
func _test_tunnel(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, map, [&"sanyen.corridor1", &"sanyen.corridor", &"sanyen.temple", &"sanyen.road1", &"sanyen.door", &"sanyen.front_yard"]), "back to the yard")
	_check(await MapPlaces.take_passage(tree, map, &"sanyen.front_yard.south"), "out of the gate")
	var mountain: WorldMapController = session.active_map() as WorldMapController
	_check(mountain.map_id() == &"sunhill.mountain" and session.player_runtime().world_location().zone_id == &"sanyen.gate", "the 山门")
	_check(await MapPlaces.drive_through(tree, mountain, [&"sanyen.tunnele", &"sanyen.tunnel"]), "into the tunnel")
	_check(await MapPlaces.take_passage(tree, mountain, &"sanyen.tunnel.west"), "out at its west end")
	var hills: WorldMapController = session.active_map() as WorldMapController
	_check(hills.map_id() == &"latemoon.hills" and session.player_runtime().world_location().zone_id == &"latemoon.sroad5", "晚月庄's slope")
	_check(await MapPlaces.take_passage(tree, hills, &"latemoon.sroad5.east"), "east into the tunnel again")
	_check(session.player_runtime().world_location().zone_id == &"sanyen.tunnel", "the tunnel")


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for id: StringName in session.inventory_state().direct_children(carried):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("sanyen: " + message)
