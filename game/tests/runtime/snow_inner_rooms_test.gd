extends RefCounted

## Snow's inner rooms (4C): the Inn's upper floor (inn_2f and three guest rooms
## behind 房门, six rats) is its own map up the stairs; the school's inner yard,
## study, guest room, inner hall and weapon storage are zones of the outdoor map;
## the secret storage below is its own map. Items lie on the floor (竹剑, 牛皮盾,
## the temple's 功德箱) and are picked up with get.c's rules. weapon_storage.c's
## shelf opens the way down after three pushes for ten seconds of world time; it
## does not close on a player below (DECISIONS 4C).
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SHELF: StringName = &"snow.weapon_storage.landmark.shelf"
const DOWN: StringName = &"snow.weapon_storage.down"
const UP: StringName = &"snow.secret_storage.up"
const NEW_ZONES: Dictionary[StringName, StringName] = {
	&"snow.inn_2f": &"snow.inn_upstairs", &"snow.n_room": &"snow.inn_upstairs", &"snow.e_room": &"snow.inn_upstairs",
	&"snow.w_room": &"snow.inn_upstairs", &"snow.inneryard": &"snow.outdoor", &"snow.innerhall": &"snow.outdoor",
	&"snow.guestroom": &"snow.outdoor", &"snow.nyard": &"snow.outdoor", &"snow.weapon_storage": &"snow.outdoor",
	&"snow.secret_storage": &"snow.cellar",
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_passage_rule()
	_test_record_rules()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_tiles(session)
	await _test_upstairs(tree, session)
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	await tree.process_frame
	await _test_inner_school(tree, session)
	await _test_storage_and_cellar(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for zone_id: StringName in NEW_ZONES:
		var zone: ZoneDefinition = catalog.zone(zone_id)
		var room: RoomDefinition = catalog.room(StringName("es2:d/snow/" + String(zone_id).get_slice(".", 1)))
		_check(zone != null and room != null and zone.map_id == NEW_ZONES[zone_id] and zone.room_ids() == [room.room_id], "%s is one ES2 room on %s" % [zone_id, NEW_ZONES[zone_id]])
	_check(catalog.room(&"es2:d/snow/inn_2f").short == "饮风客栈二楼" and catalog.room(&"es2:d/snow/secret_storage").short == "地下密室", "room titles verbatim")
	_check(catalog.room(&"es2:d/snow/weapon_storage").long.begins_with("这是一间堆满各式兵器"), "room text verbatim")
	_check(catalog.zones_adjacent(&"snow.schoolhall", &"snow.inneryard") and catalog.zones_adjacent(&"snow.school2", &"snow.weapon_storage"), "the school's ES2 exits join the new zones")
	_check(not catalog.zones_adjacent(&"snow.weapon_storage", &"snow.secret_storage"), "no static exit to the secret storage")
	var rats: NpcSpawnDefinition = catalog.spawn(&"snow.inn_upstairs.inn_2f.rats")
	_check(rats != null and rats.quantity == 6 and catalog.npc(&"snow.npc.rat").race_id == &"beast", "inn_2f.c: six rats (beasts)")
	_check(catalog.spawn(&"snow.outdoor.nyard.girl") != null and catalog.spawn(&"snow.outdoor.nyard.girl").zone_id == &"snow.nyard", "柳绘心 stands in the study (offense/defense routes)")
	var items: Dictionary[StringName, StringName] = {}
	for map_id: StringName in [&"snow.outdoor", &"snow.cellar", &"snow.inn_upstairs"]:
		for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map_id):
			items[spawn.zone_id] = spawn.item_definition_id
	_check(items == {&"snow.temple": &"es2:d/snow/obj/denotation", &"snow.weapon_storage": &"es2:d/snow/obj/bamboo_sword", &"snow.secret_storage": &"es2:d/snow/obj/shield"}, "items on the floor: 功德箱, 竹剑, 牛皮盾 (no 桃符纸 yet): %s" % items)
	var box: ItemContentDefinition = catalog.item(&"es2:d/snow/obj/denotation")
	_check(box.no_get and box.own_weight == 0 and box.unit == "个", "功德箱: no_get, weight 0 (move.c default)")
	var shield: ItemContentDefinition = catalog.item(&"es2:d/snow/obj/shield")
	_check(shield.armor_definition() != null and shield.armor_definition().armor_type == &"shield" and shield.value == 340, "牛皮盾 is a shield worth 340")
	for door_id: StringName in [&"snow.inn_2f.north_door", &"snow.inn_2f.east_door", &"snow.inn_2f.west_door"]:
		var door: DoorDefinition = catalog.door(door_id)
		_check(door != null and door.display_name == "房门" and door.closable and door.map_id == &"snow.inn_upstairs", "%s: 房门, closable" % door_id)
	var shelf: WorldLandmarkDefinition = catalog.landmark(SHELF)
	_check(shelf.policy == &"hidden_passage" and shelf.setting("pushes") == 3 and shelf.setting("open_seconds") == 10 and shelf.portal_ids() == [DOWN, UP], "the shelf: three pushes, ten seconds, down and back up")
	_check(catalog.hidden_passage_for_portal(DOWN) == shelf and catalog.hidden_passage_for_portal(UP) == shelf and catalog.hidden_passage_for_portal(&"snow.inn.up") == null, "only the shelf's portals are hidden")


## weapon_storage.c do_push()/check_trigger()/close_passage()/reset().
func _test_passage_rule() -> void:
	var passage: HiddenPassageState = HiddenPassageState.new()
	_check(not passage.push(3, 10000) and not passage.push(3, 10000) and passage.left_trigger == 2, "two pushes: still shut")
	_check(passage.push(3, 10000) and passage.is_open and passage.left_trigger == 0 and passage.remaining_ms == 10000, "the third push opens it; left_trigger deleted")
	_check(not passage.advance(9999, false) and passage.is_open, "open for ten seconds")
	_check(not passage.push(3, 10000) and not passage.push(3, 10000) and not passage.push(3, 10000) and passage.left_trigger == 3, "pushes while open keep counting")
	_check(passage.advance(1, false) and not passage.is_open, "close_passage after ten seconds")
	_check(not passage.push(3, 10000) and passage.left_trigger == 4 and not passage.is_open, "the count passed three: no push opens it until the room resets")
	passage.reset()
	passage.push(3, 10000)
	passage.push(3, 10000)
	_check(passage.push(3, 10000) and passage.is_open, "reset() clears left_trigger; three pushes open it again")
	_check(not passage.advance(60000, true) and passage.is_open and passage.remaining_ms == 0, "native: it does not close on a player below")
	_check(passage.advance(0, false) and not passage.is_open, "it closes once nobody is below")
	passage.open_for_player_below()
	_check(passage.is_open and passage.remaining_ms == 0, "Continue below: open, its time up")


func _test_record_rules() -> void:
	var errors: Array[String] = []
	var record: Dictionary = {"id": "x", "zone": "z", "name": "n", "long": "l", "action": "a", "policy": "hidden_passage",
		"portals": ["p", "q"], "messages": {"push": "1", "open": "2", "close": "3"}, "legacy_source": "s"}
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(record, "test", errors))
	_check(not errors.is_empty(), "a hidden passage needs pushes and open_seconds")
	errors.clear()
	record["pushes"] = 3
	record["open_seconds"] = 10
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(record, "test", errors))
	_check(errors.is_empty(), "a complete hidden passage reads: " + str(errors))
	record["policy"] = "portal"
	record["portals"] = ["p"]
	record["messages"] = {}
	errors.clear()
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(record, "test", errors))
	_check(not errors.is_empty(), "pushes belong to hidden passages only")
	errors.clear()
	ItemSpawnDefinition.from_record(ContentRecordReader.new({"id": "s", "item": "i", "map": "m", "zone": "z", "points": ["a", "a"],
		"legacy_room": "r", "legacy_quantity": 2}, "test", errors))
	_check(not errors.is_empty(), "item spawn points are unique")


