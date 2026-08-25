class_name ItemLifecycleService
extends RefCounted

const ArmorTransitionResultType := preload(
	"res://core/armor/armor_transition_result.gd"
)
const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const EquipmentTransitionResultType := preload(
	"res://core/equipment/equipment_transition_result.gd"
)
const ResultType := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)
const OwnerContextType := preload(
	"res://core/items/lifecycle/item_lifecycle_owner_context.gd"
)


## Removes one live item from the represented runtime domains. This method is
## deliberately stateless: InventoryState remains the liveness/parent/weight
## authority and CombinedStackCollection remains the amount association.
static func destroy_item(
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_instance_id: StringName,
	child_disposition: int = ResultType.ChildDisposition.REQUIRE_LEAF,
	direct_owner: OwnerContextType = null,
) -> ResultType:
	if item_instance_id == &"":
		return _result(
			ResultType.Outcome.INVALID_ITEM_ID,
			false,
			item_instance_id,
			child_disposition,
		)
	if inventory == null or stacks == null:
		return _result(
			ResultType.Outcome.INVALID_DOMAIN_STATE,
			false,
			item_instance_id,
			child_disposition,
		)
	if not inventory.is_registered(item_instance_id):
		return _result(
			ResultType.Outcome.ITEM_NOT_LIVE,
			false,
			item_instance_id,
			child_disposition,
		)
	if (
		child_disposition != ResultType.ChildDisposition.REQUIRE_LEAF
		and child_disposition != ResultType.ChildDisposition.DESTROY_SUBTREE
	):
		return _result(
			ResultType.Outcome.INVALID_CHILD_DISPOSITION,
			false,
			item_instance_id,
			child_disposition,
		)

	var previous_parent: ContainmentEndpointType = inventory.direct_parent(
		item_instance_id
	)
	var previous_root: ContainmentEndpointType = inventory.root_holder(
		item_instance_id
	)
	var graph_validation: int = _validate_ancestry(inventory, item_instance_id)
	if graph_validation != ResultType.Outcome.REMOVED:
		return _result(
			graph_validation,
			false,
			item_instance_id,
			child_disposition,
			[],
			previous_parent,
			previous_root,
		)

	var has_direct_character_owner: bool = (
		previous_parent != null
		and previous_parent.kind == ContainmentEndpointType.Kind.CHARACTER
	)
	if has_direct_character_owner:
		if direct_owner == null:
			return _result(
				ResultType.Outcome.OWNER_CONTEXT_REQUIRED,
				false,
				item_instance_id,
				child_disposition,
				[],
				previous_parent,
				previous_root,
			)
		if not direct_owner.is_complete():
			return _result(
				ResultType.Outcome.OWNER_CONTEXT_INCOMPLETE,
				false,
				item_instance_id,
				child_disposition,
				[],
				previous_parent,
				previous_root,
			)
		if (
			direct_owner.character_id != previous_parent.endpoint_id
		):
			return _result(
				ResultType.Outcome.OWNER_CONTEXT_MISMATCH,
				false,
				item_instance_id,
				child_disposition,
				[],
				previous_parent,
				previous_root,
			)

	var removal_order: Array[StringName] = []
	if child_disposition == ResultType.ChildDisposition.REQUIRE_LEAF:
		var item_endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
			ContainmentEndpointType.Kind.ITEM,
			item_instance_id,
		)
		if not inventory.direct_children(item_endpoint).is_empty():
			return _result(
				ResultType.Outcome.NOT_LEAF,
				false,
				item_instance_id,
				child_disposition,
				[],
				previous_parent,
				previous_root,
			)
		removal_order.append(item_instance_id)
	else:
		var visiting: Dictionary[StringName, bool] = {}
		var visited: Dictionary[StringName, bool] = {}
		if not _collect_post_order(
			inventory,
			item_instance_id,
			visiting,
			visited,
			removal_order,
		):
			return _result(
				ResultType.Outcome.INVALID_CONTAINMENT_GRAPH,
				false,
				item_instance_id,
				child_disposition,
				[],
				previous_parent,
				previous_root,
			)

	for removal_id: StringName in removal_order:
		if not inventory.is_registered(removal_id):
			return _result(
				ResultType.Outcome.INVALID_CONTAINMENT_GRAPH,
				false,
				item_instance_id,
				child_disposition,
				[],
				previous_parent,
				previous_root,
			)
		if stacks.has_stack(removal_id):
			var state: CombinedStackState = stacks.stack_state(removal_id)
			var definition: CombinedStackDefinition = stacks.stack_definition(
				removal_id
			)
			if (
				state == null
				or state.item_instance_id != removal_id
				or state.amount < 0
				or definition == null
				or not definition.is_valid()
			):
				return _result(
					ResultType.Outcome.INVALID_STACK_ASSOCIATION,
					false,
					item_instance_id,
					child_disposition,
					[],
					previous_parent,
					previous_root,
				)

	## feature/move.c::remove() attempts equipment cleanup before destruction.
	## Native hand and Armor authorities are separate, so malformed dual state
	## is cleaned in deterministic hand-then-Armor order.
	var weapon_detached: bool = false
	var armor_detached: bool = false
	if (
		has_direct_character_owner
		and direct_owner != null
	):
		if direct_owner.equipment_state.has_weapon_instance(item_instance_id):
			var weapon_remove: EquipmentTransitionResultType = (
				direct_owner.equipment_state.unwield(item_instance_id)
			)
			if not weapon_remove.succeeded:
				return _result(
					ResultType.Outcome.EQUIPMENT_DETACH_FAILED,
					false,
					item_instance_id,
					child_disposition,
					[],
					previous_parent,
					previous_root,
				)
			weapon_detached = weapon_remove.changed
	if (
		has_direct_character_owner
		and direct_owner != null
	):
		if direct_owner.armor_state.is_worn(item_instance_id):
			var armor_remove: ArmorTransitionResultType = (
				direct_owner.armor_state.remove(item_instance_id)
			)
			if not armor_remove.succeeded:
				return _result(
					ResultType.Outcome.ARMOR_DETACH_FAILED,
					false,
					item_instance_id,
					child_disposition,
					[],
					previous_parent,
					previous_root,
					weapon_detached,
				)
			armor_detached = armor_remove.changed

	var removed_ids: Array[StringName] = []
	for removal_id: StringName in removal_order:
		var had_stack: bool = stacks.has_stack(removal_id)
		if not inventory._remove_registered_leaf(removal_id):
			return _result(
				ResultType.Outcome.INVENTORY_REMOVAL_FAILED,
				false,
				item_instance_id,
				child_disposition,
				removed_ids,
				previous_parent,
				previous_root,
				weapon_detached,
				armor_detached,
			)
		removed_ids.append(removal_id)
		if had_stack and not stacks._remove_stack(removal_id):
			return _result(
				ResultType.Outcome.STACK_REMOVAL_FAILED,
				false,
				item_instance_id,
				child_disposition,
				removed_ids,
				previous_parent,
				previous_root,
				weapon_detached,
				armor_detached,
			)

	return _result(
		ResultType.Outcome.REMOVED,
		true,
		item_instance_id,
		child_disposition,
		removed_ids,
		previous_parent,
		previous_root,
		weapon_detached,
		armor_detached,
	)


