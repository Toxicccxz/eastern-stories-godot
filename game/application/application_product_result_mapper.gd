class_name ApplicationProductResultMapper
extends RefCounted


static func inspect_slot(result: GameSaveSlotInspectionResult) -> ApplicationSlotInspection:
	if result == null:
		return ApplicationSlotInspection.new()
	return _inspect_repository_outcome(result.canonical_outcome, result.recovery_sources())


static func _inspect_repository_result(
	result: GameSaveResult,
	recovery_sources: Array[int] = [],
) -> ApplicationSlotInspection:
	return _inspect_repository_outcome(result.outcome, recovery_sources)


static func _inspect_repository_outcome(
	outcome: int,
	recovery_sources: Array[int] = [],
) -> ApplicationSlotInspection:
	match outcome:
		GameSaveResult.Outcome.SUCCESS:
			return ApplicationSlotInspection.new(
				ApplicationSlotInspection.Availability.CONTINUE_AVAILABLE,
				&"save.continue_available",
			)
		GameSaveResult.Outcome.NO_SAVE:
			return ApplicationSlotInspection.new(
				ApplicationSlotInspection.Availability.NO_SAVE,
				&"save.no_save",
			)
		GameSaveResult.Outcome.BACKUP_AVAILABLE:
			return ApplicationSlotInspection.new(
				ApplicationSlotInspection.Availability.RECOVERY_REQUIRED,
				&"save.recovery_required",
				recovery_sources,
			)
		GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, GameSaveResult.Outcome.UNSUPPORTED_ITEM_SCHEMA:
			return ApplicationSlotInspection.new(
				ApplicationSlotInspection.Availability.UNSUPPORTED_SAVE,
				&"save.unsupported",
			)
		GameSaveResult.Outcome.READ_FAILED, GameSaveResult.Outcome.OPERATION_IN_PROGRESS:
			return ApplicationSlotInspection.new(
				ApplicationSlotInspection.Availability.STORAGE_FAILURE,
				&"save.storage_failure",
			)
	return ApplicationSlotInspection.new(
		ApplicationSlotInspection.Availability.SAVE_UNUSABLE,
		&"save.unusable",
	)


static func runtime_result(
	operation: int,
	result: OldPineRuntimeSaveLoadResult,
) -> ApplicationOperationResult:
	if result == null:
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.SESSION_FAILURE,
			&"operation.session_failure",
		)
	if result.succeeded():
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.SUCCESS,
			&"save.success"
			if operation == ApplicationOperationResult.Operation.SAVE
			else &"operation.success",
		)
	if result.outcome == OldPineRuntimeSaveLoadResult.Outcome.REQUEST_REJECTED:
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.REQUEST_BUSY,
			&"operation.busy",
		)
	if result.outcome == OldPineRuntimeSaveLoadResult.Outcome.RESTORE_FAILED:
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.RESTORE_FAILURE,
			&"continue.restore_failure",
		)
	if result.outcome == OldPineRuntimeSaveLoadResult.Outcome.SAVE_BLOCKED:
		return _save_blocked(operation, result.eligibility)
	if result.outcome == OldPineRuntimeSaveLoadResult.Outcome.CAPTURE_FAILED:
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.SAVE_CAPTURE_FAILURE,
			&"save.capture_failure",
		)
	if result.outcome == OldPineRuntimeSaveLoadResult.Outcome.REPOSITORY_FAILED:
		if operation == ApplicationOperationResult.Operation.SAVE:
			return ApplicationOperationResult.new(
				operation,
				ApplicationOperationResult.Outcome.SAVE_WRITE_FAILURE,
				&"save.write_failure",
			)
		return _repository_failure(operation, result.repository)
	if (
		operation == ApplicationOperationResult.Operation.SAVE
		and result.outcome == OldPineRuntimeSaveLoadResult.Outcome.NO_CURRENT_SESSION
	):
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_RUNTIME_NOT_READY,
			&"save.blocked.runtime_not_ready",
		)
	return ApplicationOperationResult.new(
		operation,
		ApplicationOperationResult.Outcome.SESSION_FAILURE,
		&"operation.session_failure",
	)


static func _repository_failure(
	operation: int,
	result: GameSaveResult,
) -> ApplicationOperationResult:
	var inspection: ApplicationSlotInspection = _inspect_repository_result(result)
	var outcome: int = ApplicationOperationResult.Outcome.INVALID_SAVE
	match inspection.availability():
		ApplicationSlotInspection.Availability.NO_SAVE:
			outcome = ApplicationOperationResult.Outcome.NO_SAVE
		ApplicationSlotInspection.Availability.RECOVERY_REQUIRED:
			outcome = ApplicationOperationResult.Outcome.RECOVERY_REQUIRED
		ApplicationSlotInspection.Availability.UNSUPPORTED_SAVE:
			outcome = ApplicationOperationResult.Outcome.UNSUPPORTED_SAVE
		ApplicationSlotInspection.Availability.STORAGE_FAILURE:
			outcome = ApplicationOperationResult.Outcome.STORAGE_FAILURE
	return ApplicationOperationResult.new(operation, outcome, inspection.message_key())


static func _save_blocked(
	operation: int,
	eligibility: OldPineSaveEligibilityResult,
) -> ApplicationOperationResult:
	if eligibility == null:
		return ApplicationOperationResult.new(
			operation,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_RUNTIME_NOT_READY,
			&"save.blocked.runtime_not_ready",
		)
	var outcome: int = ApplicationOperationResult.Outcome.SAVE_BLOCKED_RUNTIME_NOT_READY
	var message_key: StringName = &"save.blocked.runtime_not_ready"
	match eligibility.outcome:
		OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_ACTIVE, \
		OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_PARTIAL, \
		OldPineSaveEligibilityResult.Outcome.CAVE_EXIT_PENDING:
			outcome = ApplicationOperationResult.Outcome.SAVE_BLOCKED_WORLD_TRANSITION
			message_key = &"save.blocked.world_transition"
		OldPineSaveEligibilityResult.Outcome.INCOMPLETE_LIFECYCLE, \
		OldPineSaveEligibilityResult.Outcome.LIFE_EXISTENCE_CONTRADICTION:
			outcome = ApplicationOperationResult.Outcome.SAVE_BLOCKED_LIFECYCLE
			message_key = &"save.blocked.lifecycle"
		OldPineSaveEligibilityResult.Outcome.UNREPRESENTED_ATTRIBUTE_MODIFIER:
			outcome = ApplicationOperationResult.Outcome.SAVE_BLOCKED_TEMPORARY_EFFECT
			message_key = &"save.blocked.temporary_effect"
		OldPineSaveEligibilityResult.Outcome.PENDING_AGGRESSION, \
		OldPineSaveEligibilityResult.Outcome.COMBAT_CADENCE_ACTIVE, \
		OldPineSaveEligibilityResult.Outcome.OPPONENT_RELATIONSHIP, \
		OldPineSaveEligibilityResult.Outcome.LETHAL_MARKER, \
		OldPineSaveEligibilityResult.Outcome.BUSY, \
		OldPineSaveEligibilityResult.Outcome.INTERRUPT_THRESHOLD, \
		OldPineSaveEligibilityResult.Outcome.GUARDING:
			outcome = ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION
			message_key = &"save.blocked.combat_or_action"
	return ApplicationOperationResult.new(operation, outcome, message_key)
