extends RefCounted

const SceneType := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

class CountingCombatRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		return 0 if exclusive_upper_bound > 0 else -1

class MaximumCombatRandomSource extends CombatRandomSource:
	func next_below(exclusive_upper_bound: int) -> int:
		return exclusive_upper_bound - 1 if exclusive_upper_bound > 0 else -1

class LootFixture extends RefCounted:
	var player: WorldPlayerRuntimeState
	var corpse: CorpseState
	var item: ItemInstance
	var inventory: InventoryState
	var stacks: CombinedStackCollection
	var item_index: WorldItemInstanceIndex
	var adapter: OldPineCorpseLootAdapter

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_target_index_content_and_player_capacity()
	_test_live_projection_and_short_sword_take()
	_test_silver_no_merge_and_merge()
	_test_partial_merge_and_validation_gates()
	_test_capacity_and_corpse_worn_compatibility()
	_test_multiple_corpse_contents_are_independent()
	await _test_corpse_view_identity_and_multiple_views(tree)
	await _test_partial_death_does_not_activate_loot(tree)
	await _test_unconscious_consumes_gap_without_item(tree)
	await _test_item_index_collision_preserves_completed_lifecycle(tree)
	await _test_oldpine_scene_loot_loop(tree)
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_target_index_content_and_player_capacity() -> void:
	var item_target: WorldInteractionTarget = WorldInteractionTarget.item(&"instance:corpse")
	_assert_true(item_target.is_valid(), "ITEM target accepts a stable ItemInstanceId")
	_assert_eq(item_target.kind, WorldInteractionTarget.Kind.ITEM, "ITEM is distinct target kind")
	_assert_eq(item_target.target_id, &"instance:corpse", "ITEM keeps exact instance identity")
	_assert_eq(WorldInteractionTarget.character(&"character").kind, WorldInteractionTarget.Kind.CHARACTER, "CHARACTER target is unchanged")
	_assert_eq(WorldInteractionTarget.landmark(&"landmark").kind, WorldInteractionTarget.Kind.LANDMARK, "LANDMARK target is unchanged")
	_assert_false(WorldInteractionTarget.item(&"").is_valid(), "empty ITEM identity is invalid")

	var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	var item: ItemInstance = ItemInstance.new(&"item:one", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)
	_assert_true(index.register_snapshot(item), "map-local index registers immutable snapshot")
	_assert_false(index.register_snapshot(item), "map-local index rejects duplicate instance identity")
	var resolved: ItemInstance = index.resolve(item.item_instance_id)
	_assert_true(resolved != item, "index returns a defensive ItemInstance snapshot")
	_assert_eq(resolved.item_definition_id, item.item_definition_id, "index preserves definition identity")
	_assert_true(index.resolve(&"missing") == null, "index does not infer unknown identities")

	_assert_true(OldPineItemContentDefinitions.validate(), "narrow Old Pine content validates")
	var long_sword: OldPineItemContentDefinition = OldPineItemContentDefinitions.content_by_id(OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID)
	var short_sword: OldPineItemContentDefinition = OldPineItemContentDefinitions.content_by_id(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)
	var silver: OldPineItemContentDefinition = OldPineItemContentDefinitions.content_by_id(OldPineItemContentDefinitions.SILVER_ITEM_ID)
	_assert_eq(long_sword.display_name, "长剑", "prototype long sword uses authored display name")
	_assert_true(long_sword.description.contains("粗制滥造的长剑"), "long sword uses LPC long text")
	_assert_eq(long_sword.weapon_damage, 25, "long sword keeps authored damage fact")
	_assert_eq(short_sword.display_name, "短剑", "short sword uses authored display name")
	_assert_true(short_sword.description.contains("粗制滥造的短剑"), "short sword uses LPC long text")
	_assert_eq(short_sword.weapon_skill_type, &"sword", "short sword remains sword")
	_assert_eq(short_sword.weapon_damage, 15, "short sword damage is exact")
	_assert_true(short_sword.can_wield_secondary, "short sword keeps SECONDARY capability")
	_assert_false(short_sword.is_two_handed, "short sword is not two-handed")
	_assert_eq(short_sword.own_weight, 3000, "short sword own weight is exact")
	_assert_eq(silver.display_name, "银子", "silver uses authored display name")
	_assert_true(silver.description.contains("人见人爱"), "silver uses LPC long text")
	_assert_eq(silver.stack_base_weight, 37, "silver base weight is exact")
	_assert_eq(silver.currency_base_value, 100, "silver base value is exact")
	_assert_true(OldPineItemContentDefinitions.content_by_id(&"unknown") == null, "unknown content fails honestly")

	var player: WorldPlayerRuntimeState = _make_player(12345)
	_assert_eq(player.maximum_encumbrance, 12345, "runtime stores setup-time maximum encumbrance verbatim")
	player.state.attributes.strength += 100
	_assert_eq(player.maximum_encumbrance, 12345, "capacity snapshot does not recompute from live strength")


func _test_live_projection_and_short_sword_take() -> void:
	var fixture: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
		3000,
		50000,
	)
	var rows: Array[WorldItemRowProjection] = fixture.adapter.project_rows(
		fixture.corpse, fixture.inventory, fixture.stacks, fixture.item_index
	)
	_assert_eq(rows.size(), 1, "projection enumerates current direct corpse contents")
	_assert_eq(rows[0].item_instance_id, fixture.item.item_instance_id, "row Take identity is exact ItemInstanceId")
	_assert_eq(rows[0].item_definition_id, fixture.item.item_definition_id, "row keeps definition identity separately")
	_assert_eq(rows[0].display_name, "短剑", "short sword row is authored")
	_assert_eq(rows[0].amount, 1, "ordinary item row amount is one")
	_assert_true(rows[0].can_take, "fresh ordinary corpse item can be taken")

	var primary_before: EquippedWeaponRef = fixture.player.state.equipment.primary_weapon()
	var result: CorpseLootTransferResult = fixture.adapter.take(
		fixture.player, fixture.corpse, fixture.item.item_instance_id, true,
		fixture.inventory, fixture.stacks, fixture.item_index,
	)
	_assert_eq(result.outcome, CorpseLootTransferResult.Outcome.COMPLETED, "short sword Take completes")
	_assert_true(result.succeeded, "short sword Take is successful")
	_assert_true(result.corpse_transfer_result != null and result.corpse_transfer_result.succeeded, "Take evidence contains corpse-aware transfer")
	_assert_eq(result.resulting_item_instance_id, fixture.item.item_instance_id, "same short sword instance survives")
	_assert_true(fixture.inventory.is_direct_child(fixture.item.item_instance_id, _character_endpoint()), "short sword parent becomes player")
	_assert_eq(fixture.inventory.own_weight(fixture.item.item_instance_id), 3000, "short sword weight is unchanged")
	_assert_true(fixture.inventory.direct_children(_corpse_endpoint(fixture.corpse)).is_empty(), "corpse direct contents refresh to empty")
	_assert_true(fixture.inventory.is_registered(fixture.corpse.corpse_item_instance_id), "empty corpse remains registered")
	_assert_true(fixture.player.state.equipment.primary_weapon() == primary_before, "Take does not auto-wield or replace equipment")


