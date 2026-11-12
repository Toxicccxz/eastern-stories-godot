extends RefCounted

## Keyboard and pad paths through the shell with real input events (审查修补 M, 2026-11-12):
## a card (the opening card, 拜师) paused and resumed still takes Enter / Space / A; the
## window losing its focus pauses the game and keeps a pad from steering it; Esc during the
## dialogue box, a scripted scene and the epilogue opens 系统 over them and they resume where
## they were.

const ShellTests := preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var shell: ApplicationShellController = await _start(tree, "input-paths")
	if shell != null:
		await _test_card_after_pause(tree, shell)
		shell.queue_free()
		await tree.process_frame
	InputDevices.shared().set_kind(InputDevices.Kind.KEYBOARD_MOUSE)
	return {"assertions": _count, "failures": _failures.duplicate()}


## A New Game through the shell, the opening card left on.
func _start(tree: SceneTree, slot: String) -> ApplicationShellController:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test(slot), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new()), "shell configures")
	tree.root.add_child(shell)
	await _frames(tree, 3)
	shell.runtime_host().opening_card = true
	_check(shell.request_new_game_from_menu(), "New Game")
	shell.player_name_edit.text = "按键"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "the journey starts")
	await _frames(tree, 3)
	if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
		await _frames(tree, 3)
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and session.shared_ui() != null, "playing")
	if session == null or session.shared_ui() == null:
		shell.queue_free()
		return null
	await _frames(tree, 3)
	return shell


## Paused over a card and resumed, Enter / Space / A still press 继续 (it had lost the focus
## and the confirm went to the HUD under the card): keys and pad, the opening card and a
## card put up while playing (拜师's).
func _test_card_after_pause(tree: SceneTree, shell: ApplicationShellController) -> void:
	var session: WorldSessionController = shell.runtime_host().current_session()
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	_check(overlay.card_shown(), "the opening card is up")
	var cases: Array[Array] = [
		["keys, the opening card", false, ""],
		["pad, a card while playing", true, "柳淳风收下了你。\n\n你成了封山剑派第十四代弟子。"],
		["keys, a card while playing", false, "柳淳风收下了你。"],
		["E, a card while playing", false, "柳淳风收下了你。"],
	]
	for case: Array in cases:
		var label: String = case[0]
		var pad: bool = case[1]
		if not String(case[2]).is_empty():
			session.shared_ui().show_card(case[2])
			await _frames(tree, 2)
		_check(overlay.card_shown(), "%s: the card is up" % label)
		await _frames(tree, 2)
		_check(tree.root.gui_get_focus_owner() == overlay._continue, "%s: 继续 has the focus as it comes up" % label)
		if pad:
			await _joy(tree, JOY_BUTTON_BACK)
		else:
			await _key(tree, KEY_ESCAPE)
		_check(shell.shell_state().mode() == ApplicationShellState.Mode.PAUSED, "%s: paused over the card" % label)
		if pad:
			await _joy(tree, JOY_BUTTON_BACK)
		else:
			await _key(tree, KEY_ESCAPE)
		await _frames(tree, 2)
		_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "%s: resumed" % label)
		_check(tree.root.gui_get_focus_owner() == overlay._continue, "%s: 继续 has the focus again: %s" % [label, tree.root.gui_get_focus_owner()])
		if pad:
			await _joy(tree, JOY_BUTTON_A)
		elif label.begins_with("E"):
			await _key(tree, KEY_E, true)
		else:
			await _key(tree, KEY_ENTER)
		await _frames(tree, 2)
		_check(not overlay.card_shown() and not session.world_time_held(), "%s: confirm closes the card" % label)
		_check(not session.shared_ui().interaction_open(), "%s: and nothing under it was interacted with" % label)


# --- helpers -------------------------------------------------------------------------

func _key(tree: SceneTree, keycode: Key, physical: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		if physical:
			event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame
	await tree.process_frame


func _joy(tree: SceneTree, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame
	await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
