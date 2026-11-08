class_name OldPineSessionLoadCoordinator
extends RefCounted

const Result := preload("res://runtime/persistence/oldpine_runtime_save_load_result.gd")

var _repository: GameSaveRepository
var _operation_in_progress: bool = false
## The worker task reading a save for a start in slices, or writing a Save in play, or
## inspecting the slots (-1: none): waited for at quit.
var _reading_task: int = -1


func _init(repository: GameSaveRepository) -> void:
	_repository = repository


func operation_in_progress() -> bool:
	return _operation_in_progress


## The slot Save, Load and the recovery work on.
func selected_slot() -> StringName:
	return _repository.slot_id()


func select_slot(slot_id: StringName) -> bool:
	return not _operation_in_progress and _repository.select_slot(slot_id)


func repository_for(slot_id: StringName) -> GameSaveRepository:
	return _repository.for_slot(slot_id)


## Each slot's row, the player's first and the autosave's last; the 决战前 one after it once it
## holds something (DECISIONS「决战前存档」).
func slot_summaries() -> Array[GameSaveSlotSummary]:
	var summaries: Array[GameSaveSlotSummary] = []
	for slot_id: StringName in GameSaveSnapshot.MANUAL_SLOT_IDS + [GameSaveSnapshot.AUTO_SLOT_ID]:
		summaries.append(repository_for(slot_id).read_summary())
	var kept: GameSaveSlotSummary = repository_for(GameSaveSnapshot.KEEP_SLOT_ID).read_summary()
	if kept.state != GameSaveSlotSummary.State.EMPTY or kept.recoverable:
		summaries.append(kept)
	return summaries


func inspect_slot() -> GameSaveSlotInspectionResult:
	if not _begin_operation():
		return GameSaveSlotInspectionResult.new(
			GameSaveResult.Outcome.OPERATION_IN_PROGRESS,
		)
	var result: GameSaveSlotInspectionResult = _repository.inspect_slot()
	_operation_in_progress = false
	return result


func save_current(session: WorldSessionController) -> OldPineRuntimeSaveLoadResult:
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
				null,
				_repository.slot_id(),
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


## Save in play without holding the frame (owner, 2026-11-07: 存档 froze the game for
## seconds): the world is captured here, while the tree is paused; the checks, the encoding
## and the file work run on a worker thread while `frame` ticks and the busy note animates,
## as the autosave's do. Without a slice or a frame, save_current() as it was.
func save_current_aside(session: WorldSessionController, slice_usec: int, frame: Signal = Signal()) -> OldPineRuntimeSaveLoadResult:
	if slice_usec <= 0 or frame.is_null():
		return save_current(session)
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
				null,
				_repository.slot_id(),
				false,
			)
			if not captured.succeeded():
				result = Result.failure(Result.Outcome.CAPTURE_FAILED)
				result.capture = captured
			else:
				var repository: GameSaveRepository = _repository
				var written: Array = await _aside(func() -> Array:
					var checked: OldPineWorldCaptureResult = OldPineWorldSaveCapture.check(captured.snapshot)
					var saved: GameSaveResult = repository.save(captured.snapshot) if checked.succeeded() else null
					if saved != null and saved.succeeded():
						repository.read_summary() # Its row is read here, not when the list opens.
					return [checked, saved], frame)
				var checked: OldPineWorldCaptureResult = null if written.size() < 2 else written[0]
				if checked == null:
					result = Result.failure(Result.Outcome.REPOSITORY_FAILED)
					result.repository = GameSaveResult.failure(GameSaveResult.Outcome.WRITE_FAILED, "repository", "the save's worker ended without a result")
				elif not checked.succeeded():
					result = Result.failure(Result.Outcome.CAPTURE_FAILED)
					result.capture = checked
				else:
					var saved: GameSaveResult = written[1]
					result = Result.success(session) if saved.succeeded() else Result.failure(Result.Outcome.REPOSITORY_FAILED)
					result.capture = checked
					result.repository = saved
	_operation_in_progress = false
	return result


