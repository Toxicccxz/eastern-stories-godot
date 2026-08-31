class_name OldPineSessionLoadCoordinator
extends RefCounted

const Result := preload("res://runtime/persistence/oldpine_runtime_save_load_result.gd")

var _repository: GameSaveRepository
var _operation_in_progress: bool = false


func _init(repository: GameSaveRepository) -> void:
	_repository = repository


func operation_in_progress() -> bool:
	return _operation_in_progress


func save_current(session: OldPineWorldSessionController) -> OldPineRuntimeSaveLoadResult:
	if not _begin_operation():
		return Result.failure(Result.Outcome.REQUEST_REJECTED)
	var result := Result.failure(Result.Outcome.NO_CURRENT_SESSION)
	if session != null:
		var eligibility := OldPineSaveEligibility.inspect(session)
		if not eligibility.allowed():
			result = Result.failure(Result.Outcome.SAVE_BLOCKED)
			result.eligibility = eligibility
		else:
			var timestamp: String = Time.get_datetime_string_from_system(true, false) + "Z"
			var captured := OldPineWorldSaveCapture.new().capture(
				session,
				_repository.storage_profile_id(),
				timestamp,
			)
			if not captured.succeeded():
				result = Result.failure(Result.Outcome.CAPTURE_FAILED)
				result.capture = captured
			else:
				var saved: GameSaveResult = _repository.save(captured.snapshot)
				if saved.succeeded():
					result = Result.success(session)
				else:
					result = Result.failure(Result.Outcome.REPOSITORY_FAILED)
				result.capture = captured
				result.repository = saved
	_operation_in_progress = false
	return result


func load_replacing(
	current: OldPineWorldSessionController,
	session_slot: Node,
	staging_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	if not _begin_operation():
		return Result.failure(Result.Outcome.REQUEST_REJECTED)
	var result := _load_replacing_impl(current, session_slot, staging_slot)
	_operation_in_progress = false
	return result


func _load_replacing_impl(
	current: OldPineWorldSessionController,
	session_slot: Node,
	staging_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	if session_slot == null or staging_slot == null:
		return Result.failure(Result.Outcome.NO_CURRENT_SESSION)
	var loaded: GameSaveResult = _repository.load()
	if not loaded.succeeded():
		var repository_failure := Result.failure(Result.Outcome.REPOSITORY_FAILED)
		repository_failure.repository = loaded
		return repository_failure
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		loaded.snapshot,
		staging_slot,
	)
	if not restored.succeeded() or not _candidate_transients_are_fresh(restored.candidate):
		_discard_candidate(restored.candidate)
		var restore_failure := Result.failure(Result.Outcome.RESTORE_FAILED)
		restore_failure.repository = loaded
		restore_failure.restore = restored
		return restore_failure
	var candidate: OldPineWorldSessionController = restored.candidate
	if current != null and not current.suspend_for_session_swap():
		_discard_candidate(candidate)
		return Result.failure(Result.Outcome.SESSION_SUSPEND_FAILED)
	if not _activate_candidate(candidate):
		_discard_candidate(candidate)
		if current != null and not current.resume_after_failed_session_swap():
			return Result.failure(Result.Outcome.ROLLBACK_FAILED)
		return Result.failure(Result.Outcome.ACTIVATION_FAILED)
	if not candidate.begin_session_swap_reparent():
		_discard_candidate(candidate)
		if current != null and not current.resume_after_failed_session_swap():
			return Result.failure(Result.Outcome.ROLLBACK_FAILED)
		return Result.failure(Result.Outcome.ACTIVATION_FAILED)
	candidate.reparent(session_slot)
	candidate.complete_session_swap_reparent()
	if candidate.get_parent() != session_slot or candidate.active_map_child_count() != 1:
		_discard_candidate(candidate)
		if current != null and not current.resume_after_failed_session_swap():
			return Result.failure(Result.Outcome.ROLLBACK_FAILED)
		return Result.failure(Result.Outcome.ACTIVATION_FAILED)
	if current != null:
		current.queue_free()
	var success := Result.success(candidate)
	success.repository = loaded
	success.restore = restored
	return success


func _activate_candidate(candidate: OldPineWorldSessionController) -> bool:
	return candidate != null and candidate.activate_restore_candidate()


static func _candidate_transients_are_fresh(session: OldPineWorldSessionController) -> bool:
	if session == null or not session.is_restore_candidate_staged():
		return false
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	if outdoor == null or outdoor.aggression_adapter().pending_count() != 0 or outdoor.lifecycle_is_pending():
		return false
	var player: WorldPlayerRuntimeState = session.player_runtime()
	if not _runtime_transients_are_fresh(player.relationship, player.busy):
		return false
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if not _runtime_transients_are_fresh(npc.relationship, npc.busy):
			return false
	return true


static func _runtime_transients_are_fresh(
	relationship: CombatRelationshipState,
	busy: ActionBusyState,
) -> bool:
	return (
		relationship != null
		and relationship.opponent_ids().is_empty()
		and relationship.lethal_target_ids().is_empty()
		and not relationship.guarding
		and relationship.last_opponent_id.is_empty()
		and busy != null
		and busy.busy_value == 0
		and busy.interrupt_threshold == 0
	)


static func _discard_candidate(candidate: OldPineWorldSessionController) -> void:
	if candidate == null:
		return
	if candidate.get_parent() != null:
		candidate.get_parent().remove_child(candidate)
	candidate.queue_free()


func _begin_operation() -> bool:
	if _operation_in_progress or _repository == null:
		return false
	_operation_in_progress = true
	return true
