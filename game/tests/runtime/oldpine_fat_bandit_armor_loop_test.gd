extends RefCounted

const SceneType := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")

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
	await _test_live_fat_authority_and_stable_multi_aggression(tree)
	await _test_death_loot_player_wear_remove_and_reset(tree)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_live_fat_authority_and_stable_multi_aggression(tree: SceneTree) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "real Old Pine scene instantiates")
	if controller == null:
		return
	controller.set_process(false)
	var npcs: Array[NpcRuntimeState] = controller.npc_runtimes()
	_assert_eq(npcs.size(), 5, "map-local order contains three scouts, Tall, Fat")
	_assert_eq(npcs[3].definition_id, OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID, "Tall remains fourth")
	var fat: NpcRuntimeState = npcs[4]
	_assert_eq(fat.definition_id, OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID, "Fat is explicit fifth runtime")
	_assert_eq(fat.world_location().zone_id, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, "Fat runtime starts in Pine Entrance")
	_assert_eq(controller.fat_bandit_body.global_position, (controller.get_node("SpawnPoints/Pine1FatBanditSpawn") as Marker2D).global_position, "Fat body uses stable authored marker")
	_assert_ne(controller.fat_bandit_body.global_position, controller.tall_bandit_body.global_position, "Tall and Fat are not stacked")
	var entrance_obstacle: CollisionShape2D = controller.get_node(
		"Terrain/Boundaries/PineMazeObstacles/EntranceNorth"
	) as CollisionShape2D
	var obstacle_shape: RectangleShape2D = entrance_obstacle.shape as RectangleShape2D
	var fat_shape: RectangleShape2D = (
		(controller.get_node("Characters/FatBandit/CollisionShape2D") as CollisionShape2D).shape
		as RectangleShape2D
	)
	var obstacle_delta: Vector2 = (
		controller.fat_bandit_body.global_position - entrance_obstacle.global_position
	)
	_assert_true(
		absf(obstacle_delta.x) > (obstacle_shape.size.x + fat_shape.size.x) / 2.0
		or absf(obstacle_delta.y) > (obstacle_shape.size.y + fat_shape.size.y) / 2.0,
		"Fat spawn body is outside EntranceNorth collision",
	)
	var tall_presence: Area2D = controller.get_node(
		"Characters/TallBandit/AggressionPresence"
	) as Area2D
	var fat_presence: Area2D = controller.get_node(
		"Characters/FatBandit/AggressionPresence"
	) as Area2D
	var tall_radius: float = (
		(tall_presence.get_node("CollisionShape2D") as CollisionShape2D).shape
		as CircleShape2D
	).radius
	var fat_radius: float = (
		(fat_presence.get_node("CollisionShape2D") as CollisionShape2D).shape
		as CircleShape2D
	).radius
	_assert_true(
		controller.tall_bandit_body.global_position.distance_to(
			controller.fat_bandit_body.global_position
		) < tall_radius + fat_radius,
		"actual Tall and Fat Presence circles overlap",
	)
	var items: Array[ItemInstance] = fat.loadout_items()
	_assert_eq(items.size(), 3, "Fat owns sword, leather, one silver stack")
	var sword: ItemInstance = _item_by_definition(items, OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID)
	var leather: ItemInstance = _item_by_definition(items, OldPineNpcDefinitions.LEATHER_ITEM_ID)
	var silver: ItemInstance = _item_by_definition(items, OldPineNpcDefinitions.SILVER_ITEM_ID)
	var fat_owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, fat.character_id)
	_assert_eq(fat.character_state.equipment.primary_weapon().instance_id, sword.item_instance_id, "Fat live primary is exact short sword")
	_assert_true(controller.inventory_state().is_direct_child(leather.item_instance_id, fat_owner), "worn leather remains Fat direct inventory")
	_assert_eq(fat.armor.item_instance_id_in_slot(&"cloth"), leather.item_instance_id, "Fat live cloth slot uses same item identity")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 5, "Fat has one silver amount-five stack")
	_assert_eq(controller.inventory_state().own_weight(silver.item_instance_id), 185, "Fat silver weight is 185")

	var participants: Array[CombatSliceCharacterBinding] = controller._build_participants()
	var player_binding: CombatSliceCharacterBinding = _binding_for(participants, controller.player_runtime().character_id)
	var fat_binding: CombatSliceCharacterBinding = _binding_for(participants, fat.character_id)
	var fat_as_defender: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(
		player_binding,
		fat_binding,
		player_binding.content.attack_template_for(player_binding.state.equipment.primary_weapon()),
	)
	var fat_as_attacker: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(
		fat_binding,
		player_binding,
		fat_binding.content.attack_template_for(fat_binding.state.equipment.primary_weapon()),
	)
	_assert_eq(fat_as_defender.defender.armor, 5, "current Combat defender input sees leather armor +5")
	_assert_eq(fat_as_defender.defender.effective_dodge_skill_level, 3, "current Combat input preserves effective raw-half 5 plus dodge -2")
	_assert_eq(fat_as_attacker.attacker.projected_apply_damage, 15, "Fat ordinary attack input uses short-sword damage 15")
	_assert_true(fat.armor.remove(leather.item_instance_id).succeeded, "test removes Fat leather through current ArmorState")
	var next_fat: CombatSliceCharacterBinding = _binding_for(controller._build_participants(), fat.character_id)
	var next_without_armor: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(
		_binding_for(controller._build_participants(), controller.player_runtime().character_id),
		next_fat,
		player_binding.content.attack_template_for(player_binding.state.equipment.primary_weapon()),
	)
	_assert_eq(next_without_armor.defender.armor, 0, "next Combat input drops removed armor")
	_assert_eq(next_without_armor.defender.effective_dodge_skill_level, 5, "next Combat input returns to effective raw-half dodge 5")
	_assert_true(ArmorService.wear(fat.armor, controller.inventory_state(), fat_owner, leather, OldPineItemContentDefinitions.content_by_id(leather.item_definition_id).armor_definition()).succeeded, "test restores Fat leather through ArmorService")

	controller._on_pine_entrance_body_entered(controller.player_body)
	tall_presence.body_entered.emit(controller.player_body)
	fat_presence.body_entered.emit(controller.player_body)
	_assert_eq(controller.aggression_adapter().pending_count(), 2, "actual overlapping Presence Areas queue Tall and Fat once each")
	var starts: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(starts.size(), 2, "overlapping Tall and Fat presences initiate both eligible aggressors")
	if starts.size() == 2:
		_assert_eq(starts[0].initiator_id, npcs[3].character_id, "multi-aggressor order follows map-local Tall insertion")
		_assert_eq(starts[1].initiator_id, fat.character_id, "multi-aggressor order follows map-local Fat insertion")
	_assert_true(npcs[3].relationship.has_lethal_target(controller.player_runtime().character_id), "Tall relationship established")
	_assert_true(fat.relationship.has_lethal_target(controller.player_runtime().character_id), "Fat relationship established independently")
	_assert_eq(controller.opportunity_timer.get_signal_connection_list("timeout").size(), 1, "one OpportunityTimer remains")
	controller.queue_free()
	await tree.process_frame


