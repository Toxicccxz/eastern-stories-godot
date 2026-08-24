class_name NativeItemStateRestoreResult
extends RefCounted

var _reconstructed_state: NativeItemDomainState
var _validation_result: NativeItemStateValidationResult

var succeeded: bool:
	get:
		return _reconstructed_state != null and _validation_result.succeeded
var reconstructed_state: NativeItemDomainState:
	get:
		return _reconstructed_state
var validation_result: NativeItemStateValidationResult:
	get:
		return NativeItemStateValidationResult.new(
			_validation_result.outcome,
			_validation_result.subject_id,
			_validation_result.related_id,
		)


func _init(
	p_reconstructed_state: NativeItemDomainState = null,
	p_validation_result: NativeItemStateValidationResult = null,
) -> void:
	_reconstructed_state = p_reconstructed_state
	_validation_result = (
		NativeItemStateValidationResult.new(
			NativeItemStateValidationResult.Outcome.INVALID_SNAPSHOT
		)
		if p_validation_result == null
		else NativeItemStateValidationResult.new(
			p_validation_result.outcome,
			p_validation_result.subject_id,
			p_validation_result.related_id,
		)
	)
