class_name InputGlyphTexture
extends Texture2D
## An action's glyph (InputGlyphs) as a texture for a Button's icon or a TextureRect: it
## follows the input in use (InputDevices) and is empty (0×0) when nothing is shown.

var action: StringName
var _glyph: InputGlyphs.Glyph
## The kind and pad style the glyph was made for; another one remakes it.
var _made_for: Vector2i = Vector2i(-1, -1)


func _init(p_action: StringName = &"") -> void:
	action = p_action
	InputDevices.shared().changed.connect(_on_devices_changed)


func has_glyph() -> bool:
	return glyph() != null


func glyph() -> InputGlyphs.Glyph:
	var devices: InputDevices = InputDevices.shared()
	var now := Vector2i(devices.kind, devices.pad_style)
	if now != _made_for:
		_made_for = now
		_glyph = InputGlyphs.glyph_for(action, devices)
	return _glyph


func _on_devices_changed() -> void:
	emit_changed()


func _get_width() -> int:
	var shown: InputGlyphs.Glyph = glyph()
	return 0 if shown == null else ceili(shown.size().x)


func _get_height() -> int:
	var shown: InputGlyphs.Glyph = glyph()
	return 0 if shown == null else ceili(shown.size().y)


func _has_alpha() -> bool:
	return true


func _is_pixel_opaque(_x: int, _y: int) -> bool:
	return true


func _draw(item: RID, pos: Vector2, modulate: Color, _transpose: bool) -> void:
	var shown: InputGlyphs.Glyph = glyph()
	if shown != null:
		InputGlyphs.draw(item, Rect2(pos, shown.size()), shown, modulate)


func _draw_rect(item: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool) -> void:
	InputGlyphs.draw(item, rect, glyph(), modulate)


func _draw_rect_region(item: RID, rect: Rect2, _src_rect: Rect2, modulate: Color, _transpose: bool, _clip_uv: bool) -> void:
	InputGlyphs.draw(item, rect, glyph(), modulate)