## The slots' rows and what the slot 继续 reads says, read on a worker thread while `frame`
## ticks (a whole save is decoded and checked: seconds). `newest`: the newest save's slot,
## else the one selected. Returns [rows, slot, inspection]; the caller selects the slot.
## Without a slice or a frame, read here.
func inspect_aside(newest: bool, slice_usec: int, frame: Signal = Signal()) -> Array:
	var selected: StringName = _repository.slot_id()
	var work := func() -> Array:
		var rows: Array[GameSaveSlotSummary] = slot_summaries()
		var slot: StringName = GameSaveSlotSummary.newest(rows, selected) if newest else selected
		return [rows, slot, repository_for(slot).inspect_slot()]
	if slice_usec <= 0 or frame.is_null():
		return work.call()
	_operation_in_progress = true
	var out: Array = await _aside(work, frame)
	_operation_in_progress = false
	if out.size() < 3:
		var none: Array[GameSaveSlotSummary] = []
		return [none, selected, GameSaveSlotInspectionResult.new(GameSaveResult.Outcome.READ_FAILED)]
	return out


## `work` on a worker thread; waits on `frame` until it is done.
func _aside(work: Callable, frame: Signal) -> Array:
	var out: Array = []
	_reading_task = WorkerThreadPool.add_task(func() -> void: out.append(work.call()), false, "save aside")
	while not WorkerThreadPool.is_task_completed(_reading_task):
		await frame
	wait_for_reads()
	return out[0] if not out.is_empty() else []


