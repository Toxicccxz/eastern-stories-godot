class_name NativeItemRestoreCompositionResult
extends RefCounted

var _domain_state: NativeItemDomainState
var _item_index: WorldItemInstanceIndex
var _allocator: SessionItemIdAllocator
var _item_validation: NativeItemStateValidationResult
var _allocator_restore_outcome: int = (
	SessionItemIdAllocatorRestoreResult.Outcome.INVALID_SNAPSHOT
)
var _allocator_subject_id: StringName = &""

var succeeded: bool:
	get:
		return (
			_domain_state != null
			and _item_index != null
			and _allocator != null
			and _item_validation.succeeded
			and _allocator_restore_outcome
			== SessionItemIdAllocatorRestoreResult.Outcome.RESTORED
		)
var domain_state: NativeItemDomainState:
	get:
		return _domain_state
var item_index: WorldItemInstanceIndex:
	get:
		return _item_index
var allocator: SessionItemIdAllocator:
	get:
		return _allocator
var item_validation: NativeItemStateValidationResult:
	get:
		return NativeItemStateValidationResult.new(
			_item_validation.outcome,
			_item_validation.subject_id,
			_item_validation.related_id,
		)
var allocator_restore_outcome: int:
	get:
		return _allocator_restore_outcome
var allocator_subject_id: StringName:
	get:
		return _allocator_subject_id


func _init(
	p_domain_state: NativeItemDomainState = null,
	p_item_index: WorldItemInstanceIndex = null,
	p_allocator: SessionItemIdAllocator = null,
	p_item_validation: NativeItemStateValidationResult = null,
	p_allocator_restore_result: SessionItemIdAllocatorRestoreResult = null,
) -> void:
	_domain_state = p_domain_state
	_item_index = p_item_index
	_allocator = p_allocator
	_item_validation = (
		NativeItemStateValidationResult.new(
			NativeItemStateValidationResult.Outcome.INVALID_SNAPSHOT
		)
		if p_item_validation == null
		else NativeItemStateValidationResult.new(
			p_item_validation.outcome,
			p_item_validation.subject_id,
			p_item_validation.related_id,
		)
	)
	if p_allocator_restore_result != null:
		_allocator_restore_outcome = p_allocator_restore_result.outcome
		_allocator_subject_id = p_allocator_restore_result.subject_id
