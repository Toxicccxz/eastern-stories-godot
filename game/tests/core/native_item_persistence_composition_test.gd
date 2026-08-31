extends RefCounted

const SessionItemIdScopeFactoryType := preload(
	"res://core/persistence/session_item_id_scope_factory.gd"
)

const CHARACTER_ID: StringName = &"oldpine.player"
const SCOPE: StringName = &"test-session"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_production_definition_projections()
	_test_graph_capture_restore_and_continuation()
	_test_allocator_restore_boundaries()
	_test_allocator_allocation_boundaries()
	_test_scope_generation()
	_test_duplicate_registration_does_not_overwrite()
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
	var corpse_a: ItemInstance = ItemInstance.new(
		&"test-session.dynamic.2",
		OldPineNativeItemDefinitionProjections.CORPSE_DEFINITION_ID,
	)
	var silver_a: ItemInstance = ItemInstance.new(
		&"test-session.authored-silver",
		OldPineItemContentDefinitions.SILVER_ITEM_ID,
	)
	var items_a: Array[ItemInstance] = [sword_a, leather_a, corpse_a, silver_a]
	var weights: Array[int] = [7_000, 6_000, 456, 111]
	for index: int in range(items_a.size()):
		var item: ItemInstance = items_a[index]
		_assert_true(
			inventory_a.register_item(item, weights[index]),
			"graph A item registers",
		)
		_assert_true(index_a.register_snapshot(item), "graph A item index registers")
	_assert_true(_place_on_character(inventory_a, sword_a.item_instance_id), "graph A sword is direct inventory")
	_assert_true(_place_on_character(inventory_a, leather_a.item_instance_id), "graph A leather is direct inventory")
	_assert_true(
		_place_at(
			inventory_a,
			corpse_a.item_instance_id,
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"oldpine.outdoor"),
		),
		"graph A corpse is placed in the world",
	)
	_assert_true(
		_place_at(
			inventory_a,
			silver_a.item_instance_id,
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_a.item_instance_id),
		),
		"graph A silver is nested in the corpse",
	)
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
	var graph_a_ids_before: Array[StringName] = inventory_a.registered_item_ids()
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
	for index: int in range(items_a.size()):
		var item: ItemInstance = items_a[index]
		_assert_eq(
			domain_b.inventory.own_weight(item.item_instance_id),
			weights[index],
			"own weight survives exactly: %s" % String(item.item_instance_id),
		)
	_assert_true(
		domain_b.inventory.is_direct_child(
			corpse_a.item_instance_id,
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"oldpine.outdoor"),
		),
		"world containment survives exactly",
	)
	_assert_true(
		domain_b.inventory.is_direct_child(
			silver_a.item_instance_id,
			ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_a.item_instance_id),
		),
		"nested containment survives exactly",
	)
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
	_assert_eq(inventory_a.registered_item_ids(), graph_a_ids_before, "failed capture does not mutate graph A registration")
	_assert_true(inventory_a.is_direct_child(silver_a.item_instance_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_a.item_instance_id)), "failed capture does not mutate graph A containment")

	var unknown_snapshot: NativeItemStateSnapshot = NativeItemStateSnapshot.new(
		NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION,
		[
			NativeItemRecord.new(
				&"unknown-instance",
				&"unknown-definition",
				1,
				ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"oldpine.outdoor"),
			),
		],
	)
	var unknown_restore: NativeItemRestoreCompositionResult = NativeItemPersistenceComposition.restore(
		unknown_snapshot,
		definitions,
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 0),
	)
	_assert_false(unknown_restore.succeeded, "unknown definitions fail strict production restore")
	_assert_eq(unknown_restore.item_validation.outcome, NativeItemStateValidationResult.Outcome.UNKNOWN_ITEM_DEFINITION, "unknown definition uses strict Phase4 failure")
	_assert_eq(inventory_a.registered_item_ids().size(), 4, "failed restore cannot mutate existing graph A")


