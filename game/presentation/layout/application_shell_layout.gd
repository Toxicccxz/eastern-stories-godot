class_name ApplicationShellLayout
extends Node

var _presenter: SafeAreaPresenter
var _dialogs: Array[ResponsivePanelLayout] = []
var _widths: Array[float] = [520.0, 460.0, 520.0, 580.0, 560.0]
var _busy: Label
var _window_row: Control
var _platform_hint: Label


func _ready() -> void:
	var shell: Node = get_parent()
	_window_row = shell.get_node("%WindowModeRow") as Control
	_platform_hint = Label.new()
	_platform_hint.name = "PlatformWindowModeHint"
	_platform_hint.text = "Window mode is managed by this platform."
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
	]:
		var layout: ResponsivePanelLayout = ResponsivePanelLayout.new()
		add_child(layout)
		layout.initialize(shell.get_node(path) as PanelContainer)
		_dialogs.append(layout)
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
	for index: int in _dialogs.size():
		_dialogs[index].apply(metrics, metrics.content_rect(), true, _widths[index])
	_busy.position = metrics.content_rect().position
	_busy.size = metrics.content_rect().size
