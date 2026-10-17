class_name ApplicationShellLayout
extends Node

var _presenter: SafeAreaPresenter
var _dialogs: Array[ResponsivePanelLayout] = []
var _widths: Array[float] = [520.0, 460.0, 520.0, 580.0, 560.0, 520.0]
var _busy: Label
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
	_busy = shell.get_node("ShellCanvas/BusyOverlay/BusyCenter/BusyLabel") as Label
	_busy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_busy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_busy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_presenter = SafeAreaPresenter.find_or_create(self)
	_presenter.metrics_changed.connect(_reflow)
	_reflow(_presenter.current_metrics())


func _update_platform_hint() -> void:
	_platform_hint.visible = not _window_row.visible


func _reflow(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	var short: bool = metrics.content_rect().size.y < SHORT_HEIGHT
	for index: int in _dialogs.size():
		_space(_dialogs[index].content, _spacing[index], short)
		_dialogs[index].apply(metrics, metrics.content_rect(), true, _widths[index])
	_busy.position = metrics.content_rect().position
	_busy.size = metrics.content_rect().size


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
