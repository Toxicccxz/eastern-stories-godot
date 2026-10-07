extends RefCounted

const HistoricalCombat := preload("res://tests/support/historical_world_combat_fixture.gd")

const SCENE_PATH: String = "res://scenes/world/oldpine/oldpine_world_session.tscn"
const ControllerType := preload(
	"res://runtime/world/world_map_controller.gd"
)
const ScriptedRandomType := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

class MaximumCombatRandomSource extends CombatRandomSource:
	var _calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		_calls += 1
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

	func call_count() -> int:
		return _calls


class RejectingLocationPlayer extends WorldPlayerRuntimeState:
	func set_world_location(_value: WorldLocationState) -> bool:
		return false

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_authored_landmark_and_portal_data()
	await _test_scene_portal_nodes_and_click_selection(tree)
	await _test_target_kind_and_inspect_safety(tree)
	await _test_climb_and_return_traversal(tree)
	await _test_portal_rng_and_character_state_safety(tree)
	await _test_portal_rejections_and_combat_cleanup(tree)
	await _test_deferred_aggression_and_deduplication(tree)
	await _test_aggression_cancellation_and_gates(tree)
	await _test_area_escape_and_current_authority_rechecks(tree)
	await _test_player_already_fighting_and_timer_semantics(tree)
	await _test_multiple_bandits_are_stable_and_rng_free(tree)
	await _test_aggressive_death_and_fresh_scene_boundary(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_authored_landmark_and_portal_data() -> void:
	_assert_true(GameContent.load_errors().is_empty(), "Old Pine world data remains coherent")
	_assert_true(GameContent.load_errors().is_empty(), "landmark references resolve")
	var pine: WorldLandmarkDefinition = (
		GameContent.catalog().landmark(
			&"oldpine.outdoor.landmark.ancient_pine"
		)
	)
	_assert_true(pine != null and pine.is_valid(), "ancient pine authored definition exists")
	_assert_eq(pine.display_name, "大松树", "pine name is authored outside HUD/controller")
	_assert_eq(
		pine.description,
		"一株又高又大的松树，当你抬头往上看的时候似乎有个人影\n"
		+ "在树梢之间移动，不过也许是风吹动所造成的错觉。\n",
		"pine inspect text traces clearing.c item_desc",
	)
	_assert_eq(pine.legacy_source_path, "d/oldpine/clearing.c", "pine source metadata")
	var climb: PortalDefinition = GameContent.catalog().portal(
		pine.portal_id
	)
	_assert_eq(climb.destination_zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "climb destination zone")
	_assert_eq(climb.destination_spawn_point_id, OldPineWorldDefinitions.TREE1_LANDING_SPAWN_POINT_ID, "climb exact landing ID")
	var descent: WorldLandmarkDefinition = (
		GameContent.catalog().landmark(
			&"oldpine.tree.landmark.tree1_descent"
		)
	)
	_assert_eq(descent.display_name, "大松树上", "tree1 authored name")
	_assert_eq(
		descent.description,
		"你现在正攀附在一株大松树的树干上，从这里可以很清楚地望见树\n"
		+ "下的一切动静，而不被人发觉，似乎是个干偷鸡摸狗勾当的好地方。\n",
		"tree1 inspect text traces tree1.c long",
	)
	_assert_eq(descent.action_label, "往下爬", "tree1 authored action label")
	_assert_eq(descent.portal_id, OldPineWorldDefinitions.DESCEND_TREE1_PORTAL_ID, "tree1 descent resolves return portal")
	_assert_eq(descent.legacy_source_path, "d/oldpine/tree1.c", "tree1 descent source metadata")
	var return_portal: PortalDefinition = GameContent.catalog().portal(
		descent.portal_id
	)
	_assert_eq(return_portal.source_zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "return source is exact tree1 canopy zone")
	_assert_eq(return_portal.destination_zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "return destination is exact clearing zone")
	_assert_eq(return_portal.destination_spawn_point_id, OldPineWorldDefinitions.CLEARING_PINE_LANDING_SPAWN_POINT_ID, "return resolves exact pine landing")
	var target: WorldInteractionTarget = WorldInteractionTarget.landmark(pine.landmark_id)
	_assert_true(target.is_valid(), "typed landmark target is valid")
	_assert_eq(target.kind, WorldInteractionTarget.Kind.LANDMARK, "landmark target kind is closed")
	var character_target: WorldInteractionTarget = WorldInteractionTarget.character(&"character")
	_assert_eq(character_target.kind, WorldInteractionTarget.Kind.CHARACTER, "character target kind remains distinct")
	var target_variant: Variant = target
	var result_variant: Variant = WorldPortalTraversalResult.new()
	_assert_false(target_variant is Node, "interaction target is Node-free")
	_assert_false(target_variant is Callable, "interaction target is not callback dispatch")
	_assert_false(result_variant is Node, "portal result is Node-free")
	_assert_false(result_variant is Dictionary, "portal result is not payload dictionary")


func _test_scene_portal_nodes_and_click_selection(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "Phase 7B3 scene instantiates")
	if controller == null:
		return
	var pine_area: WorldLandmarkArea2D = controller.get_node_or_null(
		"Interactions/PineInteraction"
	) as WorldLandmarkArea2D
	# The tree top is its own map (DECISIONS 3B5); its descent, zone and landing live there.
	var tree_map: WorldMapController = controller.session.world_map_of(OldPineWorldDefinitions.TREE_MAP_ID)
	_assert_true(tree_map != null and tree_map != controller, "the tree top is a separate resident map")
	var descent_area: WorldLandmarkArea2D = tree_map.get_node_or_null(
		"Interactions/Tree1DescentInteraction"
	) as WorldLandmarkArea2D
	_assert_true(pine_area != null and pine_area.is_configured(), "pine click Area2D persists")
	_assert_true(descent_area != null and descent_area.is_configured(), "return click Area2D persists")
	_assert_true(controller.get_node_or_null("Interactions/Tree1DescentInteraction") == null, "the forest map holds no tree1 descent")
	_assert_eq(pine_area.get_signal_connection_list("selection_requested").size(), 1, "pine typed selection signal persists once")
	_assert_eq(descent_area.get_signal_connection_list("selection_requested").size(), 1, "descent typed selection signal persists once")
	var canopy_zone: Area2D = tree_map.get_node_or_null("Zones/CanopyZone") as Area2D
	_assert_true(canopy_zone != null, "TreeCanopyZone Area2D persists")
	_assert_true(canopy_zone.get_node_or_null("CollisionShape2D") is CollisionShape2D, "TreeCanopyZone has collision")
	_assert_eq(canopy_zone.get_signal_connection_list("body_entered").size(), 1, "TreeCanopyZone logical adapter persists")
	_assert_true(controller.physical_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID) == null, "the forest map holds no canopy zone")
	var tree_landing: WorldSpawnMarker2D = tree_map.get_node_or_null(
		"SpawnPoints/Tree1Landing"
	) as WorldSpawnMarker2D
	var clearing_landing: WorldSpawnMarker2D = controller.get_node_or_null(
		"SpawnPoints/ClearingPineLanding"
	) as WorldSpawnMarker2D
	_assert_eq(tree_landing.spawn_point_id, OldPineWorldDefinitions.TREE1_LANDING_SPAWN_POINT_ID, "tree1 marker has exact portal ID")
	_assert_eq(clearing_landing.spawn_point_id, OldPineWorldDefinitions.CLEARING_PINE_LANDING_SPAWN_POINT_ID, "return marker has exact portal ID")
	# A middle bough of the great pine (tree2).
	_assert_eq(TerrainProbe.terrain_at(tree_map, Vector2(1880, 180)), "bridge", "canopy terrain is painted on the tree map")
	_assert_false(TerrainProbe.blocks_at(tree_map, Vector2(1880, 180)), "canopy terrain is walkable")
	# The canopy's edge is colliding terrain (was a StaticBody2D boundary).
	_assert_true(TerrainProbe.blocks_at(tree_map, Vector2(2296, 260)), "canopy right boundary collides")
	_assert_true(TerrainProbe.blocks_at(tree_map, Vector2(1704, 260)), "canopy left boundary collides")
	var tree_camera: Camera2D = tree_map.get_node("Characters/Player/Camera2D") as Camera2D
	_assert_true(tree_camera.limit_left <= 1712 and tree_camera.limit_right >= 2288, "camera covers canopy platform")
	for index: int in range(3):
		var presence: Area2D = OldPineTestMap.body(controller, "Bandit%02d" % (index + 1)).get_node("AggressionPresence") as Area2D
		_assert_eq(presence.collision_layer, 0, "presence Area does not become physical body")
		_assert_eq(presence.collision_mask, 1, "presence Area observes character bodies")
		_assert_eq(presence.get_signal_connection_list("body_entered").size(), 1, "presence enter signal persists once")
		_assert_eq(presence.get_signal_connection_list("body_exited").size(), 1, "presence exit signal persists once")
	var first_shape: CircleShape2D = (
		OldPineTestMap.body(controller, "Bandit01").get_node("AggressionPresence/CollisionShape2D")
		as CollisionShape2D
	).shape as CircleShape2D
	var second_shape: CircleShape2D = (
		OldPineTestMap.body(controller, "Bandit02").get_node("AggressionPresence/CollisionShape2D")
		as CollisionShape2D
	).shape as CircleShape2D
	var bandit_distance: float = OldPineTestMap.body(controller, "Bandit01").global_position.distance_to(
		OldPineTestMap.body(controller, "Bandit02").global_position
	)
	_assert_true(first_shape.radius + second_shape.radius > bandit_distance, "authored presence regions overlap for multi-bandit case")
	var camera: Camera2D = controller.get_node("Characters/Player/Camera2D") as Camera2D
	camera.make_current()
	camera.reset_smoothing()
	await tree.physics_frame
	await _click_area_through_viewport(pine_area, tree)
	var selected: WorldInteractionTarget = controller.selected_interaction_target()
	_assert_true(selected != null and selected.is_valid(), "real pine picking creates typed selection")
	_assert_eq(selected.kind, WorldInteractionTarget.Kind.LANDMARK, "real pine picking selects landmark kind")
	_assert_eq(selected.target_id, &"oldpine.outdoor.landmark.ancient_pine", "real pine picking selects stable landmark ID")
	_assert_true(controller.session.shared_ui().portal_action_is_enabled(), "Climb action becomes available for active player")
	_assert_eq(controller.session.shared_ui().portal_action_text(), "爬树", "HUD uses authored action label")
	_assert_false(controller.session.shared_ui().attack_is_enabled(), "landmark target never enables Attack")
	_assert_true(controller.inspect_selected(), "landmark Inspect is available")
	_assert_true(controller.session.shared_ui().inspection_display().contains("风吹动"), "HUD renders authored pine description")
	controller.queue_free()
	await tree.process_frame


