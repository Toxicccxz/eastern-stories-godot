extends RefCounted

## 玉螺湖村 A (d/village): twenty-six rooms on three maps — the village with the 黄土大道 south of
## 天驼关, the lakeside and the valley outside 忘情谷 beyond the grass; the lake's middle (the
## boat: only the paddle reaches it) and the ice cave under the lake. The grass opens the way
## west for five seconds (road6.c); the lake is no walk, the boat goes out and comes back, and
## the dive (repaired, owner Q1; asked first) breaks into the ice cave, whose 玄冰 offers 放弃.
## The 白鳞冰龙 fall on whoever enters their hall, all together. The doors shut; the 西瓜 the
## 瓜农 sells feeds and quenches thirst bite by bite and leaves its rind (bone). Reminders: the
## road south to 京师 (#12) and 黑松山 (after it: 刘老农's thanks and revenge). Walks use the move
## actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"village.main": 23, &"village.midlake": 1, &"village.icecave": 2}
const GRASS: StringName = &"village.road6.landmark.grass"
const WEST: StringName = &"village.road6.west"
const MELON: StringName = &"es2:d/village/obj/melon"
const LIU: StringName = &"village.npc.oldliu"
## Where each kind stands (the rooms' set("objects")).
const PEOPLE: Dictionary = {
	&"village.road2": {&"village.npc.trader1": 2},
	&"village.fmhousback": {&"village.npc.woman1": 1},
	&"village.littlegarden": {&"village.npc.flowergirl": 5},
	&"village.home": {LIU: 1},
	&"village.smallstorage": {&"village.npc.rat": 6},
	&"village.melonguard": {&"village.npc.meloner": 3},
	&"village.lakeside": {&"village.npc.fisher": 3},
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_reminders()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_way_in(tree, session)
	await _test_village(tree, session)
	await _test_grass(tree, session)
	await _test_lake(tree, session)
	await _test_melon(tree, session)
	await _test_dragons(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("village."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null, "%s: one room" % zone.zone_id)
	_check(maps == MAPS, "26 rooms on three maps: %s" % maps)
	_check(catalog.region(&"village").display_name == "玉螺湖村", "the region is 玉螺湖村")
	_check(catalog.zone(&"village.lakebottom2").combat_entry == &"complete_set", "the dragons' hall: all at once (默认)")
	for id: StringName in [&"village.home.door", &"village.lordhouse1.door"]:
		_check(catalog.door(id) != null and not catalog.door(id).starts_open, "%s shut" % id)
	_check(catalog.door(&"village.lordhouse1.door").display_name == "田老财家大门" and catalog.door(&"village.home.door").display_name == "木门", "刘家's 木门, 田老财家大门")
	_check(catalog.landmark(&"village.road3.landmark.tablet").description == "你勉强分辨出那上面模糊的字迹：傅家坡\n", "the sign: 傅家坡")
	var grass: WorldLandmarkDefinition = catalog.landmark(GRASS)
	_check(grass.policy == &"hidden_passage" and grass.portal_ids() == [WEST] and grass.setting("every_push") == 1 and grass.setting("open_seconds") == 5, "the grass: one way west, every push, five seconds")
	_check(catalog.hidden_passage_for_portal(WEST) == grass and catalog.hidden_passage_for_portal(&"village.valley2.east") == null, "only the way west is hidden; east back to the village is an exit")
	for rule_id: Array in [[&"village.lakeside", &"village.lake", "这么大的一片湖，你想走过去吗？"], [&"village.lake", &"village.lakeside", "你正站在船头，向东走一小步就会掉入湖中！你不想这样吧？"]]:
		var rule: ZoneExitRuleDefinition = catalog.exit_rules_between(rule_id[0], rule_id[1])[0]
		_check(rule.refuses(ZoneExitRuleDefinition.Leaver.new(), false) and rule.lines == [rule_id[2]], "%s: nobody walks onto the water" % rule_id[2])
	_check(not catalog.room(&"es2:d/village/lordhouse3").long.is_empty() and catalog.zone_of_room(&"es2:d/village/lordhouse3") != null, "the 南房 loads (lordhouse3.c's stray brace, 默认)")
	var melon: ItemContentDefinition = catalog.item(MELON)
	var food: FoodDefinition = melon.food_definition()
	_check(food.initial_portions == 8 and food.food_supply == 20 and food.water_supply == 40 and melon.value == 60, "西瓜: eight bites of 20 food and 40 water, worth 60")
	_check(catalog.vendor(&"village.vendor.meloner").item_definition_id("water melon") == MELON, "the 瓜农 sell 西瓜")


## Content that waits for another region keeps a test that fails once it comes.
func _test_reminders() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# 京师 (#12, 京师 A): road2.c's south is the 北驿道 (nroad2.c's north comes back).
	_check(catalog.room(&"es2:d/village/road2").exits().get("south") == "es2:d/city/nroad2", "road2.c's south names 京师's nroad2")
	var south: PortalDefinition = catalog.portal(&"village.road2.south")
	_check(south != null and south.source_zone_id == &"village.road2" and south.destination_zone_id == &"city.nroad2", "the 三叉路口's way south leads to the 北驿道")
	var north: PortalDefinition = catalog.portal(&"city.nroad2.north")
	_check(north != null and north.destination_zone_id == &"village.road2", "the 北驿道's way north comes back to the 三叉路口")
	# 黑松山 (after 京师, owner Q2): 小娟 sets marks/老刘 or marks/murder; 刘老农 then thanks
	# (銮鱼衡冰 and 过招要旨, he leaves with 娟儿) or takes revenge (悲愤欲绝). Until then he only asks.
	for zone: ZoneDefinition in catalog.zones():
		for room: StringName in zone.room_ids():
			_check(not String(room).begins_with("es2:d/chuenyu/"), "黑松山 is placed (%s): give 刘老农 his thanks and revenge (oldliu.c greeting(), killhim()) and open the 黄土大道's spur" % room)
	_check(catalog.npc(LIU).talk().has_greeting() and catalog.item(&"es2:d/village/npc/obj/hengbing") == null, "刘老农 only asks after 娟儿 for now")


## 天驼关's valley south onto the 黄土大道, and back.
func _test_way_in(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"canyon.pass", &"canyon.canyon7", &"canyon.canyon7", &"canyon.canyon7.village_return").succeeded(), "in 天驼关谷地")
	await tree.physics_frame
	var gorge: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, gorge, &"canyon.canyon7.south"), "south out of the valley")
	var map: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(map.map_id() == &"village.main" and location.zone_id == &"village.road1", "the 黄土大道: %s" % location.zone_id)
	_check(session.place_name(location) == "玉螺湖村 · 黄土大道", "玉螺湖村 · 黄土大道: %s" % session.place_name(location))
	_check(Work.capture(session) != null, "Save on the 黄土大道")
	_check(await MapPlaces.take_passage(tree, map, &"village.road1.north"), "north back to 天驼关")
	_check(session.active_map_id() == &"canyon.pass" and session.player_runtime().world_location().zone_id == &"canyon.canyon7", "天驼关谷地")
	gorge = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, gorge, &"canyon.canyon7.south"), "and south again")