func _test_silver_no_merge_and_merge() -> void:
	var no_merge: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SILVER_ITEM_ID,
		0,
		50000,
		3,
	)
	var rows: Array[WorldItemRowProjection] = no_merge.adapter.project_rows(
		no_merge.corpse, no_merge.inventory, no_merge.stacks, no_merge.item_index
	)
	_assert_eq(rows[0].display_name, "银子", "silver row uses authored name")
	_assert_eq(rows[0].amount, 3, "silver row reads live amount three")
	_assert_eq(no_merge.inventory.own_weight(no_merge.item.item_instance_id), 111, "amount three weighs 3 * 37")
	var no_merge_result: CorpseLootTransferResult = no_merge.adapter.take(
		no_merge.player, no_merge.corpse, no_merge.item.item_instance_id, true,
		no_merge.inventory, no_merge.stacks, no_merge.item_index,
	)
	_assert_eq(no_merge_result.outcome, CorpseLootTransferResult.Outcome.COMPLETED, "silver without sibling completes without merge")
	_assert_true(no_merge_result.merge_result != null and no_merge_result.merge_result.succeeded, "combined move still executes closed merge service")
	_assert_false(no_merge_result.merge_result.merge_applied, "no compatible sibling means no merge")
	_assert_eq(no_merge.stacks.stack_state(no_merge.item.item_instance_id).amount, 3, "same silver keeps amount three")
	_assert_eq(no_merge.inventory.own_weight(no_merge.item.item_instance_id), 111, "same silver keeps weight 111")
	_assert_eq(OldPineNpcDefinitions.silver_content().currency_definition().value_for_amount(3), 300, "amount three value is 300")

	var merged: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SILVER_ITEM_ID,
		0,
		50000,
		3,
	)
	var existing: ItemInstance = _add_player_silver(merged, &"player-silver", 5)
	var merge_result: CorpseLootTransferResult = merged.adapter.take(
		merged.player, merged.corpse, merged.item.item_instance_id, true,
		merged.inventory, merged.stacks, merged.item_index,
	)
	_assert_eq(merge_result.outcome, CorpseLootTransferResult.Outcome.COMPLETED_WITH_MERGE, "5 + 3 uses completed merge outcome")
	_assert_true(merge_result.merge_result.merge_applied, "merge evidence is explicit")
	_assert_eq(merge_result.resulting_item_instance_id, merged.item.item_instance_id, "incoming corpse silver is survivor")
	_assert_eq(merged.stacks.stack_state(merged.item.item_instance_id).amount, 8, "survivor amount is eight")
	_assert_eq(merged.inventory.own_weight(merged.item.item_instance_id), 296, "survivor weight is 8 * 37")
	_assert_eq(OldPineNpcDefinitions.silver_content().currency_definition().value_for_amount(8), 800, "survivor value is 800")
	_assert_false(merged.inventory.is_registered(existing.item_instance_id), "absorbed old player silver is removed from Inventory")
	_assert_false(merged.stacks.has_stack(existing.item_instance_id), "absorbed old player silver association is removed")
	_assert_true(merged.item_index.has_snapshot(existing.item_instance_id), "stale immutable index metadata may remain")
	_assert_true(merged.item_index.resolve(existing.item_instance_id) != null, "absorbed metadata remains an immutable lookup only")
	_assert_eq(merged.inventory.direct_children(_character_endpoint()), [merged.item.item_instance_id], "only the incoming live silver survivor remains player-owned")
	_assert_true(merged.adapter.project_rows(merged.corpse, merged.inventory, merged.stacks, merged.item_index).is_empty(), "stale absorbed metadata cannot reappear in corpse projection")
	var stale_absorbed_take: CorpseLootTransferResult = merged.adapter.take(
		merged.player, merged.corpse, existing.item_instance_id, true,
		merged.inventory, merged.stacks, merged.item_index,
	)
	_assert_eq(stale_absorbed_take.outcome, CorpseLootTransferResult.Outcome.ITEM_NOT_AVAILABLE, "stale absorbed metadata cannot become a live Take target")


