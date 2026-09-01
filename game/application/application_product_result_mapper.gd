class_name ApplicationProductResultMapper
extends RefCounted


static func inspect_slot(result: GameSaveResult) -> ApplicationSlotInspection:
	if result == null:
		return ApplicationSlotInspection.new()
	match result.outcome:
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
			&"operation.success",
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
	if result.outcome == OldPineRuntimeSaveLoadResult.Outcome.REPOSITORY_FAILED:
		return _repository_failure(operation, result.repository)
	return ApplicationOperationResult.new(
		operation,
		ApplicationOperationResult.Outcome.SESSION_FAILURE,
		&"operation.session_failure",
	)


static func _repository_failure(
	operation: int,
	result: GameSaveResult,
) -> ApplicationOperationResult:
	var inspection: ApplicationSlotInspection = inspect_slot(result)
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
