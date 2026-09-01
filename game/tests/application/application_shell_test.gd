extends RefCounted

const SHELL_SCENE: PackedScene = preload(
	"res://scenes/application/application_shell.tscn"
)
const HOST_SCENE: PackedScene = preload(
	"res://scenes/runtime/oldpine_game_runtime_host.tscn"
)
const SESSION_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)
const SaveFixture := preload("res://tests/support/oldpine_world_save_fixture.gd")

class MemoryFiles extends SaveFileOperations:
	var files: Dictionary[String, PackedByteArray] = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func make_directory_recursive(_path: String) -> int:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> SaveFileReadResult:
		if not files.has(path):
			return SaveFileReadResult.new(ERR_FILE_NOT_FOUND)
		var bytes: PackedByteArray = files[path]
		if bytes.size() > maximum_bytes:
			return SaveFileReadResult.new(
				SaveFileReadResult.ERROR_FILE_TOO_LARGE,
				PackedByteArray(),
				bytes.size(),
			)
		return SaveFileReadResult.new(OK, bytes, bytes.size())

	func write_bytes(path: String, bytes: PackedByteArray) -> int:
		files[path] = bytes.duplicate()
		return OK

	func rename_file(from_path: String, to_path: String) -> int:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK

	func remove_file(path: String) -> int:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK


class FailingNewGameHost extends OldPineGameRuntimeHost:
	func _instantiate_new_game_session() -> OldPineWorldSessionController:
		return null


class PartiallyFailingNewGameHost extends OldPineGameRuntimeHost:
	var created_session_ref: WeakRef
	var created_session_once: bool = false

	func _instantiate_new_game_session() -> OldPineWorldSessionController:
		var session: OldPineWorldSessionController = (
			SESSION_SCENE.instantiate() as OldPineWorldSessionController
		)
		created_session_once = true
		created_session_ref = weakref(session)
		session.get_node("ActiveMapSlot").add_child(Node.new())
		return session