func _test_target_kind_and_inspect_safety(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0, 0])
	controller.session.configure_combat_random_source(random)
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	var npc_opponents: Array[StringName] = npc.relationship.opponent_ids()
	var player_opponents: Array[StringName] = (
		controller.player_runtime().relationship.opponent_ids()
	)
	_assert_true(controller.select_npc(npc.character_id), "Bandit target selects first")
	_assert_true(controller.session.shared_ui().inspect_button.disabled == false, "Bandit enables Inspect")
	_assert_true(controller.session.shared_ui().attack_is_enabled(), "Bandit enables Attack for active player")
	_assert_false(controller.session.shared_ui().portal_action_is_enabled(), "Bandit disables Traverse")
	_assert_true(controller.inspect_selected(), "Bandit Inspect remains presentation-only")
	_assert_true(
		controller.select_landmark(&"oldpine.outdoor.landmark.ancient_pine"),
		"Bandit to Pine switches target kind",
	)
	_assert_true(controller.session.shared_ui().inspect_button.disabled == false, "Pine enables Inspect")
	_assert_false(controller.session.shared_ui().attack_is_enabled(), "Pine disables stale Attack")
	_assert_false(
		controller.session.shared_ui().portal_action_is_enabled(),
		"Pine selected from South Slope does not expose stale Climb",
	)
	_assert_true(controller.inspect_selected(), "Pine Inspect remains available off-source")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
	))
	controller._refresh_selected_landmark_source()
	_assert_true(
		controller.session.shared_ui().portal_action_is_enabled(),
		"selected Pine enables Climb only after current source becomes valid",
	)
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	_assert_true(controller.select_npc(npc.character_id), "Pine to Bandit restores character target")
	_assert_true(controller.session.shared_ui().attack_is_enabled(), "Bandit restores Attack availability")
	_assert_false(controller.session.shared_ui().portal_action_is_enabled(), "Bandit clears stale Climb availability")
	_assert_eq(random.call_count(), 0, "Bandit and Pine Inspect consume zero combat RNG")
	_assert_eq(npc.relationship.opponent_ids(), npc_opponents, "Inspect changes no NPC relationship")
	_assert_eq(
		controller.player_runtime().relationship.opponent_ids(),
		player_opponents,
		"Inspect changes no player relationship",
	)
	_assert_eq(controller.corpse_states().size(), 0, "Inspect triggers no lifecycle/corpse mutation")
	controller.queue_free()
	await tree.process_frame


