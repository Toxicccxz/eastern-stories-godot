class_name GameAutosave
extends RefCounted

## 自动存档 (现代基线 A; DECISIONS「自动存档」): one slot, rolled at the moments a session names
## (autosave_moment: a map change landed, a fight over), at least pacing.json's
## autosave_min_seconds apart. A moment that cannot save is skipped, not queued: the same
## OldPineSaveEligibility as the player's Save, and no ghost (the slot is always someone alive,
## or 回到上次自动存档 would bring back the ghost). Only the capture runs on the main thread,
## where the view is dark; the checks, the encoding and the file work are the same as a Save's
## and run on a worker while the world goes on. Reads the world, draws nothing from its streams.

var _repository: GameSaveRepository
## The WorkerThreadPool task under way, or -1.
var _task: int = -1
## What the task under way ended in.
var _saved: GameSaveResult
var _last_ms: int = -1


func _init(repository: GameSaveRepository) -> void:
	_repository = repository


## The interval starts now (a save was just loaded: the slot has nothing to add yet).
func restart_interval(now_ms: int = Time.get_ticks_msec()) -> void:
	_last_ms = now_ms


## Whether a moment at `now_ms` saves.
func due(session: WorldSessionController, now_ms: int = Time.get_ticks_msec()) -> bool:
	var seconds: int = GameContent.catalog().pacing().autosave_min_seconds
	if seconds <= 0 or _task >= 0 or session == null or session.player_runtime() == null:
		return false
	if _last_ms >= 0 and now_ms - _last_ms < seconds * 1000:
		return false
	return not session.player_runtime().state.ghost and OldPineSaveEligibility.inspect(session).allowed()


## Takes the world as it is and leaves the rest to a worker. Whether it set off.
func begin(session: WorldSessionController, now_ms: int = Time.get_ticks_msec()) -> bool:
	if not due(session, now_ms):
		return false
	var timestamp: String = Time.get_datetime_string_from_system(true, false) + "Z"
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, _repository.storage_profile_id(), timestamp, null, GameSaveSnapshot.AUTO_SLOT_ID, false)
	# The moment is spent either way: a capture that fails now would fail again at the next door.
	_last_ms = now_ms
	if not captured.succeeded():
		_saved = GameSaveResult.failure(GameSaveResult.Outcome.INVALID_SNAPSHOT, captured.path, captured.detail)
		return false
	var snapshot: GameSaveSnapshot = captured.snapshot
	_saved = null
	_task = WorkerThreadPool.add_task(_write.bind(snapshot), false, "autosave")
	return true


func _write(snapshot: GameSaveSnapshot) -> void:
	var checked: GameSaveResult = GameSaveSnapshotValidator.validate(snapshot)
	_saved = checked if not checked.succeeded() else _repository.save(snapshot)


func running() -> bool:
	return _task >= 0


## What the finished save ended in, once; null while there is none to tell of.
func take_finished() -> GameSaveResult:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return null
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var result: GameSaveResult = _saved
	_saved = null
	return result


## Waits for the save under way: a Load, a list of the slots or the end of the session comes
## after it. What it ended in stays for take_finished().
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
