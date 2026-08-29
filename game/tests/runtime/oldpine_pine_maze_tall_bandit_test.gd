extends RefCounted

const SceneType := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

class CountingMaximumCombatRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

class CountingAttackFavoringRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		if exclusive_upper_bound <= 0:
			return -1
		return 0 if calls <= 4 else exclusive_upper_bound - 1

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_authored_definitions_and_fixed_zone_partition()
	await _test_persisted_maze_geometry_and_zone_transitions(tree)
	await _test_tall_bandit_runtime_aggression_death_loot_and_equip(tree)
	await _test_partial_tall_death_is_not_lootable(tree)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_authored_definitions_and_fixed_zone_partition() -> void:
	_assert_true(OldPineWorldDefinitions.validate(), "Old Pine world definitions validate")
	_assert_true(OldPineNpcDefinitions.validate(), "Old Pine NPC definitions validate")
	_assert_true(OldPineSpawnDefinitions.validate(), "Old Pine spawn definitions validate")
	_assert_eq(
		OldPineWorldDefinitions.zone_by_id(
			OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID
		).legacy_room_ids(),
		["d/oldpine/pine1.c", "d/oldpine/pine2.c"],
		"Pine Entrance has exact source-room trace",
	)
	_assert_eq(
		OldPineWorldDefinitions.zone_by_id(
			OldPineWorldDefinitions.PINE_DEEP_ZONE_ID
		).legacy_room_ids(),
		[
			"d/oldpine/pine3.c", "d/oldpine/pine4.c",
			"d/oldpine/pine5.c", "d/oldpine/pine6.c",
		],
		"Pine Deep has exact source-room trace",
	)
	_assert_eq(
		OldPineWorldDefinitions.zone_by_id(
			OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID
		).legacy_room_ids(),
		["d/oldpine/pine7.c", "d/oldpine/cliffdown.c"],
		"Pine Cliff Edge has exact source-room trace",
	)
	var pine_room_counts: Dictionary[String, int] = {}
	for zone_id: StringName in [
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
		OldPineWorldDefinitions.PINE_DEEP_ZONE_ID,
		OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID,
	]:
		var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(zone_id)
		_assert_eq(zone.combat_location_id, zone_id, "Pine combat location is exact zone ID")
		for source_path: String in zone.legacy_room_ids():
			pine_room_counts[source_path] = pine_room_counts.get(source_path, 0) + 1
	_assert_eq(pine_room_counts.size(), 8, "exactly eight Pine legacy rooms are represented")
	for source_path: String in pine_room_counts:
		_assert_eq(pine_room_counts[source_path], 1, "%s occurs exactly once" % source_path)
	var portal_ids: Array[StringName] = []
	for portal: PortalDefinition in OldPineWorldDefinitions.portal_definitions():
		portal_ids.append(portal.portal_id)
	_assert_eq(
		portal_ids,
		[
			OldPineWorldDefinitions.CLIMB_PINE_PORTAL_ID,
			OldPineWorldDefinitions.DESCEND_TREE1_PORTAL_ID,
		],
		"Phase 9B1 invents no Keep or cliff portal",
	)

	var tall: NpcDefinition = OldPineNpcDefinitions.tall_bandit_definition()
	_assert_eq(tall.definition_id, &"oldpine.npc.tall_bandit", "tall bandit ID")
	_assert_eq(tall.display_name, "土匪", "tall bandit display name")
	_assert_eq(tall.aliases(), [&"bandit"], "tall bandit alias")
	_assert_eq(tall.gender, CharacterState.GENDER_MALE, "tall bandit gender")
	_assert_eq(tall.age, 27, "tall bandit age")
	_assert_eq(tall.combat_experience, 900, "tall bandit combat experience")
	_assert_eq(tall.score, 100, "tall bandit score")
	_assert_eq(tall.attitude, NpcDefinition.Attitude.AGGRESSIVE, "tall bandit attitude")
	_assert_eq(
		_skill_pairs(tall.skill_levels()),
		[[&"sword", 15], [&"parry", 15], [&"dodge", 10]],
		"tall bandit exact authored skills",
	)
	_assert_true(tall.base_attribute_overrides().is_empty(), "no invented base overrides")
	_assert_true(tall.resource_overrides().is_empty(), "no invented resource overrides")
	var loadout: Array[NpcLoadoutEntry] = tall.loadout_entries()
	_assert_eq(loadout.size(), 2, "tall bandit has exactly two loadout entries")
	_assert_eq(loadout[0].item_definition_id, OldPineNpcDefinitions.LONG_SWORD_ITEM_ID, "long sword loadout ID")
	_assert_eq(loadout[0].quantity, 1, "one long sword")
	_assert_eq(loadout[0].equipment_intent, NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY, "long sword starts wielded")
	_assert_eq(loadout[1].item_definition_id, OldPineNpcDefinitions.SILVER_ITEM_ID, "silver loadout ID")
	_assert_eq(loadout[1].quantity, 6, "six silver")
	var sword: NpcLoadoutItemDefinition = OldPineNpcDefinitions.long_sword_content()
	var canonical_sword: OldPineItemContentDefinition = (
		OldPineItemContentDefinitions.content_by_id(
			OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID
		)
	)
	_assert_eq(sword.item_definition().item_definition_id, canonical_sword.item_definition_id, "NPC loadout uses canonical long-sword ID")
	_assert_eq(sword.own_weight, canonical_sword.own_weight, "NPC loadout projects canonical weight 7000")
	_assert_eq(sword.weapon_damage, canonical_sword.weapon_damage, "NPC loadout projects canonical damage 25")
	_assert_eq(sword.weapon_definition().skill_type, &"sword", "long sword skill type")
	_assert_false(sword.weapon_definition().can_wield_as_secondary, "long sword has no SECONDARY flag")
	_assert_eq(
		sword.legacy_source_paths(),
		["d/oldpine/obj/long_sword.c", "d/oldpine/npc/obj/long_sword.c"],
		"long sword keeps both source paths",
	)
	_assert_eq(
		OldPineNpcDefinitions.silver_content().currency_definition().value_for_amount(6),
		600,
		"six silver has LPC-derived value 600",
	)
	var spawn: NpcSpawnDefinition = OldPineSpawnDefinitions.pine1_tall_bandit_spawn()
	_assert_eq(spawn.zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "tall bandit spawns in Pine Entrance")
	_assert_eq(spawn.quantity, 1, "exactly one tall bandit")
	_assert_eq(spawn.legacy_source_room_path, "d/oldpine/pine1.c", "tall spawn traces pine1")


