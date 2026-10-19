class_name SharedGameplayLayout
extends Node

## One Session-owned surface and one dismissable frame. Business forms remain
## owned by their resident component and return there when this frame closes.
var ui: SharedGameplayUI
var overlay: Control
var bar: PanelContainer
## The card's header (DECISIONS「说话和交互」): the player's name and 菜单; under it 精气神,
## the conditions and the waits. What is near shows on the map (the prompt over the
## target, the interaction popup); the room's name and text at the top on coming in.
var menu_button: Button
## The selected thing's commands (SharedGameplayUI's inspect_button … bribe_button) and the
## nearest door or service's context_button, kept off the card.
var contexts: HFlowContainer
var context_button: Button
## The selected thing's name (SharedGameplayUI.selected_target_label), off the card too.
var target_section: VBoxContainer
## What the player waits for (SharedUiWaits): a line, a thin bar, 继续 where it can be hurried.
var waits: VBoxContainer
## The card's button size now (touch or not).
var button_size: Vector2 = Vector2(80, 38)
## The scene's messages at the bottom left (owner, 2026-10-06).
var toasts: MessageToasts
var barrier: Control
var frame: PanelContainer
var frame_title: Label
var mount: VBoxContainer
var holding: Control
var details: VBoxContainer
## The current zone's authored ES2 description, opened by Look.
var room: Label
## The message log (消息), shown on the menu's 任务 page. Its own box keeps the log's
## height: a RichTextLabel alone shows nothing once its minimum size is zeroed.
var messages: VBoxContainer
var close_button: Button
var _frame_layout: ResponsivePanelLayout
var _safe: SafeAreaPresenter
var _content: Control
var _return_parent: Node
## Where the focus goes back when the frame closes (the 背包 row, the card's button).
var _return_focus: WeakRef
var _valid: Callable
var _bar_rows: VBoxContainer
var _bar_scroll: ScrollContainer
var _bar_area: Rect2
## Where the frame and its barrier live while the menu does not cover them.
var _frame_home: Node
## The safe area and the frame's area there, as last laid out.
var _panel_metrics: SafeAreaMetrics
var _panel_area: Rect2


