class_name InventoryTransferService
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
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


## direct_owner_equipment, when supplied, must be the EquipmentState belonging
## to the item's current direct CHARACTER parent. Nested items never consult it.
func transfer(
	inventory: InventoryStateType,
	item_instance_id: StringName,
	destination: TransferDestinationType,
	direct_owner_equipment: EquipmentStateType = null,
) -> TransferResultType:
	if item_instance_id == &"":
		return _result(
			TransferResultType.Outcome.INVALID_ITEM_ID,
			false,
			item_instance_id,
			inventory,
			destination,
		)
	if inventory == null or not inventory.is_registered(item_instance_id):
		return _result(
			TransferResultType.Outcome.ITEM_NOT_REGISTERED,
			false,
			item_instance_id,
			inventory,
			destination,
		)

	var previous_parent: ContainmentEndpointType = inventory.direct_parent(item_instance_id)
	var previous_root: ContainmentEndpointType = inventory.root_holder(item_instance_id)
	var equipment_detached: bool = false

	## feature/move.c calls unequip() before resolving or validating dest.
	if (
		direct_owner_equipment != null
		and previous_parent != null
		and previous_parent.kind == ContainmentEndpointType.Kind.CHARACTER
		and direct_owner_equipment.has_weapon_instance(item_instance_id)
	):
		var detach_result: EquipmentTransitionResultType = (
			direct_owner_equipment.unwield(item_instance_id)
		)
		if not detach_result.succeeded:
			return _snapshot_result(
				TransferResultType.Outcome.EQUIPMENT_DETACH_FAILED,
				false,
				item_instance_id,
				previous_parent,
				_destination_endpoint(destination),
				inventory.direct_parent(item_instance_id),
				false,
				false,
				previous_root,
				inventory.root_holder(item_instance_id),
			)
		equipment_detached = detach_result.changed

	var requested_parent: ContainmentEndpointType = _destination_endpoint(destination)
	if destination == null or requested_parent == null or not requested_parent.is_valid():
		return _failed_after_detach(
			TransferResultType.Outcome.INVALID_DESTINATION,
			inventory,
			item_instance_id,
			previous_parent,
			requested_parent,
			previous_root,
			equipment_detached,
		)
	if not destination.is_available:
		return _failed_after_detach(
			TransferResultType.Outcome.DESTINATION_UNAVAILABLE,
			inventory,
			item_instance_id,
			previous_parent,
			requested_parent,
			previous_root,
			equipment_detached,
		)
	if not destination.is_containment_capable:
		return _failed_after_detach(
			TransferResultType.Outcome.DESTINATION_NOT_CONTAINMENT_CAPABLE,
			inventory,
			item_instance_id,
			previous_parent,
			requested_parent,
			previous_root,
			equipment_detached,
		)

	var validation: int = inventory.validate_reparent(item_instance_id, requested_parent)
	if validation == InventoryStateType.ReparentValidation.CONTAINMENT_CYCLE:
		return _failed_after_detach(
			TransferResultType.Outcome.CONTAINMENT_CYCLE,
			inventory,
			item_instance_id,
			previous_parent,
			requested_parent,
			previous_root,
			equipment_detached,
		)
	if validation != InventoryStateType.ReparentValidation.VALID:
		return _failed_after_detach(
			TransferResultType.Outcome.INVALID_DESTINATION,
			inventory,
			item_instance_id,
			previous_parent,
			requested_parent,
			previous_root,
			equipment_detached,
		)

	## If dest is already in the moving item's ancestry, its subtree weight is
	## already included there and feature/move.c skips this capacity comparison.
	if not inventory.is_ancestor(requested_parent, item_instance_id):
		var resulting_contents_weight: int = (
			inventory.contents_weight(requested_parent)
			+ inventory.subtree_weight(item_instance_id)
		)
		if resulting_contents_weight > destination.maximum_contents_weight:
			return _failed_after_detach(
				TransferResultType.Outcome.CAPACITY_EXCEEDED,
				inventory,
				item_instance_id,
				previous_parent,
				requested_parent,
				previous_root,
				equipment_detached,
			)

	var containment_changed: bool = (
		previous_parent == null or not previous_parent.same_identity(requested_parent)
	)
	if not inventory._apply_reparent(item_instance_id, requested_parent):
		return _failed_after_detach(
			TransferResultType.Outcome.CONTAINMENT_MUTATION_FAILED,
			inventory,
			item_instance_id,
			previous_parent,
			requested_parent,
			previous_root,
			equipment_detached,
		)

	return _snapshot_result(
		(
			TransferResultType.Outcome.TRANSFERRED
			if containment_changed
			else TransferResultType.Outcome.ALREADY_AT_DESTINATION
		),
		true,
		item_instance_id,
		previous_parent,
		requested_parent,
		inventory.direct_parent(item_instance_id),
		equipment_detached,
		containment_changed,
		previous_root,
		inventory.root_holder(item_instance_id),
	)


func _result(
	outcome: int,
	succeeded: bool,
	item_instance_id: StringName,
	inventory: InventoryStateType,
	destination: TransferDestinationType,
) -> TransferResultType:
	var parent: ContainmentEndpointType = (
		null if inventory == null else inventory.direct_parent(item_instance_id)
	)
	var root: ContainmentEndpointType = (
		null if inventory == null else inventory.root_holder(item_instance_id)
	)
	return _snapshot_result(
		outcome,
		succeeded,
		item_instance_id,
		parent,
		_destination_endpoint(destination),
		parent,
		false,
		false,
		root,
		root,
	)


func _failed_after_detach(
	outcome: int,
	inventory: InventoryStateType,
	item_instance_id: StringName,
	previous_parent: ContainmentEndpointType,
	requested_parent: ContainmentEndpointType,
	previous_root: ContainmentEndpointType,
	equipment_detached: bool,
) -> TransferResultType:
	return _snapshot_result(
		outcome,
		false,
		item_instance_id,
		previous_parent,
		requested_parent,
		inventory.direct_parent(item_instance_id),
		equipment_detached,
		false,
		previous_root,
		inventory.root_holder(item_instance_id),
	)


func _snapshot_result(
	outcome: int,
	succeeded: bool,
	item_instance_id: StringName,
	previous_parent: ContainmentEndpointType,
	requested_parent: ContainmentEndpointType,
	resulting_parent: ContainmentEndpointType,
	equipment_detached: bool,
	containment_changed: bool,
	previous_root: ContainmentEndpointType,
	resulting_root: ContainmentEndpointType,
) -> TransferResultType:
	return TransferResultType.new(
		outcome,
		succeeded,
		item_instance_id,
		previous_parent,
		requested_parent,
		resulting_parent,
		equipment_detached,
		containment_changed,
		previous_root,
		resulting_root,
	)


func _destination_endpoint(
	destination: TransferDestinationType,
) -> ContainmentEndpointType:
	return null if destination == null else destination.endpoint