func _test_persisted_maze_geometry_and_zone_transitions(tree: SceneTree) -> void:
	# Synchronize scene cleanup before beginning collision-backed movement proofs.
	await tree.physics_frame
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	_assert_true(controller != null, "Old Pine scene instantiates for maze geometry")
	if controller == null:
		return
	var initial_npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	_assert_eq(initial_npcs.size(), 5, "scene ready constructs all NPCs before Area signals")
	_assert_eq(initial_npcs[3].world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Tall starts logically in Pine Entrance before Area signals")
	await tree.physics_frame
	_assert_eq(_count_tree_nodes(controller), 180, "fixed Pine Maze plus Fat spawn/body hierarchy persists")
	_assert_rect_shape(controller, "Terrain/Boundaries/PineMazeBounds/Top", Vector2(2100, 30), "maze north boundary")
	_assert_rect_shape(controller, "Terrain/Boundaries/PineMazeBounds/Bottom", Vector2(2100, 30), "maze south boundary")
	_assert_rect_shape(controller, "Terrain/Boundaries/PineMazeObstacles/CentralIsland", Vector2(300, 240), "central loop island")
	_assert_rect_shape(controller, "Terrain/Boundaries/PineMazeObstacles/DeadEndWest", Vector2(40, 220), "dead-end west wall")
	_assert_rect_shape(controller, "Terrain/Boundaries/PineMazeObstacles/DeadEndEast", Vector2(40, 220), "dead-end east wall")
	for zone_name: String in ["PineEntranceZone", "PineDeepZone", "PineCliffEdgeZone"]:
		var zone: Area2D = controller.get_node_or_null("Zones/%s" % zone_name) as Area2D
		_assert_true(zone != null, "%s persists" % zone_name)
		_assert_eq(zone.get_signal_connection_list("body_entered").size(), 1, "%s has one typed zone adapter" % zone_name)
	var entrance_zone: Area2D = controller.get_node("Zones/PineEntranceZone") as Area2D
	var deep_zone: Area2D = controller.get_node("Zones/PineDeepZone") as Area2D
	var cliff_zone: Area2D = controller.get_node("Zones/PineCliffEdgeZone") as Area2D
	var entrance_shape: RectangleShape2D = (entrance_zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var deep_shape: RectangleShape2D = (deep_zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var cliff_shape: RectangleShape2D = (cliff_zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_assert_eq(entrance_zone.position.x - entrance_shape.size.x / 2.0, -600.0, "Pine Entrance begins at exact threshold")
	_assert_eq(entrance_zone.position.x - entrance_shape.size.x / 2.0, deep_zone.position.x + deep_shape.size.x / 2.0, "Entrance and Deep meet without gap or interior overlap")
	_assert_eq(deep_zone.position.x - deep_shape.size.x / 2.0, cliff_zone.position.x + cliff_shape.size.x / 2.0, "Deep and Cliff Edge meet without gap or interior overlap")
	_assert_eq(cliff_zone.position.x - cliff_shape.size.x / 2.0, -2100.0, "Pine Cliff Edge reaches implemented west boundary")
	_assert_eq([entrance_shape.size.y, deep_shape.size.y, cliff_shape.size.y], [600.0, 600.0, 600.0], "all Pine zone interiors cover the traversable vertical span")
	_assert_eq((controller.get_node("MazeEvidence/PineThresholdRoute") as Marker2D).position, Vector2(-40, 300), "continuous threshold marker")
	_assert_eq((controller.get_node("MazeEvidence/PineLoopNorth") as Marker2D).position, Vector2(-1050, 120), "north loop marker")
	_assert_eq((controller.get_node("MazeEvidence/PineLoopSouth") as Marker2D).position, Vector2(-1050, 480), "south loop marker")
	_assert_eq((controller.get_node("MazeEvidence/PineDeadEnd") as Marker2D).position, Vector2(-705, 50), "safe dead-end marker")
	_assert_eq((controller.get_node("MazeEvidence/KeepFutureBoundary") as Marker2D).position, Vector2(-520, 60), "future Keep boundary marker")
	_assert_eq((controller.get_node("MazeEvidence/CliffFutureBoundary") as Marker2D).position, Vector2(-2040, 300), "future cliff boundary marker")

	controller.tall_bandit_body.global_position = Vector2(-300, 210)
	controller.player_body.global_position = Vector2(80, 300)
	await tree.physics_frame
	var player_state: CharacterState = controller.player_runtime().state
	var resources_before: Array[int] = [
		player_state.essence.current,
		player_state.vitality.current,
		player_state.spirit.current,
	]
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-550, 350)), "old outdoor connects directly into Pine Entrance")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "physical threshold enters Pine Entrance")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-650, 350)), "physical Entrance-to-Deep seam is traversable")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Entrance-to-Deep seam assigns Deep without a gap")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-550, 350)), "physical Deep-to-Entrance seam is traversable")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Deep-to-Entrance seam assigns Entrance deterministically")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-850, 480)), "south route reaches loop approach")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1050, 480)), "south branch passes central island")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "physical route enters Pine Deep")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1350, 480)), "south branch clears central island")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1450, 300)), "south branch exits Pine Deep")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-2040, 300)), "fixed route reaches cliff edge")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "physical route enters Pine Cliff Edge")
	var cliff_collision: KinematicCollision2D = controller.player_body.move_and_collide(Vector2(-100, 0))
	_assert_true(cliff_collision != null, "future cliff descent remains physically closed")
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "blocked cliff edge retains Pine Cliff Edge location")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1450, 300)), "cliff edge route returns east")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1350, 480)), "return route reaches south loop")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-850, 480)), "return route crosses Pine Deep")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-550, 350)), "return route reaches Pine Entrance")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(80, 300)), "return route reaches original Outdoor")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "physical return restores existing Outdoor location")
	_assert_eq(
		[
			player_state.essence.current,
			player_state.vitality.current,
			player_state.spirit.current,
		],
		resources_before,
		"physical zone traversal does not mutate CharacterState resources",
	)

	controller.player_body.global_position = Vector2(-520, 300)
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-520, 60)), "future Keep boundary remains physically reachable")
	var keep_collision: KinematicCollision2D = controller.player_body.move_and_collide(Vector2(0, -100))
	_assert_true(keep_collision != null, "future Keep route remains physically closed")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "blocked Keep path retains Pine Entrance location")

	controller.player_body.global_position = Vector2(-705, 300)
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-705, 50)), "safe dead-end corridor is traversable")
	_assert_true(controller.player_body.move_and_collide(Vector2(0, -100)) != null, "dead end terminates at maze boundary")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-705, 300)), "dead end is safely escapable")

	controller.player_body.global_position = Vector2(-850, 300)
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-850, 120)), "north loop approach is traversable")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1050, 120)), "north branch passes central island")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1350, 120)), "north branch reaches west side of island")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1450, 300)), "loop turns around island west side")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1350, 480)), "loop reaches alternate south branch")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-1050, 480)), "alternate south branch passes island")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-850, 480)), "alternate branch returns east of island")
	_assert_true(_walk_without_collision(controller.player_body, Vector2(-850, 300)), "physical route closes the loop at its original junction without teleport")

	controller._on_pine_entrance_body_entered(controller.player_body)
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Pine Entrance has stable combat location")
	controller._on_pine_deep_body_entered(controller.player_body)
	_assert_eq(controller.player_runtime().world_location().combat_location_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Pine Deep has stable combat location")
	controller._on_pine_cliff_edge_body_entered(controller.player_body)
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, "Pine Cliff Edge has stable zone identity")
	controller.queue_free()
	await tree.process_frame


