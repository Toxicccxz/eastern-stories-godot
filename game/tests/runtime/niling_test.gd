extends RefCounted

## 逆灵宫 A and B (DECISIONS「逆灵宫 A」「逆灵宫 B」): the region's four maps — the crack's top with
## the winch and the goods road north (niling.slope), the 黑砖山门, the yard and the 货栈
## (niling.gate), the 前殿, 丹房 and 账房 (niling.hall) and the dungeon under them
## (niling.dungeon) — their thirteen native rooms, the ways between them and back out, walked in
## the 黑冠 (the 道士 take the wearer for their own), the people at their posts, the doors (the
## 殿门; the cells' iron doors with their key), the landmarks' texts. Walks use the move actions
## (MapPlaces). The story's three ways up the crack are story_chapter3_test; the hall, the ledger
## and the dungeon story_chapter3b_test.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"niling.slope": 3, &"niling.gate": 3, &"niling.hall": 3, &"niling.dungeon": 4, &"niling.rear": 1, &"niling.master_house": 1, &"niling.backhill": 2}
const CROWN: StringName = &"native:niling/black_crown"
## Where each kind stands.
const PEOPLE: Dictionary = {
	&"niling.winch": {&"native.npc.niling_winch_taoist": 1},
	&"niling.gatehouse": {&"native.npc.niling_gatekeeper": 1},
	&"niling.yard": {&"native.npc.niling_gate_guard": 2},
	&"niling.store": {&"native.npc.niling_store_taoist": 1},
	&"niling.front": {&"native.npc.niling_chanter": 4, &"native.npc.niling_lead_chanter": 1},
	&"niling.counting": {&"native.npc.niling_steward": 1},
	&"niling.corridor": {&"native.npc.niling_jailer": 2, &"native.npc.niling_jailer_keyed": 2},
	&"niling.altar": {&"native.npc.shang_jue": 1, &"native.npc.xuan_mingzi": 1, &"native.npc.headless_shade": 1, &"native.npc.hell_runner": 2},
	&"niling.cliff_path": {&"native.npc.xuan_mingzi_cliff": 1},
	&"niling.cell_huo": {&"native.npc.huo_zheng": 1},
	&"niling.cell_shitou": {&"native.npc.shitou": 1},
	&"niling.cell_others": {&"native.npc.guanbei_corvee": 2},
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
		if String(zone.zone_id).begins_with("niling."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null and String(zone.room_ids()[0]).begins_with("native:niling/"), "%s: one native room" % zone.zone_id)
	_check(maps == MAPS, "seventeen native rooms on seven maps: %s" % maps)
	_check(catalog.region(&"niling").display_name == "逆灵宫", "the region is 逆灵宫")
	_check(catalog.map(&"niling.gate").interior and catalog.map(&"niling.hall").interior and catalog.map(&"niling.dungeon").interior and not catalog.map(&"niling.slope").interior, "the gate, the hall and the dungeon are indoors, the slope is outdoors")
	_check(catalog.portal(&"niling.yard.north").destination_zone_id == &"niling.front" and catalog.portal(&"niling.front.south").destination_zone_id == &"niling.yard" and catalog.door(&"niling.front.door").zone_ids() == [&"niling.yard", &"niling.front"] and catalog.door(&"niling.front.door").map_ids() == [&"niling.gate", &"niling.hall"], "the 殿门 on the way from the yard into the 前殿, placed by both maps")
	_check(catalog.portal(&"niling.alchemy.down").destination_zone_id == &"niling.corridor" and catalog.portal(&"niling.corridor.up").destination_zone_id == &"niling.alchemy", "the stair from the 丹房 down to the passage, and up")
	for cell: StringName in [&"niling.cell_huo", &"niling.cell_shitou", &"niling.cell_others"]:
		var iron: DoorDefinition = catalog.door(StringName(String(cell) + ".door"))
		_check(iron != null and iron.key == &"native:niling/cell_key" and not iron.closable and not iron.locked_line.is_empty() and iron.zone_ids() == [&"niling.corridor", cell] and catalog.room(&"native:niling/corridor").exits().values().has(String(StringName("native:niling/" + String(cell).trim_prefix("niling.")))), "%s: an iron door off the passage, the 地牢钥匙 its key" % cell)
	_check(catalog.item_spawn(&"niling.counting.ledger") != null and catalog.item_spawn(&"niling.counting.papers") != null and catalog.item(&"native:niling/tribute_ledger").act != null and catalog.item(&"native:niling/tribute_ledger").act.verb == "翻看" and catalog.item(&"native:niling/war_ministry_papers").act.verb == "翻看", "the ledger and the papers on the 账房's desk, each with 翻看")
	_check(catalog.landmark(&"niling.front.landmark.scripture").description.contains("字像是在动") and catalog.landmark(&"niling.alchemy.landmark.jars").description.contains("傅家坡 · 待") and catalog.landmark(&"niling.corridor.landmark.scratches").description.contains("最后一组只有三道"), "the scripture, the jars and the tally can be looked at")
	for peaceful: StringName in [&"native.npc.huo_zheng", &"native.npc.shitou", &"native.npc.guanbei_corvee"]:
		_check(not catalog.npc(peaceful).attacks_on_sight({}, CharacterState.new(), true), "%s attacks nobody" % peaceful)
	_check(catalog.npc(&"native.npc.huo_zheng").title == "野羊山大寨主" and catalog.npc(&"native.npc.shitou").age == 7, "霍铮 the 大寨主; 石头 seven")
	_check(catalog.spawn(&"niling.corridor.jailers").until != null and catalog.spawn(&"niling.corridor.jailers").until.key == "见过唤首" and catalog.spawn(&"niling.corridor.jailers_keyed").present.key == "见过唤首", "the keyless jailers stand until the 唤首 scene, the keyed ones from it")
	_check(catalog.door(&"niling.master.door").found_by == "见过唤首" and not catalog.door(&"niling.master.door").operable and catalog.npc(&"native.npc.shang_jue").hooks().scene_mark == "见过唤首", "the 黑门 is found by 商玦's scene")
	_check(catalog.spawn(&"niling.altar.hell_runners").summoned and catalog.spawn(&"niling.altar.hell_runners").cleared_mark == "祭坛的鬼卒倒了" and catalog.spawn(&"niling.altar.shade").summoned, "the ghouls and the shade are summoned by the scene")
	_check(catalog.spawn(&"niling.cliff_path.xuan_mingzi").until.key == "main.chapter3/choice/rescue" and catalog.spawn(&"niling.cell_huo.huo_zheng").until.key == "main.chapter3/choice/chase" and catalog.item_spawn(&"niling.cell_huo.body").present.key == "main.chapter3/choice/chase", "the two endings exclude each other on the stage")
	_check(catalog.npc(&"native.npc.xuan_mingzi_cliff").hooks().spared_drop == &"native:niling/scroll_fragment" and catalog.npc(&"native.npc.hell_runner").hooks().vanishes and catalog.npc(&"native.npc.huo_zheng").hooks().follows_every_way, "玄冥子 drops the 残卷 when spared; a 鬼卒 leaves no corpse; 霍铮 follows every way")
	_check(WorldRoute.moves_to(catalog, catalog.service(&"niling.master.back_door")) == &"niling.backhill" and catalog.portal(&"niling.cliff_path.south").destination_zone_id == &"niling.master", "the small door out onto the cliff path, and back")
	_check(catalog.portal(&"niling.goods_path.north").destination_zone_id == &"niling.gatehouse" and catalog.portal(&"niling.gatehouse.south").destination_zone_id == &"niling.goods_path", "the goods road north into the gate, and back")
	_check(catalog.portal(&"niling.side_door.north").destination_zone_id == &"niling.store" and catalog.portal(&"niling.store.south").destination_zone_id == &"niling.side_door", "the side door into the 货栈, and back")
	_check(catalog.room(&"native:niling/goods_path").exits().get("east") == "native:niling/side_door" and catalog.room(&"native:niling/yard").exits().get("east") == "native:niling/store", "the branch east to the side door; the yard opens east into the 货栈")
	_check(WorldRoute.moves_to(catalog, catalog.service(&"niling.winch.rope")) == &"goathill.mountain" and WorldRoute.moves_to(catalog, catalog.service(&"goathill.mroad4.rope")) == &"niling.slope" and WorldRoute.moves_to(catalog, catalog.service(&"goathill.mroad4.tarp")) == &"niling.slope", "the rope and the oil-cloth are ways between the turn and the slope (WorldRoute)")
	_check(catalog.landmark(&"niling.yard.landmark.burner").description.contains("烧着的不是香") and catalog.landmark(&"niling.yard.landmark.banners").description.contains("黑布的幡") and catalog.landmark(&"niling.winch.landmark.crates").description.contains("野羊寨的记号"), "the burner, the banners and the boxes can be looked at")
	var crown: ItemContentDefinition = catalog.item(CROWN)
	_check(crown != null and crown.armor_definition() != null and crown.armor_definition().armor_type == &"head", "the 黑冠 is worn on the head")
	for definition_id: StringName in [&"native.npc.niling_gatekeeper", &"native.npc.niling_gate_guard", &"native.npc.niling_store_taoist", &"native.npc.niling_chanter", &"native.npc.niling_lead_chanter", &"native.npc.niling_steward", &"native.npc.niling_jailer"]:
		var npc: NpcDefinition = catalog.npc(definition_id)
		_check(npc.dealings().ignores_when != null and npc.dealings().ignores_when.when == JournalEntryDefinition.When.WEARING and npc.dealings().ignores_when.key == String(CROWN), "%s takes one in the 黑冠 for its own" % definition_id)
		_check(npc.attacks_on_sight({}, CharacterState.new(), true) and not npc.attacks_on_sight({}, CharacterState.new(), true, true), "%s attacks a stranger on sight, not one it ignores" % definition_id)
	_check(not catalog.npc(&"native.npc.niling_winch_taoist").attacks_on_sight({}, CharacterState.new(), true), "the 绞盘道士 attacks nobody")


## In at the rope's top, north along the goods road through the gate into the yard and the 货栈,
## through the 殿门 into the 前殿 and back, out of the gate and down to the winch, in the 黑冠
## (nobody falls on the player).
func _test_walk(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.handoff_to(&"niling.slope", &"niling.winch", &"niling.winch", &"niling.winch.rope_arrival").succeeded(), "at the rope's top")
	var slope: WorldMapController = session.active_map() as WorldMapController
	await tree.physics_frame
	var crown: StringName = slope.give_new_item_to_player(CROWN)
	_check(not crown.is_empty() and session.wear_player_item(crown).succeeded and session.player_worn_item_ids().has(CROWN), "the 黑冠 on (TEST-ONLY: given)")
	_people(session)
	_check(await MapPlaces.drive_to_zone(tree, slope, &"niling.goods_path"), "north onto the goods road")
	_check(await MapPlaces.drive_to_zone(tree, slope, &"niling.side_door"), "east to the side door")
	_check(await MapPlaces.take_passage(tree, slope, &"niling.side_door.north"), "in at the side door")
	var gate: WorldMapController = session.active_map() as WorldMapController
	await tree.physics_frame
	_check(gate != null and gate.map_id() == &"niling.gate" and player.world_location().zone_id == &"niling.store", "in the 货栈: %s" % [player.world_location().zone_id])
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the 货栈道士 lets one in the crown be")
	_check(await MapPlaces.drive_to_zone(tree, gate, &"niling.yard"), "west into the yard")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the guards too")
	var ui: SharedGameplayUI = session.shared_ui()
	_check(gate.select_landmark(&"niling.yard.landmark.burner") and gate.inspect_selected() and ui.inspection_text.text.contains("烧着的不是香"), "the burner in the yard's middle, looked at: %s" % ui.inspection_text.text.left(30))
	ui.dismiss_current_panel()
	await tree.physics_frame
	_check(await MapPlaces.drive(tree, gate, MapPlaces.door_spot(gate, &"niling.front.door", &"niling.yard")) and gate.open_door(&"niling.front.door") and await MapPlaces.take_passage(tree, gate, &"niling.yard.north"), "the 殿门 opened and the 前殿 entered")
	var hall: WorldMapController = session.active_map() as WorldMapController
	await tree.physics_frame
	_check(hall != null and hall.map_id() == &"niling.hall" and player.world_location().zone_id == &"niling.front", "in the 前殿: %s" % [player.world_location().zone_id])
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the five at their cushions let one in the crown be")
	_check(await MapPlaces.take_passage(tree, hall, &"niling.front.south"), "back out into the yard")
	gate = session.active_map() as WorldMapController
	await tree.physics_frame
	_check(gate != null and gate.map_id() == &"niling.gate" and player.world_location().zone_id == &"niling.yard", "in the yard again: %s" % [player.world_location().zone_id])
	_check(await MapPlaces.drive_to_zone(tree, gate, &"niling.gatehouse"), "south into the gate tower")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "and the 门房")
	_check(gate.select_landmark(&"niling.yard.landmark.burner") and not gate.landmark_available(GameContent.catalog().landmark(&"niling.yard.landmark.burner")), "the burner is the yard's: not to be used from the gate tower")
	_check(await MapPlaces.take_passage(tree, gate, &"niling.gatehouse.south"), "out of the gate")
	slope = session.active_map() as WorldMapController
	await tree.physics_frame
	_check(slope != null and slope.map_id() == &"niling.slope" and player.world_location().zone_id == &"niling.goods_path", "on the goods road: %s" % [player.world_location().zone_id])
	_check(await MapPlaces.drive_to_zone(tree, slope, &"niling.winch"), "south to the winch")
	_check(await MapPlaces.drive(tree, slope, MapPlaces.service_spot(slope, &"niling.winch.rope")) and (slope.service(&"niling.winch.rope") as ActService).in_reach(), "the rope down within reach")
	_check(Work.capture(session) != null, "Save on the slope")


func _people(session: WorldSessionController) -> void:
	var found: Dictionary = {}
	for map: WorldMapController in session.world_maps():
		if not String(map.map_id()).begins_with("niling."):
			continue
		for npc: NpcRuntimeState in map.npc_runtimes():
			var zone: StringName = npc.world_location().zone_id
			var kinds: Dictionary = found.get(zone, {})
			kinds[npc.definition().definition_id] = kinds.get(npc.definition().definition_id, 0) + 1
			found[zone] = kinds
	_check(found == PEOPLE, "the 道士 at their posts: %s" % [found])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("niling: " + label)
