extends RefCounted
## 界面微调 (owner 2026-11-07: 存档 and 回到主菜单 froze the game): a Save in play and the main
## menu's look at the saves run their heavy part on a worker thread while frames go on, and give
## what the old one-frame way gave; the slot list's rows are remembered by the file's bytes.

const HOST_SCENE: PackedScene = preload("res://scenes/runtime/oldpine_game_runtime_host.tscn")
const Transaction := preload("res://tests/runtime/oldpine_save_load_transaction_test.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_save_and_inspect_aside(tree)
	_test_remembered_rows()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_save_and_inspect_aside(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("save-aside-%d" % Time.get_ticks_usec())
	var files := Transaction.MemoryFiles.new()
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	_check(host.configure_before_start(profile, files), "the test profile configures")
	tree.root.add_child(host)
	await tree.process_frame
	var session: WorldSessionController = host.current_session()
	_check(session != null and session.is_initialized(), "a Session stands")
	var coordinator := OldPineSessionLoadCoordinator.new(GameSaveRepository.new(profile, files))
	coordinator.select_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[1])
	var frames: Array[int] = [0]
	var count := func() -> void: frames[0] += 1
	tree.process_frame.connect(count)
	var saved: OldPineRuntimeSaveLoadResult = await coordinator.save_current_aside(session, 1000, tree.process_frame)
	tree.process_frame.disconnect(count)
	_check(saved.succeeded() and saved.repository != null and saved.repository.succeeded(), "the Save in play is written: %s" % saved.outcome)
	_check(frames[0] >= 1, "frames went on while it was written: %d" % frames[0])
	_check(not coordinator.operation_in_progress(), "the coordinator is free again")
	var loaded: GameSaveResult = coordinator.repository_for(GameSaveSnapshot.MANUAL_SLOT_IDS[1]).load()
	_check(loaded.succeeded(), "what it wrote loads")
	_check(loaded.succeeded() and loaded.snapshot.player.character_id == session.player_runtime().character_id, "and is this player's")
	# Without a slice it is the old Save, in one go.
	coordinator.select_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[0])
	var at_once: OldPineRuntimeSaveLoadResult = await coordinator.save_current_aside(session, 0, tree.process_frame)
	_check(at_once.succeeded(), "with no slice it saves at once, as save_current() does")
	# The main menu's look: the newest save's slot, read on a worker.
	var out: Array = await coordinator.inspect_aside(true, 1000, tree.process_frame)
	var rows: Array[GameSaveSlotSummary] = out[0]
	_check(rows.size() == GameSaveSnapshot.MANUAL_SLOT_IDS.size() + 1, "every slot's row is read")
	_check(rows[0].state == GameSaveSlotSummary.State.READY and rows[1].state == GameSaveSlotSummary.State.READY, "both saves are rows")
	var inspected: GameSaveSlotInspectionResult = out[2]
	_check(inspected.canonical_outcome == GameSaveResult.Outcome.SUCCESS, "the slot it picks is whole: %s" % inspected.canonical_outcome)
	var sync: Array = await coordinator.inspect_aside(true, 0, tree.process_frame)
	_check(sync[1] == out[1], "the same slot as the look in one go")
	host.queue_free()
	await tree.process_frame


## A row is read once per file content: the same bytes give the same row at once, other bytes
## are read again, and whether a .bak or .tmp lies beside it is the slot's own.
func _test_remembered_rows() -> void:
	var profile := GameSaveStorageProfile.isolated_test("save-rows-%d" % Time.get_ticks_usec())
	var files := Transaction.MemoryFiles.new()
	var repository := GameSaveRepository.new(profile.for_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[0]), files)
	var path: String = profile.for_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[0]).canonical_path()
	_check(repository.read_summary().state == GameSaveSlotSummary.State.EMPTY, "no file: an empty row")
	files.files[path] = "not a save".to_utf8_buffer()
	_check(repository.read_summary().state == GameSaveSlotSummary.State.UNREADABLE, "not JSON: unreadable")
	files.files[path] = PackedByteArray([0x7b, 0xff, 0x7d])
	_check(repository.read_summary().state == GameSaveSlotSummary.State.UNREADABLE, "not UTF-8: unreadable")
	var text: String = JSON.stringify({
		"metadata": {"format_id": GameSaveSnapshot.FORMAT_ID, "schema_version": GameSaveSnapshot.CURRENT_SCHEMA_VERSION, "saved_at_utc": "2026-11-07T10:00:00Z"},
		"world_content_revision": WorldContentRevision.Value.keys()[WorldContentRevision.CURRENT_PUBLIC],
		"player": {"identity": {"display_name": "凌雪"}, "world_location": {"zone_id": "snow.inn"}, "character": {}},
	})
	files.files[path] = text.to_utf8_buffer()
	var first: GameSaveSlotSummary = repository.read_summary()
	_check(first.state == GameSaveSlotSummary.State.READY and first.display_name == "凌雪" and first.zone_id == &"snow.inn", "a save's row: %s %s" % [first.state, first.display_name])
	files.files[profile.for_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[0]).backup_path()] = PackedByteArray([1])
	var again: GameSaveSlotSummary = repository.read_summary()
	_check(again != first and again.display_name == "凌雪" and again.recoverable and not first.recoverable, "the same bytes: the same row, a copy, with its own .bak")
	files.files[path] = text.replace("凌雪", "萧辟尘").to_utf8_buffer()
	_check(repository.read_summary().display_name == "萧辟尘", "other bytes are read again")
	var other := GameSaveRepository.new(profile.for_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[1]), files)
	files.files[profile.for_slot(GameSaveSnapshot.MANUAL_SLOT_IDS[1]).canonical_path()] = text.to_utf8_buffer()
	var moved: GameSaveSlotSummary = other.read_summary()
	_check(moved.slot_id == GameSaveSnapshot.MANUAL_SLOT_IDS[1] and moved.display_name == "凌雪", "the same bytes in another slot are that slot's row")


func _check(condition: bool, message: String) -> bool:
	_assertions += 1
	if not condition:
		_failures.append(message)
	return condition