func _test_partial_merge_and_validation_gates() -> void:
	var partial: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SILVER_ITEM_ID, 0, 50000, 3
	)
	var existing: ItemInstance = _add_player_silver(partial, &"nested-player-silver", 5)
	partial.player.relationship.add_opponent(&"enemy")
	var nested: ItemInstance = ItemInstance.new(
		&"nested-short-sword", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID
	)
	_assert_true(partial.inventory.register_item(nested, 3000), "partial fixture registers nested child")
	_assert_true(partial.item_index.register_snapshot(nested), "partial fixture indexes nested child")
	_assert_true(InventoryTransferService.new().transfer(
		partial.inventory,
		nested.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, existing.item_instance_id),
			true, true, 10000,
		),
	).succeeded, "partial fixture nests an item under absorb candidate")
	var partial_result: CorpseLootTransferResult = partial.adapter.take(
		partial.player, partial.corpse, partial.item.item_instance_id, true,
		partial.inventory, partial.stacks, partial.item_index,
	)
	_assert_eq(partial_result.outcome, CorpseLootTransferResult.Outcome.PARTIAL_MERGE_FAILED, "post-Take merge failure is explicit partial outcome")
	_assert_false(partial_result.succeeded, "partial merge is not reported as full success")
	_assert_true(partial_result.ownership_completed(), "partial result reports completed ownership")
	_assert_true(partial.inventory.is_direct_child(partial.item.item_instance_id, _character_endpoint()), "partial failure leaves incoming item player-owned")
	_assert_true(partial.inventory.is_registered(existing.item_instance_id), "failed absorption does not remove existing sibling")
	_assert_true(partial_result.busy_started, "fighting partial merge still records successful ownership Take busy")
	_assert_eq(partial.player.busy.busy_value, 1, "fighting partial merge starts busy one exactly")
	_assert_true(partial_result.corpse_transfer_result.succeeded, "partial result retains successful corpse-transfer evidence")
	_assert_true(partial_result.merge_result != null and not partial_result.merge_result.succeeded, "partial result retains failed merge evidence")

	var out_of_range: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	var parent_before: ContainmentEndpoint = out_of_range.inventory.direct_parent(out_of_range.item.item_instance_id)
	var out_result: CorpseLootTransferResult = out_of_range.adapter.take(
		out_of_range.player, out_of_range.corpse, out_of_range.item.item_instance_id, false,
		out_of_range.inventory, out_of_range.stacks, out_of_range.item_index,
	)
	_assert_eq(out_result.outcome, CorpseLootTransferResult.Outcome.OUT_OF_RANGE, "Take revalidates current range")
	_assert_true(out_of_range.inventory.direct_parent(out_of_range.item.item_instance_id).same_identity(parent_before), "out-of-range Take mutates no ownership")

	var busy: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	busy.player.busy.start_busy(2)
	var busy_result: CorpseLootTransferResult = busy.adapter.take(
		busy.player, busy.corpse, busy.item.item_instance_id, true,
		busy.inventory, busy.stacks, busy.item_index,
	)
	_assert_eq(busy_result.outcome, CorpseLootTransferResult.Outcome.PLAYER_BUSY, "busy rejects before transfer")
	_assert_eq(busy.player.busy.busy_value, 2, "failed Take does not add busy")
	_assert_true(busy.inventory.is_direct_child(busy.item.item_instance_id, _corpse_endpoint(busy.corpse)), "busy failure keeps corpse ownership")

	var fighting: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	fighting.player.relationship.add_opponent(&"enemy")
	var fighting_result: CorpseLootTransferResult = fighting.adapter.take(
		fighting.player, fighting.corpse, fighting.item.item_instance_id, true,
		fighting.inventory, fighting.stacks, fighting.item_index,
	)
	_assert_true(fighting_result.succeeded, "fighting does not block single Take")
	_assert_true(fighting_result.busy_started, "successful fighting Take starts existing busy")
	_assert_eq(fighting.player.busy.busy_value, 1, "fighting Take starts busy one exactly")

	var inactive: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	inactive.player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	var inactive_result: CorpseLootTransferResult = inactive.adapter.take(
		inactive.player, inactive.corpse, inactive.item.item_instance_id, true,
		inactive.inventory, inactive.stacks, inactive.item_index,
	)
	_assert_eq(inactive_result.outcome, CorpseLootTransferResult.Outcome.PLAYER_NOT_AVAILABLE, "non-ACTIVE player cannot Take")
	_assert_eq(
		inactive.adapter.validate_open(
			inactive.player, inactive.corpse, inactive.inventory,
			inactive.item_index, true,
		),
		OldPineCorpseLootAdapter.OpenValidation.PLAYER_NOT_AVAILABLE,
		"non-ACTIVE player cannot Open Loot",
	)

	var wrong_parent: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	_assert_true(InventoryTransferService.new().transfer(
		wrong_parent.inventory, wrong_parent.item.item_instance_id,
		_player_destination(wrong_parent.player.maximum_encumbrance),
	).succeeded, "wrong-parent fixture moves row item elsewhere")
	var wrong_result: CorpseLootTransferResult = wrong_parent.adapter.take(
		wrong_parent.player, wrong_parent.corpse, wrong_parent.item.item_instance_id, true,
		wrong_parent.inventory, wrong_parent.stacks, wrong_parent.item_index,
	)
	_assert_eq(wrong_result.outcome, CorpseLootTransferResult.Outcome.ITEM_NOT_IN_CORPSE, "stale row cannot move arbitrary item")

	var stale_item: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	_assert_true(stale_item.inventory._remove_registered_leaf(stale_item.item.item_instance_id), "stale item fixture removes live authority only")
	_assert_true(stale_item.item_index.has_snapshot(stale_item.item.item_instance_id), "stale item metadata remains indexed")
	var stale_item_result: CorpseLootTransferResult = stale_item.adapter.take(
		stale_item.player, stale_item.corpse, stale_item.item.item_instance_id, true,
		stale_item.inventory, stale_item.stacks, stale_item.item_index,
	)
	_assert_eq(stale_item_result.outcome, CorpseLootTransferResult.Outcome.ITEM_NOT_AVAILABLE, "Inventory liveness rejects stale indexed item")

	var unknown: LootFixture = _make_fixture(&"es2:unknown", 1, 50000)
	_assert_false(unknown.adapter.contents_are_resolvable(unknown.corpse, unknown.inventory, unknown.item_index), "unknown live definition makes projection incoherent")
	var unknown_result: CorpseLootTransferResult = unknown.adapter.take(
		unknown.player, unknown.corpse, unknown.item.item_instance_id, true,
		unknown.inventory, unknown.stacks, unknown.item_index,
	)
	_assert_eq(unknown_result.outcome, CorpseLootTransferResult.Outcome.CONTENT_UNAVAILABLE, "unknown content is not silently Takeable")

	var stale_corpse: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	stale_corpse.adapter.take(
		stale_corpse.player, stale_corpse.corpse, stale_corpse.item.item_instance_id, true,
		stale_corpse.inventory, stale_corpse.stacks, stale_corpse.item_index,
	)
	_assert_true(stale_corpse.inventory._remove_registered_leaf(stale_corpse.corpse.corpse_item_instance_id), "stale corpse fixture removes empty corpse liveness")
	_assert_eq(
		stale_corpse.adapter.validate_open(
			stale_corpse.player, stale_corpse.corpse, stale_corpse.inventory,
			stale_corpse.item_index, true,
		),
		OldPineCorpseLootAdapter.OpenValidation.CORPSE_NOT_AVAILABLE,
		"stale indexed corpse cannot reopen loot",
	)