func _test_death_loot_player_wear_remove_and_reset(tree: SceneTree) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	controller.set_process(false)
	var fat: NpcRuntimeState = controller.npc_runtimes()[4]
	var fat_state: CharacterState = fat.character_state
	var items: Array[ItemInstance] = fat.loadout_items()
	var sword: ItemInstance = _item_by_definition(items, OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID)
	var leather: ItemInstance = _item_by_definition(items, OldPineNpcDefinitions.LEATHER_ITEM_ID)
	var silver: ItemInstance = _item_by_definition(items, OldPineNpcDefinitions.SILVER_ITEM_ID)
	controller.player_body.global_position = (
		controller.fat_bandit_body.global_position + Vector2(50, 50)
	)
	await tree.physics_frame
	await tree.physics_frame
	var starts: Array[CombatSliceInitiationResult] = controller.process_pending_aggression()
	_assert_eq(starts.size(), 1, "physical Fat presence produces one deferred aggression initiation")
	if starts.size() == 1:
		_assert_eq(starts[0].initiator_id, fat.character_id, "physical Fat presence initiates exact Fat runtime")
	else:
		controller._on_fat_bandit_presence_entered(controller.player_body)
		starts = controller.process_pending_aggression()
	controller.opportunity_timer.stop()
	var live_fat_binding: CombatSliceCharacterBinding = _binding_for(
		controller._build_participants(),
		fat.character_id,
	)
	_assert_eq(
		live_fat_binding.content.projected_apply_damage(
			live_fat_binding.state.equipment.primary_weapon()
		),
		15,
		"live Fat participant still projects short-sword damage before its opportunity",
	)
	controller.player_runtime().busy.start_busy(1)
	var fat_attack_random: CountingAttackFavoringRandomSource = (
		CountingAttackFavoringRandomSource.new()
	)
	controller.configure_combat_random_source(fat_attack_random)
	var fat_attack_calculation: CombatAttackCalculation = null
	for _tick: int in range(8):
		for result: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if result.actor_id == fat.character_id:
				fat_attack_calculation = _ordinary_calculation(result)
		if fat_attack_calculation != null:
			break
	_assert_true(fat_attack_calculation != null, "physical Fat aggression reaches actual ordinary attack")
	if fat_attack_calculation != null:
		_assert_eq(fat_attack_calculation.base_apply_damage, 15, "actual Fat attack calculation uses short-sword damage 15")
	_assert_true(fat_attack_random.calls > 0, "actual Fat combat consumes Combat RNG")
	_assert_eq(fat.armor.item_instance_id_in_slot(&"cloth"), leather.item_instance_id, "Fat leather remains worn after its ordinary attack")

	fat.busy.start_busy(4)
	var player_attack_random: CountingMaximumCombatRandomSource = (
		CountingMaximumCombatRandomSource.new()
	)
	controller.configure_combat_random_source(player_attack_random)
	var fat_defense_calculation: CombatAttackCalculation = null
	for _tick: int in range(8):
		for result: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if result.actor_id != controller.player_runtime().character_id:
				continue
			var forward: CombatSingleAttackExecutionResult = result.forward_result
			if forward != null and forward.victim_id == fat.character_id:
				fat_defense_calculation = _ordinary_calculation(result)
		if fat_defense_calculation != null:
			break
	_assert_true(player_attack_random.calls > 0, "actual player attack consumes Combat RNG")
	_assert_true(fat_defense_calculation != null, "actual player attack resolves against live Fat defender")
	if fat_defense_calculation != null:
		_assert_eq(fat_defense_calculation.armor, 5, "actual ordinary attack consumes Fat live armor +5")

	var lifecycle_random: CountingMaximumCombatRandomSource = CountingMaximumCombatRandomSource.new()
	controller.configure_combat_random_source(lifecycle_random)
	controller.player_runtime().busy.start_busy(1)
	fat.character_state.attributes.strength = 30
	fat.character_state.vitality.current = -1
	fat.character_state.vitality.effective = -1
	controller.process_cadence_tick()
	for _tick: int in range(24):
		if fat.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		controller.process_cadence_tick()
	await tree.process_frame
	_assert_eq(fat.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "Fat dies through existing outer lifecycle")
	_assert_false(fat.exists_in_map, "dead Fat leaves active map authority")
	_assert_false(controller.fat_bandit_body.visible, "dead Fat body is hidden")
	_assert_eq(controller.corpse_states().size(), 1, "Fat death creates one normal corpse")
	var corpse: CorpseState = controller.corpse_states()[0]
	var corpse_endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)
	_assert_true(controller.inventory_state().is_direct_child(sword.item_instance_id, corpse_endpoint), "Fat short sword moves to corpse")
	_assert_true(controller.inventory_state().is_direct_child(leather.item_instance_id, corpse_endpoint), "Fat leather moves to corpse")
	_assert_true(controller.inventory_state().is_direct_child(silver.item_instance_id, corpse_endpoint), "Fat silver moves to corpse")
	_assert_true(fat.character_state.equipment.is_primary_hand_empty(), "death transfer unwields short sword")
	_assert_false(fat.armor.is_worn(leather.item_instance_id), "death transfer removes victim ArmorState")
	_assert_eq(corpse.decay_stage, CorpseState.Stage.FRESH, "Fat corpse begins at stage zero")
	_assert_eq(corpse.worn_item_in_slot(&"cloth"), leather.item_instance_id, "fresh corpse preserves leather worn projection")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 5, "corpse preserves silver amount five")

	var corpse_view: CombatSliceCorpseView = controller.corpse_view_for(corpse.corpse_item_instance_id)
	controller.player_body.global_position = corpse_view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "Fat corpse is selectable")
	_assert_true(controller.open_selected_loot(), "Fat corpse opens existing Loot panel")
	var loot_rows: Array[WorldItemRowProjection] = controller.hud.loot_rows()
	_assert_eq(loot_rows.size(), 3, "Loot projects sword, leather, silver")
	var leather_loot: WorldItemRowProjection = _loot_row(loot_rows, leather.item_instance_id)
	_assert_eq(leather_loot.display_name, "皮衣", "Loot resolves canonical leather content")
	_assert_eq(leather_loot.description, "皮衣(Leather)。\n", "Loot resolves leather default long")
	_assert_eq(_loot_row(loot_rows, silver.item_instance_id).amount, 5, "Loot projects silver amount five")
	var existing_silver: ItemInstance = _add_player_silver(controller, &"phase9b2.existing-silver", 3)
	while controller.player_runtime().busy.is_busy():
		controller.player_runtime().busy.advance()
	var capacity_filler: ItemInstance = _add_player_capacity_filler(
		controller,
		&"phase9b2.capacity-filler",
		5999,
	)
	var failed_take: CorpseLootTransferResult = controller.take_selected_loot_item(
		leather.item_instance_id
	)
	_assert_eq(failed_take.outcome, CorpseLootTransferResult.Outcome.TRANSFER_FAILED, "leather Take reports destination capacity failure")
	_assert_true(failed_take.corpse_transfer_result.corpse_worn_released, "fresh leather projection releases before failed transfer")
	_assert_eq(corpse.worn_item_in_slot(&"cloth"), &"", "failed Take does not restore corpse worn projection")
	_assert_true(controller.inventory_state().is_direct_child(leather.item_instance_id, corpse_endpoint), "failed Take leaves leather corpse-contained")
	_assert_false(controller.player_runtime().busy.is_busy(), "failed leather Take creates no busy")
	_assert_true(InventoryTransferService.new().transfer(
		controller.inventory_state(),
		capacity_filler.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID),
			true,
			true,
			OldPineOutdoorController.WORLD_CAPACITY,
		),
	).succeeded, "fixture releases player capacity without touching leather")
	var take_leather: CorpseLootTransferResult = controller.take_selected_loot_item(leather.item_instance_id)
	_assert_true(take_leather.succeeded, "single Take transfers leather")
	_assert_false(take_leather.corpse_transfer_result.corpse_worn_released, "second Take observes already-released corpse projection")
	_assert_true(controller.inventory_state().is_direct_child(leather.item_instance_id, _player_endpoint()), "same leather instance becomes player direct inventory")
	_assert_false(controller.player_runtime().armor.is_worn(leather.item_instance_id), "Take does not auto-Wear")
	var take_silver: CorpseLootTransferResult = controller.take_selected_loot_item(silver.item_instance_id)
	_assert_eq(take_silver.outcome, CorpseLootTransferResult.Outcome.COMPLETED_WITH_MERGE, "Fat silver uses closed incoming-stack merge")
	_assert_eq(take_silver.resulting_item_instance_id, silver.item_instance_id, "incoming Fat silver survives merge")
	_assert_eq(controller.stack_collection().stack_state(silver.item_instance_id).amount, 8, "silver 3 + 5 becomes amount eight")
	_assert_eq(controller.inventory_state().own_weight(silver.item_instance_id), 296, "merged silver weight is 8 * 37")
	_assert_eq(OldPineNpcDefinitions.silver_content().currency_definition().value_for_amount(8), 800, "merged silver value is 8 * 100")
	_assert_false(controller.inventory_state().is_registered(existing_silver.item_instance_id), "absorbed prior silver is destroyed by closed merge")

	_assert_true(controller.open_player_inventory(), "player Inventory opens after leather Take")
	var row: PlayerInventoryRowProjection = _inventory_row(controller.hud.inventory_rows(), leather.item_instance_id)
	_assert_eq(row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.NONE, "looted leather row starts NONE")
	_assert_true(row.can_wear and not row.can_remove, "looted leather offers Wear only")
	_assert_true(controller.inspect_player_item(leather.item_instance_id), "leather Inspect resolves exact live row")
	var inspection: String = controller.hud.inventory_panel.inspection_display()
	for expected: String in ["皮衣", "皮衣(Leather)", "Armor slot: cloth", "Armor: +5", "Dodge: -2", "Equipped: NONE"]:
		_assert_true(inspection.contains(expected), "Inspect contains %s" % expected)
	var surviving: NpcRuntimeState = controller.npc_runtimes()[3]
	_assert_true(controller.select_npc(surviving.character_id), "same live world selects Tall for post-loot combat")
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "post-loot combat relationship starts through world controller")
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(4)
	var wear_busy_before: int = controller.player_runtime().busy.busy_value
	var wear_random: CountingMaximumCombatRandomSource = CountingMaximumCombatRandomSource.new()
	controller.configure_combat_random_source(wear_random)
	_assert_true(controller.wear_player_item(leather.item_instance_id).succeeded, "player Wear uses runtime adapter and ArmorService")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(surviving.character_id), "Wear preserves active lethal relationship")
	_assert_true(controller.player_runtime().relationship.is_fighting(), "Wear preserves fighting state")
	_assert_true(controller.opportunity_timer.is_stopped(), "Wear does not restart stopped OpportunityTimer")
	_assert_eq(controller.player_runtime().busy.busy_value, wear_busy_before, "Wear does not mutate existing busy")
	_assert_eq(wear_random.calls, 0, "Inspect, projection and Wear consume zero Combat RNG")
	row = _inventory_row(controller.hud.inventory_rows(), leather.item_instance_id)
	_assert_eq(row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.WORN, "post-Wear row derives WORN")
	_assert_true(row.can_remove and not row.can_wear, "post-Wear row offers Remove only")
	_assert_dynamic_row_connections(controller.hud.inventory_panel)

	var player_binding: CombatSliceCharacterBinding = _binding_for(controller._build_participants(), controller.player_runtime().character_id)
	var surviving_binding: CombatSliceCharacterBinding = _binding_for(controller._build_participants(), surviving.character_id)
	var worn_input: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(
		surviving_binding,
		player_binding,
		surviving_binding.content.attack_template_for(surviving_binding.state.equipment.primary_weapon()),
	)
	_assert_eq(worn_input.defender.armor, 5, "next world Combat input sees player leather armor +5")
	_assert_eq(worn_input.defender.effective_dodge_skill_level, 3, "player effective raw-half dodge five plus leather -2 remains exact")
	var worn_attack_random: CountingMaximumCombatRandomSource = (
		CountingMaximumCombatRandomSource.new()
	)
	controller.configure_combat_random_source(worn_attack_random)
	var worn_attack_calculation: CombatAttackCalculation = null
	for _tick: int in range(8):
		for result: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if result.actor_id == surviving.character_id:
				worn_attack_calculation = _ordinary_calculation(result)
		if worn_attack_calculation != null:
			break
	_assert_true(worn_attack_calculation != null, "actual Tall opportunity attacks worn player")
	if worn_attack_calculation != null:
		_assert_eq(worn_attack_calculation.armor, 5, "actual combat calculation observes current player armor +5")
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(4)
	var remove_busy_before: int = controller.player_runtime().busy.busy_value
	var remove_random: CountingMaximumCombatRandomSource = CountingMaximumCombatRandomSource.new()
	controller.configure_combat_random_source(remove_random)
	_assert_true(controller.remove_player_item(leather.item_instance_id).succeeded, "player Remove uses narrow runtime adapter")
	_assert_true(controller.player_runtime().relationship.has_lethal_target(surviving.character_id), "Remove preserves active lethal relationship")
	_assert_true(controller.player_runtime().relationship.is_fighting(), "Remove preserves fighting state")
	_assert_true(controller.opportunity_timer.is_stopped(), "Remove does not restart stopped OpportunityTimer")
	_assert_eq(controller.player_runtime().busy.busy_value, remove_busy_before, "Remove does not mutate existing busy")
	_assert_eq(remove_random.calls, 0, "Remove and projection consume zero Combat RNG")
	_assert_true(controller.inventory_state().is_direct_child(leather.item_instance_id, _player_endpoint()), "Remove leaves leather player-owned")
	var next_player: CombatSliceCharacterBinding = _binding_for(controller._build_participants(), controller.player_runtime().character_id)
	var removed_input: CombatAttackInput = CombatSliceProjectionBuilder.build_attack_input(
		_binding_for(controller._build_participants(), surviving.character_id),
		next_player,
		surviving_binding.content.attack_template_for(surviving_binding.state.equipment.primary_weapon()),
	)
	_assert_eq(removed_input.defender.armor, 0, "next world Combat input drops removed player armor")
	_assert_eq(removed_input.defender.effective_dodge_skill_level, 5, "next world Combat input returns to effective raw-half dodge five")
	var removed_attack_random: CountingMaximumCombatRandomSource = (
		CountingMaximumCombatRandomSource.new()
	)
	controller.configure_combat_random_source(removed_attack_random)
	var removed_attack_calculation: CombatAttackCalculation = null
	for _tick: int in range(8):
		for result: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if result.actor_id == surviving.character_id:
				removed_attack_calculation = _ordinary_calculation(result)
		if removed_attack_calculation != null:
			break
	_assert_true(removed_attack_calculation != null, "actual next Tall opportunity attacks removed player")
	if removed_attack_calculation != null:
		_assert_eq(removed_attack_calculation.armor, 0, "actual next combat calculation observes removed armor immediately")
	row = _inventory_row(controller.hud.inventory_rows(), leather.item_instance_id)
	_assert_eq(row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.NONE, "post-Remove row returns to NONE")
	_assert_true(controller.select_npc(surviving.character_id), "same world continues with surviving NPC")
	_assert_dynamic_row_connections(controller.hud.inventory_panel)

	controller.queue_free()
	await tree.process_frame
	var fresh: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_eq(_count_tree_nodes(fresh), 225, "persisted scene retains audited hierarchy after Phase 10C1A Reset removal")
	_assert_eq(fresh.npc_runtimes().size(), 5, "fresh scene restores exactly three scouts, Tall, Fat")
	_assert_eq(
		[
			fresh.npc_runtimes()[0].definition_id,
			fresh.npc_runtimes()[1].definition_id,
			fresh.npc_runtimes()[2].definition_id,
			fresh.npc_runtimes()[3].definition_id,
			fresh.npc_runtimes()[4].definition_id,
		],
		[
			OldPineNpcDefinitions.BANDIT_DEFINITION_ID,
			OldPineNpcDefinitions.BANDIT_DEFINITION_ID,
			OldPineNpcDefinitions.BANDIT_DEFINITION_ID,
			OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID,
			OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID,
		],
		"fresh map-local NPC order remains explicit",
	)
	var fresh_fat: NpcRuntimeState = fresh.npc_runtimes()[4]
	var fresh_leather: ItemInstance = _item_by_definition(fresh_fat.loadout_items(), OldPineNpcDefinitions.LEATHER_ITEM_ID)
	var fresh_sword: ItemInstance = _item_by_definition(fresh_fat.loadout_items(), OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID)
	var fresh_silver: ItemInstance = _item_by_definition(fresh_fat.loadout_items(), OldPineNpcDefinitions.SILVER_ITEM_ID)
	_assert_true(fresh_fat.character_state != fat_state, "fresh scene owns new Fat CharacterState")
	_assert_ne(fresh_leather.item_instance_id, leather.item_instance_id, "fresh scene owns new leather instance")
	_assert_ne(fresh_sword.item_instance_id, sword.item_instance_id, "fresh scene owns new Fat short-sword instance")
	_assert_ne(fresh_silver.item_instance_id, silver.item_instance_id, "fresh scene owns new Fat silver instance")
	_assert_eq(fresh_fat.character_state.equipment.primary_weapon().instance_id, fresh_sword.item_instance_id, "fresh Fat restores exact short sword primary")
	_assert_eq(fresh_fat.armor.item_instance_id_in_slot(&"cloth"), fresh_leather.item_instance_id, "fresh Fat restores worn leather baseline")
	_assert_eq(fresh.stack_collection().stack_state(fresh_silver.item_instance_id).amount, 5, "fresh Fat restores silver amount five")
	_assert_eq(fresh.corpse_states().size(), 0, "fresh scene has no corpses")
	_assert_true(fresh.player_runtime().armor.occupied_slots().is_empty(), "fresh player has no leather equipped")
	_assert_true(_item_by_definition(_player_items(fresh), OldPineNpcDefinitions.LEATHER_ITEM_ID) == null, "fresh player owns no leather")
	_assert_true(fresh.selected_interaction_target() == null, "fresh scene has no stale target")
	_assert_false(fresh.hud.inventory_is_open(), "fresh scene closes Inventory panel")
	_assert_false(fresh.hud.loot_is_open(), "fresh scene closes Loot panel")
	_assert_eq(fresh.opportunity_timer.get_signal_connection_list("timeout").size(), 1, "fresh scene retains one OpportunityTimer signal")
	_assert_eq(fresh.fat_bandit_body.get_signal_connection_list("selection_requested").size(), 1, "fresh Fat selection signal is unique")
	_assert_eq((fresh.get_node("Characters/FatBandit/AggressionPresence") as Area2D).get_signal_connection_list("body_entered").size(), 1, "fresh Fat presence signal is unique")
	_assert_eq((fresh.get_node("Characters/FatBandit/AggressionPresence") as Area2D).get_signal_connection_list("body_exited").size(), 1, "fresh Fat exit signal is unique")
	_assert_eq(fresh.hud.inventory_panel.get_signal_connection_list("wear_requested").size(), 1, "fresh Inventory Wear signal is unique")
	_assert_eq(fresh.hud.inventory_panel.get_signal_connection_list("remove_requested").size(), 1, "fresh Inventory Remove signal is unique")
	fresh.queue_free()
	await tree.process_frame


