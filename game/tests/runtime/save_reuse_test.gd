extends RefCounted

## Save and Continue prepare a snapshot once where they have checked it already
## (performance, owner 2026-10-11): validate() keeps its preparation on the snapshot for the
## next prepare() or validate() of that content, once; an exact copy takes it along; a
## change of the content drops it; prepare() never keeps one.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Composition := preload("res://runtime/persistence/oldpine_world_restore_composition.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	_test_kept_once(session)
	_test_copies_and_changes(session)
	_test_failures_keep_nothing(session)
	await _test_save_and_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## Capture checks its snapshot: the first prepare() of that content takes what the check
## made, the next prepares anew; both are the same restored world.
func _test_kept_once(session: WorldSessionController) -> void:
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var kept: OldPineWorldRestoreResult = Composition.prepare(snapshot)
	var fresh: OldPineWorldRestoreResult = Composition.prepare(snapshot)
	_check(kept.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS and fresh.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS, "both prepare")
	_check(kept.preparation != fresh.preparation and kept.preparation.player != fresh.preparation.player, "the second is prepared anew, sharing nothing")
	_check(snapshot.take_derived() == null, "prepare() keeps nothing")
	_check(_same_preparation(kept.preparation, fresh.preparation), "the kept preparation is what preparing gives")


func _test_copies_and_changes(session: WorldSessionController) -> void:
	var snapshot: GameSaveSnapshot = Work.capture(session)
	snapshot.take_derived()
	var verdict: OldPineWorldRestoreResult = Composition.validate(snapshot)
	_check(verdict.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS and verdict.preparation == null, "validate() gives its verdict, never the preparation")
	var copy: GameSaveSnapshot = snapshot.duplicate_snapshot()
	_check(snapshot.take_derived() == null and copy.take_derived() != null, "an exact copy takes the kept preparation along")
	_check(Composition.validate(snapshot).outcome == OldPineWorldRestoreResult.Outcome.SUCCESS, "checked again")
	snapshot.with_floor_items(snapshot.floor_items)
	_check(snapshot.take_derived() == null, "a change of the content drops it (floor items)")
	Composition.validate(snapshot)
	snapshot.with_maze_notes(snapshot.maze_notes)
	_check(snapshot.take_derived() == null, "and the maze notes")


func _test_failures_keep_nothing(session: WorldSessionController) -> void:
	var snapshot: GameSaveSnapshot = Work.capture(session)
	snapshot.take_derived()
	var bad := GameSaveValueTypes.FloorItemSnapshot.new(&"no.such.item", GameSaveValueTypes.WorldLocationSnapshot.new(&"snow", &"snow.inn", &"snow.inn", &"snow.inn"), GameSaveValueTypes.MapPositionSnapshot.new(0.0, 0.0))
	snapshot.with_floor_items([bad])
	var verdict: OldPineWorldRestoreResult = Composition.validate(snapshot)
	_check(verdict.outcome != OldPineWorldRestoreResult.Outcome.SUCCESS and verdict.path == "floor_items", "a floor item that does not exist is refused: %s" % verdict.path)
	_check(snapshot.take_derived() == null, "a refused check keeps nothing")
	var direct: OldPineWorldRestoreResult = Composition.prepare(snapshot)
	_check(direct.outcome == verdict.outcome and direct.path == verdict.path and direct.detail == verdict.detail, "the verdict is prepare()'s outcome, path and detail")


## Save, then Continue from the file, as the repository and restore service do them.
func _test_save_and_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var repository := SourceEntrySaveRepository.new(GameSaveStorageProfile.isolated_test("save-reuse"))
	var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-11T00:00:00Z")
	_check(repository.save(captured.snapshot).succeeded(), "saved")
	var loaded: GameSaveResult = repository.load()
	_check(loaded.succeeded(), "read back")
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(loaded.snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "continued from what was read")
	if restored.succeeded():
		_check(restored.candidate.player_runtime().state.attributes.strength == session.player_runtime().state.attributes.strength, "the same player")
		restored.candidate.free()
		await tree.process_frame


func _same_preparation(a: OldPineWorldRestorePreparation, b: OldPineWorldRestorePreparation) -> bool:
	if a.player.character_id != b.player.character_id or a.player_position != b.player_position:
		return false
	if a.player.state.attributes.strength != b.player.state.attributes.strength or a.npc_entries().size() != b.npc_entries().size():
		return false
	for index: int in range(a.npc_entries().size()):
		var left: OldPineRestoredNpcEntry = a.npc_entries()[index]
		var right: OldPineRestoredNpcEntry = b.npc_entries()[index]
		if left.runtime.character_id != right.runtime.character_id or left.map_position != right.map_position or left.runtime.character_state.attributes.strength != right.runtime.character_state.attributes.strength:
			return false
	return a.corpse_entries().size() == b.corpse_entries().size() and a.item_index.snapshot_ids() == b.item_index.snapshot_ids()


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