func _test_capacity_and_corpse_worn_compatibility() -> void:
	var exact: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 3000)
	var exact_result: CorpseLootTransferResult = exact.adapter.take(
		exact.player, exact.corpse, exact.item.item_instance_id, true,
		exact.inventory, exact.stacks, exact.item_index,
	)
	_assert_true(exact_result.succeeded, "exact capacity succeeds")

	var over: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 2999)
	var over_result: CorpseLootTransferResult = over.adapter.take(
		over.player, over.corpse, over.item.item_instance_id, true,
		over.inventory, over.stacks, over.item_index,
	)
	_assert_eq(over_result.outcome, CorpseLootTransferResult.Outcome.TRANSFER_FAILED, "capacity exceeded by one fails")
	_assert_eq(over_result.corpse_transfer_result.transfer_result.outcome, InventoryTransferResult.Outcome.CAPACITY_EXCEEDED, "closed transfer owns capacity result")
	_assert_eq(over.player.busy.busy_value, 0, "capacity failure starts no busy")

	var exact_with_contents: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 4000
	)
	_assert_true(_add_player_burden(exact_with_contents, &"player-burden", 1000), "exact boundary fixture adds existing player contents")
	var exact_with_contents_result: CorpseLootTransferResult = exact_with_contents.adapter.take(
		exact_with_contents.player, exact_with_contents.corpse,
		exact_with_contents.item.item_instance_id, true,
		exact_with_contents.inventory, exact_with_contents.stacks,
		exact_with_contents.item_index,
	)
	_assert_true(exact_with_contents_result.succeeded, "existing 1000 plus moving 3000 equals capacity 4000")
	var over_with_contents: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 3999
	)
	_assert_true(_add_player_burden(over_with_contents, &"player-burden-over", 1000), "over boundary fixture adds existing player contents")
	var over_with_contents_result: CorpseLootTransferResult = over_with_contents.adapter.take(
		over_with_contents.player, over_with_contents.corpse,
		over_with_contents.item.item_instance_id, true,
		over_with_contents.inventory, over_with_contents.stacks,
		over_with_contents.item_index,
	)
	_assert_eq(over_with_contents_result.corpse_transfer_result.transfer_result.outcome, InventoryTransferResult.Outcome.CAPACITY_EXCEEDED, "existing 1000 plus moving 3000 exceeds capacity 3999 by one")

	var silver_capacity: LootFixture = _make_fixture(OldPineItemContentDefinitions.SILVER_ITEM_ID, 0, 110, 3)
	var silver_failure: CorpseLootTransferResult = silver_capacity.adapter.take(
		silver_capacity.player, silver_capacity.corpse, silver_capacity.item.item_instance_id, true,
		silver_capacity.inventory, silver_capacity.stacks, silver_capacity.item_index,
	)
	_assert_eq(silver_failure.corpse_transfer_result.transfer_result.outcome, InventoryTransferResult.Outcome.CAPACITY_EXCEEDED, "silver capacity uses current weight 111, not base 37")

	var released: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 2999)
	_assert_true(released.corpse._try_wear(&"cloth", released.item.item_instance_id, released.inventory), "fresh corpse worn projection is established")
	var release_result: CorpseLootTransferResult = released.adapter.take(
		released.player, released.corpse, released.item.item_instance_id, true,
		released.inventory, released.stacks, released.item_index,
	)
	_assert_eq(release_result.outcome, CorpseLootTransferResult.Outcome.TRANSFER_FAILED, "post-release capacity failure remains transfer failure")
	_assert_true(release_result.corpse_transfer_result.corpse_worn_released, "fresh worn projection releases before capacity")
	_assert_false(released.corpse.is_worn(released.item.item_instance_id), "release is not rolled back")
	_assert_true(released.inventory.is_direct_child(released.item.item_instance_id, _corpse_endpoint(released.corpse)), "failed transfer keeps containment in corpse")

	var released_success: LootFixture = _make_fixture(
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000
	)
	_assert_true(released_success.corpse._try_wear(&"cloth", released_success.item.item_instance_id, released_success.inventory), "successful fresh-worn fixture establishes projection")
	var released_success_result: CorpseLootTransferResult = released_success.adapter.take(
		released_success.player, released_success.corpse,
		released_success.item.item_instance_id, true,
		released_success.inventory, released_success.stacks,
		released_success.item_index,
	)
	_assert_true(released_success_result.succeeded, "fresh corpse-worn item releases then transfers")
	_assert_true(released_success_result.corpse_transfer_result.corpse_worn_released, "successful fresh corpse-worn Take records release")
	_assert_false(released_success.corpse.is_worn(released_success.item.item_instance_id), "successful Take leaves no stale corpse-worn projection")

	var locked: LootFixture = _make_fixture(OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID, 3000, 50000)
	_assert_true(locked.corpse._try_wear(&"cloth", locked.item.item_instance_id, locked.inventory), "locked fixture starts corpse-worn")
	_assert_true(locked.corpse._apply_next_decay_stage(CorpseState.Stage.ROTTEN), "locked fixture advances to stage one")
	var locked_result: CorpseLootTransferResult = locked.adapter.take(
		locked.player, locked.corpse, locked.item.item_instance_id, true,
		locked.inventory, locked.stacks, locked.item_index,
	)
	_assert_eq(locked_result.outcome, CorpseLootTransferResult.Outcome.CORPSE_WORN_LOCKED, "stage one worn item is locked")
	_assert_true(locked.corpse.is_worn(locked.item.item_instance_id), "locked projection remains")


func _test_multiple_corpse_contents_are_independent() -> void:
	var inventory: InventoryState = InventoryState.new()
	var stacks: CombinedStackCollection = CombinedStackCollection.new()
	var item_index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	var adapter: OldPineCorpseLootAdapter = OldPineCorpseLootAdapter.new()
	var player: WorldPlayerRuntimeState = _make_player(50000)
	var corpse_a: CorpseState = CorpseState.new(&"corpse:a", &"victim:a", "甲")
	var corpse_b: CorpseState = CorpseState.new(&"corpse:b", &"victim:b", "乙")
	for corpse: CorpseState in [corpse_a, corpse_b]:
		var corpse_item: ItemInstance = ItemInstance.new(
			corpse.corpse_item_instance_id,
			CombatSliceDeathAdapter.CORPSE_DEFINITION_ID,
		)
		_assert_true(inventory.register_item(corpse_item, 0), "multiple-corpse fixture registers exact corpse")
		_assert_true(item_index.register_snapshot(corpse_item), "multiple-corpse fixture indexes exact corpse")
		_assert_true(
			InventoryTransferService.new().transfer(
				inventory,
				corpse_item.item_instance_id,
				InventoryTransferDestination.new(
					ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"oldpine.location"),
					true,
					true,
					100000,
				),
			).succeeded,
			"multiple-corpse fixture places exact corpse in world",
		)
	var sword: ItemInstance = ItemInstance.new(
		&"corpse-a-sword", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID
	)
	var silver: ItemInstance = ItemInstance.new(
		&"corpse-b-silver", OldPineItemContentDefinitions.SILVER_ITEM_ID
	)
	_assert_true(inventory.register_item(sword, 3000), "corpse A sword registers")
	_assert_true(item_index.register_snapshot(sword), "corpse A sword indexes")
	_assert_true(inventory.register_item(silver, 0), "corpse B silver registers")
	_assert_true(item_index.register_snapshot(silver), "corpse B silver indexes")
	_assert_true(
		CombinedStackService.register_stack(
			stacks,
			inventory,
			silver,
			OldPineNpcDefinitions.silver_content().stack_definition(),
			3,
		).accepted,
		"corpse B silver keeps amount three",
	)
	_assert_true(
		InventoryTransferService.new().transfer(
			inventory,
			sword.item_instance_id,
			InventoryTransferDestination.new(
				_corpse_endpoint(corpse_a), true, true, 50000
			),
		).succeeded,
		"corpse A owns only its sword",
	)
	_assert_true(
		InventoryTransferService.new().transfer(
			inventory,
			silver.item_instance_id,
			InventoryTransferDestination.new(
				_corpse_endpoint(corpse_b), true, true, 50000
			),
		).succeeded,
		"corpse B owns only its silver",
	)
	var rows_a: Array[WorldItemRowProjection] = adapter.project_rows(
		corpse_a, inventory, stacks, item_index
	)
	var rows_b: Array[WorldItemRowProjection] = adapter.project_rows(
		corpse_b, inventory, stacks, item_index
	)
	_assert_eq(rows_a.size(), 1, "corpse A projects one independent row")
	_assert_eq(rows_a[0].item_instance_id, sword.item_instance_id, "corpse A row is its exact sword")
	_assert_eq(rows_b.size(), 1, "corpse B projects one independent row")
	_assert_eq(rows_b[0].item_instance_id, silver.item_instance_id, "corpse B row is its exact silver")
	var selected_b_out_of_range: CorpseLootTransferResult = adapter.take(
		player, corpse_b, silver.item_instance_id, false,
		inventory, stacks, item_index,
	)
	_assert_eq(selected_b_out_of_range.outcome, CorpseLootTransferResult.Outcome.OUT_OF_RANGE, "corpse B cannot borrow corpse A's range")
	_assert_true(inventory.is_direct_child(sword.item_instance_id, _corpse_endpoint(corpse_a)), "failed B Take does not mutate corpse A")
	var selected_b_take: CorpseLootTransferResult = adapter.take(
		player, corpse_b, silver.item_instance_id, true,
		inventory, stacks, item_index,
	)
	_assert_true(selected_b_take.succeeded, "in-range Take affects selected corpse B only")
	_assert_true(inventory.is_direct_child(sword.item_instance_id, _corpse_endpoint(corpse_a)), "successful B Take still does not mutate corpse A")
	_assert_true(inventory.direct_children(_corpse_endpoint(corpse_b)).is_empty(), "corpse B alone becomes empty")


