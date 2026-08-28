extends RefCounted

const SCENE_PATH: String = "res://scenes/world/oldpine/oldpine_outdoor.tscn"
const ScriptedRandomScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const ControllerType := preload(
	"res://runtime/world/oldpine_outdoor_controller.gd"
)
const SpawnMarkerType := preload(
	"res://runtime/world/world_spawn_marker_2d.gd"
)
const CharacterBodyType := preload(
	"res://runtime/world/world_character_body_2d.gd"
)
const NpcRandomType := preload(
	"res://runtime/npcs/godot_npc_initialization_random_source.gd"
)

class MaximumCombatRandomSource extends CombatRandomSource:
	var _calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		_calls += 1
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

	func call_count() -> int:
		return _calls

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_random_boundaries()
	_test_main_scene_configuration()
	await _test_scene_spawn_and_authored_data(tree)
	await _test_projection_authority_and_committed_status(tree)
	await _test_zone_movement_and_same_location(tree)
	await _test_selection_inspect_attack_and_no_aggression(tree)
	await _test_blocked_death_remains_partial(tree)
	await _test_lifecycle_death_corpse_and_continued_map(tree)
	await _test_fresh_scene_reset_boundary(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_random_boundaries() -> void:
	var left: NpcRandomType = (
		NpcRandomType.new(12345, true)
	)
	var right: NpcRandomType = (
		NpcRandomType.new(12345, true)
	)
	for bound: int in [1, 4, 21, 30]:
		var draw: int = left.next_below(bound)
		_assert_eq(draw, right.next_below(bound), "equal NPC seeds preserve deterministic stream")
		_assert_true(draw >= 0 and draw < bound, "NPC RNG honors exclusive bound")
	_assert_eq(left.next_below(0), -1, "NPC RNG rejects zero bound")
	_assert_eq(left.next_below(-1), -1, "NPC RNG rejects negative bound")
	_assert_true(
		left.get_script() != GodotCombatRandomSource.new(12345, true).get_script(),
		"NPC initialization and combat RNG adapters have distinct types",
	)


func _test_main_scene_configuration() -> void:
	var configured: String = String(
		ProjectSettings.get_setting("application/run/main_scene", "")
	)
	if configured.begins_with("uid://"):
		configured = ResourceUID.get_id_path(ResourceUID.text_to_id(configured))
	_assert_eq(configured, SCENE_PATH, "Old Pine is the persisted development main scene")


func _test_scene_spawn_and_authored_data(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	_assert_true(controller != null, "Old Pine scene loads and instantiates")
	if controller == null:
		return
	await tree.physics_frame
	_assert_true(controller.player_runtime() != null, "world player runtime initializes")
	_assert_eq(controller.npc_runtimes().size(), 3, "exactly three bandit runtimes initialize")
	_assert_eq(controller.map_character_state().ordered_active_characters().size(), 3, "map-local collection owns three active NPCs")
	_assert_eq(controller.opportunity_timer.wait_time, 1.0, "map cadence is exactly one second")
	_assert_false(controller.opportunity_timer.one_shot, "map cadence uses one repeating Timer")
	_assert_false(controller.opportunity_timer.autostart, "map cadence never autostarts")
	_assert_true(controller.opportunity_timer.is_stopped(), "passive authored bandits do not autostart cadence")
	_assert_eq(_count_tree_nodes(controller), 102, "persisted Old Pine hierarchy contains exactly 102 nodes")
	_assert_true(controller.hud != null, "world HUD initializes")
	_assert_true(controller.get_node_or_null("Terrain/Boundaries/WorldBounds/Top") is CollisionShape2D, "world top collision persists")
	_assert_true(controller.get_node_or_null("Terrain/Boundaries/ForestObstacles/TreeBarrierNorthWest") is CollisionShape2D, "forest obstacle collision persists")
	_assert_true((controller.get_node("Characters/Player/Camera2D") as Camera2D).enabled, "player Camera2D is active")
	for zone_name: String in ["CentralClearingZone", "SouthSlopeZone", "NorthApproachZone", "EastBridgeZone"]:
		var zone: Area2D = controller.get_node_or_null("Zones/%s" % zone_name) as Area2D
		_assert_true(zone != null, "%s persists" % zone_name)
		_assert_true(zone.get_node_or_null("CollisionShape2D") is CollisionShape2D, "%s has persistent collision" % zone_name)
		_assert_eq(zone.get_signal_connection_list("body_entered").size(), 1, "%s has one persistent adapter signal" % zone_name)
	var spawn: NpcSpawnDefinition = OldPineSpawnDefinitions.spath1_bandit_spawn()
	var point_ids: Array[StringName] = spawn.spawn_point_ids()
	var marker_names: Array[String] = ["Spath1Bandit01", "Spath1Bandit02", "Spath1Bandit03"]
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	var item_ids: Array[StringName] = []
	for index: int in range(3):
		var marker: SpawnMarkerType = controller.get_node(
			"SpawnPoints/%s" % marker_names[index]
		) as SpawnMarkerType
		_assert_eq(marker.spawn_point_id, point_ids[index], "ordered spawn ID resolves to exact persistent marker")
		_assert_eq(npcs[index].spawn_point_id, point_ids[index], "runtime spawn order matches definition order")
		_assert_eq(controller.bandit_bodies[index].global_position, marker.global_position, "bandit body starts at authored Marker2D")
		_assert_eq(npcs[index].definition_id, OldPineNpcDefinitions.BANDIT_DEFINITION_ID, "visible bandit resolves exact authored definition")
		_assert_eq(npcs[index].definition().display_name, "土匪探哨", "authored display name has no arena identity leak")
		_assert_eq(npcs[index].age, 19, "world runtime retains authored age")
		_assert_eq(npcs[index].character_state.gender, CharacterState.GENDER_MALE, "world runtime retains authored gender")
		_assert_eq(npcs[index].loadout_items().size(), 2, "each bandit owns sword and silver instance")
		for item: ItemInstance in npcs[index].loadout_items():
			_assert_false(item_ids.has(item.item_instance_id), "each bandit item instance ID is unique")
			item_ids.append(item.item_instance_id)
		_assert_eq(controller.bandit_bodies[index].get_signal_connection_list("selection_requested").size(), 1, "each bandit selection signal persists once")
	var description: String = npcs[0].definition().description
	_assert_eq(description, "这人满脸匪气，一付百无聊赖的模样，令人望而生厌。\n", "inspect description is exact bandit.c authored text")
	_assert_true(controller.npc_random_source() != controller.combat_random_source(), "NPC initialization and combat use distinct RNG instances")
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "player logical start is central clearing")
	_assert_eq(controller.player_body.global_position, (controller.get_node("SpawnPoints/PlayerStart") as Marker2D).global_position, "player physical start comes from Marker2D")
	controller.queue_free()
	await tree.process_frame


func _test_projection_authority_and_committed_status(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var participants: Array[CombatSliceCharacterBinding] = controller._build_participants()
	_assert_eq(participants.size(), 4, "current projection contains player plus three live bandits")
	var player_binding: CombatSliceCharacterBinding = participants[0]
	var player: WorldPlayerRuntimeState = controller.player_runtime()
	_assert_true(player_binding.state == player.state, "player projection aliases live CharacterState")
	_assert_true(player_binding.relationship == player.relationship, "player projection aliases live relationship")
	_assert_true(player_binding.busy == player.busy, "player projection aliases live busy state")
	_assert_true(player_binding.armor == player.armor, "player projection aliases live ArmorState")
	for index: int in range(3):
		var npc: NpcRuntimeState = controller.npc_runtimes()[index]
		var binding: CombatSliceCharacterBinding = participants[index + 1]
		_assert_true(binding.state == npc.character_state, "NPC projection aliases live CharacterState")
		_assert_true(binding.relationship == npc.relationship, "NPC projection aliases live relationship")
		_assert_true(binding.busy == npc.busy, "NPC projection aliases live busy state")
		_assert_true(binding.armor == npc.armor, "NPC projection aliases live ArmorState")
		var primary: EquippedWeaponRef = npc.character_state.equipment.primary_weapon()
		_assert_true(binding.content.is_verified_primary(primary), "bandit content verifies current equipped short sword")
		_assert_eq(binding.content.projected_apply_damage(primary), OldPineNpcDefinitions.SHORT_SWORD_DAMAGE, "bandit projection uses authored short-sword damage")
	var unequipped_npc: NpcRuntimeState = controller.npc_runtimes()[2]
	var removed_primary: EquippedWeaponRef = unequipped_npc.character_state.equipment.primary_weapon()
	_assert_true(unequipped_npc.character_state.equipment.unwield(removed_primary.instance_id).succeeded, "fixture unwields current bandit short sword")
	var unequipped_projection: Array[CombatSliceCharacterBinding] = controller._build_participants()
	var unequipped_binding: CombatSliceCharacterBinding = unequipped_projection[3]
	_assert_true(unequipped_npc.character_state.equipment.primary_weapon() == null, "live EquipmentState owns the unwield result")
	_assert_false(unequipped_binding.content.is_verified_primary(unequipped_npc.character_state.equipment.primary_weapon()), "authored definition cannot override missing live primary equipment")
	_assert_eq(unequipped_binding.content.projected_apply_damage(unequipped_npc.character_state.equipment.primary_weapon()), 0, "unwielded bandit injects no short-sword apply damage")
	var original_player_location: StringName = player_binding.location_id
	controller._on_south_slope_body_entered(controller.player_body)
	var refreshed: Array[CombatSliceCharacterBinding] = controller._build_participants()
	_assert_eq(player_binding.location_id, original_player_location, "old projection is an ephemeral snapshot")
	_assert_eq(refreshed[0].location_id, OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID, "fresh projection reads current world location")
	player.state.vitality.current = -1
	_assert_eq(player.state.life_threshold(), CharacterState.LifeThreshold.UNCONSCIOUS, "resource threshold evidence is unconscious")
	_assert_eq(player.life_status, CharacterRuntimeLifeStatus.Value.ACTIVE, "threshold evidence does not commit world status")
	var move_start: Vector2 = controller.player_body.position
	Input.action_press("move_right")
	controller.player_body._physics_process(1.0 / 30.0)
	Input.action_release("move_right")
	_assert_true(controller.player_body.position != move_start, "committed ACTIVE status still governs movement")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	move_start = controller.player_body.position
	Input.action_press("move_right")
	controller.player_body._physics_process(1.0 / 30.0)
	Input.action_release("move_right")
	_assert_eq(controller.player_body.position, move_start, "committed non-ACTIVE status blocks movement")
	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	victim.character_state.attributes.strength = 30
	controller._on_north_approach_body_entered(controller.bandit_bodies[0])
	participants = controller._build_participants()
	var victim_binding: CombatSliceCharacterBinding = participants[1]
	var destination: InventoryTransferDestination = controller._world_destination_for(victim.character_id)
	var context: DeathContext = controller._death_context_for(victim_binding, player_binding, destination)
	_assert_eq(context.victim_display_name, "土匪探哨", "death context uses authored bandit display name")
	_assert_eq(context.victim_gender, CharacterState.GENDER_MALE, "death context uses current gender")
	_assert_eq(context.victim_age, 19, "death context uses authored age")
	_assert_eq(context.victim_body_own_weight, CharacterDerivedValues.human_weight(30), "death context derives current body weight")
	_assert_eq(context.victim_maximum_encumbrance, CharacterDerivedValues.maximum_encumbrance(30), "death context derives current encumbrance")
	_assert_true(context.victim_owner.equipment_state == victim.character_state.equipment, "death context aliases current EquipmentState")
	_assert_true(context.victim_owner.armor_state == victim.armor, "death context aliases current ArmorState")
	_assert_eq(context.victim_environment.endpoint.endpoint_id, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID, "death context reads current logical world destination")
	var mismatched_context: DeathContext = DeathContext.new(
		victim.character_id,
		false,
		false,
		destination,
		ItemLifecycleOwnerContext.new(victim.character_id, EquipmentState.new(), victim.armor),
		"土匪探哨",
		CharacterState.GENDER_MALE,
		19,
		CharacterDerivedValues.human_weight(30),
		CharacterDerivedValues.maximum_encumbrance(30),
	)
	var rejected: CombatSliceDeathExecutionResult = CombatSliceDeathAdapter.new().execute(
		victim_binding,
		player_binding,
		controller.inventory_state(),
		controller.stack_collection(),
		&"audit.mismatched-corpse",
		destination,
		[],
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
		mismatched_context,
	)
	_assert_true(rejected.death_inventory_result == null, "world death override rejects a shadow EquipmentState authority")
	_assert_false(controller.inventory_state().is_registered(&"audit.mismatched-corpse"), "rejected death override mutates no inventory")
	controller.queue_free()
	await tree.process_frame


func _test_zone_movement_and_same_location(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var state: CharacterState = controller.player_runtime().state
	var vitality_before: Array[int] = [state.vitality.current, state.vitality.effective, state.vitality.maximum]
	var start_position: Vector2 = controller.player_body.position
	controller.player_body.position = Vector2(450.0, 585.0)
	await tree.physics_frame
	Input.action_press("move_down")
	for _frame: int in range(12):
		await tree.physics_frame
	Input.action_release("move_down")
	await tree.physics_frame
	_assert_true(controller.player_body.position != start_position, "CharacterBody2D moves continuously through physical space")
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID, "Area2D transition updates typed logical zone")
	_assert_eq(controller.player_runtime().world_location().combat_location_id, OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID, "zone supplies stable combat location ID")
	_assert_true(controller.player_runtime().state == state, "zone transition never replaces CharacterState authority")
	_assert_eq([state.vitality.current, state.vitality.effective, state.vitality.maximum], vitality_before, "zone transition does not mutate CharacterState resources")
	var target: NpcRuntimeState = controller.npc_runtimes()[1]
	_assert_true(controller.player_runtime().world_location().shares_combat_location(target.world_location()), "player and bandit share combat location in south slope")
	controller._on_central_clearing_body_entered(controller.player_body)
	_assert_false(controller.player_runtime().world_location().shares_combat_location(target.world_location()), "logical zone change makes same-location false without distance comparison")
	controller._on_south_slope_body_entered(controller.player_body)
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID, "touch-only zone transition works central to south")
	controller._on_central_clearing_body_entered(controller.player_body)
	_assert_eq(controller.player_runtime().world_location().zone_id, OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, "touch-only zone transition works south to central")
	var before_bounds: Vector2 = Vector2(100.0, 300.0)
	controller.player_body.position = before_bounds
	await tree.physics_frame
	Input.action_press("move_left")
	for _step: int in range(360):
		controller.player_body._physics_process(1.0 / 60.0)
	Input.action_release("move_left")
	_assert_true(controller.player_body.position.x >= 16.9, "world boundary collision keeps player in continuous map")
	controller.queue_free()
	await tree.process_frame


func _test_selection_inspect_attack_and_no_aggression(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var scripted: ScriptedCombatRandomSource = ScriptedRandomScript.new([0, 0, 0])
	controller.configure_combat_random_source(scripted)
	for _frame: int in range(4):
		await tree.process_frame
	_assert_true(controller.process_cadence_tick().is_empty(), "NPCs outside player presence execute no automatic aggression")
	_assert_eq(scripted.call_count(), 0, "three idle NPCs consume zero combat RNG")
	for npc: NpcRuntimeState in controller.npc_runtimes():
		_assert_false(npc.relationship.is_fighting(), "out-of-range bandit remains out of combat before explicit Attack")
	var bandit2: NpcRuntimeState = controller.npc_runtimes()[1]
	controller.player_body.global_position = Vector2(450.0, 700.0)
	controller.bandit_bodies[0].global_position = Vector2(600.0, 700.0)
	controller.bandit_bodies[1].global_position = Vector2(700.0, 700.0)
	controller.bandit_bodies[2].global_position = Vector2(800.0, 700.0)
	var camera: Camera2D = controller.get_node("Characters/Player/Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	await tree.physics_frame
	await tree.physics_frame
	await _click_body_through_viewport(controller.bandit_bodies[0], tree)
	_assert_eq(controller.selected_character_id(), controller.npc_runtimes()[0].character_id, "real picking selects bandit1")
	await _click_body_through_viewport(controller.bandit_bodies[2], tree)
	_assert_eq(controller.selected_character_id(), controller.npc_runtimes()[2].character_id, "real picking switches HUD target to bandit3")
	await _click_body_through_viewport(controller.bandit_bodies[1], tree)
	_assert_eq(controller.selected_character_id(), bandit2.character_id, "bandit body click selects exact second CharacterId")
	_assert_eq(controller.hud.selected_target_text(), "Selected: 土匪探哨", "HUD follows the current stable target")
	_assert_true(controller.inspect_selected(), "Inspect accepts selected live bandit")
	_assert_true(controller.hud.inspection_display().contains("土匪探哨"), "Inspect shows authored name")
	_assert_true(controller.hud.inspection_display().contains("满脸匪气"), "Inspect shows authored long description")
	_assert_eq(scripted.call_count(), 0, "Inspect consumes no combat RNG")
	for npc: NpcRuntimeState in controller.npc_runtimes():
		_assert_false(npc.relationship.is_fighting(), "Inspect mutates no combat relationship")
	controller._on_south_slope_body_entered(controller.player_body)
	var initiation: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(initiation.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "explicit Attack delegates to closed lethal initiation")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(bandit2.character_id), "player lethal relation targets selected bandit only")
	_assert_true(bandit2.relationship.has_lethal_target(controller.player_runtime().character_id), "selected bandit gains reciprocal lethal relation")
	_assert_false(controller.npc_runtimes()[0].relationship.is_fighting(), "bandit 1 remains idle")
	_assert_false(controller.npc_runtimes()[2].relationship.is_fighting(), "bandit 3 remains idle")
	_assert_eq(scripted.call_count(), 0, "Attack initiation executes no combat opportunity RNG")
	_assert_false(controller.opportunity_timer.is_stopped(), "successful explicit Attack starts one map cadence timer")
	controller.opportunity_timer.start(9.0)
	var repeated: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(repeated.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "repeated Attack remains idempotently accepted")
	_assert_true(controller.opportunity_timer.time_left > 8.0, "repeated Attack does not restart cadence timing")
	_assert_eq(controller.player_runtime().relationship.opponent_ids().size(), 1, "repeated Attack does not duplicate player opponent")
	_assert_eq(bandit2.relationship.opponent_ids().size(), 1, "repeated Attack does not duplicate NPC opponent")
	controller._on_central_clearing_body_entered(controller.player_body)
	var cleanup_results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(cleanup_results.size(), 2, "both fighting sides receive one cleanup opportunity after zone exit")
	_assert_false(controller.player_runtime().relationship.has_opponent(bandit2.character_id), "closed availability removes player opponent after zone exit")
	_assert_false(bandit2.relationship.has_opponent(controller.player_runtime().character_id), "closed availability removes reciprocal opponent after zone exit")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(bandit2.character_id), "zone cleanup preserves player lethal marker")
	_assert_true(bandit2.relationship.has_lethal_target(controller.player_runtime().character_id), "zone cleanup preserves reciprocal lethal marker")
	_assert_eq(scripted.call_count(), 0, "different-location cleanup consumes zero combat RNG")
	controller._on_south_slope_body_entered(controller.player_body)
	_assert_false(controller.player_runtime().relationship.is_fighting(), "returning to same zone does not invent combat restart")
	controller.opportunity_timer.stop()
	controller.queue_free()
	await tree.process_frame


func _test_blocked_death_remains_partial(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var victim: NpcRuntimeState = controller.npc_runtimes()[1]
	controller._on_south_slope_body_entered(controller.player_body)
	controller.select_npc(victim.character_id)
	controller.attack_selected()
	controller.opportunity_timer.stop()
	var unknown_item: ItemInstance = ItemInstance.new(&"audit.unknown-item", &"audit.unknown-definition")
	_assert_true(controller.inventory_state().register_item(unknown_item, 1), "partial-death fixture registers unknown direct item")
	var victim_destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, victim.character_id),
		true,
		true,
		victim.maximum_encumbrance,
	)
	_assert_true(InventoryTransferService.new().transfer(controller.inventory_state(), unknown_item.item_instance_id, victim_destination).succeeded, "partial-death fixture places unknown item in victim inventory")
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.vitality.current = -1
	victim.character_state.vitality.effective = -1
	controller.process_cadence_tick()
	var lifecycles: Array[CombatSliceLifecycleResult] = controller.last_lifecycle_results()
	_assert_eq(lifecycles.size(), 1, "blocked death produces one lifecycle result")
	if not lifecycles.is_empty():
		_assert_eq(lifecycles[0].outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_BLOCKED, "uncovered direct item blocks death inventory")
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.ACTIVE, "blocked death does not commit world DEAD")
	_assert_true(victim.exists_in_map, "blocked death does not commit world nonexistence")
	_assert_true(controller.bandit_bodies[1].visible, "blocked death keeps NPC body visible")
	_assert_true(controller.bandit_bodies[1].input_pickable, "blocked death keeps NPC body pickable")
	_assert_true(controller.lifecycle_is_pending(), "blocked death raises the closed scene-level lifecycle gate")
	var corpse_count: int = controller.corpse_states().size()
	_assert_true(controller.process_cadence_tick().is_empty(), "blocked lifecycle character is not restarted from the beginning")
	_assert_eq(controller.corpse_states().size(), corpse_count, "blocked lifecycle retry gate prevents duplicate corpse creation")
	controller.queue_free()
	await tree.process_frame


