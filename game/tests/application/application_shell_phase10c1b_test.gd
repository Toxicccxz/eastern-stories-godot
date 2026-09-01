extends RefCounted

const SHELL_SCENE: PackedScene = preload(
	"res://scenes/application/application_shell.tscn"
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


var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_typed_state_and_save_mapping()
	await _test_recovery_repository_contract(tree)
	await _test_pause_freeze_and_stable_save(tree)
	await _test_paused_blocked_save_preserves_blocker(tree)
	await _test_failed_end_request_preserves_paused_session(tree)
	await _test_return_menu_continue_roundtrip(tree)
	await _test_shell_recovery_reread_and_explicit_selection(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_typed_state_and_save_mapping() -> void:
	_assert_true(ApplicationShellState.paused().is_valid(), "PAUSED state is valid")
	_assert_true(ApplicationShellState.saving().is_valid(), "SAVING state owns Save operation")
	_assert_true(ApplicationShellState.recovery_choice().is_valid(), "RECOVERY_CHOICE is valid")
	_assert_true(
		ApplicationShellState.result(ApplicationShellState.ResultOrigin.MAIN_MENU).is_valid(),
		"menu-origin Result is valid",
	)
	_assert_true(
		ApplicationShellState.result(ApplicationShellState.ResultOrigin.PAUSED).is_valid(),
		"paused-origin Result is valid",
	)
	_assert_false(
		ApplicationShellState.new(ApplicationShellState.Mode.RESULT).is_valid(),
		"Result without a typed origin rejects",
	)
	_assert_false(
		ApplicationShellState.new(
			ApplicationShellState.Mode.PAUSED,
			ApplicationShellState.Operation.SAVE,
		).is_valid(),
		"PAUSED cannot also claim Save is running",
	)
	_assert_false(
		ApplicationShellState.new(
			ApplicationShellState.Mode.SAVING,
			ApplicationShellState.Operation.SAVE,
			ApplicationShellState.ResultOrigin.PAUSED,
		).is_valid(),
		"SAVING cannot carry Result return metadata",
	)

	var categories: Array[Array] = [
		[
			OldPineSaveEligibilityResult.Outcome.SESSION_NOT_READY,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_RUNTIME_NOT_READY,
			&"save.blocked.runtime_not_ready",
		],
		[
			OldPineSaveEligibilityResult.Outcome.RESTORE_STAGED,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_RUNTIME_NOT_READY,
			&"save.blocked.runtime_not_ready",
		],
		[
			OldPineSaveEligibilityResult.Outcome.SESSION_SWAP_ACTIVE,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_RUNTIME_NOT_READY,
			&"save.blocked.runtime_not_ready",
		],
		[
			OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_PARTIAL,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_WORLD_TRANSITION,
			&"save.blocked.world_transition",
		],
		[
			OldPineSaveEligibilityResult.Outcome.CAVE_EXIT_PENDING,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_WORLD_TRANSITION,
			&"save.blocked.world_transition",
		],
		[
			OldPineSaveEligibilityResult.Outcome.OPPONENT_RELATIONSHIP,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
		[
			OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_ACTIVE,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_WORLD_TRANSITION,
			&"save.blocked.world_transition",
		],
		[
			OldPineSaveEligibilityResult.Outcome.INCOMPLETE_LIFECYCLE,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_LIFECYCLE,
			&"save.blocked.lifecycle",
		],
		[
			OldPineSaveEligibilityResult.Outcome.LIFE_EXISTENCE_CONTRADICTION,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_LIFECYCLE,
			&"save.blocked.lifecycle",
		],
		[
			OldPineSaveEligibilityResult.Outcome.UNREPRESENTED_ATTRIBUTE_MODIFIER,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_TEMPORARY_EFFECT,
			&"save.blocked.temporary_effect",
		],
		[
			OldPineSaveEligibilityResult.Outcome.PENDING_AGGRESSION,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
		[
			OldPineSaveEligibilityResult.Outcome.COMBAT_CADENCE_ACTIVE,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
		[
			OldPineSaveEligibilityResult.Outcome.LETHAL_MARKER,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
		[
			OldPineSaveEligibilityResult.Outcome.BUSY,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
		[
			OldPineSaveEligibilityResult.Outcome.INTERRUPT_THRESHOLD,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
		[
			OldPineSaveEligibilityResult.Outcome.GUARDING,
			ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
			&"save.blocked.combat_or_action",
		],
	]
	for entry: Array in categories:
		var runtime := OldPineRuntimeSaveLoadResult.failure(
			OldPineRuntimeSaveLoadResult.Outcome.SAVE_BLOCKED
		)
		runtime.eligibility = OldPineSaveEligibilityResult.block(int(entry[0]))
		var product: ApplicationOperationResult = ApplicationProductResultMapper.runtime_result(
			ApplicationOperationResult.Operation.SAVE,
			runtime,
		)
		_assert_eq(product.outcome(), int(entry[1]), "typed Save blocker maps by enum")
		_assert_eq(product.message_key(), entry[2], "Save blocker uses stable product key")


func _test_recovery_repository_contract(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1b-repository")
	var files := MemoryFiles.new()
	var bytes: PackedByteArray = await _valid_save_bytes(tree)
	var repository := GameSaveRepository.new(profile, files)
	var empty: GameSaveSlotInspectionResult = repository.inspect_slot()
	_assert_eq(empty.canonical_outcome, GameSaveResult.Outcome.NO_SAVE, "empty slot reports NO_SAVE")
	_assert_eq(empty.recovery_sources(), [], "empty slot has no recovery candidates")
	files.files[profile.backup_path()] = bytes.duplicate()
	var backup_only: GameSaveSlotInspectionResult = repository.inspect_slot()
	_assert_eq(backup_only.canonical_outcome, GameSaveResult.Outcome.BACKUP_AVAILABLE, "backup is advisory evidence")
	_assert_eq(backup_only.recovery_sources(), [GameSaveRecoverySource.Value.BACKUP], "backup source identity is typed")
	files.files.erase(profile.backup_path())
	files.files[profile.temp_path()] = bytes.duplicate()
	var temp_only: GameSaveSlotInspectionResult = repository.inspect_slot()
	_assert_eq(temp_only.recovery_sources(), [GameSaveRecoverySource.Value.TEMP], "temp source identity is typed")
	files.files[profile.backup_path()] = bytes.duplicate()
	var both: GameSaveSlotInspectionResult = repository.inspect_slot()
	_assert_eq(
		both.recovery_sources(),
		[GameSaveRecoverySource.Value.BACKUP, GameSaveRecoverySource.Value.TEMP],
		"both fixed candidates preserve deterministic source order",
	)
	var exposed_sources: Array[int] = both.recovery_sources()
	exposed_sources.clear()
	_assert_eq(
		both.recovery_sources(),
		[GameSaveRecoverySource.Value.BACKUP, GameSaveRecoverySource.Value.TEMP],
		"repository inspection returns a defensive recovery-source array",
	)
	var product_inspection: ApplicationSlotInspection = (
		ApplicationProductResultMapper.inspect_slot(both)
	)
	var product_sources: Array[int] = product_inspection.recovery_sources()
	product_sources.clear()
	_assert_eq(
		product_inspection.recovery_sources(),
		[GameSaveRecoverySource.Value.BACKUP, GameSaveRecoverySource.Value.TEMP],
		"application inspection returns a defensive recovery-source array",
	)
	var before: Dictionary[String, PackedByteArray] = files.files.duplicate(true)
	var selected: GameSaveResult = repository.load_recovery(GameSaveRecoverySource.Value.TEMP)
	_assert_true(selected.succeeded(), "selected temp candidate re-reads successfully")
	_assert_eq(files.files, before, "selected recovery read performs no promotion or mutation")
	files.files[profile.temp_path()] = "{".to_utf8_buffer()
	_assert_false(
		repository.load_recovery(GameSaveRecoverySource.Value.TEMP).succeeded(),
		"selected candidate is validated again after inspection",
	)
	files.files[profile.canonical_path()] = bytes.duplicate()
	files.files[profile.temp_path()] = bytes.duplicate()
	var canonical_with_recovery: GameSaveSlotInspectionResult = repository.inspect_slot()
	_assert_eq(
		canonical_with_recovery.canonical_outcome,
		GameSaveResult.Outcome.SUCCESS,
		"valid canonical remains the default when recovery files also exist",
	)
	var canonical_product: ApplicationSlotInspection = (
		ApplicationProductResultMapper.inspect_slot(canonical_with_recovery)
	)
	_assert_true(canonical_product.continue_available(), "valid canonical enables Continue")
	_assert_false(
		canonical_product.recovery_available(),
		"valid canonical does not expose an advisory recovery choice in the application",
	)
	files.files.erase(profile.canonical_path())
	files.files[profile.backup_path()] = "{".to_utf8_buffer()
	files.files[profile.temp_path()] = PackedByteArray([0x80])
	var invalid_candidates: GameSaveSlotInspectionResult = repository.inspect_slot()
	_assert_eq(
		invalid_candidates.canonical_outcome,
		GameSaveResult.Outcome.NO_SAVE,
		"corrupt fixed candidates do not become recovery availability",
	)
	_assert_eq(
		invalid_candidates.recovery_sources(),
		[],
		"corrupt fixed candidates expose no source identity",
	)


func _test_pause_freeze_and_stable_save(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1b-pause-save")
	var files := MemoryFiles.new()
	var shell: ApplicationShellController = await _playing_shell(tree, profile, files)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var player_body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	var timer := Timer.new()
	timer.wait_time = 1.0
	session.add_child(timer)
	timer.start()
	var player_position: Vector2 = player_body.global_position
	var combat_rng: int = session.combat_random_source().capture_random_state().state
	var npc_rng: int = session.npc_random_source().capture_random_state().state
	var world_rng: int = session.world_interaction_random_source().capture_random_state().state
	var allocator_sequence: int = session.item_id_allocator().next_dynamic_sequence
	var inventory_ids: Array[StringName] = session.inventory_state().registered_item_ids()
	var player_velocity: Vector2 = player_body.velocity
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var life_status: int = player.life_status
	var exists_in_world: bool = player.exists_in_world
	var opponent_ids: Array[StringName] = player.relationship.opponent_ids()
	var lethal_target_ids: Array[StringName] = player.relationship.lethal_target_ids()
	var guarding: bool = player.relationship.guarding
	var primary_weapon: EquippedWeaponRef = player.state.equipment.primary_weapon()
	var secondary_weapon: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	var primary_weapon_id: StringName = (
		&"" if primary_weapon == null else primary_weapon.instance_id
	)
	var secondary_weapon_id: StringName = (
		&"" if secondary_weapon == null else secondary_weapon.instance_id
	)
	var armor_slots: Array[StringName] = player.armor.occupied_slots()
	var armor_items: Dictionary[StringName, StringName] = {}
	for armor_slot: StringName in armor_slots:
		armor_items[armor_slot] = player.armor.item_instance_id_in_slot(armor_slot)
	var npc_positions: Dictionary[StringName, Vector2] = {}
	var npc_velocities: Dictionary[StringName, Vector2] = {}
	for npc: NpcRuntimeState in session.outdoor_map().npc_runtimes():
		var npc_body: WorldCharacterBody2D = (
			session.outdoor_map().runtime_body_for_character(npc.character_id)
		)
		if npc_body != null:
			npc_positions[npc.character_id] = npc_body.global_position
			npc_velocities[npc.character_id] = npc_body.velocity
	_assert_true(shell.request_pause(), "PLAYING admits application Pause")
	_assert_true(tree.paused, "application Pause sets SceneTree.paused")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "typed state enters PAUSED")
	_assert_true(shell.pause_visible(), "Pause UI remains live")
	var paused_time: float = timer.time_left
	await _wait_frames(tree, 4)
	_assert_eq(player_body.global_position, player_position, "Player position remains frozen")
	_assert_eq(timer.time_left, paused_time, "pausable Timer does not advance")
	_assert_eq(session.combat_random_source().capture_random_state().state, combat_rng, "combat RNG remains frozen")
	_assert_eq(session.npc_random_source().capture_random_state().state, npc_rng, "NPC RNG remains frozen")
	_assert_eq(session.world_interaction_random_source().capture_random_state().state, world_rng, "world RNG remains frozen")
	_assert_eq(session.item_id_allocator().next_dynamic_sequence, allocator_sequence, "allocator remains frozen")
	_assert_eq(player_body.velocity, player_velocity, "Player velocity remains frozen")
	_assert_eq(session.inventory_state().registered_item_ids(), inventory_ids, "Inventory identity remains frozen")
	_assert_eq(player.life_status, life_status, "Player lifecycle remains frozen")
	_assert_eq(player.exists_in_world, exists_in_world, "Player existence remains frozen")
	_assert_eq(player.relationship.opponent_ids(), opponent_ids, "opponent relationships remain frozen")
	_assert_eq(player.relationship.lethal_target_ids(), lethal_target_ids, "lethal relationships remain frozen")
	_assert_eq(player.relationship.guarding, guarding, "guarding state remains frozen")
	var paused_primary: EquippedWeaponRef = player.state.equipment.primary_weapon()
	var paused_secondary: EquippedWeaponRef = player.state.equipment.secondary_weapon()
	_assert_eq(
		&"" if paused_primary == null else paused_primary.instance_id,
		primary_weapon_id,
		"primary equipment remains frozen",
	)
	_assert_eq(
		&"" if paused_secondary == null else paused_secondary.instance_id,
		secondary_weapon_id,
		"secondary equipment remains frozen",
	)
	_assert_eq(player.armor.occupied_slots(), armor_slots, "armor slots remain frozen")
	for armor_slot: StringName in armor_slots:
		_assert_eq(
			player.armor.item_instance_id_in_slot(armor_slot),
			armor_items[armor_slot],
			"armor item identity remains frozen",
		)
	for character_id: StringName in npc_positions:
		var paused_npc_body: WorldCharacterBody2D = (
			session.outdoor_map().runtime_body_for_character(character_id)
		)
		_assert_eq(paused_npc_body.global_position, npc_positions[character_id], "NPC position remains frozen")
		_assert_eq(paused_npc_body.velocity, npc_velocities[character_id], "NPC velocity remains frozen")
	_assert_true(shell.request_save_from_pause(), "Host accepts deferred Save while tree is paused")
	_assert_false(shell.request_save_from_pause(), "repeated Save intent is rejected while Save is pending")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.SAVING, "Save enters typed SAVING state")
	await _wait_frames(tree, 3)
	_assert_true(tree.paused, "Save completion does not resume gameplay")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.RESULT, "Save completes to Result")
	_assert_eq(shell.shell_state().result_origin(), ApplicationShellState.ResultOrigin.PAUSED, "Save Result returns to Pause")
	_assert_true(shell.last_result().succeeded(), "stable paused Save succeeds")
	_assert_true(files.files.has(profile.canonical_path()), "stable paused Save writes canonical slot")
	_assert_true(shell.dismiss_current_result(), "Save result acknowledges")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PAUSED, "acknowledgement returns to PAUSED")
	_assert_true(shell.request_resume(), "Pause resumes explicitly")
	_assert_false(tree.paused, "Resume clears SceneTree.paused")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "Resume restores PLAYING")
	_free_node(shell)
	await tree.process_frame


func _test_paused_blocked_save_preserves_blocker(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1b-blocked-save")
	var files := MemoryFiles.new()
	var shell: ApplicationShellController = await _playing_shell(tree, profile, files)
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var relationship: CombatRelationshipState = session.player_runtime().relationship
	_assert_true(relationship.add_opponent(&"phase10c1b.real-opponent"), "real relationship fixture enters unstable gameplay")
	var combat_rng: int = session.combat_random_source().capture_random_state().state
	var allocator_sequence: int = session.item_id_allocator().next_dynamic_sequence
	_assert_true(shell.request_pause(), "combat state does not prevent application Pause")
	_assert_true(shell.request_save_from_pause(), "blocked Save still queues through Host")
	await _wait_frames(tree, 3)
	_assert_eq(
		shell.last_result().outcome(),
		ApplicationOperationResult.Outcome.SAVE_BLOCKED_COMBAT_OR_ACTION,
		"combat relationship maps to player-facing blocked Save",
	)
	_assert_true(tree.paused, "blocked Save leaves gameplay paused")
	_assert_eq(relationship.opponent_ids(), [&"phase10c1b.real-opponent"], "blocked Save preserves opponent relationship")
	_assert_eq(session.combat_random_source().capture_random_state().state, combat_rng, "blocked Save consumes no combat RNG")
	_assert_eq(session.item_id_allocator().next_dynamic_sequence, allocator_sequence, "blocked Save consumes no item ID")
	_assert_eq(files.files.size(), 0, "blocked Save performs no repository write")
	_assert_true(shell.dismiss_current_result(), "blocked result returns to Pause")
	_assert_true(shell.request_resume(), "blocked Save does not trap player in Pause")
	_free_node(shell)
	await tree.process_frame


func _test_return_menu_continue_roundtrip(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1b-return")
	var files := MemoryFiles.new()
	var shell: ApplicationShellController = await _playing_shell(tree, profile, files)
	_assert_true(shell.request_pause(), "roundtrip enters Pause")
	_assert_true(shell.request_save_from_pause(), "roundtrip writes a canonical Save")
	await _wait_frames(tree, 3)
	shell.dismiss_current_result()
	var original_session_id: int = shell.runtime_host().current_session().get_instance_id()
	_assert_true(shell.request_return_to_main_menu(), "Return always opens confirmation")
	_assert_false(shell.request_return_to_main_menu(), "repeated Return intent is rejected by modal state")
	_assert_eq(shell.last_result().message_key(), &"return.confirm", "Return uses unconditional loss warning")
	_assert_true(tree.paused, "confirmation keeps gameplay paused")
	_assert_true(shell.confirm_current_result(), "confirmed Return requests Host teardown")
	_assert_false(shell.confirm_current_result(), "repeated confirmation cannot queue a second teardown")
	_assert_true(tree.paused, "Session teardown starts while still paused")
	await _wait_frames(tree, 4)
	_assert_false(tree.paused, "tree unpauses only after teardown")
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "Return reaches refreshed Main Menu")
	_assert_true(shell.runtime_host().current_session() == null, "Return clears Host Session authority")
	_assert_eq(shell.runtime_host().session_slot.get_child_count(), 0, "Return empties SessionSlot")
	_assert_eq(shell.runtime_host().staging_slot.get_child_count(), 0, "Return leaves StagingSlot empty")
	_assert_true(shell.continue_enabled(), "post-return inspection refreshes Continue")
	_assert_true(shell.request_continue_from_menu(), "real Continue queues after Return")
	await _wait_frames(tree, 4)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "Continue restores gameplay")
	_assert_true(shell.runtime_host().session_invariant_holds(), "Continue restores exactly one Session")
	_assert_true(shell.runtime_host().current_session().get_instance_id() != original_session_id, "restored Session has fresh runtime identity")
	_free_node(shell)
	await tree.process_frame


func _test_failed_end_request_preserves_paused_session(tree: SceneTree) -> void:
	var profile := GameSaveStorageProfile.isolated_test("phase10c1b-end-failure")
	var shell: ApplicationShellController = await _playing_shell(tree, profile, MemoryFiles.new())
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	var session: OldPineWorldSessionController = host.current_session()
	_assert_true(shell.request_pause(), "end-failure fixture pauses coherently")
	var orphan := Node.new()
	host.staging_slot.add_child(orphan)
	_assert_true(shell.request_return_to_main_menu(), "Return confirmation opens despite later invariant failure")
	_assert_true(shell.confirm_current_result(), "Host accepts typed end request for invariant validation")
	await _wait_frames(tree, 2)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.RESULT, "failed end request remains Result")
	_assert_eq(shell.shell_state().result_origin(), ApplicationShellState.ResultOrigin.PAUSED, "failed end request retains paused origin")
	_assert_true(tree.paused, "failed end request keeps tree paused")
	_assert_true(host.current_session() == session, "failed end request retains exact Session authority")
	_assert_true(session.get_parent() == host.session_slot, "failed end request retains Session containment")
	host.staging_slot.remove_child(orphan)
	orphan.free()
	_assert_true(host.session_invariant_holds(), "removing adversarial orphan restores invariant")
	_assert_true(shell.dismiss_current_result(), "failed end result returns to Pause")
	_assert_true(shell.request_resume(), "retained Session can resume")
	_free_node(shell)
	await tree.process_frame


func _test_shell_recovery_reread_and_explicit_selection(tree: SceneTree) -> void:
	var bytes: PackedByteArray = await _valid_save_bytes(tree)
	var stale_profile := GameSaveStorageProfile.isolated_test("phase10c1b-stale-recovery")
	var stale_files := MemoryFiles.new()
	stale_files.files[stale_profile.canonical_path()] = "{".to_utf8_buffer()
	stale_files.files[stale_profile.backup_path()] = bytes.duplicate()
	stale_files.files[stale_profile.temp_path()] = bytes.duplicate()
	var stale_shell: ApplicationShellController = await _menu_shell(tree, stale_profile, stale_files)
	_assert_true(stale_shell.recovery_enabled(), "valid fixed candidates enable Recovery action")
	_assert_true(stale_shell.runtime_host().current_session() == null, "recovery availability never auto-loads")
	_assert_true(stale_shell.request_recovery_choice_from_menu(), "Recovery opens explicit choice")
	_assert_true(stale_shell.recovery_visible(), "Recovery dialog is shell-owned")
	stale_files.files[stale_profile.backup_path()] = "{".to_utf8_buffer()
	_assert_true(stale_shell.request_recovery_source(GameSaveRecoverySource.Value.BACKUP), "advisory source selection queues fresh read")
	await _wait_frames(tree, 4)
	_assert_eq(stale_shell.shell_state().mode(), ApplicationShellState.Mode.RESULT, "changed candidate fails to Result")
	_assert_true(stale_shell.runtime_host().current_session() == null, "failed recovery leaves Host empty")
	_assert_true(
		stale_files.files.has(stale_profile.temp_path()),
		"failed selected backup never falls back to valid temp",
	)
	_assert_eq(stale_shell.runtime_host().session_slot.get_child_count(), 0, "failed recovery commits no Session")
	_assert_eq(stale_shell.runtime_host().staging_slot.get_child_count(), 0, "failed recovery leaks no candidate")
	_free_node(stale_shell)
	await tree.process_frame

	var profile := GameSaveStorageProfile.isolated_test("phase10c1b-explicit-recovery")
	var files := MemoryFiles.new()
	files.files[profile.canonical_path()] = "{".to_utf8_buffer()
	files.files[profile.backup_path()] = bytes.duplicate()
	files.files[profile.temp_path()] = await _valid_save_bytes_at(tree, Vector2(450.0, 280.0))
	var before: Dictionary[String, PackedByteArray] = files.files.duplicate(true)
	var shell: ApplicationShellController = await _menu_shell(tree, profile, files)
	_assert_eq(
		shell.slot_inspection().recovery_sources(),
		[GameSaveRecoverySource.Value.BACKUP, GameSaveRecoverySource.Value.TEMP],
		"Shell caches source identity only for both validated candidates",
	)
	_assert_true(shell.request_recovery_choice_from_menu(), "both-candidate dialog opens")
	_assert_true(shell.request_recovery_source(GameSaveRecoverySource.Value.TEMP), "player explicitly chooses temp candidate")
	await _wait_frames(tree, 4)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "selected recovery restores gameplay")
	_assert_true(shell.runtime_host().session_invariant_holds(), "selected recovery owns exactly one Session")
	_assert_eq(
		shell.runtime_host().current_session().active_map().runtime_player_body().global_position,
		Vector2(450.0, 280.0),
		"explicit temp selection restores temp content instead of backup content",
	)
	_assert_eq(files.files, before, "Recovery neither promotes nor rewrites any save file")
	_free_node(shell)
	await tree.process_frame


func _playing_shell(
	tree: SceneTree,
	profile: GameSaveStorageProfile,
	files: MemoryFiles,
) -> ApplicationShellController:
	var shell: ApplicationShellController = await _menu_shell(tree, profile, files)
	_assert_true(shell.request_new_game_from_menu(), "test Shell accepts New Game")
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.PLAYING, "test Shell reaches PLAYING")
	return shell


func _menu_shell(
	tree: SceneTree,
	profile: GameSaveStorageProfile,
	files: MemoryFiles,
) -> ApplicationShellController:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_assert_true(shell.configure_before_start(profile, files), "test Shell configures fixed profile")
	tree.root.add_child(shell)
	await _wait_frames(tree, 3)
	_assert_eq(shell.shell_state().mode(), ApplicationShellState.Mode.MAIN_MENU, "test Shell reaches Main Menu")
	return shell


func _valid_save_bytes(tree: SceneTree) -> PackedByteArray:
	return await _valid_save_bytes_at(tree, Vector2(450.0, 300.0))


func _valid_save_bytes_at(tree: SceneTree, position: Vector2) -> PackedByteArray:
	var source: OldPineWorldSessionController = SESSION_SCENE.instantiate()
	tree.root.add_child(source)
	var snapshot: GameSaveSnapshot = SaveFixture.from_new_game(
		source,
		null,
		GameSaveValueTypes.MapPositionSnapshot.new(position.x, position.y),
	)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_assert_true(encoded.succeeded(), "recovery fixture encodes valid native Save")
	_free_node(source)
	await tree.process_frame
	return encoded.text.to_utf8_buffer()


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