## Who stands where; the sign; 刘家's door and 刘老农's question; no spar with him.
func _test_village(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var found: Dictionary = {}
	for npc: NpcRuntimeState in map.resident_npcs():
		var zone: StringName = npc.world_location().zone_id
		if not found.has(zone):
			found[zone] = {}
		found[zone][npc.definition().definition_id] = found[zone].get(npc.definition().definition_id, 0) + 1
	_check(found == PEOPLE, "the villagers where the rooms put them: %s" % [found])
	_check(await MapPlaces.drive_through(tree, map, [&"village.road2", &"village.road3"]), "to the 三叉路口 and west onto the 青石小路")
	_check(map.select_landmark(&"village.road3.landmark.tablet"), "the sign")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("傅家坡"), "傅家坡: %s" % hud.inspection_text.text.left(30))
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive_through(tree, map, [&"village.road4", &"village.road5", &"village.littlegarden"]), "into 刘老汉's garden")
	var door: WorldDoor = map.door(&"village.home.door")
	_check(door != null and not door.is_open(), "the 木门 is shut")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"village.home.door", &"village.littlegarden")) and map.open_door(&"village.home.door"), "the 木门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.home"), "into 刘家小房")
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(1.0)
	var asked: Array[String] = []
	for line: String in hud.log_lines():
		if line.begins_with("刘老农说道：“这位") and line.contains("，可否见到小女娟儿？”"):
			asked.append(line)
	_check(asked.size() == 1, "a second later: 可否见到小女娟儿？ %s" % [hud.log_lines().slice(-3)])
	var liu: NpcRuntimeState = _npc(map, LIU)
	_check(liu != null and map.select_npc(liu.character_id), "刘老农")
	var spar: CombatSliceInitiationResult = map.spar_selected()
	_check(spar.outcome != CombatSliceInitiationResult.Outcome.COMPLETED and hud.log_lines().has("刘老农说道：老头子哪里是您的对手？"), "no spar: 老头子哪里是您的对手？ %s" % [hud.log_lines().slice(-2)])
	_check(Work.capture(session) != null, "Save in 刘家小房")
	_check(player.world_location().zone_id == &"village.home", "still in the house")


