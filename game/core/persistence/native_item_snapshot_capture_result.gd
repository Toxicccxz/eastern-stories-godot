class_name NativeItemSnapshotCaptureResult
extends RefCounted

var _snapshot: NativeItemStateSnapshot
var _validation_result: NativeItemStateValidationResult

var succeeded: bool:
	get:
		return _snapshot != null and _validation_result.succeeded
var snapshot: NativeItemStateSnapshot:
	get:
		return null if _snapshot == null else _snapshot.duplicate_snapshot()
var validation_result: NativeItemStateValidationResult:
	get:
		return NativeItemStateValidationResult.new(
			_validation_result.outcome,
			_validation_result.subject_id,
			_validation_result.related_id,
		)


func _init(
	p_snapshot: NativeItemStateSnapshot = null,
	p_validation_result: NativeItemStateValidationResult = null,
) -> void:
	_snapshot = null if p_snapshot == null else p_snapshot.duplicate_snapshot()
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
