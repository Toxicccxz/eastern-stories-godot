class_name CorpseContentTransferResult
extends RefCounted

const TransferResultType := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)

enum Outcome {
	TRANSFERRED,
	INVALID_DOMAIN_STATE,
	ITEM_NOT_DIRECT_CORPSE_CONTENT,
	CORPSE_WORN_LOCKED,
	TRANSFER_FAILED,
}

var _outcome: int
var _succeeded: bool
var _item_instance_id: StringName
var _corpse_worn_released: bool
var _transfer_result: TransferResultType

var outcome: int:
	get: return _outcome
var succeeded: bool:
	get: return _succeeded
var item_instance_id: StringName:
	get: return _item_instance_id
var corpse_worn_released: bool:
	get: return _corpse_worn_released
var transfer_result: TransferResultType:
	get: return _transfer_result


func _init(
	p_outcome: int = Outcome.INVALID_DOMAIN_STATE,
	p_succeeded: bool = false,
	p_item_instance_id: StringName = &"",
	p_corpse_worn_released: bool = false,
	p_transfer_result: TransferResultType = null,
) -> void:
	_outcome = p_outcome
	_succeeded = p_succeeded
	_item_instance_id = p_item_instance_id
	_corpse_worn_released = p_corpse_worn_released
	_transfer_result = p_transfer_result
