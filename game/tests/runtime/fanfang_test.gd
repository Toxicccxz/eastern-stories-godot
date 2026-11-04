extends RefCounted

## 番坊 A (DECISIONS「番坊 A」): the region's first four maps — the 海崖道 from the south end of
## the path outside 忘情谷 (fanfang.cliff_road), the port (fanfang.dock), the bazaar's street with
## 铁盾会's gate (fanfang.bazaar) and the 市舶司 (fanfang.customs) — their ten native rooms, the ways
## between them and back up to 玉螺湖村, the people at their posts, the vendors and their goods, the
## landmarks' texts, the 兵部文书 (its second sentence for one who learned the 印色), 卢卡 at the
## gate only after 关北, and a Save/Continue round trip from the office. Walks use the move
## actions (MapPlaces). The chapter's step is story_chapter7_test.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"fanfang.cliff_road": 3, &"fanfang.port": 2, &"fanfang.bazaar": 3, &"fanfang.customs": 2}
## Where each kind stands (卢卡 is counted on the walk: he comes after 关北).
const PEOPLE: Dictionary = {
	&"fanfang.cliff_path": {&"native.npc.salt_porter": 2},
	&"fanfang.dock": {&"native.npc.boatman": 2, &"native.npc.cargo_merchant": 2, &"native.npc.tax_clerk": 1},
	&"fanfang.shed": {&"native.npc.boatman": 1},
	&"fanfang.bazaar_west": {&"native.npc.glass_merchant": 1, &"native.npc.carpet_merchant": 1, &"native.npc.storyteller": 1},
	&"fanfang.bazaar_east": {&"native.npc.spice_merchant": 1, &"native.npc.stall_child": 1, &"native.npc.copper_merchant": 1},
	&"fanfang.office": {&"native.npc.feng_lu": 1, &"native.npc.customs_clerk": 1},
	&"fanfang.yard": {&"native.npc.customs_runner": 2},
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
		if String(zone.zone_id).begins_with("fanfang."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null and String(zone.room_ids()[0]).begins_with("native:fanfang/"), "%s: one native room" % zone.zone_id)
	_check(maps == MAPS, "ten native rooms on four maps: %s" % maps)
	_check(catalog.region(&"fanfang").display_name == "番坊", "the region is 番坊")
	_check(catalog.map(&"fanfang.customs").interior and not catalog.map(&"fanfang.cliff_road").interior and not catalog.map(&"fanfang.port").interior and not catalog.map(&"fanfang.bazaar").interior, "the 市舶司 is indoors, the road, the dock and the bazaar outdoors")
	var south: PortalDefinition = catalog.portal(&"village.valley1.south")
	_check(south != null and south.destination_zone_id == &"fanfang.cliff_top" and south.set_mark == "到了番坊" and catalog.portal(&"fanfang.cliff_top.north").destination_zone_id == &"village.valley1", "the path outside 忘情谷 runs on south to the 海崖口 (marking 到了番坊), and back")
	_check(catalog.portal(&"fanfang.cliff_foot.south").destination_zone_id == &"fanfang.dock" and catalog.portal(&"fanfang.dock.north").destination_zone_id == &"fanfang.cliff_foot", "the steps down to the dock, and back up")
	_check(catalog.portal(&"fanfang.dock.east").destination_zone_id == &"fanfang.bazaar_west" and catalog.portal(&"fanfang.bazaar_west.west").destination_zone_id == &"fanfang.dock", "the road from the dock into the bazaar, and back")
	_check(catalog.portal(&"fanfang.bazaar_west.south").destination_zone_id == &"fanfang.office" and catalog.portal(&"fanfang.office.north").destination_zone_id == &"fanfang.bazaar_west", "the 市舶司's door off the street, and out")
	for id: StringName in [&"fanfang.cliff_top.landmark.shrine", &"fanfang.cliff_path.landmark.sea", &"fanfang.dock.landmark.boats", &"fanfang.bazaar_north.landmark.shields"]:
		_check(catalog.landmark(id) != null, "landmark %s" % id)
	var notice: WorldLandmarkDefinition = catalog.landmark(&"fanfang.office.landmark.notice")
	_check(notice != null and notice.description.contains("辑拿要犯----於兰天武"), "the wanted notice copied word for word from eastdoor2.c")
	var papers: ServiceDefinition = catalog.service(&"fanfang.office.papers")
	_check(papers != null and papers.act != null and papers.act.verb == "看" and papers.act.acts.size() == 2 and papers.act.acts[0].mark == "学过印色", "the 兵部文书: 看, its second sentence for one who learned the 印色")
	_check(catalog.vendor(&"fanfang.vendor.glass").goods_keys().size() == 1 and catalog.vendor(&"fanfang.vendor.carpet").goods_keys().size() == 1 and catalog.vendor(&"fanfang.vendor.spice").goods_keys().size() == 2 and catalog.vendor(&"fanfang.vendor.copper").goods_keys().size() == 1, "the four merchants' goods")
	var bread: ItemContentDefinition = catalog.item(&"native:fanfang/hu_bread")
	var kettle: ItemContentDefinition = catalog.item(&"native:fanfang/copper_kettle")
	_check(bread != null and bread.category == ItemContentDefinition.CATEGORY_FOOD and kettle != null and kettle.liquid_initial_name == "清水", "the 胡饼 is food, the 铜壶 holds water")
	var luca_market: NpcSpawnDefinition = catalog.spawn(&"guanbei.market.luca")
	var luca_port: NpcSpawnDefinition = catalog.spawn(&"fanfang.bazaar_north.luca")
	_check(luca_market != null and luca_market.until != null and luca_market.until.key == "关北一章" and luca_port != null and luca_port.present != null and luca_port.present.key == "关北一章", "卢卡 leaves the 马市 for 铁盾会's gate once 关北 is done")
	var luca: NpcDefinition = catalog.npc(&"native.npc.luca")
	_check(luca != null and luca.hooks() != null and luca.hooks().calls.size() == 1 and luca.hooks().calls[0].reaction and luca.hooks().calls[0].act.mark == "关北一章", "卢卡 greets the player at the gate (only once he is there)")
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter7")
	_check(quest != null and quest.steps.size() == 2 and quest.steps[0].condition.key == "到了番坊" and quest.steps[1].condition.key == "见了安敦", "the chapter so far: the way down, then 安敦 (番坊 B)")
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_FANFANG_A_V1, "番坊 A's world revision is current")


