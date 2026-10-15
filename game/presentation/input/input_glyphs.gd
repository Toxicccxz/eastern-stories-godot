class_name InputGlyphs
extends RefCounted
## The button an action is bound to on the input the player uses now, as a small drawn
## glyph (owner, gamepad support): a pad's face buttons as coloured discs (Xbox letters,
## PlayStation shapes, Nintendo letters by position), its other buttons as pills, keys as
## keycaps. Touch shows none. Placeholder art drawn in code, like the maps' tiles.

enum Shape { DISC, PILL, KEY, CROSS, RING, SQUARE, TRIANGLE }

const HEIGHT: float = 22.0
const FONT_SIZE: int = 12

const _XBOX_FACES: Dictionary[int, Array] = {
	JOY_BUTTON_A: ["A", Color(0.36, 0.72, 0.28)],
	JOY_BUTTON_B: ["B", Color(0.86, 0.27, 0.24)],
	JOY_BUTTON_X: ["X", Color(0.22, 0.5, 0.92)],
	JOY_BUTTON_Y: ["Y", Color(0.93, 0.74, 0.16)],
}
const _PLAYSTATION_FACES: Dictionary[int, Array] = {
	JOY_BUTTON_A: [Shape.CROSS, Color(0.5, 0.66, 1.0)],
	JOY_BUTTON_B: [Shape.RING, Color(1.0, 0.42, 0.42)],
	JOY_BUTTON_X: [Shape.SQUARE, Color(0.95, 0.55, 0.85)],
	JOY_BUTTON_Y: [Shape.TRIANGLE, Color(0.35, 0.85, 0.7)],
}
## Nintendo pads name the buttons by the other diagonal: the bottom one is B.
const _NINTENDO_FACES: Dictionary[int, String] = {
	JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
}
## [Xbox, PlayStation, Nintendo] names of the other buttons.
const _PAD_BUTTONS: Dictionary[int, Array] = {
	JOY_BUTTON_BACK: ["Back", "Share", "-"],
	JOY_BUTTON_GUIDE: ["Guide", "PS", "Home"],
	JOY_BUTTON_START: ["Start", "Options", "+"],
	JOY_BUTTON_LEFT_STICK: ["LS", "L3", "LS"],
	JOY_BUTTON_RIGHT_STICK: ["RS", "R3", "RS"],
	JOY_BUTTON_LEFT_SHOULDER: ["LB", "L1", "L"],
	JOY_BUTTON_RIGHT_SHOULDER: ["RB", "R1", "R"],
	JOY_BUTTON_DPAD_UP: ["D-Pad Up", "D-Pad Up", "D-Pad Up"],
	JOY_BUTTON_DPAD_DOWN: ["D-Pad Down", "D-Pad Down", "D-Pad Down"],
	JOY_BUTTON_DPAD_LEFT: ["D-Pad Left", "D-Pad Left", "D-Pad Left"],
	JOY_BUTTON_DPAD_RIGHT: ["D-Pad Right", "D-Pad Right", "D-Pad Right"],
}
## [Xbox, PlayStation, Nintendo] names of the sticks and triggers.
const _PAD_AXES: Dictionary[int, Array] = {
	JOY_AXIS_LEFT_X: ["LS", "L3", "LS"],
	JOY_AXIS_LEFT_Y: ["LS", "L3", "LS"],
	JOY_AXIS_RIGHT_X: ["RS", "R3", "RS"],
	JOY_AXIS_RIGHT_Y: ["RS", "R3", "RS"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "L2", "ZL"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "R2", "ZR"],
}
const _KEY_NAMES: Dictionary[String, String] = {
	"Escape": "Esc", "PageUp": "PgUp", "PageDown": "PgDn", "Backspace": "Backspace",
}


## One drawn glyph: its shape, the text on it and its colour.
class Glyph:
	var shape: int
	var text: String
	var color: Color

	func _init(p_shape: int, p_text: String, p_color: Color = Color.WHITE) -> void:
		shape = p_shape
		text = p_text
		color = p_color

	func size() -> Vector2:
		match shape:
			Shape.PILL:
				return Vector2(maxf(HEIGHT, InputGlyphs.text_width(text) + 14.0), HEIGHT)
			Shape.KEY:
				return Vector2(maxf(HEIGHT, InputGlyphs.text_width(text) + 12.0), HEIGHT)
		return Vector2(HEIGHT, HEIGHT)


