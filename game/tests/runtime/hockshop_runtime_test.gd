extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const H2 := preload("res://tests/application/hockshop_core_test.gd")
const O := HockshopValuationResult.Outcome
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await physical_tests(tree)
	await panel_tests(tree)
	await equipment_and_error_tests(tree)
	var profile: String = "h3-cold-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for mode: String in ["write", "read"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_hockshop_cold_process.gd", "--", mode, profile], output, true)
		check(code == 0 and str(output).contains("H3 cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold process " + mode + str(output))
	return {"assertions": assertions, "failures": failures}


func physical_tests(tree: SceneTree) -> void:
	var random: Recovery.RandomSequence = Recovery.RandomSequence.new([5])
	var session: OldPineWorldSessionController = Recovery.create_session(tree, random)
	var snow: WorldMapController = session.resident_map(&"snow.outdoor") as WorldMapController
	var ui: HockshopService = snow.service(&"snow.hockshop.counter") as HockshopService
	var walk: Work = Work.new()
	var authorities: Array[Object] = [session.player_runtime(), session.inventory_state(), session.stack_collection(), session.item_instance_index(), session.food_collection(), session.liquid_collection(), session.item_id_allocator(), session.world_simulation_gate(), session.player_recovery_cadence()]
	var rng: Array[int] = Work.rng_state(session)
	var sequence: int = session.item_id_allocator().next_dynamic_sequence
	check(GameContent.catalog().zones_for_map(&"snow.outdoor").size() + 1 == 32, "32 Snow zones on the Inn and outdoor maps, with 4B's and 4C's rooms")
	check(GameContent.catalog().zone(&"snow.hockshop").room_ids() == [&"es2:d/snow/hockshop"], "source metadata")
	check(GameContent.catalog().zones_adjacent(&"snow.hockshop", &"snow.mstreet3") and GameContent.catalog().zones_adjacent(&"snow.mstreet3", &"snow.hockshop"), "two-way local neighbor")
	check(GameContent.catalog().zone(&"snow.hockshop2") != null and GameContent.catalog().portal(&"snow.hockshop2") == null and GameContent.catalog().zones_adjacent(&"snow.hockshop", &"snow.hockshop2"), "4B: the storage room is walked into, no portal")
	check(not snow.door(&"snow.hockshop.door").is_open() and not snow.open_door(&"snow.hockshop.door") and not ui.in_reach(), "fresh closed / no remote interaction in Inn")
	await tree.physics_frame
	check(await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID), "out through the Inn's door")
	check(await MapPlaces.drive_through(tree, snow, [&"snow.square", &"snow.mstreet1", &"snow.mstreet2", &"snow.mstreet3"]), "up the street to the Hockshop")
	check(await MapPlaces.drive(tree, snow, MapPlaces.door_spot(snow, &"snow.hockshop.door", &"snow.mstreet3")), "up to its door")
	var door_wall: CollisionShape2D = MapPlaces.door_wall(snow, &"snow.hockshop.door")
	await MapPlaces.push(tree, &"move_right", 40)
	check(snow.player_body.position.x < door_wall.global_position.x - 16.0 and session.player_runtime().world_location().zone_id == &"snow.mstreet3", "closed collision stops physical input")
	check(snow.can_operate_door(&"snow.hockshop.door") and not ui.in_reach(), "street offers door, never trade")
	var before: Vector2 = snow.player_body.position
	check(snow.open_door(&"snow.hockshop.door") and snow.player_body.position == before, "open-only no teleport")
	await tree.physics_frame
	await tree.physics_frame
	check(door_wall.disabled, "only door collision disabled")
	check(not MapPlacementValidator.is_valid_character_position(snow, &"snow.hockshop", door_wall.global_position), "open threshold still save-invalid for closed cold restore")
	var doorway: Vector2 = MapPlaces.doorway(snow, &"snow.mstreet3", &"snow.hockshop")
	check(await MapPlaces.drive(tree, snow, MapPlaces.spot(snow, &"snow.hockshop", doorway + Vector2(48, 0))), "in through the open door")
	check(session.player_runtime().world_location().zone_id == &"snow.hockshop" and not ui.in_reach(), "ordinary Area crossing, doorway not counter")
	check(await MapPlaces.drive(tree, snow, MapPlaces.service_spot(snow, &"snow.hockshop.counter")), "up to the counter")
	check(ui.in_reach() and session.active_map() == snow, "counter physical reach")
	check(session.resident_map_count() == GameContent.catalog().maps().size() and session.active_map_child_count() == 1 and snow.resident_npcs().size() == GameContent.catalog().spawns_for_map(snow.map_id()).reduce(func(total: int, spawn: NpcSpawnDefinition) -> int: return total + spawn.quantity, 0), "every authored map resident, one active, only authored Snow NPCs")
	var room: Rect2 = MapPlaces.zone_rect(snow, &"snow.hockshop")
	var at_counter: Vector2 = MapPlaces.service_spot(snow, &"snow.hockshop.counter")
	var counter: Vector2 = MapPlaces.first_blocked(snow, ui.point.global_position, room.get_center())
	check(counter.is_finite(), "the counter stands between its service point and the room")
	for position: Vector2 in [room.get_center(), doorway + Vector2(56, 0), Vector2(room.position.x + 56, room.end.y - 56)]:
		check(MapPlacementValidator.is_valid_character_position(snow, &"snow.hockshop", position), "valid interior " + str(position))
	for position: Vector2 in [Vector2(room.get_center().x, room.position.y + 10), Vector2(room.get_center().x, room.end.y - 10), counter, Vector2(NAN,0)]:
		check(not MapPlacementValidator.is_valid_character_position(snow, &"snow.hockshop", position), "reject wall/counter/void/nonfinite " + str(position))
	# 4B: east through the curtain is the storage room (hockshop2.c), another zone.
	var storage: Rect2 = MapPlaces.zone_rect(snow, &"snow.hockshop2")
	for position: Vector2 in [MapPlaces.zone_spot(snow, &"snow.hockshop2"), MapPlaces.spot(snow, &"snow.hockshop2", Vector2(storage.end.x - 48, storage.get_center().y))]:
		check(not MapPlacementValidator.is_valid_character_position(snow, &"snow.hockshop", position) and MapPlacementValidator.is_valid_character_position(snow, &"snow.hockshop2", position), "storage room, not the shop " + str(position))
	var mst3: Area2D = snow.physical_zone(&"snow.mstreet3")
	var original: Vector2 = mst3.position
	mst3.position = snow.physical_zone(&"snow.hockshop").position
	check(not MapPlacementValidator.is_valid_character_position(snow, &"snow.hockshop", at_counter), "ambiguous zones reject")
	mst3.position = original
	var snapshot: GameSaveSnapshot = Work.capture(session)
	check(snapshot != null, "capture actual entered Hockshop")
	if snapshot != null:
		var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
		check(encoded.succeeded() and not encoded.text.contains('"door') and not encoded.text.contains("confirmation"), "door/UI not saved")
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(snapshot, tree.root)
		check(restored.succeeded(), "restore Hockshop")
		if restored.succeeded():
			var fresh: OldPineWorldSessionController = restored.candidate
			check(fresh.activate_restore_candidate(), "activate Hockshop restore")
			fresh.set_process(false)
			var new_snow: WorldMapController = fresh.active_map() as WorldMapController
			check(not new_snow.door(&"snow.hockshop.door").is_open() and new_snow.player_body.position == snow.player_body.position and (new_snow.service(&"snow.hockshop.counter") as HockshopService).in_reach(), "exact restore closed door and service")
			check(GameSaveJsonCodec.encode(Work.capture(fresh)).text == encoded.text, "whole snapshot equality / no rewrite")
			snow.player_body.player_controlled = false # isolate two simultaneously loaded test bodies
			(snow.player_body.get_node("CollisionShape2D") as CollisionShape2D).disabled = true # the restored body starts where it stands
			await tree.physics_frame
			check(await MapPlaces.drive(tree, new_snow, MapPlaces.door_spot(new_snow, &"snow.hockshop.door", &"snow.hockshop")), "back to the door inside")
			check(new_snow.open_door(&"snow.hockshop.door"), "reopen from inside after restore")
			await tree.physics_frame
			check(await MapPlaces.drive_to_zone(tree, new_snow, &"snow.mstreet3"), "out onto the street")
			check(fresh.player_runtime().world_location().zone_id == &"snow.mstreet3", "restored inside not trapped")
			fresh.free()
			(snow.player_body.get_node("CollisionShape2D") as CollisionShape2D).disabled = false
			snow.player_body.player_controlled = true
	check(authorities == [session.player_runtime(), session.inventory_state(), session.stack_collection(), session.item_instance_index(), session.food_collection(), session.liquid_collection(), session.item_id_allocator(), session.world_simulation_gate(), session.player_recovery_cadence()], "all nine authority identities exact")
	check(Work.rng_state(session) == rng and sequence == session.item_id_allocator().next_dynamic_sequence and random.calls == 1, "walk/door zero RNG / allocation / redraw")
	check(await MapPlaces.drive_through(tree, snow, [&"snow.mstreet3", &"snow.mstreet2", &"snow.mstreet1", &"snow.square"]), "back down the street")
	check(await MapPlaces.take_passage(tree, snow, &"snow.square.west"), "into the Inn's door")
	check(session.active_map_id() == &"snow.inn", "return physically to Inn")
	check(await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID), "out again")
	check(session.active_map_id() == &"snow.outdoor" and snow.door(&"snow.hockshop.door").is_open(), "resident reattach retains local open state")
	assertions += walk._count
	failures.append_array(walk._failures)
	session.free()
	await tree.process_frame


