extends RefCounted

const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const OutdoorScene := preload(
	"res://scenes/world/oldpine/oldpine_outdoor.tscn"
)
const CaveScene := preload(
	"res://scenes/world/oldpine/oldpine_cave.tscn"
)
const OUTDOOR_PLAYER_START: StringName = (
	&"oldpine.outdoor.central_clearing.player_start"
)
const CAVE_VINE_LANDING: StringName = (
	&"oldpine.cave.waterfall_passage.vine_landing"
)

class CountingCombatRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		return 0 if exclusive_upper_bound > 0 else -1

class MaximumCombatRandomSource extends CombatRandomSource:
	func next_below(exclusive_upper_bound: int) -> int:
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

class RejectingLocationPlayerRuntime extends WorldPlayerRuntimeState:
	func set_world_location(_value: WorldLocationState) -> bool:
		return false

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_unconfigured_maps_remain_inert(tree)
	await _test_handoff_failure_boundaries(tree)
	await _test_session_authorities_and_resident_lifetime(tree)
	await _test_fresh_session_identity_scope(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_unconfigured_maps_remain_inert(tree: SceneTree) -> void:
	var outdoor: OldPineOutdoorController = (
		OutdoorScene.instantiate() as OldPineOutdoorController
	)
	tree.root.add_child(outdoor)
	_assert_false(outdoor.is_map_initialized(), "direct Outdoor stays uninitialized without session authorities")
	_assert_true(outdoor.player_runtime() == null, "direct Outdoor creates no fallback player authority")
	_assert_true(outdoor.inventory_state() == null, "direct Outdoor creates no fallback InventoryState")
	_assert_true(outdoor.stack_collection() == null, "direct Outdoor creates no fallback stack authority")
	_assert_true(outdoor.item_instance_index() == null, "direct Outdoor creates no fallback item index")
	_assert_true(outdoor.npc_random_source() == null, "direct Outdoor creates no fallback NPC RNG")
	_assert_true(outdoor.combat_random_source() == null, "direct Outdoor creates no fallback Combat RNG")
	_assert_false(outdoor.player_body.player_controlled, "unconfigured Outdoor body stays non-controllable")
	_assert_false((outdoor.player_body.get_node("Camera2D") as Camera2D).enabled, "unconfigured Outdoor camera stays disabled")
	_assert_true(outdoor.opportunity_timer.is_stopped(), "unconfigured Outdoor timer stays stopped")
	_assert_true(outdoor.npc_runtimes().is_empty(), "unconfigured Outdoor creates no NPC runtimes")
	outdoor.queue_free()
	await tree.process_frame

	var cave: OldPineCavePassageController = (
		CaveScene.instantiate() as OldPineCavePassageController
	)
	tree.root.add_child(cave)
	_assert_false(cave.is_map_initialized(), "direct Cave stays uninitialized without session authorities")
	_assert_true(cave.player_runtime() == null, "direct Cave creates no fallback player authority")
	_assert_false(cave.player_body.player_controlled, "unconfigured Cave body stays non-controllable")
	_assert_false((cave.player_body.get_node("Camera2D") as Camera2D).enabled, "unconfigured Cave camera stays disabled")
	_assert_true(cave.resident_npcs().is_empty(), "unconfigured Cave creates no NPC runtimes")
	cave.queue_free()
	await tree.process_frame


func _test_handoff_failure_boundaries(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _instantiate_session(tree, 9201, 9202)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var cave: OldPineCavePassageController = session.cave_map()
	var location_before: WorldLocationState = session.player_runtime().world_location()
	session._transitioning = true
	var concurrent: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	session._transitioning = false
	_assert_eq(concurrent.outcome, OldPineMapHandoffResult.Outcome.SESSION_NOT_READY, "transition gate rejects a concurrent handoff")
	_assert_true(session.player_runtime().world_location().same_location(location_before), "concurrent rejection preserves player location")
	_assert_true(outdoor.get_parent() == session.active_map_slot, "concurrent rejection preserves source attachment")
	_assert_true(cave.get_parent() == null, "concurrent rejection leaves destination detached")

	var original_player: WorldPlayerRuntimeState = session.player_runtime()
	var rejecting_player: RejectingLocationPlayerRuntime = RejectingLocationPlayerRuntime.new(
		original_player.character_id,
		original_player.state,
		original_player.relationship,
		original_player.busy,
		original_player.armor,
		original_player.world_location(),
		original_player.life_status,
		original_player.exists_in_world,
		original_player.combat_available,
		original_player.maximum_encumbrance,
	)
	session._player = rejecting_player
	var commit_failure: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_eq(commit_failure.outcome, OldPineMapHandoffResult.Outcome.LOCATION_COMMIT_FAILED, "rejected logical commit reports its exact stage")
	_assert_true(commit_failure.destination_prepared, "commit failure retains destination preparation evidence")
	_assert_true(commit_failure.source_detached, "commit failure retains source-detach evidence")
	_assert_true(commit_failure.source_restored, "pre-commit failure restores the source map")
	_assert_false(commit_failure.location_committed, "rejected logical commit is not reported committed")
	_assert_false(commit_failure.has_committed_partial_transition(), "pre-commit restoration is not a committed partial transition")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "pre-commit restoration keeps source logical ownership")
	_assert_eq(session.active_map_child_count(), 1, "pre-commit restoration recovers exact-one active child")
	_assert_true(outdoor.get_parent() == session.active_map_slot, "pre-commit restoration reattaches source")
	_assert_true(outdoor.player_body.player_controlled, "pre-commit restoration re-enables source control")
	_assert_false(cave.player_body.player_controlled, "pre-commit restoration keeps destination inert")
	_assert_true(rejecting_player.world_location().same_location(location_before), "pre-commit restoration preserves authoritative location")
	session._player = original_player
	cave._initialized = false
	var preparation_failure: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_eq(preparation_failure.outcome, OldPineMapHandoffResult.Outcome.DESTINATION_PREPARATION_FAILED, "destination preparation failure is typed before source suspension")
	_assert_false(preparation_failure.source_detached, "preparation failure never detaches source")
	_assert_false(preparation_failure.location_committed, "preparation failure never commits location")
	_assert_true(outdoor.get_parent() == session.active_map_slot, "preparation failure keeps source attached")
	_assert_true(outdoor.player_body.player_controlled, "preparation failure keeps source controllable")
	_assert_false(cave.player_body.player_controlled, "preparation failure leaves destination non-controllable")
	cave._initialized = true
	session.queue_free()
	await tree.process_frame

	var partial_session: OldPineWorldSessionController = _instantiate_session(tree, 9211, 9212)
	var partial_outdoor: OldPineOutdoorController = partial_session.outdoor_map()
	var partial_cave: OldPineCavePassageController = partial_session.cave_map()
	partial_outdoor.tree_exiting.connect(
		func() -> void: partial_cave._initialized = false,
		CONNECT_ONE_SHOT,
	)
	var activation_failure: OldPineMapHandoffResult = partial_session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_eq(activation_failure.outcome, OldPineMapHandoffResult.Outcome.DESTINATION_ACTIVATION_FAILED, "post-commit activation failure reports exact outcome")
	_assert_true(activation_failure.location_committed, "post-commit failure keeps location commit evidence")
	_assert_true(activation_failure.destination_attached, "post-commit failure keeps destination attachment evidence")
	_assert_true(activation_failure.has_committed_partial_transition(), "post-commit failure is explicitly partial")
	_assert_eq(partial_session.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "post-commit recovery target remains destination")
	_assert_eq(partial_session.active_map_child_count(), 1, "post-commit failure preserves exact-one attached map")
	_assert_true(partial_cave.get_parent() == partial_session.active_map_slot, "post-commit failure keeps committed destination attached")
	_assert_false(partial_outdoor.player_body.player_controlled, "post-commit failure leaves source non-controllable")
	_assert_false(partial_cave.player_body.player_controlled, "post-commit failure safes destination control")
	_assert_false((partial_cave.player_body.get_node("Camera2D") as Camera2D).enabled, "post-commit failure safes destination camera")
	_assert_eq(partial_session.player_runtime().world_location().map_id, OldPineWorldDefinitions.CAVE_MAP_ID, "post-commit failure never reports source logical location")
	partial_session.queue_free()
	await tree.process_frame


func _test_session_authorities_and_resident_lifetime(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _instantiate_session(tree, 9301, 9302)
	_assert_true(session != null, "Old Pine session scene instantiates")
	if session == null:
		return
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var cave: OldPineCavePassageController = session.cave_map()
	var session_allocator: SessionItemIdAllocator = session.item_id_allocator()
	_assert_true(outdoor != null and cave != null, "session retains both typed resident maps")
	_assert_eq(session.resident_map_count(), 2, "session has exactly two resident maps")
	_assert_eq(session.active_map_child_count(), 1, "exactly one resident map is tree-active")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "Outdoor starts active")
	_assert_eq(session.player_runtime().world_location().map_id, OldPineWorldDefinitions.OUTDOOR_MAP_ID, "inactive Cave prewarm never changes player location")
	_assert_true(outdoor.get_parent() == session.active_map_slot, "Outdoor is the attached resident")
	_assert_true(cave.get_parent() == null, "Cave starts detached and frozen")
	_assert_eq(outdoor.initialization_count(), 1, "Outdoor initializes exactly once")
	_assert_eq(cave.initialization_count(), 1, "Cave initializes exactly once")
	_assert_true(outdoor.player_runtime() == session.player_runtime(), "Outdoor binds the session player authority")
	_assert_true(cave.player_runtime() == session.player_runtime(), "Cave binds the same session player authority")
	_assert_true(outdoor.player_body != cave.player_body, "resident maps own distinct physical player bodies")
	_assert_true(outdoor.inventory_state() == session.inventory_state(), "Outdoor shares session inventory authority")
	_assert_true(outdoor.stack_collection() == session.stack_collection(), "Outdoor shares session stack authority")
	_assert_true(outdoor.item_instance_index() == session.item_instance_index(), "Outdoor shares session item index")
	_assert_true(outdoor._item_id_allocator == session_allocator, "Outdoor receives the exact session item-ID allocator object")
	_assert_true(outdoor.npc_random_source() == session.npc_random_source(), "Outdoor shares session NPC RNG")
	_assert_true(outdoor.combat_random_source() == session.combat_random_source(), "Outdoor shares session combat RNG")
	_assert_true(cave._inventory == session.inventory_state(), "Cave receives the same session InventoryState")
	_assert_true(cave._stacks == session.stack_collection(), "Cave receives the same session stack authority")
	_assert_true(cave._item_index == session.item_instance_index(), "Cave receives the same session item index")
	_assert_true(cave._npc_random == session.npc_random_source(), "Cave receives the same session NPC RNG without consuming it")
	_assert_true(cave._combat_random == session.combat_random_source(), "Cave receives the same session Combat RNG")
	_assert_eq(cave._item_instance_scope, session.item_instance_scope(), "Cave receives the same session item-ID scope")
	_assert_true(cave._item_id_allocator == session_allocator, "Cave receives the exact session item-ID allocator object")
	_assert_eq(session_allocator.next_dynamic_sequence, 0, "twelve authored bootstrap items consume no dynamic sequence")
	_assert_eq(session.inventory_state().registered_item_ids().size(), 12, "New Game still creates exactly twelve bootstrap items")
	_assert_true(outdoor.player_body.player_controlled, "only active Outdoor player body is controllable")
	_assert_false(cave.player_body.player_controlled, "detached Cave player body is not controllable")
	_assert_true(
		(outdoor.player_body.get_node("Camera2D") as Camera2D).enabled,
		"active Outdoor camera is enabled",
	)
	_assert_false(
		(cave.player_body.get_node("Camera2D") as Camera2D).enabled,
		"detached Cave camera is disabled",
	)
	_assert_eq(cave.resident_npcs().size(), 0, "minimal Passage Cave has no authored NPC")
	_assert_true(cave.resolve_spawn_marker(CAVE_VINE_LANDING) != null, "Cave exposes exact VineLanding marker")
	_assert_true(cave.has_node("Zones/PassageZone"), "Cave contains one PassageZone")
	_assert_true(cave.has_node("Terrain/NorthBlocked"), "Cave keeps north passage visibly blocked")
	_assert_true(cave.has_node("Boundaries/NorthBlockedBoundary"), "Cave has a physical north blocked boundary")
	var outdoor_world_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.WORLD,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
	)
	var cave_world_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.WORLD,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
	)
	_assert_ne(cave_world_endpoint.endpoint_id, outdoor_world_endpoint.endpoint_id, "opaque Cave WORLD endpoint does not collide with Outdoor")

	var player: WorldPlayerRuntimeState = session.player_runtime()
	var character_state_before: CharacterState = player.state
	var equipment_before: EquipmentState = player.state.equipment
	var armor_before: ArmorState = player.armor
	var inventory_before: InventoryState = session.inventory_state()
	var stacks_before: CombinedStackCollection = session.stack_collection()
	var item_index_before: WorldItemInstanceIndex = session.item_instance_index()
	var combat_random_before: CombatRandomSource = session.combat_random_source()
	var npc_random_before: NpcInitializationRandomSource = session.npc_random_source()
	var primary_before: EquippedWeaponRef = player.state.equipment.primary_weapon()
	var primary_id: StringName = primary_before.instance_id
	var outdoor_instance_id: int = outdoor.get_instance_id()
	var cave_instance_id: int = cave.get_instance_id()
	var victim: NpcRuntimeState = outdoor.npc_runtimes()[1]
	var victim_body: WorldCharacterBody2D = outdoor.bandit_bodies[1]
	var corpse: CorpseState = await _kill_bandit(outdoor, victim, tree)
	_assert_true(corpse != null, "fixture creates one DEATH_COMPLETE Outdoor corpse")
	if corpse == null:
		session.queue_free()
		await tree.process_frame
		return
	var corpse_view: CombatSliceCorpseView = outdoor.corpse_view_for(
		corpse.corpse_item_instance_id
	)
	_assert_true(corpse_view != null, "completed corpse has an interactive resident view")
	var corpse_view_id: int = corpse_view.get_instance_id()
	var corpse_selection_connections: int = corpse_view.get_signal_connection_list(
		"selection_requested"
	).size()
	var corpse_range_connections: int = corpse_view.get_signal_connection_list(
		"loot_range_changed"
	).size()
	var corpse_position: Vector2 = corpse_view.global_position
	var corpse_id: StringName = corpse.corpse_item_instance_id
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.ITEM,
		corpse_id,
	)
	var corpse_items: Array[ItemInstance] = victim.loadout_items()
	var short_sword: ItemInstance = _item_by_definition(
		corpse_items,
		OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID,
	)
	var silver: ItemInstance = _item_by_definition(
		corpse_items,
		OldPineNpcDefinitions.SILVER_ITEM_ID,
	)
	_assert_true(short_sword != null and silver != null, "corpse retains sword and silver authorities")
	_assert_eq(session.stack_collection().stack_state(silver.item_instance_id).amount, 3, "corpse silver begins at authored amount three")
	outdoor.player_body.global_position = corpse_view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(outdoor.select_corpse(corpse_id), "fixture selects the live corpse")
	_assert_true(outdoor.open_selected_loot(), "fixture opens corpse loot in physical range")
	_assert_true(outdoor.take_selected_loot_item(short_sword.item_instance_id).succeeded, "fixture loots one real short-sword instance")
	_assert_true(outdoor.unwield_player_item(primary_id).succeeded, "fixture unwields prototype long sword")
	_assert_true(outdoor.wield_player_item(short_sword.item_instance_id).succeeded, "fixture wields looted short sword")
	var leather_content: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(
			OldPineItemContentDefinitions.LEATHER_ITEM_ID
		)
	)
	var leather: ItemInstance = ItemInstance.new(
		StringName("%s.roundtrip-leather" % String(session.item_instance_scope())),
		OldPineItemContentDefinitions.LEATHER_ITEM_ID,
	)
	_assert_true(session.inventory_state().register_item(leather, leather_content.own_weight), "fixture registers authored leather instance")
	_assert_true(session.item_instance_index().register_snapshot(leather), "fixture indexes authored leather metadata")
	_assert_true(
		InventoryTransferService.new().transfer(
			session.inventory_state(),
			leather.item_instance_id,
			InventoryTransferDestination.new(
				ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id),
				true,
				true,
				player.maximum_encumbrance,
			),
		).succeeded,
		"fixture places leather in direct player inventory",
	)
	_assert_true(outdoor.wear_player_item(leather.item_instance_id).succeeded, "fixture wears authored leather through runtime adapter")
	_assert_true(player.armor.is_worn(leather.item_instance_id), "player armor authority records worn leather")
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var npc_body: WorldCharacterBody2D = outdoor.bandit_bodies[0]
	var npc_body_position: Vector2 = npc_body.global_position
	npc.character_state.vitality.current -= 7
	var living_npc_vitality: int = npc.character_state.vitality.current
	var corpse_layer_id: int = outdoor.corpse_layer.get_instance_id()

	var location_before: WorldLocationState = player.world_location()
	var unknown_map: OldPineMapHandoffResult = session.handoff_to(
		&"oldpine.unknown",
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_eq(unknown_map.outcome, OldPineMapHandoffResult.Outcome.UNKNOWN_DESTINATION_MAP, "unknown destination map is rejected")
	var wrong_zone: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.SECRET_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.SECRET_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_eq(wrong_zone.outcome, OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID, "unimplemented Cave zone is rejected even with internally matching IDs")
	var wrong_combat: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.SECRET_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_eq(wrong_combat.outcome, OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID, "wrong combat-location ID is rejected")
	var invalid: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		&"oldpine.cave.missing",
	)
	_assert_eq(invalid.outcome, OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING, "missing destination marker fails before preparation")
	_assert_false(invalid.destination_prepared, "invalid handoff performs no destination preparation")
	_assert_false(invalid.location_committed, "invalid handoff performs no location mutation")
	_assert_true(player.world_location().same_location(location_before), "invalid handoff preserves location")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "invalid handoff preserves active map")
	_assert_eq(session.active_map_child_count(), 1, "invalid handoff preserves one active child")

	var random: CountingCombatRandomSource = CountingCombatRandomSource.new()
	_assert_true(session.configure_combat_random_source(random), "session accepts one replacement combat RNG authority")
	_assert_true(outdoor.combat_random_source() == random, "replacement RNG is propagated to resident Outdoor")
	var pending_npc: NpcRuntimeState = outdoor.npc_runtimes()[4]
	_assert_true(pending_npc.set_world_location(player.world_location()), "fixture places an idle authored NPC in current combat location")
	outdoor.aggression_adapter().enter_player_presence(pending_npc, player, true)
	_assert_true(outdoor.aggression_adapter().pending_count() > 0, "fixture establishes pending Node-bound aggression before detach")
	_assert_true(player.relationship.mark_lethal_target(npc.character_id), "fixture creates player lethal relation")
	_assert_true(npc.relationship.add_opponent(player.character_id), "fixture creates reciprocal ordinary relation")
	_assert_true(player.busy.start_busy(3), "fixture starts busy without cadence")
	outdoor.opportunity_timer.start(40.0)
	_assert_false(outdoor.opportunity_timer.is_stopped(), "fixture starts Outdoor cadence timer before detach")
	var busy_before: int = player.busy.busy_value
	var to_cave: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_true(to_cave.succeeded(), "typed lower-level handoff reaches Cave")
	_assert_true(to_cave.destination_prepared and to_cave.source_detached, "handoff reports ordered preparation and detach")
	_assert_true(to_cave.location_committed and to_cave.destination_attached, "handoff reports commit before active destination")
	_assert_true(to_cave.relationship_reconciled, "handoff reports post-commit relationship reconciliation")
	_assert_false(to_cave.has_committed_partial_transition(), "completed handoff is not a partial transition")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.CAVE_MAP_ID, "Cave becomes active map")
	_assert_eq(session.active_map_child_count(), 1, "handoff leaves exactly one active map child")
	_assert_true(outdoor.get_parent() == null, "inactive Outdoor is detached, not freed")
	_assert_false(outdoor.is_inside_tree(), "inactive Outdoor is physically outside SceneTree")
	_assert_true(outdoor.opportunity_timer.is_stopped(), "inactive Outdoor cadence timer is suspended")
	_assert_eq(outdoor.aggression_adapter().pending_count(), 0, "deactivation clears stale pending aggression")
	_assert_false(outdoor.aggression_adapter().is_present(pending_npc.character_id), "deactivation clears stale physical presence")
	_assert_true(cave.get_parent() == session.active_map_slot, "Cave is attached to ActiveMapSlot")
	_assert_eq(outdoor.get_instance_id(), outdoor_instance_id, "Outdoor resident Node identity survives detach")
	_assert_eq(cave.get_instance_id(), cave_instance_id, "Cave resident Node identity survives activation")
	_assert_false(outdoor.player_body.player_controlled, "detached Outdoor body is non-controllable")
	_assert_true(cave.player_body.player_controlled, "active Cave body is controllable")
	_assert_false((outdoor.player_body.get_node("Camera2D") as Camera2D).enabled, "detached Outdoor camera is disabled")
	_assert_true((cave.player_body.get_node("Camera2D") as Camera2D).enabled, "active Cave camera is enabled")
	_assert_eq(player.world_location().map_id, OldPineWorldDefinitions.CAVE_MAP_ID, "player map ID commits to Cave")
	_assert_eq(player.world_location().zone_id, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, "player zone commits exactly")
	_assert_eq(player.world_location().combat_location_id, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, "player combat-location ID commits exactly")
	_assert_eq(cave.player_body.global_position, cave.resolve_spawn_marker(CAVE_VINE_LANDING).global_position, "Cave body lands on exact VineLanding")
	await tree.physics_frame
	await tree.physics_frame
	var passage_zone: Area2D = cave.get_node("Zones/PassageZone") as Area2D
	_assert_true(passage_zone.overlaps_body(cave.player_body), "VineLanding is physically inside PassageZone")
	_assert_true(cave.player_body.move_and_collide(Vector2(80.0, 0.0), true) == null, "Cave passage permits ordinary lateral player movement")
	var north_collision: KinematicCollision2D = cave.player_body.move_and_collide(
		Vector2(0.0, -1000.0)
	)
	_assert_true(north_collision != null, "Cave player cannot cross physical north boundary")
	_assert_true(cave.player_body.global_position.y > -245.0, "north collision leaves player south of blocked passage")
	_assert_false(player.relationship.has_opponent(npc.character_id), "cross-map availability removes ordinary player opponent")
	_assert_true(player.relationship.has_lethal_target(npc.character_id), "cross-map reconciliation preserves lethal marker")
	_assert_true(npc.relationship.has_opponent(player.character_id), "inactive source NPC remains frozen until reactivation")
	_assert_eq(player.busy.busy_value, busy_before, "handoff does not advance busy")
	_assert_eq(random.calls, 0, "empty post-cleanup selection consumes no combat RNG")
	_assert_eq(player.state.equipment.primary_weapon().instance_id, short_sword.item_instance_id, "looted equipped item identity survives first handoff")
	_assert_true(session.inventory_state().is_registered(primary_id), "same inventory item remains registered")
	_assert_true(player.armor.is_worn(leather.item_instance_id), "worn leather survives first handoff")

	for _frame: int in range(3):
		await tree.process_frame
		await tree.physics_frame
	_assert_eq(outdoor.get_instance_id(), outdoor_instance_id, "detached Outdoor remains resident across frames")
	_assert_eq(npc_body.global_position, npc_body_position, "inactive NPC body does not simulate off-screen")
	_assert_true(npc.relationship.has_opponent(player.character_id), "inactive NPC relationship does not tick off-screen")
	_assert_eq(npc.character_state.vitality.current, living_npc_vitality, "inactive NPC resource state does not progress off-screen")
	_assert_eq(outdoor.corpse_states()[0], corpse, "inactive corpse authority remains the same object")
	_assert_eq(outdoor.corpse_view_for(corpse_id).get_instance_id(), corpse_view_id, "inactive corpse view remains the same Node")
	_assert_eq(outdoor.corpse_view_for(corpse_id).global_position, corpse_position, "inactive corpse physical position remains unchanged")
	_assert_eq(session.stack_collection().stack_state(silver.item_instance_id).amount, 3, "inactive corpse silver amount does not change")

	var to_outdoor: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OUTDOOR_PLAYER_START,
	)
	_assert_true(to_outdoor.succeeded(), "typed return handoff reaches Outdoor")
	_assert_true(session.outdoor_map() == outdoor, "return reuses the exact Outdoor controller")
	_assert_true(session.cave_map() == cave, "return retains the exact Cave controller")
	_assert_eq(outdoor.initialization_count(), 1, "Outdoor is not reinitialized on return")
	_assert_eq(cave.initialization_count(), 1, "Cave is not reinitialized after detach")
	_assert_eq(outdoor.corpse_layer.get_instance_id(), corpse_layer_id, "Outdoor corpse layer identity survives round trip")
	_assert_true(outdoor.corpse_states()[0] == corpse, "same CorpseState survives round trip")
	_assert_true(session.item_id_allocator() == session_allocator, "map round trip preserves the exact allocator authority")
	_assert_eq(outdoor.corpse_view_for(corpse_id).get_instance_id(), corpse_view_id, "same corpse view Node survives round trip")
	_assert_eq(corpse_view.get_signal_connection_list("selection_requested").size(), corpse_selection_connections, "corpse picking signal is not duplicated on reactivation")
	_assert_eq(corpse_view.get_signal_connection_list("loot_range_changed").size(), corpse_range_connections, "corpse range signal is not duplicated on reactivation")
	_assert_eq(outdoor.corpse_view_for(corpse_id).global_position, corpse_position, "corpse view position survives round trip")
	_assert_true(session.inventory_state().is_direct_child(silver.item_instance_id, corpse_endpoint), "remaining silver stays directly in same corpse")
	_assert_eq(session.stack_collection().stack_state(silver.item_instance_id).amount, 3, "remaining corpse silver preserves exact amount")
	_assert_eq(npc_body.global_position, npc_body_position, "Outdoor NPC physical state survives round trip")
	_assert_eq(npc.character_state.vitality.current, living_npc_vitality, "living NPC resource mutation survives round trip")
	_assert_false(victim.exists_in_map, "dead authored NPC remains absent after round trip")
	_assert_false(npc.relationship.has_opponent(player.character_id), "source NPC reconciles before resumed cadence")
	_assert_true(player.relationship.has_lethal_target(npc.character_id), "return still preserves independent lethal marker")
	_assert_eq(player.busy.busy_value, busy_before, "round trip performs no combat opportunity")
	_assert_eq(random.calls, 0, "round trip with no retained opponent consumes zero combat RNG")
	_assert_true(outdoor.opportunity_timer.is_stopped(), "reactivation does not restart cadence when reconciliation leaves no active relationship")
	_assert_true(session.combat_random_source() == random, "same replacement Combat RNG survives map round trip")
	_assert_true(player.state == character_state_before, "exact CharacterState identity survives full round trip")
	_assert_true(player.state.equipment == equipment_before, "exact EquipmentState identity survives full round trip")
	_assert_true(player.armor == armor_before, "exact ArmorState identity survives full round trip")
	_assert_true(session.inventory_state() == inventory_before, "exact InventoryState identity survives full round trip")
	_assert_true(session.stack_collection() == stacks_before, "exact CombinedStackCollection identity survives full round trip")
	_assert_true(session.item_instance_index() == item_index_before, "exact item-index identity survives full round trip")
	_assert_true(session.npc_random_source() == npc_random_before, "exact NPC RNG identity survives full round trip")
	_assert_true(combat_random_before != session.combat_random_source(), "explicit test replacement is the only combat RNG identity change")
	_assert_eq(player.state.equipment.primary_weapon().instance_id, short_sword.item_instance_id, "same looted weapon ID survives full round trip")
	_assert_true(player.armor.is_worn(leather.item_instance_id), "same leather ItemInstanceId remains worn after round trip")
	_assert_true(session.inventory_state().is_direct_child(leather.item_instance_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)), "worn leather remains direct player inventory")
	_assert_true(outdoor.player_body.player_controlled, "returned Outdoor body regains control")
	_assert_false(cave.player_body.player_controlled, "detached Cave body loses control")
	_assert_false(outdoor.has_signal("reset_requested"), "obsolete Outdoor Reset signal is absent")
	var cave_second_activation: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		CAVE_VINE_LANDING,
	)
	_assert_true(cave_second_activation.succeeded(), "same Cave resident supports a second activation")
	_assert_eq(cave.get_instance_id(), cave_instance_id, "second Cave activation reuses exact Node identity")
	_assert_eq(cave.initialization_count(), 1, "second Cave activation does not repeat initialization")
	var second_return: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OUTDOOR_PLAYER_START,
	)
	_assert_true(second_return.succeeded(), "second Cave roundtrip returns through same residents")
	_assert_eq(outdoor.initialization_count(), 1, "repeated roundtrip still does not reinitialize Outdoor")
	_assert_false(outdoor.has_signal("reset_requested"), "repeated roundtrip retains no Reset seam")
	_assert_eq(corpse_view.get_signal_connection_list("selection_requested").size(), corpse_selection_connections, "repeated roundtrip still has one corpse picking connection")
	_assert_eq(corpse_view.get_signal_connection_list("loot_range_changed").size(), corpse_range_connections, "repeated roundtrip still has one corpse range connection")
	var already_active: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID,
		OUTDOOR_PLAYER_START,
	)
	_assert_eq(already_active.outcome, OldPineMapHandoffResult.Outcome.ALREADY_ACTIVE, "handoff rejects an already-active destination before mutation")
	var npc_random_after_roundtrip: int = session.npc_random_source().next_below(1000)
	var old_session_ref: WeakRef = weakref(session)
	var old_outdoor_ref: WeakRef = weakref(outdoor)
	var old_cave_ref: WeakRef = weakref(cave)
	var old_outdoor_body_ref: WeakRef = weakref(outdoor.player_body)
	var old_cave_body_ref: WeakRef = weakref(cave.player_body)
	var old_outdoor_camera_ref: WeakRef = weakref(outdoor.player_body.get_node("Camera2D"))
	var old_cave_camera_ref: WeakRef = weakref(cave.player_body.get_node("Camera2D"))
	var old_timer_ref: WeakRef = weakref(outdoor.opportunity_timer)
	var old_corpse_view_ref: WeakRef = weakref(corpse_view)
	session.queue_free()
	await tree.process_frame
	_assert_true(old_session_ref.get_ref() == null, "destroyed old session Node becomes invalid")
	_assert_true(old_outdoor_ref.get_ref() == null, "active Outdoor Node is destroyed with old session")
	_assert_true(old_cave_ref.get_ref() == null, "detached Cave Node is explicitly destroyed with old session")
	_assert_true(old_outdoor_body_ref.get_ref() == null, "old Outdoor player body cannot survive session destruction")
	_assert_true(old_cave_body_ref.get_ref() == null, "old detached Cave player body cannot survive session destruction")
	_assert_true(old_outdoor_camera_ref.get_ref() == null, "old Outdoor Camera cannot survive session destruction")
	_assert_true(old_cave_camera_ref.get_ref() == null, "old detached Cave Camera cannot survive session destruction")
	_assert_true(old_timer_ref.get_ref() == null, "old Outdoor Timer cannot fire after session destruction")
	_assert_true(old_corpse_view_ref.get_ref() == null, "old corpse view and signals cannot survive session destruction")
	var control: OldPineWorldSessionController = _instantiate_session(tree, 9301, 9302)
	_assert_eq(control.npc_random_source().next_below(1000), npc_random_after_roundtrip, "Cave activation and return consume zero NPC-init RNG draws")
	_assert_eq(control.outdoor_map().npc_runtimes().size(), 5, "fresh whole-session boundary restores all five authored NPCs")
	_assert_eq(control.outdoor_map().corpse_states().size(), 0, "fresh whole-session boundary clears prior corpse state")
	_assert_true(control.player_runtime().armor.occupied_slots().is_empty(), "fresh whole-session boundary restores initial Armor")
	_assert_eq(control.player_runtime().state.equipment.primary_weapon().weapon_id, OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID, "fresh whole-session boundary restores prototype long sword")
	_assert_false(control.inventory_state().is_registered(leather.item_instance_id), "fresh whole-session boundary excludes acquired leather")
	control.queue_free()
	await tree.process_frame