## road6.c: pushaside opens the way west for five seconds; valley2's way east is always there.
func _test_grass(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, map, [&"village.littlegarden", &"village.road5", &"village.road6"]), "west to the path's end")
	_check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"village.road6", MapPlaces.passage(map, WEST).global_position + Vector2(64, 0))), "by the grass")
	_check(not map.is_portal_open(WEST), "the grass shuts the way")
	_check(map.select_landmark(GRASS) and hud.portal_action_text() == "拨开" and hud.portal_action_is_enabled(), "茅草 · 拨开")
	map.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你拨开茅草，发现了一条向西的路。" and map.is_portal_open(WEST), "a way west: %s" % hud.log_lines()[-1])
	_check(await MapPlaces.take_same_map_passage(tree, map, WEST), "west through the grass")
	_check(player.world_location().zone_id == &"village.valley2", "忘情谷外: %s" % player.world_location().zone_id)
	var start: int = hud.log_lines().size()
	session.advance_hidden_passages(5.0)
	_check(not map.is_portal_open(WEST) and hud.log_lines().size() == start, "five seconds on, the grass closes; nobody in road6 sees it")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.valley1") and await MapPlaces.drive_to_zone(tree, map, &"village.valley2"), "south along the lake's west shore and back")
	_check(await MapPlaces.take_same_map_passage(tree, map, &"village.valley2.east"), "east back into the village, always open")
	_check(player.world_location().zone_id == &"village.road6", "back at the path's end")
	_check(map.select_landmark(GRASS), "the grass again")
	map.traverse_selected_portal()
	_check(map.is_portal_open(WEST), "pushed aside again")
	session.advance_hidden_passages(4.0)
	map.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你拨开茅草，发现了一条向西的路。" and map.is_portal_open(WEST), "pushed again while open: the line again")
	session.advance_hidden_passages(1.0)
	_check(not map.is_portal_open(WEST) and hud.log_lines()[-1] == "茅草晃了晃，又遮住了向西的路。", "the first call_out closes it, seen from road6: %s" % hud.log_lines()[-1])
	# Standing right at the grass (the body brushing the shut way), push, then walk on in.
	var way: WorldPassageArea2D = MapPlaces.passage(map, WEST)
	_check(map.place_player(&"village.road6", way.global_position + Vector2(way.global_rect().size.x / 2.0 + 10.0, 0)), "TEST-ONLY: right against the grass")
	await tree.physics_frame
	await tree.physics_frame
	_check(map.select_landmark(GRASS), "the grass, close by")
	map.traverse_selected_portal()
	await tree.physics_frame
	_check(await MapPlaces.take_same_map_passage(tree, map, WEST, 240) and player.world_location().zone_id == &"village.valley2", "a step on west takes the way that opened at the player's side: %s" % player.world_location().zone_id)
	_check(await MapPlaces.take_same_map_passage(tree, map, &"village.valley2.east"), "and back east")
	# Pressed against the grass (the centre on the shut way): pushing it aside steps through.
	session.advance_hidden_passages(5.0)
	_check(map.place_player(&"village.road6", way.global_position), "TEST-ONLY: against the grass")
	await tree.physics_frame
	await tree.physics_frame
	_check(not map.is_portal_open(WEST) and player.world_location().zone_id == &"village.road6", "the way shut, still in road6")
	_check(map.select_landmark(GRASS), "the grass, pressed against it")
	map.traverse_selected_portal()
	for _frame: int in range(6):
		await tree.physics_frame
	_check(player.world_location().zone_id == &"village.valley2", "pushed aside, the player is through (a one-way way opened under them): %s" % player.world_location().zone_id)
	_check(await MapPlaces.take_same_map_passage(tree, map, &"village.valley2.east"), "and back east again")


