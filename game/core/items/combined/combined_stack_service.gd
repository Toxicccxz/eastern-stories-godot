class_name CombinedStackService
extends RefCounted

const EquipmentStateType := preload("res://core/equipment/equipment_state.gd")
const EquipmentTransitionResultType := preload(
	"res://core/equipment/equipment_transition_result.gd"
)
const InventoryStateType := preload("res://core/inventory/inventory_state.gd")
const TransferDestinationType := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const TransferResultType := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const TransferServiceType := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const ItemInstanceType := preload("res://core/items/item_instance.gd")
const StackDefinitionType := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const StackStateType := preload("res://core/items/combined/combined_stack_state.gd")
const StackCollectionType := preload(
	"res://core/items/combined/combined_stack_collection.gd"
)
const AmountResultType := preload(
	"res://core/items/combined/combined_stack_amount_result.gd"
)
const SplitResultType := preload(
	"res://core/items/combined/combined_stack_split_result.gd"
)
const MergeResultType := preload(
	"res://core/items/combined/combined_stack_merge_result.gd"
)

const LEGACY_DESTRUCTION_DELAY_SECONDS: int = 1


## Associates an already-live Inventory item with the explicit stack protocol.
## Initial zero is raw combined.c static state and does not itself request
## destruction; only a later set_amount(0) operation does that.
static func register_stack(
	stacks: StackCollectionType,
	inventory: InventoryStateType,
	item: ItemInstanceType,
	definition: StackDefinitionType,
	initial_amount: int = 0,
) -> AmountResultType:
	var instance_id: StringName = &"" if item == null else item.item_instance_id
	if item == null or instance_id == &"":
		return _amount_failure(AmountResultType.Outcome.INVALID_INSTANCE, instance_id, initial_amount)
	if definition == null or not definition.is_valid():
		return _amount_failure(AmountResultType.Outcome.INVALID_DEFINITION, instance_id, initial_amount)
	if item.item_definition_id != definition.item_definition_id:
		return _amount_failure(AmountResultType.Outcome.DEFINITION_MISMATCH, instance_id, initial_amount)
	if initial_amount < 0:
		return _amount_failure(
			AmountResultType.Outcome.LEGACY_NEGATIVE_AMOUNT_ERROR,
			instance_id,
			initial_amount,
		)
	if stacks == null or inventory == null or not inventory.is_registered(instance_id):
		return _amount_failure(AmountResultType.Outcome.INSTANCE_NOT_REGISTERED, instance_id, initial_amount)
	if stacks.has_stack(instance_id):
		return _amount_failure(AmountResultType.Outcome.STACK_ALREADY_REGISTERED, instance_id, initial_amount)

	var weight_before: int = inventory.own_weight(instance_id)
	## A raw static amount of zero has not passed through LPC set_amount(), so
	## registration must not invent the positive branch's weight mutation.
	var weight_after: int = (
		weight_before
		if initial_amount == 0
		else definition.own_weight_for_amount(initial_amount)
	)
	if not inventory.update_own_weight(instance_id, weight_after):
		return _amount_failure(
			AmountResultType.Outcome.INVENTORY_WEIGHT_UPDATE_FAILED,
			instance_id,
			initial_amount,
			0,
			weight_before,
		)
	var state: StackStateType = StackStateType.new(instance_id, initial_amount)
	if not stacks._register_stack(state, definition):
		inventory.update_own_weight(instance_id, weight_before)
		return _amount_failure(
			AmountResultType.Outcome.STACK_ALREADY_REGISTERED,
			instance_id,
			initial_amount,
			0,
			weight_before,
		)
	return AmountResultType.new(
		AmountResultType.Outcome.REGISTERED,
		true,
		initial_amount != 0,
		instance_id,
		initial_amount,
		0,
		initial_amount,
		weight_before,
		weight_after,
	)