## From the path outside 忘情谷: south down the 海崖道 to the dock and the shed, into the bazaar
## and the 市舶司 and back; the people at their posts; then (TEST-ONLY: 关北 done) 卢卡 at the gate.
func _test_walk(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var valley: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return")
	_check(valley != null and valley.map_id() == &"village.main", "on the path outside 忘情谷")
	await _settle(tree)
	var road: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.cliff_top")
	_check(road != null and road.map_id() == &"fanfang.cliff_road" and state.marks.get("到了番坊", 0) == 1, "south out of the woods onto the 海崖口; 到了番坊 marked by the way")
	_check(road.select_landmark(&"fanfang.cliff_top.landmark.shrine") and road.inspect_selected() and ui.inspection_text.text.contains("平安"), "the sea god's niche: 平安")
	ui.dismiss_current_panel()
	await _settle(tree)
	_check(await MapPlaces.drive_through(tree, road, [&"fanfang.cliff_path"]), "down onto the cliff road")
	_check(road.select_landmark(&"fanfang.cliff_path.landmark.sea") and road.inspect_selected() and ui.inspection_text.text.contains("看不见对岸"), "the sea looked at")
	ui.dismiss_current_panel()
	await _settle(tree)
	var porter: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.cliff_path.porter.1")
	_check(porter != null and await MapPlaces.drive(tree, road, MapPlaces.spot(road, &"fanfang.cliff_path", road.runtime_body_for_character(porter.character_id).global_position + Vector2(0, 60), 64.0)) and road.select_npc(porter.character_id), "beside a salt porter")
	_check(road.ask_selected("盐").any(func(line: String) -> bool: return line.contains("玉螺湖村")), "the salt goes up to 玉螺湖村")
	_check(await MapPlaces.drive_through(tree, road, [&"fanfang.cliff_foot"]), "down to the cliff's foot")
	var dock: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(dock != null and dock.map_id() == &"fanfang.port", "down the steps onto the quay")
	_check(dock.select_landmark(&"fanfang.dock.landmark.boats") and dock.inspect_selected() and ui.inspection_text.text.contains("南边来的商人"), "the boats are others'")
	ui.dismiss_current_panel()
	await _settle(tree)
	var clerk: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.dock.tax_clerk.1")
	_check(clerk != null and await MapPlaces.drive(tree, dock, MapPlaces.spot(dock, &"fanfang.dock", dock.runtime_body_for_character(clerk.character_id).global_position + Vector2(0, 60), 64.0)) and dock.select_npc(clerk.character_id), "beside the tax clerk")
	_check(dock.ask_selected("大秦人").any(func(line: String) -> bool: return line.contains("两面大盾")), "he points the way to 铁盾会")
	_check(await MapPlaces.drive_through(tree, dock, [&"fanfang.shed", &"fanfang.dock"]), "west into the shed and back")
	var bazaar: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and bazaar.map_id() == &"fanfang.bazaar", "east into the bazaar")
	for zone: StringName in PEOPLE:
		for kind: StringName in PEOPLE[zone]:
			_check(_count_in(session, zone, kind) == PEOPLE[zone][kind], "%d %s in %s" % [PEOPLE[zone][kind], kind, zone])
	_check(_count_in(session, &"fanfang.bazaar_north", &"native.npc.luca") == 0, "卢卡 is not here before 关北")
	var teller: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.bazaar_west.storyteller.1")
	_check(teller != null and await MapPlaces.drive(tree, bazaar, MapPlaces.spot(bazaar, &"fanfang.bazaar_west", bazaar.runtime_body_for_character(teller.character_id).global_position + Vector2(0, -60), 64.0)) and bazaar.select_npc(teller.character_id), "beside the old storyteller")
	_check(bazaar.ask_selected("大秦").any(func(line: String) -> bool: return line.contains("已经没有了")), "the empire is gone")
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "east along the street and up the lane to 铁盾会's gate")
	_check(bazaar.select_landmark(&"fanfang.bazaar_north.landmark.shields") and bazaar.inspect_selected() and ui.inspection_text.text.contains("鹰"), "the two great shields")
	ui.dismiss_current_panel()
	await _settle(tree)
	var office: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.office")
	_check(office != null and office.map_id() == &"fanfang.customs", "into the 市舶司")
	_check(office.select_landmark(&"fanfang.office.landmark.notice") and office.inspect_selected() and ui.inspection_text.text.contains("於兰天武"), "京师's wanted notice, copied")
	ui.dismiss_current_panel()
	await _settle(tree)
	var papers: ActService = office.service(&"fanfang.office.papers") as ActService
	_check(papers != null and await MapPlaces.drive(tree, office, MapPlaces.service_spot(office, &"fanfang.office.papers")) and papers.in_reach() and papers.verb() == "看", "兵部文书 · 看 at the desk")
	papers.interact()
	await _settle(tree)
	_check(state.marks.get("看过清人文书", 0) == 1 and not state.marks.has("看出文书是假的") and ui.log_lines().any(func(line: String) -> bool: return line.contains("着市舶司即日清出")), "the order read; without the 印色 nothing is seen in the seal")
	state.marks["学过印色"] = 1 # TEST-ONLY: 关北 A's 比印 (story_chapter6_test)
	papers.interact()
	await _settle(tree)
	_check(state.marks.get("看出文书是假的", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("印是假的")), "with the 印色 learned the seal is seen to be false")
	var feng: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.office.feng_lu.1")
	_check(feng != null and await MapPlaces.drive(tree, office, MapPlaces.spot(office, &"fanfang.office", office.runtime_body_for_character(feng.character_id).global_position + Vector2(-60, 0), 48.0)) and office.select_npc(feng.character_id), "beside 冯禄")
	_check(office.ask_selected("文书").any(func(line: String) -> bool: return line.contains("懂什么印色")), "冯禄 bristles at one who has seen through the seal")
	_check(await MapPlaces.drive_through(tree, office, [&"fanfang.yard", &"fanfang.office"]), "into the back yard and back")
	# Save and Continue from the office.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "a save from the 市舶司")
	if snapshot != null:
		var walker: RefCounted = Work.new()
		await walker.round_trip(tree, session, snapshot, "番坊 A in the 市舶司")
		_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))
	# 关北 done (TEST-ONLY): 卢卡 stands at the gate and greets the player once.
	state.marks["关北一章"] = 1
	var dock_again: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(dock_again != null and dock_again.map_id() == &"fanfang.port", "back out to the dock")
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and _count_in(session, &"fanfang.bazaar_north", &"native.npc.luca") == 1, "after 关北, 卢卡 at 铁盾会's gate")
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "up the lane to him")
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("卢卡在番坊见到你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("路，不近")), "卢卡: 你来了。路，不近。")
	var luca: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.bazaar_north.luca.1")
	_check(luca != null and await MapPlaces.drive(tree, bazaar, MapPlaces.spot(bazaar, &"fanfang.bazaar_north", bazaar.runtime_body_for_character(luca.character_id).global_position + Vector2(0, 60), 64.0)) and bazaar.select_npc(luca.character_id), "beside 卢卡")
	_check(bazaar.ask_selected("番坊").any(func(line: String) -> bool: return line.contains("就是这里")), "卢卡 on 番坊, now he is here")
	state.marks.erase("关北一章")


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
