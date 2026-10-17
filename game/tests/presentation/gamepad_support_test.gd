extends RefCounted
## Gamepad support (owner, ROADMAP "After the grey box" step 2, 界面重构 B): which input is
## in use and the glyphs that follow it, the walking HUD's list (Y / A in, B out), the
## menu's LB / RB and its focus, a panel's focus and its return, the battle's LB / RB, Y and
## B, number boxes stepped with ←/→. Pad input is sent as joypad events.

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_devices()
	_test_glyphs()
	_test_random_names()
	await _test_bindings_and_hints(tree)
	await _test_focus_helpers(tree)
	await _test_walking_hud(tree)
	InputDevices.shared().set_kind(InputDevices.Kind.KEYBOARD_MOUSE, InputDevices.PadStyle.XBOX)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_devices() -> void:
	var devices := InputDevices.new()
	var changes: Array[int] = []
	var note := func() -> void: changes.append(devices.kind)
	devices.changed.connect(note)
	devices.observe(_joy_button(JOY_BUTTON_A, true))
	_check(devices.is_gamepad() and changes == [InputDevices.Kind.GAMEPAD], "a pad button makes the pad the input in use")
	devices.observe(_joy_button(JOY_BUTTON_A, false))
	devices.observe(_joy_motion(JOY_AXIS_LEFT_X, 0.2))
	_check(changes.size() == 1, "a release or a resting stick changes nothing")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	devices.observe(key)
	_check(devices.kind == InputDevices.Kind.KEYBOARD_MOUSE and changes.size() == 2, "a key press: keys again")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(1, 1)
	devices.set_kind(InputDevices.Kind.GAMEPAD)
	devices.observe(motion)
	_check(devices.is_gamepad(), "a tiny mouse move keeps the pad")
	motion.relative = Vector2(12, 0)
	devices.observe(motion)
	_check(devices.kind == InputDevices.Kind.KEYBOARD_MOUSE, "a real mouse move: keys and mouse")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	devices.observe(touch)
	_check(devices.is_touch(), "a touch: touch")
	var routed := InputEventMouseButton.new()
	routed.pressed = true
	routed.device = InputDevices.TOUCH_POINTER_DEVICE
	devices.observe(routed)
	_check(devices.is_touch(), "the touch adapter's own clicks stay touch")
	devices.changed.disconnect(note)
	_check(InputDevices.style_for("PS5 Controller") == InputDevices.PadStyle.PLAYSTATION and InputDevices.style_for("Nintendo Switch Pro Controller") == InputDevices.PadStyle.NINTENDO and InputDevices.style_for("Xbox Series Controller") == InputDevices.PadStyle.XBOX, "pad styles by name")


func _test_glyphs() -> void:
	var devices := InputDevices.new()
	devices.set_kind(InputDevices.Kind.GAMEPAD, InputDevices.PadStyle.XBOX)
	_check(_text(&"ui_accept", devices) == "A" and _text(&"ui_cancel", devices) == "B" and _text(&"nearby_focus", devices) == "Y" and _text(&"look_around", devices) == "X" and _text(&"interact", devices) == "A", "Xbox: A B Y X, interact A")
	_check(_text(&"menu_open", devices) == "Start" and _text(&"pause_game", devices) == "Back" and _text(&"menu_tab_previous", devices) == "LB" and _text(&"menu_tab_next", devices) == "RB", "Start, Back, LB, RB")
	_check(_text(&"scroll_down", devices) == "RS", "the right stick scrolls")
	_check(InputGlyphs.glyph_for(&"menu_character", devices) == null, "no pad glyph for a key-only action")
	devices.set_kind(InputDevices.Kind.GAMEPAD, InputDevices.PadStyle.PLAYSTATION)
	_check(InputGlyphs.glyph_for(&"ui_accept", devices).shape == InputGlyphs.Shape.CROSS and InputGlyphs.glyph_for(&"ui_cancel", devices).shape == InputGlyphs.Shape.RING and _text(&"menu_tab_next", devices) == "R1", "PlayStation: ✕ ○ R1")
	devices.set_kind(InputDevices.Kind.GAMEPAD, InputDevices.PadStyle.NINTENDO)
	_check(_text(&"ui_accept", devices) == "B" and _text(&"ui_cancel", devices) == "A", "Nintendo names the bottom button B")
	devices.set_kind(InputDevices.Kind.KEYBOARD_MOUSE)
	_check(_text(&"ui_accept", devices) == "Enter" and _text(&"ui_cancel", devices) == "Esc" and _text(&"menu_open", devices) == "M" and _text(&"nearby_focus", devices) == "Tab" and _text(&"battle_back", devices) == "Backspace" and _text(&"interact", devices) == "E", "keys: Enter Esc M Tab Backspace, interact E")
	devices.set_kind(InputDevices.Kind.TOUCH)
	_check(InputGlyphs.glyph_for(&"ui_accept", devices) == null, "touch shows no glyph")
	# Every action the game binds to a pad shows one.
	devices.set_kind(InputDevices.Kind.GAMEPAD, InputDevices.PadStyle.XBOX)
	for action: StringName in [&"move_left", &"move_up", &"battle_target_next", &"battle_log", &"battle_back", &"scroll_up"]:
		_check(InputGlyphs.glyph_for(action, devices) != null, "%s has a pad glyph" % action)


