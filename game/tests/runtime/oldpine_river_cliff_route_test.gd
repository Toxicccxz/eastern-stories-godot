extends RefCounted

const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

class CountingCombatRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		return maxi(exclusive_upper_bound - 1, 0)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_authored_route_definitions()
	await _test_complete_physical_route_and_authority_preservation(tree)
	await _test_cliff_return_stale_and_inactive_boundaries(tree)
	await _test_direct_pine_shortcut_and_route_collisions(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_authored_route_definitions() -> void:
	_assert_true(OldPineWorldDefinitions.validate(), "Old Pine route data validates")
	_assert_true(OldPineLandmarkDefinitions.validate(), "route landmarks validate")
	_assert_eq(
		OldPineWorldDefinitions.zone_by_id(
			OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID
		).legacy_room_ids(),
		["d/oldpine/riverbank1.c", "d/oldpine/riverbank2.c"],
		"River Gorge represents only implemented riverbank rooms",
	)
	_assert_eq(
		OldPineWorldDefinitions.zone_by_id(
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID
		).legacy_room_ids(),
		["d/oldpine/cliffside.c", "d/oldpine/cliff1.c"],
		"Cliff Ledge represents only implemented cliff rooms",
	)
	var expected: Array[Array] = [
		[
			OldPineWorldDefinitions.RIVERBANK1_CLIFF_PORTAL_ID,
			OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID,
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID,
			&"climb", &"cliff", "d/oldpine/riverbank1.c",
		],
		[
			OldPineWorldDefinitions.CLIFF1_DOWN_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID,
			OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID,
			&"climb", &"down", "d/oldpine/cliff1.c",
		],
		[
			OldPineWorldDefinitions.CLIFF1_UP_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID,
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID,
			&"climb", &"up", "d/oldpine/cliff1.c",
		],
		[
			OldPineWorldDefinitions.CLIFFSIDE_PINE1_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID,
			OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
			&"north", &"", "d/oldpine/cliffside.c",
		],
	]
	for facts: Array in expected:
		var portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(facts[0])
		_assert_true(portal != null and portal.is_valid(), "%s resolves" % facts[0])
		_assert_eq(portal.source_map_id, OldPineWorldDefinitions.OUTDOOR_MAP_ID, "route source remains Outdoor")
		_assert_eq(portal.destination_map_id, OldPineWorldDefinitions.OUTDOOR_MAP_ID, "route destination remains Outdoor")
		_assert_eq(portal.source_zone_id, facts[1], "%s source zone" % facts[0])
		_assert_eq(portal.destination_zone_id, facts[2], "%s destination zone" % facts[0])
		_assert_eq(portal.legacy_action_verb, facts[3], "%s legacy verb" % facts[0])
		_assert_eq(portal.legacy_action_argument, facts[4], "%s legacy argument" % facts[0])
		_assert_eq(portal.legacy_source_path, facts[5], "%s legacy source" % facts[0])
		_assert_true(portal.policy_id.is_empty(), "%s invents no policy" % facts[0])
	var reverse_count: int = 0
	for portal: PortalDefinition in OldPineWorldDefinitions.portal_definitions():
		if (
			portal.source_zone_id == OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID
			and portal.destination_zone_id == OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID
		):
			reverse_count += 1
	_assert_eq(reverse_count, 0, "pine1 has no invented reverse edge to cliffside")
	_assert_true(OldPineWorldDefinitions.portal_by_id(&"oldpine.outdoor.cliffdown_to_cliff2") == null, "cliffdown/cliff2 remains deferred")
	_assert_true(OldPineWorldDefinitions.zone_by_id(OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID).legacy_room_ids().has("d/oldpine/lake.c") == false, "Lake remains outside implemented route metadata")


func _test_complete_physical_route_and_authority_preservation(
	tree: SceneTree,
) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 93_331)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var random: ScriptedWorldInteractionRandomSource = (
		ScriptedWorldInteractionRandomSource.new([4])
	)
	var combat_random: CountingCombatRandomSource = CountingCombatRandomSource.new()
	_assert_true(session.configure_world_interaction_random_source(random), "route test installs one deterministic Vine draw")
	_assert_true(session.configure_combat_random_source(combat_random), "route test observes Combat RNG independently")
	var authorities: Array[Variant] = [
		player,
		player.state,
		player.state.equipment,
		player.armor,
		player.relationship,
		player.busy,
		session.inventory_state(),
		session.stack_collection(),
		session.item_instance_index(),
		session.npc_random_source(),
		session.combat_random_source(),
		session.world_interaction_random_source(),
	]
	var npc_authorities: Array[NpcRuntimeState] = outdoor.npc_runtimes()
	var npc_vitality_before: Array[int] = []
	var npc_item_ids_before: Array[Array] = []
	for npc: NpcRuntimeState in npc_authorities:
		npc_vitality_before.append(npc.character_state.vitality.current)
		npc_item_ids_before.append(_npc_item_ids(npc))
	var player_primary_id: StringName = player.state.equipment.primary_weapon().instance_id
	var corpse_count_before: int = outdoor.corpse_states().size()
	var resources_before: Array[int] = _resources(player.state)
	_assert_true(await _walk(outdoor.player_body, Vector2(1200, 300), tree), "player physically walks Central Clearing to East Bridge")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, "physical East Bridge updates location")
	_select_area(outdoor.get_node("Interactions/VineInteraction") as WorldLandmarkArea2D, outdoor)
	_assert_true(outdoor.hud.portal_action_is_enabled(), "actual Vine click enables the HUD action")
	_press_portal_action(outdoor)
	var vine: OldPineVineTraversalResult = outdoor.last_vine_traversal()
	_assert_eq(vine.outcome, OldPineVineTraversalResult.Outcome.COMPLETED_WATERFALL, "default authored route enters Waterfall")
	_assert_eq(random.call_count(), 1, "Vine consumes the route's only WorldInteraction RNG draw")
	await tree.process_frame
	await tree.physics_frame
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "arrival remains Waterfall through process and physics frames")
	_assert_eq(outdoor.player_body.global_position, outdoor.resolve_spawn_marker(OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).global_position, "Waterfall landing does not auto-fall south")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1080), tree), "player physically reaches the Waterfall-side bank threshold")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "Waterfall side of the threshold remains stable")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1140), tree), "intentional bank walk reaches riverbank2")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "riverbank2 enters River Gorge combat location")
	for _frame: int in range(3):
		await tree.physics_frame
		_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "River side of the threshold remains stable")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1350), tree), "player follows the intended east-bank route")
	var water_collision: KinematicCollision2D = outdoor.player_body.move_and_collide(Vector2(-400, 0))
	_assert_true(water_collision != null, "actual CharacterBody cannot cross the RiverStream water")
	_assert_true(outdoor.player_body.global_position.x >= 1387.0, "water collision stays aligned inside the visible stream edge")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1940), tree), "continuous bank walk reaches riverbank1 cliff without an invisible blocker")
	await _settle(tree)
	_select_area(outdoor.riverbank_cliff_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID, "climb reaches Cliff Ledge location")
	_assert_eq(outdoor.player_body.global_position, outdoor.resolve_spawn_marker(OldPineWorldDefinitions.CLIFF1_LANDING_SPAWN_POINT_ID).global_position, "climb reaches exact cliff1 landing")
	_assert_true(await _walk(outdoor.player_body, Vector2(680, 1650), tree), "player physically crosses cliff1 to the up route")
	await _settle(tree)
	_select_area(outdoor.cliff1_up_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_eq(outdoor.player_body.global_position, outdoor.resolve_spawn_marker(OldPineWorldDefinitions.CLIFFSIDE_LANDING_SPAWN_POINT_ID).global_position, "cliffside exact landing")
	var vitality_before_pine: int = player.state.vitality.current
	var relationships_before_pine: Array[StringName] = player.relationship.opponent_ids()
	_assert_true(await _walk(outdoor.player_body, Vector2(435, 1180), tree), "player physically walks north into one-way cliffside edge")
	await _settle(tree)
	var pine_result: WorldPortalTraversalResult = outdoor.last_cliffside_pine_traversal()
	_assert_true(pine_result != null and pine_result.completed(), "north edge performs one source-faithful cliffside to pine1 traversal")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "north edge reaches Pine Entrance")
	_assert_eq(outdoor.player_body.global_position, outdoor.resolve_spawn_marker(OldPineWorldDefinitions.PINE1_CLIFFSIDE_LANDING_SPAWN_POINT_ID).global_position, "north edge uses exact safe Pine landing")
	_assert_eq(player.life_status, CharacterRuntimeLifeStatus.Value.ACTIVE, "Pine landing leaves player ACTIVE")
	_assert_eq(player.state.vitality.current, vitality_before_pine, "Pine landing changes no vitality")
	_assert_eq(player.relationship.opponent_ids(), relationships_before_pine, "Pine landing creates no combat relationship")
	for npc_index: int in [3, 4]:
		var npc_body: WorldCharacterBody2D = (
			outdoor.tall_bandit_body if npc_index == 3 else outdoor.fat_bandit_body
		)
		_assert_true(outdoor.player_body.global_position.distance_to(npc_body.global_position) > 150.0, "Pine landing avoids authored bandit body/presence")
		_assert_false((npc_body.get_node("AggressionPresence") as Area2D).overlaps_body(outdoor.player_body), "Pine landing is outside authored aggression Presence")
	_assert_true(outdoor.player_body.global_position.distance_to(Vector2(-40, 300)) > 200.0, "Pine landing avoids Phase 9B1 direct shortcut threshold")
	var forward_result: WorldPortalTraversalResult = outdoor.last_cliffside_pine_traversal()
	_assert_true(await _walk(outdoor.player_body, Vector2(-80, 520), tree), "Pine-side CharacterBody moves back toward the B3 landing seam")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Pine-side reverse movement does not return to Cliffside")
	_assert_true(outdoor.last_cliffside_pine_traversal() == forward_result, "Pine-side movement triggers no second one-way traversal")
	_assert_false(outdoor.cliffside_pine_exit.overlaps_body(outdoor.player_body), "one-way Cliffside Area has no reverse Pine-side overlap")
	_assert_eq(random.call_count(), 1, "River/Cliff/Pine route consumes zero additional WorldInteraction RNG")
	_assert_eq(combat_random.calls, 0, "route consumes zero Combat RNG without cadence")
	_assert_eq(session.combat_random_source(), authorities[10], "route neither replaces nor consumes Combat RNG authority")
	_assert_eq(_resources(player.state), resources_before, "route mutates no character resources")
	var current_authorities: Array[Variant] = [
		session.player_runtime(), player.state, player.state.equipment, player.armor,
		player.relationship, player.busy, session.inventory_state(),
		session.stack_collection(), session.item_instance_index(),
		session.npc_random_source(), session.combat_random_source(),
		session.world_interaction_random_source(),
	]
	for index: int in range(authorities.size()):
		_assert_true(authorities[index] == current_authorities[index], "route preserves authority identity %d" % index)
	_assert_eq(player.state.equipment.primary_weapon().instance_id, player_primary_id, "route preserves exact player weapon ItemInstanceId")
	_assert_eq(outdoor.corpse_states().size(), corpse_count_before, "route neither creates nor removes corpse state")
	for index: int in range(npc_authorities.size()):
		_assert_true(outdoor.npc_runtimes()[index] == npc_authorities[index], "route preserves NPC authority identity %d" % index)
		_assert_eq(outdoor.npc_runtimes()[index].character_state.vitality.current, npc_vitality_before[index], "route preserves NPC vitality %d" % index)
		_assert_eq(_npc_item_ids(outdoor.npc_runtimes()[index]), npc_item_ids_before[index], "route preserves exact NPC item identities %d" % index)
	_assert_true(await _walk(outdoor.player_body, Vector2(-80, 220), tree), "player physically continues from B3 landing around authored bandit bodies")
	_assert_true(await _walk(outdoor.player_body, Vector2(-300, 220), tree), "player physically enters existing Tall/Fat aggression Presence")
	await _settle(tree)
	var pending_initiations: Array[CombatSliceInitiationResult] = outdoor.process_pending_aggression()
	_assert_true(player.relationship.is_fighting() or not pending_initiations.is_empty() or not outdoor.last_aggression_initiations().is_empty(), "only physical entry into existing Presence starts authored aggression")
	outdoor.opportunity_timer.stop()
	_assert_true(await _walk(outdoor.player_body, Vector2(-550, 220), tree), "player follows the existing Pine north approach")
	_assert_true(await _walk(outdoor.player_body, Vector2(-550, 350), tree), "player turns around the existing dead-end wall")
	_assert_true(await _walk(outdoor.player_body, Vector2(-650, 350), tree), "complete route reaches Pine Deep without teleport")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "complete Waterfall-to-Pine route ends in Pine Deep")
	var old_outdoor: WeakRef = weakref(outdoor)
	var old_rngs: Array[Variant] = [session.npc_random_source(), session.combat_random_source(), session.world_interaction_random_source()]
	await _free_session(session, tree)
	var fresh_session: OldPineWorldSessionController = await _session(tree, 93_334)
	var fresh: OldPineOutdoorController = fresh_session.outdoor_map()
	_assert_true(old_outdoor.get_ref() == null, "whole Session reset frees the traversed Outdoor node")
	_assert_eq(fresh.npc_runtimes().size(), 5, "reset creates five fresh authored NPCs")
	_assert_eq(fresh.corpse_states().size(), 0, "reset has no prior corpse")
	_assert_true(fresh.selected_interaction_target() == null, "reset has no stale River/Cliff target")
	_assert_eq(fresh_session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "reset returns to Central Clearing")
	_assert_true(fresh_session.npc_random_source() != old_rngs[0] and fresh_session.combat_random_source() != old_rngs[1] and fresh_session.world_interaction_random_source() != old_rngs[2], "reset owns three fresh RNG authorities")
	_assert_true(fresh.get_node_or_null("Terrain/Boundaries/RiverWaterBoundary/CollisionShape2D") is CollisionShape2D, "reset reloads authored River collision unchanged")
	await _free_session(fresh_session, tree)


