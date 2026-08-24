class_name CombinedStackAmountResult
extends RefCounted

enum Outcome {
	REGISTERED,
	UPDATED,
	DELAYED_DESTRUCTION_REQUESTED,
	LEGACY_NEGATIVE_AMOUNT_ERROR,
	INVALID_INSTANCE,
	INVALID_DEFINITION,
	DEFINITION_MISMATCH,
	INSTANCE_NOT_REGISTERED,
	STACK_ALREADY_REGISTERED,
	INVENTORY_WEIGHT_UPDATE_FAILED,
}

enum LifecycleAction {
	NONE,
	DELAYED_DESTRUCTION,
}

var _outcome: int
var _accepted: bool
var _amount_changed: bool
var _item_instance_id: StringName
var _requested_amount: int
var _amount_before: int
var _amount_after: int
var _own_weight_before: int
var _own_weight_after: int
var _lifecycle_action: int
var _lifecycle_delay_seconds: int

var outcome: int:
	get: return _outcome
var accepted: bool:
	get: return _accepted
var amount_changed: bool:
	get: return _amount_changed
var item_instance_id: StringName:
	get: return _item_instance_id
var requested_amount: int:
	get: return _requested_amount
var amount_before: int:
	get: return _amount_before
var amount_after: int:
	get: return _amount_after
var own_weight_before: int:
	get: return _own_weight_before
var own_weight_after: int:
	get: return _own_weight_after
var lifecycle_action: int:
	get: return _lifecycle_action
var lifecycle_delay_seconds: int:
	get: return _lifecycle_delay_seconds


func _init(
	p_outcome: int = Outcome.INVALID_INSTANCE,
	p_accepted: bool = false,
	p_amount_changed: bool = false,
	p_item_instance_id: StringName = &"",
	p_requested_amount: int = 0,
	p_amount_before: int = 0,
	p_amount_after: int = 0,
	p_own_weight_before: int = 0,
	p_own_weight_after: int = 0,
	p_lifecycle_action: int = LifecycleAction.NONE,
	p_lifecycle_delay_seconds: int = 0,
) -> void:
	_outcome = p_outcome
	_accepted = p_accepted
	_amount_changed = p_amount_changed
	_item_instance_id = p_item_instance_id
	_requested_amount = p_requested_amount
	_amount_before = p_amount_before
	_amount_after = p_amount_after
	_own_weight_before = p_own_weight_before
	_own_weight_after = p_own_weight_after
	_lifecycle_action = p_lifecycle_action
	_lifecycle_delay_seconds = p_lifecycle_delay_seconds
