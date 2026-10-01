extends RefCounted

const HistoricalCombat := preload("res://tests/support/historical_world_combat_fixture.gd")

const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const ObservingWorldInteractionRandomSource := preload(
	"res://tests/support/observing_world_interaction_random_source.gd"
)


class MaximumCombatRandomSource extends CombatRandomSource:
	func next_below(exclusive_upper_bound: int) -> int:
		return maxi(exclusive_upper_bound - 1, 0)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_authored_definitions()
	await _test_default_waterfall_branch(tree)
	await _test_live_dodge_and_armor(tree)
	await _test_passage_roundtrip(tree)
	await _test_reactivated_zone_contacts(tree)
	await _test_invalid_and_partial_boundaries(tree)
	await _test_committed_partial_after_vine_draw(tree)
	await _test_south_exit_failure_recovery(tree)
	await _test_physical_interaction_and_exit_deduplication(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_authored_definitions() -> void:
	var vine: WorldLandmarkDefinition = (
		GameContent.catalog().landmark(&"oldpine.outdoor.landmark.epath2_vine")
	)
	_assert_true(GameContent.load_errors().is_empty(), "Old Pine world definitions remain coherent")
	_assert_true(GameContent.load_errors().is_empty(), "landmark and Vine authored definitions validate")
	_assert_true(vine.is_valid(), "epath2 Vine definition is immutable valid content")
	_assert_eq(vine.landmark_id, &"oldpine.outdoor.landmark.epath2_vine", "Vine stable landmark identity")
	_assert_eq(vine.legacy_source_path, "d/oldpine/epath2.c", "exact Vine source path retained")
	_assert_true(vine.description.contains("高约百丈的山涧深谷"), "exact authored Inspect warning retained")
	var waterfall: ZoneDefinition = GameContent.catalog().zone(
		OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID
	)
	_assert_eq(waterfall.room_ids(), [&"es2:d/oldpine/waterfall"], "Waterfall Basin owns only waterfall.c metadata")
	var river: ZoneDefinition = GameContent.catalog().zone(
		OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID
	)
	_assert_false(river.room_ids().has(&"es2:d/oldpine/waterfall"), "River Gorge no longer duplicates waterfall.c metadata")
	_assert_ne(waterfall.combat_location_id, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, "Waterfall has a distinct East Bridge combat location")
	_assert_ne(waterfall.combat_location_id, river.combat_location_id, "Waterfall and future River Gorge combat locations are distinct")
	var legacy_rooms: Dictionary[StringName, bool] = {}
	var duplicate_legacy_room: bool = false
	for zone: ZoneDefinition in GameContent.catalog().zones():
		for legacy_room_id: StringName in zone.room_ids():
			if legacy_rooms.has(legacy_room_id):
				duplicate_legacy_room = true
			legacy_rooms[legacy_room_id] = true
	_assert_false(duplicate_legacy_room, "every represented LPC room belongs to exactly one native zone")
	for portal_id: StringName in [
		OldPineWorldDefinitions.VINE_WATERFALL_PORTAL_ID,
		OldPineWorldDefinitions.VINE_PASSAGE_PORTAL_ID,
		OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID,
	]:
		var portal: PortalDefinition = GameContent.catalog().portal(portal_id)
		_assert_true(portal != null, "%s resolves" % portal_id)
		_assert_true(portal != null and GameContent.catalog().portals_for_map(portal.source_map_id).has(portal), "%s belongs to its declared source map" % portal_id)
	_assert_eq(
		GameContent.catalog().portal(
			OldPineWorldDefinitions.VINE_PASSAGE_PORTAL_ID
		).destination_spawn_point_id,
		OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID,
		"Vine Passage portal uses the single stable VineLanding identity",
	)


func _test_default_waterfall_branch(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_001)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var vine_definition: WorldLandmarkDefinition = (
		GameContent.catalog().landmark(&"oldpine.outdoor.landmark.epath2_vine")
	)
	var world_random: ObservingWorldInteractionRandomSource = (
		ObservingWorldInteractionRandomSource.new(
			[4],
			outdoor.session.shared_ui(),
			session.player_runtime(),
			vine_definition.message("hold"),
		)
	)
	var combat_random: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([])
	_assert_true(session.configure_world_interaction_random_source(world_random), "test injects session World RNG")
	_assert_true(session.configure_combat_random_source(combat_random), "test injects independent Combat RNG")
	_move_player(outdoor, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, Vector2(1200, 300))
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var target: NpcRuntimeState = outdoor.npc_runtimes()[0]
	player.relationship.mark_lethal_target(target.character_id)
	player.busy.start_busy(7, 2)
	var resources_before: Array[int] = _resource_snapshot(player.state)
	var npc_rng_identity: NpcInitializationRandomSource = session.npc_random_source()
	_assert_eq(_effective_dodge(player), 5, "fresh player current effective dodge is exactly five")
	_assert_true(outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine"), "Vine is selectable as LANDMARK")
	_assert_true(outdoor.inspect_selected(), "Vine Inspect succeeds")
	_assert_true(outdoor.session.shared_ui().inspection_display().contains("高约百丈的山涧深谷"), "HUD renders authored Vine Inspect")
	_assert_true(outdoor.session.shared_ui().portal_action_is_enabled(), "Vine action enabled only at East Bridge source")
	_assert_false(outdoor.session.shared_ui().attack_is_enabled(), "Vine selection is not a fake attack target")
	var hold_log_start: int = outdoor.session.shared_ui().log_lines().size()
	var result: VineTraversalResult = outdoor.traverse_selected_portal()
	_assert_eq(result.outcome, VineTraversalResult.Outcome.COMPLETED_WATERFALL, "bound five draw four selects Waterfall")
	_assert_eq(result.effective_dodge, 5, "outer result retains current effective dodge")
	_assert_eq(result.policy_result.random_bound, 5, "fresh player uses exact bound five")
	_assert_eq(result.policy_result.draw_value, 4, "upper valid bound-five draw retained")
	_assert_true(result.source_presentation_reached, "source presentation precedes random")
	_assert_true(result.branch_presentation_reached, "Waterfall presentation precedes movement")
	# The pool lies on the gorge map below the bridge (DECISIONS 3B5): the fall is a handoff.
	_assert_true(result.map_handoff_result != null and result.map_handoff_result.succeeded(), "Waterfall fall uses the map handoff")
	_assert_true(result.same_map_result == null, "Waterfall fall is no same-map teleport")
	_assert_true(result.movement_location_committed, "Waterfall handoff commits the location")
	_assert_eq(world_random.call_count(), 1, "valid Vine consumes exactly one World RNG draw")
	_assert_true(world_random.source_text_was_visible_at_draw, "source presentation is already visible at the exact RNG call")
	_assert_true(world_random.player_was_at_east_bridge_at_draw, "movement has not occurred at the exact RNG call")
	var hold_lines: Array[String] = outdoor.session.shared_ui().log_lines()
	_assert_eq(hold_lines[hold_log_start], vine_definition.message("hold"), "actual HUD log records source presentation first")
	_assert_eq(hold_lines[hold_log_start + 1], vine_definition.message("fall"), "actual HUD log records selected branch presentation second")
	_assert_eq(combat_random.call_count(), 0, "Vine consumes zero Combat RNG")
	_assert_true(session.npc_random_source() == npc_rng_identity, "Vine neither replaces nor consumes another NPC RNG stream")
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "Waterfall activates the resident Gorge map")
	_assert_true(session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID) == outdoor, "Waterfall keeps the exact resident Outdoor Node")
	_assert_true(outdoor.get_parent() == null and gorge.get_parent() == session.active_map_slot, "Outdoor detaches and the Gorge attaches")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "Waterfall logical zone exact")
	_assert_eq(gorge.player_body.global_position, gorge.resolve_spawn_marker(OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).global_position, "Waterfall physical landing exact")
	_assert_eq(_resource_snapshot(player.state), resources_before, "source fall causes no resource, wound, force, mana, atman, food, or water mutation")
	_assert_eq(player.busy.busy_value, 7, "Vine neither rejects nor advances busy")
	# The handoff reconciles relationships at once (B1), as the Passage branch does.
	_assert_false(player.relationship.has_opponent(target.character_id), "Waterfall handoff reconciliation clears the separated ordinary opponent")
	_assert_true(player.relationship.has_lethal_target(target.character_id), "Waterfall handoff preserves lethal marker")
	_assert_true(outdoor.selected_interaction_target() == null, "successful movement clears stale Vine target")
	_assert_false(outdoor.session.shared_ui().portal_action_is_enabled(), "stale Vine action cannot retrigger from Waterfall")
	var marker: WorldSpawnMarker2D = gorge.resolve_spawn_marker(OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID)
	var zone_area: Area2D = gorge.get_node("Zones/WaterfallZone") as Area2D
	var zone_shape: RectangleShape2D = (zone_area.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_assert_true(absf(marker.global_position.x - zone_area.global_position.x) < zone_shape.size.x / 2.0, "Waterfall landing lies inside zone horizontally")
	_assert_true(absf(marker.global_position.y - zone_area.global_position.y) < zone_shape.size.y / 2.0, "Waterfall landing lies inside zone vertically")
	# The reattached map's tile collision is rebuilt on the next frame.
	await tree.physics_frame
	_assert_false(gorge.player_body.test_move(Transform2D(0.0, Vector2(1420, 1080)), Vector2(0, 60)), "Phase 9B3B3 keeps the intentional east-bank River route physically open")
	_assert_true(gorge.player_body.test_move(Transform2D(0.0, Vector2(1420, 1350)), Vector2(-400, 0)), "Phase 9B3B3 water prevents a River shortcut")
	# The south staging block was a StaticBody2D; collision is terrain tiles now.
	for point: Vector2 in [Vector2(1420, 1080), Vector2(1420, 1110)]:
		_assert_false(TerrainProbe.blocks_at(gorge, point), "no staging block closes the Waterfall south bank at %s" % point)
	for index: int in range(8):
		player.busy.advance()
	HistoricalCombat.tick(gorge)
	_assert_false(player.relationship.has_opponent(target.character_id), "next availability opportunity keeps the separated ordinary opponent cleared")
	_assert_true(player.relationship.has_lethal_target(target.character_id), "availability cleanup preserves lethal marker")
	_assert_eq(combat_random.call_count(), 0, "cleanup-to-empty performs no Combat selection draw")
	await _free_session(session, tree)


func _test_live_dodge_and_armor(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_101)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var world_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([4, 2, 4, 5])
	var combat_random: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([])
	session.configure_world_interaction_random_source(world_random)
	session.configure_combat_random_source(combat_random)
	var leather_id: StringName = &"phase9b3b2.player-leather"
	_assert_true(_add_owned_leather(outdoor, leather_id), "live test adds one canonical owned leather instance")
	_assert_eq(_attempt_from_east(outdoor).effective_dodge, 5, "unworn leather does not affect first current bound")
	_assert_true(OldPineTestMap.wear(outdoor, leather_id).succeeded, "player wears live leather")
	_assert_eq(_attempt_from_east(outdoor).effective_dodge, 3, "worn leather immediately applies dodge minus two")
	_assert_true(OldPineTestMap.remove(outdoor, leather_id).succeeded, "player removes live leather")
	_assert_eq(_attempt_from_east(outdoor).effective_dodge, 5, "removed leather restores next current bound")
	player.state.skills.set_raw_level(&"dodge", 12)
	var success: VineTraversalResult = _attempt_from_east(outdoor)
	_assert_eq(success.effective_dodge, 6, "skill change is read at execution, not selection time")
	_assert_eq(success.outcome, VineTraversalResult.Outcome.COMPLETED_PASSAGE, "bound six draw five selects Passage")
	_assert_eq(player.state.skills.raw_level(&"dodge"), 12, "Vine evaluation mutates no raw skill")
	_assert_eq(world_random.requested_bounds(), [5, 3, 5, 6], "live armor and skill facts define each exact bound")
	_assert_eq(combat_random.call_count(), 0, "Wear/Remove/Vine consume no Combat RNG")
	await _free_session(session, tree)


func _test_passage_roundtrip(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_201)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var cave: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.skills.set_raw_level(&"dodge", 12)
	var victim: NpcRuntimeState = outdoor.npc_runtimes()[1]
	var corpse: CorpseState = await _kill_bandit(outdoor, victim, tree)
	_assert_true(corpse != null, "Vine roundtrip fixture creates one resident Outdoor corpse")
	if corpse == null:
		await _free_session(session, tree)
		return
	var corpse_id: StringName = corpse.corpse_item_instance_id
	var corpse_view: CombatSliceCorpseView = outdoor.corpse_view_for(corpse_id)
	var corpse_view_id: int = corpse_view.get_instance_id()
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.ITEM,
		corpse_id,
	)
	var corpse_items: Array[ItemInstance] = victim.loadout_items()
	var remaining_loot: ItemInstance = _item_by_definition(
		corpse_items,
		TestContent.SHORT_SWORD_ITEM_ID,
	)
	var looted_silver: ItemInstance = _item_by_definition(
		corpse_items,
		TestContent.SILVER_ITEM_ID,
	)
	_assert_true(remaining_loot != null and looted_silver != null, "corpse exposes exact sword and silver authorities")
	if remaining_loot == null or looted_silver == null:
		await _free_session(session, tree)
		return
	var remaining_loot_id: StringName = remaining_loot.item_instance_id
	var silver_id: StringName = looted_silver.item_instance_id
	outdoor.player_body.global_position = corpse_view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(outdoor.select_corpse(corpse_id), "roundtrip selects the physical resident corpse")
	_assert_true(outdoor.open_selected_loot(), "roundtrip opens corpse loot in physical range")
	_assert_true(outdoor.take_selected_loot_item(silver_id).succeeded, "roundtrip loots the exact amount-three silver instance")
	var player_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		player.character_id,
	)
	_assert_true(session.inventory_state().is_direct_child(silver_id, player_endpoint), "looted silver becomes direct player inventory")
	_assert_eq(session.stack_collection().stack_state(silver_id).amount, 3, "looted silver preserves authored amount three")
	_assert_true(session.inventory_state().is_direct_child(remaining_loot_id, corpse_endpoint), "one authored sword remains in the corpse")
	var leather_id: StringName = StringName(
		"%s.vine-roundtrip-leather" % String(session.item_instance_scope())
	)
	_assert_true(_add_owned_leather(outdoor, leather_id), "roundtrip adds one canonical player-owned leather instance")
	_assert_true(OldPineTestMap.wear(outdoor, leather_id).succeeded, "roundtrip wears leather through the production adapter")
	_assert_true(player.armor.is_worn(leather_id), "roundtrip fixture records the exact WORN armor ref")
	player.state.skills.set_raw_level(&"dodge", 16)
	var opponent: NpcRuntimeState = outdoor.npc_runtimes()[0]
	opponent.character_state.vitality.current -= 7
	var altered_vitality: int = opponent.character_state.vitality.current
	player.busy.start_busy(9, 3)
	player.relationship.mark_lethal_target(opponent.character_id)
	var world_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([5, 4])
	var combat_random: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([])
	session.configure_world_interaction_random_source(world_random)
	session.configure_combat_random_source(combat_random)
	var state_identity: CharacterState = player.state
	var equipment_identity: EquipmentState = player.state.equipment
	var armor_identity: ArmorState = player.armor
	var relationship_identity: CombatRelationshipState = player.relationship
	var busy_identity: ActionBusyState = player.busy
	var inventory_identity: InventoryState = session.inventory_state()
	var stack_identity: CombinedStackCollection = session.stack_collection()
	var index_identity: WorldItemInstanceIndex = session.item_instance_index()
	var npc_rng_identity: NpcInitializationRandomSource = session.npc_random_source()
	var combat_rng_identity: CombatRandomSource = session.combat_random_source()
	var world_rng_identity: WorldInteractionRandomSource = session.world_interaction_random_source()
	var outdoor_identity: WorldMapController = outdoor
	var cave_identity: WorldMapController = cave
	var gorge: WorldMapController = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID)
	var primary_id: StringName = player.state.equipment.primary_weapon().instance_id
	var secondary_before: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	var result: VineTraversalResult = _attempt_from_east(outdoor)
	_assert_eq(result.outcome, VineTraversalResult.Outcome.COMPLETED_PASSAGE, "high dodge real player reaches Passage")
	_assert_true(result.map_handoff_result != null and result.map_handoff_result.succeeded(), "Vine success uses exact B1 handoff")
	if result.map_handoff_result == null:
		await _free_session(session, tree)
		return
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "Cave becomes active")
	_assert_true(outdoor.get_parent() == null and cave.get_parent() == session.active_map_slot, "Outdoor detaches and same Cave attaches")
	_assert_false(outdoor.player_body.player_controlled, "Outdoor body is inert")
	_assert_true(cave.player_body.player_controlled, "only Cave body is controllable")
	_assert_false((outdoor.player_body.get_node("Camera2D") as Camera2D).enabled, "Outdoor camera disabled")
	_assert_true((cave.player_body.get_node("Camera2D") as Camera2D).enabled, "Cave camera enabled")
	_assert_eq(cave.player_body.global_position, cave.resolve_spawn_marker(OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID).global_position, "Cave arrival uses exact VineLanding")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, "Cave logical Passage exact")
	_assert_true(outdoor.selected_interaction_target() == null, "committed Passage clears detached Outdoor Vine selection")
	var stale_attempt: RefCounted = outdoor.traverse_selected_portal()
	_assert_false(stale_attempt is VineTraversalResult and (stale_attempt as VineTraversalResult).succeeded(), "detached Outdoor cannot execute a stale Vine action")
	_assert_eq(world_random.call_count(), 1, "stale detached action consumes no second World RNG draw")
	_assert_false(player.relationship.has_opponent(opponent.character_id), "B1 reconciliation removes cross-map ordinary opponent")
	_assert_true(player.relationship.has_lethal_target(opponent.character_id), "cross-map cleanup preserves lethal marker")
	_assert_eq(player.busy.busy_value, 9, "cross-map handoff leaves busy unchanged")
	_assert_eq(combat_random.call_count(), 0, "cross-map cleanup-to-empty attacks and draws nothing")
	await tree.physics_frame
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "VineLanding does not immediately trigger south return")
	_assert_false(cave.get_node("SouthExit").overlaps_body(cave.player_body), "actual VineLanding geometry does not overlap SouthExit")
	await _physically_enter_south_exit(cave, tree)
	# passage.c south leads to the waterfall pool, on the gorge map below the bridge.
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "physical Cave south Area returns to the Gorge waterfall")
	_assert_true(session.last_map_handoff_result().succeeded(), "south exit emits one successful typed handoff")
	_assert_true(session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID) == outdoor_identity and session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID) == cave_identity and session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID) == gorge, "roundtrip reuses every resident map Node")
	_assert_eq(outdoor.corpse_states()[0], corpse, "same CorpseState survives the Vine roundtrip")
	_assert_eq(outdoor.corpse_view_for(corpse_id).get_instance_id(), corpse_view_id, "same corpse view Node survives the Vine roundtrip")
	_assert_true(session.inventory_state().is_direct_child(remaining_loot_id, corpse_endpoint), "remaining corpse loot preserves exact containment")
	_assert_true(session.inventory_state().is_direct_child(silver_id, player_endpoint), "looted silver preserves exact player parent")
	_assert_eq(session.stack_collection().stack_state(silver_id).amount, 3, "looted silver preserves exact amount across roundtrip")
	_assert_true(session.inventory_state().is_direct_child(leather_id, player_endpoint), "worn leather remains direct player inventory")
	_assert_true(player.armor.is_worn(leather_id), "same leather ItemInstanceId remains WORN")
	_assert_eq(opponent.character_state.vitality.current, altered_vitality, "altered living NPC resource survives the Vine roundtrip")
	_assert_false(victim.exists_in_map, "dead authored NPC remains absent after Vine roundtrip")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, "Passage south returns to Waterfall Basin")
	_assert_eq(gorge.player_body.global_position, gorge.resolve_spawn_marker(OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).global_position, "Passage return uses exact Waterfall landing")
	_assert_true(session.player_runtime() == player, "same WorldPlayerRuntimeState survives")
	_assert_true(player.state == state_identity, "same CharacterState survives")
	_assert_true(player.state.equipment == equipment_identity, "same EquipmentState survives")
	_assert_true(player.armor == armor_identity, "same ArmorState survives")
	_assert_true(player.relationship == relationship_identity, "same relationship authority survives")
	_assert_true(player.busy == busy_identity, "same busy authority survives")
	_assert_true(session.inventory_state() == inventory_identity, "same InventoryState survives")
	_assert_true(session.stack_collection() == stack_identity, "same stack authority survives")
	_assert_true(session.item_instance_index() == index_identity, "same item index survives")
	_assert_true(session.npc_random_source() == npc_rng_identity, "same NPC RNG survives")
	_assert_true(session.combat_random_source() == combat_rng_identity, "same Combat RNG survives")
	_assert_true(session.world_interaction_random_source() == world_rng_identity, "same World RNG survives")
	_assert_eq(player.state.equipment.primary_weapon().instance_id, primary_id, "exact primary ItemInstanceId survives")
	_assert_true(player.state.equipment.secondary_weapon() == secondary_before, "exact secondary weapon ref state survives")
	_assert_true(session.inventory_state().is_registered(primary_id), "same primary item remains live")
	_assert_eq(world_random.call_count(), 1, "Passage handoff and south exit consume no extra World RNG")
	_assert_eq(session.active_map_child_count(), 1, "roundtrip retains exact-one active map child")
	_assert_true(gorge.player_body.player_controlled and not cave.player_body.player_controlled and not outdoor.player_body.player_controlled, "only the returned Gorge body controls")
	var continued: VineTraversalResult = _attempt_from_east(outdoor)
	_assert_eq(continued.outcome, VineTraversalResult.Outcome.COMPLETED_WATERFALL, "same World RNG stream continues with its second scripted draw")
	_assert_eq(world_random.requested_bounds(), [6, 6], "roundtrip neither reseeds nor replaces the World RNG stream")
	_assert_true(session.inventory_state().is_direct_child(remaining_loot_id, corpse_endpoint), "continued Vine use still leaves corpse loot untouched")
	var old_scope: StringName = session.item_instance_scope()
	var old_outdoor_id: int = outdoor.get_instance_id()
	var old_cave_id: int = cave.get_instance_id()
	var old_outdoor_ref: WeakRef = weakref(outdoor)
	var old_cave_ref: WeakRef = weakref(cave)
	var old_gorge_ref: WeakRef = weakref(gorge)
	await _free_session(session, tree)
	_assert_true(old_outdoor_ref.get_ref() == null, "whole-session boundary frees the old active Outdoor Node")
	_assert_true(old_cave_ref.get_ref() == null, "whole-session boundary explicitly frees the detached Cave Node")
	_assert_true(old_gorge_ref.get_ref() == null, "whole-session boundary frees the Gorge Node")
	var fresh: OldPineWorldSessionController = await _session(tree, 10_202)
	_assert_true(fresh.world_interaction_random_source() != world_rng_identity, "fresh whole-session boundary owns a fresh World RNG object")
	_assert_ne(fresh.item_instance_scope(), old_scope, "fresh whole-session boundary owns a fresh item-ID scope")
	_assert_ne(fresh.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID).get_instance_id(), old_outdoor_id, "fresh session owns a new Outdoor resident Node")
	_assert_ne(fresh.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID).get_instance_id(), old_cave_id, "fresh session owns a new Cave resident Node")
	_assert_eq(fresh.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID).corpse_states().size(), 0, "fresh session restores no prior corpse")
	_assert_eq(fresh.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID).npc_runtimes().size(), 5, "fresh session creates the authored five Outdoor NPCs")
	_assert_eq(fresh.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID).npc_runtimes().size(), 5, "fresh session creates the authored five Gorge NPCs")
	_assert_true(fresh.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID).selected_interaction_target() == null, "fresh session has no stale Vine selection")
	_assert_false(fresh.passage_request_pending(), "fresh session has no stale SouthExit request")
	_assert_eq(fresh.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "fresh session starts with Outdoor active")
	await _free_session(fresh, tree)