func _test_climb_and_return_traversal(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var state: CharacterState = controller.player_runtime().state
	var resource_snapshot: Array[int] = _character_resource_snapshot(state)
	var session: OldPineWorldSessionController = controller.session
	var tree_map: WorldMapController = session.world_map_of(OldPineWorldDefinitions.TREE_MAP_ID)
	_assert_true(controller.select_landmark(&"oldpine.outdoor.landmark.ancient_pine"), "pine target selects")
	# Climbing is a map handoff: the canopy is the tree map's (DECISIONS 3B5).
	var climb: OldPineMapHandoffResult = controller.traverse_selected_portal() as OldPineMapHandoffResult
	_assert_true(climb != null and climb.succeeded(), "clearing climb completes")
	if climb == null:
		await _free_scene(controller, tree)
		return
	_assert_true(climb.destination_attached, "physical embodiment updates")
	_assert_true(climb.location_committed, "logical location updates")
	_assert_eq(climb.source_map_id, OldPineWorldDefinitions.OUTDOOR_MAP_ID, "result records clearing source")
	_assert_eq(climb.destination_zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "result records canopy destination")
	_assert_eq(climb.destination_spawn_point_id, OldPineWorldDefinitions.TREE1_LANDING_SPAWN_POINT_ID, "result records the exact tree1 landing")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.TREE_MAP_ID, "climb activates the tree map")
	_assert_eq(tree_map.player_body.global_position, (tree_map.get_node("SpawnPoints/Tree1Landing") as Marker2D).global_position, "physical position uses exact tree1 marker")
	_assert_true(controller.player_runtime().state == state, "portal keeps authoritative CharacterState instance")
	_assert_eq(_character_resource_snapshot(state), resource_snapshot, "portal mutates no character resources")
	_assert_false(controller.session.shared_ui().portal_action_is_enabled(), "completed climb disables stale Pine action in canopy")
	# tree1's east bough narrows to its tip in dense needles; the body is 34 px wide. The
	# reattached map's tile collision is rebuilt on the next frame, before any real input.
	await tree.physics_frame
	tree_map.player_body.position = Vector2(2160.0, 300.0)
	Input.action_press("move_right")
	for _step: int in range(30):
		tree_map.player_body._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_assert_true(tree_map.player_body.global_position.x <= 2240.0 - 17.0 + 0.1, "the bough's end blocks movement")
	_assert_true(tree_map.player_body.global_position.x > 2160.0, "the body moved out along the bough")
	_assert_true(tree_map.select_landmark(&"oldpine.tree.landmark.tree1_descent"), "tree1 descent target selects")
	_assert_true(controller.session.shared_ui().portal_action_is_enabled(), "tree1 source enables explicit Descend")
	var descent: OldPineMapHandoffResult = tree_map.traverse_selected_portal() as OldPineMapHandoffResult
	_assert_true(descent != null and descent.succeeded(), "tree1 down returns to clearing")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "descent reactivates the forest map")
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "return restores clearing logical zone")
	_assert_eq(controller.player_body.global_position, (controller.get_node("SpawnPoints/ClearingPineLanding") as Marker2D).global_position, "return uses exact clearing marker")
	_assert_eq(_character_resource_snapshot(state), resource_snapshot, "return also mutates no character resources")
	_assert_false(controller.session.shared_ui().portal_action_is_enabled(), "completed return disables stale Descend and cannot loop")
	await _free_scene(controller, tree)


func _test_portal_rng_and_character_state_safety(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	var rng_control: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0, 0, 0])
	controller.session.configure_combat_random_source(random)
	var player: WorldPlayerRuntimeState = controller.player_runtime()
	var state: CharacterState = player.state
	var state_snapshot: Array[Variant] = _character_domain_snapshot(state)
	var relationship_snapshot: Array[Variant] = [
		player.relationship.opponent_ids(),
		player.relationship.lethal_target_ids(),
		player.relationship.guarding,
		player.relationship.last_opponent_id,
	]
	player.busy.start_busy(3)
	var tree_map: WorldMapController = controller.session.world_map_of(OldPineWorldDefinitions.TREE_MAP_ID)
	controller.select_landmark(&"oldpine.outdoor.landmark.ancient_pine")
	_assert_true(controller.inspect_selected(), "Pine Inspect succeeds before RNG audit")
	var climb: OldPineMapHandoffResult = controller.traverse_selected_portal() as OldPineMapHandoffResult
	tree_map.select_landmark(&"oldpine.tree.landmark.tree1_descent")
	_assert_true(tree_map.inspect_selected(), "tree1 Inspect succeeds before RNG audit")
	var descent: OldPineMapHandoffResult = tree_map.traverse_selected_portal() as OldPineMapHandoffResult
	_assert_true(climb != null and descent != null and climb.succeeded() and descent.succeeded(), "forward and return complete in RNG audit")
	_assert_eq(player.busy.busy_value, 3, "portal and Inspect do not advance or reject busy state")
	_assert_eq(random.call_count(), 0, "Inspect and both portal traversals consume zero combat RNG")
	_assert_eq(
		controller.npc_random_source().next_below(1000),
		rng_control.npc_random_source().next_below(1000),
		"portal and Inspect do not advance NPC initialization RNG stream",
	)
	_assert_eq(_character_domain_snapshot(state), state_snapshot, "portal changes no CharacterState domain facts")
	_assert_eq(
		[
			player.relationship.opponent_ids(),
			player.relationship.lethal_target_ids(),
			player.relationship.guarding,
			player.relationship.last_opponent_id,
		],
		relationship_snapshot,
		"portal changes no relationship authority directly",
	)
	# A map handoff records value IDs, not location objects a caller could mutate.
	if climb != null and descent != null:
		_assert_eq(
			[climb.source_map_id, climb.destination_map_id, climb.destination_zone_id],
			[OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.TREE_MAP_ID, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID],
			"climb result records the clearing source and canopy destination",
		)
		_assert_eq(
			[descent.source_map_id, descent.destination_map_id, descent.destination_zone_id],
			[OldPineWorldDefinitions.TREE_MAP_ID, OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID],
			"descent result records the canopy source and clearing destination",
		)
	await _free_scene(controller, tree)
	await _free_scene(rng_control, tree)