func _test_tall_bandit_runtime_aggression_death_loot_and_equip(
	tree: SceneTree,
) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	_assert_eq(npcs.size(), 5, "runtime owns three scouts, Tall, and Fat")
	var tall: NpcRuntimeState = npcs[3]
	_assert_eq(tall.definition_id, OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID, "fourth runtime is exact tall bandit")
	_assert_eq(tall.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "tall runtime starts in Pine Entrance")
	_assert_eq(controller.tall_bandit_body.global_position, (controller.get_node("SpawnPoints/Pine1TallBanditSpawn") as Marker2D).global_position, "tall body starts at exact marker")
	_assert_eq(controller.tall_bandit_body.get_signal_connection_list("selection_requested").size(), 1, "tall selection signal persists once")
	var presence: Area2D = controller.get_node("Characters/TallBandit/AggressionPresence") as Area2D
	_assert_eq(presence.get_signal_connection_list("body_entered").size(), 1, "tall aggression enter signal persists once")
	_assert_eq(presence.get_signal_connection_list("body_exited").size(), 1, "tall aggression exit signal persists once")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	controller.tall_bandit_body._input_event(controller.get_viewport(), click, 0)
	_assert_eq(controller.selected_character_id(), tall.character_id, "clicking Tall selects exact Tall identity")
	controller.bandit_bodies[0]._input_event(controller.get_viewport(), click, 0)
	_assert_eq(controller.selected_character_id(), npcs[0].character_id, "clicking existing bandit still selects exact original identity")
	var map_local_timer_count: int = 0
	for child: Node in controller.get_children():
		if child is Timer:
			map_local_timer_count += 1
	_assert_eq(map_local_timer_count, 1, "scene retains one direct map-local OpportunityTimer")

	var long_sword: ItemInstance = _item_by_definition(tall.loadout_items(), OldPineNpcDefinitions.LONG_SWORD_ITEM_ID)
	var silver: ItemInstance = _item_by_definition(tall.loadout_items(), OldPineNpcDefinitions.SILVER_ITEM_ID)
	_assert_true(long_sword != null, "tall runtime owns long sword instance")
	_assert_true(silver != null, "tall runtime owns silver instance")
	var tall_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		tall.character_id,
	)
	_assert_true(controller.inventory_state().is_direct_child(long_sword.item_instance_id, tall_endpoint), "tall long sword is direct owned inventory")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, tall_endpoint), "tall silver is direct owned inventory")
	_assert_true(controller.item_instance_index().resolve(long_sword.item_instance_id) != null, "tall long sword is present in map-local item index")
	_assert_true(controller.item_instance_index().resolve(silver.item_instance_id) != null, "tall silver is present in map-local item index")
	_assert_ne(long_sword.item_instance_id, controller.player_runtime().state.equipment.primary_weapon().instance_id, "tall and player long swords have distinct live identities")
	_assert_eq(tall.character_state.equipment.primary_weapon().instance_id, long_sword.item_instance_id, "tall long sword starts in primary hand")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 6, "tall silver stack amount is six")
	_assert_eq(controller.inventory_state().own_weight(silver.item_instance_id), 222, "six silver weighs 6 * 37")
	var participants: Array[CombatSliceCharacterBinding] = controller._build_participants()
	_assert_eq(participants.size(), 6, "combat projection includes player and five NPCs")
	_assert_eq(participants[4].content.projected_apply_damage(participants[4].state.equipment.primary_weapon()), 25, "tall combat projection uses long-sword damage 25")
	var tall_primary: EquippedWeaponRef = tall.character_state.equipment.primary_weapon()
	_assert_true(tall.character_state.equipment.unwield(tall_primary.instance_id).succeeded, "audit can remove Tall current primary through Equipment authority")
	var unequipped_binding: CombatSliceCharacterBinding = _binding_for(controller._build_participants(), tall.character_id)
	_assert_eq(unequipped_binding.content.projected_apply_damage(unequipped_binding.state.equipment.primary_weapon()), 0, "authored Tall profile does not override live unequipped state")
	_assert_true(tall.character_state.equipment.wield(tall_primary, false).succeeded, "audit restores Tall primary before combat")

	var random: CountingMaximumCombatRandomSource = CountingMaximumCombatRandomSource.new()
	controller.configure_combat_random_source(random)
	_assert_true(controller.process_cadence_tick().is_empty(), "idle Tall creates no combat opportunity")
	_assert_eq(random.calls, 0, "idle Tall consumes zero Combat RNG")
	controller.set_process(false)
	controller.player_body.global_position = controller.tall_bandit_body.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.aggression_adapter().has_pending(tall.character_id), "physical tall-bandit presence queues aggression")
	_assert_eq(random.calls, 0, "presence and aggression decision consume no Combat RNG")
	controller._on_pine_deep_body_entered(controller.player_body)
	_assert_true(controller.process_pending_aggression().is_empty(), "escape before deferred recheck starts no combat")
	_assert_false(tall.relationship.is_fighting(), "escaped tall presence creates no relationship")
	controller._on_pine_entrance_body_entered(controller.player_body)
	controller._on_tall_bandit_presence_exited(controller.player_body)
	controller._on_tall_bandit_presence_entered(controller.player_body)
	var starts: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(starts.size(), 1, "one tall aggressor establishes combat")
	_assert_eq(starts[0].initiator_id, tall.character_id, "aggression initiator is exact tall bandit")
	_assert_true(tall.relationship.has_lethal_target(controller.player_runtime().character_id), "tall bandit gains reciprocal lethal relation")
	_assert_eq(random.calls, 0, "relationship initiation remains RNG-free")
	controller._on_pine_deep_body_entered(controller.player_body)
	controller.process_cadence_tick()
	_assert_false(controller.player_runtime().relationship.has_opponent(tall.character_id), "Pine zone change uses closed opponent cleanup")
	_assert_false(tall.relationship.has_opponent(controller.player_runtime().character_id), "Pine zone cleanup is reciprocal")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(tall.character_id), "Pine zone cleanup preserves lethal marker")
	_assert_eq(random.calls, 0, "different-location cleanup consumes no Combat RNG")
	controller._on_pine_entrance_body_entered(controller.player_body)
	controller._on_tall_bandit_presence_exited(controller.player_body)
	controller._on_tall_bandit_presence_entered(controller.player_body)
	_assert_eq(controller.process_pending_aggression().size(), 1, "returning to Pine Entrance permits authored aggression again")
	controller.opportunity_timer.stop()
	var attack_random: CountingAttackFavoringRandomSource = (
		CountingAttackFavoringRandomSource.new()
	)
	controller.configure_combat_random_source(attack_random)
	controller.player_runtime().busy.start_busy(1)
	var actual_tall_apply_damage: int = -1
	for _opportunity: int in range(6):
		for result: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if result.actor_id != tall.character_id:
				continue
			var forward: CombatSingleAttackExecutionResult = result.forward_result
			if forward == null or forward.ordinary_attack_result == null:
				continue
			var ordinary: CombatOrdinaryAttackResult = forward.ordinary_attack_result
			if ordinary.has_base_result and ordinary.base_result != null:
				actual_tall_apply_damage = ordinary.base_result.calculation.base_apply_damage
				break
		if actual_tall_apply_damage >= 0:
			break
	_assert_eq(actual_tall_apply_damage, 25, "actual tall attack calculation receives long-sword damage 25")
	_assert_true(attack_random.calls > 0, "actual tall combat consumes only Combat RNG")

	controller.opportunity_timer.stop()
	controller.configure_combat_random_source(CountingMaximumCombatRandomSource.new())
	controller.player_runtime().busy.start_busy(1)
	tall.character_state.attributes.strength = 30
	controller.player_body.global_position = Vector2(-1300, 300)
	controller.tall_bandit_body.global_position = Vector2(-1300, 300)
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "player live authority reaches Pine Deep before Tall death")
	_assert_eq(tall.world_location().zone_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Tall live authority reaches Pine Deep before death")
	var current_participants: Array[CombatSliceCharacterBinding] = controller._build_participants()
	var tall_binding: CombatSliceCharacterBinding = _binding_for(current_participants, tall.character_id)
	var killer_binding: CombatSliceCharacterBinding = _binding_for(current_participants, controller.player_runtime().character_id)
	var death_destination: InventoryTransferDestination = controller._world_destination_for(tall.character_id)
	var death_context: DeathContext = controller._death_context_for(tall_binding, killer_binding, death_destination)
	_assert_eq(death_context.victim_display_name, "土匪", "Tall death context uses authored display name")
	_assert_eq(death_context.victim_gender, CharacterState.GENDER_MALE, "Tall death context uses current gender")
	_assert_eq(death_context.victim_age, 27, "Tall death context uses authored age")
	_assert_eq(death_context.victim_body_own_weight, CharacterDerivedValues.human_weight(30), "Tall death context derives current body weight")
	_assert_eq(death_context.victim_maximum_encumbrance, CharacterDerivedValues.maximum_encumbrance(30), "Tall death context derives current encumbrance")
	_assert_true(death_context.victim_owner.equipment_state == tall.character_state.equipment, "Tall death context uses current EquipmentState")
	_assert_true(death_context.victim_owner.armor_state == tall.armor, "Tall death context uses current ArmorState")
	_assert_eq(death_context.victim_environment.endpoint.kind, ContainmentEndpoint.Kind.WORLD, "Tall death destination is a WORLD endpoint")
	_assert_eq(death_context.victim_environment.endpoint.endpoint_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Tall death context reads current Pine location")
	tall.character_state.vitality.current = -1
	controller.process_cadence_tick()
	for _tick: int in range(24):
		if tall.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		controller.process_cadence_tick()
	_assert_eq(tall.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "existing combat lifecycle kills tall bandit")
	_assert_false(tall.exists_in_map, "dead tall bandit leaves active map membership")
	_assert_false(controller.tall_bandit_body.visible, "dead tall body is hidden")
	_assert_eq(controller.corpse_states().size(), 1, "tall death creates one corpse")
	var corpse: CorpseState = controller.corpse_states()[0]
	_assert_eq(corpse.victim_display_name, "土匪", "Tall corpse preserves authored display name")
	_assert_eq(corpse.victim_gender, CharacterState.GENDER_MALE, "Tall corpse preserves authored gender")
	_assert_eq(corpse.victim_age, 27, "Tall corpse preserves authored age")
	_assert_eq(controller.inventory_state().direct_parent(corpse.corpse_item_instance_id).endpoint_id, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID, "Tall corpse is placed at current Pine Deep endpoint")
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.ITEM,
		corpse.corpse_item_instance_id,
	)
	_assert_true(controller.inventory_state().is_direct_child(long_sword.item_instance_id, corpse_endpoint), "long sword transfers into corpse")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, corpse_endpoint), "silver transfers into corpse")
	_assert_true(tall.character_state.equipment.is_primary_hand_empty(), "death transfer unwields the same Tall long sword")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 6, "corpse preserves silver amount six")
	var corpse_view: CombatSliceCorpseView = controller.corpse_view_for(corpse.corpse_item_instance_id)
	controller.player_body.global_position = corpse_view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "tall corpse is selectable")
	_assert_true(controller.open_selected_loot(), "tall corpse opens through existing loot UI boundary")
	var loot_rows: Array[WorldItemRowProjection] = controller.hud.loot_rows()
	var long_row: WorldItemRowProjection = _loot_row(loot_rows, long_sword.item_instance_id)
	var silver_row: WorldItemRowProjection = _loot_row(loot_rows, silver.item_instance_id)
	_assert_true(long_row != null and long_row.display_name == "长剑", "Loot projects authored long sword")
	_assert_true(silver_row != null and silver_row.display_name == "银子", "Loot projects authored silver")
	_assert_eq(silver_row.amount, 6, "Loot projects silver amount six")
	var existing_silver: ItemInstance = _add_player_silver(controller, &"phase9b1.existing-player-silver", 3)
	_assert_true(existing_silver != null, "merge regression creates prior player silver amount three")
	var player_primary_before_take: StringName = (
		controller.player_runtime().state.equipment.primary_weapon().instance_id
	)
	_assert_true(controller.take_selected_loot_item(long_sword.item_instance_id).succeeded, "player takes exact long sword instance")
	_assert_eq(controller.player_runtime().state.equipment.primary_weapon().instance_id, player_primary_before_take, "Take does not auto-wield Tall long sword")
	var silver_take: CorpseLootTransferResult = controller.take_selected_loot_item(silver.item_instance_id)
	_assert_eq(silver_take.outcome, CorpseLootTransferResult.Outcome.COMPLETED_WITH_MERGE, "Tall silver uses existing corpse Take merge path")
	_assert_eq(silver_take.resulting_item_instance_id, silver.item_instance_id, "incoming Tall silver is closed-semantics survivor")
	var player_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		OldPineOutdoorController.PLAYER_ID,
	)
	_assert_true(controller.inventory_state().is_direct_child(long_sword.item_instance_id, player_endpoint), "looted long sword becomes player direct inventory")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, player_endpoint), "looted silver becomes player direct inventory")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 9, "existing silver three plus Tall silver six merges to nine")
	_assert_eq(controller.inventory_state().own_weight(silver.item_instance_id), 333, "merged silver weight remains 9 * 37")
	_assert_eq(OldPineNpcDefinitions.silver_content().currency_definition().value_for_amount(9), 900, "merged silver value remains 9 * 100")
	_assert_false(controller.inventory_state().is_registered(existing_silver.item_instance_id), "absorbed prior player silver is no longer live")
	_assert_true(controller.open_player_inventory(), "existing Inventory UI opens after Tall loot")
	_assert_eq(_definition_row_count(controller.hud.inventory_rows(), OldPineNpcDefinitions.LONG_SWORD_ITEM_ID), 2, "two live long swords remain separate inventory rows")
	var original_primary: EquippedWeaponRef = controller.player_runtime().state.equipment.primary_weapon()
	_assert_true(controller.unwield_player_item(original_primary.instance_id).succeeded, "existing equipment action unwields original long sword")
	_assert_true(controller.wield_player_item(long_sword.item_instance_id).succeeded, "existing equipment action wields looted long sword")
	_assert_eq(controller.player_runtime().state.equipment.primary_weapon().instance_id, long_sword.item_instance_id, "looted instance is current primary authority")
	var player_binding: CombatSliceCharacterBinding = controller._build_participants()[0]
	_assert_eq(player_binding.content.projected_apply_damage(player_binding.state.equipment.primary_weapon()), 25, "looted long sword preserves combat content projection")
	var old_tall_state: CharacterState = tall.character_state
	var old_long_id: StringName = long_sword.item_instance_id
	var old_silver_id: StringName = silver.item_instance_id
	controller.queue_free()
	await tree.process_frame
	var fresh: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	var fresh_tall: NpcRuntimeState = fresh.npc_runtimes()[3]
	_assert_true(fresh_tall.character_state != old_tall_state, "fresh scene owns new tall CharacterState")
	_assert_eq(fresh_tall.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "fresh tall returns to Pine Entrance")
	_assert_eq(fresh.corpse_states().size(), 0, "fresh scene clears tall corpse")
	_assert_true(fresh.selected_interaction_target() == null, "fresh scene clears stale interaction target")
	_assert_false(fresh.player_runtime().relationship.is_fighting(), "fresh scene clears player relationships")
	for fresh_npc: NpcRuntimeState in fresh.npc_runtimes():
		_assert_false(fresh_npc.relationship.is_fighting(), "fresh scene clears every NPC relationship")
	var fresh_long: ItemInstance = _item_by_definition(fresh_tall.loadout_items(), OldPineNpcDefinitions.LONG_SWORD_ITEM_ID)
	var fresh_silver: ItemInstance = _item_by_definition(fresh_tall.loadout_items(), OldPineNpcDefinitions.SILVER_ITEM_ID)
	_assert_ne(fresh_long.item_instance_id, old_long_id, "fresh tall owns new long-sword instance")
	_assert_ne(fresh_silver.item_instance_id, old_silver_id, "fresh tall owns new silver instance")
	_assert_eq(fresh.stack_collection().stack_state(fresh_silver.item_instance_id).amount, 6, "fresh tall restores silver amount six")
	_assert_eq(fresh.tall_bandit_body.get_signal_connection_list("selection_requested").size(), 1, "fresh tall has no duplicate selection signal")
	_assert_eq((fresh.get_node("Characters/TallBandit/AggressionPresence") as Area2D).get_signal_connection_list("body_entered").size(), 1, "fresh tall has no duplicate presence signal")
	fresh.queue_free()
	await tree.process_frame