var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_state_and_product_mapping()
	await _test_manual_host_lifecycle_and_serialization(tree)
	await _test_manual_host_rejects_nonempty_startup(tree)
	await _test_failed_new_game_leaves_empty_host(tree)
	await _test_partial_new_game_failure_is_freed(tree)
	await _test_shell_new_game_and_profile_ownership(tree)
	await _test_confirmed_new_game_preserves_storage(tree)
	await _test_canonical_continue_rereads_and_never_falls_back(tree)
	await _test_valid_continue_and_confirmation(tree)
	await _test_reset_path_absent(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_state_and_product_mapping() -> void:
	_assert_true(ApplicationShellState.boot_inspecting().is_valid(), "BOOT inspection state is valid")
	_assert_true(ApplicationShellState.main_menu().is_valid(), "MAIN_MENU state is valid")
	_assert_true(
		ApplicationShellState.starting(ApplicationShellState.Operation.NEW_GAME).is_valid(),
		"STARTING_SESSION New Game state is valid",
	)
	_assert_false(
		ApplicationShellState.new(
			ApplicationShellState.Mode.PLAYING,
			ApplicationShellState.Operation.CONTINUE,
		).is_valid(),
		"PLAYING cannot carry a Continue operation",
	)
	_assert_false(
		ApplicationShellState.starting(ApplicationShellState.Operation.INSPECT_SLOT).is_valid(),
		"STARTING_SESSION rejects inspection",
	)
	var cases: Array[Array] = [
		[GameSaveResult.Outcome.NO_SAVE, ApplicationSlotInspection.Availability.NO_SAVE, false],
		[GameSaveResult.Outcome.SUCCESS, ApplicationSlotInspection.Availability.CONTINUE_AVAILABLE, true],
		[GameSaveResult.Outcome.BACKUP_AVAILABLE, ApplicationSlotInspection.Availability.RECOVERY_REQUIRED, false],
		[GameSaveResult.Outcome.MALFORMED_JSON, ApplicationSlotInspection.Availability.SAVE_UNUSABLE, false],
		[GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, ApplicationSlotInspection.Availability.UNSUPPORTED_SAVE, false],
		[GameSaveResult.Outcome.READ_FAILED, ApplicationSlotInspection.Availability.STORAGE_FAILURE, false],
	]
	for entry: Array in cases:
		var repository_result: GameSaveResult = (
			GameSaveResult.success()
			if int(entry[0]) == GameSaveResult.Outcome.SUCCESS
			else GameSaveResult.failure(int(entry[0]), "hidden-path")
		)
		var inspection: ApplicationSlotInspection = (
			ApplicationProductResultMapper.inspect_slot(repository_result)
		)
		_assert_eq(inspection.availability(), int(entry[1]), "repository outcome maps to typed availability")
		_assert_eq(inspection.continue_available(), bool(entry[2]), "availability maps Continue permission")
	_assert_false(
		ApplicationProductResultMapper.inspect_slot(
			GameSaveResult.failure(GameSaveResult.Outcome.NO_SAVE, "hidden")
		).has_save_material(),
		"NO_SAVE is the only proven empty slot",
	)
	_assert_true(
		ApplicationProductResultMapper.inspect_slot(
			GameSaveResult.failure(GameSaveResult.Outcome.READ_FAILED, "hidden")
		).has_save_material(),
		"storage failure conservatively requires New Game confirmation",
	)
	var runtime := OldPineRuntimeSaveLoadResult.failure(
		OldPineRuntimeSaveLoadResult.Outcome.REPOSITORY_FAILED
	)
	runtime.repository = GameSaveResult.failure(GameSaveResult.Outcome.NO_SAVE, "hidden")
	var product: ApplicationOperationResult = ApplicationProductResultMapper.runtime_result(
		ApplicationOperationResult.Operation.CONTINUE,
		runtime,
	)
	_assert_eq(product.outcome(), ApplicationOperationResult.Outcome.NO_SAVE, "Continue NO_SAVE maps without detail parsing")
	_assert_eq(product.message_key(), &"save.no_save", "product result exposes stable message key")
	_assert_false(_has_snapshot_property(ApplicationShellState.main_menu()), "shell state has no GameSaveSnapshot property")
	_assert_false(
		_has_snapshot_property(ApplicationSlotInspection.new()),
		"slot metadata has no GameSaveSnapshot property",
	)
	var repository_expectations: Dictionary[int, int] = {}
	for outcome: int in range(GameSaveResult.Outcome.size()):
		repository_expectations[outcome] = ApplicationSlotInspection.Availability.SAVE_UNUSABLE
	repository_expectations[GameSaveResult.Outcome.SUCCESS] = ApplicationSlotInspection.Availability.CONTINUE_AVAILABLE
	repository_expectations[GameSaveResult.Outcome.NO_SAVE] = ApplicationSlotInspection.Availability.NO_SAVE
	repository_expectations[GameSaveResult.Outcome.BACKUP_AVAILABLE] = ApplicationSlotInspection.Availability.RECOVERY_REQUIRED
	repository_expectations[GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA] = ApplicationSlotInspection.Availability.UNSUPPORTED_SAVE
	repository_expectations[GameSaveResult.Outcome.UNSUPPORTED_ITEM_SCHEMA] = ApplicationSlotInspection.Availability.UNSUPPORTED_SAVE
	repository_expectations[GameSaveResult.Outcome.READ_FAILED] = ApplicationSlotInspection.Availability.STORAGE_FAILURE
	repository_expectations[GameSaveResult.Outcome.OPERATION_IN_PROGRESS] = ApplicationSlotInspection.Availability.STORAGE_FAILURE
	for outcome: int in repository_expectations:
		var mapped: ApplicationSlotInspection = ApplicationProductResultMapper.inspect_slot(
			GameSaveResult.success()
			if outcome == GameSaveResult.Outcome.SUCCESS
			else GameSaveResult.failure(outcome, "misleading/success/path", "continue.restore_failure")
		)
		_assert_eq(
			mapped.availability(),
			repository_expectations[outcome],
			"every repository outcome maps independently of diagnostic strings",
		)
		_assert_eq(
			mapped.has_save_material(),
			outcome != GameSaveResult.Outcome.NO_SAVE,
			"only an explicit NO_SAVE result permits unconfirmed New Game",
		)
	var busy_result: ApplicationOperationResult = ApplicationProductResultMapper.runtime_result(
		ApplicationOperationResult.Operation.CONTINUE,
		OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.REQUEST_REJECTED
		),
	)
	_assert_eq(
		busy_result.outcome(),
		ApplicationOperationResult.Outcome.REQUEST_BUSY,
		"runtime request rejection maps to product busy",
	)
	var restore_failure: ApplicationOperationResult = ApplicationProductResultMapper.runtime_result(
		ApplicationOperationResult.Operation.CONTINUE,
		OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.RESTORE_FAILED
		),
	)
	_assert_eq(
		restore_failure.outcome(),
		ApplicationOperationResult.Outcome.RESTORE_FAILURE,
		"runtime restore failure maps distinctly",
	)
	var invariant_failure: ApplicationOperationResult = ApplicationProductResultMapper.runtime_result(
		ApplicationOperationResult.Operation.NEW_GAME,
		OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED
		),
	)
	_assert_eq(
		invariant_failure.outcome(),
		ApplicationOperationResult.Outcome.SESSION_FAILURE,
		"Session invariant failure maps to a stable product failure",
	)