func _test_portal_rejections_and_combat_cleanup(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller.select_landmark(&"oldpine.outdoor.landmark.ancient_pine")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var before_position: Vector2 = controller.player_body.global_position
	var before_location: WorldLocationState = controller.player_runtime().world_location()
	controller._refresh_selected_landmark_source()
	_assert_false(controller.session.shared_ui().portal_action_is_enabled(), "wrong source disables stale Traverse action")
	var wrong_source: RefCounted = controller.traverse_selected_portal()
	_assert_false(_traversal_completed(wrong_source), "portal rejects wrong source zone")
	_assert_true(wrong_source is OldPineMapHandoffResult and (wrong_source as OldPineMapHandoffResult).outcome == OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID, "cross-map portal refuses a player outside its source zone")
	_assert_eq(controller.session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "wrong source starts no map handoff")
	_assert_eq(controller.player_body.global_position, before_position, "wrong source has no physical mutation")
	_assert_true(controller.player_runtime().world_location().same_location(before_location), "wrong source has no logical mutation")
	if controller.session.active_map_id() != OldPineWorldDefinitions.OUTDOOR_MAP_ID:
		# Keep the rest of the audit on the forest even if the rejection above failed.
		controller.session.handoff_to(
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
			OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
			OldPineWorldDefinitions.CLEARING_PINE_LANDING_SPAWN_POINT_ID,
		)
		controller.player_body.global_position = before_position
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
	))
	var central_location: WorldLocationState = controller.player_runtime().world_location()
	# The generic same-map adapter still validates any portal on its own; the
	# climb portal's destination is now the tree map's canopy and landing.
	var tree_map: WorldMapController = controller.session.world_map_of(OldPineWorldDefinitions.TREE_MAP_ID)
	var tree_landing: WorldSpawnMarker2D = tree_map.get_node("SpawnPoints/Tree1Landing") as WorldSpawnMarker2D
	var direct_adapter: WorldPortalTraversalAdapter = WorldPortalTraversalAdapter.new()
	var wrong_map_source: WorldLocationState = WorldLocationState.new(
		OldPineWorldDefinitions.REGION_ID,
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
	)
	controller.player_runtime().set_world_location(wrong_map_source)
	var wrong_map: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		GameContent.catalog().portal(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		tree_landing,
		tree_map.location_for_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID),
	)
	_assert_eq(wrong_map.outcome, WorldPortalTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH, "portal independently validates source map")
	_assert_eq(controller.player_body.global_position, before_position, "wrong source map has no physical mutation")
	controller.player_runtime().set_world_location(central_location)
	var missing_marker: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		GameContent.catalog().portal(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		null,
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.TREE_MAP_ID,
			OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID,
			OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID,
		),
	)
	_assert_eq(missing_marker.outcome, WorldPortalTraversalResult.Outcome.DESTINATION_MARKER_MISMATCH, "missing exact marker rejects")
	_assert_eq(controller.player_body.global_position, before_position, "missing marker has no physical mutation")
	_assert_eq(missing_marker.physical_position_updated, false, "missing marker reports no physical commit")
	_assert_eq(missing_marker.logical_location_updated, false, "missing marker reports no logical commit")
	var wrong_marker: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		GameContent.catalog().portal(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		controller.get_node("SpawnPoints/ClearingPineLanding") as WorldSpawnMarker2D,
		tree_map.location_for_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID),
	)
	_assert_eq(wrong_marker.outcome, WorldPortalTraversalResult.Outcome.DESTINATION_MARKER_MISMATCH, "wrong exact marker ID is rejected without fallback")
	_assert_eq(controller.player_body.global_position, before_position, "wrong marker ID has no physical mutation")
	var incoherent_destination: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		GameContent.catalog().portal(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		tree_landing,
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.TREE_MAP_ID,
			OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID,
			&"audit.wrong-combat-location",
		),
	)
	_assert_eq(
		incoherent_destination.outcome,
		WorldPortalTraversalResult.Outcome.DESTINATION_LOCATION_MISMATCH,
		"destination must match authored zone combat-location",
	)
	_assert_eq(controller.player_body.global_position, before_position, "incoherent destination has no physical mutation")
	_assert_true(controller.player_runtime().world_location().same_location(central_location), "incoherent destination has no logical mutation")
	var wrong_region_destination: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		GameContent.catalog().portal(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		tree_landing,
		WorldLocationState.new(
			&"audit.wrong-region",
			OldPineWorldDefinitions.TREE_MAP_ID,
			OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID,
			OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID,
		),
	)
	_assert_eq(wrong_region_destination.outcome, WorldPortalTraversalResult.Outcome.DESTINATION_LOCATION_MISMATCH, "destination must remain in authored Old Pine region")
	_assert_eq(controller.player_body.global_position, before_position, "wrong destination region has no physical mutation")
	_assert_true(controller.player_runtime().world_location().same_location(central_location), "wrong destination region has no logical mutation")
	var base_player: WorldPlayerRuntimeState = controller.player_runtime()
	var rejecting_player: RejectingLocationPlayer = RejectingLocationPlayer.new(
		base_player.character_id,
		base_player.state,
		base_player.relationship,
		base_player.busy,
		base_player.armor,
		base_player.world_location(),
		base_player.life_status,
		base_player.exists_in_world,
		base_player.combat_available,
		base_player.body_facts,
	)
	var partial: WorldPortalTraversalResult = direct_adapter.traverse(
		rejecting_player,
		controller.player_body,
		GameContent.catalog().portal(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		tree_landing,
		tree_map.location_for_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID),
	)
	_assert_eq(partial.outcome, WorldPortalTraversalResult.Outcome.LOGICAL_LOCATION_UPDATE_FAILED, "logical commit failure is typed")
	_assert_true(partial.physical_position_updated, "logical failure honestly preserves prior physical commit")
	_assert_false(partial.logical_location_updated, "logical failure reports no logical commit")
	_assert_eq(rejecting_player.world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "logical failure leaves runtime source unchanged")
	controller.player_body.global_position = before_position
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	var npc_home: WorldLocationState = npc.world_location()
	npc.set_world_location(controller.player_runtime().world_location())
	controller.select_npc(npc.character_id)
	var initiation: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(initiation.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "test combat starts through existing lethal path")
	controller.select_landmark(&"oldpine.outdoor.landmark.ancient_pine")
	var in_combat: RefCounted = controller.traverse_selected_portal()
	_assert_true(in_combat is OldPineMapHandoffResult and _traversal_completed(in_combat), "source LPC permits climb during combat")
	# The climb is a map handoff now. Its relationship reconciliation (the same
	# availability cleanup a combat round runs) separates the player from the
	# bandit left below at once; the bandit's own side is reconciled when its
	# map is active again.
	_assert_false(controller.player_runtime().relationship.is_fighting(), "existing availability cleanup removes moved player opponent")
	HistoricalCombat.tick(tree_map)
	_assert_false(controller.player_runtime().relationship.is_fighting(), "a later round in the canopy restores no opponent")
	_assert_true(npc.set_world_location(npc_home), "fixture returns the bandit to its slope")
	tree_map.select_landmark(&"oldpine.tree.landmark.tree1_descent")
	_assert_true(_traversal_completed(tree_map.traverse_selected_portal()), "the player climbs back down during the separation")
	_assert_false(npc.relationship.is_fighting(), "existing availability cleanup removes reciprocal opponent")
	_assert_false(controller.player_runtime().relationship.is_fighting(), "return to the forest restores no separated opponent")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(npc.character_id), "closed cross-location cleanup preserves player lethal intent")
	_assert_true(npc.relationship.has_lethal_target(controller.player_runtime().character_id), "closed cross-location cleanup preserves NPC lethal intent")
	await _free_scene(controller, tree)


