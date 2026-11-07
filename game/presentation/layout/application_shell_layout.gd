class_name ApplicationShellLayout
extends Node

var _presenter: SafeAreaPresenter
var _dialogs: Array[ResponsivePanelLayout] = []
## The settings dialog is wide enough for its label/control pairs in two columns.
var _widths: Array[float] = [330.0, 460.0, 720.0, 580.0, 560.0, 520.0]
var _busy: Label
## The voxel animation over the busy note (owner, 2026-11-07: a wait shows it is working).
var _busy_loader: VoxelLoader
var _window_row: Control
var _platform_hint: Label
## Below this content height (the 界面缩放 at 150%: 480) the dialogs close up their margins
## and rows, so 设置 and the main menu fit without scrolling their title away.
const SHORT_HEIGHT: float = 600.0
const SHORT_MARGIN: int = 14
const SHORT_SEPARATION: int = 8
## Each dialog's authored spacing: [margin left, top, right, bottom, row separation].
var _spacing: Array[PackedInt32Array] = []


func _ready() -> void:
	var shell: Node = get_parent()
	# 界面重做: the shell's surfaces wear GameTheme (also those added later, the slot list),
	# and the focus arrow sits on top of them.
	var canvas: CanvasLayer = shell.get_node("%ShellCanvas") as CanvasLayer
	for child: Node in canvas.get_children():
		_dress(child)
	canvas.child_entered_tree.connect(_dress)
	canvas.add_child(FocusCursor.new(canvas))
	_window_row = shell.get_node("%WindowModeRow") as Control
	_platform_hint = Label.new()
	_platform_hint.name = "PlatformWindowModeHint"
	_platform_hint.text = "窗口模式由这个平台管理。"
	_platform_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_platform_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_window_row.get_parent().add_child(_platform_hint)
	_window_row.get_parent().move_child(_platform_hint, 2)
	_window_row.visibility_changed.connect(_update_platform_hint)
	_update_platform_hint()
	for path: String in [
		"ShellCanvas/MainMenuPanel/Center/Panel", "ShellCanvas/PausePanel/Center/Panel",
		"ShellCanvas/SettingsPanel/Center/Panel", "ShellCanvas/RecoveryPanel/Center/Panel",
		"ShellCanvas/ResultOverlay/ResultCenter/Panel",
		"ShellCanvas/NewGameSetupPanel/Center/Panel",
	]:
		var layout: ResponsivePanelLayout = ResponsivePanelLayout.new()
		add_child(layout)
		layout.initialize(shell.get_node(path) as PanelContainer)
		_dialogs.append(layout)
		_spacing.append(_authored_spacing(layout.content))
	# The title's menu column never scrolls (owner, 2026-11-07): it moves up to fit instead
	# (_menu_column); only a screen too short for it at all scrolls it, with no bar.
	_dialogs[0].scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialogs[0].content.minimum_size_changed.connect(_queue_reflow)
	_busy = shell.get_node("ShellCanvas/BusyOverlay/BusyCenter/BusyLabel") as Label
	_busy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_busy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_busy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var busy_overlay: Control = _busy.get_parent().get_parent() as Control
	_busy_loader = VoxelLoader.new()
	_busy_loader.size = _busy_loader.custom_minimum_size
	_busy.get_parent().add_child(_busy_loader)
	busy_overlay.visibility_changed.connect(func() -> void:
		if busy_overlay.visible:
			_busy_loader.restart())
	_presenter = SafeAreaPresenter.find_or_create(self)
	_presenter.metrics_changed.connect(_reflow)
	_reflow(_presenter.current_metrics())


static func _dress(node: Node) -> void:
	if node is Control and (node as Control).theme == null:
		(node as Control).theme = GameTheme.shared()


func _update_platform_hint() -> void:
	_platform_hint.visible = not _window_row.visible


var _reflow_queued: bool = false


func _queue_reflow() -> void:
	if _reflow_queued or _presenter == null:
		return
	_reflow_queued = true
	_reflow_later.call_deferred()


func _reflow_later() -> void:
	_reflow_queued = false
	_reflow(_presenter.current_metrics())


func _reflow(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	var short: bool = metrics.content_rect().size.y < SHORT_HEIGHT
	for index: int in _dialogs.size():
		_space(_dialogs[index].content, _spacing[index], short)
	var menu: ResponsivePanelLayout = _dialogs[0]
	var needed: float = menu.content.get_combined_minimum_size().y + menu.panel.get_theme_stylebox("panel").get_minimum_size().y
	var column: Rect2 = _menu_column(metrics, needed)
	# Scrolled only when even the highest column cannot hold it.
	var fits: bool = needed <= column.size.y
	menu.scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if fits else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	for index: int in _dialogs.size():
		_dialogs[index].apply(metrics, column if index == 0 else metrics.content_rect(), true, _widths[index])
	# The animation above the middle, the note under it: the note's box loses twice the
	# drop off its top, so its middle sits that much lower and it stays inside the area.
	var area: Rect2 = metrics.content_rect()
	var lift: float = minf(_busy_loader.size.y / 2.0 + 10.0, area.size.y / 4.0) if _busy_loader.has_cubes() else 0.0
	var note_y: float = area.get_center().y + lift
	_busy_loader.position = Vector2(area.get_center().x - _busy_loader.size.x / 2.0, note_y - 20.0 - _busy_loader.size.y).floor()
	_busy.position = area.position + Vector2(0.0, 2.0 * lift)
	_busy.size = area.size - Vector2(0.0, 2.0 * lift)


## Where the main menu's column starts (a share of the content area's height) when it fits
## there, and the highest it may go (just under the logo). The content area keeps its own
## margin from the bottom.
const MENU_TOP_SHARE: float = 0.4
const MENU_HIGHEST_SHARE: float = 0.30


## The main menu on the title (DECISIONS「标题画面」): a column at the lower left, leaving the
## logo above it and the 沙盘's place to its right; a phone keeps it in the middle. A short
## screen lifts it towards the logo, so all `needed` of it shows without scrolling.
static func _menu_column(metrics: SafeAreaMetrics, needed: float = 0.0) -> Rect2:
	var area: Rect2 = metrics.content_rect()
	if metrics.touch_sized():
		return area
	var top: float = floorf(clampf(area.size.y - needed, area.size.y * MENU_HIGHEST_SHARE, area.size.y * MENU_TOP_SHARE))
	return Rect2(area.position + Vector2(area.size.x * 0.06, top), Vector2(minf(340.0, area.size.x * 0.5), area.size.y - top))


static func _authored_spacing(content: Control) -> PackedInt32Array:
	var spacing := PackedInt32Array()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		spacing.append(content.get_theme_constant(side) if content is MarginContainer else 0)
	var rows: Control = _rows(content)
	spacing.append(rows.get_theme_constant("separation") if rows != null else 0)
	return spacing


static func _space(content: Control, authored: PackedInt32Array, short: bool) -> void:
	if content is MarginContainer:
		var sides: Array[String] = ["margin_left", "margin_top", "margin_right", "margin_bottom"]
		for side: int in sides.size():
			content.add_theme_constant_override(sides[side], mini(authored[side], SHORT_MARGIN) if short else authored[side])
	var rows: Control = _rows(content)
	if rows != null:
		rows.add_theme_constant_override("separation", mini(authored[4], SHORT_SEPARATION) if short else authored[4])


static func _rows(content: Control) -> VBoxContainer:
	return content.get_child(0) as VBoxContainer if content.get_child_count() > 0 else null
