class_name NativeItemPersistenceComposition
extends RefCounted


static func capture(
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_index: WorldItemInstanceIndex,
	equipment_sources: Array[NativeCharacterEquipmentSource],
	armor_sources: Array[NativeCharacterArmorSource],
	definitions: NativeItemDefinitionProjections,
) -> NativeItemSnapshotCaptureResult:
	if inventory == null or stacks == null or item_index == null:
		return _capture_failure(
			NativeItemStateValidationResult.Outcome.INVALID_SNAPSHOT
		)
	var items: Array[ItemInstance] = []
	for item_instance_id: StringName in inventory.registered_item_ids():
		var item: ItemInstance = item_index.resolve(item_instance_id)
		if item == null:
			return _capture_failure(
				NativeItemStateValidationResult.Outcome.UNREPRESENTED_REGISTERED_ITEM,
				item_instance_id,
			)
		items.append(item)
	return NativeItemStateCapture.capture(
		items,
		inventory,
		stacks,
		equipment_sources,
		armor_sources,
		definitions,
	)


static func restore(
	snapshot: NativeItemStateSnapshot,
	definitions: NativeItemDefinitionProjections,
	allocator_snapshot: GameSaveValueTypes.ItemIdAllocatorSnapshot,
) -> NativeItemRestoreCompositionResult:
	var item_restore: NativeItemStateRestoreResult = NativeItemStateRestorer.restore(
		snapshot,
		definitions,
	)
	if not item_restore.succeeded:
		return NativeItemRestoreCompositionResult.new(
			null,
			null,
			null,
			item_restore.validation_result,
		)
	var domain: NativeItemDomainState = item_restore.reconstructed_state
	var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
	for item_instance_id: StringName in domain.item_instance_ids():
		if not index.register_snapshot(domain.item_instance(item_instance_id)):
			return NativeItemRestoreCompositionResult.new(
				null,
				null,
				null,
				NativeItemStateValidationResult.new(
					NativeItemStateValidationResult.Outcome.RECONSTRUCTION_FAILED,
					item_instance_id,
				),
			)
	var allocator_restore: SessionItemIdAllocatorRestoreResult = (
		SessionItemIdAllocator.restore(
			allocator_snapshot,
			domain.item_instance_ids(),
		)
	)
	if not allocator_restore.succeeded:
		return NativeItemRestoreCompositionResult.new(
			null,
			null,
			null,
			item_restore.validation_result,
			allocator_restore,
		)
	return NativeItemRestoreCompositionResult.new(
		domain,
		index,
		allocator_restore.allocator,
		item_restore.validation_result,
		allocator_restore,
	)


static func _capture_failure(
	outcome: int,
	subject_id: StringName = &"",
) -> NativeItemSnapshotCaptureResult:
	return NativeItemSnapshotCaptureResult.new(
		null,
		NativeItemStateValidationResult.new(outcome, subject_id),
	)