func _test_deferred_aggression_and_deduplication(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0])
	controller.session.configure_combat_random_source(random)
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	OldPineTestMap.presence_entered(controller, 0, controller.player_body)
	_assert_true(controller.aggression_adapter().has_pending(npc.character_id), "presence queues one zero-delay opportunity")
	_assert_false(npc.relationship.is_fighting(), "presence callback itself mutates no relationship")
	_assert_false(controller.player_runtime().relationship.is_fighting(), "player relation also unchanged before next process")
	_assert_true(not HistoricalCombat.cadence_running(controller), "presence callback itself does not start cadence")
	_assert_eq(random.call_count(), 0, "presence callback consumes zero combat RNG")
	OldPineTestMap.presence_entered(controller, 0, controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 1, "duplicate presence is deduplicated per NPC")
	var initiations: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(initiations.size(), 1, "next-process opportunity initiates exactly once")
	_assert_eq(initiations[0].initiator_id, npc.character_id, "authored NPC is lethal initiator")
	_assert_eq(initiations[0].target_id, controller.player_runtime().character_id, "only player is aggression target")
	_assert_true(npc.relationship.has_lethal_target(controller.player_runtime().character_id), "aggression uses existing lethal marker authority")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(npc.character_id), "lethal initiation establishes reciprocal relation")
	_assert_false(not HistoricalCombat.cadence_running(controller), "successful aggression starts existing cadence Timer")
	_assert_eq(random.call_count(), 0, "aggression decision and lethal initiation consume zero combat RNG")
	_assert_true(controller.aggression_adapter().is_present(npc.character_id), "successful pending may retain current physical presence")
	await tree.process_frame
	await tree.process_frame
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "remaining presence does not reschedule aggression every frame")
	_assert_eq(controller.last_aggression_initiations().size(), 1, "successful pending fires exactly once")
	OldPineTestMap.presence_exited(controller, 0, controller.player_body)
	_assert_true(npc.relationship.is_fighting(), "presence exit does not clear established combat")
	OldPineTestMap.presence_entered(controller, 1, OldPineTestMap.body(controller, "Bandit01"))
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "non-player body never becomes aggression target")
	controller.queue_free()
	await tree.process_frame


func _test_aggression_cancellation_and_gates(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	OldPineTestMap.presence_entered(controller, 0, controller.player_body)
	OldPineTestMap.presence_exited(controller, 0, controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "leaving presence cancels pending opportunity")
	_assert_true(controller.process_pending_aggression().is_empty(), "cancelled opportunity cannot initiate")
	OldPineTestMap.presence_entered(controller, 0, controller.player_body)
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
	))
	_assert_true(controller.process_pending_aggression().is_empty(), "deferred recheck cancels different combat location")
	_assert_eq(controller.last_aggression_decisions()[0].outcome, NpcAggressionDecision.Outcome.DIFFERENT_COMBAT_LOCATION, "cancellation reason is typed")
	_assert_false(npc.relationship.is_fighting(), "co-location cancellation mutates no relation")
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive_npc: NpcAggressionDecision = OldPineTestMap.queue_presence(controller, 0, controller.player_body)
	_assert_eq(inactive_npc.outcome, NpcAggressionDecision.Outcome.NPC_NOT_ACTIVE, "unconscious NPC never queues")
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	var dead_npc: NpcAggressionDecision = OldPineTestMap.queue_presence(controller, 0, controller.player_body)
	_assert_eq(dead_npc.outcome, NpcAggressionDecision.Outcome.NPC_NOT_ACTIVE, "dead/corpse NPC leaves no active aggression trigger")
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	controller.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive_player: NpcAggressionDecision = OldPineTestMap.queue_presence(controller, 0, controller.player_body)
	_assert_eq(inactive_player.outcome, NpcAggressionDecision.Outcome.PLAYER_NOT_ACTIVE, "unconscious player is never targeted")
	controller.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	var blocked: NpcAggressionDecision = NpcAggressionAdapter.new().enter_player_presence(
		npc,
		controller.player_runtime(),
		false,
	)
	_assert_eq(blocked.outcome, NpcAggressionDecision.Outcome.COMBAT_NOT_ALLOWED, "no-fight projection blocks before queue")
	var peaceful: NpcRuntimeState = _runtime_without_aggression(npc)
	var not_authored: NpcAggressionDecision = NpcAggressionAdapter.new().enter_player_presence(
		peaceful,
		controller.player_runtime(),
		true,
	)
	_assert_eq(not_authored.outcome, NpcAggressionDecision.Outcome.NOT_AUTHORED, "capability gate is required")
	npc.set_combat_available(false)
	var npc_unavailable: NpcAggressionDecision = NpcAggressionAdapter.new().enter_player_presence(
		npc,
		controller.player_runtime(),
		true,
	)
	_assert_eq(npc_unavailable.outcome, NpcAggressionDecision.Outcome.NPC_NOT_AVAILABLE, "NPC combat availability gates initial queue")
	npc.set_combat_available(true)
	controller.player_runtime().set_combat_available(false)
	var player_unavailable: NpcAggressionDecision = NpcAggressionAdapter.new().enter_player_presence(
		npc,
		controller.player_runtime(),
		true,
	)
	_assert_eq(player_unavailable.outcome, NpcAggressionDecision.Outcome.PLAYER_NOT_AVAILABLE, "player combat availability gates initial queue")
	controller.player_runtime().set_combat_available(true)
	controller.queue_free()
	await tree.process_frame