## lakeside.c and lake.c: the lake is no walk; the boat out and back; the dive (asked first)
## into the ice cave; 放弃 there wakes the player in the Inn.
func _test_lake(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, map, [&"village.road5", &"village.road7", &"village.lakeside"]), "down to the lakeside")
	_check(not await MapPlaces.take_passage(tree, map, &"village.lakeside.west", 240), "west onto the lake does not take the player")
	_check(player.world_location().zone_id == &"village.lakeside" and hud.log_lines().has("这么大的一片湖，你想走过去吗？"), "这么大的一片湖，你想走过去吗？")
	_check(map.select_landmark(&"village.lakeside.landmark.boat"), "the boats")
	map.inspect_selected()
	_check(hud.inspection_text.text.contains("你可以划着(paddle)它到湖中心"), "关内能经常见到的渔船")
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	var out: ActService = map.service(&"village.lakeside.paddle") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"village.lakeside.paddle")) and out.in_reach() and out.verb() == "划向湖心", "木船 · 划向湖心")
	out.interact()
	await tree.physics_frame
	await tree.physics_frame
	var lake: WorldMapController = session.active_map() as WorldMapController
	_check(lake.map_id() == &"village.midlake" and player.world_location().zone_id == &"village.lake", "on the lake's middle: %s" % player.world_location().zone_id)
	_check(_said(hud, ["你跳上渔船，奋力向湖心划去。", "你终于划到湖中心了。"]), "paddled out: %s" % [hud.log_lines().slice(-3)])
	_check(session.place_name(player.world_location()) == "玉螺湖村 · 玉螺湖", "玉螺湖村 · 玉螺湖")
	_check(Work.capture(session) != null, "Save on the boat")
	_check(not await MapPlaces.take_passage(tree, lake, &"village.lake.east", 240) and hud.log_lines().has("你正站在船头，向东走一小步就会掉入湖中！你不想这样吧？"), "east off the bow: refused")
	var back: ActService = lake.service(&"village.lake.paddle") as ActService
	_check(await MapPlaces.drive(tree, lake, MapPlaces.service_spot(lake, &"village.lake.paddle")) and back.in_reach() and back.verb() == "划回岸边", "小船 · 划回岸边 (repaired, owner Q1)")
	back.interact()
	await tree.physics_frame
	await tree.physics_frame
	map = session.active_map() as WorldMapController
	_check(map.map_id() == &"village.main" and player.world_location().zone_id == &"village.lakeside", "ashore")
	_check(_said(hud, ["你划动双桨，小船慢慢向岸边漂去。", "你终于划到湖岸边。"]), "paddled back (你划动双桨): %s" % [hud.log_lines().slice(-3)])
	out = map.service(&"village.lakeside.paddle") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"village.lakeside.paddle")), "by the boats again")
	out.interact()
	await tree.physics_frame
	await tree.physics_frame
	lake = session.active_map() as WorldMapController
	var dive: ActService = lake.service(&"village.lake.dive") as ActService
	_check(await MapPlaces.drive(tree, lake, MapPlaces.service_spot(lake, &"village.lake.dive")) and dive.in_reach() and dive.verb() == "潜入湖中", "湖水 · 潜入湖中")
	dive.interact()
	await tree.physics_frame
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("白鳞冰龙"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(session.active_map_id() == &"village.midlake", "取消: still on the boat")
	dive.interact()
	await tree.physics_frame
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	await tree.physics_frame
	var cave: WorldMapController = session.active_map() as WorldMapController
	_check(cave.map_id() == &"village.icecave" and player.world_location().zone_id == &"village.lakebottom1", "through the ice into the 水下岩洞")
	_check(_said(hud, ["你深深吸了一口气，一个猛子潜入水中！", "你越潜越深，突然眼前一亮，一处湖底发出光亮。你用拳一砸，那湖底竟然碎了，原来是一层冰！你随着水流被冲进一个岩洞中。"]), "the dive, one line: %s" % [hud.log_lines().slice(-3)])
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the dragons are in the hall beyond, not here")
	_check(Work.capture(session) != null, "Save in the ice cave")
	_check(cave.select_landmark(&"village.lakebottom1.landmark.ice") and hud.portal_action_text() == "放弃", "玄冰 · 放弃")
	cave.traverse_selected_portal()
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map().map_id() == &"snow.inn" and player.world_location().zone_id == &"snow.inn.main_floor", "放弃: in the Inn")
	_check(hud.log_lines().slice(-3).any(func(line: String) -> bool: return line.contains("醒来时，你已经躺在雪亭镇的饮风客栈里")), "told so: %s" % [hud.log_lines().slice(-3)])