func _instantiate_scene(tree: SceneTree) -> OldPineOutdoorController:
	var session: OldPineWorldSessionController = (
		SceneType.instantiate() as OldPineWorldSessionController
	)
	if session == null:
		return null
	session.deterministic_npc_seed = true
	session.npc_seed = 9022
	session.deterministic_combat_seed = true
	session.combat_seed = 9023
	tree.root.add_child(session)
	return session.outdoor_map()


func _binding_for(bindings: Array[CombatSliceCharacterBinding], character_id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.character_id == character_id:
			return binding
	return null


func _item_by_definition(items: Array[ItemInstance], definition_id: StringName) -> ItemInstance:
	for item: ItemInstance in items:
		if item.item_definition_id == definition_id:
			return item
	return null


func _loot_row(rows: Array[WorldItemRowProjection], item_id: StringName) -> WorldItemRowProjection:
	for row: WorldItemRowProjection in rows:
		if row.item_instance_id == item_id:
			return row
	return null


func _inventory_row(rows: Array[PlayerInventoryRowProjection], item_id: StringName) -> PlayerInventoryRowProjection:
	for row: PlayerInventoryRowProjection in rows:
		if row.item_instance_id == item_id:
			return row
	return null


func _add_player_silver(controller: OldPineOutdoorController, item_id: StringName, amount: int) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new(item_id, OldPineNpcDefinitions.SILVER_ITEM_ID)
	controller.inventory_state().register_item(item, 0)
	controller.item_instance_index().register_snapshot(item)
	CombinedStackService.register_stack(controller.stack_collection(), controller.inventory_state(), item, OldPineNpcDefinitions.silver_content().stack_definition(), amount)
	InventoryTransferService.new().transfer(
		controller.inventory_state(),
		item_id,
		InventoryTransferDestination.new(_player_endpoint(), true, true, controller.player_runtime().maximum_encumbrance),
	)
	return item


func _add_player_capacity_filler(
	controller: OldPineOutdoorController,
	item_id: StringName,
	remaining_capacity: int,
) -> ItemInstance:
	var endpoint: ContainmentEndpoint = _player_endpoint()
	var current_weight: int = controller.inventory_state().contents_weight(endpoint)
	var filler_weight: int = (
		controller.player_runtime().maximum_encumbrance
		- current_weight
		- remaining_capacity
	)
	var item: ItemInstance = ItemInstance.new(item_id, &"test:capacity-filler")
	controller.inventory_state().register_item(item, filler_weight)
	InventoryTransferService.new().transfer(
		controller.inventory_state(),
		item_id,
		InventoryTransferDestination.new(
			endpoint,
			true,
			true,
			controller.player_runtime().maximum_encumbrance,
		),
	)
	return item


func _ordinary_calculation(
	result: CombatSliceOpportunityResult,
) -> CombatAttackCalculation:
	if result == null or result.forward_result == null:
		return null
	var ordinary: CombatOrdinaryAttackResult = (
		result.forward_result.ordinary_attack_result
	)
	if ordinary == null or not ordinary.has_base_result or ordinary.base_result == null:
		return null
	return ordinary.base_result.calculation


func _assert_dynamic_row_connections(panel: PlayerInventoryPanel) -> void:
	for child: Node in panel.row_container.get_children():
		for row_child: Node in child.get_children():
			var button: Button = row_child as Button
			if button != null:
				_assert_eq(button.get_signal_connection_list("pressed").size(), 1, "dynamic Inventory action binds exact item once")


func _player_items(controller: OldPineOutdoorController) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item_id: StringName in controller.inventory_state().direct_children(
		_player_endpoint()
	):
		var item: ItemInstance = controller.item_instance_index().resolve(item_id)
		if item != null:
			result.append(item)
	return result


func _count_tree_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_tree_nodes(child)
	return count


func _player_endpoint() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, OldPineOutdoorController.PLAYER_ID)


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (actual=%s expected=%s)" % [label, actual, expected])


func _assert_ne(actual: Variant, unexpected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual == unexpected:
		_failures.append("%s (unexpected=%s)" % [label, unexpected])