func _test_area_escape_and_current_authority_rechecks(tree: SceneTree) -> void:
	var escape: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	escape.player_body.set_world_location(escape.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var escape_random: ScriptedCombatRandomSource = ScriptedRandomType.new([0])
	escape.session.configure_combat_random_source(escape_random)
	var escape_npc: NpcRuntimeState = escape.npc_runtimes()[0]
	var presence: Area2D = OldPineTestMap.body(escape, "Bandit01").get_node("AggressionPresence") as Area2D
	escape.set_process(false)
	escape.player_body.global_position = OldPineTestMap.body(escape, "Bandit01").global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(escape.aggression_adapter().has_pending(escape_npc.character_id), "persisted Area enter reaches pending adapter")
	_assert_false(escape_npc.relationship.is_fighting(), "Area enter signal remains pre-combat")
	escape.player_body.global_position = Vector2(100.0, 600.0)
	await tree.physics_frame
	await tree.physics_frame
	escape.set_process(true)
	await tree.process_frame
	_assert_eq(escape.aggression_adapter().pending_count(), 0, "actual Area exit cancels before deferred process")
	_assert_false(escape_npc.relationship.is_fighting(), "escape window creates no NPC combat")
	_assert_false(escape.player_runtime().relationship.is_fighting(), "escape window creates no player combat")
	_assert_true(not HistoricalCombat.cadence_running(escape), "escape window does not start Timer")
	_assert_eq(escape_random.call_count(), 0, "escape window consumes zero combat RNG")
	escape.queue_free()
	await tree.process_frame

	var removed: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	removed.player_body.set_world_location(removed.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var removed_npc: NpcRuntimeState = removed.npc_runtimes()[0]
	OldPineTestMap.presence_entered(removed, 0, removed.player_body)
	_assert_true(
		removed.map_character_state().remove_character(removed_npc.character_id),
		"audit fixture removes pending NPC from current map registry",
	)
	_assert_true(removed.process_pending_aggression().is_empty(), "unregistered pending NPC cannot initiate")
	_assert_eq(
		removed.last_aggression_decisions()[0].outcome,
		NpcAggressionDecision.Outcome.NPC_NOT_AVAILABLE,
		"deferred pass rebuilds registration/existence authority",
	)
	_assert_true(not HistoricalCombat.cadence_running(removed), "unregistered cancellation does not start Timer")
	removed.queue_free()
	await tree.process_frame

	var changed: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	changed.player_body.set_world_location(changed.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var changed_npc: NpcRuntimeState = changed.npc_runtimes()[0]
	OldPineTestMap.presence_entered(changed, 0, changed.player_body)
	changed.select_npc(changed_npc.character_id)
	_assert_eq(
		changed.attack_selected().outcome,
		CombatSliceInitiationResult.Outcome.COMPLETED,
		"manual path can establish combat after pending was queued",
	)
	HistoricalCombat.set_running(changed, true)
	_assert_true(changed.process_pending_aggression().is_empty(), "NPC fighting by another path cancels pending aggression")
	_assert_eq(
		changed.last_aggression_decisions()[0].outcome,
		NpcAggressionDecision.Outcome.NPC_ALREADY_FIGHTING,
		"current fighting authority is rechecked at deferred execution",
	)
	_assert_eq(changed.aggression_adapter().pending_count(), 0, "fighting cancellation clears pending")
	_assert_true(HistoricalCombat.cadence_running(changed), "canceled pending leaves the running cadence alone")
	var already_fighting: NpcAggressionDecision = OldPineTestMap.queue_presence(changed, 
		0,
		changed.player_body,
	)
	_assert_eq(already_fighting.outcome, NpcAggressionDecision.Outcome.NPC_ALREADY_FIGHTING, "already-fighting NPC never enters pending")
	_assert_eq(changed.aggression_adapter().pending_count(), 0, "already-fighting enter adds no duplicate pending")
	changed.queue_free()
	await tree.process_frame

	var live_recheck: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	live_recheck.player_body.set_world_location(live_recheck.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var live_npc: NpcRuntimeState = live_recheck.npc_runtimes()[0]
	OldPineTestMap.presence_entered(live_recheck, 0, live_recheck.player_body)
	live_recheck.player_runtime().set_combat_available(false)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "player combat availability change cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, NpcAggressionDecision.Outcome.PLAYER_NOT_AVAILABLE, "deferred pass reads current player availability")
	live_recheck.player_runtime().set_combat_available(true)
	OldPineTestMap.presence_exited(live_recheck, 0, live_recheck.player_body)
	OldPineTestMap.presence_entered(live_recheck, 0, live_recheck.player_body)
	live_npc.set_combat_available(false)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "NPC combat availability change cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, NpcAggressionDecision.Outcome.NPC_NOT_AVAILABLE, "deferred pass reads current NPC availability")
	live_npc.set_combat_available(true)
	OldPineTestMap.presence_exited(live_recheck, 0, live_recheck.player_body)
	OldPineTestMap.presence_entered(live_recheck, 0, live_recheck.player_body)
	var combat_blocked: Array[NpcAggressionDecision] = (
		live_recheck.aggression_adapter().resolve_pending(
			live_recheck.npc_runtimes(),
			live_recheck.player_runtime(),
			false,
		)
	)
	_assert_eq(combat_blocked[0].outcome, NpcAggressionDecision.Outcome.COMBAT_NOT_ALLOWED, "deferred pass reads current combat-allowed projection")
	OldPineTestMap.presence_exited(live_recheck, 0, live_recheck.player_body)
	OldPineTestMap.presence_entered(live_recheck, 0, live_recheck.player_body)
	live_recheck.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "player lifecycle change cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, NpcAggressionDecision.Outcome.PLAYER_NOT_ACTIVE, "deferred pass reads committed player life status")
	live_recheck.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	OldPineTestMap.presence_exited(live_recheck, 0, live_recheck.player_body)
	OldPineTestMap.presence_entered(live_recheck, 0, live_recheck.player_body)
	live_npc.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "NPC death before deferred pass cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, NpcAggressionDecision.Outcome.NPC_NOT_ACTIVE, "deferred pass reads committed NPC death")
	_assert_true(not HistoricalCombat.cadence_running(live_recheck), "all live-authority cancellations leave Timer stopped")
	live_recheck.queue_free()
	await tree.process_frame


func _test_player_already_fighting_and_timer_semantics(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	controller.select_npc(npcs[0].character_id)
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "first manual opponent establishes player combat")
	HistoricalCombat.set_running(controller, true)
	var queued: NpcAggressionDecision = OldPineTestMap.queue_presence(controller, 
		1,
		controller.player_body,
	)
	_assert_eq(queued.outcome, NpcAggressionDecision.Outcome.QUEUED, "player already fighting does not block second authored aggressor")
	var results: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(results.size(), 1, "second eligible aggressor initiates while player already fights")
	_assert_eq(results[0].initiator_id, npcs[1].character_id, "second aggressor is exact queued NPC")
	_assert_eq(controller.player_runtime().relationship.opponent_ids().size(), 2, "closed combat authority accepts two opponents")
	_assert_true(HistoricalCombat.cadence_running(controller), "successful aggression keeps the cadence running")
	controller.select_npc(npcs[1].character_id)
	var repeated: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(repeated.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "manual Attack after aggression remains idempotently accepted")
	_assert_true(HistoricalCombat.cadence_running(controller), "idempotent manual Attack keeps the cadence running")
	_assert_eq(controller.player_runtime().relationship.opponent_ids().size(), 2, "idempotent manual Attack adds no duplicate opponent")
	controller.queue_free()
	await tree.process_frame


func _test_multiple_bandits_are_stable_and_rng_free(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	var rng_control: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0, 0, 0])
	controller.session.configure_combat_random_source(random)
	OldPineTestMap.presence_entered(controller, 2, controller.player_body)
	OldPineTestMap.presence_entered(controller, 0, controller.player_body)
	OldPineTestMap.presence_entered(controller, 1, controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 3, "three overlapping presences queue independently")
	var results: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(results.size(), 3, "all three authored aggressors initiate")
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	for index: int in range(3):
		_assert_eq(results[index].initiator_id, npcs[index].character_id, "multi-aggression follows stable spawn order %d" % index)
		_assert_eq(results[index].target_id, controller.player_runtime().character_id, "multi-aggression target remains player")
		_assert_eq(results[index].outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "multi-aggression uses completed lethal path")
	_assert_eq(random.call_count(), 0, "aggression initiation consumes no combat RNG")
	_assert_eq(
		controller.npc_random_source().next_below(1000),
		rng_control.npc_random_source().next_below(1000),
		"multi-aggression does not advance NPC initialization RNG",
	)
	_assert_eq(controller.player_runtime().relationship.opponent_ids().size(), 3, "player receives three distinct opponents")
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "pending set clears after one processing opportunity")
	controller.queue_free()
	rng_control.queue_free()
	await tree.process_frame


func _test_aggressive_death_and_fresh_scene_boundary(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	var victim_body: WorldCharacterBody2D = OldPineTestMap.body(controller, "Bandit01")
	var presence: Area2D = OldPineTestMap.body(controller, "Bandit01").get_node("AggressionPresence") as Area2D
	controller.set_process(false)
	controller.player_body.global_position = victim_body.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.aggression_adapter().has_pending(victim.character_id), "physical Presence overlap creates deferred pending state")
	_assert_false(victim.relationship.is_fighting(), "physical Area enter still creates no immediate relation")
	controller.set_process(true)
	var aggressive_starts: Array[CombatSliceInitiationResult] = (
		controller.process_pending_aggression()
	)
	_assert_eq(
		aggressive_starts.size(),
		1,
		"next controller process starts death fixture through authored aggression",
	)
	_assert_true(controller.select_npc(victim.character_id), "aggressor may remain selected for stale-target audit")
	HistoricalCombat.set_running(controller, false)
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.vitality.current = -1
	HistoricalCombat.tick(controller)
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "aggressively initiated victim reaches closed unconscious lifecycle")
	var maximum: MaximumCombatRandomSource = MaximumCombatRandomSource.new()
	controller.session.configure_combat_random_source(maximum)
	for _tick: int in range(24):
		if victim.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		HistoricalCombat.tick(controller)
	_assert_true(maximum.call_count() > 0, "combat RNG begins only in later combat opportunities")
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "aggressively initiated combat reaches committed death")
	_assert_false(victim.exists_in_map, "dead aggressor leaves active map membership")
	_assert_false(victim_body.visible, "dead aggressor body is inactive")
	_assert_false(victim_body.input_pickable, "dead aggressor body cannot be selected")
	_assert_true(controller.session.shared_ui().attack_is_enabled() == false, "stale selected dead NPC disables Attack")
	_assert_ne(
		controller.attack_selected().outcome,
		CombatSliceInitiationResult.Outcome.COMPLETED,
		"stale dead target cannot be attacked",
	)
	_assert_eq(controller.corpse_states().size(), 1, "aggressive death leaves one authoritative corpse")
	_assert_eq(controller.get_node("CorpseLayer").get_child_count(), 1, "aggressive death leaves one corpse view")
	_assert_true(controller.npc_runtimes()[1].exists_in_map and controller.npc_runtimes()[2].exists_in_map, "other authored bandits remain after aggressive death")
	presence.body_entered.emit(controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "dead NPC Presence cannot retrigger aggression")
	_assert_eq(controller.map_character_state().ordered_active_characters().size(), 17, "dead aggressor does not respawn")
	var before_move: Vector2 = controller.player_body.position
	Input.action_press("move_right")
	controller.player_body._physics_process(1.0 / 30.0)
	Input.action_release("move_right")
	_assert_true(controller.player_body.position != before_move, "map remains playable after aggressive death")
	var old_adapter: NpcAggressionAdapter = controller.aggression_adapter()
	var old_npc_random: NpcInitializationRandomSource = controller.npc_random_source()
	var old_combat_random: CombatRandomSource = controller.combat_random_source()
	controller.queue_free()
	await tree.process_frame

	var fresh: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(fresh.selected_interaction_target() == null, "fresh scene clears CHARACTER/LANDMARK target")
	_assert_eq(fresh.aggression_adapter().pending_count(), 0, "fresh scene clears pending aggression")
	for fresh_npc: NpcRuntimeState in fresh.npc_runtimes():
		_assert_false(fresh.aggression_adapter().is_present(fresh_npc.character_id), "fresh scene clears presence state")
		_assert_false(fresh_npc.relationship.is_fighting(), "fresh scene clears NPC combat relations")
	_assert_true(fresh.aggression_adapter() != old_adapter, "fresh scene owns new map-local aggression state")
	_assert_true(fresh.npc_random_source() != old_npc_random, "fresh scene owns new NPC RNG authority")
	_assert_true(fresh.combat_random_source() != old_combat_random, "fresh scene owns new combat RNG authority")
	_assert_eq(fresh.corpse_states().size(), 0, "fresh scene clears corpses")
	_assert_eq(fresh.npc_runtimes().size(), 23, "fresh scene restores all 23 of the forest")
	_assert_eq(
		OldPineTestMap.body(fresh, "Bandit01").get_node("AggressionPresence").get_signal_connection_list("body_entered").size(),
		1,
		"fresh scene has one Presence enter connection",
	)
	for index: int in range(3):
		var fresh_presence: Area2D = OldPineTestMap.body(fresh, "Bandit%02d" % (index + 1)).get_node("AggressionPresence") as Area2D
		_assert_eq(fresh_presence.get_signal_connection_list("body_entered").size(), 1, "fresh Presence enter signal %d is unique" % index)
		_assert_eq(fresh_presence.get_signal_connection_list("body_exited").size(), 1, "fresh Presence exit signal %d is unique" % index)
	_assert_eq(
		fresh.get_node("Interactions/PineInteraction").get_signal_connection_list("selection_requested").size(),
		1,
		"fresh scene has one Pine selection connection",
	)
	_assert_eq(
		fresh.session.world_map_of(OldPineWorldDefinitions.TREE_MAP_ID).get_node("Interactions/Tree1DescentInteraction").get_signal_connection_list("selection_requested").size(),
		1,
		"fresh scene has one tree1 descent selection connection",
	)
	_assert_eq(
		fresh.session.shared_ui().portal_button.get_signal_connection_list("pressed").size(),
		1,
		"fresh scene has one production Traverse connection",
	)
	_assert_true(fresh.select_landmark(&"oldpine.outdoor.landmark.ancient_pine"), "fresh Pine target works")
	_assert_true(_traversal_completed(fresh.traverse_selected_portal()), "fresh Pine portal works after reset boundary")
	await _free_scene(fresh, tree)


