class_name GameDeathSave
extends RefCounted

## Native (全项目审查 补充 D; DECISIONS「死前存档」): as the death card comes up, the autosave file
## as it lies on disk is copied byte for byte into the 死前存档 slot (GameSaveSnapshot.DEATH_SLOT_ID);
## nothing is captured, the dead world is not the one to keep. The autosave rolls on after the
## return to life (arriving at the 城隍庙 is one of its moments) and keeps one .bak; this copy stays
## until the next death replaces it, and not even then while an earlier corpse of the player still
## holds things (the copy from before that death is the way back to them). Only an autosave of
## this very journey is copied. The copy writes as a save does (GameSaveRepository.copy_from(): the
## .tmp read back in full, the main file to the .bak); it runs on a worker.

var _auto: GameSaveRepository
var _death: GameSaveRepository
## The WorkerThreadPool task under way, or -1.
var _task: int = -1
var _copied: GameSaveResult


func _init(auto: GameSaveRepository, death: GameSaveRepository) -> void:
	_auto = auto
	_death = death


## The player died, leaving corpse `corpse_id` (empty: none). Whether a copy set off.
func begin(session: WorldSessionController, corpse_id: StringName) -> bool:
	if _task >= 0 or session == null or corpse_id.is_empty() or session.item_id_allocator() == null:
		return false
	var scope: StringName = session.item_id_allocator().scope
	var auto: GameSaveSlotSummary = _auto.read_summary()
	if auto.state != GameSaveSlotSummary.State.READY or auto.run_id != scope:
		return false
	if keeps_earlier(session, corpse_id):
		return false
	_copied = null
	_task = WorkerThreadPool.add_task(_copy, false, "death save")
	return true


## Whether the slot keeps what it holds: a save of this journey, while a corpse of the player other
## than `corpse_id` still holds things.
func keeps_earlier(session: WorldSessionController, corpse_id: StringName) -> bool:
	var held: GameSaveSlotSummary = _death.read_summary()
	if held.state != GameSaveSlotSummary.State.READY or held.run_id != session.item_id_allocator().scope:
		return false
	for place: WorldLeftBehind.Place in WorldLeftBehind.corpses(session):
		if place.id != corpse_id:
			return true
	return false


func _copy() -> void:
	_copied = _death.copy_from(_auto)
	if _copied.succeeded():
		_death.read_summary() # Its row is read here, not when the list opens.


func running() -> bool:
	return _task >= 0


## What the finished copy ended in, once; null while there is none to tell of.
func take_finished() -> GameSaveResult:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return null
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var result: GameSaveResult = _copied
	_copied = null
	return result


## Waits for the copy under way.
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
