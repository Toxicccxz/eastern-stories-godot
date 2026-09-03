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
		## One-opportunity source order: opponent, courage, action, limb,
		## then dodge/parry/damage. Low opens the regular branch; high
		## passes dodge/parry without deriving any expected combat formula.
		return 0 if calls <= 4 else exclusive_upper_bound - 1

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_full_loot_inventory_equip_second_fight_loop(tree)
	await _test_stale_dynamic_rows_revalidate_live_authority(tree)
	await _test_weapon_switch_during_live_combat_and_unsupported_gate(tree)
	await _test_fresh_scene_reset_baseline(tree)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_full_loot_inventory_equip_second_fight_loop(
	tree: SceneTree,
) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "real Old Pine scene instantiates for full loot loop")
	if controller == null:
		return
	_assert_true(controller.find_children("ResetButton", "Button", true, false).is_empty(), "persisted Loot hierarchy reflects Phase 10C1A Reset removal")
	_assert_true(controller.hud.inventory_panel != null, "HUD owns one presentation-only Inventory panel")
	_assert_false(controller.hud.inventory_is_open(), "Inventory panel starts closed")
	_assert_false(controller.hud.loot_is_open(), "Loot panel starts closed")
	_assert_eq(controller.hud.inventory_button.get_signal_connection_list("pressed").size(), 1, "Inventory button has one persisted controller connection")
	_assert_eq(controller.hud.inventory_panel.inspect_requested.get_connections().size(), 1, "Inspect request has one typed controller connection")
	_assert_eq(controller.hud.inventory_panel.wield_requested.get_connections().size(), 1, "Wield request has one typed controller connection")
	_assert_eq(controller.hud.inventory_panel.unwield_requested.get_connections().size(), 1, "Unwield request has one typed controller connection")
	var panel: PlayerInventoryPanel = controller.hud.inventory_panel
	var viewport_size: Vector2 = controller.get_viewport_rect().size
	_assert_true(panel.position.x >= 0.0 and panel.position.y >= 0.0, "Inventory panel begins inside viewport")
	_assert_true(panel.position.x + panel.size.x <= viewport_size.x, "Inventory panel right edge stays visible")
	_assert_true(panel.position.y + panel.size.y <= viewport_size.y, "Inventory panel bottom edge stays visible")

	controller.hud.inventory_button.pressed.emit()
	_assert_true(controller.hud.inventory_is_open(), "Inventory button opens live panel")
	var fresh_rows: Array[PlayerInventoryRowProjection] = controller.hud.inventory_rows()
	_assert_eq(fresh_rows.size(), 1, "fresh scene inventory has one direct item")
	_assert_dynamic_row_connections(controller.hud.inventory_panel, 1)
	var long_id: StringName = fresh_rows[0].item_instance_id
	_assert_eq(fresh_rows[0].item_definition_id, OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID, "fresh direct item is prototype long sword")
	_assert_eq(fresh_rows[0].equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.PRIMARY, "fresh long sword is PRIMARY")
	var long_binding: CombatSliceCharacterBinding = controller._build_participants()[0]
	_assert_eq(long_binding.content.projected_apply_damage(long_binding.state.equipment.primary_weapon()), 25, "fresh world participant resolves long-sword damage 25")

	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	await _kill_bandit(controller, victim, tree)
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.DEAD, "first authored bandit dies through existing combat/lifecycle path")
	_assert_eq(controller.corpse_states().size(), 1, "first death creates one corpse authority")
	var corpse: CorpseState = controller.corpse_states()[0]
	var corpse_view: CombatSliceCorpseView = controller.corpse_view_for(
		corpse.corpse_item_instance_id
	)
	_assert_true(corpse_view != null, "DEATH_COMPLETE creates interactive corpse view")
	controller.player_body.global_position = corpse_view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "full loop selects exact corpse ITEM")
	_assert_true(controller.open_selected_loot(), "Open Loot validates live corpse and range")
	_assert_false(controller.hud.inventory_is_open(), "opening Loot closes Inventory panel")
	var loot_rows: Array[WorldItemRowProjection] = controller.hud.loot_rows()
	var short_id: StringName = _loot_id_for_definition(
		loot_rows, OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID
	)
	var silver_id: StringName = _loot_id_for_definition(
		loot_rows, OldPineItemContentDefinitions.SILVER_ITEM_ID
	)
	_assert_false(short_id.is_empty(), "corpse exposes exact short sword instance")
	_assert_false(silver_id.is_empty(), "corpse exposes exact silver instance")
	var operation_random: CountingAttackFavoringRandomSource = (
		CountingAttackFavoringRandomSource.new()
	)
	controller.configure_combat_random_source(operation_random)
	_assert_true(controller.take_selected_loot_item(short_id).succeeded, "Take transfers short sword to player")
	_assert_true(controller.open_player_inventory(), "Inventory can reopen while corpse selection remains current")
	_assert_true(_row_ids(controller.hud.inventory_rows()).has(short_id), "Inventory opened after Take immediately projects acquired short")
	_assert_true(controller.take_selected_loot_item(silver_id).succeeded, "Take transfers amount-three silver to player")
	_assert_true(_row_ids(controller.hud.inventory_rows()).has(silver_id), "successful Take refreshes an already-open Inventory panel")
	_assert_true(controller.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)).is_empty(), "corpse authority is Empty after both Take operations")
	_assert_true(controller.open_selected_loot(), "empty corpse can reopen Loot after live Inventory refresh proof")
	_assert_true(controller.hud.loot_rows().is_empty(), "reopened corpse panel renders Empty from authority")
	_assert_true(controller.inventory_state().is_direct_child(short_id, _player_endpoint()), "same short sword instance is player direct inventory")
	_assert_true(controller.inventory_state().is_direct_child(silver_id, _player_endpoint()), "same silver instance is player direct inventory")
	_assert_eq(operation_random.calls, 0, "Open/Take consume zero Combat RNG")

	controller.hud.inventory_button.pressed.emit()
	_assert_true(controller.hud.inventory_is_open(), "Inventory opens after loot")
	_assert_false(controller.hud.loot_is_open(), "opening Inventory closes Loot panel")
	var rows: Array[PlayerInventoryRowProjection] = controller.hud.inventory_rows()
	controller.open_player_inventory()
	controller.open_player_inventory()
	rows = controller.hud.inventory_rows()
	_assert_dynamic_row_connections(panel, 3)
	_assert_eq(
		_row_ids(rows),
		controller.inventory_state().direct_children(_player_endpoint()),
		"live inventory preserves authoritative stable direct-child order",
	)
	var projected_definitions: Array[StringName] = _definition_ids(rows)
	_assert_true(projected_definitions.has(OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID), "live inventory contains long sword")
	_assert_true(projected_definitions.has(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID), "live inventory contains short sword")
	_assert_true(projected_definitions.has(OldPineItemContentDefinitions.SILVER_ITEM_ID), "live inventory contains silver")
	var short_row: PlayerInventoryRowProjection = _inventory_row_for(rows, short_id)
	var silver_row: PlayerInventoryRowProjection = _inventory_row_for(rows, silver_id)
	_assert_eq(short_row.equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.NONE, "Take never auto-equips short sword")
	_assert_eq(silver_row.amount, 3, "Inventory reads current silver amount three")
	panel.inspect_requested.emit(short_id)
	_assert_true(panel.inspection_display().contains("短剑"), "typed Inspect renders authored short name")
	_assert_true(panel.inspection_display().contains("粗制滥造的短剑"), "typed Inspect renders authored short description")
	_assert_true(panel.inspection_display().contains("Skill: sword"), "typed Inspect renders sword category fact")
	_assert_true(panel.inspection_display().contains("Damage: 15"), "typed Inspect renders authored damage 15")
	_assert_eq(operation_random.calls, 0, "Inventory open and Inspect consume zero Combat RNG")

	panel.wield_requested.emit(short_id)
	var short_secondary: OldPineEquipmentInteractionResult = (
		controller.last_equipment_interaction()
	)
	_assert_eq(short_secondary.equipment_transition.outcome, EquipmentTransitionResult.Outcome.WIELDED_SECONDARY, "long primary plus Wield short produces SECONDARY")
	_assert_eq(controller.player_runtime().state.equipment.primary_weapon().instance_id, long_id, "long stays primary after short secondary Wield")
	_assert_eq(controller.player_runtime().state.equipment.secondary_weapon().instance_id, short_id, "short is exact secondary instance")
	panel.unwield_requested.emit(long_id)
	_assert_true(controller.player_runtime().state.equipment.primary_weapon() == null, "Unwield long leaves primary empty")
	_assert_eq(controller.player_runtime().state.equipment.secondary_weapon().instance_id, short_id, "secondary short is not promoted")
	var secondary_only_binding: CombatSliceCharacterBinding = controller._build_participants()[0]
	_assert_eq(controller.last_player_content_resolution().outcome, OldPineWeaponContentResolution.Outcome.UNARMED, "secondary-only world participant resolves unarmed")
	_assert_eq(secondary_only_binding.content.projected_apply_damage(null), 0, "secondary-only participant has zero weapon apply damage")
	panel.unwield_requested.emit(short_id)
	panel.wield_requested.emit(short_id)
	var short_primary: EquippedWeaponRef = (
		controller.player_runtime().state.equipment.primary_weapon()
	)
	_assert_eq(short_primary.instance_id, short_id, "explicit legal sequence makes looted short PRIMARY")
	_assert_true(controller.player_runtime().state.equipment.secondary_weapon() == null, "short-primary sequence leaves secondary empty")
	_assert_true(controller.inventory_state().is_direct_child(short_id, _player_endpoint()), "Wield/Unwield never change item parent")
	_assert_eq(operation_random.calls, 0, "Wield/Unwield/projection refresh consume zero Combat RNG")

	var short_binding: CombatSliceCharacterBinding = controller._build_participants()[0]
	_assert_eq(controller.last_player_content_resolution().outcome, OldPineWeaponContentResolution.Outcome.SHORT_SWORD, "fresh participant projection resolves current short primary")
	_assert_eq(short_binding.content.projected_apply_damage(short_primary), 15, "fresh participant projects current short damage 15")
	_assert_eq(long_binding.content.projected_apply_damage(long_binding.state.equipment.primary_weapon()), 0, "old binding does not become a mutable short profile")

	var second: NpcRuntimeState = controller.npc_runtimes()[1]
	_assert_true(second.exists_in_map, "second authored bandit survives first loot loop")
	## Full-suite scene ordering can deliver a later overlapping zone callback
	## after the corpse physics frames. Re-enter through the production zone
	## adapter immediately before initiation so the test proves combat content,
	## not an incidental Area2D notification order.
	controller._on_south_slope_body_entered(controller.player_body)
	_assert_true(controller.select_npc(second.character_id), "second bandit becomes current world target")
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "second fight starts through world combat initiation")
	controller.opportunity_timer.stop()
	var actual_apply_damage: int = -1
	for _tick: int in range(12):
		var results: Array[CombatSliceOpportunityResult] = controller.process_cadence_tick()
		for result: CombatSliceOpportunityResult in results:
			if result.actor_id != controller.player_runtime().character_id:
				continue
			var forward: CombatSingleAttackExecutionResult = result.forward_result
			if forward == null or forward.ordinary_attack_result == null:
				continue
			var ordinary: CombatOrdinaryAttackResult = forward.ordinary_attack_result
			if not ordinary.has_base_result or ordinary.base_result == null:
				continue
			actual_apply_damage = ordinary.base_result.calculation.base_apply_damage
			break
		if actual_apply_damage >= 0:
			break
	_assert_eq(actual_apply_damage, 15, "actual second-fight attack calculation receives short-sword apply damage 15")
	_assert_true(operation_random.calls > 0, "only actual second combat consumes Combat RNG")
	_assert_true(controller.is_inside_tree(), "world remains loaded after second fight opportunity")
	_assert_true(controller.npc_runtimes()[2].exists_in_map, "third bandit/world state continues")
	var npc_random_after_loop: int = controller.npc_random_source().next_below(1000)

	controller.queue_free()
	await tree.process_frame
	var comparison: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_eq(comparison.npc_random_source().next_below(1000), npc_random_after_loop, "inventory/equipment/combat path does not consume NPC initialization RNG")
	comparison.queue_free()
	await tree.process_frame