## The glyph of `action` on the input in use, or null (touch, or not bound to it).
static func glyph_for(action: StringName, devices: InputDevices = InputDevices.shared()) -> Glyph:
	if action.is_empty() or devices.is_touch() or not InputMap.has_action(action):
		return null
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if devices.is_gamepad():
		for event: InputEvent in events:
			if event is InputEventJoypadButton:
				return pad_button_glyph(event.button_index, devices.pad_style)
		for event: InputEvent in events:
			if event is InputEventJoypadMotion and _PAD_AXES.has(event.axis):
				return Glyph.new(Shape.PILL, _PAD_AXES[event.axis][devices.pad_style])
		return null
	for event: InputEvent in events:
		if event is InputEventKey:
			return Glyph.new(Shape.KEY, key_name(event))
	return null


static func pad_button_glyph(button: int, style: int) -> Glyph:
	if _XBOX_FACES.has(button):
		match style:
			InputDevices.PadStyle.PLAYSTATION:
				return Glyph.new(_PLAYSTATION_FACES[button][0], "", _PLAYSTATION_FACES[button][1])
			InputDevices.PadStyle.NINTENDO:
				return Glyph.new(Shape.DISC, _NINTENDO_FACES[button], Color(0.42, 0.44, 0.46))
		return Glyph.new(Shape.DISC, _XBOX_FACES[button][0], _XBOX_FACES[button][1])
	if _PAD_BUTTONS.has(button):
		return Glyph.new(Shape.PILL, _PAD_BUTTONS[button][style])
	return Glyph.new(Shape.PILL, str(button))


static func key_name(event: InputEventKey) -> String:
	var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	var shown: String = OS.get_keycode_string(code)
	return _KEY_NAMES.get(shown, shown)


static func font() -> Font:
	return ThemeDB.fallback_font


static func text_width(text: String) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


## Draws `glyph` into `rect` on `item`, tinted by `modulate` (a disabled button's grey).
static func draw(item: RID, rect: Rect2, glyph: Glyph, modulate: Color) -> void:
	if glyph == null:
		return
	var centre: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) / 2.0
	match glyph.shape:
		Shape.DISC:
			RenderingServer.canvas_item_add_circle(item, centre, radius, glyph.color * modulate)
			_text(item, rect, glyph.text, Color(1, 1, 1) * modulate)
		Shape.PILL:
			_box(item, rect, Color(0.86, 0.87, 0.84) * modulate, Color(0, 0, 0, 0), rect.size.y / 2.0)
			_text(item, rect, glyph.text, Color(0.08, 0.09, 0.1) * modulate)
		Shape.KEY:
			_box(item, rect, Color(1, 1, 1, 0.1) * modulate, Color(1, 1, 1, 0.65) * modulate, 4.0)
			_text(item, rect, glyph.text, Color(0.96, 0.95, 0.9) * modulate)
		_:
			RenderingServer.canvas_item_add_circle(item, centre, radius, Color(0.13, 0.14, 0.16) * modulate)
			_symbol(item, centre, radius * 0.5, glyph.shape, glyph.color * modulate)


static func _box(item: RID, rect: Rect2, fill: Color, border: Color, corner: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(int(corner))
	style.anti_aliasing = true
	style.draw(item, rect)


static func _text(item: RID, rect: Rect2, text: String, color: Color) -> void:
	var shown_font: Font = font()
	var width: float = shown_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var ascent: float = shown_font.get_ascent(FONT_SIZE)
	var descent: float = shown_font.get_descent(FONT_SIZE)
	var baseline := Vector2(rect.get_center().x - width / 2.0, rect.position.y + (rect.size.y - ascent - descent) / 2.0 + ascent)
	shown_font.draw_string(item, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## PlayStation's ✕ ○ □ △, drawn as lines.
static func _symbol(item: RID, centre: Vector2, half: float, shape: int, color: Color) -> void:
	var points := PackedVector2Array()
	match shape:
		Shape.CROSS:
			RenderingServer.canvas_item_add_line(item, centre + Vector2(-half, -half), centre + Vector2(half, half), color, 2.0, true)
			RenderingServer.canvas_item_add_line(item, centre + Vector2(-half, half), centre + Vector2(half, -half), color, 2.0, true)
			return
		Shape.RING:
			for step: int in 21:
				points.append(centre + Vector2.from_angle(TAU * step / 20.0) * half)
		Shape.SQUARE:
			points = PackedVector2Array([centre + Vector2(-half, -half), centre + Vector2(half, -half), centre + Vector2(half, half), centre + Vector2(-half, half), centre + Vector2(-half, -half)])
		Shape.TRIANGLE:
			points = PackedVector2Array([centre + Vector2(0, -half), centre + Vector2(half, half * 0.8), centre + Vector2(-half, half * 0.8), centre + Vector2(0, -half)])
	RenderingServer.canvas_item_add_polyline(item, points, PackedColorArray([color]), 2.0, true)


## Shows `action`'s glyph on `button` (as its icon) while the player uses keys or a pad.
static func decorate(button: Button, action: StringName) -> void:
	InputGlyphBinding.attach(button, action)
