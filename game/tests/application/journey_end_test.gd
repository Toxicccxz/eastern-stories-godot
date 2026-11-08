extends RefCounted

## 终章 C (DECISIONS「结局讲述」): an ending that ends the journey (the player stayed in the ice) takes the
## game back to the main menu through the shell, as 回到主菜单 does, without asking; one that does not
## leaves the world as it is.

const MemoryFiles = preload("res://tests/application/application_shell_test.gd").MemoryFiles
const SHELL = preload("res://scenes/application/application_shell.tscn")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var files: MemoryFiles = MemoryFiles.new()
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test("journey-end")
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	if shell.request_new_game_from_menu() and shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
	shell.runtime_host().opening_card = false
	shell.player_name_edit.text = "冰"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "New Game")
	await _frames(tree)
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "playing")
	session.epilogue_ended.emit(false)
	await _frames(tree)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and shell.runtime_host().current_session() == session, "an ending that does not end the journey: the world goes on")
	_check(shell.request_pause(), "paused while the last card fades (the end is not lost)")
	await _frames(tree)
	session.epilogue_ended.emit(true)
	for frame: int in 600:
		await tree.process_frame
		if shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU:
			break
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU and shell.runtime_host().current_session() == null, "the journey ended: back on the main menu (%s)" % shell.shell_state().mode())
	_check(not tree.paused, "the tree runs again on the main menu")
	shell.free()
	await _frames(tree)
	return {"assertions": _count, "failures": _failures}


func _frames(tree: SceneTree, count: int = 8) -> void:
	for _frame: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