## Painted walkable tiles join every zone of each map to its entry (doors are floor too).
func _test_tiles(session: OldPineWorldSessionController) -> void:
	for map_id: StringName in [&"snow.outdoor", &"snow.inn_upstairs", &"snow.cellar"]:
		var map: WorldMapController = session.world_map_of(map_id)
		var layers: Array[TileMapLayer] = TerrainProbe.layers(map)
		var walkable: Dictionary[Vector2i, bool] = {}
		for layer: TileMapLayer in layers:
			for cell: Vector2i in layer.get_used_cells():
				if layer.get_cell_tile_data(cell).get_collision_polygons_count(0) == 0:
					walkable[cell] = true
		var entry: Vector2 = map.resolve_spawn_marker(GameContent.catalog().map(map_id).entry_spawn_id).position
		var start: Vector2i = layers[0].local_to_map(entry)
		var reached: Dictionary[Vector2i, bool] = {start: true}
		var frontier: Array[Vector2i] = [start]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if walkable.has(cell + step) and not reached.has(cell + step):
					reached[cell + step] = true
					frontier.append(cell + step)
		for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
			var rect: Rect2 = _zone_rect(map, zone.zone_id)
			var joined: bool = false
			for cell: Vector2i in reached:
				if rect.has_point(layers[0].map_to_local(cell)):
					joined = true
					break
			_check(joined, "%s is joined to %s's entry on the tiles" % [zone.zone_id, map_id])