func _test_partial_tall_death_is_not_lootable(tree: SceneTree) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	var tall: NpcRuntimeState = controller.npc_runtimes()[3]
	controller._on_pine_entrance_body_entered(controller.player_body)
	_assert_true(controller.select_npc(tall.character_id), "partial Tall fixture selects exact Tall")
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "partial Tall fixture starts lethal combat")
	controller.opportunity_timer.stop()
	var unknown: ItemInstance = ItemInstance.new(
		&"phase9b1.partial-tall-unknown",
		&"phase9b1.partial-tall-unknown-definition",
	)
	_assert_true(controller.inventory_state().register_item(unknown, 1), "partial Tall fixture registers uncovered direct item")
	_assert_true(InventoryTransferService.new().transfer(
		controller.inventory_state(),
		unknown.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, tall.character_id),
			true,
			true,
			tall.maximum_encumbrance,
		),
	).succeeded, "partial Tall fixture places uncovered item in Tall inventory")
	controller.player_runtime().busy.start_busy(1)
	tall.character_state.vitality.current = -1
	tall.character_state.vitality.effective = -1
	controller.process_cadence_tick()
	var lifecycles: Array[CombatSliceLifecycleResult] = controller.last_lifecycle_results()
	_assert_eq(lifecycles.size(), 1, "partial Tall death produces one lifecycle result")
	_assert_eq(lifecycles[0].outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_BLOCKED, "uncovered Tall item preserves typed partial death")
	_assert_eq(controller.corpse_states().size(), 1, "partial Tall corpse authority is retained")
	var corpse: CorpseState = controller.corpse_states()[0]
	_assert_false(controller.item_instance_index().has_snapshot(corpse.corpse_item_instance_id), "partial Tall corpse is absent from interaction index")
	_assert_true(controller.corpse_view_for(corpse.corpse_item_instance_id) == null, "partial Tall corpse has no loot-range binding")
	_assert_false(controller.select_corpse(corpse.corpse_item_instance_id), "partial Tall corpse cannot become loot target")
	controller.queue_free()
	await tree.process_frame