func _test_corpse_view_identity_and_multiple_views(tree: SceneTree) -> void:
	var first: CombatSliceCorpseView = CombatSliceCorpseView.new()
	var second: CombatSliceCorpseView = CombatSliceCorpseView.new()
	var first_state: CorpseState = CorpseState.new(&"corpse:a", &"a", "甲")
	var second_state: CorpseState = CorpseState.new(&"corpse:b", &"b", "乙")
	_assert_true(first.configure(first_state), "first corpse view configures")
	_assert_true(second.configure(second_state), "second corpse view configures")
	_assert_eq(first.corpse_item_instance_id, &"corpse:a", "first view keeps exact corpse ID")
	_assert_eq(second.corpse_item_instance_id, &"corpse:b", "second view keeps independent ID")
	_assert_true(first.picking_area() != null, "corpse view creates picking Area2D")
	_assert_true(first.picking_area().get_node("CollisionShape2D") is CollisionShape2D, "picking Area has shape")
	var range_shape: CircleShape2D = (first.loot_interaction_range().get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_assert_eq(range_shape.radius, CombatSliceCorpseView.LOOT_INTERACTION_RADIUS, "loot range uses fixed prototype radius")
	_assert_eq(first.loot_interaction_range().collision_mask, 1, "loot range observes player body layer")
	var root: Node2D = Node2D.new()
	var body: CharacterBody2D = CharacterBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_rectangle: RectangleShape2D = RectangleShape2D.new()
	body_rectangle.size = Vector2(36.0, 36.0)
	body_shape.shape = body_rectangle
	body.add_child(body_shape)
	first.global_position = Vector2.ZERO
	second.global_position = Vector2(300.0, 0.0)
	body.global_position = Vector2.ZERO
	root.add_child(first)
	root.add_child(second)
	root.add_child(body)
	tree.root.add_child(root)
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(first.is_inside_tree() and second.is_inside_tree(), "multiple corpse views coexist")
	_assert_true(first.is_body_in_loot_range(body), "corpse A owns its independent in-range fact")
	_assert_false(second.is_body_in_loot_range(body), "selected corpse B cannot borrow corpse A range")
	body.global_position = second.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_false(first.is_body_in_loot_range(body), "leaving corpse A clears only A range")
	_assert_true(second.is_body_in_loot_range(body), "entering corpse B establishes only B range")
	var selected_ids: Array[StringName] = []
	first.selection_requested.connect(
		func(corpse_id: StringName) -> void: selected_ids.append(corpse_id)
	)
	second.selection_requested.connect(
		func(corpse_id: StringName) -> void: selected_ids.append(corpse_id)
	)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	first.picking_area().input_event.emit(root.get_viewport(), click, 0)
	second.picking_area().input_event.emit(root.get_viewport(), click, 0)
	_assert_eq(selected_ids, [&"corpse:a", &"corpse:b"], "each dynamic picking signal emits its exact corpse ID once")
	root.queue_free()
	await tree.process_frame


func _test_partial_death_does_not_activate_loot(tree: SceneTree) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "partial-death fixture instantiates Old Pine")
	if controller == null:
		return
	var unknown: ItemInstance = ItemInstance.new(
		&"partial-death-unknown", &"unknown-definition"
	)
	_assert_true(controller.inventory_state().register_item(unknown, 10), "partial-death fixture registers uncovered direct item")
	_assert_true(
		InventoryTransferService.new().transfer(
			controller.inventory_state(),
			unknown.item_instance_id,
			InventoryTransferDestination.new(
				ContainmentEndpoint.new(
					ContainmentEndpoint.Kind.CHARACTER,
					controller.player_runtime().character_id,
				),
				true,
				true,
				controller.player_runtime().maximum_encumbrance,
			),
		).succeeded,
		"partial-death fixture makes unknown item direct player inventory",
	)
	controller._on_south_slope_body_entered(controller.player_body)
	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	_assert_true(controller.select_npc(victim.character_id), "partial-death fixture selects a bandit")
	_assert_eq(
		controller.attack_selected().outcome,
		CombatSliceInitiationResult.Outcome.COMPLETED,
		"partial-death fixture starts lethal combat",
	)
	controller.opportunity_timer.stop()
	controller.player_runtime().state.vitality.effective = -1
	controller.process_cadence_tick()
	var lifecycle: CombatSliceLifecycleResult = controller.last_lifecycle_results()[0]
	_assert_eq(lifecycle.outcome, CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_BLOCKED, "uncovered player item produces blocked partial death")
	_assert_eq(controller.corpse_states().size(), 1, "closed Phase 6B3 partial corpse authority remains preserved")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "closed Phase 6B3 partial corpse view remains presented")
	var partial_corpse: CorpseState = controller.corpse_states()[0]
	_assert_false(controller.item_instance_index().has_snapshot(partial_corpse.corpse_item_instance_id), "partial corpse is not registered as Phase 8B1 item interaction metadata")
	_assert_true(controller.corpse_view_for(partial_corpse.corpse_item_instance_id) == null, "partial corpse has no active loot-range binding")
	_assert_false(controller.select_corpse(partial_corpse.corpse_item_instance_id), "partial corpse cannot become an ITEM target")
	var partial_view: CombatSliceCorpseView = controller.corpse_layer.get_child(0) as CombatSliceCorpseView
	_assert_true(partial_view.selection_requested.get_connections().is_empty(), "partial corpse picking signal has no controller connection")
	_assert_true(partial_view.loot_range_changed.get_connections().is_empty(), "partial corpse range signal has no controller connection")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	partial_view.picking_area().input_event.emit(controller.get_viewport(), click, 0)
	_assert_true(controller.selected_interaction_target() != null and controller.selected_interaction_target().kind == WorldInteractionTarget.Kind.CHARACTER, "partial corpse picking has no connected interaction activation")
	controller.queue_free()
	await tree.process_frame


