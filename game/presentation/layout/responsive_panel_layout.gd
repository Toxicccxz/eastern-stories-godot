class_name ResponsivePanelLayout
extends Node

var panel: PanelContainer
var scroll: ScrollContainer
var content: Control
var _available: Rect2
var _preferred_width: float = 520.0
var _centered: bool = true
var _touch: bool = false
var _queued: bool = false
var _minimums: Dictionary[Control, Vector2] = {}
var _font_sizes: Dictionary[Control, int] = {}


func initialize(target: PanelContainer) -> void:
	panel = target
	panel.custom_minimum_size = Vector2.ZERO
	content = panel.get_child(0) as Control
	scroll = ScrollContainer.new()
	scroll.name = "ResponsiveScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	content.reparent(scroll, false)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.minimum_size_changed.connect(queue_layout)
	panel.visibility_changed.connect(queue_layout)
	_prepare_controls(content)


func apply(metrics: SafeAreaMetrics, rect: Rect2, centered: bool = false, preferred_width: float = 520.0) -> void:
	_available = rect
	_centered = centered
	_preferred_width = preferred_width
	_touch = metrics.touch_sized()
	_prepare_controls(content)
	queue_layout()


func _prepare_controls(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		if not _minimums.has(control):
			_minimums[control] = control.custom_minimum_size
			var font_key: StringName = &"normal_font_size" if control is RichTextLabel else &"font_size"
			_font_sizes[control] = control.get_theme_font_size(font_key) if control.has_theme_font_size_override(font_key) else -1
		var original: Vector2 = _minimums[control]
		if control is FlowContainer:
			control.add_theme_constant_override("h_separation", 8)
			control.add_theme_constant_override("v_separation", 8)
		# Godot renames sibling rows with duplicate names; identify their stable list parent.
		if control is BoxContainer and control.get_parent().name in ["PlayerInventoryRows", "LootRows"]:
			(control as BoxContainer).vertical = _touch or control.get_parent().name == "LootRows"
		control.custom_minimum_size = Vector2(0.0, original.y)
		if control is ScrollContainer:
			control.custom_minimum_size.y = minf(original.y, 120.0) if _touch else original.y
		if control is BaseButton:
			control.custom_minimum_size = Vector2(64.0 if _touch else original.x, maxf(64.0, original.y) if _touch else original.y)
			if control is Button:
				(control as Button).clip_text = false
		if control is Label:
			(control as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if control is RichTextLabel:
			(control as RichTextLabel).scroll_active = true
		var key: StringName = &"normal_font_size" if control is RichTextLabel else &"font_size"
		if _touch:
			control.add_theme_font_size_override(key, maxi(20, _font_sizes[control]))
		elif _font_sizes[control] >= 0:
			control.add_theme_font_size_override(key, _font_sizes[control])
		else:
			control.remove_theme_font_size_override(key)
		if control is Label and control.get_parent() is FlowContainer:
			var label: Label = control as Label
			var text_width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			control.custom_minimum_size.x = minf(text_width, maxf(64.0, _available.size.x - 80.0))
	for child: Node in node.get_children():
		if child is Control and not child is ScrollBar:
			_prepare_controls(child)


func queue_layout() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	call_deferred("_layout")


func _layout() -> void:
	_queued = false
	if not is_instance_valid(panel) or _available.size.x <= 0.0 or _available.size.y <= 0.0:
		return
	var width: float = minf(_preferred_width, _available.size.x) if _centered else _available.size.x
	var height: float = _available.size.y
	if _centered:
		height = minf(height, content.get_combined_minimum_size().y + 16.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = _available.position + (_available.size - Vector2(width, height)) / 2.0 if _centered else _available.position
	panel.size = Vector2(width, height)
	call_deferred("_reveal_focused")


func _reveal_focused() -> void:
	# Reflow can occur after the unchanged Shell focus authority selected its child.
	# Reveal that child; do not select a new focus owner or release gameplay input.
	if not is_inside_tree() or not is_instance_valid(panel):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and panel.is_visible_in_tree() and scroll.is_ancestor_of(focused):
		scroll.ensure_control_visible(focused)


func restyle_dynamic_content() -> void:
	# Forget freed row controls without retaining a mutable item or projection model.
	# A typed Dictionary cannot erase a freed Object key: copy only live keys instead.
	var live_minimums: Dictionary[Control, Vector2] = {}
	var live_fonts: Dictionary[Control, int] = {}
	for control: Variant in _minimums.keys():
		if is_instance_valid(control):
			live_minimums[control] = _minimums[control]
			live_fonts[control] = _font_sizes[control]
	_minimums = live_minimums
	_font_sizes = live_fonts
	_prepare_controls(content)
	queue_layout()
