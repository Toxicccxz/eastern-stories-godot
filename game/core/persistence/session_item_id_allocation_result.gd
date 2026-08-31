class_name SessionItemIdAllocationResult
extends RefCounted

enum Outcome {
	INVALID_ALLOCATOR,
	COLLISION,
	SEQUENCE_OVERFLOW,
	ALLOCATED,
}

var _outcome: int = Outcome.INVALID_ALLOCATOR
var _item_instance_id: StringName = &""

var outcome: int:
	get:
		return _outcome
var item_instance_id: StringName:
	get:
		return _item_instance_id
var succeeded: bool:
	get:
		return _outcome == Outcome.ALLOCATED


func _init(
	p_outcome: int = Outcome.INVALID_ALLOCATOR,
	p_item_instance_id: StringName = &"",
) -> void:
	_outcome = p_outcome
	_item_instance_id = p_item_instance_id