func build(owner_ui: SharedGameplayUI) -> void:
	ui = owner_ui
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The skin is pixel art (UiSkin): drawn without smoothing.
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.add_child(overlay)
	holding = Control.new()
	holding.name = "ClosedPanels"
	holding.hide()
	overlay.add_child(holding)
	bar = PanelContainer.new()
	bar.name = "ExplorationHUD"
	overlay.add_child(bar)
	# The status card (owner, 2026-10-06: a more modern top left): the name and the
	# place, 精/气/神 as bars, then the actions; a lacquer card in the skin (UiSkin).
	bar.add_theme_stylebox_override("panel", _card_style())
	bar.theme = card_theme()
	# Small screens scroll the HUD instead of letting it leave the safe area.
	_bar_scroll = ScrollContainer.new()
	_bar_scroll.name = "Rows"
	_bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bar_scroll.follow_focus = true
	bar.add_child(_bar_scroll)
	_bar_rows = VBoxContainer.new()
	_bar_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_rows.add_theme_constant_override("separation", 10)
	_bar_scroll.add_child(_bar_rows)
	# The card follows its rows at once (a target's buttons appear): no clipped button.
	_bar_rows.minimum_size_changed.connect(fit_bar)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	_bar_rows.add_child(header)
	ui.player_name = Label.new()
	ui.player_name.name = "PlayerName"
	ui.player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.player_name.clip_text = true
	ui.player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.player_name.add_theme_font_size_override("font_size", 19)
	ui.player_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ui.player_name.add_theme_color_override("font_color", NAME_COLOR)
	header.add_child(ui.player_name)
	menu_button = _button(header, "Menu", "菜单", ui.open_menu)
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Start / M opens it: the card takes no focus.
	menu_button.focus_mode = Control.FOCUS_NONE
	InputGlyphs.decorate(menu_button, &"menu_open")
	var vitals := HBoxContainer.new()
	vitals.name = "Vitals"
	vitals.add_theme_constant_override("separation", 14)
	_bar_rows.add_child(vitals)
	var essence: Array = _stat(vitals, "Essence", "精", ESSENCE_COLOR, 1.0)
	ui.player_essence = essence[0]
	ui.player_essence_text = essence[1]
	var vitality: Array = _stat(vitals, "Vitality", "气", VITALITY_COLOR, 1.5)
	ui.player_vitality = vitality[0]
	ui.player_vitality_value = vitality[1]
	var spirit: Array = _stat(vitals, "Spirit", "神", SPIRIT_COLOR, 1.0)
	ui.player_spirit = spirit[0]
	ui.player_spirit_text = spirit[1]
	# The conditions the player has (蛇毒), shown only when there are some.
	ui.player_vitality_text = _label(_bar_rows, "Resources")
	ui.player_vitality_text.add_theme_font_size_override("font_size", 13)
	ui.player_vitality_text.add_theme_color_override("font_color", CONDITION_COLOR)
	ui.player_vitality_text.hide()
	waits = VBoxContainer.new()
	waits.name = "Waits"
	waits.add_theme_constant_override("separation", 6)
	waits.hide()
	_bar_rows.add_child(waits)
	# Where the player is (card.refresh_exploration()), kept off the card.
	ui.world_title = Label.new()
	ui.world_title.name = "Location"
	ui.world_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	holding.add_child(ui.world_title)
	target_section = VBoxContainer.new()
	target_section.name = "TargetSection"
	target_section.add_theme_constant_override("separation", 8)
	holding.add_child(target_section)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_section.add_child(rule)
	var target_row := HBoxContainer.new()
	target_row.name = "TargetRow"
	target_row.add_theme_constant_override("separation", 8)
	target_section.add_child(target_row)
	var tag_chip := PanelContainer.new()
	tag_chip.name = "TargetTag"
	tag_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag_chip.add_theme_stylebox_override("panel", _chip_style(Color(ACCENT_COLOR, 0.2)))
	target_row.add_child(tag_chip)
	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "目标"
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", ACCENT_COLOR)
	tag_chip.add_child(tag)
	ui.selected_target_label = _label(target_row, "Target")
	ui.selected_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.selected_target_label.add_theme_color_override("font_color", NAME_COLOR)
	ui.selected_target_label.hide()
	target_section.hide()
	contexts = HFlowContainer.new()
	contexts.name = "Contexts"
	contexts.add_theme_constant_override("h_separation", 8)
	contexts.add_theme_constant_override("v_separation", 8)
	holding.add_child(contexts)
	context_button = _button(contexts, "Context", "交互", ui.open_current_context)
	context_button.theme_type_variation = &"AccentButton"
	ui.inspect_button = _button(contexts, "Inspect", "查看", Callable())
	ui.attack_button = _button(contexts, "Attack", "攻击", Callable())
	ui.spar_button = _button(contexts, "Spar", "切磋", Callable())
	ui.ask_button = _button(contexts, "Ask", "打听", Callable())
	ui.portal_button = _button(contexts, "Traverse", "通行", Callable())
	ui.open_loot_button = _button(contexts, "Loot", "拾取", Callable())
	ui.animate_button = _button(contexts, "Animate", AnimateSpell.WORLD_LABEL, Callable())
	ui.lifeheal_button = _button(contexts, "Lifeheal", ExertFunctions.LABELS[&"lifeheal"], Callable())
	ui.heart_sense_button = _button(contexts, "HeartSense", HeartSenseConjure.LABEL, Callable())
	ui.steal_button = _button(contexts, "Steal", "偷窃", Callable())
	ui.bribe_button = _button(contexts, "Bribe", "行贿", Callable())
	# Context controls appear only once the HUD knows what is here.
	contexts.hide()
	for button: Node in contexts.get_children():
		(button as Control).hide()
	barrier = Control.new()
	barrier.name = "PanelInputBarrier"
	barrier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barrier.mouse_filter = Control.MOUSE_FILTER_STOP
	barrier.hide()
	overlay.add_child(barrier)
	frame = PanelContainer.new()
	frame.name = "SharedPanel"
	frame.hide()
	overlay.add_child(frame)
	_style(frame)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	frame.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	frame_title = _label(heading, "Title")
	frame_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(heading, "Close", "关闭", close_panel)
	InputGlyphs.decorate(close_button, &"ui_cancel")
	mount = VBoxContainer.new()
	mount.name = "Content"
	# A panel of fixed size (the interaction popup) fills the frame's height.
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mount.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(mount)
	_frame_layout = ResponsivePanelLayout.new()
	add_child(_frame_layout)
	_frame_layout.initialize(frame)
	_frame_layout.blocks_touch_gameplay = true
	_frame_layout.dismiss_requested.connect(ui.dismiss_current_panel)
	frame.add_child(ExplorationPresentationBlocker.new())
	_frame_home = overlay
	details = VBoxContainer.new()
	holding.add_child(details)
	ui.target_vitality = ProgressBar.new()
	details.add_child(ui.target_vitality)
	ui.target_vitality_text = _label(details, "TargetResources")
	ui.inspection_text = RichTextLabel.new()
	ui.inspection_text.custom_minimum_size = Vector2(0, 180)
	details.add_child(ui.inspection_text)
	room = _label(holding, "RoomDescription")
	messages = VBoxContainer.new()
	messages.name = "Messages"
	holding.add_child(messages)
	ui.combat_log = RichTextLabel.new()
	ui.combat_log.custom_minimum_size = Vector2(0, 320)
	ui.combat_log.scroll_following = true
	ui.combat_log.add_to_group(PadSupport.SCROLL_GROUP)
	# Alert lines are coloured (SharedGameplayUI escapes the rest).
	ui.combat_log.bbcode_enabled = true
	ui.combat_log.add_theme_color_override("default_color", SharedGameplayUI.PLAIN_LOG_COLOR)
	# Shown on the menu's paper too (任务 › 消息记录): a lacquer ground keeps ES2's bright colours.
	ui.combat_log.add_theme_stylebox_override("normal", UiSkin.inset(false, 10.0))
	messages.add_child(ui.combat_log)
	ui.inventory_panel = load("res://scenes/ui/player_inventory_panel.tscn").instantiate() as PlayerInventoryPanel
	holding.add_child(ui.inventory_panel)
	ui.loot_panel = load("res://scenes/ui/oldpine_loot_panel.tscn").instantiate() as OldPineLootPanel
	holding.add_child(ui.loot_panel)
	ui.confirm_prompt = ConfirmPrompt.new()
	holding.add_child(ui.confirm_prompt)
	ui.drift_panel = DriftSensePanel.new()
	holding.add_child(ui.drift_panel)
	ui.steal_panel = StealPanel.new()
	holding.add_child(ui.steal_panel)
	ui.bribe_panel = BribePanel.new()
	holding.add_child(ui.bribe_panel)
	# Last, so they draw above the card and the frame (they take no input).
	toasts = MessageToasts.new()
	overlay.add_child(toasts)
	_attach()


