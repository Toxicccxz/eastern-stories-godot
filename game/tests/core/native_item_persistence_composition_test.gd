extends RefCounted

const CHARACTER_ID: StringName = &"oldpine.player"
const SCOPE: StringName = &"test-session"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_production_definition_projections()
	_test_graph_capture_restore_and_continuation()
	_test_allocator_restore_boundaries()
	_test_allocator_allocation_boundaries()
	_test_allocator_consumes_zero_gameplay_rng()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_production_definition_projections() -> void:
	var definitions: NativeItemDefinitionProjections = (
		OldPineNativeItemDefinitionProjections.create()
	)
	_assert_true(definitions.is_valid, "Old Pine production item projections validate")
	for definition_id: StringName in [
		OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
		OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID,
		OldPineItemContentDefinitions.SILVER_ITEM_ID,
		OldPineItemContentDefinitions.LEATHER_ITEM_ID,
		OldPineNativeItemDefinitionProjections.CORPSE_DEFINITION_ID,
	]:
		_assert_true(
			definitions.has_item_definition(definition_id),
			"playable definition is projected: %s" % String(definition_id),
		)
	_assert_true(
		definitions.weapon_definition(
			OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID
		) != null,
		"long sword weapon projection is available",
	)
	_assert_true(
		definitions.armor_definition(
			OldPineItemContentDefinitions.LEATHER_ITEM_ID
		) != null,
		"leather armor projection is available",
	)
	_assert_true(
		definitions.stack_definition(
			OldPineItemContentDefinitions.SILVER_ITEM_ID
		) != null,
		"silver stack projection is available",
	)


