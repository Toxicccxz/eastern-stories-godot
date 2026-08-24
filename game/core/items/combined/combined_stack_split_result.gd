class_name CombinedStackSplitResult
extends RefCounted

enum Outcome {
	SPLIT,
	INVALID_SOURCE_INSTANCE,
	INVALID_NEW_INSTANCE,
	NEW_INSTANCE_ALREADY_REGISTERED,
	DEFINITION_MISMATCH,
	REQUEST_NOT_POSITIVE,
	REQUEST_NOT_PARTIAL,
	INVENTORY_REGISTRATION_FAILED,
	STACK_REGISTRATION_FAILED,
}

var _outcome: int
var _succeeded: bool
var _source_instance_id: StringName
var _new_instance_id: StringName
var _amount_requested: int
var _source_amount_before: int
var _source_amount_after: int
var _new_amount: int
var _source_weight_before: int
var _source_weight_after: int
var _new_weight: int

var outcome: int:
	get: return _outcome
var succeeded: bool:
	get: return _succeeded
var source_instance_id: StringName:
	get: return _source_instance_id
var new_instance_id: StringName:
	get: return _new_instance_id
var amount_requested: int:
	get: return _amount_requested
var source_amount_before: int:
	get: return _source_amount_before
var source_amount_after: int:
	get: return _source_amount_after
var new_amount: int:
	get: return _new_amount
var source_weight_before: int:
	get: return _source_weight_before
var source_weight_after: int:
	get: return _source_weight_after
var new_weight: int:
	get: return _new_weight


func _init(
	p_outcome: int = Outcome.INVALID_SOURCE_INSTANCE,
	p_succeeded: bool = false,
	p_source_instance_id: StringName = &"",
	p_new_instance_id: StringName = &"",
	p_amount_requested: int = 0,
	p_source_amount_before: int = 0,
	p_source_amount_after: int = 0,
	p_new_amount: int = 0,
	p_source_weight_before: int = 0,
	p_source_weight_after: int = 0,
	p_new_weight: int = 0,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_source_instance_id = p_source_instance_id
	_new_instance_id = p_new_instance_id
	_amount_requested = p_amount_requested
	_source_amount_before = p_source_amount_before
	_source_amount_after = p_source_amount_after
	_new_amount = p_new_amount
	_source_weight_before = p_source_weight_before
	_source_weight_after = p_source_weight_after
	_new_weight = p_new_weight