## Inn → up the stairs → the three rooms behind their doors → down again.
func _test_upstairs(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var walker: RefCounted = Work.new()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	await walker.walk_to(tree, session, "move_right", 336, 0)
	await _walk_until_map(tree, session, "move_up", &"snow.inn_upstairs")
	_check(session.active_map_id() == &"snow.inn_upstairs" and player.world_location().zone_id == &"snow.inn_2f", "up the Inn's stairs to 饮风客栈二楼")
	var map: WorldMapController = session.active_map() as WorldMapController
	var rats: int = 0
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"snow.npc.rat" and npc.world_location().zone_id == &"snow.inn_2f":
			rats += 1
	_check(rats == 6, "six rats in the corridor: %d" % rats)
	await tree.physics_frame
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the rats leave the player be")
	await walker.walk_to(tree, session, "move_up", -60, 1)
	await walker.walk(tree, session, "move_up", 40)
	_check(player.world_location().zone_id == &"snow.inn_2f" and map.player_body.position.y > -110, "the north door is shut (DOOR_CLOSED)")
	_check(map.interaction_title() == "打开房门" and map.open_door(&"snow.inn_2f.north_door"), "open the north 房门")
	await walker.walk_to(tree, session, "move_up", -250, 1)
	_check(player.world_location().zone_id == &"snow.n_room", "into the north guest room")
	_check(session.shared_ui().log_lines().back().begins_with("【客房】这是一间打扫得相当乾净的客房"), "the room's text on arrival")
	await walker.walk_to(tree, session, "move_down", 64, 1)
	for side: Array in [[&"snow.inn_2f.east_door", "move_right", 300, &"snow.e_room", "move_left", 0], [&"snow.inn_2f.west_door", "move_left", -300, &"snow.w_room", "move_right", 0]]:
		await walker.walk_to(tree, session, side[1], (side[2] as int) / 2, 0)
		_check(map.open_door(side[0]), "open %s" % side[0])
		await walker.walk_to(tree, session, side[1], side[2], 0)
		_check(player.world_location().zone_id == side[3], "into %s" % side[3])
		await walker.walk_to(tree, session, side[4], side[5], 0)
	await _walk_until_map(tree, session, "move_down", &"snow.inn")
	_check(session.active_map_id() == &"snow.inn" and player.world_location().zone_id == &"snow.inn.main_floor", "down the stairs into the Inn")
	_check(walker._failures.is_empty(), "walked: " + str(walker._failures))


## Inn → square → the school → the inner yard and its four neighbours.
func _test_inner_school(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var walker: RefCounted = Work.new()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	await walker.walk(tree, session, "move_right", 125)
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_up", -400, 1)
	await walker.walk_to(tree, session, "move_right", 330, 0)
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(map.open_door(&"snow.school.gate"), "the school gate opens")
	await walker.walk_to(tree, session, "move_right", 960, 0)
	await walker.walk_to(tree, session, "move_down", -320, 1)
	await walker.walk_to(tree, session, "move_right", 1300, 0)
	_check(player.world_location().zone_id == &"snow.inneryard", "east of the hall is the inner yard (天井)")
	await walker.walk_to(tree, session, "move_right", 1408, 0)
	await walker.walk_to(tree, session, "move_down", -100, 1)
	_check(player.world_location().zone_id == &"snow.guestroom", "south of the yard is the guest room")
	# Around the pillar (石柱) in the middle of the yard.
	await walker.walk_to(tree, session, "move_up", -320, 1)
	await walker.walk_to(tree, session, "move_right", 1500, 0)
	await walker.walk_to(tree, session, "move_up", -470, 1)
	await walker.walk_to(tree, session, "move_left", 1408, 0)
	await walker.walk_to(tree, session, "move_up", -650, 1)
	_check(player.world_location().zone_id == &"snow.nyard", "north of the yard is the study (书房), empty for now")
	await walker.walk_to(tree, session, "move_down", -470, 1)
	await walker.walk_to(tree, session, "move_right", 1500, 0)
	await walker.walk_to(tree, session, "move_down", -400, 1)
	await walker.walk_to(tree, session, "move_right", 1800, 0)
	_check(player.world_location().zone_id == &"snow.innerhall", "east of the yard is the inner hall")
	await walker.walk_to(tree, session, "move_left", 1500, 0)
	await walker.walk_to(tree, session, "move_down", -320, 1)
	await walker.walk_to(tree, session, "move_left", 960, 0)
	await walker.walk_to(tree, session, "move_up", -400, 1)
	await walker.walk_to(tree, session, "move_left", 760, 0)
	_check(player.world_location().zone_id == &"snow.school2", "back in the practice yard")
	_check(walker._failures.is_empty(), "walked: " + str(walker._failures))


## Pick up the 竹剑 (busy first refuses), push the shelf three times standing on
## the shut floor, step off and go down for the 牛皮盾 (too heavy first) and back
## up; the passage then closes. Save/Continue keeps the floor and the way back.
## Holding the key after a passage never carries the player straight back.
func _test_storage_and_cellar(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var walker: RefCounted = Work.new()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	await walker.walk_to(tree, session, "move_up", -620, 1)
	_check(player.world_location().zone_id == &"snow.weapon_storage", "north of the practice yard is the weapon storage")
	await walker.walk_to(tree, session, "move_left", 680, 0)
	await walker.walk_to(tree, session, "move_up", -758, 1)
	var scope: StringName = session.item_id_allocator().scope
	var sword: StringName = ItemSpawnDefinition.item_instance_id(scope, &"snow.weapon_storage.bamboo_sword.1")
	_check(map.floor_item_ids().has(sword) and map.select_floor_item(sword) and hud.open_loot_is_enabled(), "the 竹剑 lies on the floor, in reach")
	player.busy.start_busy(1)
	_check(not map.open_selected_loot() and hud.log_lines().back() == "你上一个动作还没有完成！" and map.floor_item_ids().has(sword), "get.c: busy refuses first")
	player.busy.advance()
	_check(map.open_selected_loot() and session.inventory_state().is_direct_child(sword, ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)), "拾取 picks it up")
	_check(hud.log_lines().back() == "你捡起一把竹剑。" and not map.floor_item_ids().has(sword) and map.floor_item_view(sword) == null, "get.c: 你捡起一把竹剑。")
	var passages: WorldHiddenPassages = session.hidden_passages()
	var down_open: Callable = func() -> bool: return map.is_portal_open(DOWN)
	_check(not down_open.call() and not (session.world_map_of(&"snow.cellar")).is_portal_open(UP), "the way down is shut")
	_check(map.select_landmark(SHELF) and hud.portal_action_text() == "往左推" and hud.portal_action_is_enabled(), "the shelf: 往左推")
	map.traverse_selected_portal()
	map.traverse_selected_portal()
	_check(hud.log_lines().back() == "你将架子往左推...，忽然「喀」一声架子又移回原位。" and not down_open.call(), "two pushes: the shelf springs back")
	map.traverse_selected_portal()
	_check(down_open.call() and session.world_map_of(&"snow.cellar").is_portal_open(UP), "the third push opens the way down and the way up")
	_check(hud.log_lines().back() == "地板忽然发出轧轧的声音，一块地面缓缓移动著，露出一个向下的阶梯。", "the floor moves (check_trigger)")
	for _frame: int in range(10):
		await tree.physics_frame
	_check(session.active_map_id() == &"snow.outdoor" and player.world_location().zone_id == &"snow.weapon_storage", "the floor opening under the player does not drop them: the exit is there to take")
	await walker.walk_to(tree, session, "move_down", -680, 1)
	await _walk_until_map(tree, session, "move_up", &"snow.cellar")
	_check(session.active_map_id() == &"snow.cellar" and player.world_location().zone_id == &"snow.secret_storage", "down the steps into the secret storage, and still there with the key held")
	session.advance_hidden_passages(30.0)
	var cellar: WorldMapController = session.active_map() as WorldMapController
	_check(passages.state(SHELF).remaining_ms == 0 and passages.state(SHELF).is_open and cellar.is_portal_open(UP), "the time is up and the way up stays open while the player is below")
	var shield: StringName = ItemSpawnDefinition.item_instance_id(scope, &"snow.secret_storage.shield.1")
	await walker.walk_to(tree, session, "move_down", 40, 1)
	await walker.walk_to(tree, session, "move_right", -60, 0)
	# feature/move.c: too heavy when the shield would pass the player's maximum encumbrance.
	var inventory: InventoryState = session.inventory_state()
	var own: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)
	var load: ItemInstance = ItemInstance.new(&"test.4c.load", &"es2:d/snow/obj/hammer")
	_check(inventory.register_item(load, player.maximum_encumbrance - inventory.contents_weight(own) - 6000)
		and InventoryTransferService.new().transfer(inventory, load.item_instance_id, InventoryTransferDestination.new(own, true, true, WorldMapController.WORLD_CAPACITY)).succeeded, "test load carried")
	_check(cellar.select_floor_item(shield) and not cellar.open_selected_loot() and hud.log_lines().back() == "牛皮盾对你而言太重了。" and cellar.floor_item_ids().has(shield), "move.c: 牛皮盾对你而言太重了。")
	_check(ItemLifecycleService.destroy_item(inventory, session.stack_collection(), load.item_instance_id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF,
		ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor)).succeeded, "test load gone")
	_check(cellar.select_floor_item(shield) and cellar.open_selected_loot() and hud.log_lines().back() == "你捡起一面牛皮盾。", "the 牛皮盾 is picked up")
	await walker.round_trip(tree, session, Work.capture(session), "4C below")
	await _test_continue_below(tree, session)
	await walker.walk_to(tree, session, "move_left", -104, 0)
	await _walk_until_map(tree, session, "move_down", &"snow.outdoor")
	_check(session.active_map_id() == &"snow.outdoor" and player.world_location().zone_id == &"snow.weapon_storage", "back up the steps, and still up with the key held")
	await tree.process_frame
	await tree.process_frame
	_check(not passages.state(SHELF).is_open and not map.is_portal_open(DOWN), "the passage closes once nobody is below")
	_check(hud.log_lines().slice(-3).has("地板忽然发出轧轧的声音，一块地面缓缓移动著，将向下的通道盖住了。"), "close_passage's line: " + str(hud.log_lines().slice(-3)))
	# The temple's donation box is a container (4E): 拾取 lists what is in it, and it stays;
	# it can be looked at from across the room.
	_check(map.relocate_player(&"snow.temple", &"snow.temple.revive"), "to the temple")
	var box: StringName = ItemSpawnDefinition.item_instance_id(scope, &"snow.temple.denotation.1")
	_check(map.select_floor_item(box) and map.open_selected_loot() and hud.loot_rows().is_empty() and map.floor_item_ids().has(box), "功德箱: an empty container")
	hud.dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame
	await walker.walk_to(tree, session, "move_down", 400, 1)
	_check(player.world_location().zone_id == &"snow.temple" and map.select_floor_item(box) and not hud.open_loot_is_enabled() and map.inspect_selected(), "the box is out of reach but in the room")
	for _frame: int in range(10):
		await tree.process_frame
	_check(hud._presentation_layout.frame.visible and hud.inspection_display().begins_with("功德箱\n这是寺庙接受善男信女捐献香油钱的功德箱"), "look at the box from across the room")
	hud.dismiss_current_panel()
	await tree.process_frame
	await walker.round_trip(tree, session, Work.capture(session), "4C floor")
	_count += walker._count
	_failures.append_array(walker._failures)


