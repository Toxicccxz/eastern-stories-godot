class_name OldPineHudLayout
extends Node

var _presenter: SafeAreaPresenter
var _overlay: Control
var _info: ResponsivePanelLayout
var _actions: ResponsivePanelLayout
var _details: ResponsivePanelLayout
var _inventory: ResponsivePanelLayout
var _loot: ResponsivePanelLayout
var _grid: GridContainer
var _columns: HBoxContainer
var _detail_button: Button
var _detail_close: Button
var _compact: bool = false
var _details_open: bool = false


func _ready() -> void:
	var hud: Node = get_parent()
	_overlay = hud.get_node("Overlay") as Control
	var status: PanelContainer = _overlay.get_node("StatusPanel") as PanelContainer
	var box: VBoxContainer = status.get_node("Margin/VBox") as VBoxContainer
	var old_actions: Node = box.get_node("Actions")
	var action_panel: PanelContainer = _new_panel("ActionPanel")
	_grid = GridContainer.new()
	_grid.name = "Actions"
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	action_panel.get_node("Margin").add_child(_grid)
	for button: Node in old_actions.get_children():
		button.reparent(_grid, false)
		(button as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	old_actions.queue_free()
	_detail_button = Button.new()
	_detail_button.name = "DetailsButton"
	_detail_button.text = "Details"
	_detail_button.pressed.connect(_toggle_details)
	_grid.add_child(_detail_button)
	var detail_panel: PanelContainer = _new_panel("DetailPanel")
	_overlay.move_child(detail_panel, 2)
	var detail_box: VBoxContainer = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	detail_panel.get_node("Margin").add_child(detail_box)
	for child_name: String in ["InspectionText", "CombatLogTitle", "CombatLog"]:
		box.get_node(child_name).reparent(detail_box, false)
	_detail_close = Button.new()
	_detail_close.text = "Close details"
	_detail_close.pressed.connect(_toggle_details)
	detail_box.add_child(_detail_close)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 8)
	box.add_child(_columns)
	for names: PackedStringArray in [
		PackedStringArray(["PlayerTitle", "PlayerVitality", "PlayerVitalityText"]),
		PackedStringArray(["SelectedTargetLabel", "TargetVitality", "TargetVitalityText"]),
	]:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_columns.add_child(column)
		for child_name: String in names:
			box.get_node(child_name).reparent(column, false)
	box.get_node("TargetSeparator").queue_free()
	_info = _wrap(status)
	_actions = _wrap(action_panel)
	_details = _wrap(detail_panel)
	_inventory = _wrap(_overlay.get_node("PlayerInventoryPanel") as PanelContainer)
	_loot = _wrap(_overlay.get_node("LootPanel") as PanelContainer)
	# List/details are bounded by the outer scroll too, including below-qualified sizes.
	for panel: ResponsivePanelLayout in [_inventory, _loot]:
		var nested: ScrollContainer = panel.content.get_node("VBox/Scroll") as ScrollContainer
		nested.follow_focus = true
		nested.custom_minimum_size = Vector2(0, 120)
	_presenter = SafeAreaPresenter.find_or_create(self)
	_presenter.metrics_changed.connect(_reflow)
	_reflow(_presenter.current_metrics())


func _new_panel(panel_name: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = panel_name
	_overlay.add_child(panel)
	# Existing item panels remain above the information/actions in drawing and picking order.
	_overlay.move_child(panel, 1)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	return panel


func _wrap(panel: PanelContainer) -> ResponsivePanelLayout:
	# Modal item information must visually occlude the HUD/world underneath it.
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.09, 0.085, 1.0)
	panel.add_theme_stylebox_override("panel", background)
	var layout: ResponsivePanelLayout = ResponsivePanelLayout.new()
	add_child(layout)
	layout.initialize(panel)
	return layout


func _reflow(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	_compact = metrics.is_compact()
	var area: Rect2 = metrics.content_rect()
	_grid.columns = 2 if _compact else 5
	_detail_button.visible = _compact
	_detail_close.visible = _compact
	_details.panel.visible = not _compact or _details_open
	var column_width: float = 640.0 if metrics.touch_sized() else 514.0
	var info_width: float = area.size.x - 80.0 if _compact else column_width
	var info_height: float = 144.0 if metrics.touch_sized() else 128.0
	info_width = maxf(1.0, minf(info_width, area.size.x))
	info_height = minf(info_height, area.size.y * 0.4)
	_info.apply(metrics, Rect2(area.position, Vector2(info_width, info_height)))
	for column: Node in _columns.get_children():
		(column as Control).custom_minimum_size.x = maxf(0.0, (info_width - 40.0) / 2.0)
	var below: float = area.position.y + info_height + 8.0
	if _compact and metrics.is_qualified():
		_actions.apply(metrics, Rect2(Vector2(area.end.x - 272.0, below), Vector2(272.0, area.end.y - below)))
		_details.apply(metrics, Rect2(Vector2(area.position.x + 208.0, below), Vector2(area.size.x - 488.0, area.end.y - below)))
	elif _compact:
		# Below qualification, actions stack/scroll in available space; no undersized buttons.
		_actions.apply(metrics, Rect2(Vector2(area.position.x, below), Vector2(area.size.x, maxf(1.0, area.end.y - below))))
		_details.apply(metrics, area)
	else:
		var action_height: float = 88.0 if metrics.touch_sized() else 56.0
		_actions.apply(metrics, Rect2(Vector2(area.position.x, below), Vector2(column_width, action_height)))
		_details.apply(metrics, Rect2(Vector2(area.position.x, below + action_height + 8.0), Vector2(column_width, maxf(1.0, area.end.y - below - action_height - 8.0))))
	for layout: ResponsivePanelLayout in [_inventory, _loot]:
		if _compact:
			layout.apply(metrics, area, true, minf(640.0, area.size.x))
		else:
			var width: float = 440.0 if layout == _inventory else 360.0
			var height: float = minf(area.size.y, 520.0 if layout == _inventory else 300.0)
			layout.apply(metrics, Rect2(Vector2(area.end.x - width, area.position.y), Vector2(width, height)))
	_inventory.restyle_dynamic_content()
	_loot.restyle_dynamic_content()


func refresh_rows() -> void:
	if _inventory != null:
		_inventory.restyle_dynamic_content()
		_loot.restyle_dynamic_content()


func reveal_details() -> void:
	_details_open = true
	if _details != null:
		_details.panel.visible = true


func _toggle_details() -> void:
	_details_open = not _details_open
	_details.panel.visible = not _compact or _details_open
