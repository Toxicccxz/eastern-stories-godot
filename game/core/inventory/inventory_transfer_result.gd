class_name InventoryTransferResult
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)

enum Outcome {
	TRANSFERRED,
	ALREADY_AT_DESTINATION,
	INVALID_ITEM_ID,
	ITEM_NOT_REGISTERED,
	INVALID_DESTINATION,
	DESTINATION_UNAVAILABLE,
	DESTINATION_NOT_CONTAINMENT_CAPABLE,
	CONTAINMENT_CYCLE,
	CAPACITY_EXCEEDED,
	EQUIPMENT_DETACH_FAILED,
	CONTAINMENT_MUTATION_FAILED,
}

var _outcome: int
var _succeeded: bool
var _item_instance_id: StringName
var _previous_parent: ContainmentEndpointType
var _requested_parent: ContainmentEndpointType
var _resulting_parent: ContainmentEndpointType
var _equipment_detached: bool
var _containment_changed: bool
var _previous_root_holder: ContainmentEndpointType
var _resulting_root_holder: ContainmentEndpointType

var outcome: int:
	get:
		return _outcome

var succeeded: bool:
	get:
		return _succeeded

var item_instance_id: StringName:
	get:
		return _item_instance_id

var previous_parent: ContainmentEndpointType:
	get:
		return _copy_endpoint(_previous_parent)

var requested_parent: ContainmentEndpointType:
	get:
		return _copy_endpoint(_requested_parent)

var resulting_parent: ContainmentEndpointType:
	get:
		return _copy_endpoint(_resulting_parent)

var equipment_detached: bool:
	get:
		return _equipment_detached

var containment_changed: bool:
	get:
		return _containment_changed

var previous_root_holder: ContainmentEndpointType:
	get:
		return _copy_endpoint(_previous_root_holder)

var resulting_root_holder: ContainmentEndpointType:
	get:
		return _copy_endpoint(_resulting_root_holder)


func _init(
	p_outcome: int = Outcome.INVALID_ITEM_ID,
	p_succeeded: bool = false,
	p_item_instance_id: StringName = &"",
	p_previous_parent: ContainmentEndpointType = null,
	p_requested_parent: ContainmentEndpointType = null,
	p_resulting_parent: ContainmentEndpointType = null,
	p_equipment_detached: bool = false,
	p_containment_changed: bool = false,
	p_previous_root_holder: ContainmentEndpointType = null,
	p_resulting_root_holder: ContainmentEndpointType = null,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_item_instance_id = p_item_instance_id
	_previous_parent = _copy_endpoint(p_previous_parent)
	_requested_parent = _copy_endpoint(p_requested_parent)
	_resulting_parent = _copy_endpoint(p_resulting_parent)
	_equipment_detached = p_equipment_detached
	_containment_changed = p_containment_changed
	_previous_root_holder = _copy_endpoint(p_previous_root_holder)
	_resulting_root_holder = _copy_endpoint(p_resulting_root_holder)


func _copy_endpoint(value: ContainmentEndpointType) -> ContainmentEndpointType:
	return null if value == null else value.duplicate_snapshot()
