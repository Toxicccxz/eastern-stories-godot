class_name SessionItemIdAllocatorRestoreResult
extends RefCounted

enum Outcome {
	INVALID_SNAPSHOT,
	DUPLICATE_REPRESENTED_ID,
	MALFORMED_SAME_SCOPE_ID,
	SEQUENCE_OVERFLOW,
	RESTORED,
}

var _outcome: int = Outcome.INVALID_SNAPSHOT
var _allocator: SessionItemIdAllocator
var _subject_id: StringName = &""

var outcome: int:
	get:
		return _outcome
var allocator: SessionItemIdAllocator:
	get:
		return _allocator
var subject_id: StringName:
	get:
		return _subject_id
var succeeded: bool:
	get:
		return _outcome == Outcome.RESTORED and _allocator != null


func _init(
	p_outcome: int = Outcome.INVALID_SNAPSHOT,
	p_allocator: SessionItemIdAllocator = null,
	p_subject_id: StringName = &"",
) -> void:
	_outcome = p_outcome
	_allocator = p_allocator
	_subject_id = p_subject_id
