class_name CombinedStackMergeResult
extends RefCounted

const TransferResultType := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const AmountResultType := preload(
	"res://core/items/combined/combined_stack_amount_result.gd"
)

enum Outcome {
	MERGED,
	MOVED_NO_MERGE_DESTINATION,
	MOVED_NO_COMPATIBLE_STACK,
	INVALID_MOVED_STACK,
	TRANSFER_FAILED,
	ABSORBED_STACK_HAS_CONTENTS,
	ABSORBED_LIFECYCLE_FAILED,
	AMOUNT_UPDATE_FAILED,
}

var _outcome: int
var _succeeded: bool
var _merge_applied: bool
var _surviving_instance_id: StringName
var _amount_before: int
var _amount_after: int
var _total_absorbed_amount: int
var _resulting_own_weight: int
var _lifecycle_action: int
var _lifecycle_delay_seconds: int
var _absorbed_instance_ids: Array[StringName]
var _equipment_detached_instance_ids: Array[StringName]
var _inventory_transfer: TransferResultType

var outcome: int:
	get: return _outcome
var succeeded: bool:
	get: return _succeeded
var merge_applied: bool:
	get: return _merge_applied
var surviving_instance_id: StringName:
	get: return _surviving_instance_id
var amount_before: int:
	get: return _amount_before
var amount_after: int:
	get: return _amount_after
var total_absorbed_amount: int:
	get: return _total_absorbed_amount
var resulting_own_weight: int:
	get: return _resulting_own_weight
var lifecycle_action: int:
	get: return _lifecycle_action
var lifecycle_delay_seconds: int:
	get: return _lifecycle_delay_seconds
var inventory_transfer: TransferResultType:
	get: return _inventory_transfer

var absorbed_instance_ids: Array[StringName]:
	get:
		return _absorbed_instance_ids.duplicate()

var equipment_detached_instance_ids: Array[StringName]:
	get:
		return _equipment_detached_instance_ids.duplicate()


func _init(
	p_outcome: int = Outcome.INVALID_MOVED_STACK,
	p_succeeded: bool = false,
	p_merge_applied: bool = false,
	p_surviving_instance_id: StringName = &"",
	p_amount_before: int = 0,
	p_amount_after: int = 0,
	p_total_absorbed_amount: int = 0,
	p_resulting_own_weight: int = 0,
	p_lifecycle_action: int = AmountResultType.LifecycleAction.NONE,
	p_lifecycle_delay_seconds: int = 0,
	p_absorbed_instance_ids: Array[StringName] = [],
	p_equipment_detached_instance_ids: Array[StringName] = [],
	p_inventory_transfer: TransferResultType = null,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_merge_applied = p_merge_applied
	_surviving_instance_id = p_surviving_instance_id
	_amount_before = p_amount_before
	_amount_after = p_amount_after
	_total_absorbed_amount = p_total_absorbed_amount
	_resulting_own_weight = p_resulting_own_weight
	_lifecycle_action = p_lifecycle_action
	_lifecycle_delay_seconds = p_lifecycle_delay_seconds
	_absorbed_instance_ids = p_absorbed_instance_ids.duplicate()
	_equipment_detached_instance_ids = p_equipment_detached_instance_ids.duplicate()
	_inventory_transfer = p_inventory_transfer
