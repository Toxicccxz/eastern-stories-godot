extends RefCounted

const HistoricalCombat := preload("res://tests/support/historical_world_combat_fixture.gd")

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
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_true(GameContent.load_errors().is_empty(), "Old Pine route data validates")
	_assert_true(GameContent.load_errors().is_empty(), "route landmarks validate")
	_assert_eq(
		catalog.zone(
			OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID
		).room_ids(),
		[&"es2:d/oldpine/riverbank1", &"es2:d/oldpine/riverbank2"],
		"River Gorge represents only implemented riverbank rooms",
	)
	_assert_eq(
		catalog.zone(
			OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID
		).room_ids(),
		[&"es2:d/oldpine/cliff1"],
		"the cliff niche represents only cliff1",
	)
	var cliffside: ZoneDefinition = catalog.zone(OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID)
	_assert_eq(cliffside.room_ids(), [&"es2:d/oldpine/cliffside"], "cliffside is its own zone")
	_assert_eq(cliffside.map_id, OldPineWorldDefinitions.OUTDOOR_MAP_ID, "cliffside lies on the forest map")
	# Each height change of the route is an ES2 action and a map handoff (DECISIONS 3B5).
	var expected: Array[Array] = [
		[
			OldPineWorldDefinitions.RIVERBANK1_CLIFF_PORTAL_ID,
			OldPineWorldDefinitions.GORGE_MAP_ID, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID,
			OldPineWorldDefinitions.CLIFF_MAP_ID, OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID,
			OldPineWorldDefinitions.CLIFF1_LANDING_SPAWN_POINT_ID,
			"climb cliff", &"es2:d/oldpine/riverbank1",
		],
		[
			OldPineWorldDefinitions.CLIFF1_DOWN_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF_MAP_ID, OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID,
			OldPineWorldDefinitions.GORGE_MAP_ID, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID,
			OldPineWorldDefinitions.RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID,
			"climb down", &"es2:d/oldpine/cliff1",
		],
		[
			OldPineWorldDefinitions.CLIFF1_UP_PORTAL_ID,
			OldPineWorldDefinitions.CLIFF_MAP_ID, OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID,
			OldPineWorldDefinitions.CLIFFSIDE_LANDING_SPAWN_POINT_ID,
			"climb up", &"es2:d/oldpine/cliff1",
		],
	]
	for facts: Array in expected:
		var portal: PortalDefinition = catalog.portal(facts[0])
		_assert_true(portal != null and portal.is_valid(), "%s resolves" % facts[0])
		if portal == null:
			continue
		_assert_eq(portal.source_map_id, facts[1], "%s source map" % facts[0])
		_assert_eq(portal.source_zone_id, facts[2], "%s source zone" % facts[0])
		_assert_eq(portal.destination_map_id, facts[3], "%s destination map" % facts[0])
		_assert_eq(portal.destination_zone_id, facts[4], "%s destination zone" % facts[0])
		_assert_eq(portal.destination_spawn_point_id, facts[5], "%s exact landing" % facts[0])
		_assert_ne(portal.source_map_id, portal.destination_map_id, "%s crosses maps" % facts[0])
		_assert_eq(portal.legacy_command, facts[6], "%s legacy command" % facts[0])
		_assert_eq(portal.legacy_room_id, facts[7], "%s legacy room" % facts[0])
	# cliffside.c north is an ordinary exit: walked, not a portal.
	var cliffside_exits: Dictionary[String, StringName] = catalog.room(&"es2:d/oldpine/cliffside").exits()
	_assert_eq(cliffside_exits.size(), 1, "cliffside keeps its single ES2 exit")
	_assert_eq(cliffside_exits.get("north", &""), &"es2:d/oldpine/pine1", "cliffside.c north leads to pine1")
	_assert_true(catalog.zones_adjacent(OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "walking north from cliffside may enter Pine Entrance")
	_assert_false(catalog.room(&"es2:d/oldpine/pine1").exits().values().has(&"es2:d/oldpine/cliffside"), "pine1 has no invented reverse exit to cliffside")
	var cliffside_portals: int = 0
	var reverse_count: int = 0
	for map: MapDefinition in catalog.maps():
		for portal: PortalDefinition in catalog.portals_for_map(map.map_id):
			if portal.source_zone_id == OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID:
				cliffside_portals += 1
			if (
				portal.source_zone_id == OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID
				and portal.destination_zone_id == OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID
			):
				reverse_count += 1
	_assert_eq(cliffside_portals, 0, "cliffside north is no portal")
	_assert_eq(reverse_count, 0, "pine1 has no invented reverse edge to cliffside")
	_assert_true(catalog.portal(&"oldpine.outdoor.cliffdown_to_cliff2") == null, "cliffdown/cliff2 remains deferred")
	_assert_true(catalog.zone(OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID).room_ids().has(&"es2:d/oldpine/lake") == false, "Lake remains outside implemented route metadata")


func _test_complete_physical_route_and_authority_preservation(
	tree: SceneTree,
) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 93_331)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	var cliff: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CLIFF_MAP_ID)
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
	# The route crosses the forest, the gorge and the cliff: observe every Old Pine NPC.
	var npc_authorities: Array[NpcRuntimeState] = session.world_npcs()
	_assert_eq(npc_authorities.size(), 34, "route observes the 34 authored Old Pine NPCs")
	var npc_vitality_before: Array[int] = []
	var npc_item_ids_before: Array[Array] = []
	for npc: NpcRuntimeState in npc_authorities:
		npc_vitality_before.append(npc.character_state.vitality.current)
		npc_item_ids_before.append(_npc_item_ids(npc))
	var player_primary_id: StringName = player.state.equipment.primary_weapon().instance_id
	var corpse_count_before: int = _corpse_count(session)
	var resources_before: Array[int] = _resources(player.state)
	_assert_true(await _walk(outdoor.player_body, Vector2(1200, 300), tree), "player physically walks Central Clearing to East Bridge")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, "physical East Bridge updates location")
	_select_area(outdoor.get_node("Interactions/VineInteraction") as WorldLandmarkArea2D, outdoor)
	_assert_true(outdoor.session.shared_ui().portal_action_is_enabled(), "actual Vine click enables the HUD action")
	_press_portal_action(outdoor)
	var vine: VineTraversalResult = outdoor.last_landmark_use() as VineTraversalResult
	_assert_true(vine != null, "Vine use records its typed result")
	if vine == null:
		await _free_session(session, tree)
		return
	_assert_eq(vine.outcome, VineTraversalResult.Outcome.COMPLETED_WATERFALL, "default authored route enters Waterfall")
	_assert_true(vine.map_handoff_result != null and vine.map_handoff_result.succeeded(), "the fall is a handoff down to the gorge map")
	_assert_eq(random.call_count(), 1, "Vine consumes the route's only WorldInteraction RNG draw")
	await tree.process_frame
	await tree.physics_frame
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "the gorge map is active below the bridge")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "arrival remains Waterfall through process and physics frames")
	_assert_eq(gorge.player_body.global_position, gorge.resolve_spawn_marker(OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).global_position, "Waterfall landing does not auto-fall south")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1080), tree), "player physically reaches the Waterfall-side bank threshold")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "Waterfall side of the threshold remains stable")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1140), tree), "intentional bank walk reaches riverbank2")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "riverbank2 enters River Gorge combat location")
	for _frame: int in range(3):
		await tree.physics_frame
		_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "River side of the threshold remains stable")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1350), tree), "player follows the intended east-bank route")
	var water_collision: KinematicCollision2D = gorge.player_body.move_and_collide(Vector2(-400, 0))
	_assert_true(water_collision != null, "actual CharacterBody cannot cross the river water")
	_assert_true(gorge.player_body.global_position.x >= 1387.0, "water collision stays aligned inside the visible stream edge")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1940), tree), "continuous bank walk reaches riverbank1 cliff without an invisible blocker")
	await _settle(tree)
	_select_area(gorge.get_node("Interactions/RiverbankCliffInteraction") as WorldLandmarkArea2D, gorge)
	_press_portal_action(gorge)
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CLIFF_MAP_ID, "climb cliff hands off to the cliff map")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID, "climb reaches the cliff1 niche location")
	_assert_eq(cliff.player_body.global_position, cliff.resolve_spawn_marker(OldPineWorldDefinitions.CLIFF1_LANDING_SPAWN_POINT_ID).global_position, "climb reaches exact cliff1 landing")
	await _settle(tree)
	_assert_true(await _walk(cliff.player_body, Vector2(680, 1650), tree), "player physically crosses cliff1 to the up route")
	await _settle(tree)
	_select_area(cliff.get_node("Interactions/Cliff1UpInteraction") as WorldLandmarkArea2D, cliff)
	_press_portal_action(cliff)
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "climb up hands off to the forest")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, "climb up reaches the cliffside")
	_assert_eq(outdoor.player_body.global_position, outdoor.resolve_spawn_marker(OldPineWorldDefinitions.CLIFFSIDE_LANDING_SPAWN_POINT_ID).global_position, "cliffside exact landing")
	var climb_up: OldPineMapHandoffResult = session.last_map_handoff_result()
	await _settle(tree)
	var vitality_before_pine: int = player.state.vitality.current
	var relationships_before_pine: Array[StringName] = player.relationship.opponent_ids()
	# cliffside.c north is an ordinary exit: the player walks into pine1.
	var pine_arrival: Vector2 = Vector2(435, 1060)
	_assert_true(await _walk(outdoor.player_body, pine_arrival, tree), "player physically walks north from the cliffside into the pine forest")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "walking north reaches Pine Entrance")
	_assert_true(outdoor.player_body.global_position.distance_to(pine_arrival) <= 0.5, "the body stays where the walk ended: no landing marker")
	_assert_true(outdoor.last_passage_traversal() == null, "no passage traversal moves the player into pine1")
	_assert_true(session.last_map_handoff_result() == climb_up, "no map handoff after the climb up")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "pine1 is on the same forest map")
	_assert_eq(player.life_status, CharacterRuntimeLifeStatus.Value.ACTIVE, "Pine arrival leaves player ACTIVE")
	_assert_eq(player.state.vitality.current, vitality_before_pine, "Pine arrival changes no vitality")
	_assert_eq(player.relationship.opponent_ids(), relationships_before_pine, "Pine arrival creates no combat relationship")
	for npc_index: int in [3, 4]:
		var npc_body: WorldCharacterBody2D = (
			OldPineTestMap.body(outdoor, "TallBandit") if npc_index == 3 else OldPineTestMap.body(outdoor, "FatBandit")
		)
		_assert_true(outdoor.player_body.global_position.distance_to(npc_body.global_position) > 150.0, "Pine arrival avoids authored bandit body/presence")
		_assert_false((npc_body.get_node("AggressionPresence") as Area2D).overlaps_body(outdoor.player_body), "Pine arrival is outside authored aggression Presence")
	# The clearing's native link into the pines is on its south side (DECISIONS 3B5).
	_assert_true(outdoor.player_body.global_position.distance_to(Vector2(450, 616)) > 200.0, "Pine arrival avoids the clearing's direct Pine threshold")
	for _frame: int in range(3):
		await tree.physics_frame
		_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Pine side of the threshold remains stable")
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
	_assert_eq(_corpse_count(session), corpse_count_before, "route neither creates nor removes corpse state")
	var npcs_after: Array[NpcRuntimeState] = session.world_npcs()
	for index: int in range(npc_authorities.size()):
		_assert_true(npcs_after[index] == npc_authorities[index], "route preserves NPC authority identity %d" % index)
		_assert_eq(npcs_after[index].character_state.vitality.current, npc_vitality_before[index], "route preserves NPC vitality %d" % index)
		_assert_eq(_npc_item_ids(npcs_after[index]), npc_item_ids_before[index], "route preserves exact NPC item identities %d" % index)
	_assert_true(await _walk(outdoor.player_body, Vector2(435, 1000), tree), "player physically enters existing Tall aggression Presence")
	await _settle(tree)
	var pending_initiations: Array[CombatSliceInitiationResult] = outdoor.process_pending_aggression()
	_assert_true(player.relationship.is_fighting() or not pending_initiations.is_empty() or not outdoor.last_aggression_initiations().is_empty(), "only physical entry into existing Presence starts authored aggression")
	HistoricalCombat.set_running(outdoor, false)
	_assert_true(await _walk(outdoor.player_body, Vector2(360, 1000), tree), "player steps west around the Tall bandit body")
	_assert_true(await _walk(outdoor.player_body, Vector2(360, 864), tree), "player follows the pine floor north")
	_assert_true(await _walk(outdoor.player_body, Vector2(-150, 864), tree), "complete route reaches Pine Deep without teleport")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "complete Waterfall-to-Pine route ends in Pine Deep")
	var old_maps: Array[WeakRef] = [weakref(outdoor), weakref(gorge), weakref(cliff)]
	var old_rngs: Array[Variant] = [session.npc_random_source(), session.combat_random_source(), session.world_interaction_random_source()]
	await _free_session(session, tree)
	var fresh_session: OldPineWorldSessionController = await _session(tree, 93_334)
	var fresh: WorldMapController = fresh_session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	for old_map: WeakRef in old_maps:
		_assert_true(old_map.get_ref() == null, "whole Session reset frees every traversed map node")
	_assert_eq(fresh_session.world_npcs().size(), 34, "reset creates 34 fresh authored NPCs")
	_assert_eq(_corpse_count(fresh_session), 0, "reset has no prior corpse")
	for map: WorldMapController in fresh_session.world_maps():
		_assert_true(map.selected_interaction_target() == null, "reset has no stale River/Cliff target on %s" % map.map_id())
	_assert_eq(fresh_session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "reset starts on the forest map")
	_assert_eq(fresh_session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "reset returns to Central Clearing")
	_assert_true(fresh_session.npc_random_source() != old_rngs[0] and fresh_session.combat_random_source() != old_rngs[1] and fresh_session.world_interaction_random_source() != old_rngs[2], "reset owns three fresh RNG authorities")
	var fresh_gorge: WorldMapController = fresh_session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_true(fresh != null and TerrainProbe.blocks_at(fresh_gorge, Vector2(1200, 1300)) and TerrainProbe.terrain_at(fresh_gorge, Vector2(1200, 1300)) == "water", "reset reloads authored River collision unchanged")
	await _free_session(fresh_session, tree)


