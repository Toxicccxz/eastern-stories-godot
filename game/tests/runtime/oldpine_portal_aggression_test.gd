extends RefCounted

const SCENE_PATH: String = "res://scenes/world/oldpine/oldpine_outdoor.tscn"
const ControllerType := preload(
	"res://runtime/world/oldpine_outdoor_controller.gd"
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
	_assert_true(OldPineWorldDefinitions.validate(), "Old Pine world data remains coherent")
	_assert_true(OldPineLandmarkDefinitions.validate(), "landmark references resolve")
	var pine: WorldLandmarkDefinition = (
		OldPineLandmarkDefinitions.definition_by_id(
			OldPineLandmarkDefinitions.PINE_LANDMARK_ID
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
	var climb: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		pine.portal_id
	)
	_assert_eq(climb.destination_zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "climb destination zone")
	_assert_eq(climb.destination_spawn_point_id, OldPineWorldDefinitions.TREE1_LANDING_SPAWN_POINT_ID, "climb exact landing ID")
	var descent: WorldLandmarkDefinition = (
		OldPineLandmarkDefinitions.definition_by_id(
			OldPineLandmarkDefinitions.TREE1_DESCENT_LANDMARK_ID
		)
	)
	_assert_eq(descent.display_name, "大松树上", "tree1 authored name")
	_assert_eq(
		descent.description,
		"你现在正攀附在一株大松树的树干上，从这里可以很清楚地望见树\n"
		+ "下的一切动静，而不被人发觉，似乎是个干偷鸡摸狗勾当的好地方。\n",
		"tree1 inspect text traces tree1.c long",
	)
	_assert_eq(descent.action_label, "Descend", "tree1 authored action label")
	_assert_eq(descent.portal_id, OldPineWorldDefinitions.DESCEND_TREE1_PORTAL_ID, "tree1 descent resolves return portal")
	_assert_eq(descent.legacy_source_path, "d/oldpine/tree1.c", "tree1 descent source metadata")
	var return_portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		descent.portal_id
	)
	_assert_eq(return_portal.source_zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "return source is exact tree1 canopy zone")
	_assert_eq(return_portal.destination_zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "return destination is exact clearing zone")
	_assert_eq(return_portal.destination_spawn_point_id, OldPineWorldDefinitions.CLEARING_PINE_LANDING_SPAWN_POINT_ID, "return resolves exact pine landing")
	_assert_eq(return_portal.policy_id, &"", "tree1 return has no invented policy")
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
	var descent_area: WorldLandmarkArea2D = controller.get_node_or_null(
		"Interactions/Tree1DescentInteraction"
	) as WorldLandmarkArea2D
	_assert_true(pine_area != null and pine_area.is_configured(), "pine click Area2D persists")
	_assert_true(descent_area != null and descent_area.is_configured(), "return click Area2D persists")
	_assert_eq(pine_area.get_signal_connection_list("selection_requested").size(), 1, "pine typed selection signal persists once")
	_assert_eq(descent_area.get_signal_connection_list("selection_requested").size(), 1, "descent typed selection signal persists once")
	var canopy_zone: Area2D = controller.get_node_or_null("Zones/TreeCanopyZone") as Area2D
	_assert_true(canopy_zone != null, "TreeCanopyZone Area2D persists")
	_assert_true(canopy_zone.get_node_or_null("CollisionShape2D") is CollisionShape2D, "TreeCanopyZone has collision")
	_assert_eq(canopy_zone.get_signal_connection_list("body_entered").size(), 1, "TreeCanopyZone logical adapter persists")
	var tree_landing: WorldSpawnMarker2D = controller.get_node_or_null(
		"SpawnPoints/Tree1Landing"
	) as WorldSpawnMarker2D
	var clearing_landing: WorldSpawnMarker2D = controller.get_node_or_null(
		"SpawnPoints/ClearingPineLanding"
	) as WorldSpawnMarker2D
	_assert_eq(tree_landing.spawn_point_id, OldPineWorldDefinitions.TREE1_LANDING_SPAWN_POINT_ID, "tree1 marker has exact portal ID")
	_assert_eq(clearing_landing.spawn_point_id, OldPineWorldDefinitions.CLEARING_PINE_LANDING_SPAWN_POINT_ID, "return marker has exact portal ID")
	_assert_true(controller.get_node_or_null("Terrain/TreeCanopyPlatform") is ColorRect, "canopy geometry persists in same map")
	_assert_true(controller.get_node_or_null("Terrain/Boundaries/TreeCanopyBounds/Right") is CollisionShape2D, "canopy boundary collision persists")
	_assert_eq((controller.get_node("Characters/Player/Camera2D") as Camera2D).limit_right, 2300, "camera covers canopy platform")
	for index: int in range(3):
		var presence: Area2D = controller.get_node(
			"Characters/Bandit%02d/AggressionPresence" % (index + 1)
		) as Area2D
		_assert_eq(presence.collision_layer, 0, "presence Area does not become physical body")
		_assert_eq(presence.collision_mask, 1, "presence Area observes character bodies")
		_assert_eq(presence.get_signal_connection_list("body_entered").size(), 1, "presence enter signal persists once")
		_assert_eq(presence.get_signal_connection_list("body_exited").size(), 1, "presence exit signal persists once")
	var first_shape: CircleShape2D = (
		controller.get_node("Characters/Bandit01/AggressionPresence/CollisionShape2D")
		as CollisionShape2D
	).shape as CircleShape2D
	var second_shape: CircleShape2D = (
		controller.get_node("Characters/Bandit02/AggressionPresence/CollisionShape2D")
		as CollisionShape2D
	).shape as CircleShape2D
	var bandit_distance: float = controller.bandit_bodies[0].global_position.distance_to(
		controller.bandit_bodies[1].global_position
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
	_assert_eq(selected.target_id, OldPineLandmarkDefinitions.PINE_LANDMARK_ID, "real pine picking selects stable landmark ID")
	_assert_true(controller.hud.portal_action_is_enabled(), "Climb action becomes available for active player")
	_assert_eq(controller.hud.portal_action_text(), "Climb", "HUD uses authored action label")
	_assert_false(controller.hud.attack_is_enabled(), "landmark target never enables Attack")
	_assert_true(controller.inspect_selected(), "landmark Inspect is available")
	_assert_true(controller.hud.inspection_display().contains("风吹动"), "HUD renders authored pine description")
	controller.queue_free()
	await tree.process_frame


func _test_target_kind_and_inspect_safety(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0, 0])
	controller.configure_combat_random_source(random)
	controller._on_south_slope_body_entered(controller.player_body)
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	var npc_opponents: Array[StringName] = npc.relationship.opponent_ids()
	var player_opponents: Array[StringName] = (
		controller.player_runtime().relationship.opponent_ids()
	)
	_assert_true(controller.select_npc(npc.character_id), "Bandit target selects first")
	_assert_true(controller.hud.inspect_button.disabled == false, "Bandit enables Inspect")
	_assert_true(controller.hud.attack_is_enabled(), "Bandit enables Attack for active player")
	_assert_false(controller.hud.portal_action_is_enabled(), "Bandit disables Traverse")
	_assert_true(controller.inspect_selected(), "Bandit Inspect remains presentation-only")
	_assert_true(
		controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID),
		"Bandit to Pine switches target kind",
	)
	_assert_true(controller.hud.inspect_button.disabled == false, "Pine enables Inspect")
	_assert_false(controller.hud.attack_is_enabled(), "Pine disables stale Attack")
	_assert_false(
		controller.hud.portal_action_is_enabled(),
		"Pine selected from South Slope does not expose stale Climb",
	)
	_assert_true(controller.inspect_selected(), "Pine Inspect remains available off-source")
	controller._on_central_clearing_body_entered(controller.player_body)
	_assert_true(
		controller.hud.portal_action_is_enabled(),
		"selected Pine enables Climb only after current source becomes valid",
	)
	controller._on_south_slope_body_entered(controller.player_body)
	_assert_true(controller.select_npc(npc.character_id), "Pine to Bandit restores character target")
	_assert_true(controller.hud.attack_is_enabled(), "Bandit restores Attack availability")
	_assert_false(controller.hud.portal_action_is_enabled(), "Bandit clears stale Climb availability")
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
	_assert_true(controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID), "pine target selects")
	var climb: WorldPortalTraversalResult = controller.traverse_selected_portal()
	_assert_true(climb.completed(), "clearing climb completes")
	_assert_true(climb.physical_position_updated, "physical embodiment updates")
	_assert_true(climb.logical_location_updated, "logical location updates")
	_assert_eq(climb.previous_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "result records clearing source")
	_assert_eq(climb.current_location().zone_id, OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID, "result records canopy destination")
	_assert_eq(controller.player_body.global_position, (controller.get_node("SpawnPoints/Tree1Landing") as Marker2D).global_position, "physical position uses exact tree1 marker")
	_assert_true(controller.player_runtime().state == state, "portal keeps authoritative CharacterState instance")
	_assert_eq(_character_resource_snapshot(state), resource_snapshot, "portal mutates no character resources")
	_assert_false(controller.hud.portal_action_is_enabled(), "completed climb disables stale Pine action in canopy")
	controller.player_body.position = Vector2(2275.0, 260.0)
	Input.action_press("move_right")
	for _step: int in range(30):
		controller.player_body._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_assert_true(controller.player_body.global_position.x <= 2283.1, "canopy right boundary blocks movement")
	_assert_true(controller.select_landmark(OldPineLandmarkDefinitions.TREE1_DESCENT_LANDMARK_ID), "tree1 descent target selects")
	_assert_true(controller.hud.portal_action_is_enabled(), "tree1 source enables explicit Descend")
	var descent: WorldPortalTraversalResult = controller.traverse_selected_portal()
	_assert_true(descent.completed(), "tree1 down returns to clearing")
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "return restores clearing logical zone")
	_assert_eq(controller.player_body.global_position, (controller.get_node("SpawnPoints/ClearingPineLanding") as Marker2D).global_position, "return uses exact clearing marker")
	_assert_eq(_character_resource_snapshot(state), resource_snapshot, "return also mutates no character resources")
	_assert_false(controller.hud.portal_action_is_enabled(), "completed return disables stale Descend and cannot loop")
	controller.queue_free()
	await tree.process_frame