func panel_tests(tree: SceneTree) -> void:
	# Fixtures below isolate the scoped UI/core boundary, not physical/live journey evidence.
	for free_capacity: int in [114,50,90,20]:
		var session: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new([5]))
		var ui: HockshopService = await panel_fixture(tree, session)
		H2.add_item(ui.context(), session.food_collection(), session.liquid_collection(), H2.SHORT, &"h3.sword")
		session.player_runtime()._body_facts = PlayerBodyFacts.new(80000, ui.context().checked_contents_weight() + free_capacity) # explicit test-only capacity fixture
		ui.interact()
		ui.select_item(&"h3.sword")
		var before: int = session.item_id_allocator().next_dynamic_sequence
		ui.request_value()
		check(ui.last_valuation.source_value == 300 and ui.last_valuation.actual_payout == 240 and ui.feedback.text.contains("240"), "Value uses H2 short300/240")
		check(session.item_id_allocator().next_dynamic_sequence == before, "Value no ID")
		ui.request_confirmation()
		check(ui.last_sell == null and session.inventory_state().is_registered(&"h3.sword") and ui.confirm_button.is_visible_in_tree(), "confirmation before payout")
		ui.confirm_sale()
		var expected: int = {114:240,50:40,90:200,20:0}[free_capacity]
		check(ui.last_sell.outcome == HockshopSellResult.Outcome.SOLD and ui.last_sell.payout.delivered_value == expected, "H2 delivered literal " + str(expected))
		check(ui.feedback.text.contains("实际收到%d文" % expected) and not ui.visible_ids().has(&"h3.sword"), "truthful receipt and removed row")
		var after: int = session.item_id_allocator().next_dynamic_sequence
		ui.confirm_sale()
		check(session.item_id_allocator().next_dynamic_sequence == after, "confirmation consumed exactly once")
		session.free()
		await tree.process_frame
	var session: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new([5]))
	var ui: HockshopService = await panel_fixture(tree, session)
	for row: Array in [[H2.SHORT,&"h3.a",300,240],[H2.SHORT,&"h3.b",300,240],[H2.LONG,&"h3.long",700,560],[H2.LEATHER,&"h3.leather",200,160],[TestContent.DUMPLING_ITEM_ID,&"h3.food",15,12],[TestContent.WINESKIN_ITEM_ID,&"h3.liquid",20,16]]:
		H2.add_item(ui.context(), session.food_collection(), session.liquid_collection(), row[0], row[1])
	ui.interact()
	check(ui.visible_ids().has(&"h3.a") and ui.visible_ids().has(&"h3.b") and ui.item_label(&"h3.a") != ui.item_label(&"h3.b"), "duplicate exact-ID disambiguation")
	for row: Array in [[&"h3.a",300,240],[&"h3.long",700,560],[&"h3.leather",200,160],[&"h3.food",15,12],[&"h3.liquid",20,16]]:
		ui.select_item(row[0]); ui.request_value()
		check(ui.last_valuation.source_value == row[1] and ui.last_valuation.actual_payout == row[2], "literal H2 UI quote " + str(row))
	ui.select_item(&"h3.food"); ui.request_confirmation()
	session.food_collection().state(&"h3.food").consume_portion()
	var sequence: int = session.item_id_allocator().next_dynamic_sequence
	ui.confirm_sale()
	check(ui.last_sell == null and sequence == session.item_id_allocator().next_dynamic_sequence and ui.feedback.text.contains("未执行"), "changed food cancels confirmation/no payout")
	ui.request_value()
	check(ui.last_valuation.outcome == O.WORTHLESS and ui.sell_button.disabled, "bitten food worthless")
	ui.select_item(&"h3.a"); ui.request_confirmation()
	session.inventory_state()._apply_reparent(&"h3.a", ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"test"))
	ui.confirm_sale()
	check(ui.last_sell == null and not ui.visible_ids().has(&"h3.a") and session.inventory_state().is_registered(&"h3.b"), "stale moved ID no substitute duplicate")
	ui.close_panel()
	check(not ui.panel.visible, "close panel")
	ui.request_value(); ui.request_confirmation(); ui.confirm_sale()
	check(sequence == session.item_id_allocator().next_dynamic_sequence, "closed service calls inert")
	ui.interact(); tree.paused = true
	await tree.process_frame
	await tree.process_frame
	check(not ui.panel.visible and not ui.in_reach(), "Pause hides and invalidates panel")
	tree.paused = false
	session.free()
	await tree.process_frame