func _test_reactivated_zone_contacts(tree: SceneTree) -> void:
	# Warm actual PhysicsServer contacts before detaching the resident map. Both
	# the old corpse-fixture position and the real Vine source must be harmless
	# after return; Input is released and no lifecycle/Shell fixture is involved.
	# The Cave now returns to the gorge, so the forest is reactivated where the
	# route really comes back up: cliff1 climb up lands on the cliffside.
	for from_slope: bool in [true, false]:
		var session: OldPineWorldSessionController = await _session(tree, 10_251)
		var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
		var source_zone: StringName = (
			OldPineWorldDefinitions.SLOPE_ZONE_ID if from_slope
			else OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID
		)
		var source_area: Area2D = outdoor.get_node(
			"Zones/SlopeZone" if from_slope else "Zones/EastBridgeZone"
		)
		# On the slope path, clear of the three bandits' presence.
		_move_player(outdoor, source_zone, Vector2(450, -50) if from_slope else Vector2(1200, 300))
		for frame: int in 8:
			await tree.physics_frame
			await tree.process_frame
			if source_area.overlaps_body(outdoor.player_body):
				break
		_assert_true(source_area.overlaps_body(outdoor.player_body), "fixture warms real source Area contact")
		_assert_eq(Input.get_vector("move_left", "move_right", "move_up", "move_down"), Vector2.ZERO, "contact regression starts without stale global movement")
		var landing: Vector2 = outdoor.resolve_spawn_marker(
			OldPineWorldDefinitions.CLIFFSIDE_LANDING_SPAWN_POINT_ID
		).global_position
		var stale_locations: Array[StringName] = []
		source_area.body_entered.connect(func(body: Node2D) -> void:
			if body == outdoor.player_body and body.global_position == landing:
				if session.player_runtime().world_location().zone_id != OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID:
					stale_locations.append(session.player_runtime().world_location().zone_id)
		)
		session.player_runtime().state.skills.set_raw_level(&"dodge", 12)
		session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([5]))
		_assert_true(_attempt_from_east(outdoor).succeeded(), "contact fixture uses normal Vine handoff")
		await _physically_enter_south_exit(session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID), tree)
		_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "SouthExit returns to the Gorge waterfall")
		var climb_up: PortalDefinition = GameContent.catalog().portal(OldPineWorldDefinitions.CLIFF1_UP_PORTAL_ID)
		_assert_true(session.handoff_to(
			climb_up.destination_map_id, climb_up.destination_zone_id,
			climb_up.destination_zone_id, climb_up.destination_spawn_point_id,
		).succeeded(), "the cliff1 climb-up handoff reactivates the forest")
		_assert_eq(outdoor.player_body.global_position, landing, "no movement/teleport correction after reactivation")
		# Observe actual subsequent physics, not just a fast idle frame before the
		# delayed contact callback. Preserve every transient violation above too.
		for frame: int in 4:
			await tree.physics_frame
			await tree.process_frame
			_assert_eq(session.player_runtime().world_location().zone_id,
				OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID,
				"settled return remains Cliffside")
		_assert_eq(outdoor.player_body.global_position, landing, "settling with zero input cannot move the body")
		_assert_true(stale_locations.is_empty(), "no stale notification transiently overwrites committed landing")
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_D
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.physics_frame
		await tree.physics_frame
		event = event.duplicate() as InputEventKey
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		_assert_true(outdoor.player_body.global_position.x > landing.x, "fresh hardware input still moves returned player")
		_assert_false(Input.is_action_pressed(&"move_right"), "test releases injected hardware action")
		# Zones own the body's center (half-open), not its footprint edge.
		OldPineTestMap.enter_zone(outdoor, OldPineWorldDefinitions.SLOPE_ZONE_ID, outdoor.player_body)
		_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, "disjoint stale Slope callback is rejected")
		outdoor.player_body.global_position = Vector2(435, 1108)
		OldPineTestMap.enter_zone(outdoor, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, outdoor.player_body)
		_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID, "a body edge over Pine Entrance keeps the Cliffside center owner")
		await _free_session(session, tree)


