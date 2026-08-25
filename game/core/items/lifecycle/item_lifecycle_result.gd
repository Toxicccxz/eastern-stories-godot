class_name ItemLifecycleResult
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)

enum ChildDisposition {
	REQUIRE_LEAF,
	DESTROY_SUBTREE,
}

enum Outcome {
	REMOVED,
	INVALID_ITEM_ID,
	INVALID_DOMAIN_STATE,
	ITEM_NOT_LIVE,
	INVALID_CHILD_DISPOSITION,
	OWNER_CONTEXT_REQUIRED,
	OWNER_CONTEXT_INCOMPLETE,
	OWNER_CONTEXT_MISMATCH,
	NOT_LEAF,
	INVALID_CONTAINMENT_GRAPH,
	INVALID_STACK_ASSOCIATION,
	EQUIPMENT_DETACH_FAILED,
	ARMOR_DETACH_FAILED,
	INVENTORY_REMOVAL_FAILED,
	STACK_REMOVAL_FAILED,
}

var _outcome: int
var _succeeded: bool
var _requested_item_instance_id: StringName
var _child_disposition: int
var _removed_instance_ids: Array[StringName] = []
var _previous_parent: ContainmentEndpointType
var _previous_root: ContainmentEndpointType
var _weapon_detached: bool
var _armor_detached: bool

var outcome: int:
	get:
		return _outcome
var succeeded: bool:
	get:
		return _succeeded
var requested_item_instance_id: StringName:
	get:
		return _requested_item_instance_id
var child_disposition: int:
	get:
		return _child_disposition
var removed_instance_ids: Array[StringName]:
	get:
		return _removed_instance_ids.duplicate()
var previous_parent: ContainmentEndpointType:
	get:
		return (
			null
			if _previous_parent == null
			else _previous_parent.duplicate_snapshot()
		)
var previous_root: ContainmentEndpointType:
	get:
		return (
			null
			if _previous_root == null
			else _previous_root.duplicate_snapshot()
		)
var weapon_detached: bool:
	get:
		return _weapon_detached
var armor_detached: bool:
	get:
		return _armor_detached


func _init(
	p_outcome: int = Outcome.INVALID_DOMAIN_STATE,
	p_succeeded: bool = false,
	p_requested_item_instance_id: StringName = &"",
	p_child_disposition: int = ChildDisposition.REQUIRE_LEAF,
	p_removed_instance_ids: Array[StringName] = [],
	p_previous_parent: ContainmentEndpointType = null,
	p_previous_root: ContainmentEndpointType = null,
	p_weapon_detached: bool = false,
	p_armor_detached: bool = false,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_requested_item_instance_id = p_requested_item_instance_id
	_child_disposition = p_child_disposition
	_removed_instance_ids = p_removed_instance_ids.duplicate()
	_previous_parent = (
		null
		if p_previous_parent == null
		else p_previous_parent.duplicate_snapshot()
	)
	_previous_root = (
		null
		if p_previous_root == null
		else p_previous_root.duplicate_snapshot()
	)
	_weapon_detached = p_weapon_detached
	_armor_detached = p_armor_detached