static func _validate_ancestry(
	inventory: InventoryState,
	item_instance_id: StringName,
) -> int:
	var visited: Dictionary[StringName, bool] = {item_instance_id: true}
	var current_id: StringName = item_instance_id
	while inventory.has_direct_parent(current_id):
		var parent: ContainmentEndpointType = inventory.direct_parent(current_id)
		if parent == null or not parent.is_valid():
			return ResultType.Outcome.INVALID_CONTAINMENT_GRAPH
		if parent.kind != ContainmentEndpointType.Kind.ITEM:
			break
		if (
			not inventory.is_registered(parent.endpoint_id)
			or visited.has(parent.endpoint_id)
		):
			return ResultType.Outcome.INVALID_CONTAINMENT_GRAPH
		visited[parent.endpoint_id] = true
		current_id = parent.endpoint_id
	return ResultType.Outcome.REMOVED


static func _collect_post_order(
	inventory: InventoryState,
	item_instance_id: StringName,
	visiting: Dictionary[StringName, bool],
	visited: Dictionary[StringName, bool],
	result: Array[StringName],
) -> bool:
	if not inventory.is_registered(item_instance_id):
		return false
	if visiting.has(item_instance_id):
		return false
	if visited.has(item_instance_id):
		return true
	visiting[item_instance_id] = true
	var endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
		ContainmentEndpointType.Kind.ITEM,
		item_instance_id,
	)
	for child_id: StringName in inventory.direct_children(endpoint):
		if not _collect_post_order(
			inventory,
			child_id,
			visiting,
			visited,
			result,
		):
			return false
	visiting.erase(item_instance_id)
	visited[item_instance_id] = true
	result.append(item_instance_id)
	return true


static func _result(
	outcome: int,
	succeeded: bool,
	item_instance_id: StringName,
	child_disposition: int,
	removed_instance_ids: Array[StringName] = [],
	previous_parent: ContainmentEndpointType = null,
	previous_root: ContainmentEndpointType = null,
	weapon_detached: bool = false,
	armor_detached: bool = false,
) -> ResultType:
	return ResultType.new(
		outcome,
		succeeded,
		item_instance_id,
		child_disposition,
		removed_instance_ids,
		previous_parent,
		previous_root,
		weapon_detached,
		armor_detached,
	)
