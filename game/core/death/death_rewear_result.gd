class_name DeathRewearResult
extends RefCounted

const TransferResultType := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)

enum Outcome {
	WORN_ON_CORPSE,
	REWORN_ON_VICTIM,
	ALREADY_WORN_ON_VICTIM,
	CUSTOM_SUCCESS_WITHOUT_WEAR,
	FALLBACK_TRANSFERRED,
	FALLBACK_TRANSFER_FAILED,
	DEPENDENCY_UNAVAILABLE,
	INVALID_ARMOR_FACTS,
}

enum WornLocation {
	NONE,
	VICTIM,
	CORPSE,
}

var _outcome: int
var _item_instance_id: StringName
var _policy: int
var _reported_wear_success: bool
var _worn_location: int
var _fallback_result: TransferResultType

var outcome: int:
	get: return _outcome
var item_instance_id: StringName:
	get: return _item_instance_id
var policy: int:
	get: return _policy
var reported_wear_success: bool:
	get: return _reported_wear_success
var worn_location: int:
	get: return _worn_location
var fallback_result: TransferResultType:
	get: return _fallback_result


func _init(
	p_outcome: int = Outcome.INVALID_ARMOR_FACTS,
	p_item_instance_id: StringName = &"",
	p_policy: int = 0,
	p_reported_wear_success: bool = false,
	p_worn_location: int = WornLocation.NONE,
	p_fallback_result: TransferResultType = null,
) -> void:
	_outcome = p_outcome
	_item_instance_id = p_item_instance_id
	_policy = p_policy
	_reported_wear_success = p_reported_wear_success
	_worn_location = p_worn_location
	_fallback_result = p_fallback_result