func _test_invalid_and_partial_boundaries(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_301)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var world_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([4])
	session.configure_world_interaction_random_source(world_random)
	_assert_true(outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine"), "Vine can be selected before leaving source")
	var wrong_source: VineTraversalResult = outdoor.traverse_selected_portal()
	_assert_eq(wrong_source.outcome, VineTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH, "selected Vine revalidates exact source at execution")
	_assert_eq(world_random.call_count(), 0, "wrong source consumes zero World RNG")
	_assert_false(outdoor.session.shared_ui().portal_action_is_enabled(), "wrong source disables visible Vine action")
	_move_player(outdoor, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, Vector2(1200, 300))
	session.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine")
	var inactive: VineTraversalResult = outdoor.traverse_selected_portal()
	_assert_eq(inactive.outcome, VineTraversalResult.Outcome.PLAYER_NOT_ACTIVE, "non-ACTIVE player is rejected before presentation or draw")
	_assert_eq(world_random.call_count(), 0, "non-ACTIVE player consumes zero World RNG")
	session.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine")
	session.player_runtime().state.skills.set_raw_level(&"dodge", 0)
	var log_before: int = outdoor.session.shared_ui().log_lines().size()
	var ambiguous: VineTraversalResult = outdoor.traverse_selected_portal()
	_assert_eq(ambiguous.outcome, VineTraversalResult.Outcome.POLICY_AMBIGUITY, "zero effective dodge returns typed legacy ambiguity")
	_assert_true(ambiguous.source_presentation_reached, "ambiguity retains already-emitted source presentation")
	_assert_false(ambiguous.branch_presentation_reached, "ambiguity emits no invented branch presentation")
	_assert_eq(outdoor.session.shared_ui().log_lines().size(), log_before + 1, "source presentation occurs before ambiguous random position")
	_assert_eq(world_random.call_count(), 0, "ambiguous bound consumes zero RNG")
	_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, "ambiguity performs no movement")
	session.player_runtime().state.skills.set_raw_level(&"dodge", 12)
	var invalid_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([6])
	session.configure_world_interaction_random_source(invalid_random)
	outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine")
	var invalid_draw: VineTraversalResult = outdoor.traverse_selected_portal()
	_assert_eq(invalid_draw.outcome, VineTraversalResult.Outcome.POLICY_INVALID_DRAW, "out-of-range injected draw returns typed failure")
	_assert_true(invalid_draw.source_presentation_reached, "invalid draw retains source presentation")
	_assert_false(invalid_draw.branch_presentation_reached, "invalid draw emits no branch presentation")
	_assert_eq(session.player_runtime().world_location().zone_id, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, "invalid draw performs no movement")
	session.configure_world_interaction_random_source(world_random)
	var marker: WorldSpawnMarker2D = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID).resolve_spawn_marker(OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID)
	marker.spawn_point_id = &"temporarily.missing"
	outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine")
	var missing_marker: VineTraversalResult = outdoor.traverse_selected_portal()
	_assert_eq(missing_marker.outcome, VineTraversalResult.Outcome.MAP_HANDOFF_FAILED, "missing Waterfall marker fails after branch selection")
	_assert_true(missing_marker.map_handoff_result != null and missing_marker.map_handoff_result.outcome == OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING, "missing Waterfall marker is the typed handoff failure")
	_assert_true(missing_marker.policy_result.branch_selected(), "missing marker retains selected branch")
	_assert_true(missing_marker.has_ordered_partial_completion(), "missing marker reports ordered partial completion")
	_assert_false(missing_marker.movement_location_committed, "missing marker performs no arbitrary fallback move")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "missing marker keeps the forest active")
	_assert_eq(world_random.call_count(), 1, "missing marker does not roll back consumed draw")
	marker.spawn_point_id = OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID
	await _free_session(session, tree)

	var handoff_session: OldPineWorldSessionController = await _session(tree, 10_302)
	var handoff_outdoor: WorldMapController = handoff_session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var handoff_cave: WorldMapController = handoff_session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)
	handoff_session.player_runtime().state.skills.set_raw_level(&"dodge", 12)
	var handoff_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([5])
	handoff_session.configure_world_interaction_random_source(handoff_random)
	_move_player(handoff_outdoor, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, Vector2(1200, 300))
	handoff_outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine")
	handoff_cave._initialized = false
	var failed_handoff: VineTraversalResult = handoff_outdoor.traverse_selected_portal()
	_assert_eq(failed_handoff.outcome, VineTraversalResult.Outcome.MAP_HANDOFF_FAILED, "Passage selection exposes pre-commit handoff failure")
	_assert_true(failed_handoff.map_handoff_result != null and not failed_handoff.map_handoff_result.location_committed, "pre-commit handoff result remains uncommitted")
	_assert_eq(handoff_random.call_count(), 1, "failed handoff does not retry World RNG")
	_assert_eq(handoff_session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "pre-commit handoff failure keeps source active")
	handoff_cave._initialized = true
	await _free_session(handoff_session, tree)