## The 瓜农's 西瓜 (60 coins): food.c with drink_func, eight bites, then the rind (bone).
func _test_melon(_tree: SceneTree, session: WorldSessionController) -> void:
	var money: MoneyInventoryContext = Finance.session_context(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	# TEST-ONLY: stacks that sort first, so buy.c pays from them (pay_money() wants silver beside coins).
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 1, &"000-test-village-silver")
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 100, &"000-test-village-coin")
	var bought: VendorPurchaseResult = VendorPurchaseService.buy(GameContent.catalog().vendor(&"village.vendor.meloner"), "water melon", GameContent.catalog(), money,
		session.food_collection(), session.liquid_collection(), session.item_id_allocator(), player.maximum_encumbrance)
	_check(bought.delivered and bought.price == 60, "a 西瓜 for 60 coins: %s" % VendorPurchaseResult.Outcome.find_key(bought.outcome))
	var melon: StringName = bought.item_id
	var water_cap: int = CharacterRecovery.maximum_water_capacity(player.body_facts.body_weight)
	player.state.recovery.food = 0 # TEST-ONLY: hungry
	player.state.recovery.water = water_cap # TEST-ONLY: not thirsty
	var bloated: FoodUseResult = HeldFoodUseService.eat(player, money, session.food_collection(), GameContent.catalog().native_item_projections(), melon, true)
	_check(bloated.outcome == FoodUseResult.Outcome.TOO_BLOATED and player.state.recovery.food == 0, "water full: 你肚子太涨了 (drink_func)")
	var outcomes: Array[int] = []
	for bite: int in range(8):
		player.state.recovery.food = 0 # TEST-ONLY
		player.state.recovery.water = 0 # TEST-ONLY
		var result: FoodUseResult = HeldFoodUseService.eat(player, money, session.food_collection(), GameContent.catalog().native_item_projections(), melon, true)
		outcomes.append(result.outcome)
		_check(player.state.recovery.food == 20 and player.state.recovery.water == 40, "bite %d: 20 food, 40 water" % bite)
		if bite == 7:
			_check(result.leftover_id == GameContent.catalog().item(MELON).leftover_id(), "the last bite leaves the rind")
	_check(outcomes.all(func(outcome: int) -> bool: return outcome == FoodUseResult.Outcome.ATE), "eight bites: %s" % [outcomes])
	var rind: ItemContentDefinition = GameContent.catalog().item(session.item_instance_index().resolve(melon).item_definition_id)
	_check(rind != null and rind.display_name == "西瓜皮" and rind.aliases().has("bone") and session.inventory_state().own_weight(melon) == 150, "a 150 g 西瓜皮 (bone: Snow's dog takes it)")
	_check(Work.capture(session) != null, "a save takes the rind")


## lakebottom2.c's six dragons (aggressive, 1,000,000 exp) fall on whoever comes into their hall,
## from the valley's way down as from the dive.
func _test_dragons(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.handoff_to(&"village.main", &"village.valley1", &"village.valley1", &"village.valley1.cave_return").succeeded(), "TEST-ONLY: outside 忘情谷")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.take_passage(tree, map, &"village.valley1.eastdown"), "east down the ice stair")
	var cave: WorldMapController = session.active_map() as WorldMapController
	_check(cave.map_id() == &"village.icecave" and player.world_location().zone_id == &"village.lakebottom2", "in the dragons' hall")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for _frame: int in range(6):
		await tree.physics_frame
		cave.hostilities.process_pending_aggression()
		if coordinator.has_active_encounter():
			break
	var dragons: int = 0
	if coordinator.has_active_encounter():
		for participant: CombatParticipant in coordinator.active_encounter().participants():
			var npc: NpcRuntimeState = cave.find_resident_npc(participant.participant_id)
			if npc != null and npc.definition().definition_id == &"village.npc.dragon":
				dragons += 1
	_check(dragons == 6, "all six dragons at once (complete_set): %d" % dragons)


## These lines, one after the other, among the last few of the log (the arrival's text follows).
func _said(hud: SharedGameplayUI, lines: Array[String]) -> bool:
	var log: Array[String] = hud.log_lines()
	var at: int = log.rfind(lines[0])
	return at >= 0 and at >= log.size() - 4 and log.slice(at, at + lines.size()) == lines


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("village: " + message)
