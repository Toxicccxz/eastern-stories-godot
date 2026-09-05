class_name BattleLogPanel
extends Control

signal closed
var panel: PanelContainer
var close_button: Button
var _text: RichTextLabel
var _layout: ResponsivePanelLayout


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.03, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.name = "LogPanel"
	add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "Combat Log"
	content.add_child(title)
	_text = RichTextLabel.new()
	_text.custom_minimum_size = Vector2(0, 240)
	_text.scroll_following = true
	content.add_child(_text)
	close_button = Button.new()
	close_button.name = "CloseLog"
	close_button.text = "Close log"
	close_button.custom_minimum_size = Vector2(64, 64)
	close_button.pressed.connect(close_log)
	content.add_child(close_button)
	_layout = ResponsivePanelLayout.new()
	add_child(_layout)
	_layout.initialize(panel)
	_layout.blocks_touch_gameplay = true
	_layout.dismiss_requested.connect(close_log)
	hide()


func apply_metrics(metrics: SafeAreaMetrics) -> void:
	_layout.apply(metrics, metrics.content_rect(), true, 840)


func append_entries(entries: Array[BattleFeedbackProjection]) -> void:
	for entry: BattleFeedbackProjection in entries:
		_text.add_text("%d · %s\n" % [entry.progression_order, entry.text])


func clear_entries() -> void:
	_text.clear()


func open_log() -> void:
	show()
	close_button.grab_focus()


func close_log() -> void:
	hide()
	closed.emit()
