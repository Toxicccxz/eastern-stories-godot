extends RefCounted

## 逆灵宫 A (DECISIONS「逆灵宫 A」): the region's first two maps — the crack's top with the winch
## and the goods road north (niling.slope) and the 黑砖山门, the yard and the 货栈 (niling.gate)
## — their six native rooms, the ways between them and back out, walked in the 黑冠 (the 道士
## take the wearer for their own), the people at their posts, the landmarks' texts. Walks use
## the move actions (MapPlaces). The story's three ways up the crack are story_chapter3_test.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"niling.slope": 3, &"niling.gate": 3}
const CROWN: StringName = &"native:niling/black_crown"
## Where each kind stands.
const PEOPLE: Dictionary = {
	&"niling.winch": {&"native.npc.niling_winch_taoist": 1},
	&"niling.gatehouse": {&"native.npc.niling_gatekeeper": 1},
	&"niling.yard": {&"native.npc.niling_gate_guard": 2},
	&"niling.store": {&"native.npc.niling_store_taoist": 1},
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
	_check(maps == MAPS, "six native rooms on two maps: %s" % maps)
	_check(catalog.region(&"niling").display_name == "逆灵宫", "the region is 逆灵宫")
	_check(catalog.map(&"niling.gate").interior and not catalog.map(&"niling.slope").interior, "the gate is a building, the slope is outdoors")
	_check(catalog.portal(&"niling.goods_path.north").destination_zone_id == &"niling.gatehouse" and catalog.portal(&"niling.gatehouse.south").destination_zone_id == &"niling.goods_path", "the goods road north into the gate, and back")
	_check(catalog.portal(&"niling.side_door.north").destination_zone_id == &"niling.store" and catalog.portal(&"niling.store.south").destination_zone_id == &"niling.side_door", "the side door into the 货栈, and back")
	_check(catalog.room(&"native:niling/goods_path").exits().get("east") == "native:niling/side_door" and catalog.room(&"native:niling/yard").exits().get("east") == "native:niling/store", "the branch east to the side door; the yard opens east into the 货栈")
	_check(WorldRoute.moves_to(catalog, catalog.service(&"niling.winch.rope")) == &"goathill.mountain" and WorldRoute.moves_to(catalog, catalog.service(&"goathill.mroad4.rope")) == &"niling.slope" and WorldRoute.moves_to(catalog, catalog.service(&"goathill.mroad4.tarp")) == &"niling.slope", "the rope and the oil-cloth are ways between the turn and the slope (WorldRoute)")
	_check(catalog.landmark(&"niling.yard.landmark.burner").description.contains("烧着的不是香") and catalog.landmark(&"niling.yard.landmark.banners").description.contains("黑布的幡") and catalog.landmark(&"niling.winch.landmark.crates").description.contains("野羊寨的记号"), "the burner, the banners and the boxes can be looked at")
	var crown: ItemContentDefinition = catalog.item(CROWN)
	_check(crown != null and crown.armor_definition() != null and crown.armor_definition().armor_type == &"head", "the 黑冠 is worn on the head")
	for definition_id: StringName in [&"native.npc.niling_gatekeeper", &"native.npc.niling_gate_guard", &"native.npc.niling_store_taoist"]:
		var npc: NpcDefinition = catalog.npc(definition_id)
		_check(npc.dealings().ignores_when != null and npc.dealings().ignores_when.when == JournalEntryDefinition.When.WEARING and npc.dealings().ignores_when.key == String(CROWN), "%s takes one in the 黑冠 for its own" % definition_id)
		_check(npc.attacks_on_sight({}, CharacterState.new(), true) and not npc.attacks_on_sight({}, CharacterState.new(), true, true), "%s attacks a stranger on sight, not one it ignores" % definition_id)
	_check(not catalog.npc(&"native.npc.niling_winch_taoist").attacks_on_sight({}, CharacterState.new(), true), "the 绞盘道士 attacks nobody")


## In at the rope's top, north along the goods road through the gate into the yard and the 货栈,
## out of its side door and back down to the winch, in the 黑冠 (nobody falls on the player).
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