func _test_committed_partial_after_vine_draw(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_351)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var cave: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)
	var random: ScriptedWorldInteractionRandomSource = (
		ScriptedWorldInteractionRandomSource.new([5])
	)
	session.configure_world_interaction_random_source(random)
	session.player_runtime().state.skills.set_raw_level(&"dodge", 12)
	outdoor.tree_exiting.connect(
		func() -> void: cave._initialized = false,
		CONNECT_ONE_SHOT,
	)
	var result: VineTraversalResult = _attempt_from_east(outdoor)
	_assert_eq(result.outcome, VineTraversalResult.Outcome.MAP_HANDOFF_FAILED, "Vine exposes post-commit B1 activation failure")
	_assert_true(result.source_presentation_reached and result.branch_presentation_reached, "post-commit failure preserves source and Passage presentation evidence")
	_assert_eq(result.selected_portal_id, OldPineWorldDefinitions.VINE_PASSAGE_PORTAL_ID, "post-commit failure preserves selected Passage portal")
	_assert_true(result.map_handoff_result != null and result.map_handoff_result.has_committed_partial_transition(), "nested B1 result remains explicitly committed-partial")
	_assert_true(result.movement_location_committed, "outer Vine result exposes committed destination location")
	_assert_true(result.has_ordered_partial_completion(), "outer Vine result exposes ordered partial completion")
	_assert_eq(random.call_count(), 1, "committed-partial handoff neither retries nor rolls back the World draw")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "committed partial keeps Cave as truthful recovery target")
	_assert_eq(session.player_runtime().world_location().map_id, OldPineWorldDefinitions.CAVE_MAP_ID, "committed partial never reports source logical location")
	_assert_true(cave.get_parent() == session.active_map_slot and outdoor.get_parent() == null, "committed partial keeps destination attached and source detached")
	_assert_false(cave.player_body.player_controlled, "B1 safe state leaves failed destination body non-controllable")
	_assert_false((cave.player_body.get_node("Camera2D") as Camera2D).enabled, "B1 safe state leaves failed destination camera disabled")
	cave._initialized = true
	await _free_session(session, tree)


