extends Node

## Explicitly injected into an ignored technical APK only, never the release stage.
## F9 reads evidence. F8 prepares Vine proximity/dodge once BEFORE the claimed route.
var _shell: ApplicationShellController
var _saves: int = 0
var _completions: int = 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_added)


func _added(node: Node) -> void:
	if node is ApplicationShellController:
		_shell = node
		_shell.state_changed.connect(_state)
		_shell.interaction_changed.connect(_report.bind("activity"))
		_shell.host_ready.connect(_host_ready)


func _host_ready(host: OldPineGameRuntimeHost) -> void:
	host.save_completed.connect(_saved)


func _saved(result: OldPineRuntimeSaveLoadResult) -> void:
	_completions += 1
	_report("save_completed_%d" % result.outcome)


func _state(state: ApplicationShellState) -> void:
	if state.mode() == ApplicationShellState.Mode.SAVING:
		_saves += 1
	_report.call_deferred("mode_%d" % state.mode())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			_report("F9")
		elif event.keycode == KEY_F8 and is_instance_valid(_shell):
			var session: OldPineWorldSessionController = _shell.runtime_host().current_session()
			if session != null and session.active_map_id() == OldPineWorldDefinitions.OUTDOOR_MAP_ID:
				session.player_runtime().state.skills.set_raw_level(&"dodge", 100)
				var vine: Node2D = session.outdoor_map().get_node("Interactions/VineInteraction")
				session.active_map().runtime_player_body().global_position = vine.global_position + Vector2(0, 60)
				_report("PRE_ROUTE_VINE_SETUP_dodge100_proximity_only")
	if event is InputEventScreenTouch:
		_report.call_deferred("touch_%d_%s" % [event.index, event.pressed])


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN] and is_inside_tree():
		_report.call_deferred("OS_%d" % what)


func _report(reason: String) -> void:
	if not is_instance_valid(_shell) or not _shell.is_node_ready():
		return
	var host: OldPineGameRuntimeHost = _shell.runtime_host()
	if host == null: return
	var touch: MobileTouchAdapter = _shell.get_node("TouchCanvas/TouchInput")
	var data: Dictionary[String, Variant] = {
		"reason": reason, "pid": OS.get_process_id(), "mode": _shell.shell_state().mode(),
		"paused": get_tree().paused, "allowed": _shell.interaction_allowed(),
		"gate": _shell.activity().resume_gate(), "save_requests": _saves, "save_completions": _completions,
		"host": str(host.get_instance_id()), "touch": str(touch.get_instance_id()),
		"lifecycle": str(_shell.get_node("MobileLifecycle").get_instance_id()),
		"pad_owner": touch.capture_state().pad_index, "pointer_owner": touch.capture_state().pointer_index,
		"safe": str((_shell.get_node("SafeAreaPresentation") as SafeAreaPresenter).current_metrics().content_rect()),
	}
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.release()
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = profile.canonical_path() + suffix
		data["file" + suffix] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	var session: OldPineWorldSessionController = host.current_session()
	if session != null:
		data["session"] = str(session.get_instance_id())
		data["map"] = session.active_map_id()
		data["map_count"] = session.active_map_child_count()
		data["position"] = str(session.active_map().runtime_player_body().global_position)
		data["velocity"] = str(session.active_map().runtime_player_body().velocity)
		data["camera"] = str(get_viewport().get_camera_2d().get_instance_id())
		data["cave_hud_count"] = session.cave_map().find_children("HUD", "", true, false).size()
		data["items"] = session.inventory_state().registered_item_ids()
		data["sequence"] = session.item_id_allocator().next_dynamic_sequence
		data["combat_rng"] = str(session.combat_random_source().capture_random_state().state)
		data["npc_rng"] = str(session.npc_random_source().capture_random_state().state)
		data["world_rng"] = str(session.world_interaction_random_source().capture_random_state().state)
	# Android's release logger truncates long print calls. Keep every JSON byte.
	var encoded: String = JSON.stringify(data)
	for offset: int in range(0, encoded.length(), 650):
		print("C2C_CHUNK %d %s" % [offset, encoded.substr(offset, 650)])
	print("C2C_END")
