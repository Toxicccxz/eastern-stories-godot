extends RefCounted

## 关北 A (DECISIONS「关北 A」): the region's first four maps — the military road out of 天驼关's
## valley by the gate in its east wall (guanbei.gorge), 槐阳城's gate, street and the 王府's front
## (guanbei.town), the 马市 (guanbei.horse_market) and the 塞外酒肆 (guanbei.inn) — their nine
## native rooms, the ways between them and back into the valley, the east gate's rule (no mark,
## no way out), the people at their posts, the 告示, the vendors and their goods, the landmarks'
## texts, and a Save/Continue round trip from the inn. Walks use the move actions (MapPlaces).
## The chapter's steps (the letter, the mould, the 印色, the four ways past the gate) are
## story_chapter6_test.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"guanbei.gorge": 3, &"guanbei.town": 3, &"guanbei.horse_market": 1, &"guanbei.inn": 2, &"guanbei.palace_court": 2, &"guanbei.palace": 2}
## Where each kind stands (the rescue ledger's 老秦 is story_chapter6_test's).
const PEOPLE: Dictionary = {
	&"guanbei.gate": {&"native.npc.huaiyang_gate_guard": 2, &"native.npc.camel_driver": 2},
	&"guanbei.street": {&"native.npc.guanbei_smith": 1},
	&"guanbei.market": {&"native.npc.balang": 1, &"native.npc.luca": 1, &"native.npc.herdsman": 2},
	&"guanbei.inn_hall": {&"native.npc.hu_sanniang": 1, &"native.npc.qin_popo": 1, &"native.npc.qin_xiaoliu": 1},
	&"guanbei.palace_front": {&"native.npc.palace_gate_guard": 2},
	&"guanbei.palace_yard": {&"native.npc.palace_steward": 1},
	&"guanbei.drill": {&"native.npc.guo_cheng": 1, &"native.npc.palace_soldier": 4},
	&"guanbei.palace_hall": {&"native.npc.cheng_shuo": 1, &"native.npc.palace_guard": 2},
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_walk(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("guanbei."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null and String(zone.room_ids()[0]).begins_with("native:guanbei/"), "%s: one native room" % zone.zone_id)
	_check(maps == MAPS, "thirteen native rooms on six maps: %s" % maps)
	_check(catalog.region(&"guanbei").display_name == "关北", "the region is 关北")
	_check(catalog.map(&"guanbei.inn").interior and catalog.map(&"guanbei.palace").interior and catalog.map(&"guanbei.palace_court").interior and not catalog.map(&"guanbei.gorge").interior and not catalog.map(&"guanbei.town").interior and not catalog.map(&"guanbei.horse_market").interior, "the inn and the 王府 are indoors, the road, the town and the market are outdoors")
	_check(catalog.portal(&"guanbei.palace_front.north").destination_zone_id == &"guanbei.palace_yard" and catalog.portal(&"guanbei.palace_yard.north").destination_zone_id == &"guanbei.palace_hall" and catalog.door(&"guanbei.palace.gate").map_ids() == [&"guanbei.town", &"guanbei.palace_court"], "the 王府大门 off the street into the court (placed by both maps), the hall's door off the court")
	var east: PortalDefinition = catalog.portal(&"canyon.canyon7.east")
	_check(east != null and east.destination_zone_id == &"guanbei.gate_road" and east.set_mark == "到了关北" and catalog.portal(&"guanbei.gate_road.south").destination_zone_id == &"canyon.canyon7", "the valley's east gate into 关北 (marking 到了关北) and the way back")
	var rule: ZoneExitRuleDefinition = null
	for candidate: ZoneExitRuleDefinition in catalog.exit_rules():
		if candidate.rule_id == &"canyon.canyon7.east_gate":
			rule = candidate
	_check(rule != null and rule.condition == ZoneExitRuleDefinition.Condition.NO_MARK and rule.mark == "过了关门" and rule.to_zone_id == &"guanbei.gate_road", "the gate refuses one without 过了关门")
	_check(catalog.portal(&"guanbei.boundary.north").destination_zone_id == &"guanbei.gate" and catalog.portal(&"guanbei.gate.south").destination_zone_id == &"guanbei.boundary", "the boundary stone's road into the city gate, and back")
	_check(catalog.portal(&"guanbei.street.east").destination_zone_id == &"guanbei.market" and catalog.portal(&"guanbei.market.west").destination_zone_id == &"guanbei.street", "the lane from the street to the 马市, and back")
	_check(catalog.portal(&"guanbei.market.north").destination_zone_id == &"guanbei.inn_hall" and catalog.portal(&"guanbei.inn_hall.south").destination_zone_id == &"guanbei.market", "the 酒肆's door off the market, and out")
	var stone: WorldLandmarkDefinition = catalog.landmark(&"guanbei.boundary.landmark.stone")
	_check(stone != null and stone.teaches == ["到了关北"] and stone.description.contains("关北封国界"), "the boundary stone reads 关北封国界 and teaches 到了关北")
	for id: StringName in [&"guanbei.gate_road.landmark.gate", &"guanbei.gate.landmark.wall", &"guanbei.market.landmark.pen", &"guanbei.inn_hall.landmark.hearth"]:
		_check(catalog.landmark(id) != null, "landmark %s" % id)
	var notice: ServiceDefinition = catalog.service(&"guanbei.gate.notice")
	_check(notice != null and notice.act != null and notice.act.verb == "看" and notice.act.acts.size() == 1, "the 王府's notice: 看 (its mark 看过王府告示 is read on the walk)")
	_check(catalog.vendor(&"guanbei.vendor.inn").goods_keys().size() == 2 and catalog.vendor(&"guanbei.vendor.smith").goods_keys().size() == 1, "胡三娘 sells 马奶酒 and 手抓羊肉, the smith his 马刀")
	var wine: ItemContentDefinition = catalog.item(&"native:guanbei/mares_milk_wine")
	var mutton: ItemContentDefinition = catalog.item(&"native:guanbei/mutton")
	_check(wine != null and wine.liquid_initial_name == "马奶酒" and mutton != null and mutton.category == ItemContentDefinition.CATEGORY_FOOD, "the wine is a drink, the mutton food")
	var saber: ItemContentDefinition = catalog.item(&"native:guanbei/saber")
	var gladius: ItemContentDefinition = catalog.item(&"native:guanbei/gladius")
	_check(saber != null and saber.weapon_skill_type == &"blade" and gladius != null and gladius.weapon_skill_type == &"sword" and gladius.weapon_damage == 55, "the 马刀 is a blade, 卢卡's 大秦短剑 a sword")
	var mould: ItemContentDefinition = catalog.item(&"native:canyon/seal_mould")
	_check(mould != null and mould.no_drop and mould.act != null and mould.act.verb == "比印" and mould.act.acts.size() == 2 and mould.act.acts[0].carries == "文书", "the 印模: no_drop, its 比印 wants the 文书 at hand")
	var seal: ItemContentDefinition = catalog.item(&"es2:d/canyon/npc/obj/seal")
	var fake: ItemContentDefinition = catalog.item(&"es2:d/canyon/npc/obj/fake_seal")
	_check(seal != null and seal.name_color == ColoredLine.HIY and fake != null and fake.name_color.is_empty(), "general.c: the real 印鉴's name is HIY, the fake's plain (name_color)")
	_check(PlayerInventoryPanel.name_color_of(&"es2:d/canyon/npc/obj/seal") == SharedGameplayUI.ES2_COLORS[ColoredLine.HIY] and PlayerInventoryPanel.name_color_of(&"es2:d/canyon/npc/obj/fake_seal") == Color.TRANSPARENT, "the 背包 writes the real seal's name in yellow")
	var soldier: NpcDefinition = catalog.npc(&"native.npc.pass_gate_soldier")
	_check(soldier != null and soldier.hooks() != null and soldier.hooks().calls.size() == 1 and soldier.hooks().calls[0].act.mark == "军营" and soldier.dealings().object_rules.size() == 4 and soldier.dealings().object_rules[1].value_at_least == 500, "the 关门兵: lets the listed through, takes five taels")
	var soldiers: NpcSpawnDefinition = catalog.spawn(&"native.canyon7.gate_soldiers")
	_check(soldiers != null and soldiers.quantity == 2 and soldiers.zone_id == &"canyon.canyon7" and soldiers.cleared_mark == "过了关门", "two of them at the gate; beaten, the way is open")
	var lao_qin: NpcSpawnDefinition = catalog.spawn(&"guanbei.inn_hall.lao_qin")
	_check(lao_qin != null and lao_qin.present != null, "老秦 sits in the 酒肆 only on the rescue ledger")
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_GUANBEI_B_V1, "关北 B's world revision is current")


## From the valley: the gate refused, then (TEST-ONLY: the mark set) through it and north to the
## city, the street, the 王府's front, the market and the inn and back; the people at their posts.
func _test_walk(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var valley: WorldMapController = MapPlaces.enter(session, &"canyon.canyon7", &"canyon.canyon7.village_return")
	_check(valley != null and valley.map_id() == &"canyon.pass", "in the valley")
	await _settle(tree)
	_check(_count_in(session, &"canyon.canyon7", &"native.npc.pass_gate_soldier") == 2, "two 关门兵 at the east gate")
	var left: bool = await MapPlaces.take_passage(tree, valley, &"canyon.canyon7.east", 240)
	_check(not left and session.active_map_id() == &"canyon.pass" and ui.log_lines().any(func(line: String) -> bool: return line.contains("过路钱")), "without 过了关门 the gate refuses: %s" % [ui.log_lines().slice(-2)])
	state.marks["过了关门"] = 1 # TEST-ONLY: paid, listed, lettered or fought — story_chapter6_test does each
	var gorge: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.gate_road")
	_check(gorge != null and gorge.map_id() == &"guanbei.gorge" and state.marks.get("到了关北", 0) == 1, "through the gate onto the 关外山道; 到了关北 marked by the way")
	_check(gorge.select_landmark(&"guanbei.gate_road.landmark.gate") and gorge.inspect_selected() and ui.inspection_text.text.contains("严"), "the gate looked back at: 严廷殷's flag")
	ui.dismiss_current_panel()
	await _settle(tree)
	_check(await MapPlaces.drive_through(tree, gorge, [&"guanbei.dust_road", &"guanbei.boundary"]), "up the dust road to the boundary stone")
	_check(gorge.select_landmark(&"guanbei.boundary.landmark.stone") and gorge.inspect_selected() and ui.inspection_text.text.contains("关北封国界"), "the stone read")
	ui.dismiss_current_panel()
	await _settle(tree)
	var town: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.gate")
	_check(town != null and town.map_id() == &"guanbei.town", "through the city gate")
	for zone: StringName in PEOPLE:
		for kind: StringName in PEOPLE[zone]:
			_check(_count_in(session, zone, kind) == PEOPLE[zone][kind], "%d %s in %s" % [PEOPLE[zone][kind], kind, zone])
	var notice: ActService = town.service(&"guanbei.gate.notice") as ActService
	_check(notice != null and await MapPlaces.drive(tree, town, MapPlaces.service_spot(town, &"guanbei.gate.notice")) and notice.in_reach() and notice.verb() == "看", "告示 · 看 by the gate")
	notice.interact()
	await _settle(tree)
	_check(state.marks.get("看过王府告示", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("本府不奉")), "the notice read: 本府不奉")
	var guard: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.gate.gate_guard.1")
	_check(guard != null and await MapPlaces.drive(tree, town, town.runtime_body_for_character(guard.character_id).global_position + Vector2(0, -60)) and town.select_npc(guard.character_id), "beside a gate guard")
	_check(town.ask_selected("告示").any(func(line: String) -> bool: return line.contains("先过我们这一关")), "he stands by the notice")
	_check(await MapPlaces.drive_through(tree, town, [&"guanbei.street", &"guanbei.palace_front"]), "up the street to the 王府's front")
	_check(not town.door(&"guanbei.palace.gate").is_open(), "the 王府大门 shut to one without the letter")
	var knock: ActService = town.service(&"guanbei.palace_front.knock") as ActService
	_check(knock != null and await MapPlaces.drive(tree, town, MapPlaces.service_spot(town, &"guanbei.palace_front.knock")) and knock.in_reach(), "王府大门 · 叩门")
	knock.interact()
	await _settle(tree)
	_check(not state.marks.has("王府放行") and ui.log_lines().any(func(line: String) -> bool: return line.contains("有凭据再来")), "empty-handed: 王爷不见生人，有凭据再来")
	town.give_new_item_to_player(&"native:choyin/magistrate_letter") # TEST-ONLY: 程不平's letter (story_chapter6_test earns it)
	knock.interact()
	await _settle(tree)
	_check(state.marks.get("王府放行", 0) == 1 and town.door(&"guanbei.palace.gate").is_open(), "with the letter: 朱门开了")
	var court: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.palace_yard")
	_check(court != null and court.map_id() == &"guanbei.palace_court", "through the 王府大门 into the court")
	_check(await MapPlaces.drive_through(tree, court, [&"guanbei.drill", &"guanbei.palace_yard"]), "over to the drill yard and back")
	_check(court.select_landmark(&"guanbei.drill.landmark.posts") and court.inspect_selected() and ui.inspection_text.text.contains("左肩"), "the posts looked at")
	ui.dismiss_current_panel()
	await _settle(tree)
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.palace_hall")
	_check(hall != null and hall.map_id() == &"guanbei.palace", "up the steps into the 正厅")
	_check(await MapPlaces.drive_through(tree, hall, [&"guanbei.side_hall", &"guanbei.palace_hall"]), "into the side hall and back")
	_check(hall.select_landmark(&"guanbei.side_hall.landmark.map") and hall.inspect_selected() and ui.inspection_text.text.contains("工地") and state.marks.get("看过王府的地图", 0) == 1, "the map read: the 工地 ringed in red")
	ui.dismiss_current_panel()
	await _settle(tree)
	town = await MapPlaces.go_to(tree, session, &"guanbei.street")
	_check(town != null and town.map_id() == &"guanbei.town", "back out to the street")
	var smith: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.street.smith.1")
	_check(smith != null and await MapPlaces.drive(tree, town, town.runtime_body_for_character(smith.character_id).global_position + Vector2(0, 60)) and town.select_npc(smith.character_id), "beside the smith")
	_check(town.ask_selected("马刀").any(func(line: String) -> bool: return line.contains("十五两")), "his 马刀 for fifteen taels")
	var market: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.market")
	_check(market != null and market.map_id() == &"guanbei.horse_market", "east down the lane into the 马市")
	_check(market.select_landmark(&"guanbei.market.landmark.pen") and market.inspect_selected() and ui.inspection_text.text.contains("矮脚马"), "the pen looked at")
	ui.dismiss_current_panel()
	await _settle(tree)
	var inn: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.inn_hall")
	_check(inn != null and inn.map_id() == &"guanbei.inn", "into the 塞外酒肆")
	_check(_count_in(session, &"guanbei.inn_hall", &"native.npc.lao_qin") == 0, "老秦 is not here on a fresh game (the rescue ledger seats him)")
	_check(await MapPlaces.drive_through(tree, inn, [&"guanbei.inn_back", &"guanbei.inn_hall"]), "into the back room and out again")
	var keeper: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.inn_hall.hu_sanniang.1")
	_check(keeper != null and await MapPlaces.drive(tree, inn, inn.runtime_body_for_character(keeper.character_id).global_position + Vector2(0, 60)) and inn.select_npc(keeper.character_id), "beside 胡三娘")
	_check(inn.ask_selected("民夫").any(func(line: String) -> bool: return line.contains("等人的")), "她 on the waiting")
	# Save and Continue from the inn.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "a save from the 酒肆")
	if snapshot != null:
		var walker: RefCounted = Work.new()
		await walker.round_trip(tree, session, snapshot, "关北 A in the 酒肆")
		_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))
	var back: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.street")
	_check(back != null and back.map_id() == &"guanbei.town", "out of the inn and back to the street")


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