func _instantiate_scene(tree: SceneTree) -> OldPineOutdoorController:
	var session: OldPineWorldSessionController = (
		SceneType.instantiate() as OldPineWorldSessionController
	)
	if session == null:
		return null
	session.deterministic_npc_seed = true
	session.npc_seed = 9011
	session.deterministic_combat_seed = true
	session.combat_seed = 9012
	tree.root.add_child(session)
	return session.outdoor_map()


func _walk_without_collision(body: CharacterBody2D, target: Vector2) -> bool:
	for _step: int in range(1000):
		var remaining: Vector2 = target - body.global_position
		if remaining.length() <= 0.5:
			return true
		var motion: Vector2 = remaining.limit_length(5.0)
		if body.move_and_collide(motion) != null:
			return false
	return false


func _binding_for(
	participants: Array[CombatSliceCharacterBinding],
	character_id: StringName,
) -> CombatSliceCharacterBinding:
	for participant: CombatSliceCharacterBinding in participants:
		if participant.character_id == character_id:
			return participant
	return null


func _add_player_silver(
	controller: OldPineOutdoorController,
	instance_id: StringName,
	amount: int,
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new(
		instance_id,
		OldPineNpcDefinitions.SILVER_ITEM_ID,
	)
	if not controller.inventory_state().register_item(item, 0):
		return null
	if not controller.item_instance_index().register_snapshot(item):
		return null
	var registration: CombinedStackAmountResult = CombinedStackService.register_stack(
		controller.stack_collection(),
		controller.inventory_state(),
		item,
		OldPineNpcDefinitions.silver_content().stack_definition(),
		amount,
	)
	if not registration.accepted:
		return null
	var result: InventoryTransferResult = InventoryTransferService.new().transfer(
		controller.inventory_state(),
		item.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.CHARACTER,
				OldPineOutdoorController.PLAYER_ID,
			),
			true,
			true,
			controller.player_runtime().maximum_encumbrance,
		),
	)
	return item if result.succeeded else null