func _test_south_exit_failure_recovery(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_361)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var cave: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)
	var random: ScriptedWorldInteractionRandomSource = (
		ScriptedWorldInteractionRandomSource.new([5, 5])
	)
	session.configure_world_interaction_random_source(random)
	session.player_runtime().state.skills.set_raw_level(&"dodge", 12)
	_assert_true(_attempt_from_east(outdoor).succeeded(), "SouthExit recovery fixture reaches Cave")
	var waterfall_marker: WorldSpawnMarker2D = session.world_map_of(OldPineWorldDefinitions.GORGE_MAP_ID).resolve_spawn_marker(
		OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID
	)
	waterfall_marker.spawn_point_id = &"temporarily.missing"
	await _physically_enter_south_exit(cave, tree)
	var failed: OldPineMapHandoffResult = session.last_map_handoff_result()
	_assert_true(failed != null, "physical SouthExit produces a typed failed handoff result")
	if failed == null:
		waterfall_marker.spawn_point_id = OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID
		await _free_session(session, tree)
		return
	_assert_eq(failed.outcome, OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING, "SouthExit pre-commit failure preserves exact B1 outcome")
	_assert_false(failed.location_committed, "SouthExit missing marker does not commit location")
	_assert_false(session.passage_request_pending(), "failed pre-commit SouthExit clears its duplicate-request gate")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "failed pre-commit SouthExit keeps Cave active")
	_assert_eq(random.call_count(), 1, "failed SouthExit consumes no additional World RNG")
	waterfall_marker.spawn_point_id = OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID
	await _physically_enter_south_exit(cave, tree)
	_assert_true(session.last_map_handoff_result().succeeded(), "recovered physical SouthExit can retry and reach the Gorge")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "recovered SouthExit lands at the Gorge waterfall")
	_assert_false(session.passage_request_pending(), "successful SouthExit clears its completed request gate")
	_assert_eq(random.call_count(), 1, "successful SouthExit still consumes zero World RNG")
	_assert_true(_attempt_from_east(outdoor).succeeded(), "same resident Cave supports later Vine reactivation")
	_assert_false(session.passage_request_pending(), "Cave reactivation starts with a clear SouthExit gate")
	await _physically_enter_south_exit(cave, tree)
	_assert_true(session.last_map_handoff_result().succeeded(), "SouthExit remains reusable after Cave reactivation")
	_assert_eq(random.call_count(), 2, "only the two Vine attempts consume World RNG across repeated exits")
	await _free_session(session, tree)