func _enter_tree() -> void:
	if is_instance_valid(frame):
		_attach.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_safe) and _safe.metrics_changed.is_connected(_reflow):
		_safe.metrics_changed.disconnect(_reflow)
	_safe = null


func _attach() -> void:
	if not is_inside_tree():
		return
	_safe = SafeAreaPresenter.find_or_create(self)
	if not _safe.metrics_changed.is_connected(_reflow):
		_safe.metrics_changed.connect(_reflow)
	_reflow(_safe.current_metrics())


func _reflow(metrics: SafeAreaMetrics) -> void:
	var area: Rect2 = metrics.content_rect()
	_bar_area = area
	if metrics.touch_sized():
		# The card ends above the movement pad's corner; taller (waits), it scrolls.
		# Not below the name, the bars and the navigation row (a very short screen keeps the
		# whole height, as before).
		var above_pad: float = metrics.future_movement_rect().position.y - area.position.y - 8.0
		if above_pad >= BAR_MIN_ABOVE_PAD:
			_bar_area.size.y = minf(area.size.y, above_pad)
	bar.position = area.position
	bar.size = Vector2(minf(CARD_WIDTH, maxf(1, area.size.x - (80 if metrics.touch_sized() else 0))), 0)
	# Touch rows keep five 64 px buttons on one line at 480 px, with room for a scrollbar.
	var card: StyleBox = bar.get_theme_stylebox("panel")
	if card != null:
		card.content_margin_left = 10.0 if metrics.touch_sized() else 16.0
		card.content_margin_right = 10.0 if metrics.touch_sized() else 16.0
	# Touch-sized buttons stay 64 px square so five fit one row on 480 px.
	var gap: int = 4 if metrics.touch_sized() else 8
	button_size = Vector2(64, 64) if metrics.touch_sized() else Vector2(80, 38)
	menu_button.custom_minimum_size = Vector2(64, 64) if metrics.touch_sized() else Vector2(72, 32)
	contexts.add_theme_constant_override("h_separation", gap)
	contexts.add_theme_constant_override("v_separation", gap)
	for button: Node in contexts.get_children():
		(button as Control).custom_minimum_size = button_size
	# Touch screens keep the world visible: shorter toasts, the full text in Messages/Look,
	# right of the movement pad's corner.
	var toast_area: Rect2 = area
	if metrics.touch_sized():
		var pad: Rect2 = metrics.future_movement_rect()
		toast_area = Rect2(Vector2(pad.end.x + 8.0, area.position.y), Vector2(maxf(1.0, area.end.x - pad.end.x - 8.0), area.size.y))
	toasts.place(toast_area, minf(TOAST_WIDTH, maxf(1, toast_area.size.x - (72 if metrics.touch_sized() else 0))), 2 if metrics.touch_sized() else 3)
	fit_bar()
	var panel_area := area
	if metrics.touch_sized():
		panel_area.position.y += 72
		panel_area.size.y = maxf(1, panel_area.size.y - 72)
	_panel_metrics = metrics
	_panel_area = panel_area
	_apply_frame_width()


