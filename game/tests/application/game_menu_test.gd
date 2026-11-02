extends RefCounted
## The menu window (owner, 2026-10-15; DECISIONS「菜单窗口」): seven tabs in
## place of the HUD's panels; the keys C, K, I, J, Q, E and L; the menu's questions over it;
## 系统 is the shell's pause and holds its buttons; under the other tabs the tree runs and world time is held.

const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")
const ShellTests := preload("res://tests/application/application_shell_test.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _test_first_open_starts_at_the_top(tree)
	await _test_tabs_and_keys(tree)
	await _test_system_is_the_pause(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


## The first time the window shows, its page is sorted after the focus landed on the
## first row, and the scroll that followed the focus stayed past the top: 布衣's name and
## its buttons were cut off (project review, 2026-10-17). Every opening starts at the top
## with the focused row whole, the first, after a tab switch, and after closing.
func _test_first_open_starts_at_the_top(tree: SceneTree) -> void:
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	_check(session.configure_source_entry("背包", CharacterState.GENDER_MALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	var ui: SharedGameplayUI = session.shared_ui()
	var menu: GameMenu = ui.menu
	for opening: String in ["the first opening", "after a tab switch", "after closing"]:
		if opening == "after a tab switch":
			await _key(tree, KEY_E)
			await _frames(tree, 4)
			await _key(tree, KEY_Q)
		else:
			await _key(tree, KEY_I)
		await _frames(tree, 4)
		var scroll: ScrollContainer = menu._page_scroll
		var focused: Control = tree.root.gui_get_focus_owner()
		var rows: Node = menu.pages[GameMenu.Tab.INVENTORY].find_child("PlayerInventoryRows", true, false)
		var row: Control = null if rows == null or rows.get_child_count() == 0 else rows.get_child(0) as Control
		_check(menu.current_tab() == GameMenu.Tab.INVENTORY and row != null and focused != null and row.is_ancestor_of(focused), "%s: 背包 with the focus on its first row" % opening)
		if row == null or focused == null:
			continue
		var view: Rect2 = scroll.get_global_rect()
		_check(scroll.scroll_vertical == 0, "%s: the page starts at the top (scrolled %d)" % [opening, scroll.scroll_vertical])
		_check(view.encloses(row.get_global_rect()) and view.encloses(focused.get_global_rect()), "%s: the row and its buttons are whole: %s in %s" % [opening, row.get_global_rect(), view])
		if opening == "after a tab switch":
			await _key(tree, KEY_I)
			await _frames(tree, 4)
	session.queue_free()
	await tree.process_frame


## A Session without a shell: the menu opens on its own and pauses nothing.
func _test_tabs_and_keys(tree: SceneTree) -> void:
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	_check(session.configure_source_entry("菜单", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	var ui: SharedGameplayUI = session.shared_ui()
	var menu: GameMenu = ui.menu
	var layout: SharedGameplayLayout = ui._presentation_layout
	var titles: Array[String] = []
	for button: Button in menu.tab_buttons:
		titles.append(button.text)
	_check(titles == ["角色", "武学", "背包", "任务", "地图", "声望", "百科", "系统"], "the eight tabs in order: %s" % [titles])
	_check(not menu.is_presented() and layout.menu_button.is_visible_in_tree() and layout.bar.find_child("Navigation", true, false) == null, "the HUD keeps one 菜单 entry, no row of panels")
	_check(layout.bar.find_child("PlaceChip", true, false) == null, "the card names no place: the room's text shows at the top (DECISIONS「说话和交互」)")

	await _key(tree, KEY_C)
	_check(menu.is_presented() and menu.current_tab() == GameMenu.Tab.CHARACTER and ui.character_sheet.is_visible_in_tree(), "C opens 角色")
	_check(ui.character_sheet_text().contains("菜单") and ui.character_sheet_text().contains("综合评价"), "角色 shows score.c's sheet: " + ui.character_sheet_text().left(80))
	_check(not tree.paused and session.world_simulation_gate().is_open(), "角色 leaves the world running")
	await _key(tree, KEY_E)
	_check(menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS and ui.martial_arts_page().is_visible_in_tree(), "E: the next tab, 武学")
	await _key(tree, KEY_Q)
	await _key(tree, KEY_Q)
	_check(menu.current_tab() == GameMenu.Tab.SYSTEM and menu.system_mount.is_visible_in_tree() and not tree.paused, "Q wraps to 系统 (no shell: nothing to pause)")
	await _key(tree, KEY_I)
	_check(menu.current_tab() == GameMenu.Tab.INVENTORY and ui.inventory_is_open() and ui.inventory_rows().size() == 1, "I: 背包 with the cloth")
	_check(ui.supplies_mount.is_visible_in_tree() and ui.panels._food.is_visible_in_tree(), "背包 holds 随身补给")
	await _key(tree, KEY_J)
	_check(menu.current_tab() == GameMenu.Tab.JOURNAL and not ui.inventory_is_open(), "J: 任务; the 背包 no longer counts as open")
	# 任务系统: 朱鸿雪's lines stand under the 差事 column only while she gave a task.
	_check(ui.quest_text.text.is_empty() and not ui.quest_text.visible and ui.combat_log.is_visible_in_tree(), "任务: no quest.c lines without a task, and the log")
	await _key(tree, KEY_J)
	_check(not menu.is_presented(), "the shown tab's key closes the menu")

	ui.open_martial_arts()
	ui.ask_first("确定吗？", "确定", func() -> void: pass)
	_check(ui.is_asking() and menu.is_presented() and layout.frame.get_parent() == menu.root and layout.barrier.get_parent() == menu.root, "the menu's question shows over it")
	ui.confirm_prompt.cancel_button.pressed.emit()
	_check(not layout.frame.visible and menu.is_presented() and menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS, "取消 goes back to the page")
	ui.open_look()
	_check(not menu.is_presented() and layout.frame.visible and layout._content == layout.room and layout.frame.get_parent() == layout.overlay, "观察 replaces the menu; the frame is home")
	ui.dismiss_current_panel()
	ui.open_supplies()
	_check(menu.is_presented() and menu.current_tab() == GameMenu.Tab.INVENTORY, "补给 is on 背包")
	ui.dismiss_current_panel()
	_check(not menu.is_presented(), "Back with only the menu open closes it")
	await _key(tree, KEY_L)
	_check(layout.frame.visible and layout._content == layout.room, "L is 观察")
	ui.dismiss_current_panel()

	# World time stands still while the menu is open (owner, 2026-10-15); the player's
	# actions still work and their own busy wears down.
	var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
	var runtime: WorldPlayerRuntimeState = session.player_runtime()
	ui.open_character()
	var before: float = cadence.accumulated_seconds
	session._process(1.5)
	_check(session.world_time_held() and cadence.accumulated_seconds == before, "the open menu holds world time: the heart beat waits")
	runtime.busy.start_busy(2)
	for beat: int in 3:
		session._process(2.0)
	_check(not runtime.busy.is_busy(), "the player's own busy still wears down under the menu")
	var held_at: float = cadence.accumulated_seconds
	var vitality_before: int = runtime.state.vitality.current
	runtime.busy.start_busy(1)
	session._process(9.0)
	_check(not runtime.busy.is_busy() and cadence.accumulated_seconds < 2.0 and runtime.state.vitality.current == vitality_before, "a long frame under the menu spends only busy's beat: %.2f -> %.2f" % [held_at, cadence.accumulated_seconds])
	runtime.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	_check(not session.world_time_held(), "a player who cannot act holds no time, menu or not")
	runtime.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	before = cadence.accumulated_seconds
	ui.menu.show_tab(GameMenu.Tab.MARTIAL_ARTS)
	ui.martial_arts_page().exercise_button.pressed.emit()
	_check(ui.log_lines().back() == "你必须先用 enable 选择你要用的内功心法。", "a 武学 action still answers under the held time")
	ui.menu.close()
	session._process(1.5)
	_check(not session.world_time_held() and cadence.accumulated_seconds != before, "the menu closed: world time runs again")

	menu.begin_pause_view(true)
	var shown: Array[int] = []
	for tab: int in menu.tab_buttons.size():
		if menu.tab_buttons[tab].visible:
			shown.append(tab)
	_check(shown == [GameMenu.Tab.SYSTEM] and menu.fight_hint.visible, "in a fight the pause shows only 系统")
	await _key(tree, KEY_Q)
	_check(menu.current_tab() == GameMenu.Tab.SYSTEM, "and Q/E stay there")
	menu.end_pause_view()
	_check(not menu.is_presented() and not menu.system_only(), "the pause ends, the menu closes")
	session.queue_free()
	await tree.process_frame


## The game's shell: 系统 pauses and shows the pause's buttons; leaving it resumes.
func _test_system_is_the_pause(tree: SceneTree) -> void:
	var shell: ApplicationShellController = SHELL_SCENE.instantiate()
	_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test("game-menu"), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new()), "shell configures")
	tree.root.add_child(shell)
	await _frames(tree, 3)
	_check(PublicNewGameTestFixture.request(shell), "New Game")
	await _frames(tree, 3)
	if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
		PublicNewGameTestFixture.confirm(shell)
		await _frames(tree, 3)
	var session: WorldSessionController = shell.runtime_host().current_session()
	_check(session != null and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "playing")
	if session == null:
		shell.queue_free()
		return
	var ui: SharedGameplayUI = session.shared_ui()
	var menu: GameMenu = ui.menu
	ui.open_character()
	_check(menu.is_presented() and not tree.paused and session.world_time_held() and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "角色 opens with world time held, the tree running")
	await _frames(tree, 2)
	var card: Control = ui._presentation_layout.bar
	_check(card.is_visible_in_tree(), "角色: the status card stays behind the menu")
	menu.tab_buttons[GameMenu.Tab.SYSTEM].pressed.emit()
	_check(tree.paused and shell.shell_state().mode() == ApplicationShellState.Mode.PAUSED and menu.in_pause_view() and menu.current_tab() == GameMenu.Tab.SYSTEM, "系统 pauses the world")
	await _frames(tree, 2)
	_check(card.is_visible_in_tree() and ui.visible, "系统 (the pause): the status card stays behind the menu, as on the other tabs")
	_check(shell.menu_hosted() and shell.pause_visible() and not shell.pause_panel.visible and menu.system_mount.is_ancestor_of(shell.resume_button), "系统 holds the pause's buttons")
	menu.tab_buttons[GameMenu.Tab.INVENTORY].pressed.emit()
	_check(not tree.paused and session.world_time_held() and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING and menu.is_presented() and menu.current_tab() == GameMenu.Tab.INVENTORY, "another tab leaves the shell's pause; world time stays held")
	_check(shell.pause_panel.is_ancestor_of(shell.resume_button) and not shell.menu_hosted(), "the buttons go home")
	await _key(tree, KEY_ESCAPE)
	_check(not menu.is_presented() and not tree.paused and not session.world_time_held(), "Esc closes the menu; world time runs")
	await _key(tree, KEY_ESCAPE)
	_check(tree.paused and menu.is_presented() and menu.current_tab() == GameMenu.Tab.SYSTEM and shell.menu_hosted(), "Esc on the open world is the pause: the menu on 系统")
	await _frames(tree, 2)
	_check(shell.get_viewport().gui_get_focus_owner() == shell.resume_button, "继续 has the focus, as in the pause panel")
	_check(shell.request_settings_from_pause() and not shell.menu_hosted() and menu.is_presented(), "设置 from 系统: the menu waits under it")
	_check(shell.cancel_settings() and shell.menu_hosted() and menu.current_tab() == GameMenu.Tab.SYSTEM, "back to 系统")
	await _key(tree, KEY_ESCAPE)
	_check(not tree.paused and not menu.is_presented() and shell.shell_state().mode() == ApplicationShellState.Mode.PLAYING, "Esc in the pause resumes and closes")
	await _key(tree, KEY_K)
	_check(menu.is_presented() and menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS and not tree.paused, "K: 武学 over the running world")
	ui.ask_first("确定吗？", "确定", func() -> void: pass)
	await _key(tree, KEY_ESCAPE)
	_check(not ui.is_asking() and menu.is_presented() and menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS and not tree.paused, "Esc on the menu's question drops only the question")
	ui.ask_first("确定吗？", "确定", func() -> void: pass)
	_check(shell.request_pause() and not ui.is_asking() and not ui._presentation_layout.frame.visible and menu.current_tab() == GameMenu.Tab.SYSTEM, "the pause drops a question asked over a gameplay tab")
	await _key(tree, KEY_K)
	_check(not tree.paused and menu.is_presented() and menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS, "K in the pause resumes on 武学")
	shell.resume_button.pressed.emit()
	_check(menu.is_presented() and not tree.paused, "继续 at home does nothing while playing")
	menu.close()
	shell.queue_free()
	await tree.process_frame


func _key(tree: SceneTree, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		tree.root.push_input(event)
	await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for index: int in count:
		await tree.process_frame


func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)