func _runtime_without_aggression(source: NpcRuntimeState) -> NpcRuntimeState:
	var old: NpcDefinition = source.definition()
	var definition: NpcDefinition = NpcDefinition.new(
		&"oldpine.test.non_aggressive",
		"d/oldpine/npc/bandit.c",
		old.display_name,
		old.aliases(),
		old.race_id,
		old.has_authored_gender,
		old.gender,
		old.has_authored_age,
		old.age,
		old.base_attribute_overrides(),
		old.resource_overrides(),
		old.combat_experience,
		old.score,
		NpcDefinition.Attitude.PEACEFUL,
		old.skill_levels(),
		old.loadout_entries(),
		[],
		old.description,
	)
	var id: StringName = &"oldpine.test.non_aggressive.instance"
	return NpcRuntimeState.new(
		id,
		definition,
		&"oldpine.test.spawn",
		&"oldpine.test.point",
		source.character_state,
		CombatRelationshipState.new(id),
		ActionBusyState.new(),
		ArmorState.new(),
		source.world_location(),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		source.age,
		source.body_weight,
		source.maximum_encumbrance,
		[],
	)


func _character_resource_snapshot(state: CharacterState) -> Array[int]:
	return [
		state.essence.current,
		state.essence.effective,
		state.essence.maximum,
		state.vitality.current,
		state.vitality.effective,
		state.vitality.maximum,
		state.spirit.current,
		state.spirit.effective,
		state.spirit.maximum,
		state.recovery.inner_force.current,
		state.recovery.inner_force.maximum,
		state.recovery.mana.current,
		state.recovery.mana.maximum,
		state.recovery.atman.current,
		state.recovery.atman.maximum,
		state.recovery.food,
		state.recovery.water,
	]


