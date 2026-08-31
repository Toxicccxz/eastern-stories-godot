extends RefCounted

const HOST_SCENE: PackedScene = preload(
	"res://scenes/runtime/oldpine_game_runtime_host.tscn"
)

var _assertions: int = 0
var _failures: Array[String] = []

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


class FailingActivationCoordinator extends OldPineSessionLoadCoordinator:
	func _activate_candidate(_candidate: OldPineWorldSessionController) -> bool:
		return false


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_eligibility_matrix(tree)
	await _test_live_capture_and_transactional_replace(tree)
	await _test_blocked_save_and_failed_load_preserve_current(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_eligibility_matrix(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = preload(
		"res://scenes/world/oldpine/oldpine_world_session.tscn"
	).instantiate()
	tree.root.add_child(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var target_id: StringName = session.outdoor_map().npc_runtimes()[0].character_id
	_assert_allowed(session, "stable active Outdoor allows Save")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	_assert_allowed(session, "committed unconscious state allows Save")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	player.set_exists_in_world(false)
	_assert_allowed(session, "coherent completed dead state allows Save")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	player.set_exists_in_world(true)
	player.relationship.add_opponent(target_id)
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.OPPONENT_RELATIONSHIP, "opponent blocks")
	player.relationship.remove_opponent(target_id)
	player.relationship.mark_lethal_target(target_id)
	player.relationship._remove_opponent_for_cleanup(target_id)
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.LETHAL_MARKER, "lethal marker alone blocks")
	player.relationship.remove_lethal_relation(target_id)
	player.busy.start_busy(1, 0)
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.BUSY, "busy blocks")
	player.busy.advance()
	player.busy.start_busy(1, 2)
	player.busy.try_interrupt()
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.INTERRUPT_THRESHOLD, "leftover interrupt threshold blocks")
	player.busy.advance()
	player.relationship.set_guarding(true)
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.GUARDING, "guarding blocks")
	player.relationship.set_guarding(false)
	session.outdoor_map().aggression_adapter()._pending_npc_ids.append(target_id)
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.PENDING_AGGRESSION, "pending aggression blocks")
	session.outdoor_map().aggression_adapter().clear_all()
	session._transitioning = true
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_ACTIVE, "active handoff blocks")
	session._transitioning = false
	session.cave_map()._exit_request_pending = true
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.CAVE_EXIT_PENDING, "pending Cave exit blocks")
	session.cave_map()._exit_request_pending = false
	session.outdoor_map()._lifecycle_failed = true
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.INCOMPLETE_LIFECYCLE, "incomplete lifecycle blocks")
	session.outdoor_map()._lifecycle_failed = false
	var partial := OldPineMapHandoffResult.new()
	partial._location_committed = true
	partial._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_ACTIVATION_FAILED
	session._last_map_handoff = partial
	_assert_blocked(session, OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_PARTIAL, "committed partial handoff blocks")
	session._last_map_handoff = null
	_assert_allowed(session, "stable state remains allowed after blocker checks")
	_free_host_and_profile(session, GameSaveStorageProfile.isolated_test("unused"))
	await tree.process_frame


func _assert_allowed(session: OldPineWorldSessionController, message: String) -> void:
	_assert_true(OldPineSaveEligibility.inspect(session).allowed(), message)


func _assert_blocked(session: OldPineWorldSessionController, expected: int, message: String) -> void:
	var result: OldPineSaveEligibilityResult = OldPineSaveEligibility.inspect(session)
	_assert_eq(result.outcome, expected, message)