func _test_cliff_return_stale_and_inactive_boundaries(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 93_332)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	var cliff: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CLIFF_MAP_ID)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var combat_random: CountingCombatRandomSource = CountingCombatRandomSource.new()
	_assert_true(session.configure_combat_random_source(combat_random), "combat-location fixture observes traversal RNG isolation")
	# The stone bridge stands high above the gorge (epath2.c); only the vine or
	# the cave lead down. Start from the vine's Waterfall landing on the gorge map.
	_assert_true(session.handoff_to(
		OldPineWorldDefinitions.GORGE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID,
	).succeeded(), "return fixture starts at the vine's Waterfall landing")
	await _settle(tree)
	_assert_true(await _walk(gorge.player_body, Vector2(1200, 1000), tree), "return fixture reaches Waterfall south opening")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1080), tree), "return fixture reaches the intended east bank")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1940), tree), "return fixture physically walks into River Gorge")
	await _settle(tree)
	# The water tiles end at x 1376: a 34 px body stands on the bank from x 1393.
	_assert_true(await _walk(gorge.player_body, Vector2(1400, 1940), tree), "return fixture reaches cliff interaction")
	await _settle(tree)
	player.busy.start_busy(7)
	var opponent: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var opponent_original_location: WorldLocationState = opponent.world_location()
	_assert_true(player.relationship.mark_lethal_target(opponent.character_id), "fixture establishes fighting state without cadence")
	_assert_true(opponent.relationship.mark_lethal_target(player.character_id), "fixture establishes reciprocal fighting state")
	_select_area(gorge.get_node("Interactions/RiverbankCliffInteraction") as WorldLandmarkArea2D, gorge)
	_press_portal_action(gorge)
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CLIFF_MAP_ID, "busy/fighting climb hands off to the cliff map")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID, "busy/fighting climb reaches Cliff1")
	_assert_eq(player.busy.busy_value, 7, "climb neither rejects nor advances busy")
	# A map handoff reconciles relationships at once (B1): the separated
	# ordinary opponent is cleared, the lethal marker kept.
	_assert_false(player.relationship.has_opponent(opponent.character_id), "River-to-Cliff handoff reconciliation clears the separated ordinary opponent")
	_assert_true(player.relationship.has_lethal_target(opponent.character_id), "handoff reconciliation retains lethal marker")
	await _settle(tree)
	for _advance: int in range(8):
		player.busy.advance()
	HistoricalCombat.tick(cliff)
	_assert_false(player.relationship.has_opponent(opponent.character_id), "next availability opportunity keeps the separated ordinary opponent cleared")
	_assert_true(player.relationship.has_lethal_target(opponent.character_id), "separation cleanup retains lethal marker")
	_assert_eq(combat_random.calls, 0, "separated cleanup draws zero Combat RNG")
	_assert_true(await _walk(cliff.player_body, Vector2(200, 1940), tree), "player reaches Cliff1 Down landmark")
	await _settle(tree)
	_select_area(cliff.get_node("Interactions/Cliff1DownInteraction") as WorldLandmarkArea2D, cliff)
	_assert_true(await _walk(cliff.player_body, Vector2(435, 1900), tree), "player leaves stale Cliff1 Down while staying in the cliff niche")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID, "the stale fixture stays in the cliff niche zone")
	var before: Vector2 = cliff.player_body.global_position
	_assert_false(_completed(cliff.traverse_selected_portal()), "the niche rejects stale Cliff1 Down despite shared zone")
	_assert_eq(cliff.player_body.global_position, before, "stale Cliff1 Down performs no movement")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CLIFF_MAP_ID, "stale Cliff1 Down starts no handoff")
	_assert_true(await _walk(cliff.player_body, Vector2(200, 1940), tree), "player physically reaches climb-down landmark")
	await _settle(tree)
	_select_area(cliff.get_node("Interactions/Cliff1DownInteraction") as WorldLandmarkArea2D, cliff)
	_press_portal_action(cliff)
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "climb down hands off to the gorge map")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "climb down restores River Gorge")
	_assert_eq(gorge.player_body.global_position, gorge.resolve_spawn_marker(OldPineWorldDefinitions.RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID).global_position, "climb down exact riverbank1 landing")
	await _settle(tree)
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1140), tree), "reverse route physically reaches Riverbank2")
	await _settle(tree)
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "Riverbank1 and Riverbank2 share River Gorge combat location")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1080), tree), "reverse route physically re-enters Waterfall")
	await _settle(tree)
	for _frame: int in range(3):
		await tree.physics_frame
		_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "reverse Waterfall boundary remains stable")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1940), tree), "stale fixture returns along the east bank")
	await _settle(tree)
	_assert_true(await _walk(gorge.player_body, Vector2(1400, 1940), tree), "stale fixture re-enters cliff interaction")
	await _settle(tree)
	_select_area(gorge.get_node("Interactions/RiverbankCliffInteraction") as WorldLandmarkArea2D, gorge)
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1600), tree), "player physically leaves selected landmark while staying in River Gorge")
	await _settle(tree)
	before = gorge.player_body.global_position
	_assert_false(_completed(gorge.traverse_selected_portal()), "stale landmark execution rechecks physical source")
	_assert_eq(gorge.player_body.global_position, before, "stale execution performs no movement")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "stale execution starts no handoff")
	_assert_false(gorge.session.shared_ui().portal_action_is_enabled(), "stale execution refreshes visible action availability")
	_assert_true(await _walk(gorge.player_body, Vector2(1400, 1940), tree), "inactive fixture returns to exact cliff interaction")
	await _settle(tree)
	_select_area(gorge.get_node("Interactions/RiverbankCliffInteraction") as WorldLandmarkArea2D, gorge)
	_press_portal_action(gorge)
	await _settle(tree)
	_assert_true(await _walk(cliff.player_body, Vector2(680, 1650), tree), "Cliff1 Up stale fixture reaches authored landmark")
	await _settle(tree)
	_select_area(cliff.get_node("Interactions/Cliff1UpInteraction") as WorldLandmarkArea2D, cliff)
	_assert_true(await _walk(cliff.player_body, Vector2(435, 1900), tree), "player leaves stale Cliff1 Up while staying in the cliff niche")
	await _settle(tree)
	before = cliff.player_body.global_position
	_assert_false(_completed(cliff.traverse_selected_portal()), "the niche rejects stale Cliff1 Up despite shared zone")
	_assert_eq(cliff.player_body.global_position, before, "stale Cliff1 Up performs no movement")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CLIFF_MAP_ID, "stale Cliff1 Up starts no handoff")
	_assert_true(opponent.set_world_location(player.world_location()), "fixture co-locates opponent at Cliff1 combat location")
	_assert_true(player.relationship.mark_lethal_target(opponent.character_id), "fixture re-establishes same-Cliff relationship")
	# The bandit's own side was never reconciled while the forest map was inactive.
	opponent.relationship.mark_lethal_target(player.character_id)
	_assert_true(opponent.relationship.has_opponent(player.character_id) and opponent.relationship.has_lethal_target(player.character_id), "fixture re-establishes reciprocal same-Cliff relationship")
	_assert_true(await _walk(cliff.player_body, Vector2(680, 1650), tree), "continuity fixture returns to Cliff1 Up")
	await _settle(tree)
	_select_area(cliff.get_node("Interactions/Cliff1UpInteraction") as WorldLandmarkArea2D, cliff)
	_press_portal_action(cliff)
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "Cliff1 Up hands off to the forest")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, "Cliff1 Up reaches the cliffside")
	# cliff1 and cliffside are separate ES2 rooms: no longer one shared combat location.
	_assert_false(player.world_location().shares_combat_location(opponent.world_location()), "Cliff1 Up leaves the cliff1 combat location")
	_assert_false(player.relationship.has_opponent(opponent.character_id), "Cliff1-to-Cliffside handoff reconciliation clears the left-behind ordinary opponent")
	_assert_true(player.relationship.has_lethal_target(opponent.character_id), "Cliff1-to-Cliffside handoff retains the lethal marker")
	_assert_true(opponent.set_world_location(opponent_original_location), "fixture restores authored opponent location")
	# The cliffside has no way back down; the fixture returns to riverbank1.
	_assert_true(session.handoff_to(
		OldPineWorldDefinitions.GORGE_MAP_ID,
		OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID,
		OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID,
		OldPineWorldDefinitions.RIVERBANK1_CLIFF_LANDING_SPAWN_POINT_ID,
	).succeeded(), "inactive fixture returns to riverbank1")
	await _settle(tree)
	_assert_true(await _walk(gorge.player_body, Vector2(1400, 1940), tree), "inactive fixture returns to Riverbank Cliff")
	await _settle(tree)
	_select_area(gorge.get_node("Interactions/RiverbankCliffInteraction") as WorldLandmarkArea2D, gorge)
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	before = gorge.player_body.global_position
	_assert_false(_completed(gorge.traverse_selected_portal()), "non-ACTIVE character cannot climb")
	_assert_eq(gorge.player_body.global_position, before, "inactive rejection performs no physical mutation")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "inactive rejection starts no handoff")
	await _free_session(session, tree)