func _test_unconscious_consumes_gap_without_item(tree: SceneTree) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "unconscious allocation fixture instantiates Old Pine")
	if controller == null:
		return
	var inventory_ids_before: Array[StringName] = (
		controller.inventory_state().registered_item_ids()
	)
	var index_ids_before: Array[StringName] = (
		controller.item_instance_index().snapshot_ids()
	)
	_assert_eq(controller._item_id_allocator.next_dynamic_sequence, 0, "fresh session allocator starts at zero")
	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	controller._on_south_slope_body_entered(controller.player_body)
	_assert_true(controller.select_npc(victim.character_id), "unconscious fixture selects a bandit")
	_assert_eq(controller.attack_selected().outcome, CombatSliceInitiationResult.Outcome.COMPLETED, "unconscious fixture starts combat through normal boundary")
	controller.opportunity_timer.stop()
	controller.player_runtime().busy.start_busy(1)
	victim.character_state.attributes.strength = 30
	victim.character_state.vitality.current = -1
	controller.process_cadence_tick()
	_assert_eq(victim.life_status, CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "first threshold opportunity resolves unconscious rather than death")
	_assert_eq(controller._item_id_allocator.next_dynamic_sequence, 1, "unconscious opportunity intentionally consumes one sequence gap")
	_assert_eq(controller.inventory_state().registered_item_ids(), inventory_ids_before, "unconscious creates no Inventory item")
	_assert_eq(controller.item_instance_index().snapshot_ids(), index_ids_before, "unconscious creates no item-index projection")
	_assert_true(controller.corpse_states().is_empty(), "unconscious creates no corpse state")
	controller.queue_free()
	await tree.process_frame


func _test_item_index_collision_preserves_completed_lifecycle(
	tree: SceneTree,
) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "index-collision fixture instantiates Old Pine")
	if controller == null:
		return
	var corpse_id: StringName = StringName(
		## The deterministic helper first crosses the unconscious boundary;
		## the session allocator consumes dynamic sequence zero for that
		## opportunity before the later death opportunity uses sequence one.
		"%s.dynamic.1" % String(controller._item_id_allocator.scope)
	)
	_assert_true(
		controller.item_instance_index().register_snapshot(
			ItemInstance.new(corpse_id, CombatSliceDeathAdapter.CORPSE_DEFINITION_ID)
		),
		"index-collision fixture reserves only metadata identity",
	)
	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	await _kill_bandit(controller, victim, tree)
	var lifecycle: CombatSliceLifecycleResult = controller.last_lifecycle_results()[0]
	_assert_eq(lifecycle.outcome, CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE, "post-death metadata collision does not rewrite completed lifecycle evidence")
	_assert_true(lifecycle.completed(), "completed lifecycle remains completed after interaction-index failure")
	_assert_eq(lifecycle.corpse_item_instance_id, corpse_id, "completed lifecycle retains the exact generated corpse ID")
	_assert_true(controller.inventory_state().is_registered(corpse_id), "completed corpse remains live Inventory authority")
	_assert_eq(controller.corpse_states().size(), 1, "completed corpse authority remains retained")
	_assert_eq(controller.corpse_layer.get_child_count(), 1, "completed corpse presentation remains retained")
	_assert_true(controller.corpse_view_for(corpse_id) == null, "failed interaction registration does not expose a half-wired loot view")
	_assert_false(controller.select_corpse(corpse_id), "index collision cannot activate a normal ITEM target")
	controller.queue_free()
	await tree.process_frame