func _character_domain_snapshot(state: CharacterState) -> Array[Variant]:
	var attributes: CharacterBaseAttributes = state.attributes
	var primary: EquippedWeaponRef = state.equipment.primary_weapon()
	var secondary: EquippedWeaponRef = state.equipment.secondary_weapon()
	return [
		state.gender,
		attributes.strength,
		attributes.courage,
		attributes.intelligence,
		attributes.spirituality,
		attributes.composure,
		attributes.personality,
		attributes.constitution,
		attributes.karma,
		attributes.force_factor,
		attributes.bellicosity,
		attributes.strength_modifier,
		attributes.courage_modifier,
		attributes.intelligence_modifier,
		attributes.spirituality_modifier,
		attributes.composure_modifier,
		attributes.personality_modifier,
		attributes.constitution_modifier,
		attributes.karma_modifier,
		_character_resource_snapshot(state),
		state.skills.raw_level(&"sword"),
		state.skills.learned_progress(&"sword"),
		state.skills.raw_level(&"parry"),
		state.skills.learned_progress(&"parry"),
		state.skills.raw_level(&"dodge"),
		state.skills.learned_progress(&"dodge"),
		state.skills.raw_level(&"unarmed"),
		state.skills.learned_progress(&"unarmed"),
		state.skills.raw_level(&"force"),
		state.skills.learned_progress(&"force"),
		state.skills.mapped_skill(&"sword"),
		state.skills.mapped_skill(&"parry"),
		state.skills.mapped_skill(&"dodge"),
		state.skills.mapped_skill(&"force"),
		state.progression.combat_experience,
		state.progression.potential,
		state.progression.potential_spent,
		&"" if primary == null else primary.instance_id,
		&"" if primary == null else primary.weapon_id,
		&"" if secondary == null else secondary.instance_id,
		&"" if secondary == null else secondary.weapon_id,
	]


func _instantiate_scene(tree: SceneTree) -> ControllerType:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var session: OldPineWorldSessionController = (
		packed.instantiate() as OldPineWorldSessionController
	)
	session.deterministic_npc_seed = true
	session.npc_seed = 77
	session.deterministic_combat_seed = true
	session.combat_seed = 88
	tree.root.add_child(session)
	preload("res://tests/support/historical_world_combat_fixture.gd").install(session)
	return session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)


## Frees the whole Session behind a map: after a climb its other maps hold the player.
func _free_scene(controller: ControllerType, tree: SceneTree) -> void:
	controller.session.queue_free()
	await tree.process_frame


## A landmark action moves the player on its map or, across maps, by handoff.
func _traversal_completed(result: RefCounted) -> bool:
	if result is WorldPortalTraversalResult:
		return (result as WorldPortalTraversalResult).completed()
	if result is OldPineMapHandoffResult:
		return (result as OldPineMapHandoffResult).succeeded()
	return false


func _click_area_through_viewport(area: Area2D, tree: SceneTree) -> void:
	var viewport: Viewport = area.get_viewport()
	var screen_position: Vector2 = area.get_global_transform_with_canvas().origin
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = screen_position
	motion.global_position = screen_position
	viewport.push_input(motion, true)
	await tree.physics_frame
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = screen_position
	click.global_position = screen_position
	click.pressed = true
	viewport.push_input(click, true)
	await tree.physics_frame
	click.pressed = false
	viewport.push_input(click, true)
	await tree.process_frame


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("FAIL: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("FAIL: %s (expected %s, got %s)" % [message, expected, actual])


func _assert_ne(actual: Variant, unexpected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("FAIL: %s (unexpected %s)" % [message, actual])