func _test_physical_interaction_and_exit_deduplication(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = await _session(tree, 10_401)
	var outdoor: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	var vine_area: WorldLandmarkArea2D = outdoor.get_node("Interactions/VineInteraction") as WorldLandmarkArea2D
	var selected_ids: Array[StringName] = []
	vine_area.selection_requested.connect(func(id: StringName) -> void: selected_ids.append(id))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	vine_area._input_event(outdoor.get_viewport(), click, 0)
	_assert_eq(selected_ids, [&"oldpine.outdoor.landmark.epath2_vine"], "actual Vine Area click emits exact LANDMARK ID")
	session.player_runtime().state.skills.set_raw_level(&"dodge", 12)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([5]))
	var result: VineTraversalResult = _attempt_from_east(outdoor)
	_assert_true(result.succeeded(), "physical-exit fixture reaches Cave")
	var cave: WorldMapController = session.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)
	_assert_false(session.passage_request_pending(), "arrival outside SouthExit has no pending request")
	_assert_eq(cave.get_node("SouthExit").get_signal_connection_list(&"body_entered").size(), 1, "actual SouthExit Area owns one scene signal connection")
	await _physically_enter_south_exit(cave, tree)
	var first_result: OldPineMapHandoffResult = session.last_map_handoff_result()
	cave.get_node("SouthExit").body_entered.emit(cave.player_body)
	await tree.process_frame
	_assert_true(first_result != null and first_result.succeeded(), "one Cave south trigger performs one handoff")
	_assert_true(session.last_map_handoff_result() == first_result, "repeated trigger after detach queues no duplicate handoff")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.GORGE_MAP_ID, "deduplicated exit lands at the Gorge waterfall")
	_assert_false(session.passage_request_pending(), "processed SouthExit no longer reports a pending transition")
	# The closed north passage is a band of colliding terrain (was a StaticBody2D).
	for point: Vector2 in [Vector2(-300, -240), Vector2(0, -240), Vector2(300, -240)]:
		_assert_true(TerrainProbe.blocks_at(cave, point), "Cave north secret passage remains physically blocked at %s" % point)
	await _free_session(session, tree)