func panel_fixture(tree: SceneTree, session: OldPineWorldSessionController) -> HockshopService:
	# Existing serializer/boundary setup; NEVER claimed as physical reachability.
	var snow: WorldMapController = session.resident_map(&"snow.outdoor") as WorldMapController
	await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID)
	snow.player_body.position = MapPlaces.service_spot(snow, &"snow.hockshop.counter")
	session.player_runtime().set_world_location(snow.location_for_zone(&"snow.hockshop"))
	await tree.physics_frame
	return snow.service(&"snow.hockshop.counter") as HockshopService


func equipment_and_error_tests(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new([5]))
	var ui: HockshopService = await panel_fixture(tree, session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var definitions: NativeItemDefinitionProjections = TestContent.projections()
	for id: StringName in [&"h3.weapon1", &"h3.weapon2"]:
		H2.add_item(ui.context(), session.food_collection(), session.liquid_collection(), H2.SHORT, id)
		check(player.state.equipment.wield(EquippedWeaponRef.new(id, definitions.weapon_definition(H2.SHORT)), false).succeeded, "wield real typed fixture")
	ui.interact()
	ui.select_item(&"h3.weapon1"); ui.request_value()
	check(ui.item_label(&"h3.weapon1").contains("主手") and player.state.equipment.has_weapon_instance(&"h3.weapon1"), "Value labels equipped, never detaches")
	ui.request_confirmation()
	check(ui.sale_prompt.message.text.contains("主手") and ui.sale_prompt.message.text.contains("240"), "confirmation identifies equipped item/quote")
	ui.confirm_sale()
	check(player.state.equipment.is_primary_hand_empty() and not player.state.equipment.is_secondary_hand_empty(), "UI sale no auto promotion")
	check(ui.last_sell.removal.weapon_detached and not ui.visible_ids().has(&"h3.weapon1"), "equipped sale live lifecycle + refresh")
	for slot: StringName in player.armor.occupied_slots():
		player.armor.remove(player.armor.item_instance_id_in_slot(slot))
	H2.add_item(ui.context(), session.food_collection(), session.liquid_collection(), H2.LEATHER, &"h3.leather")
	player.armor._apply_wear(EquippedArmorRef.new(&"h3.leather", definitions.armor_definition(H2.LEATHER)))
	ui.refresh(); ui.select_item(&"h3.leather"); ui.request_confirmation()
	check(ui.sale_prompt.message.text.contains("已穿戴") and ui.sale_prompt.message.text.contains("160"), "worn leather confirmation")
	ui.confirm_sale()
	check(ui.last_sell.payout.delivered_value == 160 and player.armor.aggregate_numeric_modifiers().armor == 0 and player.armor.aggregate_numeric_modifiers().dodge == 0, "worn leather exact removal")
	check(not ui.visible_ids().has(&"h3.leather"), "worn row removed")
	for id: StringName in ui.visible_ids():
		check(GameContent.catalog().denomination_of(session.item_instance_index().resolve(id).item_definition_id) == CurrencyDenomination.Value.UNSUPPORTED, "money omitted from goods")
	check(ui.holdings.text.contains("银") and ui.holdings.text.contains("钱"), "physical silver and coin projected")
	var cloth: StringName = &""
	for id: StringName in ui.visible_ids():
		if session.item_instance_index().resolve(id).item_definition_id == TestContent.CLOTH_ITEM_ID: cloth = id
	ui.select_item(cloth); ui.request_value()
	check(ui.last_valuation.outcome == O.WORTHLESS and ui.sell_button.disabled, "birth cloth visible worthless")
	# A real existing lifecycle failure seam: do not alter H2 or bypass its body.
	player.state.equipment = H2.RefusingEquipment.new()
	player.state.equipment.wield(EquippedWeaponRef.new(&"h3.weapon2", definitions.weapon_definition(H2.SHORT)), false)
	ui.refresh(); ui.select_item(&"h3.weapon2"); ui.request_confirmation(); ui.confirm_sale()
	check(ui.last_sell.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and ui.last_sell.payout.delivered_value == 240, "post-payout authority failure from actual H2")
	check(ui.feedback.text.contains("技术异常") and ui.feedback.text.contains("未回滚") and not ui.feedback.text.contains("卖断完成"), "truthful failure, not success/refund")
	check(ui.visible_ids().has(&"h3.weapon2") and player.state.equipment.has_weapon_instance(&"h3.weapon2"), "failed removal retained live row/equipment")
	var sequence: int = session.item_id_allocator().next_dynamic_sequence
	await tree.process_frame
	await tree.process_frame
	ui.confirm_sale()
	check(sequence == session.item_id_allocator().next_dynamic_sequence, "no automatic or replay retry")
	ui.close_panel(); ui.interact(); ui.select_item(&"h3.weapon2"); ui.request_confirmation()
	var snow: WorldMapController = session.active_map() as WorldMapController
	var at_counter: Vector2 = snow.player_body.position
	snow.player_body.position = MapPlaces.spot(snow, &"snow.hockshop", MapPlaces.doorway(snow, &"snow.mstreet3", &"snow.hockshop") + Vector2(48, 0))
	ui.confirm_sale()
	check(sequence == session.item_id_allocator().next_dynamic_sequence and ui.feedback.text.contains("未执行"), "counter distance revalidated before sale")
	await tree.process_frame
	await tree.process_frame
	check(not ui.panel.visible and not ui.in_reach(), "walk-away panel inactive")
	snow.player_body.position = at_counter
	player.busy.start_busy(2)
	check(not ui.in_reach(), "busy blocks ordinary commerce")
	player.busy.advance(); player.busy.advance(); player.busy.advance()
	session.world_simulation_gate().acquire(&"h3.test")
	check(not ui.in_reach(), "frozen gate blocks commerce")
	session.world_simulation_gate().release(&"h3.test")
	ui.interact()
	var metrics: SafeAreaMetrics = SafeAreaMetrics.new(Rect2(0,0,960,540), Rect2(20,0,920,540), false, true)
	session.shared_ui()._presentation_layout._reflow(metrics)
	await tree.process_frame
	await tree.process_frame
	check(metrics.content_rect().encloses(session.shared_ui()._presentation_layout.frame.get_global_rect()), "touch safe-area bounded panel")
	check(ui.confirm_button.custom_minimum_size.y >= 64 and ui.value_button.custom_minimum_size.y >= 64, "touch-sized actions")
	check(ResponsivePanelLayout.top_interaction_panel(tree) == session.shared_ui()._presentation_layout._frame_layout and ExplorationPresentationBlocker.is_blocked(tree), "existing Back/input panel boundary")
	ui.select_item(&"h3.weapon2"); ui.request_confirmation(); session.shared_ui()._presentation_layout._frame_layout.dismiss_requested.emit()
	check(ui.panel.visible and not ui.confirm_button.is_visible_in_tree(), "Back cancels confirmation first")
	session.shared_ui()._presentation_layout._frame_layout.dismiss_requested.emit()
	check(not ui.panel.visible, "next Back closes panel")
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("H3: " + label)