func _test_manual_host_lifecycle_and_serialization(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1a-host")
	var files := MemoryFiles.new()
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	_assert_true(host.configure_manual_before_start(profile, files), "Host accepts explicit manual startup")
	tree.root.add_child(host)
	_assert_eq(host.process_mode, Node.PROCESS_MODE_ALWAYS, "Host processes ALWAYS")
	_assert_eq(host.session_slot.process_mode, Node.PROCESS_MODE_PAUSABLE, "SessionSlot establishes PAUSABLE boundary")
	_assert_true(host.current_session() == null, "manual Host enters tree without Session")
	_assert_eq(host.session_slot.get_child_count(), 0, "manual Host has no committed child")
	_assert_eq(host.staging_slot.get_child_count(), 0, "manual Host has no staging child")
	_assert_true(host.session_invariant_holds(), "empty Host satisfies zero/one invariant")
	_assert_true(host.request_slot_inspection(), "slot inspection request queues")
	_assert_false(host.request_new_game(), "concurrent New Game request rejects")
	_assert_false(host.request_continue(), "concurrent Continue request rejects")
	_assert_false(host.request_save(), "concurrent Save request rejects")
	_assert_false(host.request_load(), "concurrent Load request rejects")
	_assert_false(host.request_end_session(), "concurrent end-Session request rejects")
	_assert_true(host.request_pending(), "rejected concurrent request does not clear active request gate")
	await tree.process_frame
	_assert_false(host.request_pending(), "inspection completion releases request gate")
	_assert_true(host.request_save(), "empty-Host Save request queues")
	await tree.process_frame
	_assert_false(host.request_pending(), "empty-Host Save failure releases request gate")
	_assert_true(host.request_continue(), "empty-Host Continue request queues")
	await tree.process_frame
	_assert_false(host.request_pending(), "failed Continue releases request gate")
	_assert_true(host.session_invariant_holds(), "failed Continue preserves empty Host")
	_assert_true(host.request_new_game(), "explicit New Game request queues")
	await tree.process_frame
	_assert_false(host.request_pending(), "New Game completion releases request gate")
	var session: OldPineWorldSessionController = host.current_session()
	_assert_true(session != null and session.is_initialized(), "New Game commits initialized Session")
	_assert_eq(session.inventory_state().registered_item_ids().size(), 12, "New Game retains twelve bootstrap items")
	_assert_true(host.session_invariant_holds(), "New Game satisfies committed invariant")
	_assert_eq(host.staging_slot.get_child_count(), 0, "New Game leaks no staging candidate")
	_assert_false(host.request_new_game(), "in-game New Game replacement rejects")
	_assert_false(host.request_continue(), "in-game Continue replacement rejects")
	_assert_true(host.request_end_session(), "end-Session request queues")
	await tree.process_frame
	_assert_false(host.request_pending(), "end-Session completion releases request gate")
	_assert_true(host.current_session() == null, "end Session clears Host authority")
	_assert_true(host.session_invariant_holds(), "end Session restores empty invariant")
	_assert_true(host.request_new_game(), "Host supports a later explicit New Game")
	await tree.process_frame
	_assert_true(host.session_invariant_holds(), "repeated lifecycle still owns exactly one Session")
	_free_node(host)
	await tree.process_frame


func _test_manual_host_rejects_nonempty_startup(tree: SceneTree) -> void:
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	var orphan := Node.new()
	host.get_node("SessionSlot").add_child(orphan)
	var startup_results: Array[OldPineRuntimeSaveLoadResult] = []
	host.startup_completed.connect(
		func(result: OldPineRuntimeSaveLoadResult) -> void: startup_results.append(result)
	)
	_assert_true(
		host.configure_manual_before_start(
			GameSaveStorageProfile.isolated_test("phase10c1a-nonempty-manual"),
			MemoryFiles.new(),
		),
		"nonempty manual fixture configures before entering the tree",
	)
	tree.root.add_child(host)
	_assert_eq(startup_results.size(), 1, "manual startup emits exactly one result")
	_assert_eq(
		startup_results[0].outcome,
		OldPineRuntimeSaveLoadResult.Outcome.SESSION_INVARIANT_FAILED,
		"manual startup never reports success for a nonempty Host",
	)
	_assert_false(host.request_new_game(), "nonempty Host cannot accept New Game")
	_free_node(host)
	await tree.process_frame


func _test_failed_new_game_leaves_empty_host(tree: SceneTree) -> void:
	var host := FailingNewGameHost.new()
	var session_slot := Node.new()
	session_slot.name = "SessionSlot"
	session_slot.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(session_slot)
	var staging_slot := Node.new()
	staging_slot.name = "StagingSlot"
	staging_slot.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(staging_slot)
	_assert_true(
		host.configure_manual_before_start(
			GameSaveStorageProfile.isolated_test("phase10c1a-failed-new"),
			MemoryFiles.new(),
		),
		"failing Host configures manually",
	)
	tree.root.add_child(host)
	_assert_true(host.request_new_game(), "failing New Game request queues")
	await tree.process_frame
	_assert_eq(
		host.last_new_game_result().outcome,
		OldPineRuntimeSaveLoadResult.Outcome.NEW_GAME_FAILED,
		"failed New Game outcome is typed",
	)
	_assert_true(host.current_session() == null, "failed New Game exposes no Session")
	_assert_eq(host.session_slot.get_child_count(), 0, "failed New Game leaves SessionSlot empty")
	_assert_eq(host.staging_slot.get_child_count(), 0, "failed New Game leaves StagingSlot empty")
	_assert_true(host.session_invariant_holds(), "failed New Game preserves empty invariant")
	_free_node(host)
	await tree.process_frame


func _test_partial_new_game_failure_is_freed(tree: SceneTree) -> void:
	var host := PartiallyFailingNewGameHost.new()
	var session_slot := Node.new()
	session_slot.name = "SessionSlot"
	session_slot.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(session_slot)
	var staging_slot := Node.new()
	staging_slot.name = "StagingSlot"
	staging_slot.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(staging_slot)
	_assert_true(
		host.configure_manual_before_start(
			GameSaveStorageProfile.isolated_test("phase10c1a-partial-new"),
			MemoryFiles.new(),
		),
		"partial-failure Host configures manually",
	)
	tree.root.add_child(host)
	_assert_true(host.request_new_game(), "partial New Game request queues")
	await tree.process_frame
	_assert_true(host.created_session_once, "partial failure creates a Session graph")
	_assert_true(host.current_session() == null, "partial failure never publishes Session authority")
	_assert_eq(host.session_slot.get_child_count(), 0, "partial failure detaches committed graph")
	_assert_eq(host.staging_slot.get_child_count(), 0, "partial failure leaves staging empty")
	_assert_true(host.session_invariant_holds(), "partial failure restores exact empty invariant")
	await tree.process_frame
	_assert_true(
		host.created_session_ref.get_ref() == null,
		"detached partial Session is eventually freed",
	)
	_free_node(host)
	await tree.process_frame


func _test_shell_new_game_and_profile_ownership(tree: SceneTree) -> void:
	var files := MemoryFiles.new()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(
		shell.configure_before_start(GameSaveStorageProfile.development(), files),
		"development boundary configures Shell before Host",
	)
	tree.root.add_child(shell)
	await _wait_frames(tree, 2)
	_assert_eq(shell.storage_profile_id(), GameSaveStorageProfile.DEVELOPMENT, "Shell owns development profile selection")
	_assert_eq(shell.runtime_host().storage_profile_id(), GameSaveStorageProfile.DEVELOPMENT, "Shell forwards same profile exactly once")
	_assert_eq(shell.runtime_host_slot.get_child_count(), 1, "Shell owns exactly one persistent Host child")
	_assert_true(shell.runtime_host_slot.get_child(0) == shell.runtime_host(), "Host child is the Shell's sole Host reference")
	_assert_false(
		shell.configure_before_start(GameSaveStorageProfile.release(), files),
		"ready Shell cannot be reconfigured from development to release",
	)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "cold boot reaches Main Menu")
	_assert_true(shell.menu_visible(), "cold Main Menu is visible")
	_assert_false(shell.busy_visible(), "inspection busy overlay clears")
	_assert_false(shell.continue_enabled(), "Continue is disabled without save")
	_assert_true(shell.runtime_host().current_session() == null, "menu has no hidden Session")
	_assert_true(shell.runtime_host().session_invariant_holds(), "cold menu Host is exactly empty")
	_assert_true(
		shell.get_viewport().gui_get_focus_owner() == shell.new_game_button,
		"first enabled New Game button receives deterministic focus",
	)
	_assert_true(shell.request_new_game_from_menu(), "Main Menu accepts New Game")
	_assert_true(shell.busy_visible(), "starting overlay blocks Main Menu")
	_assert_true(shell.new_game_button.disabled and shell.continue_button.disabled, "busy state disables underlying actions")
	await _wait_frames(tree, 2)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "New Game enters PLAYING")
	_assert_true(shell.runtime_host().session_invariant_holds(), "Shell New Game owns exactly one Session")
	_assert_eq(files.files.size(), 0, "starting New Game performs zero save filesystem mutation")
	_free_node(shell)
	await tree.process_frame