func _test_portal_rng_and_character_state_safety(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	var rng_control: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0, 0, 0])
	controller.configure_combat_random_source(random)
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
	controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID)
	_assert_true(controller.inspect_selected(), "Pine Inspect succeeds before RNG audit")
	var climb: WorldPortalTraversalResult = controller.traverse_selected_portal()
	controller.select_landmark(OldPineLandmarkDefinitions.TREE1_DESCENT_LANDMARK_ID)
	_assert_true(controller.inspect_selected(), "tree1 Inspect succeeds before RNG audit")
	var descent: WorldPortalTraversalResult = controller.traverse_selected_portal()
	_assert_true(climb.completed() and descent.completed(), "forward and return complete in RNG audit")
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
	var previous_snapshot: WorldLocationState = climb.previous_location()
	var current_snapshot: WorldLocationState = climb.current_location()
	previous_snapshot._zone_id = &"audit.mutated.previous"
	current_snapshot._zone_id = &"audit.mutated.current"
	_assert_eq(
		climb.previous_location().zone_id,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		"portal previous location getter returns a defensive snapshot",
	)
	_assert_eq(
		climb.current_location().zone_id,
		OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID,
		"portal current location getter returns a defensive snapshot",
	)
	controller.queue_free()
	rng_control.queue_free()
	await tree.process_frame