func _physically_enter_south_exit(
	cave: WorldMapController,
	tree: SceneTree,
) -> void:
	var session: OldPineWorldSessionController = cave.session
	var exit_area: Area2D = cave.get_node("SouthExit")
	# A repeated contact report while the request waits must not queue a second handoff.
	exit_area.body_entered.connect(
		func(body: Node2D) -> void:
			if body == cave.player_body:
				exit_area.body_entered.emit(body),
		CONNECT_ONE_SHOT,
	)
	var landing: WorldSpawnMarker2D = cave.resolve_spawn_marker(
		OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID
	)
	cave.player_body.global_position = landing.global_position
	await tree.physics_frame
	await tree.process_frame
	var before: OldPineMapHandoffResult = session.last_map_handoff_result()
	Input.action_press(&"move_down")
	for _frame: int in range(60):
		await tree.physics_frame
		if session.last_map_handoff_result() != before:
			break
	Input.action_release(&"move_down")
	await tree.process_frame
	await tree.process_frame
	_assert_true(session.last_map_handoff_result() != before, "physical south movement into the SouthExit passage requests one handoff")


func _attempt_from_east(outdoor: WorldMapController) -> VineTraversalResult:
	_return_to_forest(outdoor)
	_move_player(outdoor, OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, Vector2(1200, 300))
	outdoor.select_landmark(&"oldpine.outdoor.landmark.epath2_vine")
	return outdoor.traverse_selected_portal()