func _test_confirmed_new_game_preserves_storage(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1a-confirm-storage")
	var files := MemoryFiles.new()
	await _write_valid_save(tree, profile, files)
	files.files[profile.backup_path()] = "preserved backup bytes".to_utf8_buffer()
	files.files[profile.temp_path()] = "preserved temp bytes".to_utf8_buffer()
	var before: Dictionary[String, PackedByteArray] = files.files.duplicate(true)
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(shell.configure_before_start(profile, files), "confirmation storage Shell configures")
	tree.root.add_child(shell)
	await _wait_frames(tree, 2)
	_assert_true(shell.request_new_game_from_menu(), "save material requires New Game confirmation")
	_assert_true(shell.confirm_current_result(), "confirmed New Game queues")
	await _wait_frames(tree, 2)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "confirmed New Game succeeds")
	_assert_eq(files.files, before, "confirmed New Game mutates no canonical, backup, or temp bytes")
	_free_node(shell)
	await tree.process_frame


func _test_canonical_continue_rereads_and_never_falls_back(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1a-reread")
	var files := MemoryFiles.new()
	await _write_valid_save(tree, profile, files)
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(shell.configure_before_start(profile, files), "reread Shell configures")
	tree.root.add_child(shell)
	await _wait_frames(tree, 2)
	_assert_true(shell.continue_enabled(), "valid canonical enables Continue after advisory inspection")
	files.files[profile.canonical_path()] = "{".to_utf8_buffer()
	_assert_true(shell.request_continue_from_menu(), "real Continue intent queues after inspection")
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.RESULT, "changed canonical returns typed Result")
	_assert_true(shell.result_visible(), "failed Continue result is visible")
	_assert_eq(shell.last_result().outcome(), ApplicationOperationResult.Outcome.INVALID_SAVE, "fresh read maps malformed canonical")
	_assert_true(shell.runtime_host().current_session() == null, "failed Continue leaves Host empty")
	_assert_eq(shell.runtime_host().session_slot.get_child_count(), 0, "failed Continue has no default New Game flash")
	_assert_eq(shell.runtime_host().staging_slot.get_child_count(), 0, "failed Continue leaks no candidate")
	_assert_true(shell.runtime_host().session_invariant_holds(), "failed Continue preserves empty invariant")
	_assert_false(shell.request_continue_from_menu(), "result overlay blocks underlying Continue")
	_free_node(shell)
	await tree.process_frame