func _test_stale_dynamic_rows_revalidate_live_authority(
	tree: SceneTree,
) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	var short_id: StringName = &"audit:stale-short"
	_assert_true(
		_register_player_item(
			controller,
			short_id,
			OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
			3000,
		),
		"stale-row fixture registers one direct-owned short sword",
	)
	_assert_true(controller.open_player_inventory(), "stale-row fixture opens live Inventory")
	_assert_dynamic_row_connections(controller.hud.inventory_panel, 2)
	var stale_wield_button: Button = _row_action_button(
		controller.hud.inventory_panel,
		"短剑",
		"Wield",
	)
	_assert_true(stale_wield_button != null, "live short row exposes one bound Wield button")
	var world_destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"audit.world"),
		true,
		true,
		OldPineOutdoorController.WORLD_CAPACITY,
	)
	_assert_true(
		InventoryTransferService.new().transfer(
			controller.inventory_state(),
			short_id,
			world_destination,
		).succeeded,
		"short becomes non-owned after its row was rendered",
	)
	if stale_wield_button != null:
		stale_wield_button.pressed.emit()
	_assert_eq(
		controller.last_equipment_interaction().outcome,
		OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED,
		"stale Wield row is rejected by current direct ownership",
	)
	_assert_true(
		controller.player_runtime().state.equipment.secondary_weapon() == null,
		"stale Wield row causes zero Equipment mutation",
	)
	_assert_eq(
		controller.hud.inventory_rows().size(),
		1,
		"stale Wield failure rebuilds panel and removes non-owned short",
	)

	var long_id: StringName = controller.hud.inventory_rows()[0].item_instance_id
	var stale_unwield_button: Button = _row_action_button(
		controller.hud.inventory_panel,
		"长剑",
		"Unwield",
	)
	_assert_true(stale_unwield_button != null, "live primary row exposes one bound Unwield button")
	_assert_true(
		InventoryTransferService.new().transfer(
			controller.inventory_state(),
			long_id,
			world_destination,
			controller.player_runtime().state.equipment,
			controller.player_runtime().armor,
		).succeeded,
		"closed transfer detaches and removes long after row render",
	)
	if stale_unwield_button != null:
		stale_unwield_button.pressed.emit()
	_assert_eq(
		controller.last_equipment_interaction().outcome,
		OldPineEquipmentInteractionResult.Outcome.ITEM_NOT_DIRECTLY_OWNED,
		"stale Unwield row is rejected by current direct ownership",
	)
	_assert_true(
		controller.player_runtime().state.equipment.primary_weapon() == null,
		"stale Unwield row cannot revive detached equipment",
	)
	_assert_true(
		controller.hud.inventory_rows().is_empty(),
		"stale Unwield failure rebuilds panel from empty direct inventory",
	)
	controller.queue_free()
	await tree.process_frame