func _test_cliff_return_stale_and_inactive_boundaries(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 93_332)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var combat_random: CountingCombatRandomSource = CountingCombatRandomSource.new()
	_assert_true(session.configure_combat_random_source(combat_random), "combat-location fixture observes traversal RNG isolation")
	_assert_true(await _walk(outdoor.player_body, Vector2(1200, 1000), tree), "return fixture reaches Waterfall south opening")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1080), tree), "return fixture reaches the intended east bank")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1940), tree), "return fixture physically walks into River Gorge")
	await _settle(tree)
	_assert_true(await _walk(outdoor.player_body, Vector2(1390, 1940), tree), "return fixture reaches cliff interaction")
	await _settle(tree)
	player.busy.start_busy(7)
	var opponent: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var opponent_original_location: WorldLocationState = opponent.world_location()
	_assert_true(player.relationship.mark_lethal_target(opponent.character_id), "fixture establishes fighting state without cadence")
	_assert_true(opponent.relationship.mark_lethal_target(player.character_id), "fixture establishes reciprocal fighting state")
	_select_area(outdoor.riverbank_cliff_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID, "busy/fighting climb reaches Cliff1")
	_assert_eq(player.busy.busy_value, 7, "climb neither rejects nor advances busy")
	_assert_true(player.relationship.has_opponent(opponent.character_id), "River-to-Cliff traversal directly edits no relationship")
	for _advance: int in range(8):
		player.busy.advance()
	outdoor.process_cadence_tick()
	_assert_false(player.relationship.has_opponent(opponent.character_id), "next availability opportunity clears separated ordinary opponent")
	_assert_true(player.relationship.has_lethal_target(opponent.character_id), "separation cleanup retains lethal marker")
	_assert_eq(combat_random.calls, 0, "separated cleanup draws zero Combat RNG")
	_assert_true(await _walk(outdoor.player_body, Vector2(200, 1940), tree), "player reaches Cliff1 Down landmark")
	await _settle(tree)
	_select_area(outdoor.cliff1_down_interaction as WorldLandmarkArea2D, outdoor)
	_assert_true(await _walk(outdoor.player_body, Vector2(435, 1300), tree), "player leaves stale Cliff1 Down while staying in Cliff Ledge")
	await _settle(tree)
	var before: Vector2 = outdoor.player_body.global_position
	_assert_false(outdoor.traverse_selected_portal().completed(), "Cliffside rejects stale Cliff1 Down despite shared zone")
	_assert_eq(outdoor.player_body.global_position, before, "stale Cliff1 Down performs no movement")
	_assert_true(await _walk(outdoor.player_body, Vector2(200, 1940), tree), "player physically reaches climb-down landmark")
	await _settle(tree)
	_select_area(outdoor.cliff1_down_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "climb down restores River Gorge")
	_assert_eq(outdoor.player_body.global_position, outdoor.resolve_spawn_marker(OldPineWorldDefinitions.RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID).global_position, "climb down exact riverbank1 landing")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1140), tree), "reverse route physically reaches Riverbank2")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "Riverbank1 and Riverbank2 share River Gorge combat location")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1080), tree), "reverse route physically re-enters Waterfall")
	await _settle(tree)
	for _frame: int in range(3):
		await tree.physics_frame
		_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "reverse Waterfall boundary remains stable")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1940), tree), "stale fixture returns along the east bank")
	await _settle(tree)
	_assert_true(await _walk(outdoor.player_body, Vector2(1390, 1940), tree), "stale fixture re-enters cliff interaction")
	await _settle(tree)
	_select_area(outdoor.riverbank_cliff_interaction as WorldLandmarkArea2D, outdoor)
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1600), tree), "player physically leaves selected landmark while staying in River Gorge")
	await _settle(tree)
	before = outdoor.player_body.global_position
	_assert_false(outdoor.traverse_selected_portal().completed(), "stale landmark execution rechecks physical source")
	_assert_eq(outdoor.player_body.global_position, before, "stale execution performs no movement")
	_assert_false(outdoor.hud.portal_action_is_enabled(), "stale execution refreshes visible action availability")
	_assert_true(await _walk(outdoor.player_body, Vector2(1390, 1940), tree), "inactive fixture returns to exact cliff interaction")
	await _settle(tree)
	_select_area(outdoor.riverbank_cliff_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_true(await _walk(outdoor.player_body, Vector2(680, 1650), tree), "Cliff1 Up stale fixture reaches authored landmark")
	await _settle(tree)
	_select_area(outdoor.cliff1_up_interaction as WorldLandmarkArea2D, outdoor)
	_assert_true(await _walk(outdoor.player_body, Vector2(435, 1300), tree), "player leaves stale Cliff1 Up while staying in Cliff Ledge")
	await _settle(tree)
	before = outdoor.player_body.global_position
	_assert_false(outdoor.traverse_selected_portal().completed(), "Cliffside rejects stale Cliff1 Up despite shared zone")
	_assert_eq(outdoor.player_body.global_position, before, "stale Cliff1 Up performs no movement")
	_assert_true(opponent.set_world_location(player.world_location()), "fixture co-locates opponent at Cliff1 combat location")
	_assert_true(player.relationship.mark_lethal_target(opponent.character_id), "fixture re-establishes same-Cliff relationship")
	_assert_true(opponent.relationship.mark_lethal_target(player.character_id), "fixture re-establishes reciprocal same-Cliff relationship")
	_assert_true(await _walk(outdoor.player_body, Vector2(680, 1650), tree), "continuity fixture returns to Cliff1 Up")
	await _settle(tree)
	_select_area(outdoor.cliff1_up_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_true(player.world_location().shares_combat_location(opponent.world_location()), "Cliff1 Up keeps same Cliff Ledge combat location")
	_assert_true(player.relationship.has_opponent(opponent.character_id), "Cliff1-to-Cliffside traversal performs no ordinary cleanup")
	_assert_true(opponent.set_world_location(opponent_original_location), "fixture restores authored opponent location")
	_assert_true(await _walk(outdoor.player_body, Vector2(200, 1940), tree), "inactive fixture reaches Cliff1 Down")
	await _settle(tree)
	_select_area(outdoor.cliff1_down_interaction as WorldLandmarkArea2D, outdoor)
	_press_portal_action(outdoor)
	_assert_true(await _walk(outdoor.player_body, Vector2(1390, 1940), tree), "inactive fixture returns to Riverbank Cliff")
	await _settle(tree)
	_select_area(outdoor.riverbank_cliff_interaction as WorldLandmarkArea2D, outdoor)
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	before = outdoor.player_body.global_position
	_assert_false(outdoor.traverse_selected_portal().completed(), "non-ACTIVE character cannot climb")
	_assert_eq(outdoor.player_body.global_position, before, "inactive rejection performs no physical mutation")
	await _free_session(session, tree)


func _test_direct_pine_shortcut_and_route_collisions(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 93_333)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	_assert_true(outdoor.find_children("ResetButton", "Button", true, false).is_empty(), "audited Outdoor hierarchy preserves Phase 10C1A Reset removal")
	_assert_true(outdoor.get_node_or_null("Terrain/Boundaries/WaterfallSouthBoundary") == null, "only Waterfall south staging block is removed")
	var river_water: CollisionShape2D = outdoor.get_node_or_null("Terrain/Boundaries/RiverWaterBoundary/CollisionShape2D") as CollisionShape2D
	_assert_true(river_water != null and river_water.shape is RectangleShape2D, "visible RiverStream owns an actual physics boundary")
	if river_water != null and river_water.shape is RectangleShape2D:
		_assert_eq((river_water.shape as RectangleShape2D).size, Vector2(340, 1100), "water collision exactly matches the visible RiverStream")
	_assert_true(outdoor.get_node_or_null("Zones/RiverGorgeZone") is Area2D, "River Gorge zone persists")
	_assert_true(outdoor.get_node_or_null("Zones/CliffLedgeZone") is Area2D, "Cliff Ledge zone persists")
	_assert_eq(outdoor.cliffside_pine_exit.get_signal_connection_list(&"body_entered").size(), 1, "one-way north edge signal persists once")
	_assert_eq((outdoor.get_node("Characters/Player/Camera2D") as Camera2D).limit_bottom, 2230, "camera covers full River/Cliff route")
	_assert_true(await _walk(outdoor.player_body, Vector2(-100, 300), tree), "Phase 9B1 direct Outdoor to Pine shortcut remains physical")
	await _settle(tree)
	_assert_eq(outdoor.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "direct shortcut still reaches Pine Entrance")
	_assert_true(await _walk(outdoor.player_body, Vector2(80, 300), tree), "Phase 9B1 Pine shortcut remains bidirectional")
	await _settle(tree)
	_assert_eq(outdoor.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "direct shortcut returns to Outdoor")
	_assert_true(await _walk(outdoor.player_body, Vector2(1200, 300), tree), "player avoids authored South Slope bodies through East Bridge")
	_assert_true(await _walk(outdoor.player_body, Vector2(1200, 1000), tree), "player returns through the Waterfall south opening")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 1080), tree), "player can step onto the intended River bank without invisible collision")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 2140), tree), "Lake southern boundary is physically reachable along the bank")
	await _settle(tree)
	var lake_collision: KinematicCollision2D = outdoor.player_body.move_and_collide(Vector2(0, 160))
	_assert_true(lake_collision != null, "deferred Lake boundary is physically blocked")
	_assert_eq(outdoor.player_runtime().world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "blocked Lake creates no fake location")
	_assert_true(await _walk(outdoor.player_body, Vector2(1420, 2000), tree), "player can retreat from the deferred Lake boundary")
	_assert_true(outdoor.get_node_or_null("Terrain/Boundaries/PineMazeObstacles/CliffNorth") is CollisionShape2D, "Pine cliffdown boundary remains closed")
	await _free_session(session, tree)