static func set_amount(
	stacks: StackCollectionType,
	inventory: InventoryStateType,
	item_instance_id: StringName,
	requested_amount: int,
) -> AmountResultType:
	if stacks == null or not stacks.has_stack(item_instance_id):
		return _amount_failure(
			AmountResultType.Outcome.INVALID_INSTANCE,
			item_instance_id,
			requested_amount,
		)
	var state: StackStateType = stacks._mutable_state(item_instance_id)
	var definition: StackDefinitionType = stacks.stack_definition(item_instance_id)
	var amount_before: int = state.amount
	var weight_before: int = 0 if inventory == null else inventory.own_weight(item_instance_id)
	if inventory == null or not inventory.is_registered(item_instance_id):
		return _amount_failure(
			AmountResultType.Outcome.INSTANCE_NOT_REGISTERED,
			item_instance_id,
			requested_amount,
			amount_before,
			weight_before,
		)
	if definition == null or not definition.is_valid():
		return _amount_failure(
			AmountResultType.Outcome.INVALID_DEFINITION,
			item_instance_id,
			requested_amount,
			amount_before,
			weight_before,
		)
	if requested_amount < 0:
		return _amount_failure(
			AmountResultType.Outcome.LEGACY_NEGATIVE_AMOUNT_ERROR,
			item_instance_id,
			requested_amount,
			amount_before,
			weight_before,
		)
	if requested_amount == 0:
		return AmountResultType.new(
			AmountResultType.Outcome.DELAYED_DESTRUCTION_REQUESTED,
			true,
			false,
			item_instance_id,
			requested_amount,
			amount_before,
			amount_before,
			weight_before,
			weight_before,
			AmountResultType.LifecycleAction.DELAYED_DESTRUCTION,
			LEGACY_DESTRUCTION_DELAY_SECONDS,
		)

	var weight_after: int = definition.own_weight_for_amount(requested_amount)
	stacks._apply_amount(item_instance_id, requested_amount)
	if not inventory.update_own_weight(item_instance_id, weight_after):
		stacks._apply_amount(item_instance_id, amount_before)
		return _amount_failure(
			AmountResultType.Outcome.INVENTORY_WEIGHT_UPDATE_FAILED,
			item_instance_id,
			requested_amount,
			amount_before,
			weight_before,
		)
	return AmountResultType.new(
		AmountResultType.Outcome.UPDATED,
		true,
		amount_before != requested_amount,
		item_instance_id,
		requested_amount,
		amount_before,
		requested_amount,
		weight_before,
		weight_after,
	)


static func add_amount(
	stacks: StackCollectionType,
	inventory: InventoryStateType,
	item_instance_id: StringName,
	delta: int,
) -> AmountResultType:
	if stacks == null or not stacks.has_stack(item_instance_id):
		return _amount_failure(
			AmountResultType.Outcome.INVALID_INSTANCE,
			item_instance_id,
			delta,
		)
	var state: StackStateType = stacks.stack_state(item_instance_id)
	return set_amount(stacks, inventory, item_instance_id, state.amount + delta)


## Reusable stack-domain split. Command adapters may perform later gates/moves
## without this service rolling the split back, preserving LPC partial-mutation
## possibilities while keeping the known get.c object-selection defect out.
static func split(
	stacks: StackCollectionType,
	inventory: InventoryStateType,
	source_instance_id: StringName,
	amount_requested: int,
	new_item: ItemInstanceType,
) -> SplitResultType:
	if (
		stacks == null
		or inventory == null
		or not stacks.has_stack(source_instance_id)
		or not inventory.is_registered(source_instance_id)
	):
		return _split_failure(
			SplitResultType.Outcome.INVALID_SOURCE_INSTANCE,
			source_instance_id,
			new_item,
			amount_requested,
		)
	var source_state: StackStateType = stacks._mutable_state(source_instance_id)
	var source_definition: StackDefinitionType = stacks.stack_definition(source_instance_id)
	var source_amount_before: int = source_state.amount
	var source_weight_before: int = inventory.own_weight(source_instance_id)
	if new_item == null or new_item.item_instance_id == &"" or new_item.item_instance_id == source_instance_id:
		return _split_failure(
			SplitResultType.Outcome.INVALID_NEW_INSTANCE,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)
	if inventory.is_registered(new_item.item_instance_id) or stacks.has_stack(new_item.item_instance_id):
		return _split_failure(
			SplitResultType.Outcome.NEW_INSTANCE_ALREADY_REGISTERED,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)
	if source_definition == null or new_item.item_definition_id != source_definition.item_definition_id:
		return _split_failure(
			SplitResultType.Outcome.DEFINITION_MISMATCH,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)
	if amount_requested <= 0:
		return _split_failure(
			SplitResultType.Outcome.REQUEST_NOT_POSITIVE,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)
	if amount_requested >= source_amount_before:
		return _split_failure(
			SplitResultType.Outcome.REQUEST_NOT_PARTIAL,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)

	var source_amount_after: int = source_amount_before - amount_requested
	var source_weight_after: int = source_definition.own_weight_for_amount(source_amount_after)
	var new_weight: int = source_definition.own_weight_for_amount(amount_requested)
	stacks._apply_amount(source_instance_id, source_amount_after)
	inventory.update_own_weight(source_instance_id, source_weight_after)
	if not inventory.register_item(new_item, new_weight):
		stacks._apply_amount(source_instance_id, source_amount_before)
		inventory.update_own_weight(source_instance_id, source_weight_before)
		return _split_failure(
			SplitResultType.Outcome.INVENTORY_REGISTRATION_FAILED,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)
	if not stacks._register_stack(
		StackStateType.new(new_item.item_instance_id, amount_requested),
		source_definition,
	):
		inventory._remove_registered_leaf(new_item.item_instance_id)
		stacks._apply_amount(source_instance_id, source_amount_before)
		inventory.update_own_weight(source_instance_id, source_weight_before)
		return _split_failure(
			SplitResultType.Outcome.STACK_REGISTRATION_FAILED,
			source_instance_id,
			new_item,
			amount_requested,
			source_amount_before,
			source_weight_before,
		)
	return SplitResultType.new(
		SplitResultType.Outcome.SPLIT,
		true,
		source_instance_id,
		new_item.item_instance_id,
		amount_requested,
		source_amount_before,
		source_amount_after,
		amount_requested,
		source_weight_before,
		source_weight_after,
		new_weight,
	)


