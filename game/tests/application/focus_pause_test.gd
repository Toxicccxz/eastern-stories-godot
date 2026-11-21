extends RefCounted

## The focus pause (DECISIONS「切出窗口」; 审查修补 X, 2026-11-19): the window left while playing
## puts a page over whatever was open and gives it back untouched — the interaction window, a
## menu page with a continuous 打坐 running (it goes on counting), a 请教 panel; a journey that
## starts or loads while the window is away opens under it; a load made from 系统 afterwards
## does not come back claiming a lost focus.

const ShellTests := preload("res://tests/application/application_shell_test.gd")
const InputPaths := preload("res://tests/application/input_paths_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var shell: ApplicationShellController = await _start(tree, "focus-pause")
	if shell != null:
		await _test_interaction_window(tree, shell)
		await _test_menu_page_training(tree, shell)
		await _test_load_from_system(tree, shell)
		shell.queue_free()
		await _frames(tree, 2)
	await _test_sliced_start(tree)
	InputDevices.shared().set_kind(InputDevices.Kind.KEYBOARD_MOUSE)
	return {"assertions": _count, "failures": _failures.duplicate()}


func _start(tree: SceneTree, slot: String, files: ShellTests.MemoryFiles = null) -> ApplicationShellController:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test(slot), files if files != null else ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new()), "shell configures")
	tree.root.add_child(shell)
	await _frames(tree, 3)
	shell.lifecycle_adapter().set_capability(InputPaths.DesktopWindow.new())
	shell.runtime_host().opening_card = false
	_check(shell.request_new_game_from_menu(), "New Game")
	shell.player_name_edit.text = "失焦"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "the journey starts")
	await _until(tree, func() -> bool: return shell.shell_state().mode() != ApplicationShellState.Mode.STARTING_SESSION)
	if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		shell.confirm_current_result()
	await _frames(tree, 3)
	var session: WorldSessionController = shell.runtime_host().current_session()
	if not _check(session != null and session.shared_ui() != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "playing"):
		shell.queue_free()
		return null
	return shell


## Away and back with a window up: the focus pause shows over it, and 继续 gives it back.
func _away_and_back(tree: SceneTree, shell: ApplicationShellController, label: String, resume_key: Key = KEY_ESCAPE) -> void:
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(tree, 3)
	_check(shell.focus_held() and shell.focus_layer.shown() and tree.paused and not shell.pause_visible(), "%s: away, the focus pause over it (not 系统)" % label)
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(tree, 4)
	_check(shell.focus_held() and shell.focus_layer.shown() and tree.paused, "%s: back, still paused until 继续" % label)
	await _key(tree, resume_key)
	await _frames(tree, 2)
	_check(not shell.focus_held() and not shell.focus_layer.shown() and not tree.paused and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "%s: 继续, playing" % label)


## The interaction window over a person: kept, its row still focused, nothing chosen in it.
func _test_interaction_window(tree: SceneTree, shell: ApplicationShellController) -> void:
	var session: WorldSessionController = shell.runtime_host().current_session()
	var ui: SharedGameplayUI = session.shared_ui()
	var map := session.active_map() as WorldMapController
	var person: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and map.runtime_body_for_character(npc.character_id) != null:
			person = npc
			break
	if not _check(person != null, "someone on the first map"):
		return
	var zone: StringName = person.world_location().zone_id
	_check(map.place_player(zone, MapPlaces.spot(map, zone, map.runtime_body_for_character(person.character_id).global_position + Vector2(0, 52))), "beside them")
	map.npc_life._advance_ambience(0.0)
	await _until(tree, func() -> bool: return ui.nearby.target() != null)
	_check(ui.nearby.choose(person.character_id), "them as the target")
	ui.open_interaction(ui.nearby.target())
	await _frames(tree, 3)
	var row: Control = tree.root.gui_get_focus_owner()
	_check(ui.interaction_open(), "the interaction window is open")
	await _away_and_back(tree, shell, "interaction window")
	_check(ui.interaction_open() and ui._presentation_layout.frame.visible, "the interaction window is still open")
	_check(tree.root.gui_get_focus_owner() == row, "its row still has the focus: %s" % tree.root.gui_get_focus_owner())
	# Enter resumes and is not also taken by the row under the page.
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(tree, 2)
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(tree, 4)
	# A held stick or D-pad comes as repeated actions (PadSupport): they move nothing under it.
	for pressed: bool in [true, false, true, false]:
		var step := InputEventAction.new()
		step.action = &"ui_down"
		step.pressed = pressed
		Input.parse_input_event(step)
		await tree.process_frame
	_check(shell.focus_held() and tree.root.gui_get_focus_owner() == row, "a pad's repeats under the page move nothing: %s" % tree.root.gui_get_focus_owner())
	await _key(tree, KEY_ENTER)
	await _frames(tree, 2)
	_check(not shell.focus_held() and ui.interaction_open() and tree.root.gui_get_focus_owner() == row, "Enter: 继续 only, the window as it was")
	ui.dismiss_current_panel()
	await _frames(tree, 2)


