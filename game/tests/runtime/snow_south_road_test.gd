extends RefCounted

## Snow's south road and shops (4B): sroad2-5, the school (书院), the smithy, the
## herbshop, the post office and the Hockshop storage room are zones of the
## outdoor map, walked into from their ES2 neighbours. Their NPCs come from the
## importer; the herbshop and the smithy sell through vendor services (the smith
## at his own buy_object() price), and what they sell can be sold at the Hockshop.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const NEW_ZONES: Array[StringName] = [&"snow.sroad2", &"snow.sroad3", &"snow.sroad4", &"snow.sroad5", &"snow.school",
	&"snow.smithy", &"snow.herbshop", &"snow.postoffice", &"snow.hockshop2"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_rooms_and_text()
	_test_every_zone_is_reachable_on_tiles(session)
	_test_authored_facts(session)
	await _test_walk_the_south_road(tree, session)
	session.free()
	await tree.process_frame
	await _test_shops(tree)
	return {"assertions": _count, "failures": _failures}


func _test_rooms_and_text() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for zone_id: StringName in NEW_ZONES:
		var zone: ZoneDefinition = catalog.zone(zone_id)
		var room: RoomDefinition = catalog.room(StringName("es2:d/snow/" + String(zone_id).get_slice(".", 1)))
		_check(zone != null and zone.map_id == &"snow.outdoor" and zone.room_ids() == [room.room_id], "%s is one ES2 room on the outdoor map" % zone_id)
	_check(catalog.room(&"es2:d/snow/sroad3").short == "青石官道" and catalog.room(&"es2:d/snow/school").short == "书院", "room titles verbatim")
	_check(catalog.room(&"es2:d/snow/hockshop2").long.begins_with("这里是丰登当铺的储藏室"), "room text verbatim")
	# Exits out of Snow stay closed: d/canyon and d/waterfog are not migrated.
	_check(catalog.room(&"es2:d/snow/sroad4").exits().get("southwest") == &"es2:d/canyon/road" and catalog.room(&"es2:d/canyon/road") == null, "sroad4 southwest leads nowhere yet")
	_check(catalog.room(&"es2:d/snow/sroad5").exits().get("west") == &"es2:d/waterfog/sroad1" and catalog.portals_for_map(&"snow.outdoor").size() == 3, "sroad5 west leads nowhere yet; no portal but the Inn, Old Pine and (4C) the weapon storage's way down")
	# herbshop1.c (药铺密室) has no entrance anywhere in the mudlib.
	_check(catalog.room(&"es2:d/snow/herbshop1") == null, "the herbshop's secret room is not migrated")


## Painted walkable tiles join the square to every zone of the map (doors are tiles
## too: their bodies open and close).
func _test_every_zone_is_reachable_on_tiles(session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"snow.outdoor")
	var layers: Array[TileMapLayer] = TerrainProbe.layers(map)
	var walkable: Dictionary[Vector2i, bool] = {}
	var blocked: Dictionary[Vector2i, bool] = {}
	for layer: TileMapLayer in layers:
		for cell: Vector2i in layer.get_used_cells():
			if layer.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0:
				blocked[cell] = true
			else:
				walkable[cell] = true
	var start: Vector2i = layers[0].local_to_map(Vector2.ZERO)
	var reached: Dictionary[Vector2i, bool] = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if walkable.has(next) and not blocked.has(next) and not reached.has(next):
				reached[next] = true
				frontier.append(next)
	for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
		var center: Vector2 = zone.position + (zone.get_node("CollisionShape2D") as Node2D).position
		_check(reached.has(layers[0].local_to_map(center)), "%s is joined to the square on the tiles" % zone.zone_id)