## 随机名字 (a pad has no keys to type a name): every name it can give passes the name rules.
func _test_random_names() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NewPlayerRandomName.NAMES_PATH))
	var invalid: Array[String] = []
	for surname: String in data["surnames"]:
		for given: String in data["given"]["male"] + data["given"]["female"]:
			if not NewPlayerNamePolicy.is_valid(surname + given):
				invalid.append(surname + given)
	_check(invalid.is_empty(), "every random name is a valid name: %s" % [invalid])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var male: String = NewPlayerRandomName.pick(CharacterState.GENDER_MALE, rng)
	var female: String = NewPlayerRandomName.pick(CharacterState.GENDER_FEMALE, rng)
	_check(data["given"]["male"].any(func(g: String) -> bool: return male.ends_with(g)) and data["given"]["female"].any(func(g: String) -> bool: return female.ends_with(g)), "the given name follows the chosen gender: %s %s" % [male, female])


func _test_bindings_and_hints(tree: SceneTree) -> void:
	var shared: InputDevices = InputDevices.shared()
	shared.set_kind(InputDevices.Kind.KEYBOARD_MOUSE, InputDevices.PadStyle.XBOX)
	var box := VBoxContainer.new()
	tree.root.add_child(box)
	var button := Button.new()
	button.text = "关闭"
	box.add_child(button)
	InputGlyphs.decorate(button, &"ui_cancel")
	var hints := InputHintRow.new()
	box.add_child(hints)
	hints.set_hints([[&"ui_accept", "开门"], [[&"menu_tab_previous", &"menu_tab_next"], "切换"], [&"menu_character", "角色"]])
	await tree.process_frame
	_check(button.icon is InputGlyphTexture and (button.icon as InputGlyphTexture).glyph().text == "Esc", "keys: 关闭 shows Esc")
	_check(hints.visible and hints.shown_hints() == ["Enter 开门", "Q E 切换", "C 角色"], "keys: the hints: %s" % [hints.shown_hints()])
	shared.set_kind(InputDevices.Kind.GAMEPAD, InputDevices.PadStyle.XBOX)
	await tree.process_frame
	_check((button.icon as InputGlyphTexture).glyph().text == "B" and button.icon.get_width() > 0, "pad: 关闭 shows B at once")
	_check(hints.shown_hints() == ["A 开门", "LB RB 切换"], "pad: the hints follow, a key-only one goes: %s" % [hints.shown_hints()])
	shared.set_kind(InputDevices.Kind.TOUCH)
	await tree.process_frame
	_check(button.icon == null and not hints.visible, "touch: no icon (the button keeps its size), no hints")
	shared.set_kind(InputDevices.Kind.KEYBOARD_MOUSE)
	box.queue_free()
	await tree.process_frame