func _test_lifecycle_death_corpse_and_continued_map(tree: SceneTree) -> void:
	var controller: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var bandits: Array[NpcRuntimeState] = controller.npc_runtimes()
	var victim: NpcRuntimeState = bandits[1]
	var victim_body: CharacterBodyType = controller.bandit_bodies[1]
	victim_body.global_position += Vector2(24.0, -18.0)
	var death_position: Vector2 = victim_body.global_position
	var sword: ItemInstance = _item_with_definition(victim.loadout_items(), OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID)
	var silver: ItemInstance = _item_with_definition(victim.loadout_items(), OldPineNpcDefinitions.SILVER_ITEM_ID)
	controller._on_south_slope_body_entered(controller.player_body)
	controller.select_npc(victim.character_id)
	controller.attack_selected()
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.attributes.strength = 30
	victim.character_state.vitality.current = -1
	var first_tick: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
	_assert_eq(first_tick.size(), 2, "stable player then selected NPC opportunities ignore idle bandits")
	_assert_eq(controller.last_tick_order(), [controller.player_runtime().character_id, victim.character_id], "map cadence order is player then spawn-order fighting NPC")
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "threshold commits unconscious only on victim outer opportunity")
	_assert_true(victim.exists_in_map, "unconscious NPC remains world-present")
	var maximum: MaximumCombatRandomSource = MaximumCombatRandomSource.new()
	controller.configure_combat_random_source(maximum)
	var observed_quick: bool = false
	for _tick: int in range(24):
		if victim.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		for opportunity: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if opportunity.forward_result != null and opportunity.forward_result.attack_type == CombatAttackType.Value.QUICK:
				observed_quick = true
	_assert_true(observed_quick, "later closed combat opportunity executes QUICK against unconscious bandit")
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "repeated deterministic wounds reach committed bandit death")
	_assert_false(victim.exists_in_map, "dead bandit alone leaves active world runtime")
	_assert_false(victim_body.visible, "dead bandit body is hidden")
	_assert_false(victim_body.input_pickable, "dead bandit body is noninteractive")
	_assert_eq(controller.corpse_states().size(), 1, "one authoritative corpse state remains")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "one corpse view remains in world scene")
	if controller.corpse_states().is_empty() or controller.corpse_layer.get_child_count() == 0:
		controller.queue_free()
		await tree.process_frame
		return
	var corpse: CorpseState = controller.corpse_states()[0]
	var view: CombatSliceCorpseView = controller.corpse_layer.get_child(0) as CombatSliceCorpseView
	_assert_eq(view.global_position, death_position, "corpse view uses captured physical death Vector2")
	_assert_eq(corpse.maximum_contents_encumbrance, CharacterDerivedValues.maximum_encumbrance(30), "successful corpse uses death-time current encumbrance")
	_assert_eq(controller.inventory_state().own_weight(corpse.corpse_item_instance_id), CharacterDerivedValues.human_weight(30), "successful corpse uses death-time current body weight")
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)
	_assert_true(controller.inventory_state().is_direct_child(sword.item_instance_id, corpse_endpoint), "short sword transfers into corpse authority")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, corpse_endpoint), "silver transfers into corpse authority")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 3, "corpse silver preserves authored amount three")
	_assert_true(victim.character_state.equipment.are_both_hands_empty(), "death transfer unwields short sword through closed equipment authority")
	_assert_true(bandits[0].exists_in_map and bandits[2].exists_in_map, "other two bandits remain world-present")
	_assert_true(controller.is_inside_tree(), "NPC death does not reload or end map")
	_assert_true(controller.select_npc(bandits[2].character_id), "remaining bandit stays selectable")
	_assert_true(controller.process_cadence_tick().is_empty(), "dead bandit never respawns or re-enters future cadence")
	_assert_eq(controller.map_character_state().ordered_active_characters().size(), 2, "live map quantity naturally falls to two after death")
	controller._on_south_slope_body_entered(controller.player_body)
	controller.select_npc(bandits[0].character_id)
	var second_initiation: CombatSliceInitiationResult = controller.attack_selected()
	_assert_eq(second_initiation.outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "surviving second bandit can begin a new combat")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(bandits[0].character_id), "second combat targets the new selected bandit")
	controller.opportunity_timer.stop()
	var before_move: Vector2 = controller.player_body.position
	Input.action_press("move_right")
	controller.player_body._physics_process(1.0 / 30.0)
	Input.action_release("move_right")
	_assert_true(controller.player_body.position != before_move, "player can continue walking after NPC death")
	controller.queue_free()
	await tree.process_frame