func _select_area(area: WorldLandmarkArea2D, outdoor: OldPineOutdoorController) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	area._input_event(outdoor.get_viewport(), click, 0)


func _press_portal_action(outdoor: OldPineOutdoorController) -> void:
	_assert_true(outdoor.hud.portal_action_is_enabled(), "selected authored action is enabled at its physical source")
	outdoor.hud.portal_button.pressed.emit()


func _npc_item_ids(npc: NpcRuntimeState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: ItemInstance in npc.loadout_items():
		ids.append(item.item_instance_id)
	return ids


func _walk(
	body: CharacterBody2D,
	target: Vector2,
	tree: SceneTree,
) -> bool:
	for _step: int in range(1000):
		var remaining: Vector2 = target - body.global_position
		if remaining.length() <= 0.5:
			return true
		if body.move_and_collide(remaining.limit_length(10.0)) != null:
			return false
		if _step % 5 == 4:
			await tree.physics_frame
	return false


func _resources(state: CharacterState) -> Array[int]:
	return [
		state.essence.current, state.essence.effective,
		state.vitality.current, state.vitality.effective,
		state.spirit.current, state.spirit.effective,
		state.recovery.inner_force.current, state.recovery.inner_force.maximum,
		state.recovery.mana.current, state.recovery.mana.maximum,
		state.recovery.atman.current, state.recovery.atman.maximum,
		state.recovery.food, state.recovery.water,
	]


func _count_tree_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_tree_nodes(child)
	return count


func _settle(tree: SceneTree) -> void:
	await tree.physics_frame
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame


func _session(tree: SceneTree, seed: int) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = (
		SessionScene.instantiate() as OldPineWorldSessionController
	)
	session.deterministic_npc_seed = true
	session.npc_seed = seed
	session.deterministic_combat_seed = true
	session.combat_seed = seed + 1
	session.deterministic_world_interaction_seed = true
	session.world_interaction_seed = seed + 2
	tree.root.add_child(session)
	await tree.process_frame
	_assert_true(session.player_runtime() != null, "session initializes route player")
	return session


func _free_session(
	session: OldPineWorldSessionController,
	tree: SceneTree,
) -> void:
	session.queue_free()
	await tree.process_frame
	await tree.process_frame


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