## 武学 with 连续打坐 under way: the page stays, the run stands while away and goes on after.
func _test_menu_page_training(tree: SceneTree, shell: ApplicationShellController) -> void:
	var session: WorldSessionController = shell.runtime_host().current_session()
	var ui: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var feel: FeelDefinition = pacing.feel
	pacing.feel = feel.but({"training_step_ms": 100, "training_auto_step_ms": 100}) # TEST-ONLY: a run in steps
	ui.open_martial_arts()
	await _frames(tree, 2)
	var page: MartialArtsPage = ui.martial_arts_page()
	state.skills.set_raw_level(&"force", 5) # TEST-ONLY: an enabled 内功 to 打坐 with
	state.skills.set_raw_level(&"fonxanforce", 1)
	state.skills.map_skill(&"force", &"fonxanforce")
	state.recovery.inner_force.maximum = 100000 # TEST-ONLY: room to grow
	state.recovery.inner_force.current = 0
	state.vitality.maximum = 100000 # TEST-ONLY: 气 for a long run
	state.vitality.effective = 100000
	state.vitality.current = 100000
	page.exercise_amount.value = 30
	page.exercise_run_button.pressed.emit()
	_check(page.progress.running() and ui.menu.is_presented() and ui.menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS, "连续打坐 runs on the 武学 page")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(tree, 2)
	var told: String = page.progress.status.text
	await _frames(tree, 30)
	_check(page.progress.running() and page.progress.status.text == told, "away: the run stands where it was")
	_check(ui.menu.is_presented() and ui.menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS and not ui.menu.in_pause_view(), "the 武学 page is still up, 系统 not shown")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(tree, 4)
	await _key(tree, KEY_ESCAPE)
	_check(not shell.focus_held() and page.progress.running(), "继续: the run goes on (Esc went to 继续, not to 停止)")
	await _frames(tree, 30)
	_check(page.progress.running() and page.progress.status.text != told, "and keeps counting: %s (stop %d, 气 %d)" % [page.progress.status.text, page.progress.last_stop, state.vitality.current])
	_check(ui.menu.is_presented() and ui.menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS, "on the same page")
	page.progress.stop()
	ui.menu.close()
	pacing.feel = feel
	await _frames(tree, 2)


## A load from 系统 after a focus pause: playing, no claim of a lost focus. Lost during the
## load: the journey opens under the focus pause.
func _test_load_from_system(tree: SceneTree, shell: ApplicationShellController) -> void:
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(tree, 2)
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(tree, 4)
	_check(shell.resume_from_focus_pause(), "继续")
	_check(shell.request_pause() and shell.request_save_slots() and shell.choose_slot_row(0), "系统: saved in slot 1")
	await _until(tree, func() -> bool: return shell.shell_state().mode() == ApplicationShellState.Mode.RESULT)
	shell.dismiss_current_result()
	_check(shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "系统: 读取 slot 1")
	await _until(tree, func() -> bool: return shell.shell_state().mode() != ApplicationShellState.Mode.STARTING_SESSION)
	await _frames(tree, 3)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and not shell.focus_held() and not shell.focus_layer.shown() and not tree.paused, "loaded: playing, nothing said of a lost focus")
	# The window left while the load runs.
	_check(shell.request_pause() and shell.request_load_slots() and shell.choose_slot_row(0) and shell.confirm_current_result(), "读取 again")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _until(tree, func() -> bool: return shell.shell_state().mode() != ApplicationShellState.Mode.STARTING_SESSION)
	await _frames(tree, 3)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and shell.focus_held() and shell.focus_layer.shown() and tree.paused, "away during the load: it opens under the focus pause")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(tree, 4)
	await _key(tree, KEY_ENTER)
	_check(not shell.focus_held() and not tree.paused, "继续: playing")


## A New Game built over frames (the feel's session_start_slice_ms) with the window left
## halfway: it opens under the focus pause, the world standing.
func _test_sliced_start(tree: SceneTree) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var feel: FeelDefinition = pacing.feel
	pacing.feel = feel.but({"session_start_slice_ms": 2}) # TEST-ONLY: the shipped slices
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("focus-pause-sliced"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new())
	tree.root.add_child(shell)
	# A start in slices looks at the saves on a worker thread, queued behind every map scene it
	# reads ahead: the menu takes 新的旅程 once that is done, not after a set count of frames (a
	# busy runner took more than three).
	await _until(tree, func() -> bool: return shell.shell_state().mode() == ApplicationShellState.Mode.MAIN_MENU)
	shell.lifecycle_adapter().set_capability(InputPaths.DesktopWindow.new())
	shell.runtime_host().opening_card = false
	_check(shell.request_new_game_from_menu(), "the main menu takes 新的旅程")
	shell.player_name_edit.text = "分帧"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	_check(shell.submit_new_game_setup(), "a sliced New Game")
	await _frames(tree, 2)
	_check(shell.shell_state().mode() == ApplicationShellState.Mode.STARTING_SESSION, "still starting a few frames in")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _until(tree, func() -> bool: return shell.shell_state().mode() != ApplicationShellState.Mode.STARTING_SESSION)
	await _frames(tree, 3)
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and shell.focus_held() and shell.focus_layer.shown() and tree.paused, "the journey opens under the focus pause")
	var minutes: float = session.day_clock().day_minutes() if session != null else 0.0
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(tree, 6)
	_check(session != null and is_equal_approx(session.day_clock().day_minutes(), minutes), "no game time went by before 继续")
	await _key(tree, KEY_SPACE)
	_check(not shell.focus_held() and not tree.paused and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "继续 (Space): playing")
	pacing.feel = feel
	shell.queue_free()
	await _frames(tree, 2)


# --- helpers -------------------------------------------------------------------------

func _key(tree: SceneTree, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame
	await tree.process_frame


func _until(tree: SceneTree, done: Callable, limit: int = 3000) -> void:
	var frames: int = 0
	while not done.call() and frames < limit:
		frames += 1
		await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