func _test_weapon_switch_during_live_combat_and_unsupported_gate(
	tree: SceneTree,
) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	var long_id: StringName = controller.inventory_state().direct_children(
		_player_endpoint()
	)[0]
	var short_id: StringName = &"audit:combat-short"
	_assert_true(
		_register_player_item(
			controller,
			short_id,
			OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
			3000,
		),
		"live-combat fixture registers short sword",
	)
	var opponent: NpcRuntimeState = controller.npc_runtimes()[0]
	controller._on_south_slope_body_entered(controller.player_body)
	_assert_true(controller.select_npc(opponent.character_id), "live-combat fixture selects first bandit")
	_assert_eq(
		controller.attack_selected().outcome,
		CombatSliceInitiationResult.Outcome.COMPLETED,
		"live-combat fixture establishes real reciprocal lethal fight",
	)
	controller.opportunity_timer.stop()
	_assert_true(
		controller.player_runtime().relationship.is_fighting(),
		"player relationship is active before weapon change",
	)
	_assert_true(
		controller.unwield_player_item(long_id).succeeded,
		"source-permitted Unwield succeeds during active combat",
	)
	_assert_true(
		controller.wield_player_item(short_id).succeeded,
		"source-permitted Wield succeeds during active combat",
	)
	_assert_true(controller.opportunity_timer.is_stopped(), "equipment change does not restart combat Timer")
	_assert_true(
		controller.player_runtime().relationship.is_fighting(),
		"equipment change does not reset combat relationship",
	)
	var combat_random: CountingAttackFavoringRandomSource = (
		CountingAttackFavoringRandomSource.new()
	)
	controller.configure_combat_random_source(combat_random)
	var actual_apply_damage: int = -1
	for _tick: int in range(12):
		for result: CombatSliceOpportunityResult in controller.process_cadence_tick():
			if result.actor_id != controller.player_runtime().character_id:
				continue
			var forward: CombatSingleAttackExecutionResult = result.forward_result
			if forward == null or forward.ordinary_attack_result == null:
				continue
			var ordinary: CombatOrdinaryAttackResult = forward.ordinary_attack_result
			if ordinary.has_base_result and ordinary.base_result != null:
				actual_apply_damage = ordinary.base_result.calculation.base_apply_damage
				break
		if actual_apply_damage >= 0:
			break
	_assert_eq(actual_apply_damage, 15, "next opportunity in existing fight observes current short damage 15")
	_assert_true(combat_random.calls > 0, "live combat consumes RNG only after equipment actions")
	controller.queue_free()
	await tree.process_frame

	var unsupported_controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	var unsupported_long_id: StringName = (
		unsupported_controller.inventory_state().direct_children(_player_endpoint())[0]
	)
	unsupported_controller.unwield_player_item(unsupported_long_id)
	var unsupported_id: StringName = &"audit:unsupported-primary"
	_assert_true(
		_register_player_item(
			unsupported_controller,
			unsupported_id,
			&"audit:unsupported-definition",
			100,
		),
		"unsupported fixture registers exact live item metadata",
	)
	var unsupported_definition: WeaponDefinition = WeaponDefinition.new(
		&"audit:unsupported-definition",
		&"sword",
		false,
		false,
		"audit/unsupported.c",
	)
	_assert_true(
		unsupported_controller.player_runtime().state.equipment.wield(
			EquippedWeaponRef.new(unsupported_id, unsupported_definition),
			false,
		).succeeded,
		"test-only closed authority accepts unsupported primary reference",
	)
	var zero_random: CountingAttackFavoringRandomSource = CountingAttackFavoringRandomSource.new()
	unsupported_controller.configure_combat_random_source(zero_random)
	var unsupported_opponent: NpcRuntimeState = unsupported_controller.npc_runtimes()[0]
	unsupported_controller.select_npc(unsupported_opponent.character_id)
	var unsupported_initiation: CombatSliceInitiationResult = (
		unsupported_controller.attack_selected()
	)
	_assert_eq(
		unsupported_controller.last_player_content_resolution().outcome,
		OldPineWeaponContentResolution.Outcome.UNSUPPORTED_PRIMARY,
		"controller records explicit unsupported-primary content result",
	)
	_assert_true(
		unsupported_initiation.outcome != CombatSliceInitiationResult.Outcome.COMPLETED,
		"unsupported primary makes world combat initiation unavailable instead of unarmed",
	)
	_assert_false(
		unsupported_controller.player_runtime().relationship.is_fighting(),
		"unsupported primary creates no hidden combat relationship",
	)
	_assert_eq(zero_random.calls, 0, "unsupported-primary rejection consumes zero Combat RNG")
	unsupported_controller.queue_free()
	await tree.process_frame


