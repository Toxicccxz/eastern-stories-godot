extends RefCounted

## Polish 1 (owner, 2026-10-08, DECISIONS「积压问题的处理」): Old Pine's look-only
## item_desc as landmarks (A4); a wanderer's resting spot off its zone's seams and a
## standing NPC stepping aside (A5); 狗肉 leaving its bone and the Snow dog following
## who gave it one (A11); the 弈者's 下棋 (A3); the selection dropped when the player
## walks off; announce()'s death line in the battle log. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const TRAINEE: StringName = &"snow.school2.trainee.1.character"
const DOG: StringName = &"snow.eroad2.dog.1.character"
const CHESS_PLAYER: StringName = &"cloud.tearoom2.chess_player.1.character"
const CHESS: StringName = &"es2:u/cloud/obj/npc/chess_player/chess"
const DOG_MEAT: StringName = &"es2:u/cloud/obj/meat/dog_m"
const LOOK_LANDMARKS: Dictionary[StringName, StringName] = {
	&"oldpine.outdoor.landmark.clearing_sign": &"oldpine.outdoor.central_clearing",
	&"oldpine.outdoor.landmark.epath3_footprints": &"oldpine.outdoor.east_bridge",
	&"oldpine.outdoor.landmark.epath2_waterfall": &"oldpine.outdoor.east_bridge",
	&"oldpine.outdoor.landmark.cliffside_cliff": &"oldpine.outdoor.cliffside",
	&"oldpine.gorge.landmark.waterfall_fall": &"oldpine.gorge.waterfall",
	&"oldpine.gorge.landmark.waterfall_cliff": &"oldpine.gorge.waterfall",
	&"oldpine.gorge.landmark.riverbank2_cliff": &"oldpine.gorge.river",
	&"oldpine.cave.landmark.passage_curtain": &"oldpine.cave.waterfall_passage",
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_look_landmarks()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "out on the square")
	for frame: int in range(5):
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	_test_seams(map)
	await _test_step_aside(tree, session, map)
	_test_bone_and_dog(session, map)
	_test_selection_dropped(session, map)
	_test_death_announced(session, map)
	await _test_chess(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## A4: every look-only item_desc is a look landmark of its room's zone, with the LPC text.
func _test_look_landmarks() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for landmark_id: StringName in LOOK_LANDMARKS:
		var landmark: WorldLandmarkDefinition = catalog.landmark(landmark_id)
		_check(landmark != null and landmark.policy == &"look" and landmark.zone_id == LOOK_LANDMARKS[landmark_id] and landmark.action_label.is_empty(), "%s: a look landmark of its zone" % landmark_id)
	var sign: WorldLandmarkDefinition = catalog.landmark(&"oldpine.outdoor.landmark.clearing_sign")
	_check(sign != null and sign.description == "「官府告示：此处常有歹人出没。」\n", "clearing.c's sign, as written")


## A5: a wanderer's resting cells keep SEAM_CLEAR from where its zone joins the next.
func _test_seams(map: WorldMapController) -> void:
	var walker: WorldNpcWalker = map.npc_walker()
	var zone: WorldPhysicalZoneArea2D = map.physical_zone(&"snow.eroad2")
	var grid := WorldNpcWalker.Grid.new(map, zone.global_rect())
	var cells: Array[Vector2i] = grid.free_cells_in(zone.global_rect())
	var kept: Array[Vector2i] = walker._off_seams(grid, zone, cells)
	var neighbours: Array[Rect2] = []
	for other: WorldPhysicalZoneArea2D in map.physical_zones():
		if other != zone and other.global_rect().grow(1.0).intersects(zone.global_rect()):
			neighbours.append(other.global_rect())
	var near_seam: bool = kept.any(func(cell: Vector2i) -> bool:
		return neighbours.any(func(rect: Rect2) -> bool: return rect.grow(WorldNpcWalker.SEAM_CLEAR).has_point(grid.center_of(cell))))
	_check(not neighbours.is_empty() and not kept.is_empty() and kept.size() < cells.size() and not near_seam, "the east road keeps its resting cells %d px off its seams (%d of %d)" % [WorldNpcWalker.SEAM_CLEAR, kept.size(), cells.size()])


## A5: the player pushing into the standing trainee for over a second: it steps aside,
## within its own zone, to a spot a save accepts.
func _test_step_aside(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	var body: WorldCharacterBody2D = map.runtime_body_for_character(TRAINEE)
	var before: Vector2 = body.global_position
	_check(map.relocate_player(&"snow.school2", trainee.spawn_point_id), "in the yard")
	map.player_body.global_position = before + Vector2(0, 40) # TEST-ONLY: just below him
	session.set_process(true)
	await tree.physics_frame
	await tree.physics_frame
	Input.action_press(&"move_up")
	var stepped: bool = false
	for frame: int in range(120):
		await tree.physics_frame
		if map.npc_walker().is_walking(TRAINEE):
			stepped = true
			break
	Input.action_release(&"move_up")
	session.set_process(false)
	var rest: Vector2 = map.npc_walker().rest_position(TRAINEE, body)
	_check(stepped, "pushed into for a second, the trainee steps aside")
	_check(rest.distance_to(before) >= 32.0 and trainee.world_location().zone_id == &"snow.school2" and MapPlacementValidator.is_valid_character_position(map, &"snow.school2", rest), "to a valid spot of his own yard: %s -> %s" % [before, rest])
	map.npc_walker().finish_all()


## A11: 狗肉 eaten up leaves 狗骨头 (finish_eat()); the Snow dog takes the bone (dog.c
## id("bone")), barks, and follows the player into the next stretch of road.
func _test_bone_and_dog(session: WorldSessionController, map: WorldMapController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var meat: StringName = _carry(session, DOG_MEAT)
	var context: MoneyInventoryContext = Finance.session_context(session)
	var ate: Array[int] = []
	for bite: int in range(3):
		player.state.recovery.food = 0 # TEST-ONLY: hungry
		var result: FoodUseResult = HeldFoodUseService.eat(player, context, session.food_collection(), GameContent.catalog().native_item_projections(), meat, true)
		ate.append(result.outcome)
		if bite == 2:
			_check(result.leftover_id == GameContent.catalog().item(DOG_MEAT).leftover_id(), "the last bite leaves the bone")
	var bone: ItemContentDefinition = GameContent.catalog().item(session.item_instance_index().resolve(meat).item_definition_id)
	_check(ate == [FoodUseResult.Outcome.ATE, FoodUseResult.Outcome.ATE, FoodUseResult.Outcome.ATE], "three bites: %s" % [ate])
	_check(bone != null and bone.display_name == "狗骨头" and bone.aliases().has("bone") and bone.aliases().has("rib") and session.inventory_state().own_weight(meat) == 250, "狗肉 is now a 250 g 狗骨头 (rib, bone)")
	_check(session.food_collection().state(meat) == null and bone.food_definition() == null and bone.value == 0, "no food any more, worth nothing")
	_check(Work.capture(session) != null, "a save takes the bone")
	var dog: NpcRuntimeState = map.find_resident_npc(DOG)
	_check(map.relocate_player(&"snow.eroad2", dog.spawn_point_id) and map.select_npc(DOG), "beside the dog")
	map.player_body.global_position = MapPlaces.spot(map, &"snow.eroad2", map.runtime_body_for_character(DOG).global_position, 96.0)
	map.npc_life._note_player_arrival()
	var given: ItemHandlingResult = map.give_to_selected(meat)
	_check(given.done() and dog.flags().get(NpcDefinition.FLAG_FOLLOWS_PLAYER, false) and hud.log_lines().has("野狗高兴地汪汪叫了起来。"), "the dog takes the bone and barks: %s" % [given.lines])
	map.player_body.global_position = MapPlaces.zone_centre(map, &"snow.eroad3")
	_check(map.accept_zone_presence(map.physical_zone(&"snow.eroad3")), "the player walks on east")
	map.npc_life._note_player_arrival()
	_check(dog.world_location().zone_id == &"snow.eroad3" and hud.log_lines().has("野狗走了过来。"), "the dog follows: 野狗走了过来。")
	map.npc_walker().finish_all()
	_check(MapPlacementValidator.is_valid_character_position(map, &"snow.eroad3", map.runtime_body_for_character(DOG).global_position), "it stands where a save takes it")


## The selection: the dog stays selected while it stands beside the player; walking on
## without it drops the selection (kill.c present()).
func _test_selection_dropped(_session: WorldSessionController, map: WorldMapController) -> void:
	var dog: NpcRuntimeState = map.find_resident_npc(DOG)
	dog.set_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER, false) # TEST-ONLY: it stays behind
	_check(map.select_npc(DOG) and map.selected_character_id() == DOG, "the dog selected")
	map.player_body.global_position = MapPlaces.zone_centre(map, &"snow.eroad2")
	_check(map.accept_zone_presence(map.physical_zone(&"snow.eroad2")), "the player walks back west")
	_check(map.selected_character_id().is_empty(), "the dog left behind is no longer selected")


## announce("dead") in the battle log: the trainee killed in a fight.
func _test_death_announced(session: WorldSessionController, map: WorldMapController) -> void:
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	session.player_runtime().state.progression.combat_experience = 100000 # TEST-ONLY: hits that land
	trainee.character_state.vitality.effective = 1 # TEST-ONLY: one blow
	trainee.character_state.vitality.current = 1
	_check(map.relocate_player(&"snow.school2", trainee.spawn_point_id) and map.select_npc(TRAINEE), "beside the trainee")
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a fight to the death")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for round: int in range(60):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
	ui.refresh_projection()
	var log: String = ui.log_panel._text.get_parsed_text()
	_check(log.contains("武馆弟子死了。"), "combatd.c announce(\"dead\") in the battle log")
	_check(not log.contains("你死了。"), "never the player's own")
	session.player_runtime().state.progression.combat_experience = 0


## A3: 下棋 with the 弈者: a win (random(100) < 50) hands over two of his 棋子, a loss
## says 承让承让！; with none left he only praises the game.
func _test_chess(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"cloud.tearoom_upstairs", &"cloud.tearoom2", &"cloud.tearoom2", &"cloud.tearoom2.stairs_arrival").succeeded(), "up in the tea house")
	for frame: int in range(5):
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player_npc: NpcRuntimeState = map.find_resident_npc(CHESS_PLAYER)
	_check(player_npc != null and map.select_npc(CHESS_PLAYER), "the 弈者 selected")
	_check(map.ask_topics_selected().has("下棋"), "下棋 is a topic")
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([10, 80])) # TEST-ONLY: a win, then a loss
	var won: Array[String] = map.ask_selected("下棋")
	_check(won == ["你向弈者打听有关『下棋』的消息。", "弈者说道：要比试一盘？好啊！", "你赢了。", "弈者给你两枚棋子。", "弈者说道：好棋技！佩服。无以为报，就给您两枚棋子防身吧！"], "a win: %s" % [won])
	_check(_amount_of(session, session.player_runtime().character_id, CHESS) == 2 and _amount_of(session, CHESS_PLAYER, CHESS) == 98, "two of his hundred 棋子 are the player's")
	var lost: Array[String] = map.ask_selected("下棋")
	_check(lost == ["你向弈者打听有关『下棋』的消息。", "弈者说道：要比试一盘？好啊！", "你输了。", "弈者说道：承让承让！"], "a loss: %s" % [lost])
	# TEST-ONLY: he has none left.
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, CHESS_PLAYER)
	for item_id: StringName in session.inventory_state().direct_children(holder):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == CHESS:
			var owner := ItemLifecycleOwnerContext.new(CHESS_PLAYER, player_npc.character_state.equipment, player_npc.armor)
			var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(session.inventory_state(), session.stack_collection(), item_id, ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, owner)
			_check(removal.succeeded and session.item_instance_index().forget_destroyed_snapshots(removal.removed_instance_ids, session.inventory_state()), "TEST-ONLY: his 棋子 gone")
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([10]))
	var empty: Array[String] = map.ask_selected("下棋")
	_check(empty == ["你向弈者打听有关『下棋』的消息。", "弈者说道：要比试一盘？好啊！", "你赢了。", "弈者说道：好棋技！佩服。"], "a win with none left: %s" % [empty])
	session.configure_world_interaction_random_source(original)


## TEST-ONLY: a new item of `definition_id` in the player's hands.
func _carry(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	return map.give_new_item_to_player(definition_id)


func _amount_of(session: WorldSessionController, character_id: StringName, definition_id: StringName) -> int:
	var total: int = 0
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)
	for item_id: StringName in session.inventory_state().direct_children(holder):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			total += session.stack_collection().stack_state(item_id).amount if session.stack_collection().has_stack(item_id) else 1
	return total


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