func _test_authored_facts(session: OldPineWorldSessionController) -> void:
	var outdoor: WorldMapController = session.world_map_of(&"snow.outdoor")
	# The dog's presence circle (the native "same room") reaches no player standing in sroad3 or sroad5.
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(&"snow.outdoor.sroad4.crazy_dog")
	var dog_at: Vector2 = outdoor.resolve_spawn_marker(&"snow.sroad4.crazy_dog.1").global_position
	for zone_id: StringName in [&"snow.sroad3", &"snow.sroad5"]:
		var reach: Rect2 = _zone_rect(outdoor, zone_id).grow(17.0)
		var nearest: Vector2 = dog_at.clamp(reach.position, reach.end)
		_check(dog_at.distance_to(nearest) > spawn.presence_radius, "疯狗 cannot notice a player in %s (%.0f px)" % [zone_id, dog_at.distance_to(nearest)])
	for point: int in [1, 2]:
		var farmer: NpcRuntimeState = outdoor.find_resident_npc(StringName("snow.sroad2.farmer.%d.character" % point))
		_check(farmer != null and farmer.definition().attitude == NpcDefinition.Attitude.FRIENDLY and farmer.armor.occupied_slots().size() == 2, "farmer %d wears raincoat and sandals" % point)
		_check(farmer != null and farmer.armor.aggregate_numeric_modifiers().armor == 2 and farmer.armor.aggregate_numeric_modifiers().personality == -1, "蓑衣: armor 2, personality -1")
	var dog: NpcRuntimeState = outdoor.find_resident_npc(&"snow.sroad4.crazy_dog.1.character")
	_check(dog != null and dog.definition().race_id == &"beast" and dog.definition().has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE), "疯狗 is an aggressive beast")
	_check(dog != null and dog.definition().authored_combat_facts().verbs() == [&"bite", &"claw"] and dog.character_state.progression.combat_experience == 100, "疯狗 bites and claws, 100 exp")
	var teacher: NpcRuntimeState = outdoor.find_resident_npc(&"snow.school.teacher.1.character")
	_check(teacher != null and teacher.definition().short_name() == "教书先生 魏无极" and teacher.character_state.skills.raw_level(&"literate") == 60, "魏无极: title and literate 60")
	var woodcutter: NpcRuntimeState = outdoor.find_resident_npc(&"snow.herbshop.woodcutter.1.character")
	_check(woodcutter != null and woodcutter.character_state.equipment.primary_weapon_skill_type() == &"axe" and woodcutter.character_state.equipment.is_secondary_hand_empty(), "樵夫 wields the lumber axe")
	var officer: NpcRuntimeState = outdoor.find_resident_npc(&"snow.postoffice.post_officer.1.character")
	_check(officer != null and officer.definition().short_name() == "雪亭驿长 杜宽" and officer.world_location().zone_id == &"snow.postoffice", "杜宽 in the post office")
	# The herbalist and the smith are their shops' services until 4E.
	for id: StringName in [&"snow.npc.herbalist", &"snow.npc.smith"]:
		_check(GameContent.catalog().npc(id) == null, "%s has no body yet" % id)