## The frame's place on the screen: a fixed share of it while it shows the interaction popup.
func _apply_frame_width() -> void:
	if _panel_metrics != null:
		var area: Vector2 = _panel_area.size
		_frame_layout.fixed_size = Vector2.ZERO if _host == null else Vector2(maxf(area.x * HOST_SHARE.x, HOST_MIN.x), maxf(area.y * HOST_SHARE.y, HOST_MIN.y))
		_frame_layout.apply(_panel_metrics, _panel_area, true, FRAME_WIDTH)


## Shrinks the HUD to its content, but never past the safe content area.
func fit_bar() -> void:
	if _bar_area.size.y <= 0:
		return
	# The card's own top and bottom margins.
	var margins: float = bar.get_theme_stylebox("panel").get_minimum_size().y
	var wanted: float = _bar_rows.get_combined_minimum_size().y
	_bar_scroll.custom_minimum_size.y = minf(wanted, maxf(1, _bar_area.size.y - margins))
	bar.size.y = 0


## The interaction popup while the frame shows it (DECISIONS「说话和交互」): whatever else
## opens then (打听, a shop, 偷窃, a question) is its page, in its right column, and closing
## that page goes back to its 查看.
var _host: InteractionPanel
## The page the popup shows (_content then), where it goes back to, and while it stays.
var _page: Control
var _page_parent: Node
var _page_valid: Callable
## The frame's own content (the popup while it has a page).
var _frame_content: Control
## The popup's frame is wider: its two columns hold what a panel alone held.
const FRAME_WIDTH: float = 660.0
## The popup keeps one size, a share of the screen, whatever its page holds (owner,
## 2026-10-17); never under HOST_MIN, so a small or scaled screen is nearly all popup.
const HOST_SHARE: Vector2 = Vector2(0.75, 0.7)
const HOST_MIN: Vector2 = Vector2(820, 440)


## The popup's page now, or null (its 查看, or no popup).
func page() -> Control:
	return _page


## The frame shows the interaction popup (its 查看 or a page).
func hosting() -> bool:
	return frame.visible and _host != null


func open_panel(title: String, content: Control, valid: Callable = Callable()) -> void:
	if _content == content:
		return
	if hosting() and content != _host:
		# Its 查看 (the details live in it) goes back there; anything else is its page.
		if _host.is_ancestor_of(content) and not _host.page_mount().is_ancestor_of(content):
			close_page()
		else:
			_open_page(title, content, valid)
		return
	# The focus goes back where it was when this panel closes (a panel replacing another
	# keeps the first one's place).
	var back: WeakRef = _return_focus if frame.visible else _focus_outside_frame()
	# Only the menu's own questions show over it; anything else replaces it.
	if ui.menu != null and ui.menu.is_presented() and not ui.is_menu_dialog(content):
		ui.menu.close()
	close_frame(false)
	_return_focus = back
	_valid = valid
	if valid.is_valid() and not valid.call():
		_valid = Callable()
		return
	_content = content
	_frame_content = content
	_host = content as InteractionPanel if content == ui.interaction_panel else null
	_return_parent = content.get_parent()
	content.reparent(mount, false)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2.ZERO
	content.show()
	frame_title.text = title
	close_button.text = "关闭"
	frame.show()
	barrier.show()
	if _host != null:
		_host.show_look(true)
		_apply_frame_width()
	ui.panel_opened()
	ui.quarantine_movement()
	_frame_layout.restyle_dynamic_content()
	focus_content()