func _test_fresh_session_identity_scope(tree: SceneTree) -> void:
	var first: OldPineWorldSessionController = _instantiate_session(tree, 9401, 9402)
	var first_scope: StringName = first.item_instance_scope()
	var first_item_id: StringName = first.player_runtime().state.equipment.primary_weapon().instance_id
	first.queue_free()
	await tree.process_frame
	var second: OldPineWorldSessionController = _instantiate_session(tree, 9401, 9402)
	_assert_ne(second.item_instance_scope(), first_scope, "whole-session reset creates a fresh item ID scope")
	_assert_ne(second.player_runtime().state.equipment.primary_weapon().instance_id, first_item_id, "fresh session creates a fresh player item instance")
	_assert_eq(second.active_map_child_count(), 1, "fresh session still has one active map child")
	second.queue_free()
	await tree.process_frame


func _instantiate_session(
	tree: SceneTree,
	npc_seed: int,
	combat_seed: int,
) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = (
		SessionScene.instantiate() as OldPineWorldSessionController
	)
	if session == null:
		return null
	session.deterministic_npc_seed = true
	session.npc_seed = npc_seed
	session.deterministic_combat_seed = true
	session.combat_seed = combat_seed
	tree.root.add_child(session)
	return session


func _kill_bandit(
	controller: OldPineOutdoorController,
	victim: NpcRuntimeState,
	tree: SceneTree,
) -> CorpseState:
	controller.player_body.set_world_location(controller.resolve_location(
		OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID, OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID,
	))
	if not controller.select_npc(victim.character_id):
		return null
	if controller.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return null
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.attributes.strength = 30
	victim.character_state.vitality.current = -1
	controller.process_cadence_tick()
	controller.configure_combat_random_source(MaximumCombatRandomSource.new())
	for _tick: int in range(24):
		if victim.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		controller.process_cadence_tick()
	await tree.process_frame
	if victim.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
		return null
	return null if controller.corpse_states().is_empty() else controller.corpse_states()[0]


func _item_by_definition(
	items: Array[ItemInstance],
	definition_id: StringName,
) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [message, expected, actual])


func _assert_ne(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual != expected, "%s (unexpected=%s)" % [message, actual])