func _test_fresh_scene_reset_baseline(tree: SceneTree) -> void:
	var fresh: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_false(fresh.hud.inventory_is_open(), "fresh/reset boundary closes Inventory panel")
	_assert_false(fresh.hud.loot_is_open(), "fresh/reset boundary closes Loot panel")
	_assert_eq(fresh.corpse_states().size(), 0, "fresh/reset boundary has no corpses")
	_assert_eq(fresh.npc_runtimes().size(), 5, "fresh/reset boundary restores all five bandits")
	_assert_true(fresh.open_player_inventory(), "fresh active player can open Inventory")
	var rows: Array[PlayerInventoryRowProjection] = fresh.hud.inventory_rows()
	_assert_eq(rows.size(), 1, "fresh/reset boundary removes acquired short and silver")
	_assert_eq(rows[0].item_definition_id, OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID, "fresh/reset boundary restores only prototype long")
	_assert_eq(rows[0].equipment_slot, PlayerInventoryRowProjection.EquipmentSlot.PRIMARY, "fresh/reset boundary restores long PRIMARY")
	var binding: CombatSliceCharacterBinding = fresh._build_participants()[0]
	_assert_eq(fresh.last_player_content_resolution().outcome, OldPineWeaponContentResolution.Outcome.LONG_SWORD, "fresh/reset resolver returns long profile")
	_assert_eq(binding.content.projected_apply_damage(binding.state.equipment.primary_weapon()), 25, "fresh/reset combat returns long damage 25")
	fresh.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	fresh.hud.refresh_live_state()
	_assert_true(fresh.hud.inventory_button.disabled, "non-ACTIVE player cannot open active Inventory actions")
	var inactive_unwield: OldPineEquipmentInteractionResult = fresh.unwield_player_item(
		rows[0].item_instance_id
	)
	_assert_eq(inactive_unwield.outcome, OldPineEquipmentInteractionResult.Outcome.PLAYER_NOT_ACTIVE, "open-panel action revalidates committed non-ACTIVE status")
	_assert_eq(fresh.player_runtime().state.equipment.primary_weapon().instance_id, rows[0].item_instance_id, "non-ACTIVE stale button path causes zero Equipment mutation")
	_assert_false(fresh.open_player_inventory(), "controller rejects non-ACTIVE Inventory opening")
	fresh.queue_free()
	await tree.process_frame