func _test_allocator_restore_boundaries() -> void:
	var exact_stale: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 5),
		[&"test-session.dynamic.12"],
	)
	_assert_eq(exact_stale.allocator.next_dynamic_sequence, 13, "saved 5 with represented 12 restores to 13")
	var exact_future: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 20),
		[&"test-session.dynamic.12"],
	)
	_assert_eq(exact_future.allocator.next_dynamic_sequence, 20, "saved 20 with represented 12 remains 20")
	var zero: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 0),
		[&"test-session.dynamic.0"],
	)
	_assert_eq(zero.allocator.next_dynamic_sequence, 1, "represented zero advances to one")
	var large: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 0),
		[&"test-session.dynamic.9223372036854775806"],
	)
	_assert_eq(large.allocator.next_dynamic_sequence, SessionItemIdAllocator.MAX_SEQUENCE, "largest continuable represented sequence reaches exact max")
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
		&"test-session.dynamic.",
		&"test-session.dynamic.nope",
		&"test-session.dynamic.01",
		&"test-session.dynamic.-1",
		&"test-session.dynamic.1.extra",
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
	for authored_id: StringName in [
		&"test-session.dynamic-sword",
		&"test-session.dynamically-authored",
		&"test-session.authored.dynamic.9",
	]:
		var authored: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
			GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, 4),
			[authored_id],
		)
		_assert_true(authored.succeeded, "similarly named authored ID is not claimed by dynamic namespace")
		_assert_eq(authored.allocator.next_dynamic_sequence, 4, "authored ID does not change continuation")
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
	var restored_large: SessionItemIdAllocatorRestoreResult = SessionItemIdAllocator.restore(
		GameSaveValueTypes.ItemIdAllocatorSnapshot.new(SCOPE, SessionItemIdAllocator.MAX_SEQUENCE),
		[],
	)
	var restored_overflow: SessionItemIdAllocationResult = restored_large.allocator.allocate(InventoryState.new())
	_assert_eq(restored_overflow.outcome, SessionItemIdAllocationResult.Outcome.SEQUENCE_OVERFLOW, "restored max continuation fails allocation")


func _test_scope_generation() -> void:
	var deterministic_entropy: PackedByteArray = PackedByteArray()
	for value: int in range(SessionItemIdScopeFactoryType.ENTROPY_BYTE_COUNT):
		deterministic_entropy.append(value)
	_assert_eq(
		SessionItemIdScopeFactoryType.old_pine_scope_from_entropy(deterministic_entropy),
		&"oldpine-session-000102030405060708090a0b0c0d0e0f",
		"scope uses stable prefix plus the complete 128-bit entropy",
	)
	_assert_eq(SessionItemIdScopeFactoryType.old_pine_scope_from_entropy(PackedByteArray([1])), &"", "wrong entropy length fails closed")
	var generated: Dictionary[StringName, bool] = {}
	for ignored: int in range(64):
		var scope: StringName = SessionItemIdScopeFactoryType.create_old_pine_scope()
		_assert_true(String(scope).begins_with(SessionItemIdScopeFactoryType.OLD_PINE_PREFIX), "generated scope has stable prefix")
		_assert_eq(String(scope).length(), SessionItemIdScopeFactoryType.OLD_PINE_PREFIX.length() + SessionItemIdScopeFactoryType.ENTROPY_BYTE_COUNT * 2, "generated scope has complete entropy")
		_assert_false(generated.has(scope), "rapid session scopes do not repeat")
		generated[scope] = true


func _test_duplicate_registration_does_not_overwrite() -> void:
	var inventory: InventoryState = InventoryState.new()
	var original: ItemInstance = ItemInstance.new(&"duplicate-id", OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID)
	var replacement: ItemInstance = ItemInstance.new(&"duplicate-id", OldPineItemContentDefinitions.SHORT_SWORD_ITEM_ID)
	_assert_true(inventory.register_item(original, 7_000), "Inventory accepts first semantic ID")
	_assert_false(inventory.register_item(replacement, 1), "Inventory rejects duplicate semantic ID")
	_assert_eq(inventory.own_weight(original.item_instance_id), 7_000, "Inventory duplicate cannot overwrite existing facts")
	var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	_assert_true(index.register_snapshot(original), "index accepts first semantic ID")
	_assert_false(index.register_snapshot(replacement), "index rejects duplicate semantic ID")
	_assert_eq(index.resolve(original.item_instance_id).item_definition_id, original.item_definition_id, "index duplicate cannot overwrite existing projection")


func _test_allocator_consumes_zero_gameplay_rng() -> void:
	var combat: GodotCombatRandomSource = GodotCombatRandomSource.new(1001, true)
	var npc: GodotNpcInitializationRandomSource = GodotNpcInitializationRandomSource.new(1002, true)
	var world: GodotWorldInteractionRandomSource = GodotWorldInteractionRandomSource.new(1003, true)
	var combat_before: RandomStreamSnapshot = combat.capture_random_state()
	var npc_before: RandomStreamSnapshot = npc.capture_random_state()
	var world_before: RandomStreamSnapshot = world.capture_random_state()
	var generated_scope: StringName = SessionItemIdScopeFactoryType.create_old_pine_scope()
	_assert_false(generated_scope.is_empty(), "scope generation succeeds independently of gameplay RNG")
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
	return _place_at(
		inventory,
		item_id,
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, CHARACTER_ID),
	)


func _place_at(
	inventory: InventoryState,
	item_id: StringName,
	endpoint: ContainmentEndpoint,
) -> bool:
	return InventoryTransferService.new().transfer(
		inventory,
		item_id,
		InventoryTransferDestination.new(
			endpoint,
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
