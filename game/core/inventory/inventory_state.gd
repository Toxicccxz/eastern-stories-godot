class_name InventoryState
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const ItemInstanceType := preload("res://core/items/item_instance.gd")

enum ReparentValidation {
	VALID,
	INVALID_ITEM_ID,
	ITEM_NOT_REGISTERED,
	INVALID_DESTINATION,
	CONTAINMENT_CYCLE,
}

## Aggregate-local registration is not an ItemRepository: only stable live
## instance IDs and the narrow own-weight fact needed by containment are kept.
var _own_weights: Dictionary[StringName, int] = {}
var _direct_parents: Dictionary[StringName, ContainmentEndpoint] = {}


func register_item(item: ItemInstanceType, own_weight: int) -> bool:
	if item == null or item.item_instance_id == &"":
		return false
	if _own_weights.has(item.item_instance_id):
		return false
	_own_weights[item.item_instance_id] = own_weight
	return true


func is_registered(item_instance_id: StringName) -> bool:
	return item_instance_id != &"" and _own_weights.has(item_instance_id)


func update_own_weight(item_instance_id: StringName, own_weight: int) -> bool:
	if not is_registered(item_instance_id):
		return false
	_own_weights[item_instance_id] = own_weight
	return true


func own_weight(item_instance_id: StringName) -> int:
	return int(_own_weights.get(item_instance_id, 0))


func direct_parent(item_instance_id: StringName) -> ContainmentEndpointType:
	var stored: ContainmentEndpointType = _direct_parents.get(item_instance_id)
	return null if stored == null else stored.duplicate_snapshot()


func has_direct_parent(item_instance_id: StringName) -> bool:
	return is_registered(item_instance_id) and _direct_parents.has(item_instance_id)


func direct_children(endpoint: ContainmentEndpointType) -> Array[StringName]:
	var children: Array[StringName] = []
	if endpoint == null or not endpoint.is_valid():
		return children
	for item_instance_id: StringName in _direct_parents:
		var parent: ContainmentEndpointType = _direct_parents[item_instance_id]
		if parent.same_identity(endpoint):
			children.append(item_instance_id)
	children.sort_custom(_string_name_less_than)
	return children


func is_direct_child(
	item_instance_id: StringName,
	endpoint: ContainmentEndpointType,
) -> bool:
	var parent: ContainmentEndpointType = direct_parent(item_instance_id)
	return parent != null and parent.same_identity(endpoint)


## Direct parent first, then each enclosing item, ending at the outer holder.
func ancestry(item_instance_id: StringName) -> Array[ContainmentEndpoint]:
	var result: Array[ContainmentEndpoint] = []
	if not is_registered(item_instance_id):
		return result
	var visited_item_ids: Dictionary[StringName, bool] = {item_instance_id: true}
	var current: ContainmentEndpointType = direct_parent(item_instance_id)
	while current != null:
		if current.kind == ContainmentEndpointType.Kind.ITEM:
			if visited_item_ids.has(current.endpoint_id):
				break
			visited_item_ids[current.endpoint_id] = true
		result.append(current.duplicate_snapshot())
		if current.kind != ContainmentEndpointType.Kind.ITEM:
			break
		current = direct_parent(current.endpoint_id)
	return result


func root_holder(item_instance_id: StringName) -> ContainmentEndpointType:
	var lineage: Array[ContainmentEndpoint] = ancestry(item_instance_id)
	return null if lineage.is_empty() else lineage[-1].duplicate_snapshot()


func is_ancestor(
	candidate: ContainmentEndpointType,
	item_instance_id: StringName,
) -> bool:
	if candidate == null or not candidate.is_valid():
		return false
	for endpoint: ContainmentEndpointType in ancestry(item_instance_id):
		if endpoint.same_identity(candidate):
			return true
	return false


func is_descendant_of(
	item_instance_id: StringName,
	candidate: ContainmentEndpointType,
) -> bool:
	return is_ancestor(candidate, item_instance_id)


## Equivalent to legacy weight(): own weight plus the complete nested contents.
func subtree_weight(item_instance_id: StringName) -> int:
	if not is_registered(item_instance_id):
		return 0
	var visited_item_ids: Dictionary[StringName, bool] = {}
	return _subtree_weight(item_instance_id, visited_item_ids)


func _subtree_weight(
	item_instance_id: StringName,
	visited_item_ids: Dictionary[StringName, bool],
) -> int:
	if not is_registered(item_instance_id) or visited_item_ids.has(item_instance_id):
		return 0
	visited_item_ids[item_instance_id] = true
	var total: int = own_weight(item_instance_id)
	var item_endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
		ContainmentEndpointType.Kind.ITEM,
		item_instance_id,
	)
	for child_id: StringName in direct_children(item_endpoint):
		total += _subtree_weight(child_id, visited_item_ids)
	return total


## Equivalent to legacy query_encumbrance() for a containment endpoint.
func contents_weight(endpoint: ContainmentEndpointType) -> int:
	var total: int = 0
	for child_id: StringName in direct_children(endpoint):
		total += subtree_weight(child_id)
	return total


func validate_reparent(
	item_instance_id: StringName,
	destination: ContainmentEndpointType,
) -> int:
	if item_instance_id == &"":
		return ReparentValidation.INVALID_ITEM_ID
	if not is_registered(item_instance_id):
		return ReparentValidation.ITEM_NOT_REGISTERED
	if destination == null or not destination.is_valid():
		return ReparentValidation.INVALID_DESTINATION
	if destination.kind == ContainmentEndpointType.Kind.ITEM:
		if not is_registered(destination.endpoint_id):
			return ReparentValidation.INVALID_DESTINATION
		if destination.endpoint_id == item_instance_id:
			return ReparentValidation.CONTAINMENT_CYCLE
		var moving_item_endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
			ContainmentEndpointType.Kind.ITEM,
			item_instance_id,
		)
		if is_ancestor(moving_item_endpoint, destination.endpoint_id):
			return ReparentValidation.CONTAINMENT_CYCLE
	return ReparentValidation.VALID


## Internal transition seam used by InventoryTransferService. The leading
## underscore is intentional: callers should not bypass ordered transfer. The
## graph invariants are still revalidated here before mutation.
func _apply_reparent(
	item_instance_id: StringName,
	destination: ContainmentEndpointType,
) -> bool:
	if validate_reparent(item_instance_id, destination) != ReparentValidation.VALID:
		return false
	_direct_parents[item_instance_id] = destination.duplicate_snapshot()
	return true


## Narrow internal lifecycle seam for an already-validated leaf instance.
## Phase 4B3 uses this only when combined.c immediately destructs an absorbed
## sibling stack. Full item destruction and contained-child handling remain
## outside InventoryState.
func _remove_registered_leaf(item_instance_id: StringName) -> bool:
	if not is_registered(item_instance_id):
		return false
	var item_endpoint: ContainmentEndpointType = ContainmentEndpointType.new(
		ContainmentEndpointType.Kind.ITEM,
		item_instance_id,
	)
	if not direct_children(item_endpoint).is_empty():
		return false
	_direct_parents.erase(item_instance_id)
	_own_weights.erase(item_instance_id)
	return true


func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