func _test_fresh_scene_reset_boundary(tree: SceneTree) -> void:
	var first: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	var first_player_state: CharacterState = first.player_runtime().state
	var first_npc_state: CharacterState = first.npc_runtimes()[0].character_state
	var first_npc_random: NpcInitializationRandomSource = first.npc_random_source()
	var first_combat_random: CombatRandomSource = first.combat_random_source()
	var first_player_item_id: StringName = (
		first.player_runtime().state.equipment.primary_weapon().instance_id
	)
	var first_npc_item_ids: Array[StringName] = []
	for first_npc: NpcRuntimeState in first.npc_runtimes():
		for first_item: ItemInstance in first_npc.loadout_items():
			first_npc_item_ids.append(first_item.item_instance_id)
	first.select_npc(first.npc_runtimes()[0].character_id)
	first.queue_free()
	await tree.process_frame
	var reset: ControllerType = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(reset.player_runtime().state != first_player_state, "fresh scene owns fresh player CharacterState")
	_assert_true(reset.npc_runtimes()[0].character_state != first_npc_state, "fresh scene owns fresh NPC CharacterState")
	_assert_true(reset.npc_random_source() != first_npc_random, "fresh scene owns fresh NPC RNG")
	_assert_true(reset.combat_random_source() != first_combat_random, "fresh scene owns fresh combat RNG")
	_assert_true(
		reset.player_runtime().state.equipment.primary_weapon().instance_id
		!= first_player_item_id,
		"fresh scene owns a fresh player ItemInstance ID",
	)
	for reset_npc: NpcRuntimeState in reset.npc_runtimes():
		for reset_item: ItemInstance in reset_npc.loadout_items():
			_assert_false(
				first_npc_item_ids.has(reset_item.item_instance_id),
				"fresh scene owns fresh NPC ItemInstance IDs",
			)
	_assert_eq(reset.npc_runtimes().size(), 3, "fresh scene reconstructs exactly three bandits")
	_assert_eq(reset.corpse_states().size(), 0, "fresh scene contains no stale corpse authority")
	_assert_false(reset.player_runtime().relationship.is_fighting(), "fresh scene contains no stale player relation")
	for npc: NpcRuntimeState in reset.npc_runtimes():
		_assert_false(npc.relationship.is_fighting(), "fresh NPC contains no stale relationship")
	_assert_eq(reset.bandit_bodies[0].get_signal_connection_list("selection_requested").size(), 1, "fresh scene has no duplicate selection signals")
	_assert_eq(reset.opportunity_timer.get_signal_connection_list("timeout").size(), 1, "fresh scene has no duplicate cadence signals")
	reset.queue_free()
	await tree.process_frame


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


func _item_with_definition(
	items: Array[ItemInstance],
	definition_id: StringName,
) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _click_body_through_viewport(
	body: CharacterBodyType,
	tree: SceneTree,
) -> void:
	var viewport: Viewport = body.get_viewport()
	var screen_position: Vector2 = body.get_global_transform_with_canvas().origin
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


func _count_tree_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_tree_nodes(child)
	return count


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