func _test_portal_rejections_and_combat_cleanup(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID)
	controller._on_south_slope_body_entered(controller.player_body)
	var before_position: Vector2 = controller.player_body.global_position
	var before_location: WorldLocationState = controller.player_runtime().world_location()
	_assert_false(controller.hud.portal_action_is_enabled(), "wrong source disables stale Traverse action")
	var wrong_source: WorldPortalTraversalResult = controller.traverse_selected_portal()
	_assert_eq(wrong_source.outcome, WorldPortalTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH, "portal rejects wrong source zone")
	_assert_eq(controller.player_body.global_position, before_position, "wrong source has no physical mutation")
	_assert_true(controller.player_runtime().world_location().same_location(before_location), "wrong source has no logical mutation")
	controller._on_central_clearing_body_entered(controller.player_body)
	var central_location: WorldLocationState = controller.player_runtime().world_location()
	var direct_adapter: OldPinePortalTraversalAdapter = OldPinePortalTraversalAdapter.new()
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
		OldPineWorldDefinitions.portal_by_id(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		controller.get_node("SpawnPoints/Tree1Landing") as WorldSpawnMarker2D,
		controller._location_for_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID),
	)
	_assert_eq(wrong_map.outcome, WorldPortalTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH, "portal independently validates source map")
	_assert_eq(controller.player_body.global_position, before_position, "wrong source map has no physical mutation")
	controller.player_runtime().set_world_location(central_location)
	var missing_marker: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		OldPineWorldDefinitions.portal_by_id(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		null,
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
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
		OldPineWorldDefinitions.portal_by_id(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		controller.get_node("SpawnPoints/ClearingPineLanding") as WorldSpawnMarker2D,
		controller._location_for_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID),
	)
	_assert_eq(wrong_marker.outcome, WorldPortalTraversalResult.Outcome.DESTINATION_MARKER_MISMATCH, "wrong exact marker ID is rejected without fallback")
	_assert_eq(controller.player_body.global_position, before_position, "wrong marker ID has no physical mutation")
	var incoherent_destination: WorldPortalTraversalResult = direct_adapter.traverse(
		controller.player_runtime(),
		controller.player_body,
		OldPineWorldDefinitions.portal_by_id(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		controller.get_node("SpawnPoints/Tree1Landing") as WorldSpawnMarker2D,
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
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
		OldPineWorldDefinitions.portal_by_id(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		controller.get_node("SpawnPoints/Tree1Landing") as WorldSpawnMarker2D,
		WorldLocationState.new(
			&"audit.wrong-region",
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
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
	)
	var partial: WorldPortalTraversalResult = direct_adapter.traverse(
		rejecting_player,
		controller.player_body,
		OldPineWorldDefinitions.portal_by_id(OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID),
		controller.get_node("SpawnPoints/Tree1Landing") as WorldSpawnMarker2D,
		controller._location_for_zone(OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID),
	)
	_assert_eq(partial.outcome, WorldPortalTraversalResult.Outcome.LOGICAL_LOCATION_UPDATE_FAILED, "logical commit failure is typed")
	_assert_true(partial.physical_position_updated, "logical failure honestly preserves prior physical commit")
	_assert_false(partial.logical_location_updated, "logical failure reports no logical commit")
	_assert_eq(rejecting_player.world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "logical failure leaves runtime source unchanged")
	controller.player_body.global_position = before_position
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	npc.set_world_location(controller.player_runtime().world_location())
	controller.select_npc(npc.character_id)
	var initiation: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(initiation.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "test combat starts through existing lethal path")
	controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID)
	var in_combat: WorldPortalTraversalResult = controller.traverse_selected_portal()
	_assert_true(in_combat.completed(), "source LPC permits climb during combat")
	_assert_true(controller.player_runtime().relationship.is_fighting(), "portal does not invent immediate forced disengage")
	controller.process_cadence_tick()
	_assert_false(controller.player_runtime().relationship.is_fighting(), "existing availability cleanup removes moved player opponent")
	_assert_false(npc.relationship.is_fighting(), "existing availability cleanup removes reciprocal opponent")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(npc.character_id), "closed cross-location cleanup preserves player lethal intent")
	_assert_true(npc.relationship.has_lethal_target(controller.player_runtime().character_id), "closed cross-location cleanup preserves NPC lethal intent")
	controller.queue_free()
	await tree.process_frame


func _test_deferred_aggression_and_deduplication(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0])
	controller.configure_combat_random_source(random)
	controller._on_south_slope_body_entered(controller.player_body)
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	controller._on_bandit_01_presence_entered(controller.player_body)
	_assert_true(controller.aggression_adapter().has_pending(npc.character_id), "presence queues one zero-delay opportunity")
	_assert_false(npc.relationship.is_fighting(), "presence callback itself mutates no relationship")
	_assert_false(controller.player_runtime().relationship.is_fighting(), "player relation also unchanged before next process")
	_assert_true(controller.opportunity_timer.is_stopped(), "presence callback itself does not start cadence")
	_assert_eq(random.call_count(), 0, "presence callback consumes zero combat RNG")
	controller._on_bandit_01_presence_entered(controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 1, "duplicate presence is deduplicated per NPC")
	var initiations: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(initiations.size(), 1, "next-process opportunity initiates exactly once")
	_assert_eq(initiations[0].initiator_id, npc.character_id, "authored NPC is lethal initiator")
	_assert_eq(initiations[0].target_id, controller.player_runtime().character_id, "only player is aggression target")
	_assert_true(npc.relationship.has_lethal_target(controller.player_runtime().character_id), "aggression uses existing lethal marker authority")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(npc.character_id), "lethal initiation establishes reciprocal relation")
	_assert_false(controller.opportunity_timer.is_stopped(), "successful aggression starts existing cadence Timer")
	_assert_eq(random.call_count(), 0, "aggression decision and lethal initiation consume zero combat RNG")
	_assert_true(controller.aggression_adapter().is_present(npc.character_id), "successful pending may retain current physical presence")
	await tree.process_frame
	await tree.process_frame
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "remaining presence does not reschedule aggression every frame")
	_assert_eq(controller.last_aggression_initiations().size(), 1, "successful pending fires exactly once")
	controller._on_bandit_01_presence_exited(controller.player_body)
	_assert_true(npc.relationship.is_fighting(), "presence exit does not clear established combat")
	controller._on_bandit_02_presence_entered(controller.bandit_bodies[0])
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "non-player body never becomes aggression target")
	controller.queue_free()
	await tree.process_frame