## combined.c move override: low-level move first, then direct-only merging when
## the resulting environment is living. CHARACTER is this phase's typed living
## containment class. Moved instance identity always survives.
static func transfer_and_merge(
	stacks: StackCollectionType,
	inventory: InventoryStateType,
	moved_instance_id: StringName,
	destination: TransferDestinationType,
	source_owner_equipment: EquipmentStateType = null,
	destination_owner_equipment: EquipmentStateType = null,
) -> MergeResultType:
	if (
		stacks == null
		or inventory == null
		or not stacks.has_stack(moved_instance_id)
		or not inventory.is_registered(moved_instance_id)
	):
		return MergeResultType.new(
			MergeResultType.Outcome.INVALID_MOVED_STACK,
			false,
			false,
			moved_instance_id,
		)
	var moved_before: StackStateType = stacks.stack_state(moved_instance_id)
	var transfer: TransferResultType = TransferServiceType.new().transfer(
		inventory,
		moved_instance_id,
		destination,
		source_owner_equipment,
	)
	if not transfer.succeeded:
		return MergeResultType.new(
			MergeResultType.Outcome.TRANSFER_FAILED,
			false,
			false,
			moved_instance_id,
			moved_before.amount,
			moved_before.amount,
			0,
			inventory.own_weight(moved_instance_id),
			AmountResultType.LifecycleAction.NONE,
			0,
			[],
			[],
			transfer,
		)
	var resulting_parent: ContainmentEndpointType = transfer.resulting_parent
	if resulting_parent == null or resulting_parent.kind != ContainmentEndpointType.Kind.CHARACTER:
		return MergeResultType.new(
			MergeResultType.Outcome.MOVED_NO_MERGE_DESTINATION,
			true,
			false,
			moved_instance_id,
			moved_before.amount,
			moved_before.amount,
			0,
			inventory.own_weight(moved_instance_id),
			AmountResultType.LifecycleAction.NONE,
			0,
			[],
			[],
			transfer,
		)

	var absorbed_ids: Array[StringName] = []
	for sibling_id: StringName in inventory.direct_children(resulting_parent):
		if sibling_id == moved_instance_id or not stacks.has_stack(sibling_id):
			continue
		if stacks.are_compatible(moved_instance_id, sibling_id):
			absorbed_ids.append(sibling_id)
	## InventoryState direct_children() is already exact-ID sorted. This makes
	## absorbed result order deterministic without claiming MudOS list order.
	for absorbed_id: StringName in absorbed_ids:
		var absorbed_endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
			ContainmentEndpointType.Kind.ITEM,
			absorbed_id,
		)
		if not inventory.direct_children(absorbed_endpoint).is_empty():
			return MergeResultType.new(
				MergeResultType.Outcome.ABSORBED_STACK_HAS_CONTENTS,
				false,
				false,
				moved_instance_id,
				moved_before.amount,
				moved_before.amount,
				0,
				inventory.own_weight(moved_instance_id),
				AmountResultType.LifecycleAction.NONE,
				0,
				[],
				[],
				transfer,
			)

	var total: int = moved_before.amount
	var total_absorbed: int = 0
	var detached_ids: Array[StringName] = []
	for absorbed_id: StringName in absorbed_ids:
		var absorbed_state: StackStateType = stacks.stack_state(absorbed_id)
		total += absorbed_state.amount
		total_absorbed += absorbed_state.amount
		## destruct() calls feature/move.c::remove(), which unequips an absorbed
		## throwing stack before the object ceases to exist.
		if (
			destination_owner_equipment != null
			and destination_owner_equipment.has_weapon_instance(absorbed_id)
		):
			var detach_result: EquipmentTransitionResultType = (
				destination_owner_equipment.unwield(absorbed_id)
			)
			if detach_result.succeeded:
				detached_ids.append(absorbed_id)
		if not inventory._remove_registered_leaf(absorbed_id):
			return _merge_lifecycle_failure(
				moved_instance_id,
				moved_before.amount,
				total_absorbed,
				absorbed_ids,
				detached_ids,
				transfer,
				inventory,
			)
		if not stacks._remove_stack(absorbed_id):
			return _merge_lifecycle_failure(
				moved_instance_id,
				moved_before.amount,
				total_absorbed,
				absorbed_ids,
				detached_ids,
				transfer,
				inventory,
			)

	## combined.c invokes set_amount(total) for every living destination, even
	## when no compatible sibling was found. This matters for raw amount zero.
	var amount_result: AmountResultType = set_amount(
		stacks,
		inventory,
		moved_instance_id,
		total,
	)
	if not amount_result.accepted:
		return MergeResultType.new(
			MergeResultType.Outcome.AMOUNT_UPDATE_FAILED,
			false,
			not absorbed_ids.is_empty(),
			moved_instance_id,
			moved_before.amount,
			amount_result.amount_after,
			total_absorbed,
			inventory.own_weight(moved_instance_id),
			amount_result.lifecycle_action,
			amount_result.lifecycle_delay_seconds,
			absorbed_ids,
			detached_ids,
			transfer,
		)
	return MergeResultType.new(
		(
			MergeResultType.Outcome.MERGED
			if not absorbed_ids.is_empty()
			else MergeResultType.Outcome.MOVED_NO_COMPATIBLE_STACK
		),
		true,
		not absorbed_ids.is_empty(),
		moved_instance_id,
		moved_before.amount,
		amount_result.amount_after,
		total_absorbed,
		inventory.own_weight(moved_instance_id),
		amount_result.lifecycle_action,
		amount_result.lifecycle_delay_seconds,
		absorbed_ids,
		detached_ids,
		transfer,
	)