func _definition_row_count(
	rows: Array[PlayerInventoryRowProjection],
	definition_id: StringName,
) -> int:
	var count: int = 0
	for row: PlayerInventoryRowProjection in rows:
		if row.item_definition_id == definition_id:
			count += 1
	return count


func _item_by_definition(
	items: Array[ItemInstance],
	definition_id: StringName,
) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _loot_row(
	rows: Array[WorldItemRowProjection],
	item_instance_id: StringName,
) -> WorldItemRowProjection:
	for row: WorldItemRowProjection in rows:
		if row.item_instance_id == item_instance_id:
			return row
	return null


func _skill_pairs(skills: Array[NpcSkillLevelDefinition]) -> Array[Array]:
	var result: Array[Array] = []
	for skill: NpcSkillLevelDefinition in skills:
		result.append([skill.skill_id, skill.raw_level])
	return result


func _assert_rect_shape(
	root: Node,
	path: String,
	expected_size: Vector2,
	label: String,
) -> void:
	var collision: CollisionShape2D = root.get_node_or_null(path) as CollisionShape2D
	_assert_true(collision != null, "%s persists" % label)
	if collision == null:
		return
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	_assert_true(rectangle != null, "%s uses RectangleShape2D" % label)
	if rectangle != null:
		_assert_eq(rectangle.size, expected_size, "%s exact size" % label)


func _count_tree_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_tree_nodes(child)
	return count


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("Expected true: %s" % label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _assert_ne(actual: Variant, unexpected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("%s: values unexpectedly equal: %s" % [label, actual])