func _test_direct_pine_shortcut_and_route_collisions(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 93_333)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	var cliff: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CLIFF_MAP_ID)
	_assert_true(outdoor.find_children("ResetButton", "Button", true, false).is_empty(), "audited Outdoor hierarchy preserves Phase 10C1A Reset removal")
	# Old Pine terrain collides through its tiles (DECISIONS 3B5); the gorge has
	# no staging block left, and its east bank opens from the pool to the river.
	_assert_true(gorge.find_children("*", "StaticBody2D", true, false).is_empty(), "the gorge keeps no staging block body")
	_assert_eq(TerrainProbe.terrain_at(gorge, Vector2(1450, 1100)), "riverbank", "the Waterfall south bank is painted bank")
	_assert_false(TerrainProbe.blocks_at(gorge, Vector2(1450, 1100)), "only the Waterfall south bank seam is open")
	# The stream is water tiles: what is drawn is what collides.
	for point: Vector2 in [Vector2(1028, 1150), Vector2(1200, 1150), Vector2(1372, 1150), Vector2(1028, 2190), Vector2(1200, 2190), Vector2(1372, 2190)]:
		_assert_eq(TerrainProbe.terrain_at(gorge, point), "water", "visible RiverStream covers %s" % point)
		_assert_true(TerrainProbe.blocks_at(gorge, point), "visible RiverStream collides at %s" % point)
	for point: Vector2 in [Vector2(1020, 1500), Vector2(1380, 1500)]:
		_assert_false(TerrainProbe.blocks_at(gorge, point), "water collision ends at the visible stream edge, bank open at %s" % point)
	_assert_true(gorge.physical_zone(OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID) != null, "River Gorge zone persists")
	_assert_true(cliff.physical_zone(OldPineWorldDefinitions.CLIFF_HOLE_ZONE_ID) != null, "the cliff niche zone persists on its own map")
	_assert_true(outdoor.physical_zone(OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID) != null, "the cliffside zone persists on the forest")
	# cliffside north is walked: the one-way passage Area is gone.
	_assert_true(outdoor.get_node_or_null("Interactions/CliffsidePineExit") == null, "no one-way passage Area remains at the cliffside")
	for node: Node in outdoor.find_children("*", "Area2D", true, false):
		var passage: WorldPassageArea2D = node as WorldPassageArea2D
		if passage != null:
			_assert_ne(GameContent.catalog().portal(passage.portal_id).source_zone_id, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, "no forest passage leaves the cliffside")
	_assert_true((gorge.get_node("Characters/Player/Camera2D") as Camera2D).limit_bottom >= 3000, "camera covers full River/Lake route")
	var cliff_camera: Camera2D = cliff.get_node("Characters/Player/Camera2D") as Camera2D
	_assert_true(cliff_camera.limit_top <= 1424 and cliff_camera.limit_bottom >= 2184, "camera covers the cliff niche")
	_assert_true((outdoor.get_node("Characters/Player/Camera2D") as Camera2D).limit_bottom >= 1392, "camera covers the cliffside")
	# The clearing's native link into the pines (B2) is on its south side now.
	_assert_true(await _walk(outdoor.player_body, Vector2(450, 700), tree), "direct Outdoor to Pine shortcut remains physical")
	await _settle(tree)
	_assert_eq(outdoor.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "direct shortcut still reaches Pine Entrance")
	_assert_true(await _walk(outdoor.player_body, Vector2(450, 500), tree), "Pine shortcut remains bidirectional")
	await _settle(tree)
	_assert_eq(outdoor.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "direct shortcut returns to Outdoor")
	_assert_true(await _walk(outdoor.player_body, Vector2(450, 300), tree), "player returns to the clearing centre")
	_assert_true(await _walk(outdoor.player_body, Vector2(1200, 300), tree), "player avoids authored Slope bodies through East Bridge")
	# The stone bridge stands high above the gorge (epath2.c); only the vine or
	# the cave lead down. Start from the vine's Waterfall landing on the gorge map.
	_assert_true(session.handoff_to(
		OldPineWorldDefinitions.GORGE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID,
	).succeeded(), "collision fixture reaches the vine's Waterfall landing")
	await _settle(tree)
	_assert_true(await _walk(gorge.player_body, Vector2(1200, 1000), tree), "player returns through the Waterfall south opening")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 1080), tree), "player can step onto the intended River bank without invisible collision")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 2140), tree), "Lake southern boundary is physically reachable along the bank")
	await _settle(tree)
	var lake_collision: KinematicCollision2D = gorge.player_body.move_and_collide(Vector2(0, 160))
	_assert_true(lake_collision == null, "Lake north connection is physically open")
	_assert_eq(gorge.player_runtime().world_location().zone_id, OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID, "direct displacement awaits zone observation")
	_assert_true(await _walk(gorge.player_body, Vector2(1420, 2000), tree), "player can return north from Lake")
	_assert_eq(TerrainProbe.terrain_at(outdoor, Vector2(-1480, 850)), "cliff", "Pine cliffdown edge is painted cliff")
	_assert_true(TerrainProbe.blocks_at(outdoor, Vector2(-1480, 850)), "Pine cliffdown boundary remains closed")
	await _free_session(session, tree)


func _select_area(area: WorldLandmarkArea2D, map: WorldMapController) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	area._input_event(map.get_viewport(), click, 0)


func _press_portal_action(map: WorldMapController) -> void:
	_assert_true(map.session.shared_ui().portal_action_is_enabled(), "selected authored action is enabled at its physical source")
	map.session.shared_ui().portal_button.pressed.emit()


## A landmark action moves the player on its map or, across maps, by handoff.
func _completed(result: RefCounted) -> bool:
	if result is WorldPortalTraversalResult:
		return (result as WorldPortalTraversalResult).completed()
	if result is OldPineMapHandoffResult:
		return (result as OldPineMapHandoffResult).succeeded()
	return false


func _corpse_count(session: OldPineWorldSessionController) -> int:
	var count: int = 0
	for map: WorldMapController in session.world_maps():
		count += map.corpse_states().size()
	return count


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
	preload("res://tests/support/historical_world_combat_fixture.gd").install(session)
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


func _assert_ne(actual: Variant, unexpected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("%s: did not expect %s" % [message, unexpected])