## A fall or a Cave exit leaves the player on the gorge map. The forest has no
## marker on the bridge, so the fixture hands off to its entry in the clearing.
func _return_to_forest(outdoor: WorldMapController) -> void:
	var session: OldPineWorldSessionController = outdoor.session
	if session.active_map_id() == outdoor.map_id():
		return
	var handoff: OldPineMapHandoffResult = session.handoff_to(
		outdoor.map_id(),
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		GameContent.catalog().map(outdoor.map_id()).entry_spawn_id,
	)
	_assert_true(handoff.succeeded(), "fixture hands the player back to the forest")


func _move_player(
	outdoor: WorldMapController,
	zone_id: StringName,
	position: Vector2,
) -> void:
	outdoor.player_body.global_position = position
	outdoor.player_runtime().set_world_location(outdoor.resolve_location(zone_id, zone_id))


func _effective_dodge(player: WorldPlayerRuntimeState) -> int:
	return player.state.skills.effective_level(
		&"dodge",
		player.armor.aggregate_numeric_modifiers().dodge,
	)


func _add_owned_leather(
	outdoor: WorldMapController,
	instance_id: StringName,
) -> bool:
	var content: ItemContentDefinition = TestContent.item(
		TestContent.LEATHER_ITEM_ID
	)
	var item: ItemInstance = ItemInstance.new(instance_id, content.item_definition_id)
	if (
		not outdoor.inventory_state().register_item(item, content.own_weight)
		or not outdoor.item_instance_index().register_snapshot(item)
	):
		return false
	return InventoryTransferService.new().transfer(
		outdoor.inventory_state(),
		instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, outdoor.player_runtime().character_id),
			true,
			true,
			outdoor.player_runtime().maximum_encumbrance,
		),
	).succeeded


func _item_by_definition(
	items: Array[ItemInstance],
	definition_id: StringName,
) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _resource_snapshot(state: CharacterState) -> Array[int]:
	return [
		state.essence.current, state.essence.effective, state.essence.maximum,
		state.vitality.current, state.vitality.effective, state.vitality.maximum,
		state.spirit.current, state.spirit.effective, state.spirit.maximum,
		state.recovery.inner_force.current, state.recovery.inner_force.maximum,
		state.recovery.mana.current, state.recovery.mana.maximum,
		state.recovery.atman.current, state.recovery.atman.maximum,
		state.recovery.food, state.recovery.water,
	]


func _kill_bandit(
	controller: WorldMapController,
	victim: NpcRuntimeState,
	tree: SceneTree,
) -> CorpseState:
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SLOPE_ZONE_ID, OldPineWorldDefinitions.SLOPE_ZONE_ID,
	))
	if not controller.select_npc(victim.character_id):
		return null
	if controller.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return null
	HistoricalCombat.set_running(controller, false)
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.attributes.strength = 30
	victim.character_state.vitality.current = -1
	HistoricalCombat.tick(controller)
	controller.session.configure_combat_random_source(MaximumCombatRandomSource.new())
	for _tick: int in range(24):
		if victim.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		HistoricalCombat.tick(controller)
	await tree.process_frame
	if victim.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
		return null
	return null if controller.corpse_states().is_empty() else controller.corpse_states()[0]


func _session(tree: SceneTree, seed: int) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SessionScene.instantiate() as OldPineWorldSessionController
	session.deterministic_npc_seed = true
	session.npc_seed = seed
	session.deterministic_combat_seed = true
	session.combat_seed = seed + 1
	session.deterministic_world_interaction_seed = true
	session.world_interaction_seed = seed + 2
	tree.root.add_child(session)
	preload("res://tests/support/historical_world_combat_fixture.gd").install(session)
	await tree.process_frame
	_assert_true(session.player_runtime() != null, "session initializes persistent player")
	return session


func _free_session(session: OldPineWorldSessionController, tree: SceneTree) -> void:
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