func _test_graph_capture_restore_and_continuation() -> void:
	var definitions: NativeItemDefinitionProjections = (
		OldPineNativeItemDefinitionProjections.create()
	)
	var inventory_a: InventoryState = InventoryState.new()
	var stacks_a: CombinedStackCollection = CombinedStackCollection.new()
	var index_a: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	var sword_a: ItemInstance = ItemInstance.new(
		&"test-session.player-long-sword",
		OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
	)
	var leather_a: ItemInstance = ItemInstance.new(
		&"test-session.player-leather",
		OldPineItemContentDefinitions.LEATHER_ITEM_ID,
	)
	var silver_a: ItemInstance = ItemInstance.new(
		&"test-session.dynamic.2",
		OldPineItemContentDefinitions.SILVER_ITEM_ID,
	)
	var items_a: Array[ItemInstance] = [sword_a, leather_a, silver_a]
	var weights: Array[int] = [7_000, 6_000, 111]
	for index: int in range(items_a.size()):
		var item: ItemInstance = items_a[index]
		_assert_true(
			inventory_a.register_item(item, weights[index]),
			"graph A item registers",
		)
		_assert_true(index_a.register_snapshot(item), "graph A item index registers")
		_assert_true(_place_on_character(inventory_a, item.item_instance_id), "graph A item is direct inventory")
	_assert_true(
		stacks_a._register_stack(
			CombinedStackState.new(silver_a.item_instance_id, 3),
			definitions.stack_definition(silver_a.item_definition_id),
		),
		"graph A silver mutable amount registers",
	)
	var equipment_a: EquipmentState = EquipmentState.new()
	_assert_true(
		equipment_a._restore_weapons(
			EquippedWeaponRef.new(
				sword_a.item_instance_id,
				definitions.weapon_definition(sword_a.item_definition_id),
			),
			null,
		),
		"graph A equipment authority restores",
	)
	var armor_a: ArmorState = ArmorState.new()
	_assert_true(
		armor_a._restore_equipped_refs([
			EquippedArmorRef.new(
				leather_a.item_instance_id,
				definitions.armor_definition(leather_a.item_definition_id),
			),
		]),
		"graph A armor authority restores",
	)
	var equipment_sources: Array[NativeCharacterEquipmentSource] = [
		NativeCharacterEquipmentSource.new(CHARACTER_ID, equipment_a),
	]
	var armor_sources: Array[NativeCharacterArmorSource] = [
		NativeCharacterArmorSource.new(CHARACTER_ID, armor_a),
	]
	var capture: NativeItemSnapshotCaptureResult = NativeItemPersistenceComposition.capture(
		inventory_a,
		stacks_a,
		index_a,
		equipment_sources,
		armor_sources,
		definitions,
	)
	_assert_true(capture.succeeded, "runtime authorities compose into Phase4 snapshot v1")
	if not capture.succeeded:
		return
	_assert_eq(capture.snapshot.schema_version, 1, "composition reuses native item schema v1")
	var restored: NativeItemRestoreCompositionResult = NativeItemPersistenceComposition.restore(
		capture.snapshot,
		definitions,
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 1),
	)
	_assert_true(restored.succeeded, "snapshot restores into fresh graph B")
	if not restored.succeeded:
		return
	var domain_b: NativeItemDomainState = restored.domain_state
	_assert_true(domain_b.inventory != inventory_a, "graph B has a fresh InventoryState")
	_assert_true(domain_b.combined_stacks != stacks_a, "graph B has a fresh stack collection")
	_assert_true(restored.item_index != index_a, "graph B has a fresh derived item index")
	_assert_eq(domain_b.item_instance_ids(), inventory_a.registered_item_ids(), "semantic item IDs survive exactly")
	_assert_eq(restored.item_index.snapshot_ids(), domain_b.inventory.registered_item_ids(), "fresh item index exactly matches restored Inventory")
	_assert_true(domain_b.item_instance(sword_a.item_instance_id) != sword_a, "same semantic sword has new runtime identity")
	_assert_true(restored.item_index.resolve(silver_a.item_instance_id) != silver_a, "derived index owns fresh runtime snapshots")
	var equipment_b: EquipmentState = domain_b.equipment_state(CHARACTER_ID)
	var armor_b: ArmorState = domain_b.armor_state(CHARACTER_ID)
	_assert_true(equipment_b != equipment_a, "restored EquipmentState is fresh")
	_assert_true(armor_b != armor_a, "restored ArmorState is fresh")
	_assert_true(equipment_b == domain_b.equipment_state(CHARACTER_ID), "one exact restored EquipmentState is injectable")
	_assert_true(armor_b == domain_b.armor_state(CHARACTER_ID), "one exact restored ArmorState is injectable")
	_assert_eq(equipment_b.primary_weapon().instance_id, sword_a.item_instance_id, "equipment semantic reference survives")
	_assert_eq(armor_b.equipped_ref_in_slot(&"cloth").item_instance_id, leather_a.item_instance_id, "armor semantic reference survives")
	_assert_eq(domain_b.combined_stacks.stack_state(silver_a.item_instance_id).amount, 3, "combined amount survives")
	_assert_eq(restored.allocator.next_dynamic_sequence, 3, "stale saved continuation advances past represented ID")
	for expected_sequence: int in range(3, 8):
		var allocated: SessionItemIdAllocationResult = restored.allocator.allocate(
			domain_b.inventory
		)
		_assert_true(allocated.succeeded, "post-restore allocation succeeds")
		_assert_eq(
			allocated.item_instance_id,
			StringName("test-session.dynamic.%d" % expected_sequence),
			"post-restore ID continues exactly",
		)
		_assert_true(
			domain_b.inventory.register_item(
				ItemInstance.new(
					allocated.item_instance_id,
					OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
				),
				7_000,
			),
			"allocated ID has no collision",
		)

	var incomplete_index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	_assert_true(incomplete_index.register_snapshot(sword_a), "incomplete index fixture registers")
	var failed_capture: NativeItemSnapshotCaptureResult = NativeItemPersistenceComposition.capture(
		inventory_a,
		stacks_a,
		incomplete_index,
		equipment_sources,
		armor_sources,
		definitions,
	)
	_assert_false(failed_capture.succeeded, "capture rejects an incomplete derived index")
	_assert_eq(
		failed_capture.validation_result.outcome,
		NativeItemStateValidationResult.Outcome.UNREPRESENTED_REGISTERED_ITEM,
		"missing indexed item uses existing Phase4 validation taxonomy",
	)