func _test_live_capture_and_transactional_replace(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test(
		"phase10b4-transaction-%d" % Time.get_ticks_usec()
	)
	var files := MemoryFiles.new()
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	_assert_true(host.configure_before_start(profile, files), "test profile configures before Host ready")
	tree.root.add_child(host)
	await tree.process_frame
	var source: OldPineWorldSessionController = host.current_session()
	_assert_true(source != null and source.is_initialized(), "Host owns initialized Session A")
	var source_id: int = source.get_instance_id()
	var player_id: int = source.player_runtime().get_instance_id()
	var scope: StringName = source.item_instance_scope()
	var item_ids: Array[StringName] = source.inventory_state().registered_item_ids()
	var combat_state: int = source.combat_random_source().capture_random_state().state
	var position: Vector2 = source.active_map().runtime_player_body().global_position
	_assert_true(host.request_save(), "stable save request accepts")
	await tree.process_frame
	await tree.process_frame
	_assert_true(host.last_save_result().succeeded(), "full live graph saves")
	source.active_map().runtime_player_body().global_position += Vector2(10.0, 0.0)
	_assert_true(host.request_load(), "transactional load request accepts")
	await tree.process_frame
	await tree.process_frame
	var restored: OldPineWorldSessionController = host.current_session()
	_assert_true(host.last_load_result().succeeded(), "candidate B activates and commits")
	_assert_true(restored.get_instance_id() != source_id, "Session B has fresh runtime identity")
	_assert_true(restored.player_runtime().get_instance_id() != player_id, "Player B has fresh runtime identity")
	_assert_eq(restored.item_instance_scope(), scope, "durable item scope survives")
	_assert_eq(restored.inventory_state().registered_item_ids(), item_ids, "semantic item IDs survive exactly")
	_assert_eq(restored.active_map().runtime_player_body().global_position, position, "saved physical position restores")
	_assert_eq(restored.combat_random_source().capture_random_state().state, combat_state, "restore consumes zero Combat RNG")
	_assert_eq(host.session_slot.get_child_count(), 1, "commit leaves exactly one playable Session")
	_assert_eq(host.staging_slot.get_child_count(), 0, "commit leaves no staged candidate")
	var current_id: int = restored.get_instance_id()
	var failing := FailingActivationCoordinator.new(
		GameSaveRepository.new(profile, files)
	)
	var failed: OldPineRuntimeSaveLoadResult = failing.load_replacing(
		restored,
		host.session_slot,
		host.staging_slot,
	)
	_assert_eq(failed.outcome, OldPineRuntimeSaveLoadResult.Outcome.ACTIVATION_FAILED, "final candidate activation failure is typed")
	_assert_eq(restored.get_instance_id(), current_id, "activation failure retains exact Session A")
	_assert_true(restored.active_map().runtime_player_body().player_controlled, "activation rollback re-enables A input")
	_assert_true(not restored.is_session_swap_suspended(), "activation rollback clears A suspension")
	_assert_eq(host.session_slot.get_child_count(), 1, "activation rollback leaves one playable Session")
	_assert_eq(host.staging_slot.get_child_count(), 0, "activation rollback discards candidate B")
	_free_host_and_profile(host, profile)
	await tree.process_frame


func _test_blocked_save_and_failed_load_preserve_current(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test(
		"phase10b4-failure-%d" % Time.get_ticks_usec()
	)
	var host: OldPineGameRuntimeHost = HOST_SCENE.instantiate()
	host.configure_before_start(profile, MemoryFiles.new())
	tree.root.add_child(host)
	await tree.process_frame
	var current: OldPineWorldSessionController = host.current_session()
	var allocator_sequence: int = current.item_id_allocator().next_dynamic_sequence
	var rng_state: int = current.combat_random_source().capture_random_state().state
	current.player_runtime().busy.start_busy(1, 0)
	host.request_save()
	await tree.process_frame
	await tree.process_frame
	_assert_eq(host.last_save_result().outcome, OldPineRuntimeSaveLoadResult.Outcome.SAVE_BLOCKED, "busy blocks save")
	_assert_eq(current.item_id_allocator().next_dynamic_sequence, allocator_sequence, "blocked save consumes no item ID")
	_assert_eq(current.combat_random_source().capture_random_state().state, rng_state, "blocked save consumes no gameplay RNG")
	current.player_runtime().busy.advance()
	var current_id: int = current.get_instance_id()
	var current_position: Vector2 = current.active_map().runtime_player_body().global_position
	host.request_load()
	await tree.process_frame
	await tree.process_frame
	_assert_eq(host.last_load_result().outcome, OldPineRuntimeSaveLoadResult.Outcome.REPOSITORY_FAILED, "missing save fails before candidate")
	_assert_eq(host.current_session().get_instance_id(), current_id, "failed load preserves exact Session A")
	_assert_eq(host.current_session().active_map().runtime_player_body().global_position, current_position, "failed load preserves A position")
	_assert_true(host.current_session().active_map().runtime_player_body().player_controlled, "failed load preserves input")
	_assert_eq(host.session_slot.get_child_count(), 1, "failed load leaks no Session")
	_assert_eq(host.staging_slot.get_child_count(), 0, "failed load leaks no candidate")
	_free_host_and_profile(host, profile)
	await tree.process_frame


func _free_host_and_profile(host: Node, profile: GameSaveStorageProfile) -> void:
	if host != null:
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()


func _assert_true(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