## `content` becomes the popup's page (its right column), replacing the page before.
func _open_page(title: String, content: Control, valid: Callable) -> void:
	if valid.is_valid() and not valid.call():
		return
	_close_page()
	_page = content
	_page_valid = valid
	_page_parent = content.get_parent()
	_content = content
	content.reparent(_host.page_mount(), false)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2.ZERO
	content.show()
	_host.show_page(title)
	# 关闭 (B) goes back to 查看 first.
	close_button.text = "返回"
	ui.panel_opened()
	_frame_layout.restyle_dynamic_content()
	focus_content()


## Keys and pad start on the panel's first button (its own focus_default() when it has
## one: a question's 取消), else on 关闭; never inside a text box (typing would start, and
## take Esc).
func focus_content() -> void:
	if not frame.visible or not is_instance_valid(_content):
		return
	if _content.has_method(&"focus_default"):
		_content.call(&"focus_default")
	elif not FocusNav.give(FocusNav.first_focusable(_content, true)):
		close_button.grab_focus()


## Closes what shows on top: the popup's page (back to its 查看), else the frame.
## `restore`: the focus goes back where it was before.
func close_panel(restore: bool = true) -> void:
	if _page != null and hosting():
		close_page(restore)
	else:
		close_frame(restore)


## The popup's page closes: its 查看 shows again, the focus on the row that opened the page.
func close_page(restore: bool = true) -> void:
	if _page == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var lost: bool = focused != null and _page.is_ancestor_of(focused)
	if lost:
		focused.release_focus()
	var row: String = _host.current()
	_close_page()
	close_button.text = "关闭"
	_host.show_look()
	ui.panel_opened()
	_frame_layout.restyle_dynamic_content()
	if restore or lost:
		_host.focus_row(row)


func _close_page() -> void:
	var content: Control = _page
	var destination: Node = _page_parent
	_page = null
	_page_parent = null
	_page_valid = Callable()
	_content = _frame_content
	if is_instance_valid(content):
		content.hide()
		if is_instance_valid(destination):
			content.reparent(destination, false)


## The frame closes with whatever it shows (the popup and its page).
## `restore`: the focus goes back where it was before the panel opened.
func close_frame(restore: bool = true) -> void:
	if not is_instance_valid(frame) or not frame.visible:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and frame.is_ancestor_of(focused):
		focused.release_focus()
	_close_page()
	var back: Control = FocusNav.held(_return_focus)
	_return_focus = null
	var content: Control = _content
	var destination: Node = _return_parent
	var hosted: bool = _host != null
	_content = null
	_frame_content = null
	_host = null
	_return_parent = null
	_valid = Callable()
	frame.hide()
	barrier.hide()
	close_button.text = "关闭"
	ui.refresh_toasts()
	if is_instance_valid(content):
		content.hide()
		if is_instance_valid(destination):
			content.reparent(destination, false)
	if hosted:
		_apply_frame_width()
	ui.quarantine_movement()
	if restore and not FocusNav.give(back):
		ui.refocus()


func _focus_outside_frame() -> WeakRef:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return null if focused == null or frame.is_ancestor_of(focused) else weakref(focused)


## The menu covers the HUD: its questions (请确认, 游识) show above it, in its layer.
func lift_frame(over: Control) -> void:
	if barrier.get_parent() == over:
		return
	barrier.reparent(over, false)
	frame.reparent(over, false)
	_frame_layout.raised = true


func lower_frame() -> void:
	if barrier.get_parent() == _frame_home:
		return
	barrier.reparent(_frame_home, false)
	frame.reparent(_frame_home, false)
	# Under the toasts again, as built.
	_frame_home.move_child(barrier, toasts.get_index())
	_frame_home.move_child(frame, toasts.get_index())
	_frame_layout.raised = false


