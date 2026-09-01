extends Node

var host: OldPineGameRuntimeHost
var shell: ApplicationShellController


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var shell_candidate: ApplicationShellController = node as ApplicationShellController
	if shell_candidate != null:
		shell = shell_candidate
		if not shell.is_configured():
			shell.configure_before_start(GameSaveStorageProfile.development())
		if not shell.host_ready.is_connected(_on_shell_host_ready):
			shell.host_ready.connect(_on_shell_host_ready)
		if not shell.state_changed.is_connected(_on_shell_state_changed):
			shell.state_changed.connect(_on_shell_state_changed)
		return
	var candidate: OldPineGameRuntimeHost = node as OldPineGameRuntimeHost
	if candidate == null:
		return
	if not candidate.is_configured():
		candidate.configure_before_start(
			GameSaveStorageProfile.development(),
			null,
			_startup_load_requested(),
		)
	_bind_host(candidate)


func _on_shell_host_ready(value: OldPineGameRuntimeHost) -> void:
	_bind_host(value)


func _on_shell_state_changed(state: ApplicationShellState) -> void:
	print("PHASE10C1A_QA shell_mode=%d operation=%d evidence=%s" % [
		state.mode(), state.operation(), evidence(),
	])


func _bind_host(value: OldPineGameRuntimeHost) -> void:
	host = value
	if not host.startup_completed.is_connected(_on_startup_completed):
		host.startup_completed.connect(_on_startup_completed)
	if not host.save_completed.is_connected(_on_save_completed):
		host.save_completed.connect(_on_save_completed)
	if not host.load_completed.is_connected(_on_load_completed):
		host.load_completed.connect(_on_load_completed)


func _startup_load_requested() -> bool:
	return (
		"--phase10b4-startup-load" in OS.get_cmdline_args()
		or "--phase10b4-startup-load" in OS.get_cmdline_user_args()
		or bool(ProjectSettings.get_setting("phase10b4/qa_startup_load", false))
	)


func request_save() -> bool:
	return is_instance_valid(host) and host.request_save()


func request_load() -> bool:
	return is_instance_valid(host) and host.request_load()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F6:
			print("PHASE10C1A_QA save_requested=%s" % request_save())
			get_viewport().set_input_as_handled()
		KEY_F7:
			var profile := GameSaveStorageProfile.development()
			var error: int = GodotSaveFileOperations.new().write_bytes(
				profile.canonical_path(),
				"{".to_utf8_buffer(),
			)
			print("PHASE10C1A_QA canonical_corrupt_fixture_error=%d" % error)
			get_viewport().set_input_as_handled()


func evidence() -> Dictionary[String, Variant]:
	var current_host: OldPineGameRuntimeHost = host if is_instance_valid(host) else null
	var current_shell: ApplicationShellController = shell if is_instance_valid(shell) else null
	var session: OldPineWorldSessionController = (
		null if current_host == null else current_host.current_session()
	)
	if session == null:
		return {
			"shell_mode": -1 if current_shell == null else current_shell.shell_state().mode(),
			"host_profile": &"" if current_host == null else current_host.storage_profile_id(),
			"session_count": 0 if current_host == null else current_host.session_slot.get_child_count(),
			"staging_count": 0 if current_host == null else current_host.staging_slot.get_child_count(),
		}
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return {
		"session_object_id": session.get_instance_id(),
		"player_object_id": player.get_instance_id(),
		"character_object_id": player.state.get_instance_id(),
		"character_id": player.character_id,
		"active_map_id": session.active_map_id(),
		"position": session.active_map().runtime_player_body().global_position,
		"item_scope": session.item_instance_scope(),
		"item_count": session.inventory_state().registered_item_ids().size(),
		"corpse_count": session.outdoor_map().corpse_states().size(),
		"combat_rng": session.combat_random_source().capture_random_state().state,
		"npc_rng": session.npc_random_source().capture_random_state().state,
		"world_rng": session.world_interaction_random_source().capture_random_state().state,
	}


func _on_startup_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	print("PHASE10B4_QA startup outcome=%d evidence=%s" % [result.outcome, evidence()])


func _on_save_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	print("PHASE10B4_QA save outcome=%d evidence=%s" % [result.outcome, evidence()])


func _on_load_completed(result: OldPineRuntimeSaveLoadResult) -> void:
	print("PHASE10B4_QA load outcome=%d evidence=%s" % [result.outcome, evidence()])