## Inn → square → sroad1 → sroad2 (farmers) → the school and back → sroad3 → sroad4,
## where the crazy dog attacks (set("attitude", "aggressive")).
func _test_walk_the_south_road(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	await _leave_inn(tree, session)
	var walker: RefCounted = Work.new()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_down", 552, 1)
	await walker.walk_to(tree, session, "move_left", -320, 0)
	_check(player.world_location().zone_id == &"snow.sroad2", "west of sroad1 is sroad2")
	await walker.walk_to(tree, session, "move_down", 760, 1)
	_check(player.world_location().zone_id == &"snow.school", "south through the school door")
	await walker.walk_to(tree, session, "move_up", 552, 1)
	await walker.walk_to(tree, session, "move_left", -900, 0)
	_check(player.world_location().zone_id == &"snow.sroad3", "on to the 青石官道")
	await tree.physics_frame
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the crazy dog does not notice anyone at sroad3's west end")
	_check(walker._failures.is_empty(), "walked: " + str(walker._failures))
	await walker.walk(tree, session, "move_left", 160)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var opponents: Array[StringName] = []
	if coordinator.has_active_encounter():
		for participant: CombatParticipant in coordinator.active_encounter().participants():
			opponents.append(participant.participant_id)
	_check(player.world_location().zone_id == &"snow.sroad4" and opponents.has(&"snow.sroad4.crazy_dog.1.character"), "the crazy dog attacks in sroad4: " + str(opponents))


## Buy once in each shop, sell both at the Hockshop, walk into the post office and
## the storage room, and Save/Continue keeps it all exactly.
func _test_shops(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 25, &"test.4b.silver")
	await _leave_inn(tree, session)
	var walker: RefCounted = Work.new()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = session.active_map() as WorldMapController
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_up", -752, 1)
	await walker.walk_to(tree, session, "move_left", -300, 0)
	_check(player.world_location().zone_id == &"snow.smithy", "west of mstreet2 is the smithy")
	var smith: VendorService = map.service(&"snow.smithy.smith") as VendorService
	_check(smith.in_reach() and smith.context_title() == "王铁匠 · 购买", "the smith's service is at the forge: " + smith.context_title())
	_check((smith.goods_rows.get_child(0) as Button).text == "铁锤 · 3两银子 · 买一把", "price as vendor.c lists it")
	var hammer: VendorPurchaseResult = smith.request_purchase("铁锤")
	_check(hammer.delivered and hammer.price == 300 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == 22, "a hammer for 300 coins (smith.c buy_object)")
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_up", -1008, 1)
	await walker.walk_to(tree, session, "move_left", -272, 0)
	_check(player.world_location().zone_id == &"snow.herbshop", "west of mstreet3 is the herbshop")
	var herbalist: VendorService = map.service(&"snow.herbshop.herbalist") as VendorService
	_check(herbalist.in_reach() and herbalist.goods_rows.get_child_count() == 1 and (herbalist.goods_rows.get_child(0) as Button).text == "金疮药 · 20两银子 · 买一颗", "the counter sells 金疮药 only")
	var medicine: VendorPurchaseResult = herbalist.request_purchase("medicine")
	_check(medicine.delivered and medicine.price == 2000 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == 2, "金疮药 for its value, 2000 coins")
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_up", -1296, 1)
	await walker.walk_to(tree, session, "move_left", -300, 0)
	_check(player.world_location().zone_id == &"snow.postoffice", "west of mstreet4 is the post office")
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_down", -1000, 1)
	await walker.walk_to(tree, session, "move_right", 40, 0)
	_check(map.open_door(&"snow.hockshop.door"), "the Hockshop door opens")
	await walker.walk_to(tree, session, "move_right", 330, 0)
	_check(player.world_location().zone_id == &"snow.hockshop", "in the Hockshop")
	var hockshop: HockshopService = map.service(&"snow.hockshop.counter") as HockshopService
	hockshop.interact()
	for row: Array in [[medicine.item_id, 1600], [hammer.item_id, 2]]:
		hockshop.select_item(row[0])
		hockshop.request_confirmation()
		hockshop.confirm_sale()
		_check(hockshop.last_sell != null and hockshop.last_sell.payout.delivered_value == row[1] and not session.inventory_state().is_registered(row[0]), "sold at the Hockshop for %d" % row[1])
	session.shared_ui().dismiss_current_panel()
	await tree.physics_frame
	_check(not hockshop.panel.visible, "the Hockshop panel closes")
	await walker.walk_to(tree, session, "move_up", -1100, 1)
	await walker.walk_to(tree, session, "move_right", 480, 0)
	await walker.walk_to(tree, session, "move_down", -1000, 1)
	await walker.walk_to(tree, session, "move_right", 650, 0)
	_check(player.world_location().zone_id == &"snow.hockshop2", "through the curtain into the storage room")
	_check(walker._failures.is_empty(), "walked: " + str(walker._failures))
	await walker.round_trip(tree, session, Work.capture(session), "4B shops")
	_count += walker._count
	_failures.append_array(walker._failures)
	session.free()
	await tree.process_frame


func _zone_rect(map: WorldMapController, zone_id: StringName) -> Rect2:
	for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
		if zone.zone_id == zone_id:
			var shape: CollisionShape2D = zone.get_node("CollisionShape2D") as CollisionShape2D
			var size: Vector2 = (shape.shape as RectangleShape2D).size
			return Rect2(zone.position + shape.position - size / 2.0, size)
	return Rect2()


func _leave_inn(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("4B south road: " + label)