func _test_focus_helpers(tree: SceneTree) -> void:
	var box := VBoxContainer.new()
	tree.root.add_child(box)
	var text := RichTextLabel.new()
	text.focus_mode = Control.FOCUS_ALL
	box.add_child(text)
	var hidden := Button.new()
	hidden.hide()
	box.add_child(hidden)
	var greyed := Button.new()
	greyed.disabled = true
	box.add_child(greyed)
	var spin := SpinBox.new()
	spin.max_value = 10
	spin.step = 2
	box.add_child(spin)
	var amount := LineEdit.new()
	amount.text = "1"
	amount.set_meta(PadSupport.STEP_META, true)
	box.add_child(amount)
	await tree.process_frame
	_check(FocusNav.first_focusable(box) == spin.get_line_edit(), "the first stop skips text, hidden and greyed controls")
	var support := PadSupport.new()
	tree.root.add_child(support)
	spin.get_line_edit().grab_focus()
	await _joy(tree, JOY_BUTTON_DPAD_RIGHT)
	await _joy(tree, JOY_BUTTON_DPAD_RIGHT)
	_check(spin.value == 4.0 and tree.root.gui_get_focus_owner() == spin.get_line_edit(), "D-pad →: the number box steps up, the focus stays")
	await _joy(tree, JOY_BUTTON_DPAD_LEFT)
	_check(spin.value == 2.0, "D-pad ←: one step down")
	amount.grab_focus()
	await _joy(tree, JOY_BUTTON_DPAD_LEFT)
	_check(amount.text == "1", "an amount never goes below 1")
	await _joy(tree, JOY_BUTTON_DPAD_RIGHT)
	_check(amount.text == "2", "the bank's amount steps too")
	await _joy(tree, JOY_BUTTON_DPAD_UP)
	_check(tree.root.gui_get_focus_owner() == spin.get_line_edit(), "D-pad ↑ still moves the focus")
	await _joy(tree, JOY_BUTTON_DPAD_RIGHT)
	_check(spin.value == 4.0, "focused again, still one step a press")
	# The stick sends a stream of motion events while tilted: one step per tilt.
	for value: float in [0.6, 0.8, 1.0, 1.0]:
		Input.parse_input_event(_joy_motion(JOY_AXIS_LEFT_X, value))
		await tree.process_frame
	_check(spin.value == 6.0, "one stick tilt, one step (%s)" % spin.value)
	Input.parse_input_event(_joy_motion(JOY_AXIS_LEFT_X, 0.0))
	await tree.process_frame
	Input.parse_input_event(_joy_motion(JOY_AXIS_LEFT_X, 1.0))
	await tree.process_frame
	Input.parse_input_event(_joy_motion(JOY_AXIS_LEFT_X, 0.0))
	await tree.process_frame
	_check(spin.value == 8.0, "rested and tilted again: the next step")
	_check(FocusNav.first_focusable(box, true) == null, "a panel does not open into a text box")
	var after := Button.new()
	box.add_child(after)
	_check(FocusNav.first_focusable(box, true) == after, "it opens on the first button")
	# A rebuilt list: the focus place is the same row and button.
	var rows := VBoxContainer.new()
	tree.root.add_child(rows)
	_fill_rows(rows)
	await tree.process_frame
	var focused: Button = rows.get_child(2).get_child(1)
	var place: PackedInt32Array = FocusNav.place_of(rows, focused)
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	_fill_rows(rows)
	_check(FocusNav.at_place(rows, place) == rows.get_child(2).get_child(1), "the same place in the rebuilt list")
	rows.get_child(2).queue_free()
	rows.get_child(1).queue_free()
	_check(FocusNav.at_place(rows, place) == rows.get_child(0).get_child(1), "a shorter list: its last row")
	rows.queue_free()
	support.queue_free()
	box.queue_free()
	await tree.process_frame


