class_name GameMenu
extends CanvasLayer
## The menu window (owner, 2026-10-15; ROADMAP "After the grey box" step 2): one window
## with the tabs 角色, 武学, 背包, 任务, 声望, 百科 and 系统 in place of the HUD's separate
## panels. 系统 is the pause: the shell's pause state shows this window and lends it its
## pause buttons (继续, 存档, 设置, 返回主菜单) through a node of HOST_GROUP. Under the other
## tabs the tree runs (their actions need it: portable_inventory_available()) but world
## time stands still (SharedGameplayUI holds it while the menu is open, owner); a fight an
## action starts closes the menu. Without a shell (tests) 系统 opens on its own. The pages
## keep their own rules; this class only shows one page at a time.

signal tab_shown(tab: int)

enum Tab { CHARACTER, MARTIAL_ARTS, INVENTORY, JOURNAL, STANDING, CODEX, SYSTEM }

## Tab titles, in Tab order.
const TAB_TITLES: Array[String] = ["角色", "武学", "背包", "任务", "声望", "百科", "系统"]
const TAB_NODE_NAMES: Array[String] = ["CharacterTab", "ArtsTab", "InventoryTab", "JournalTab", "StandingTab", "CodexTab", "SystemTab"]
## The keys that open a tab directly (project.godot), in Tab order; "" none.
const TAB_ACTIONS: Array[StringName] = [&"menu_character", &"menu_martial_arts", &"menu_inventory", &"menu_journal", &"", &"", &""]
## The shell's group: request_menu(Tab.SYSTEM) pauses, request_resume() resumes.
const HOST_GROUP: StringName = &"game_menu_hosts"
## Above the battle surface (50), below the shared frame's dialogs (61), the touch
## controls (90) and the shell (100).
const LAYER: int = 60
## The window's size where the screen allows it.
const WINDOW_SIZE: Vector2 = Vector2(920, 600)
# TRANSLATORS: the 声望 tab until reputation is built (ROADMAP step 6).
const STANDING_PLACEHOLDER: String = "江湖上对你的看法，日后会记在这里。"
# TRANSLATORS: the 系统 tab during a fight: the other tabs wait until it is over.
const FIGHT_HINT: String = "战斗中只能使用系统功能。"

var root: Control
var barrier: ColorRect
var window: PanelContainer
var tab_buttons: Array[Button] = []
## The keys or pad buttons that step through the tabs (Q / E, LB / RB), at the strip's ends.
var tab_glyphs: Array[TextureRect] = []
var close_button: Button
var pages: Array[Control] = []
## Where the shell puts its pause buttons (继续, 存档, 设置, 返回主菜单) while it shows
## this window.
var system_mount: VBoxContainer
var fight_hint: Label
var _page_scroll: ScrollContainer
var _ui: SharedGameplayUI
var _layout: ResponsivePanelLayout
var _safe: SafeAreaPresenter
var _current: int = Tab.CHARACTER
var _system_only: bool = false
var _paused_view: bool = false
## Where keys' or pad's focus goes back when the window closes (the card's list).
var _return_focus: WeakRef
## Set while show_tab() asks the shell to resume: the window stays open.
var _switching: bool = false


func build(ui: SharedGameplayUI, character_page: Control, arts_page: Control, inventory_page: Control, journal_page: Control, codex_page: Control) -> void:
	_ui = ui
	name = "GameMenu"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	barrier = ColorRect.new()
	barrier.name = "Barrier"
	barrier.color = Color(0, 0, 0, 0.45)
	barrier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barrier.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(barrier)
	window = PanelContainer.new()
	window.name = "Window"
	window.add_theme_stylebox_override("panel", _window_style())
	root.add_child(window)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	window.add_child(rows)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	header.theme = SharedGameplayLayout.card_theme()
	rows.add_child(header)
	var tabs := HFlowContainer.new()
	tabs.name = "Tabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tabs)
	tab_glyphs.append(_tab_glyph(tabs, &"menu_tab_previous"))
	var group := ButtonGroup.new()
	for tab: int in TAB_TITLES.size():
		var button := Button.new()
		button.name = TAB_NODE_NAMES[tab]
		button.text = TAB_TITLES[tab]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(72, 38)
		button.pressed.connect(show_tab.bind(tab))
		tabs.add_child(button)
		tab_buttons.append(button)
	tab_glyphs.append(_tab_glyph(tabs, &"menu_tab_next"))
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(80, 38)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	InputGlyphs.decorate(close_button, &"ui_cancel")
	InputDevices.shared().changed.connect(_show_tab_glyphs)
	_show_tab_glyphs()
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(rule)
	_page_scroll = ScrollContainer.new()
	_page_scroll.name = "PageScroll"
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.follow_focus = true
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.add_to_group(PadSupport.SCROLL_GROUP)
	rows.add_child(_page_scroll)
	var page_rows := VBoxContainer.new()
	page_rows.name = "Pages"
	page_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(page_rows)
	system_mount = VBoxContainer.new()
	system_mount.name = "SystemPage"
	system_mount.add_theme_constant_override("separation", 10)
	fight_hint = _placeholder(FIGHT_HINT)
	fight_hint.name = "FightHint"
	system_mount.add_child(fight_hint)
	var standing := _placeholder(STANDING_PLACEHOLDER)
	standing.name = "StandingPage"
	for page: Control in [character_page, arts_page, inventory_page, journal_page, standing, codex_page, system_mount]:
		if page.get_parent() != null:
			page.reparent(page_rows, false)
		else:
			page_rows.add_child(page)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.hide()
		pages.append(page)
	_layout = ResponsivePanelLayout.new()
	_layout.name = "WindowLayout"
	add_child(_layout)
	_layout.initialize(window)
	# Like the shared frame: the movement pad hides, Back closes the window.
	_layout.blocks_touch_gameplay = true
	_layout.dismiss_requested.connect(close)
	window.add_child(ExplorationPresentationBlocker.new())
	_attach()