func _test_allocator_restore_boundaries() -> void:
	var stale: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 2),
		[&"test-session.dynamic.7", &"test-session.authored"],
	)
	_assert_true(stale.succeeded, "stale allocator snapshot restores")
	_assert_eq(stale.allocator.next_dynamic_sequence, 8, "stale sequence advances past same-scope represented ID")
	var future: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 20),
		[&"test-session.dynamic.7"],
	)
	_assert_true(future.succeeded, "future allocator snapshot restores")
	_assert_eq(future.allocator.next_dynamic_sequence, 20, "restore never decreases a future saved continuation")
	var other_scope: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 4),
		[&"other-session.dynamic.99"],
	)
	_assert_eq(other_scope.allocator.next_dynamic_sequence, 4, "other-scope dynamic IDs do not affect continuation")
	for malformed_id: StringName in [
		&"test-session.dynamic",
		&"test-session.dynamicx",
		&"test-session.dynamic.",
		&"test-session.dynamic.nope",
		&"test-session.dynamic.01",
		&"test-session.dynamic.-1",
	]:
		var malformed: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
			GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 0),
			[malformed_id],
		)
		_assert_eq(
			malformed.outcome,
			SessionItemIdAllocatorRestoreResult.Outcome.MALFORMED_SAME_SCOPE_ID,
			"malformed same-scope dynamic ID fails: %s" % String(malformed_id),
		)
	var duplicate: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 0),
		[&"same-id", &"same-id"],
	)
	_assert_eq(duplicate.outcome, SessionItemIdAllocatorRestoreResult.Outcome.DUPLICATE_REPRESENTED_ID, "duplicate semantic IDs fail allocator restore")
	var represented_max: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 0),
		[&"test-session.dynamic.9223372036854775807"],
	)
	_assert_eq(represented_max.outcome, SessionItemIdAllocatorRestoreResult.Outcome.SEQUENCE_OVERFLOW, "represented INT64_MAX cannot produce a continuation")


func _test_allocator_allocation_boundaries() -> void:
	var inventory: InventoryState = InventoryState.new()
	var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(SCOPE, 0)
	_assert_true(
		inventory.register_item(
			ItemInstance.new(
				&"test-session.dynamic.0",
				OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID,
			),
			7_000,
		),
		"collision fixture registers",
	)
	var collision: SessionItemIdAllocationResult = allocator.allocate(inventory)
	_assert_eq(collision.outcome, SessionItemIdAllocationResult.Outcome.COLLISION, "allocation checks Inventory before commit")
	_assert_eq(allocator.next_dynamic_sequence, 0, "collision consumes no sequence")
	var maximum: SessionItemIdAllocator = SessionItemIdAllocator.new(
		SCOPE,
		9223372036854775807,
	)
	var overflow: SessionItemIdAllocationResult = maximum.allocate(InventoryState.new())
	_assert_eq(overflow.outcome, SessionItemIdAllocationResult.Outcome.SEQUENCE_OVERFLOW, "INT64_MAX allocation fails")
	_assert_eq(maximum.next_dynamic_sequence, 9223372036854775807, "overflow does not wrap or mutate continuation")


func _test_allocator_consumes_zero_gameplay_rng() -> void:
	var combat: GodotCombatRandomSource = GodotCombatRandomSource.new(1001, true)
	var npc: GodotNpcInitializationRandomSource = GodotNpcInitializationRandomSource.new(1002, true)
	var world: GodotWorldInteractionRandomSource = GodotWorldInteractionRandomSource.new(1003, true)
	var combat_before: RandomStreamSnapshot = combat.capture_random_state()
	var npc_before: RandomStreamSnapshot = npc.capture_random_state()
	var world_before: RandomStreamSnapshot = world.capture_random_state()
	var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(SCOPE)
	for ignored: int in range(4):
		_assert_true(allocator.allocate(InventoryState.new()).succeeded, "allocator produces ID without an RNG dependency")
	var combat_after: RandomStreamSnapshot = combat.capture_random_state()
	var npc_after: RandomStreamSnapshot = npc.capture_random_state()
	var world_after: RandomStreamSnapshot = world.capture_random_state()
	_assert_eq(combat_after.state, combat_before.state, "allocation consumes zero Combat RNG")
	_assert_eq(npc_after.state, npc_before.state, "allocation consumes zero NPC-initialization RNG")
	_assert_eq(world_after.state, world_before.state, "allocation consumes zero WorldInteraction RNG")


func _place_on_character(inventory: InventoryState, item_id: StringName) -> bool:
	return InventoryTransferService.new().transfer(
		inventory,
		item_id,
		InventoryTransferDestination.new(
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, CHARACTER_ID),
			true,
			true,
			1_000_000,
		),
	).succeeded


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append(
			"%s (expected %s, got %s)" % [message, str(expected), str(actual)]
		)