func _kill_bandit(
	controller: OldPineOutdoorController,
	victim: NpcRuntimeState,
	tree: SceneTree,
) -> void:
	controller._on_south_slope_body_entered(controller.player_body)
	controller.select_npc(victim.character_id)
	controller.attack_selected()
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.attributes.strength = 30
	victim.character_state.vitality.current = -1
	controller.process_cadence_tick()
	controller.configure_combat_random_source(CountingMaximumCombatRandomSource.new())
	for _tick: int in range(24):
		if victim.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		controller.process_cadence_tick()
	await tree.process_frame


func _instantiate_scene(tree: SceneTree) -> OldPineOutdoorController:
	var session: OldPineWorldSessionController = (
		SceneType.instantiate() as OldPineWorldSessionController
	)
	if session == null:
		return null
	session.deterministic_npc_seed = true
	session.npc_seed = 7021
	session.deterministic_combat_seed = true
	session.combat_seed = 5232
	tree.root.add_child(session)
	return session.outdoor_map()


func _player_endpoint() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.CHARACTER,
		OldPineOutdoorController.PLAYER_ID,
	)


func _register_player_item(
	controller: OldPineOutdoorController,
	item_instance_id: StringName,
	item_definition_id: StringName,
	own_weight: int,
) -> bool:
	var item: ItemInstance = ItemInstance.new(item_instance_id, item_definition_id)
	if not controller.inventory_state().register_item(item, own_weight):
		return false
	if not controller.item_instance_index().register_snapshot(item):
		return false
	return InventoryTransferService.new().transfer(
		controller.inventory_state(),
		item_instance_id,
		InventoryTransferDestination.new(
			_player_endpoint(),
			true,
			true,
			controller.player_runtime().maximum_encumbrance,
		),
	).succeeded


