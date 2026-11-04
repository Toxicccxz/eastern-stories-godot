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
	shade.color = UiPalette.SCRIM
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.name = "LogPanel"
	add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "战斗记录"
	title.theme_type_variation = &"HeadingLabel"
	content.add_child(title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.add_theme_color_override("default_color", SharedGameplayUI.PLAIN_LOG_COLOR)
	_text.custom_minimum_size = Vector2(0, 240)
	_text.scroll_following = true
	_text.add_to_group(PadSupport.SCROLL_GROUP)
	content.add_child(_text)
	close_button = Button.new()
	close_button.name = "CloseLog"
	close_button.text = "关闭"
	close_button.theme_type_variation = &"ChipButton"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.custom_minimum_size = Vector2(64, 64)
	close_button.pressed.connect(close_log)
	content.add_child(close_button)
	InputGlyphs.decorate(close_button, &"battle_back")
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
		for line: BattleNarrationLine in entry.lines():
			# DECISIONS「战斗界面」: a blow's short form first, ES2's line grey under it.
			_text.append_text(line.log_rich_text() + "\n")


func clear_entries() -> void:
	_text.clear()


func open_log() -> void:
	show()
	close_button.grab_focus()


func close_log() -> void:
	hide()
	closed.emit()
