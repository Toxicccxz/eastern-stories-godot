class_name GameSaveSlotInspectionResult
extends RefCounted

var canonical_outcome: int
var _recovery_sources: Array[int] = []


func _init(
	p_canonical_outcome: int = GameSaveResult.Outcome.OPERATION_IN_PROGRESS,
	p_recovery_sources: Array[int] = [],
) -> void:
	canonical_outcome = p_canonical_outcome
	for source: int in p_recovery_sources:
		if GameSaveRecoverySource.is_valid(source) and not _recovery_sources.has(source):
			_recovery_sources.append(source)


func recovery_sources() -> Array[int]:
	return _recovery_sources.duplicate()


func has_recovery_source(source: int) -> bool:
	return _recovery_sources.has(source)