func _test_valid_continue_and_confirmation(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1a-continue")
	var files := MemoryFiles.new()
	await _write_valid_save(tree, profile, files)
	var canonical_before: PackedByteArray = files.files[profile.canonical_path()].duplicate()
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(shell.configure_before_start(profile, files), "Continue Shell configures")
	tree.root.add_child(shell)
	await _wait_frames(tree, 2)
	_assert_true(shell.request_new_game_from_menu(), "New Game with save opens confirmation")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.RESULT, "confirmation uses typed RESULT state")
	_assert_eq(shell.last_result().outcome(), ApplicationOperationResult.Outcome.CONFIRMATION_REQUIRED, "confirmation outcome is typed")
	_assert_true(shell.confirm_button.visible and shell.cancel_button.visible, "confirmation actions are visible")
	_assert_eq(files.files[profile.canonical_path()], canonical_before, "opening confirmation does not mutate canonical save")
	_assert_true(shell.dismiss_current_result(), "confirmation can return to Main Menu")
	_assert_true(shell.request_continue_from_menu(), "canonical Continue queues from Main Menu")
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "canonical Continue enters PLAYING")
	_assert_true(shell.runtime_host().current_session() != null, "Continue commits a restored Session")
	_assert_true(shell.runtime_host().session_invariant_holds(), "Continue leaves one committed Session")
	_assert_eq(shell.runtime_host().staging_slot.get_child_count(), 0, "Continue leaves no staging candidate")
	_free_node(shell)
	await tree.process_frame