## Continue in the secret storage finds the way up open (DECISIONS 4C).
func _test_continue_below(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(Work.capture(session))
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded(), "restore below: " + restored.path)
	if not restored.succeeded():
		return
	var fresh: OldPineWorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "activation below")
	await tree.physics_frame
	await tree.physics_frame
	var stairs: WorldPassageArea2D = fresh.world_map_of(&"snow.cellar").get_node("StairsUp") as WorldPassageArea2D
	_check(fresh.hidden_passages().state(SHELF).is_open and stairs.is_open() and stairs.visible and not (stairs.get_node("CollisionShape2D") as CollisionShape2D).disabled, "Continue below: the way up is open, its shape on")
	var scope: StringName = fresh.item_id_allocator().scope
	_check(fresh.world_map_of(&"snow.outdoor").floor_item_ids() == [ItemSpawnDefinition.item_instance_id(scope, &"snow.temple.denotation.1")]
		and fresh.world_map_of(&"snow.cellar").floor_item_ids().is_empty(), "Continue: only the box still lies on the floor")
	fresh.free()
	await tree.process_frame


## Walks until a passage has handed the player to `map_id`, then keeps the key
## held for a moment, as a player does: arrival must not lead straight back.
func _walk_until_map(tree: SceneTree, session: OldPineWorldSessionController, action: String, map_id: StringName) -> void:
	Input.action_press(action)
	for _frame: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == map_id and not session.is_transitioning() and not session.passage_request_pending():
			break
	for _frame: int in range(40):
		await tree.physics_frame
	Input.action_release(action)
	await tree.physics_frame
	await tree.physics_frame


func _zone_rect(map: WorldMapController, zone_id: StringName) -> Rect2:
	for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
		if zone.zone_id == zone_id:
			var shape: CollisionShape2D = zone.get_node("CollisionShape2D") as CollisionShape2D
			var size: Vector2 = (shape.shape as RectangleShape2D).size
			return Rect2(zone.position + shape.position - size / 2.0, size)
	return Rect2()


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("4C inner rooms: " + label)