## The walking HUD, the menu and a panel, driven by pad events (no shell: B closes the
## frame through dismiss_current_panel(), as the shell's Back does).
func _test_walking_hud(tree: SceneTree) -> void:
	InputDevices.shared().set_kind(InputDevices.Kind.GAMEPAD, InputDevices.PadStyle.XBOX)
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	_check(session.configure_source_entry("凌雪", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	await _frames(tree, 4)
	var ui: SharedGameplayUI = session.shared_ui()
	var layout: SharedGameplayLayout = ui._presentation_layout
	var map := session.active_map() as WorldMapController
	_check(layout.menu_button.focus_mode == Control.FOCUS_NONE and InputGlyphBinding.action_of(layout.menu_button) == &"menu_open", "菜单 shows Start and takes no focus from a click")
	# Beside 店小二 at the counter: the prompt marks what A goes to (DECISIONS「说话和交互」).
	var waiter: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == &"snow.npc.waiter":
			waiter = npc
	var zone: StringName = waiter.world_location().zone_id
	_check(map.place_player(zone, MapPlaces.spot(map, zone, map.runtime_body_for_character(waiter.character_id).global_position + Vector2(0, 52))), "beside 店小二")
	map.npc_life._advance_ambience(0.0)
	await _until(tree, func() -> bool: return ui.nearby.target() != null)
	_check(layout.bar.find_child("Nearby", true, false) == null, "the card lists nothing near: the prompt over the target does")

	# Y steps the target through what is in reach.
	var first_target: WorldNearbyThing = ui.nearby.target()
	await _joy(tree, JOY_BUTTON_Y)
	_check(ui.nearby.groups().size() < 2 or ui.nearby.target().id != first_target.id, "Y: the next thing in reach (%d near)" % ui.nearby.groups().size())
	_check(ui.nearby.choose(waiter.character_id), "the waiter as the target")

	# A on him: his popup, on its first row; world time stands still; the stick moves the focus.
	var standing: Vector2 = map.runtime_player_body().global_position
	await _joy(tree, JOY_BUTTON_A)
	var first: Control = tree.root.gui_get_focus_owner()
	_check(ui.interaction_open() and first is Button and not (first as Button).disabled and ui.interaction_panel.is_ancestor_of(first), "A: his popup, on its first row: %s" % first)
	await _frames(tree, 2)
	_check(session.world_time_held(), "the popup holds world time")
	Input.parse_input_event(_joy_motion(JOY_AXIS_LEFT_Y, 1.0))
	for frame: int in 6:
		await tree.physics_frame
	Input.parse_input_event(_joy_motion(JOY_AXIS_LEFT_Y, 0.0))
	await tree.process_frame
	_check(map.runtime_player_body().global_position == standing, "the stick moves the focus, not the player")
	first.grab_focus()
	await _joy(tree, JOY_BUTTON_DPAD_DOWN)
	var second: Control = tree.root.gui_get_focus_owner()
	_check(second != first and ui.interaction_panel.is_ancestor_of(second), "D-pad ↓: the next row")
	_check(InputGlyphBinding.action_of(layout.close_button) == &"ui_cancel", "关闭 shows B")
	# A on a row: its page in the popup's right column, focused there; B (as the shell routes
	# it) back to 查看 with the focus on that row; B again: back to walking.
	var row: Button = second as Button
	var label: String = ""
	for shown: Array in ui.interaction_panel.shown():
		if ui.interaction_panel.button_of(shown[0]) == row:
			label = shown[0]
	row.grab_focus()
	await _joy(tree, JOY_BUTTON_A)
	await _frames(tree, 2)
	var page: Control = layout.page()
	_check(ui.interaction_open() and page != null and ui.interaction_panel.current() == label, "A on %s: its page, in the popup" % label)
	var focused: Control = tree.root.gui_get_focus_owner()
	_check(focused != null and (page.is_ancestor_of(focused) or focused == layout.close_button), "the page has the focus: %s" % focused)
	if focused != null and page.is_ancestor_of(focused):
		await _joy(tree, JOY_BUTTON_DPAD_LEFT)
		var moved: Control = tree.root.gui_get_focus_owner()
		_check(moved != null and ui.interaction_panel.is_ancestor_of(moved) and not page.is_ancestor_of(moved), "D-pad ←: from the page to the rows: %s" % moved)
		await _joy(tree, JOY_BUTTON_DPAD_RIGHT)
		moved = tree.root.gui_get_focus_owner()
		_check(moved != null and page.is_ancestor_of(moved), "D-pad →: back into the page: %s" % moved)
	await _back(tree)
	await _frames(tree, 2)
	_check(ui.interaction_open() and layout.page() == null and tree.root.gui_get_focus_owner() == row, "B: back to 查看, on its row")
	_check(session.world_time_held(), "查看 holds world time again")
	await _back(tree)
	await _frames(tree, 2)
	_check(not layout.frame.visible and tree.root.gui_get_focus_owner() == null, "B again: back to walking")

	# A button's A press is its own (it fires on release): nothing else opens on the press.
	await _joy(tree, JOY_BUTTON_A)
	ui.interaction_panel.button_of(label).grab_focus()
	Input.parse_input_event(_joy_button(JOY_BUTTON_A, true))
	await tree.process_frame
	_check(ui.interaction_open() and layout.page() == null, "the press on a focused row opens nothing else")
	Input.parse_input_event(_joy_button(JOY_BUTTON_A, false))
	await tree.process_frame
	_check(layout.page() != null and ui.interaction_panel.current() == label, "its release presses it")
	ui.dismiss_current_panel()
	ui.dismiss_current_panel()
	await tree.process_frame

	# Start: the menu on its last tab, the focus on the page or its tab; RB, LB; Start closes
	# it and the player walks again.
	await _joy(tree, JOY_BUTTON_START)
	await tree.process_frame
	var menu: GameMenu = ui.menu
	_check(menu.is_presented() and menu.window.is_ancestor_of(tree.root.gui_get_focus_owner()), "Start: the menu, focused")
	_check(menu.tab_glyphs.size() == 2 and menu.tab_glyphs[0].visible and (menu.tab_glyphs[1].texture as InputGlyphTexture).glyph().text == "RB", "LB and RB at the strip's ends")
	await _joy(tree, JOY_BUTTON_RIGHT_SHOULDER)
	await tree.process_frame
	_check(menu.current_tab() == GameMenu.Tab.MARTIAL_ARTS and menu.pages[GameMenu.Tab.MARTIAL_ARTS].is_ancestor_of(tree.root.gui_get_focus_owner()), "RB: 武学, on its first button")
	await _joy(tree, JOY_BUTTON_RIGHT_SHOULDER)
	await tree.process_frame
	_check(menu.current_tab() == GameMenu.Tab.INVENTORY and menu.pages[GameMenu.Tab.INVENTORY].is_ancestor_of(tree.root.gui_get_focus_owner()), "RB: 背包, on its first row")
	await _joy(tree, JOY_BUTTON_RIGHT_SHOULDER)
	await tree.process_frame
	_check(menu.current_tab() == GameMenu.Tab.JOURNAL and tree.root.gui_get_focus_owner() == menu.tab_buttons[GameMenu.Tab.JOURNAL], "任务 has no stop: its tab keeps the focus")
	await _joy(tree, JOY_BUTTON_LEFT_SHOULDER)
	await tree.process_frame
	_check(menu.current_tab() == GameMenu.Tab.INVENTORY, "LB: back")
	# A question over the menu takes the shoulders' presses from it.
	ui.ask_first("确定吗？", "确定", func() -> void: pass)
	await _joy(tree, JOY_BUTTON_RIGHT_SHOULDER)
	_check(menu.current_tab() == GameMenu.Tab.INVENTORY and tree.root.gui_get_focus_owner() == ui.confirm_prompt.cancel_button, "RB under a question does nothing; 取消 has the focus")
	ui.confirm_prompt.cancel()
	await tree.process_frame
	_check(menu.pages[GameMenu.Tab.INVENTORY].is_ancestor_of(tree.root.gui_get_focus_owner()), "取消: the focus back on the page")
	await _joy(tree, JOY_BUTTON_START)
	_check(not menu.is_presented() and tree.root.gui_get_focus_owner() == null, "Start closes it")

	# Walking, RB and Tab step the target too (Tab is not "next control" with nothing focused).
	var before: WorldNearbyThing = ui.nearby.target()
	await _joy(tree, JOY_BUTTON_RIGHT_SHOULDER)
	_check(ui.nearby.groups().size() < 2 or ui.nearby.target().id != before.id, "RB: the next thing in reach")
	before = ui.nearby.target()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await tree.process_frame
	tab.pressed = false
	Input.parse_input_event(tab)
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == null and (ui.nearby.groups().size() < 2 or ui.nearby.target().id != before.id), "Tab: the next thing in reach, no focus taken")

	# X is 观察.
	await _joy(tree, JOY_BUTTON_X)
	_check(layout.frame.visible and layout._content == layout.room, "X: 观察")
	ui.dismiss_current_panel()
	await tree.process_frame

	await _test_battle(tree, session, map, waiter)
	session.queue_free()
	await _frames(tree, 2)


## The battle's pad keys: LB / RB step the target, Y opens and closes the log, B closes the
## log, answers a question 取消 and drops the planned action, without pausing.
func _test_battle(tree: SceneTree, session: WorldSessionController, map: WorldMapController, waiter: NpcRuntimeState) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.progression.combat_experience = 100000
	map.select_npc(waiter.character_id)
	map.attack_selected()
	await _until(tree, func() -> bool: return session.combat_encounter_coordinator().has_active_encounter())
	session.set_process(false)
	var battle: BattlePresentationController = session.find_children("*", "BattlePresentationController", true, false)[0]
	battle.refresh_projection()
	await _frames(tree, 2)
	_check(battle.is_visible_in_tree() and battle.action_panel.is_ancestor_of(tree.root.gui_get_focus_owner()), "the battle's first action has the focus")
	_check(InputGlyphBinding.action_of(battle.log_button) == &"battle_log" and battle.action_panel.prompt.cancel_action == &"battle_back", "战斗记录 shows Y, the battle's question 取消 B")
	var before: StringName = battle.current_projection().current_target_id
	await _joy(tree, JOY_BUTTON_RIGHT_SHOULDER)
	battle.refresh_projection()
	_check(battle.current_projection().current_target_id == waiter.character_id, "RB: the target (was %s)" % before)
	await _joy(tree, JOY_BUTTON_Y)
	_check(battle.log_panel.visible, "Y opens the log")
	await _joy(tree, JOY_BUTTON_B)
	_check(not battle.log_panel.visible and not tree.paused, "B closes it, no pause")
	await _joy(tree, JOY_BUTTON_Y)
	await _joy(tree, JOY_BUTTON_Y)
	_check(not battle.log_panel.visible, "Y closes it too")
	# A planned action, dropped with B.
	var surrender: Button = null
	for button: Node in battle.action_panel._actions.get_children():
		if (button as Button).text == battle.action_panel.catalog.label_for(CombatSurrenderTacticalPolicy.ACTION_ID):
			surrender = button
	if surrender != null:
		surrender.grab_focus()
		await _joy(tree, JOY_BUTTON_A)
		battle.refresh_projection()
		_check(battle.action_panel._cancel.visible and InputGlyphBinding.action_of(battle.action_panel._cancel) == &"battle_back", "A plans 投降; 取消 shows B")
		await _joy(tree, JOY_BUTTON_B)
		battle.refresh_projection()
		_check(not battle.action_panel._cancel.visible and session.combat_encounter_coordinator().has_active_encounter() and not tree.paused, "B drops it; the fight goes on, unpaused")
	else:
		_check(false, "投降 in the battle's actions: %s" % [battle.action_panel._shown_ids])
	await _joy(tree, JOY_BUTTON_B)
	_check(not tree.paused and session.combat_encounter_coordinator().has_active_encounter(), "B with nothing to drop does nothing")
	session.set_process(true)
	session.combat_encounter_coordinator().take_aborted_total()


# --- helpers -------------------------------------------------------------------------

## B as the game's shell routes it while a panel is up (no shell here): the top panel's Back.
func _back(tree: SceneTree) -> void:
	Input.parse_input_event(_joy_button(JOY_BUTTON_B, true))
	var panel: ResponsivePanelLayout = ResponsivePanelLayout.top_interaction_panel(tree)
	if panel != null:
		panel.dismiss_requested.emit()
	await tree.process_frame
	Input.parse_input_event(_joy_button(JOY_BUTTON_B, false))
	await tree.process_frame


func _fill_rows(rows: VBoxContainer) -> void:
	for row_index: int in 3:
		var row := HBoxContainer.new()
		rows.add_child(row)
		for button_index: int in 2:
			var button := Button.new()
			button.text = "%d-%d" % [row_index, button_index]
			row.add_child(button)


func _card_button(ui: SharedGameplayUI, label: String) -> Button:
	for button: Button in ui._card_buttons():
		if button.text == label:
			return button
	return null


func _text(action: StringName, devices: InputDevices) -> String:
	var glyph: InputGlyphs.Glyph = InputGlyphs.glyph_for(action, devices)
	return "" if glyph == null else glyph.text


func _joy_button(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _joy_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _joy(tree: SceneTree, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		Input.parse_input_event(_joy_button(button, pressed))
		await tree.process_frame
	await tree.process_frame


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _until(tree: SceneTree, done: Callable, frames: int = 240) -> void:
	for i: int in frames:
		if done.call():
			return
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