func _test_oldpine_scene_loot_loop(tree: SceneTree) -> void:
	var controller: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(controller != null, "Old Pine scene instantiates with loot UI")
	if controller == null:
		return
	var viewport_size: Vector2 = controller.get_viewport_rect().size
	var loot_panel: OldPineLootPanel = controller.hud.loot_panel
	_assert_true(loot_panel.position.x >= 0.0 and loot_panel.position.y >= 0.0, "Loot panel begins inside the playable viewport")
	_assert_true(loot_panel.position.x + loot_panel.size.x <= viewport_size.x, "Loot panel right edge remains inside the playable viewport")
	_assert_true(loot_panel.position.y + loot_panel.size.y <= viewport_size.y, "Loot panel bottom edge remains inside the playable viewport")
	_assert_eq(controller.item_instance_index().snapshot_count(), 12, "index registers player sword and all eleven NPC items")
	var player_primary: EquippedWeaponRef = controller.player_runtime().state.equipment.primary_weapon()
	_assert_eq(controller.item_instance_index().resolve(player_primary.instance_id).item_definition_id, OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID, "player prototype long sword is indexed")
	var expected_maximum: int = CharacterDerivedValues.maximum_encumbrance(controller.player_runtime().state.attributes.strength)
	_assert_eq(controller.player_runtime().maximum_encumbrance, expected_maximum, "scene stores setup-time strength * 5000 capacity")
	var initial_strength: int = controller.player_runtime().state.attributes.strength
	controller.player_runtime().state.attributes.strength = initial_strength + 10
	_assert_eq(controller.player_runtime().maximum_encumbrance, expected_maximum, "scene capacity remains setup snapshot after strength mutation")

	var victim: NpcRuntimeState = controller.npc_runtimes()[0]
	var death_position: Vector2 = controller.bandit_bodies[0].global_position
	await _kill_bandit(controller, victim, tree)
	_assert_eq(controller.corpse_states().size(), 1, "bandit death creates one corpse authority")
	_assert_true(controller.selected_interaction_target() != null and controller.selected_interaction_target().kind == WorldInteractionTarget.Kind.CHARACTER, "death preserves the prior Bandit target until corpse picking")
	var corpse: CorpseState = controller.corpse_states()[0]
	var view: CombatSliceCorpseView = controller.corpse_view_for(corpse.corpse_item_instance_id)
	_assert_true(view != null and view.global_position == death_position, "corpse view retains captured death position")
	_assert_eq(view.selection_requested.get_connections().size(), 1, "completed corpse picking connects exactly once")
	_assert_eq(view.loot_range_changed.get_connections().size(), 1, "completed corpse range connects exactly once")
	_assert_true(controller.item_instance_index().has_snapshot(corpse.corpse_item_instance_id), "death boundary indexes generated corpse identity")
	_assert_eq(controller.item_instance_index().snapshot_count(), 13, "corpse adds one index snapshot without replacing loot")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	view.picking_area().input_event.emit(controller.get_viewport(), click, 0)
	var selected: WorldInteractionTarget = controller.selected_interaction_target()
	_assert_eq(selected.kind, WorldInteractionTarget.Kind.ITEM, "corpse click selects ITEM kind")
	_assert_eq(selected.target_id, corpse.corpse_item_instance_id, "corpse click selects exact corpse ID")
	_assert_false(controller.hud.attack_is_enabled(), "corpse selection disables Attack")
	_assert_false(controller.hud.portal_action_is_enabled(), "corpse selection disables Traverse")
	_assert_false(controller.hud.open_loot_is_enabled(), "Open Loot is disabled outside physical range")
	_assert_true(controller.inspect_selected(), "corpse Inspect remains available outside loot range")
	_assert_true(controller.hud.inspection_display().contains("Contents: 2"), "corpse Inspect reads live content count")
	controller._on_central_clearing_body_entered(controller.player_body)
	_assert_true(controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID), "Corpse to Pine target switch succeeds")
	_assert_eq(controller.selected_interaction_target().kind, WorldInteractionTarget.Kind.LANDMARK, "Pine uses LANDMARK target")
	_assert_true(controller.hud.portal_action_is_enabled(), "Pine exposes Traverse without stale corpse action")
	_assert_false(controller.hud.attack_is_enabled(), "Pine clears stale Attack")
	_assert_false(controller.hud.open_loot_is_enabled(), "Pine clears stale Open Loot")
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "Pine to Corpse target switch succeeds")
	_assert_eq(controller.selected_interaction_target().kind, WorldInteractionTarget.Kind.ITEM, "Corpse restores exact ITEM target")
	_assert_true(controller.select_npc(controller.npc_runtimes()[1].character_id), "Corpse to living Bandit target switch succeeds")
	_assert_eq(controller.selected_interaction_target().kind, WorldInteractionTarget.Kind.CHARACTER, "living Bandit restores CHARACTER target")
	_assert_true(controller.hud.attack_is_enabled(), "living Bandit exposes Attack")
	_assert_false(controller.hud.portal_action_is_enabled(), "Bandit clears stale Traverse")
	_assert_false(controller.hud.open_loot_is_enabled(), "Bandit clears stale Open Loot")
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "Bandit to Corpse target switch succeeds")

	controller.player_body.global_position = view.global_position
	await tree.physics_frame
	await tree.physics_frame
	_assert_true(view.is_body_in_loot_range(controller.player_body), "physical Area detects player near corpse")
	_assert_true(controller.hud.open_loot_is_enabled(), "entering physical range enables Open Loot")
	controller.hud.open_loot_button.pressed.emit()
	_assert_true(controller.hud.loot_is_open(), "loot panel is visible")
	var rows: Array[WorldItemRowProjection] = controller.hud.loot_rows()
	_assert_eq(rows.size(), 2, "live panel shows two corpse direct children")
	var projected_ids: Array[StringName] = []
	for row: WorldItemRowProjection in rows:
		projected_ids.append(row.item_instance_id)
	_assert_eq(
		projected_ids,
		controller.inventory_state().direct_children(_corpse_endpoint(corpse)),
		"loot panel preserves authoritative direct-child ordering",
	)
	var sword_id: StringName = _row_id_for_definition(rows, OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)
	var silver_id: StringName = _row_id_for_definition(rows, OldPineItemContentDefinitions.SILVER_ITEM_ID)
	_assert_false(sword_id.is_empty(), "panel shows authored 短剑 row")
	_assert_false(silver_id.is_empty(), "panel shows authored 银子 row")
	var silver_row: WorldItemRowProjection = _row_for_id(rows, silver_id)
	_assert_true(silver_row != null, "silver row resolves by stable instance ID")
	if silver_row != null:
		_assert_eq(silver_row.amount, 3, "panel reads live silver amount three")
	var stale_sword_button: Button = _take_button_for_row_id(
		controller.hud.loot_panel, rows, sword_id
	)
	_assert_true(stale_sword_button != null, "live sword row creates a Take button bound to its row")

	controller.player_body.global_position += Vector2(300.0, 0.0)
	await tree.physics_frame
	await tree.physics_frame
	_assert_false(view.is_body_in_loot_range(controller.player_body), "leaving range updates scene adapter")
	stale_sword_button.pressed.emit()
	var rejected: CorpseLootTransferResult = controller.last_loot_transfer_result()
	_assert_eq(rejected.outcome, CorpseLootTransferResult.Outcome.OUT_OF_RANGE, "open panel cannot bypass execution-time range")
	_assert_eq(rejected.requested_item_instance_id, sword_id, "stale row button carries exact sword ItemInstanceId")
	_assert_true(controller.hud.loot_is_open(), "out-of-range rejection keeps an honest refreshable panel")
	_assert_eq(controller.hud.loot_rows().size(), 2, "out-of-range rejection rebuilds unchanged live corpse rows")
	_assert_eq(controller.player_runtime().busy.busy_value, 0, "out-of-range rejection starts no busy")
	controller.player_body.global_position = view.global_position
	await tree.physics_frame
	await tree.physics_frame

	var random: CountingCombatRandomSource = CountingCombatRandomSource.new()
	controller.configure_combat_random_source(random)
	var refreshed_rows: Array[WorldItemRowProjection] = controller.hud.loot_rows()
	var sword_button: Button = _take_button_for_row_id(
		controller.hud.loot_panel, refreshed_rows, sword_id
	)
	_assert_true(sword_button != null, "refreshed sword row recreates its exact Take button")
	sword_button.pressed.emit()
	var sword_take: CorpseLootTransferResult = controller.last_loot_transfer_result()
	_assert_true(sword_take.succeeded, "scene Take transfers short sword")
	_assert_eq(sword_take.requested_item_instance_id, sword_id, "successful row signal preserves exact sword ItemInstanceId")
	_assert_true(controller.inventory_state().is_direct_child(sword_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, controller.player_runtime().character_id)), "same sword instance is player direct inventory")
	_assert_eq(controller.player_runtime().state.equipment.primary_weapon().instance_id, player_primary.instance_id, "scene Take does not auto-wield short sword")
	_assert_eq(controller.hud.loot_rows().size(), 1, "panel rebuild removes taken sword row")
	_assert_true(controller.inspect_selected(), "corpse remains inspectable after one Take")
	_assert_true(controller.hud.inspection_display().contains("Contents: 1"), "corpse Inspect count updates live from two to one")
	if sword_take.busy_started:
		controller.player_runtime().busy.advance()
	var silver_take: CorpseLootTransferResult = controller.take_selected_loot_item(silver_id)
	_assert_true(silver_take.succeeded, "scene Take transfers amount-three silver")
	_assert_eq(controller.stack_collection().stack_state(silver_id).amount, 3, "scene silver amount remains three")
	_assert_true(controller.hud.loot_rows().is_empty(), "panel rebuild shows empty corpse")
	_assert_true(controller.inspect_selected(), "empty corpse remains inspectable")
	_assert_true(controller.hud.inspection_display().contains("Contents: 0"), "corpse Inspect count updates live from one to zero")
	_assert_true(controller.inventory_state().is_registered(corpse.corpse_item_instance_id), "empty scene corpse remains live")
	_assert_true(view.visible, "empty corpse remains visible")
	_assert_eq(random.calls, 0, "Open/Take/merge consume zero Combat RNG")
	_assert_true(controller.npc_runtimes()[1].exists_in_map and controller.npc_runtimes()[2].exists_in_map, "other bandits remain after looting")
	_assert_true(controller.is_inside_tree(), "map continues without reload")
	_assert_true(controller.select_landmark(OldPineLandmarkDefinitions.PINE_LANDMARK_ID), "corpse to Pine target switch remains available")
	_assert_false(controller.hud.open_loot_is_enabled(), "Pine target clears stale Open Loot")
	_assert_false(controller.hud.loot_is_open(), "target switch closes stale loot panel")
	_assert_true(controller.select_npc(controller.npc_runtimes()[1].character_id), "Pine to Bandit target switch remains available")
	_assert_false(controller.hud.open_loot_is_enabled(), "Bandit target never exposes Open Loot")
	var npc_random_after_loot: int = controller.npc_random_source().next_below(1000)
	_assert_true(controller.select_corpse(corpse.corpse_item_instance_id), "empty corpse remains selectable before liveness removal test")
	_assert_true(controller.open_selected_loot(), "empty corpse can reopen an Empty panel")
	_assert_true(controller.inventory_state()._remove_registered_leaf(corpse.corpse_item_instance_id), "stale-corpse fixture removes only live authority after empty proof")
	await tree.process_frame
	await tree.process_frame
	_assert_true(controller.selected_interaction_target() == null, "stale selected corpse clears ITEM target")
	_assert_false(controller.hud.open_loot_is_enabled(), "stale selected corpse clears Open Loot action")
	_assert_false(controller.hud.loot_is_open(), "stale selected corpse closes its panel")

	var old_corpse_id: StringName = corpse.corpse_item_instance_id
	controller.queue_free()
	await tree.process_frame
	var fresh: OldPineOutdoorController = _instantiate_scene(tree)
	await tree.physics_frame
	_assert_true(fresh.selected_interaction_target() == null, "fresh scene clears ITEM target")
	_assert_false(fresh.hud.loot_is_open(), "fresh scene closes loot panel")
	_assert_eq(fresh.corpse_states().size(), 0, "fresh scene clears corpses")
	_assert_eq(fresh.item_instance_index().snapshot_count(), 12, "fresh scene rebuilds only initial item index")
	_assert_false(fresh.item_instance_index().has_snapshot(old_corpse_id), "fresh scene has no stale corpse identity")
	_assert_eq(fresh.npc_runtimes().size(), 5, "fresh scene restores all five bandits")
	_assert_eq(fresh.npc_random_source().next_below(1000), npc_random_after_loot, "loot consumes zero NPC initialization RNG")
	fresh.queue_free()
	await tree.process_frame


