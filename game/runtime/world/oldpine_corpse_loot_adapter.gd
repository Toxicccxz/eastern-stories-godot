class_name OldPineCorpseLootAdapter
extends RefCounted

enum OpenValidation {
	READY,
	INVALID_REQUEST,
	PLAYER_NOT_AVAILABLE,
	CORPSE_NOT_AVAILABLE,
	OUT_OF_RANGE,
	CONTENT_UNAVAILABLE,
}


func validate_open(
	player: WorldPlayerRuntimeState,
	corpse: CorpseState,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
	player_in_range: bool,
) -> int:
	if player == null or corpse == null or inventory == null or item_index == null:
		return OpenValidation.INVALID_REQUEST
	if not player.is_valid() or not player.exists_in_world:
		return OpenValidation.PLAYER_NOT_AVAILABLE
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return OpenValidation.PLAYER_NOT_AVAILABLE
	if not _corpse_is_available(corpse, inventory, item_index):
		return OpenValidation.CORPSE_NOT_AVAILABLE
	if not player_in_range:
		return OpenValidation.OUT_OF_RANGE
	if not contents_are_resolvable(corpse, inventory, item_index):
		return OpenValidation.CONTENT_UNAVAILABLE
	return OpenValidation.READY


func contents_are_resolvable(
	corpse: CorpseState,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> bool:
	if corpse == null or inventory == null or item_index == null:
		return false
	var endpoint: ContainmentEndpoint = _corpse_endpoint(corpse)
	for item_id: StringName in inventory.direct_children(endpoint):
		var item: ItemInstance = item_index.resolve(item_id)
		if (
			item == null
			or OldPineItemContentDefinitions.content_by_id(item.item_definition_id) == null
		):
			return false
	return true


func project_rows(
	corpse: CorpseState,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_index: WorldItemInstanceIndex,
) -> Array[WorldItemRowProjection]:
	var rows: Array[WorldItemRowProjection] = []
	if (
		corpse == null
		or inventory == null
		or stacks == null
		or item_index == null
		or not contents_are_resolvable(corpse, inventory, item_index)
	):
		return rows
	for item_id: StringName in inventory.direct_children(_corpse_endpoint(corpse)):
		var item: ItemInstance = item_index.resolve(item_id)
		var content: OldPineItemContentDefinition = (
			OldPineItemContentDefinitions.content_by_id(item.item_definition_id)
		)
		var amount: int = 1
		if stacks.has_stack(item_id):
			amount = stacks.stack_state(item_id).amount
		var worn: bool = corpse.is_worn(item_id)
		rows.append(
			WorldItemRowProjection.new(
				item_id,
				item.item_definition_id,
				content.display_name,
				content.description,
				amount,
				content.category,
				not worn or corpse.is_legacy_character_for_equipment(),
				worn,
				worn and not corpse.is_legacy_character_for_equipment(),
			)
		)
	return rows


func take(
	player: WorldPlayerRuntimeState,
	corpse: CorpseState,
	requested_item_instance_id: StringName,
	player_in_range: bool,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_index: WorldItemInstanceIndex,
) -> CorpseLootTransferResult:
	var actor_id: StringName = &"" if player == null else player.character_id
	var corpse_id: StringName = (
		&"" if corpse == null else corpse.corpse_item_instance_id
	)
	if (
		player == null
		or corpse == null
		or inventory == null
		or stacks == null
		or item_index == null
		or actor_id.is_empty()
		or corpse_id.is_empty()
		or requested_item_instance_id.is_empty()
	):
		return _result(
			CorpseLootTransferResult.Outcome.INVALID_REQUEST,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if not player.is_valid() or not player.exists_in_world:
		return _result(
			CorpseLootTransferResult.Outcome.PLAYER_NOT_AVAILABLE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return _result(
			CorpseLootTransferResult.Outcome.PLAYER_NOT_AVAILABLE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if player.busy.is_busy():
		return _result(
			CorpseLootTransferResult.Outcome.PLAYER_BUSY,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if not _corpse_is_available(corpse, inventory, item_index):
		return _result(
			CorpseLootTransferResult.Outcome.CORPSE_NOT_AVAILABLE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if not player_in_range:
		return _result(
			CorpseLootTransferResult.Outcome.OUT_OF_RANGE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if not inventory.is_registered(requested_item_instance_id):
		return _result(
			CorpseLootTransferResult.Outcome.ITEM_NOT_AVAILABLE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	if not inventory.is_direct_child(
		requested_item_instance_id,
		_corpse_endpoint(corpse),
	):
		return _result(
			CorpseLootTransferResult.Outcome.ITEM_NOT_IN_CORPSE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)
	var item: ItemInstance = item_index.resolve(requested_item_instance_id)
	if (
		item == null
		or OldPineItemContentDefinitions.content_by_id(item.item_definition_id) == null
	):
		return _result(
			CorpseLootTransferResult.Outcome.CONTENT_UNAVAILABLE,
			actor_id,
			corpse_id,
			requested_item_instance_id,
		)

	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, actor_id),
		true,
		true,
		player.maximum_encumbrance,
	)
	var corpse_transfer: CorpseContentTransferResult = (
		CorpseContentTransferService.transfer_out(
			corpse,
			inventory,
			requested_item_instance_id,
			destination,
		)
	)
	if not corpse_transfer.succeeded:
		var failed_outcome: int = CorpseLootTransferResult.Outcome.TRANSFER_FAILED
		if (
			corpse_transfer.outcome
			== CorpseContentTransferResult.Outcome.CORPSE_WORN_LOCKED
		):
			failed_outcome = CorpseLootTransferResult.Outcome.CORPSE_WORN_LOCKED
		return CorpseLootTransferResult.new(
			failed_outcome,
			false,
			actor_id,
			corpse_id,
			requested_item_instance_id,
			corpse_transfer,
		)

	var merge: CombinedStackMergeResult = null
	var final_outcome: int = CorpseLootTransferResult.Outcome.COMPLETED
	var completed: bool = true
	if stacks.has_stack(requested_item_instance_id):
		merge = CombinedStackService.transfer_and_merge(
			stacks,
			inventory,
			requested_item_instance_id,
			destination,
			null,
			null,
			ItemLifecycleOwnerContext.new(actor_id, player.state.equipment, player.armor),
		)
		if not merge.succeeded:
			final_outcome = CorpseLootTransferResult.Outcome.PARTIAL_MERGE_FAILED
			completed = false
		elif merge.merge_applied:
			final_outcome = CorpseLootTransferResult.Outcome.COMPLETED_WITH_MERGE

	var busy_started: bool = false
	if player.relationship.is_fighting():
		busy_started = player.busy.start_busy(1)
	return CorpseLootTransferResult.new(
		final_outcome,
		completed,
		actor_id,
		corpse_id,
		requested_item_instance_id,
		corpse_transfer,
		merge,
		requested_item_instance_id,
		busy_started,
	)


func _corpse_is_available(
	corpse: CorpseState,
	inventory: InventoryState,
	item_index: WorldItemInstanceIndex,
) -> bool:
	if (
		corpse == null
		or not corpse.is_valid()
		or not inventory.is_registered(corpse.corpse_item_instance_id)
		or not item_index.has_snapshot(corpse.corpse_item_instance_id)
	):
		return false
	var parent: ContainmentEndpoint = inventory.direct_parent(
		corpse.corpse_item_instance_id
	)
	return parent != null and parent.kind == ContainmentEndpoint.Kind.WORLD


func _corpse_endpoint(corpse: CorpseState) -> ContainmentEndpoint:
	return ContainmentEndpoint.new(
		ContainmentEndpoint.Kind.ITEM,
		corpse.corpse_item_instance_id,
	)


func _result(
	outcome: int,
	actor_id: StringName,
	corpse_id: StringName,
	item_id: StringName,
) -> CorpseLootTransferResult:
	return CorpseLootTransferResult.new(
		outcome,
		false,
		actor_id,
		corpse_id,
		item_id,
	)
