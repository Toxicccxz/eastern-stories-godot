class_name BattleVisualTheme
extends Theme

## Replaceable martial/RPG palette. No gameplay state, timing or asset dimensions.
func _init() -> void:
	default_font_size = 18
	set_color("font_color", "Label", Color("eee4cb"))
	set_color("default_color", "RichTextLabel", Color("e1d7c2"))
	set_constant("separation", "VBoxContainer", 8)
	set_constant("separation", "HBoxContainer", 8)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.065, 0.10, 0.105, 0.94)
	panel.border_color = Color("71654c")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	set_stylebox("panel", "PanelContainer", panel)
	var normal := panel.duplicate() as StyleBoxFlat
	normal.bg_color = Color("243b3c")
	set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("355556")
	set_stylebox("hover", "Button", hover)
	set_stylebox("pressed", "Button", panel)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("efc77b")
	focus.set_border_width_all(3)
	set_stylebox("focus", "Button", focus)
	set_color("font_color", "Button", Color("f6e7c6"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("a45650")
	set_stylebox("fill", "ProgressBar", fill)
