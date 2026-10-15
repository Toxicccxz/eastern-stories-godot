class_name InputHintRow
extends HFlowContainer
## A row of button hints ("[A] 开门  [Y] 选择附近"): each hint is its actions' glyphs and a
## short text, already in the shown language (tr()). Hidden on touch, and a hint whose
## actions have no glyph on the input in use is left out; the row follows the input at once.

## [[actions], text] per hint, as last given.
var _hints: Array[Array] = []


func _init() -> void:
	name = "InputHints"
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	var devices: InputDevices = InputDevices.shared()
	if not devices.changed.is_connected(_rebuild):
		devices.changed.connect(_rebuild)
	_rebuild()


func _exit_tree() -> void:
	var devices: InputDevices = InputDevices.shared()
	if devices.changed.is_connected(_rebuild):
		devices.changed.disconnect(_rebuild)


## `hints`: [actions (Array of StringName, or one StringName), shown text] each. Unchanged
## hints rebuild nothing.
func set_hints(hints: Array) -> void:
	var normalised: Array[Array] = []
	for hint: Array in hints:
		var actions: Array[StringName] = []
		if hint[0] is Array:
			actions.assign(hint[0])
		else:
			actions.append(StringName(hint[0]))
		normalised.append([actions, String(hint[1])])
	if normalised == _hints:
		return
	_hints = normalised
	_rebuild()


## The hints shown now, as "glyph text" lines with the glyphs' labels (tests).
func shown_hints() -> Array[String]:
	var shown: Array[String] = []
	for hint: Node in get_children():
		if hint.is_queued_for_deletion():
			continue
		var parts: PackedStringArray = []
		for part: Node in hint.get_children():
			if part is TextureRect:
				var glyph: InputGlyphs.Glyph = ((part as TextureRect).texture as InputGlyphTexture).glyph()
				parts.append("?" if glyph == null else glyph.text if not glyph.text.is_empty() else "shape%d" % glyph.shape)
			elif part is Label:
				parts.append((part as Label).text)
		shown.append(" ".join(parts))
	return shown


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var devices: InputDevices = InputDevices.shared()
	for hint: Array in _hints:
		var glyphs: Array[InputGlyphTexture] = []
		for action: StringName in hint[0]:
			var texture := InputGlyphTexture.new(action)
			if texture.has_glyph():
				glyphs.append(texture)
		if glyphs.is_empty():
			continue
		var item := HBoxContainer.new()
		item.name = "Hint"
		item.add_theme_constant_override("separation", 4)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for texture: InputGlyphTexture in glyphs:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.add_child(icon)
		var label := Label.new()
		label.text = hint[1]
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", SharedGameplayLayout.MUTED_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		add_child(item)
	visible = not devices.is_touch() and get_child_count() > 0