func load_replacing(
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	if not _begin_operation():
		return Result.failure(Result.Outcome.REQUEST_REJECTED)
	var result := _load_replacing_impl(current, session_slot, staging_slot)
	_operation_in_progress = false
	return result


func load_recovery_replacing(
	source: int,
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	if not GameSaveRecoverySource.is_valid(source) or not _begin_operation():
		return Result.failure(Result.Outcome.REQUEST_REJECTED)
	var loaded: GameSaveResult = _repository.load_recovery(source)
	var result := _restore_loaded(
		loaded,
		current,
		session_slot,
		staging_slot,
	)
	_operation_in_progress = false
	return result


## load_replacing with the candidate's start over frames, `slice_usec` a frame (DECISIONS
## 「加载画面」): the same checks and swap, the world built while the title or the busy note
## plays on; the save is read and checked on a worker thread while `frame` ticks. With 0 it
## is load_replacing.
func load_replacing_in_slices(
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
	slice_usec: int,
	frame: Signal = Signal(),
) -> OldPineRuntimeSaveLoadResult:
	if not _begin_operation():
		return Result.failure(Result.Outcome.REQUEST_REJECTED)
	var loaded: GameSaveResult = await _read_aside(_repository.load, slice_usec, frame)
	var result: OldPineRuntimeSaveLoadResult = await _restore_loaded_in_slices(loaded, current, session_slot, staging_slot, slice_usec, frame)
	_operation_in_progress = false
	return result


## load_recovery_replacing over frames, as load_replacing_in_slices.
func load_recovery_replacing_in_slices(
	source: int,
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
	slice_usec: int,
	frame: Signal = Signal(),
) -> OldPineRuntimeSaveLoadResult:
	if not GameSaveRecoverySource.is_valid(source) or not _begin_operation():
		return Result.failure(Result.Outcome.REQUEST_REJECTED)
	var loaded: GameSaveResult = await _read_aside(_repository.load_recovery.bind(source), slice_usec, frame)
	var result: OldPineRuntimeSaveLoadResult = await _restore_loaded_in_slices(loaded, current, session_slot, staging_slot, slice_usec, frame)
	_operation_in_progress = false
	return result


func _load_replacing_impl(
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	var loaded: GameSaveResult = _repository.load()
	return _restore_loaded(loaded, current, session_slot, staging_slot)


func _restore_loaded(
	loaded: GameSaveResult,
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	var refused: OldPineRuntimeSaveLoadResult = _refuse_restore(loaded, session_slot, staging_slot)
	if refused != null:
		return refused
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(
		loaded.snapshot,
		staging_slot,
	)
	return _swap_in(loaded, restored, current, session_slot)


func _restore_loaded_in_slices(
	loaded: GameSaveResult,
	current: WorldSessionController,
	session_slot: Node,
	staging_slot: Node,
	slice_usec: int,
	frame: Signal,
) -> OldPineRuntimeSaveLoadResult:
	var refused: OldPineRuntimeSaveLoadResult = _refuse_restore(loaded, session_slot, staging_slot)
	if refused != null:
		return refused
	# Slices need a frame to come back on; without one the candidate starts in one go.
	var begun: OldPineWorldRestoreResult = OldPineWorldRestoreService.begin_candidate(loaded.snapshot, staging_slot, 0 if frame.is_null() else slice_usec)
	if begun.candidate != null and not begun.candidate.start_finished():
		await begun.candidate.start_done
		# Not inside the candidate's own start_done: a failed one is freed, which an object
		# still emitting refuses. The staged candidate processes nothing for this frame.
		await frame
	var restored: OldPineWorldRestoreResult = begun if begun.candidate == null else OldPineWorldRestoreService.finish_candidate(begun)
	return _swap_in(loaded, restored, current, session_slot)


## A start in slices reads, decodes and checks the save on a worker thread (seconds for a big
## save) while `frame` ticks and the title draws on; the autosave writes there the same way.
## Without a slice, or a frame to wait on, it is read here.
func _read_aside(read: Callable, slice_usec: int, frame: Signal) -> GameSaveResult:
	if slice_usec <= 0 or frame.is_null():
		return read.call()
	var out: Array[GameSaveResult] = []
	_reading_task = WorkerThreadPool.add_task(func() -> void: out.append(read.call()), false, "save read")
	while not WorkerThreadPool.is_task_completed(_reading_task):
		await frame
	wait_for_reads()
	return out[0] if not out.is_empty() else GameSaveResult.failure(GameSaveResult.Outcome.READ_FAILED, "repository")


## A save still being read on a worker thread is waited for (the game closing mid-Continue).
func wait_for_reads() -> void:
	if _reading_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_reading_task)
		_reading_task = -1


## Why a save read as `loaded` cannot be restored here (null: it can be tried).
func _refuse_restore(loaded: GameSaveResult, session_slot: Node, staging_slot: Node) -> OldPineRuntimeSaveLoadResult:
	if session_slot == null or staging_slot == null:
		return Result.failure(Result.Outcome.NO_CURRENT_SESSION)
	if not loaded.succeeded():
		var repository_failure := Result.failure(Result.Outcome.REPOSITORY_FAILED)
		repository_failure.repository = loaded
		return repository_failure
	return null


## The built candidate takes `current`'s place in session_slot, or everything is put back.
func _swap_in(
	loaded: GameSaveResult,
	restored: OldPineWorldRestoreResult,
	current: WorldSessionController,
	session_slot: Node,
) -> OldPineRuntimeSaveLoadResult:
	if not restored.succeeded() or not _candidate_transients_are_fresh(restored.candidate):
		_discard_candidate(restored.candidate)
		var restore_failure := Result.failure(Result.Outcome.RESTORE_FAILED)
		restore_failure.repository = loaded
		restore_failure.restore = restored
		return restore_failure
	var candidate: WorldSessionController = restored.candidate
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
	var reparented: bool = _reparent_candidate(candidate, session_slot)
	candidate.complete_session_swap_reparent()
	if (
		not reparented
		or candidate.get_parent() != session_slot
		or candidate.active_map_child_count() != 1
	):
		_discard_candidate(candidate)
		if current != null and not current.resume_after_failed_session_swap():
			return Result.failure(Result.Outcome.ROLLBACK_FAILED)
		return Result.failure(Result.Outcome.ACTIVATION_FAILED)
	if current != null:
		# Out of the slot now: one Session stands in it, and its pace leaves the catalog to the new one's.
		if current.get_parent() != null:
			current.get_parent().remove_child(current)
		current.queue_free()
	var success := Result.success(candidate)
	success.repository = loaded
	success.restore = restored
	return success


func _activate_candidate(candidate: WorldSessionController) -> bool:
	return candidate != null and candidate.activate_restore_candidate()


func _reparent_candidate(
	candidate: WorldSessionController,
	session_slot: Node,
) -> bool:
	if candidate == null or session_slot == null or candidate.get_parent() == null:
		return false
	candidate.reparent(session_slot)
	return candidate.get_parent() == session_slot


static func _candidate_transients_are_fresh(session: WorldSessionController) -> bool:
	if session == null or not session.is_restore_candidate_staged():
		return false
	for map: WorldMapController in session.world_maps():
		if map.aggression_adapter().pending_count() != 0 or map.lifecycle_is_pending():
			return false
	var player: WorldPlayerRuntimeState = session.player_runtime()
	if not _runtime_transients_are_fresh(player.relationship):
		return false
	for npc: NpcRuntimeState in session.world_npcs():
		if not _runtime_transients_are_fresh(npc.relationship):
			return false
	return true


## Busy is saved and restored as it was (owner, 2026-10-17); the fight relations start fresh.
static func _runtime_transients_are_fresh(relationship: CombatRelationshipState) -> bool:
	return (
		relationship != null
		and relationship.opponent_ids().is_empty()
		and relationship.lethal_target_ids().is_empty()
		and not relationship.guarding
		and relationship.last_opponent_id.is_empty()
	)


static func _discard_candidate(candidate: WorldSessionController) -> void:
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