func _make_fixture(
	item_definition_id: StringName,
	own_weight: int,
	maximum_encumbrance: int,
	stack_amount: int = -1,
) -> LootFixture:
	var fixture: LootFixture = LootFixture.new()
	fixture.player = _make_player(maximum_encumbrance)
	fixture.inventory = InventoryState.new()
	fixture.stacks = CombinedStackCollection.new()
	fixture.item_index = WorldItemInstanceIndex.new()
	fixture.adapter = OldPineCorpseLootAdapter.new()
	fixture.corpse = CorpseState.new(&"corpse", &"victim", "土匪探哨", &"男性", 19, 50000)
	var corpse_item: ItemInstance = ItemInstance.new(&"corpse", CombatSliceDeathAdapter.CORPSE_DEFINITION_ID)
	fixture.inventory.register_item(corpse_item, 0)
	fixture.item_index.register_snapshot(corpse_item)
	InventoryTransferService.new().transfer(
		fixture.inventory,
		corpse_item.item_instance_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"oldpine.location"),
			true, true, 100000,
		),
	)
	fixture.item = ItemInstance.new(&"loot-item", item_definition_id)
	fixture.inventory.register_item(fixture.item, own_weight)
	fixture.item_index.register_snapshot(fixture.item)
	if stack_amount >= 0:
		CombinedStackService.register_stack(
			fixture.stacks,
			fixture.inventory,
			fixture.item,
			OldPineNpcDefinitions.silver_content().stack_definition(),
			stack_amount,
		)
	InventoryTransferService.new().transfer(
		fixture.inventory,
		fixture.item.item_instance_id,
		InventoryTransferDestination.new(
			_corpse_endpoint(fixture.corpse), true, true, 50000
		),
	)
	return fixture


func _add_player_silver(
	fixture: LootFixture,
	instance_id: StringName,
	amount: int,
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new(instance_id, OldPineItemContentDefinitions.SILVER_ITEM_ID)
	fixture.inventory.register_item(item, 0)
	fixture.item_index.register_snapshot(item)
	CombinedStackService.register_stack(
		fixture.stacks,
		fixture.inventory,
		item,
		OldPineNpcDefinitions.silver_content().stack_definition(),
		amount,
	)
	InventoryTransferService.new().transfer(
		fixture.inventory, item.item_instance_id,
		_player_destination(fixture.player.maximum_encumbrance),
	)
	return item


func _add_player_burden(
	fixture: LootFixture,
	instance_id: StringName,
	own_weight: int,
) -> bool:
	var item: ItemInstance = ItemInstance.new(
		instance_id, &"test:burden"
	)
	if not fixture.inventory.register_item(item, own_weight):
		return false
	if not fixture.item_index.register_snapshot(item):
		return false
	return InventoryTransferService.new().transfer(
		fixture.inventory,
		item.item_instance_id,
		_player_destination(fixture.player.maximum_encumbrance),
	).succeeded


func _make_player(maximum_encumbrance: int) -> WorldPlayerRuntimeState:
	var player_id: StringName = &"player"
	return WorldPlayerRuntimeState.new(
		player_id,
		CharacterState.new(),
		CombatRelationshipState.new(player_id),
		ActionBusyState.new(),
		ArmorState.new(),
		WorldLocationState.new(&"oldpine", &"outdoor", &"zone", &"oldpine.location"),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		maximum_encumbrance,
	)


func _player_destination(maximum_encumbrance: int) -> InventoryTransferDestination:
	return InventoryTransferDestination.new(
		_character_endpoint(), true, true, maximum_encumbrance
	)


func _character_endpoint() -> ContainmentEndpoint:
	return ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"player")


func _corpse_endpoint(corpse: CorpseState) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id
	)


func _row_id_for_definition(
	rows: Array[WorldItemRowProjection],
	definition_id: StringName,
) -> StringName:
	for row: WorldItemRowProjection in rows:
		if row.item_definition_id == definition_id:
			return row.item_instance_id
	return &""


func _row_for_id(
	rows: Array[WorldItemRowProjection],
	item_id: StringName,
) -> WorldItemRowProjection:
	for row: WorldItemRowProjection in rows:
		if row.item_instance_id == item_id:
			return row
	return null


func _take_button_for_row_id(
	panel: OldPineLootPanel,
	rows: Array[WorldItemRowProjection],
	item_id: StringName,
) -> Button:
	if panel == null:
		return null
	for index: int in range(rows.size()):
		if rows[index].item_instance_id != item_id:
			continue
		var row_node: BoxContainer = (
			panel.row_container.get_child(index) as BoxContainer
		)
		if row_node == null or row_node.get_child_count() < 2:
			return null
		return row_node.get_child(1) as Button
	return null


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
	controller.configure_combat_random_source(MaximumCombatRandomSource.new())
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


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
