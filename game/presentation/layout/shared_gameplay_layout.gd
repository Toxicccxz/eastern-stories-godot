class_name SharedGameplayLayout
extends Node

## One Session-owned surface and one dismissable frame. Business forms remain
## owned by their resident component and return there when this frame closes.
var ui: SharedGameplayUI
var overlay: Control
var bar: PanelContainer
## The card's header: the name, the place (a click is 观察) and 菜单.
var place_chip: PanelContainer
var menu_button: Button
## The selected thing's commands (SharedGameplayUI's inspect_button … bribe_button) and the
## nearest door or service's context_button, kept off the card: the card shows `nearby`.
var contexts: HFlowContainer
var context_button: Button
## The selected thing's name (SharedGameplayUI.selected_target_label), off the card too.
var target_section: VBoxContainer
## One group per thing in reach (SharedUiNearby): its name, then its buttons.
var nearby: VBoxContainer
## What the keys or pad do here ([A] 开门 [Y] 选择附近 [X] 观察); none on touch.
var hints: InputHintRow
## The card's button size now (touch or not), for the groups' buttons too.
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


func build(owner_ui: SharedGameplayUI) -> void:
	ui = owner_ui
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	holding = Control.new()
	holding.name = "ClosedPanels"
	holding.hide()
	overlay.add_child(holding)
	bar = PanelContainer.new()
	bar.name = "ExplorationHUD"
	overlay.add_child(bar)
	# The status card (owner, 2026-10-06: a more modern top left): the name and the
	# place, 精/气/神 as bars, then the actions as flat rounded buttons.
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
	var place := PanelContainer.new()
	place.name = "PlaceChip"
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place.add_theme_stylebox_override("panel", _chip_style(Color(1, 1, 1, 0.07)))
	# A click on the place is 观察 (the room's text), as the 观察 button was.
	place.mouse_filter = Control.MOUSE_FILTER_STOP
	place.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	place.gui_input.connect(_on_place_input)
	place.tooltip_text = "观察"
	header.add_child(place)
	place_chip = place
	ui.world_title = Label.new()
	ui.world_title.name = "Location"
	ui.world_title.add_theme_font_size_override("font_size", 13)
	# Already in the shown language (tr()).
	ui.world_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ui.world_title.add_theme_color_override("font_color", MUTED_COLOR)
	place.add_child(ui.world_title)
	menu_button = _button(header, "Menu", "菜单", ui.open_menu)
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Start / M opens it; the card's buttons take the focus only while the player moves
	# through them with keys or a pad (SharedGameplayUI.enter_card_nav()).
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
	nearby = VBoxContainer.new()
	nearby.name = "Nearby"
	nearby.add_theme_constant_override("separation", 8)
	nearby.hide()
	_bar_rows.add_child(nearby)
	hints = InputHintRow.new()
	_bar_rows.add_child(hints)
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
		# The card ends above the movement pad's corner; taller (nearby items), it scrolls.
		# Not below the name, the bars and the navigation row (a very short screen keeps the
		# whole height, as before).
		var above_pad: float = metrics.future_movement_rect().position.y - area.position.y - 8.0
		if above_pad >= BAR_MIN_ABOVE_PAD:
			_bar_area.size.y = minf(area.size.y, above_pad)
	bar.position = area.position
	bar.size = Vector2(minf(CARD_WIDTH, maxf(1, area.size.x - (80 if metrics.touch_sized() else 0))), 0)
	# Touch rows keep five 64 px buttons on one line at 480 px, with room for a scrollbar.
	var card: StyleBoxFlat = bar.get_theme_stylebox("panel") as StyleBoxFlat
	if card != null:
		card.content_margin_left = 10.0 if metrics.touch_sized() else 16.0
		card.content_margin_right = 10.0 if metrics.touch_sized() else 16.0
	# Touch-sized buttons stay 64 px square so five fit one row on 480 px.
	var gap: int = 4 if metrics.touch_sized() else 8
	button_size = Vector2(64, 64) if metrics.touch_sized() else Vector2(80, 38)
	menu_button.custom_minimum_size = Vector2(64, 64) if metrics.touch_sized() else Vector2(72, 32)
	var flows: Array[Node] = [contexts]
	for item: Node in nearby.get_children():
		flows.append(item.get_node("Item/Actions"))
	for flow: Node in flows:
		(flow as Control).add_theme_constant_override("h_separation", gap)
		(flow as Control).add_theme_constant_override("v_separation", gap)
	for button: Node in contexts.get_children():
		(button as Control).custom_minimum_size = button_size
	for item: Node in nearby.get_children():
		for button: Node in item.get_node("Item/Actions").get_children():
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
	_frame_layout.apply(metrics, panel_area, true, 660)


## Shrinks the HUD to its content, but never past the safe content area.
func fit_bar() -> void:
	if _bar_area.size.y <= 0:
		return
	# The card's own top and bottom margins.
	var margins: float = bar.get_theme_stylebox("panel").get_minimum_size().y
	var wanted: float = _bar_rows.get_combined_minimum_size().y
	_bar_scroll.custom_minimum_size.y = minf(wanted, maxf(1, _bar_area.size.y - margins))
	bar.size.y = 0


