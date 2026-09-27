class_name SharedGameplayLayout
extends Node

## One Session-owned surface and one dismissable frame. Business forms remain
## owned by their resident component and return there when this frame closes.
var ui: SharedGameplayUI
var overlay: Control
var bar: PanelContainer
var navigation: HFlowContainer
var contexts: HFlowContainer
var context_button: Button
var recent: Label
var barrier: Control
var frame: PanelContainer
var frame_title: Label
var mount: VBoxContainer
var holding: Control
var details: VBoxContainer
var character: Label
var character_button: Button
var close_button: Button
var _frame_layout: ResponsivePanelLayout
var _safe: SafeAreaPresenter
var _content: Control
var _return_parent: Node
var _valid: Callable
var _bar_rows: VBoxContainer


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
	_style(bar)
	_bar_rows = VBoxContainer.new()
	bar.add_child(_bar_rows)
	ui.world_title = _label(_bar_rows, "Location")
	ui.player_vitality = ProgressBar.new()
	ui.player_vitality.custom_minimum_size.y = 6
	ui.player_vitality.show_percentage = false
	_bar_rows.add_child(ui.player_vitality)
	ui.player_vitality_text = _label(_bar_rows, "Resources")
	navigation = HFlowContainer.new()
	navigation.add_theme_constant_override("h_separation", 8)
	navigation.add_theme_constant_override("v_separation", 8)
	_bar_rows.add_child(navigation)
	character_button = _button(navigation, "Character", "角色", ui.open_character)
	ui.inventory_button = _button(navigation, "Inventory", "背包", Callable())
	_button(navigation, "Supplies", "补给", ui.open_supplies)
	_button(navigation, "Messages", "消息", ui.open_messages)
	contexts = HFlowContainer.new()
	contexts.add_theme_constant_override("h_separation", 8)
	_bar_rows.add_child(contexts)
	context_button = _button(contexts, "Context", "交互", ui.open_current_context)
	ui.inspect_button = _button(contexts, "Inspect", "查看", Callable())
	ui.attack_button = _button(contexts, "Attack", "攻击", Callable())
	ui.portal_button = _button(contexts, "Traverse", "通行", Callable())
	ui.open_loot_button = _button(contexts, "Loot", "拾取", Callable())
	ui.selected_target_label = _label(_bar_rows, "Target")
	recent = _label(_bar_rows, "RecentMessage")
	recent.max_lines_visible = 2
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
	mount = VBoxContainer.new()
	mount.name = "Content"
	rows.add_child(mount)
	_frame_layout = ResponsivePanelLayout.new()
	add_child(_frame_layout)
	_frame_layout.initialize(frame)
	_frame_layout.blocks_touch_gameplay = true
	_frame_layout.dismiss_requested.connect(ui.dismiss_current_panel)
	frame.add_child(ExplorationPresentationBlocker.new())
	details = VBoxContainer.new()
	holding.add_child(details)
	ui.target_vitality = ProgressBar.new()
	details.add_child(ui.target_vitality)
	ui.target_vitality_text = _label(details, "TargetResources")
	ui.inspection_text = RichTextLabel.new()
	ui.inspection_text.custom_minimum_size = Vector2(0, 180)
	details.add_child(ui.inspection_text)
	character = _label(holding, "CharacterDetails")
	ui.combat_log = RichTextLabel.new()
	ui.combat_log.custom_minimum_size = Vector2(0, 320)
	holding.add_child(ui.combat_log)
	ui.inventory_panel = load("res://scenes/ui/player_inventory_panel.tscn").instantiate() as PlayerInventoryPanel
	holding.add_child(ui.inventory_panel)
	ui.loot_panel = load("res://scenes/ui/oldpine_loot_panel.tscn").instantiate() as OldPineLootPanel
	holding.add_child(ui.loot_panel)
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
	bar.position = area.position
	bar.size = Vector2(minf(560, maxf(1, area.size.x - (80 if metrics.touch_sized() else 0))), 0)
	for button: Node in navigation.get_children() + contexts.get_children():
		(button as Control).custom_minimum_size = Vector2(80, 64 if metrics.touch_sized() else 40)
	var panel_area := area
	if metrics.touch_sized():
		panel_area.position.y += 72
		panel_area.size.y = maxf(1, panel_area.size.y - 72)
	_frame_layout.apply(metrics, panel_area, true, 660)


func open_panel(title: String, content: Control, valid: Callable = Callable()) -> void:
	if _content == content:
		return
	close_panel()
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
	ui.quarantine_movement()
	_frame_layout.restyle_dynamic_content()
	close_button.grab_focus()


func close_panel() -> void:
	if not is_instance_valid(frame) or not frame.visible:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and frame.is_ancestor_of(focused):
		focused.release_focus()
	var content: Control = _content
	var destination: Node = _return_parent
	_content = null
	_return_parent = null
	_valid = Callable()
	frame.hide()
	barrier.hide()
	if is_instance_valid(content):
		content.hide()
		if is_instance_valid(destination):
			content.reparent(destination, false)
	ui.quarantine_movement()


func validate_open_panel() -> void:
	if frame.visible and (not is_instance_valid(_content) or not _content.visible or (_valid.is_valid() and not _valid.call())):
		close_panel()


func refresh_rows() -> void:
	_frame_layout.restyle_dynamic_content()


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