static func _amount_failure(
	outcome: int,
	item_instance_id: StringName,
	requested_amount: int,
	amount_before: int = 0,
	weight_before: int = 0,
) -> AmountResultType:
	return AmountResultType.new(
		outcome,
		false,
		false,
		item_instance_id,
		requested_amount,
		amount_before,
		amount_before,
		weight_before,
		weight_before,
	)


static func _split_failure(
	outcome: int,
	source_instance_id: StringName,
	new_item: ItemInstanceType,
	amount_requested: int,
	source_amount_before: int = 0,
	source_weight_before: int = 0,
) -> SplitResultType:
	return SplitResultType.new(
		outcome,
		false,
		source_instance_id,
		&"" if new_item == null else new_item.item_instance_id,
		amount_requested,
		source_amount_before,
		source_amount_before,
		0,
		source_weight_before,
		source_weight_before,
		0,
	)


static func _merge_lifecycle_failure(
	moved_instance_id: StringName,
	amount_before: int,
	total_absorbed: int,
	absorbed_ids: Array[StringName],
	detached_ids: Array[StringName],
	transfer: TransferResultType,
	inventory: InventoryStateType,
) -> MergeResultType:
	return MergeResultType.new(
		MergeResultType.Outcome.ABSORBED_LIFECYCLE_FAILED,
		false,
		true,
		moved_instance_id,
		amount_before,
		amount_before,
		total_absorbed,
		inventory.own_weight(moved_instance_id),
		AmountResultType.LifecycleAction.NONE,
		0,
		absorbed_ids,
		detached_ids,
		transfer,
	)