func open_panel(title: String, content: Control, valid: Callable = Callable()) -> void:
	if _content == content:
		return
	# The focus goes back where it was when this panel closes (a panel replacing another
	# keeps the first one's place).
	var back: WeakRef = _return_focus if frame.visible else _focus_outside_frame()
	# Only the menu's own questions show over it; anything else replaces it.
	if ui.menu != null and ui.menu.is_presented() and not ui.is_menu_dialog(content):
		ui.menu.close()
	close_panel(false)
	_return_focus = back
	_valid = valid
	if valid.is_valid() and not valid.call():
		_valid = Callable()
		return
	_content = content
	_return_parent = content.get_parent()
	content.reparent(mount, false)
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2.ZERO
	content.show()
	frame_title.text = title
	frame.show()
	barrier.show()
	ui.panel_opened()
	ui.quarantine_movement()
	_frame_layout.restyle_dynamic_content()
	focus_content()


## Keys and pad start on the panel's first control (its own focus_default() when it has
## one: a question's 取消), else on 关闭.
func focus_content() -> void:
	if not frame.visible or not is_instance_valid(_content):
		return
	if _content.has_method(&"focus_default"):
		_content.call(&"focus_default")
	elif not FocusNav.give(FocusNav.first_focusable(_content)):
		close_button.grab_focus()


## `restore`: the focus goes back where it was before the panel opened.
func close_panel(restore: bool = true) -> void:
	if not is_instance_valid(frame) or not frame.visible:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and frame.is_ancestor_of(focused):
		focused.release_focus()
	var back: Control = FocusNav.held(_return_focus)
	_return_focus = null
	var content: Control = _content
	var destination: Node = _return_parent
	_content = null
	_return_parent = null
	_valid = Callable()
	frame.hide()
	barrier.hide()
	ui.refresh_toasts()
	if is_instance_valid(content):
		content.hide()
		if is_instance_valid(destination):
			content.reparent(destination, false)
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


func _on_place_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		place_chip.accept_event()
		ui.open_look()


func validate_open_panel() -> void:
	if frame.visible and (not is_instance_valid(_content) or not _content.visible or (_valid.is_valid() and not _valid.call())):
		close_panel()


func refresh_rows() -> void:
	_frame_layout.restyle_dynamic_content()


## One thing's item in the card's list (owner, 2026-10-11): a box with its name on top
## and (nearby_button()) its own buttons below, wrapping.
func nearby_row(shown_name: String) -> PanelContainer:
	var item := PanelContainer.new()
	item.name = "Group"
	item.add_theme_stylebox_override("panel", item_style())
	var rows := VBoxContainer.new()
	rows.name = "Item"
	rows.add_theme_constant_override("separation", 6)
	item.add_child(rows)
	var label := Label.new()
	label.name = "Name"
	label.text = shown_name
	# Already in the shown language (tr()).
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	rows.add_child(label)
	var actions := HFlowContainer.new()
	actions.name = "Actions"
	var gap: int = 8 if button_size.y < 64 else 4
	actions.add_theme_constant_override("h_separation", gap)
	actions.add_theme_constant_override("v_separation", gap)
	rows.add_child(actions)
	return item


## A button in an item made by nearby_row().
func nearby_button(item: Control, text: String, action: Callable) -> Button:
	var button: Button = _button(item.get_node("Item/Actions"), "Action", text, action)
	button.custom_minimum_size = button_size
	button.focus_mode = Control.FOCUS_ALL if ui.card_nav_active() else Control.FOCUS_NONE
	return button


## A list item's box: a little lighter than the card, rounded.
static func item_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = Color(1, 1, 1, 0.07)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
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
const NAME_COLOR: Color = Color(0.96, 0.95, 0.9)
const MUTED_COLOR: Color = Color(0.74, 0.78, 0.72)
const ACCENT_COLOR: Color = Color(0.88, 0.74, 0.44)
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


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.07, 0.86)
	style.border_color = Color(1, 1, 1, 0.09)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style


func _chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 3.0
	return style


## Flat rounded buttons for the card; AccentButton for the place's own action.
static func card_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var states: Dictionary[String, Color] = {
		"normal": Color(1, 1, 1, 0.07), "hover": Color(1, 1, 1, 0.14), "pressed": Color(ACCENT_COLOR, 0.32),
		"disabled": Color(1, 1, 1, 0.03), "focus": Color(0, 0, 0, 0),
	}
	for state: String in states:
		theme.set_stylebox(state, "Button", _button_style(states[state], state == "focus"))
	theme.set_color("font_color", "Button", NAME_COLOR)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	theme.set_type_variation(&"AccentButton", &"Button")
	var accents: Dictionary[String, Color] = {
		"normal": Color(ACCENT_COLOR, 0.26), "hover": Color(ACCENT_COLOR, 0.38), "pressed": Color(ACCENT_COLOR, 0.5),
	}
	for state: String in accents:
		theme.set_stylebox(state, &"AccentButton", _button_style(accents[state], false))
	theme.set_color("font_color", &"AccentButton", Color(1.0, 0.93, 0.78))
	return theme


static func _button_style(color: Color, focus: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	if focus:
		# Keyboard and pad focus: a clear ring, drawn over the button's own state.
		style.draw_center = false
		style.border_color = ACCENT_COLOR
		style.set_border_width_all(2)
		style.expand_margin_left = 2.0
		style.expand_margin_right = 2.0
		style.expand_margin_top = 2.0
		style.expand_margin_bottom = 2.0
	return style


func _style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.085, 0.97)
	style.border_color = Color(0.39, 0.43, 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	for side: String in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 12.0)
	panel.add_theme_stylebox_override("panel", style)


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