func _row_action_button(
	panel: PlayerInventoryPanel,
	display_name: String,
	action_text: String,
) -> Button:
	if panel == null:
		return null
	for child: Node in panel.row_container.get_children():
		var row: BoxContainer = child as BoxContainer
		if row == null or row.get_child_count() == 0:
			continue
		var label: Label = row.get_child(0) as Label
		if label == null or not label.text.begins_with(display_name):
			continue
		for row_child: Node in row.get_children():
			var button: Button = row_child as Button
			if button != null and button.text == action_text:
				return button
	return null


func _assert_dynamic_row_connections(
	panel: PlayerInventoryPanel,
	expected_rows: int,
) -> void:
	_assert_true(panel != null, "dynamic row connection audit has Inventory panel")
	if panel == null:
		return
	_assert_eq(
		panel.row_container.get_child_count(),
		expected_rows,
		"repeated live refresh creates exactly one node per projected row",
	)
	for child: Node in panel.row_container.get_children():
		var row: BoxContainer = child as BoxContainer
		_assert_true(row != null, "each dynamic Inventory row is one BoxContainer")
		if row == null:
			continue
		for row_child: Node in row.get_children():
			var button: Button = row_child as Button
			if button != null:
				_assert_eq(
					button.get_signal_connection_list("pressed").size(),
					1,
					"each dynamic action button binds its exact row identity once",
				)


func _loot_id_for_definition(
	rows: Array[WorldItemRowProjection],
	definition_id: StringName,
) -> StringName:
	for row: WorldItemRowProjection in rows:
		if row.item_definition_id == definition_id:
			return row.item_instance_id
	return &""


func _inventory_row_for(
	rows: Array[PlayerInventoryRowProjection],
	item_id: StringName,
) -> PlayerInventoryRowProjection:
	for row: PlayerInventoryRowProjection in rows:
		if row.item_instance_id == item_id:
			return row
	return null


func _definition_ids(
	rows: Array[PlayerInventoryRowProjection],
) -> Array[StringName]:
	var result: Array[StringName] = []
	for row: PlayerInventoryRowProjection in rows:
		result.append(row.item_definition_id)
	return result


func _row_ids(
	rows: Array[PlayerInventoryRowProjection],
) -> Array[StringName]:
	var result: Array[StringName] = []
	for row: PlayerInventoryRowProjection in rows:
		result.append(row.item_instance_id)
	return result


func _count_tree_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_tree_nodes(child)
	return count


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