func _test_aggression_cancellation_and_gates(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller._on_south_slope_body_entered(controller.player_body)
	var npc: NpcRuntimeState = controller.npc_runtimes()[0]
	controller._on_bandit_01_presence_entered(controller.player_body)
	controller._on_bandit_01_presence_exited(controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "leaving presence cancels pending opportunity")
	_assert_true(controller.process_pending_aggression().is_empty(), "cancelled opportunity cannot initiate")
	controller._on_bandit_01_presence_entered(controller.player_body)
	controller._on_central_clearing_body_entered(controller.player_body)
	_assert_true(controller.process_pending_aggression().is_empty(), "deferred recheck cancels different combat location")
	_assert_eq(controller.last_aggression_decisions()[0].outcome, OldPineAggressionDecision.Outcome.DIFFERENT_COMBAT_LOCATION, "cancellation reason is typed")
	_assert_false(npc.relationship.is_fighting(), "co-location cancellation mutates no relation")
	controller._on_south_slope_body_entered(controller.player_body)
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive_npc: OldPineAggressionDecision = controller._queue_bandit_presence(0, controller.player_body)
	_assert_eq(inactive_npc.outcome, OldPineAggressionDecision.Outcome.NPC_NOT_ACTIVE, "unconscious NPC never queues")
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	var dead_npc: OldPineAggressionDecision = controller._queue_bandit_presence(0, controller.player_body)
	_assert_eq(dead_npc.outcome, OldPineAggressionDecision.Outcome.NPC_NOT_ACTIVE, "dead/corpse NPC leaves no active aggression trigger")
	npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	controller.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive_player: OldPineAggressionDecision = controller._queue_bandit_presence(0, controller.player_body)
	_assert_eq(inactive_player.outcome, OldPineAggressionDecision.Outcome.PLAYER_NOT_ACTIVE, "unconscious player is never targeted")
	controller.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	var blocked: OldPineAggressionDecision = OldPineBanditAggressionAdapter.new().enter_player_presence(
		npc,
		controller.player_runtime(),
		false,
	)
	_assert_eq(blocked.outcome, OldPineAggressionDecision.Outcome.COMBAT_NOT_ALLOWED, "no-fight projection blocks before queue")
	var peaceful: NpcRuntimeState = _runtime_without_aggression(npc)
	var not_authored: OldPineAggressionDecision = OldPineBanditAggressionAdapter.new().enter_player_presence(
		peaceful,
		controller.player_runtime(),
		true,
	)
	_assert_eq(not_authored.outcome, OldPineAggressionDecision.Outcome.NOT_AUTHORED, "capability gate is required")
	npc.set_combat_available(false)
	var npc_unavailable: OldPineAggressionDecision = OldPineBanditAggressionAdapter.new().enter_player_presence(
		npc,
		controller.player_runtime(),
		true,
	)
	_assert_eq(npc_unavailable.outcome, OldPineAggressionDecision.Outcome.NPC_NOT_AVAILABLE, "NPC combat availability gates initial queue")
	npc.set_combat_available(true)
	controller.player_runtime().set_combat_available(false)
	var player_unavailable: OldPineAggressionDecision = OldPineBanditAggressionAdapter.new().enter_player_presence(
		npc,
		controller.player_runtime(),
		true,
	)
	_assert_eq(player_unavailable.outcome, OldPineAggressionDecision.Outcome.PLAYER_NOT_AVAILABLE, "player combat availability gates initial queue")
	controller.player_runtime().set_combat_available(true)
	controller.queue_free()
	await tree.process_frame


func _test_area_escape_and_current_authority_rechecks(tree: SceneTree) -> void:
	var escape: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	escape._on_south_slope_body_entered(escape.player_body)
	var escape_random: ScriptedCombatRandomSource = ScriptedRandomType.new([0])
	escape.configure_combat_random_source(escape_random)
	var escape_npc: NpcRuntimeState = escape.npc_runtimes()[0]
	var presence: Area2D = escape.get_node(
		"Characters/Bandit01/AggressionPresence"
	) as Area2D
	escape.set_process(false)
	escape.player_body.global_position = escape.bandit_bodies[0].global_position
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
	_assert_true(escape.opportunity_timer.is_stopped(), "escape window does not start Timer")
	_assert_eq(escape_random.call_count(), 0, "escape window consumes zero combat RNG")
	escape.queue_free()
	await tree.process_frame

	var removed: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	removed._on_south_slope_body_entered(removed.player_body)
	var removed_npc: NpcRuntimeState = removed.npc_runtimes()[0]
	removed._on_bandit_01_presence_entered(removed.player_body)
	_assert_true(
		removed.map_character_state().remove_character(removed_npc.character_id),
		"audit fixture removes pending NPC from current map registry",
	)
	_assert_true(removed.process_pending_aggression().is_empty(), "unregistered pending NPC cannot initiate")
	_assert_eq(
		removed.last_aggression_decisions()[0].outcome,
		OldPineAggressionDecision.Outcome.NPC_NOT_AVAILABLE,
		"deferred pass rebuilds registration/existence authority",
	)
	_assert_true(removed.opportunity_timer.is_stopped(), "unregistered cancellation does not start Timer")
	removed.queue_free()
	await tree.process_frame

	var changed: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	changed._on_south_slope_body_entered(changed.player_body)
	var changed_npc: NpcRuntimeState = changed.npc_runtimes()[0]
	changed._on_bandit_01_presence_entered(changed.player_body)
	changed.select_npc(changed_npc.character_id)
	_assert_eq(
		changed.attack_selected().outcome,
		CombatSliceInitiationResult.Outcome.COMPLETED,
		"manual path can establish combat after pending was queued",
	)
	changed.opportunity_timer.start(9.0)
	_assert_true(changed.process_pending_aggression().is_empty(), "NPC fighting by another path cancels pending aggression")
	_assert_eq(
		changed.last_aggression_decisions()[0].outcome,
		OldPineAggressionDecision.Outcome.NPC_ALREADY_FIGHTING,
		"current fighting authority is rechecked at deferred execution",
	)
	_assert_eq(changed.aggression_adapter().pending_count(), 0, "fighting cancellation clears pending")
	_assert_true(changed.opportunity_timer.time_left > 8.0, "canceled pending does not restart running Timer")
	var already_fighting: OldPineAggressionDecision = changed._queue_bandit_presence(
		0,
		changed.player_body,
	)
	_assert_eq(already_fighting.outcome, OldPineAggressionDecision.Outcome.NPC_ALREADY_FIGHTING, "already-fighting NPC never enters pending")
	_assert_eq(changed.aggression_adapter().pending_count(), 0, "already-fighting enter adds no duplicate pending")
	changed.queue_free()
	await tree.process_frame

	var live_recheck: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	live_recheck._on_south_slope_body_entered(live_recheck.player_body)
	var live_npc: NpcRuntimeState = live_recheck.npc_runtimes()[0]
	live_recheck._on_bandit_01_presence_entered(live_recheck.player_body)
	live_recheck.player_runtime().set_combat_available(false)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "player combat availability change cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, OldPineAggressionDecision.Outcome.PLAYER_NOT_AVAILABLE, "deferred pass reads current player availability")
	live_recheck.player_runtime().set_combat_available(true)
	live_recheck._on_bandit_01_presence_exited(live_recheck.player_body)
	live_recheck._on_bandit_01_presence_entered(live_recheck.player_body)
	live_npc.set_combat_available(false)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "NPC combat availability change cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, OldPineAggressionDecision.Outcome.NPC_NOT_AVAILABLE, "deferred pass reads current NPC availability")
	live_npc.set_combat_available(true)
	live_recheck._on_bandit_01_presence_exited(live_recheck.player_body)
	live_recheck._on_bandit_01_presence_entered(live_recheck.player_body)
	var combat_blocked: Array[OldPineAggressionDecision] = (
		live_recheck.aggression_adapter().resolve_pending(
			live_recheck.npc_runtimes(),
			live_recheck.player_runtime(),
			false,
		)
	)
	_assert_eq(combat_blocked[0].outcome, OldPineAggressionDecision.Outcome.COMBAT_NOT_ALLOWED, "deferred pass reads current combat-allowed projection")
	live_recheck._on_bandit_01_presence_exited(live_recheck.player_body)
	live_recheck._on_bandit_01_presence_entered(live_recheck.player_body)
	live_recheck.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "player lifecycle change cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, OldPineAggressionDecision.Outcome.PLAYER_NOT_ACTIVE, "deferred pass reads committed player life status")
	live_recheck.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	live_recheck._on_bandit_01_presence_exited(live_recheck.player_body)
	live_recheck._on_bandit_01_presence_entered(live_recheck.player_body)
	live_npc.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	_assert_true(live_recheck.process_pending_aggression().is_empty(), "NPC death before deferred pass cancels pending")
	_assert_eq(live_recheck.last_aggression_decisions()[0].outcome, OldPineAggressionDecision.Outcome.NPC_NOT_ACTIVE, "deferred pass reads committed NPC death")
	_assert_true(live_recheck.opportunity_timer.is_stopped(), "all live-authority cancellations leave Timer stopped")
	live_recheck.queue_free()
	await tree.process_frame


func _test_player_already_fighting_and_timer_semantics(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller._on_south_slope_body_entered(controller.player_body)
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	controller.select_npc(npcs[0].character_id)
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "first manual opponent establishes player combat")
	controller.opportunity_timer.start(9.0)
	var queued: OldPineAggressionDecision = controller._queue_bandit_presence(
		1,
		controller.player_body,
	)
	_assert_eq(queued.outcome, OldPineAggressionDecision.Outcome.QUEUED, "player already fighting does not block second authored aggressor")
	var results: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(results.size(), 1, "second eligible aggressor initiates while player already fights")
	_assert_eq(results[0].initiator_id, npcs[1].character_id, "second aggressor is exact queued NPC")
	_assert_eq(controller.player_runtime().relationship.opponent_ids().size(), 2, "closed combat authority accepts two opponents")
	_assert_true(controller.opportunity_timer.time_left > 8.0, "successful aggression does not restart running Timer")
	controller.select_npc(npcs[1].character_id)
	var repeated: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(repeated.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "manual Attack after aggression remains idempotently accepted")
	_assert_true(controller.opportunity_timer.time_left > 8.0, "idempotent manual Attack does not restart Timer")
	_assert_eq(controller.player_runtime().relationship.opponent_ids().size(), 2, "idempotent manual Attack adds no duplicate opponent")
	controller.queue_free()
	await tree.process_frame


func _test_multiple_bandits_are_stable_and_rng_free(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	var rng_control: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	controller._on_south_slope_body_entered(controller.player_body)
	var random: ScriptedCombatRandomSource = ScriptedRandomType.new([0, 0, 0])
	controller.configure_combat_random_source(random)
	controller._on_bandit_03_presence_entered(controller.player_body)
	controller._on_bandit_01_presence_entered(controller.player_body)
	controller._on_bandit_02_presence_entered(controller.player_body)
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
	controller._on_south_slope_body_entered(controller.player_body)
	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	var victim_body: WorldCharacterBody2D = controller.bandit_bodies[0]
	var presence: Area2D = controller.get_node(
		"Characters/Bandit01/AggressionPresence"
	) as Area2D
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
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.vitality.current = -1
	controller.process_cadence_tick()
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "aggressively initiated victim reaches closed unconscious lifecycle")
	var maximum: MaximumCombatRandomSource = MaximumCombatRandomSource.new()
	controller.configure_combat_random_source(maximum)
	for _tick: int in range(24):
		if victim.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		controller.process_cadence_tick()
	_assert_true(maximum.call_count() > 0, "combat RNG begins only in later combat opportunities")
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "aggressively initiated combat reaches committed death")
	_assert_false(victim.exists_in_map, "dead aggressor leaves active map membership")
	_assert_false(victim_body.visible, "dead aggressor body is inactive")
	_assert_false(victim_body.input_pickable, "dead aggressor body cannot be selected")
	_assert_true(controller.hud.attack_is_enabled() == false, "stale selected dead NPC disables Attack")
	_assert_ne(
		controller.attack_selected().outcome,
		CombatSliceInitiationResult.Outcome.COMPLETED,
		"stale dead target cannot be attacked",
	)
	_assert_eq(controller.corpse_states().size(), 1, "aggressive death leaves one authoritative corpse")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "aggressive death leaves one corpse view")
	_assert_true(controller.npc_runtimes()[1].exists_in_map and controller.npc_runtimes()[2].exists_in_map, "other authored bandits remain after aggressive death")
	presence.body_entered.emit(controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 0, "dead NPC Presence cannot retrigger aggression")
	_assert_eq(controller.map_character_state().ordered_active_characters().size(), 2, "dead aggressor does not respawn")
	var before_move: Vector2 = controller.player_body.position
	Input.action_press("move_right")
	controller.player_body._physics_process(1.0 / 30.0)
	Input.action_release("move_right")
	_assert_true(controller.player_body.position != before_move, "map remains playable after aggressive death")
	var old_adapter: OldPineBanditAggressionAdapter = controller.aggression_adapter()
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
	_assert_eq(fresh.npc_runtimes().size(), 3, "fresh scene restores exactly three initial bandits")
	_assert_eq(
		fresh.get_node("Characters/Bandit01/AggressionPresence").get_signal_connection_list("body_entered").size(),
		1,
		"fresh scene has one Presence enter connection",
	)
	for index: int in range(3):
		var fresh_presence: Area2D = fresh.get_node(
			"Characters/Bandit%02d/AggressionPresence" % (index + 1)
		) as Area2D
		_assert_eq(fresh_presence.get_signal_connection_list("body_entered").size(), 1, "fresh Presence enter signal %d is unique" % index)
		_assert_eq(fresh_presence.get_signal_connection_list("body_exited").size(), 1, "fresh Presence exit signal %d is unique" % index)
	_assert_eq(
		fresh.get_node("Interactions/PineInteraction").get_signal_connection_list("selection_requested").size(),
		1,
		"fresh scene has one Pine selection connection",
	)
	_assert_eq(
		fresh.get_node("Interactions/Tree1DescentInteraction").get_signal_connection_list("selection_requested").size(),
		1,
		"fresh scene has one tree1 descent selection connection",
	)
	_assert_eq(
		fresh.hud.portal_button.get_signal_connection_list("pressed").size(),
		1,
		"fresh scene has one production Traverse connection",
	)
	_assert_true(fresh.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID), "fresh Pine target works")
	_assert_true(fresh.traverse_selected_portal().completed(), "fresh Pine portal works after reset boundary")
	fresh.queue_free()
	await tree.process_frame


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
	var controller: ControllerType = packed.instantiate() as ControllerType
	controller.deterministic_npc_seed = true
	controller.npc_seed = 77
	controller.deterministic_combat_seed = true
	controller.combat_seed = 88
	tree.root.add_child(controller)
	return controller


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
