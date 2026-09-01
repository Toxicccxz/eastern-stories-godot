extends Node

var host: OldPineGameRuntimeHost


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var candidate: OldPineGameRuntimeHost = node as OldPineGameRuntimeHost
	if candidate == null:
		return
	host = candidate
	var startup_load: bool = (
		"--phase10b4-startup-load" in OS.get_cmdline_args()
		or "--phase10b4-startup-load" in OS.get_cmdline_user_args()
		or bool(ProjectSettings.get_setting("phase10b4/qa_startup_load", false))
	)
	host.configure_before_start(
		GameSaveStorageProfile.development(),
		null,
		startup_load,
	)
	host.startup_completed.connect(_on_startup_completed)
	host.save_completed.connect(_on_save_completed)
	host.load_completed.connect(_on_load_completed)


func request_save() -> bool:
	return host != null and host.request_save()


func request_load() -> bool:
	return host != null and host.request_load()


func evidence() -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = null if host == null else host.current_session()
	if session == null:
		return {}
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