func _enter_tree() -> void:
	if is_instance_valid(window):
		_attach.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_safe) and _safe.metrics_changed.is_connected(_reflow):
		_safe.metrics_changed.disconnect(_reflow)
	_safe = null


func _attach() -> void:
	if not is_inside_tree() or not is_instance_valid(window):
		return
	_safe = SafeAreaPresenter.find_or_create(self)
	if not _safe.metrics_changed.is_connected(_reflow):
		_safe.metrics_changed.connect(_reflow)
	_reflow(_safe.current_metrics())


## The window keeps one size whatever the tab (centred in the safe area); touch screens
## keep the top strip for the pause button, as the shared frame does.
func _reflow(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	var area: Rect2 = metrics.content_rect()
	if metrics.touch_sized():
		area.position.y += 72
		area.size.y = maxf(1, area.size.y - 72)
	var size := Vector2(minf(WINDOW_SIZE.x, area.size.x), minf(WINDOW_SIZE.y, area.size.y))
	_layout.apply(metrics, Rect2(area.position + (area.size - size) / 2.0, size), false, size.x)


# --- opening and closing ---


## The player asks for the menu on `tab` (-1: the last one). 系统 is the pause: it goes
## through the shell, which pauses the tree and calls begin_pause_view(); the other tabs
## open at once (world time held, the tree running).
func open(tab: int = -1) -> void:
	var wanted: int = _current if tab < 0 else tab
	if wanted == Tab.SYSTEM and not _paused_view:
		var host: Node = _host()
		if host != null:
			host.request_menu(Tab.SYSTEM)
			return
	present(wanted)


## The player closes the menu: from 系统 the shell resumes the world (and calls
## end_pause_view()), else it just closes.
func close() -> void:
	var host: Node = _host()
	if _paused_view and host != null:
		host.request_resume()
	else:
		dismiss()


## Shows the window on `tab` (-1: the last one).
func present(tab: int = -1) -> void:
	var first: bool = not visible
	if first:
		var focused: Control = root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
		_return_focus = null if focused == null or root.is_ancestor_of(focused) else weakref(focused)
	visible = true
	if first and _ui != null:
		_ui.menu_presented()
	show_tab(_current if tab < 0 else tab)


func dismiss() -> void:
	_dismiss(false)


## `from_pause`: the shell resumed the world; held input is the shell's to release.
func _dismiss(from_pause: bool) -> void:
	if not visible:
		return
	var focused: Control = root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	if focused != null and root.is_ancestor_of(focused):
		focused.release_focus()
	visible = false
	_system_only = false
	_hide_pages()
	if _ui != null:
		_ui.menu_dismissed(from_pause)
	var back: Control = FocusNav.held(_return_focus)
	_return_focus = null
	FocusNav.give(back)


## The shell paused the world for 系统 (Esc, or the 系统 tab). `system_only`: during a
## fight only 系统 is shown, as the pause menu was the only thing there before.
func begin_pause_view(system_only: bool) -> void:
	_paused_view = true
	_system_only = system_only
	# A question asked over a gameplay tab is dropped: nothing is done in the pause.
	if visible and _ui != null:
		_ui._presentation_layout.close_panel()
	present(Tab.SYSTEM)


## The shell resumed the world: the menu closes, unless the player left 系统 for another
## tab (show_tab()).
func end_pause_view() -> void:
	_paused_view = false
	_system_only = false
	if not _switching:
		_dismiss(true)


## Whether the shell's pause shows this window (its buttons are on 系统).
func in_pause_view() -> bool:
	return _paused_view


func is_presented() -> bool:
	return visible


func current_tab() -> int:
	return _current


func system_only() -> bool:
	return _system_only


func show_tab(tab: int) -> void:
	if tab < 0 or tab >= pages.size():
		return
	if _system_only:
		tab = Tab.SYSTEM
	var host: Node = _host()
	if visible and host != null:
		if _paused_view and tab != Tab.SYSTEM:
			# Leaving 系统: the world runs again under the other tabs.
			_switching = true
			var resumed: bool = host.request_resume()
			_switching = false
			if not resumed:
				_press_current()
				return
		elif not _paused_view and tab == Tab.SYSTEM:
			# 系统 pauses the world: the shell comes back through begin_pause_view().
			if not host.request_menu(Tab.SYSTEM):
				_press_current()
			return
	_current = tab
	if not visible:
		return
	_hide_pages()
	for index: int in tab_buttons.size():
		tab_buttons[index].set_pressed_no_signal(index == tab)
		tab_buttons[index].visible = not _system_only or index == Tab.SYSTEM
	fight_hint.visible = _system_only
	pages[tab].show()
	_page_scroll.scroll_vertical = 0
	if _ui != null:
		_ui.menu_tab_shown(tab)
	_layout.restyle_dynamic_content()
	_focus_page_later.call_deferred()
	tab_shown.emit(tab)


## Keys and pad start on the page's first control (a 背包 row, a 武学 button, a 百科
## section, 继续), or on its tab when the page has none (角色, 任务).
func focus_page() -> void:
	if not visible or _current < 0 or _current >= pages.size():
		return
	var page: Control = pages[_current]
	# A page may say where it starts (百科: the section or the entry it shows).
	var target: Control = page.call(&"focus_target") if page.has_method(&"focus_target") else FocusNav.first_focusable(page)
	if not FocusNav.give(target):
		FocusNav.give(tab_buttons[_current])


## After the page filled its rows; a question over the menu keeps the focus.
func _focus_page_later() -> void:
	if not visible or not root.is_inside_tree():
		return
	var focused: Control = root.get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree() and (pages[_current].is_ancestor_of(focused) or (_ui != null and _ui._presentation_layout.frame.is_ancestor_of(focused))):
		return
	focus_page()


## The tab buttons show the shown tab (a refused switch leaves the pressed one wrong).
func _press_current() -> void:
	for index: int in tab_buttons.size():
		tab_buttons[index].set_pressed_no_signal(index == _current)


## The next or previous tab, wrapping (Q / E).
func step_tab(direction: int) -> void:
	if _system_only:
		return
	show_tab(posmod(_current + direction, pages.size()))


## Refits the window after a page changed its rows.
func refresh_rows() -> void:
	_layout.restyle_dynamic_content()


func _hide_pages() -> void:
	for page: Control in pages:
		page.hide()
	if _ui != null:
		_ui.menu_pages_hidden()


func _host() -> Node:
	if not is_inside_tree():
		return null
	var host: Node = get_tree().get_first_node_in_group(HOST_GROUP)
	return host if host != null and host.has_method(&"request_menu") else null


## Q / E (LB / RB) switch tabs; a tab's key opens it, or closes the menu when it is
## showing; M (Start) closes it. A question over the menu takes its own keys.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo() or not event.is_pressed():
		return
	if _ui != null and _ui._presentation_layout.frame.visible:
		return
	if event.is_action_pressed(&"menu_open"):
		close()
	elif event.is_action_pressed(&"menu_tab_previous"):
		step_tab(-1)
	elif event.is_action_pressed(&"menu_tab_next"):
		step_tab(1)
	else:
		var tab: int = tab_for_event(event)
		if tab < 0:
			return
		if _system_only:
			pass # A fight's pause: only Esc / 继续 go back to it.
		elif tab == _current:
			close()
		else:
			show_tab(tab)
	get_viewport().set_input_as_handled()


## The tab whose key `event` presses, else -1.
static func tab_for_event(event: InputEvent) -> int:
	for tab: int in TAB_ACTIONS.size():
		if not TAB_ACTIONS[tab].is_empty() and event.is_action_pressed(TAB_ACTIONS[tab]):
			return tab
	return -1


func _tab_glyph(parent: Node, action: StringName) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.name = "TabGlyph"
	glyph.texture = InputGlyphTexture.new(action)
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glyph)
	return glyph


## Touch has no tab keys: the strip's glyphs go (and their room).
func _show_tab_glyphs() -> void:
	for glyph: TextureRect in tab_glyphs:
		glyph.visible = (glyph.texture as InputGlyphTexture).has_glyph()


func _placeholder(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)
	return label


func _window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.065, 0.075, 0.98)
	style.border_color = Color(1, 1, 1, 0.1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 14
	for side: String in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 16.0)
	return style
