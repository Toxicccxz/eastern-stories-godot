extends SceneTree

# Run this external test script against the sanitized --path, never copy it into
# the release tree. The separate visual smoke launches canonical main normally.
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(not DirAccess.dir_exists_absolute("res://tests"), "sanitized tree contains no tests")
	_check(not root.has_node("_mcp_game_helper"), "no Godot AI autoload")
	_check(not root.has_node("_phase10b4_qa_bridge"), "no QA bridge")
	var main: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check(main == "res://scenes/application/application_shell.tscn", "canonical production shell")
	_check(change_scene_to_file(main) == OK, "production scene instantiates")
	for index: int in 6:
		await process_frame
	var shell: ApplicationShellController = current_scene as ApplicationShellController
	_check(shell != null, "root is ApplicationShell")
	if shell != null:
		_check(shell.runtime_host().storage_profile_id() == &"release", "default profile is release")
		_check(shell.settings_storage_path() == "user://settings/application-v1.cfg", "production settings path")
		_check(shell.runtime_host_slot.get_child_count() == 1, "one Host")
		_check(shell.runtime_host().current_session() == null, "no hidden Session")
		_check(shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU, "Menu boot")
		_check(root.gui_get_focus_owner() == shell.new_game_button, "New Game focus")
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
		for index: int in 6:
			await process_frame
		_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "native input activates New Game")
		_check(shell.runtime_host().session_slot.get_child_count() == 1, "one production Session")
		root.remove_child(shell)
		shell.free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	print("%s Phase 10C1C sanitized smoke: %d assertions" % [
		"PASS" if _failures.is_empty() else "FAIL", _assertions,
	])
	quit(0 if _failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)