## A page that no longer holds goes back to 查看; a frame whose content no longer holds closes.
func validate_open_panel() -> void:
	if not frame.visible:
		return
	if _page != null and (not is_instance_valid(_page) or not _page.visible or (_page_valid.is_valid() and not _page_valid.call())):
		close_page()
	if not is_instance_valid(_frame_content) or not _frame_content.visible or (_valid.is_valid() and not _valid.call()):
		close_frame()


func refresh_rows() -> void:
	_frame_layout.restyle_dynamic_content()


## One row of `waits`: [line, bar, 继续 button] (the button hidden until it can hurry).
func wait_row(hurry: Callable) -> Array:
	var row := VBoxContainer.new()
	row.name = "Wait"
	row.add_theme_constant_override("separation", 3)
	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var text := _label(line, "Text")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", CONDITION_COLOR)
	var button: Button = _button(line, "Hurry", "继续", hurry)
	button.custom_minimum_size = Vector2(64, 30)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	InputGlyphs.decorate(button, &"ui_accept")
	button.hide()
	var progress := ProgressBar.new()
	progress.name = "Bar"
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	progress.max_value = 1.0
	progress.step = 0.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.09)
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CONDITION_COLOR
	fill.set_corner_radius_all(2)
	progress.add_theme_stylebox_override("background", track)
	progress.add_theme_stylebox_override("fill", fill)
	row.add_child(progress)
	waits.add_child(row)
	return [text, progress, button]


## A list item's box on the menu's paper: a sunken section.
static func item_style() -> StyleBox:
	var style: StyleBoxTexture = UiSkin.inset(true)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 9.0
	return style


## The status card's look.
const CARD_WIDTH: float = 480.0
## The least height the card keeps above the movement pad (name, bars, navigation row).
const BAR_MIN_ABOVE_PAD: float = 200.0
const TOAST_WIDTH: float = 440.0
## Text on the lacquer over the map (UiSkin); paper pages use the theme's label variations.
const NAME_COLOR: Color = UiSkin.TEXT_NAME
const MUTED_COLOR: Color = UiSkin.TEXT_MUTED
const ACCENT_COLOR: Color = UiSkin.TEXT_ACCENT
const CONDITION_COLOR: Color = Color(0.95, 0.68, 0.42)
const ESSENCE_COLOR: Color = Color(0.86, 0.72, 0.34)
const VITALITY_COLOR: Color = Color(0.86, 0.38, 0.33)
const SPIRIT_COLOR: Color = Color(0.42, 0.64, 0.92)


## One of 精/气/神: its name and number over a thin bar. Returns [bar, number].
func _stat(parent: Node, node_name: String, caption: String, color: Color, stretch: float) -> Array:
	var column := VBoxContainer.new()
	column.name = node_name
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = stretch
	column.add_theme_constant_override("separation", 3)
	parent.add_child(column)
	var line := HBoxContainer.new()
	line.name = "Line"
	column.add_child(line)
	var name_label := Label.new()
	name_label.name = "Caption"
	name_label.text = caption
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", color.lightened(0.25))
	line.add_child(name_label)
	var value := Label.new()
	value.name = "Value"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.clip_text = true
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", NAME_COLOR)
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.add_child(value)
	var bar_control := ProgressBar.new()
	bar_control.name = "Bar"
	bar_control.show_percentage = false
	bar_control.custom_minimum_size.y = 6
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.09)
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar_control.add_theme_stylebox_override("background", track)
	bar_control.add_theme_stylebox_override("fill", fill)
	column.add_child(bar_control)
	return [bar_control, value]


func _card_style() -> StyleBox:
	return UiSkin.panel(false, 16.0)


func _chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 3.0
	return style


## The card's lacquer theme with its smaller text: paper plaques, AccentButton for the place's
## own action (UiSkin).
static func card_theme() -> Theme:
	return UiSkin.theme(false, 15)


## The shared frame (the interaction popup, the log, loot): lacquer, so ES2's colours read.
func _style(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", UiSkin.panel(false, 16.0))


func _label(parent: Node, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(80, 40)
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	return button