func _test_reset_path_absent(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = SESSION_SCENE.instantiate()
	tree.root.add_child(session)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	_assert_false(outdoor.has_signal("reset_requested"), "Outdoor exposes no reset signal")
	_assert_true(outdoor.get_node_or_null("HUD/Overlay/StatusPanel/Margin/VBox/Actions/ResetButton") == null, "Outdoor Reset button is absent")
	_assert_false(outdoor.has_method("reset_world"), "Outdoor reset handler is absent")
	_assert_false(session.has_method("reset_session"), "Session reload seam is absent")
	_free_node(session)
	await tree.process_frame


func _write_valid_save(
	tree: SceneTree,
	profile: GameSaveStorageProfile,
	files: MemoryFiles,
) -> void:
	var source: OldPineWorldSessionController = SESSION_SCENE.instantiate()
	tree.root.add_child(source)
	var snapshot: GameSaveSnapshot = SaveFixture.from_new_game(source)
	_assert_true(snapshot != null, "valid save fixture captures New Game")
	_assert_true(GameSaveRepository.new(profile, files).save(snapshot).succeeded(), "valid canonical fixture saves through repository")
	_free_node(source)
	await tree.process_frame


func _has_snapshot_property(value: Object) -> bool:
	for property: Dictionary in value.get_property_list():
		if String(property["name"]).contains("snapshot"):
			return true
	return false


func _wait_frames(tree: SceneTree, count: int) -> void:
	for _index: int in range(count):
		await tree.process_frame


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _assert_true(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
