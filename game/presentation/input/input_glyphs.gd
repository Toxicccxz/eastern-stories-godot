class_name InputGlyphs
extends RefCounted
## The button an action is bound to on the input the player uses now, as a small drawn
## glyph (owner, gamepad support): keys as the theme's bone key caps; a pad's buttons as little
## pixel plates on the interface's own grid (GameTheme.GRID; owner 2026-11-22: the pale
## rounded "Start" pills read as another game's): the face buttons as discs (Xbox letters on
## their colours worn down to the palette, PlayStation's shapes, Nintendo letters by position),
## Start and Back as their icons (☰, two squares), the D-pad as a cross with its arm lit, the
## sticks as capped discs, the shoulders and triggers as iron plates with their short names.
## Touch shows none. Drawn in code, like the maps' tiles.

enum Shape { DISC, KEY, CROSS, RING, SQUARE, TRIANGLE, MENU, VIEW, HOME, DPAD, STICK, SHOULDER, TRIGGER }

## A pad glyph is this many texels (GameTheme.GRID logical pixels) high.
const TEXELS: int = 14
const HEIGHT: float = TEXELS * GameTheme.GRID
## 像素界面: the pixel face at its one crisp size (GameTheme.BODY_SIZE).
const FONT_SIZE: int = 18

## The face buttons' colours, the palette's (worn, not toy-bright).
const _XBOX_FACES: Dictionary[int, Array] = {
	JOY_BUTTON_A: ["A", Color("4f8a45")],
	JOY_BUTTON_B: ["B", Color("a3301f")],
	JOY_BUTTON_X: ["X", Color("3a6390")],
	JOY_BUTTON_Y: ["Y", Color("b8862e")],
}
const _PLAYSTATION_FACES: Dictionary[int, Array] = {
	JOY_BUTTON_A: [Shape.CROSS, Color("8fb0e8")],
	JOY_BUTTON_B: [Shape.RING, Color("e8857a")],
	JOY_BUTTON_X: [Shape.SQUARE, Color("dc9ccf")],
	JOY_BUTTON_Y: [Shape.TRIANGLE, Color("7fcfb4")],
}
## Nintendo pads name the buttons by the other diagonal: the bottom one is B.
const _NINTENDO_FACES: Dictionary[int, String] = {
	JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
}
## The other buttons: [shape, [Xbox, PlayStation, Nintendo] text drawn on it, the same pads'
## names written out (the key page)]. A D-pad arm's text is its index in _DPAD_ARMS.
const _PAD_BUTTONS: Dictionary[int, Array] = {
	JOY_BUTTON_BACK: [Shape.VIEW, ["", "", ""], ["视图键", "SHARE", "-"]],
	JOY_BUTTON_GUIDE: [Shape.HOME, ["", "", ""], ["导航键", "PS", "HOME"]],
	JOY_BUTTON_START: [Shape.MENU, ["", "", ""], ["菜单键", "OPTIONS", "+"]],
	JOY_BUTTON_LEFT_STICK: [Shape.STICK, ["L", "L", "L"], ["LS", "L3", "LS"]],
	JOY_BUTTON_RIGHT_STICK: [Shape.STICK, ["R", "R", "R"], ["RS", "R3", "RS"]],
	JOY_BUTTON_LEFT_SHOULDER: [Shape.SHOULDER, ["LB", "L1", "L"], ["LB", "L1", "L"]],
	JOY_BUTTON_RIGHT_SHOULDER: [Shape.SHOULDER, ["RB", "R1", "R"], ["RB", "R1", "R"]],
	JOY_BUTTON_DPAD_UP: [Shape.DPAD, ["0", "0", "0"], ["十字键上", "十字键上", "十字键上"]],
	JOY_BUTTON_DPAD_DOWN: [Shape.DPAD, ["1", "1", "1"], ["十字键下", "十字键下", "十字键下"]],
	JOY_BUTTON_DPAD_LEFT: [Shape.DPAD, ["2", "2", "2"], ["十字键左", "十字键左", "十字键左"]],
	JOY_BUTTON_DPAD_RIGHT: [Shape.DPAD, ["3", "3", "3"], ["十字键右", "十字键右", "十字键右"]],
}
## The sticks and triggers, written the same way.
const _PAD_AXES: Dictionary[int, Array] = {
	JOY_AXIS_LEFT_X: [Shape.STICK, ["L", "L", "L"], ["LS", "L3", "LS"]],
	JOY_AXIS_LEFT_Y: [Shape.STICK, ["L", "L", "L"], ["LS", "L3", "LS"]],
	JOY_AXIS_RIGHT_X: [Shape.STICK, ["R", "R", "R"], ["RS", "R3", "RS"]],
	JOY_AXIS_RIGHT_Y: [Shape.STICK, ["R", "R", "R"], ["RS", "R3", "RS"]],
	JOY_AXIS_TRIGGER_LEFT: [Shape.TRIGGER, ["LT", "L2", "ZL"], ["LT", "L2", "ZL"]],
	JOY_AXIS_TRIGGER_RIGHT: [Shape.TRIGGER, ["RT", "R2", "ZR"], ["RT", "R2", "ZR"]],
}
## PlayStation's face buttons, written out where a glyph has no text (the key page).
const _SHAPE_SIGNS: Dictionary[int, String] = {Shape.CROSS: "叉", Shape.RING: "圈", Shape.SQUARE: "方", Shape.TRIANGLE: "三角"}
const _KEY_NAMES: Dictionary[String, String] = {
	"Escape": "Esc", "PageUp": "PgUp", "PageDown": "PgDn", "Backspace": "Backspace",
}
## The little pictures, one string a row ("#" lit): PlayStation's shapes, ☰, the View
## button's two squares, the Guide's ring.
const _PICTURES: Dictionary[int, Array] = {
	Shape.CROSS: ["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"],
	Shape.RING: ["..###..", ".#...#.", "#.....#", "#.....#", "#.....#", ".#...#.", "..###.."],
	Shape.SQUARE: ["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
	Shape.TRIANGLE: ["...#...", "..#.#..", "..#.#..", ".#...#.", ".#...#.", "#.....#", "#######"],
	Shape.MENU: ["#######", ".......", "#######", ".......", "#######"],
	Shape.VIEW: ["####..", "#..#..", "#.####", "####.#", "..#..#", "..####"],
	Shape.HOME: ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
}
## The D-pad's arms, in the order their glyph text names them: up, down, left, right.
const _DPAD_ARMS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## The pad plates' iron.
const PLATE: Color = Color("4a4f4e")


## One drawn glyph: its shape, the text on it, its colour and its name written out.
class Glyph:
	var shape: int
	var text: String
	var color: Color
	## What the key page and the hints call it ("A", "菜单键", "十字键上"; "" for PlayStation's shapes).
	var name: String

	func _init(p_shape: int, p_text: String, p_color: Color = Color.WHITE, p_name: String = "") -> void:
		shape = p_shape
		text = p_text
		color = p_color
		name = p_text if p_name.is_empty() and p_shape not in [Shape.DPAD] else p_name

	func size() -> Vector2:
		var grid: float = GameTheme.GRID
		match shape:
			Shape.KEY:
				return Vector2(maxf(HEIGHT, InputGlyphs.text_width(text) + 12.0), HEIGHT)
			Shape.SHOULDER, Shape.TRIGGER:
				return Vector2(maxi(TEXELS + 4, ceili(InputGlyphs.text_width(text) / grid) + 8) * grid, HEIGHT)
			Shape.MENU, Shape.VIEW:
				return Vector2((TEXELS + 3) * grid, HEIGHT)
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
				return pad_axis_glyph(event.axis, devices.pad_style)
		return null
	for event: InputEvent in events:
		if event is InputEventKey:
			return Glyph.new(Shape.KEY, key_name(event))
	return null


## Every key `action` is bound to, by name (the key page, 按键一览).
static func key_names(action: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and not names.has(key_name(event)):
				names.append(key_name(event))
	return names


## Every pad button and stick `action` is bound to on a pad of `style`, by name (the key
## page): the face buttons as the pad prints them (PlayStation's shapes as signs).
static func pad_names(action: StringName, style: int) -> PackedStringArray:
	var names := PackedStringArray()
	for glyph: Glyph in pad_glyphs(action, style):
		var shown: String = shown_name(glyph)
		if not shown.is_empty() and not names.has(shown):
			names.append(shown)
	return names


## A glyph's name written out, in the shown language: PlayStation's shapes as their signs.
static func shown_name(glyph: Glyph) -> String:
	return TranslationServer.translate(glyph.name if not glyph.name.is_empty() else _SHAPE_SIGNS.get(glyph.shape, ""))


## Every pad button and stick `action` is bound to on a pad of `style`, one glyph a name.
static func pad_glyphs(action: StringName, style: int) -> Array[Glyph]:
	var glyphs: Array[Glyph] = []
	if not InputMap.has_action(action):
		return glyphs
	var seen := PackedStringArray()
	for event: InputEvent in InputMap.action_get_events(action):
		var glyph: Glyph = null
		if event is InputEventJoypadButton:
			glyph = pad_button_glyph(event.button_index, style)
		elif event is InputEventJoypadMotion and _PAD_AXES.has(event.axis):
			glyph = pad_axis_glyph(event.axis, style)
		if glyph != null and not seen.has(shown_name(glyph)):
			seen.append(shown_name(glyph))
			glyphs.append(glyph)
	return glyphs


static func pad_button_glyph(button: int, style: int) -> Glyph:
	if _XBOX_FACES.has(button):
		match style:
			InputDevices.PadStyle.PLAYSTATION:
				return Glyph.new(_PLAYSTATION_FACES[button][0], "", _PLAYSTATION_FACES[button][1])
			InputDevices.PadStyle.NINTENDO:
				return Glyph.new(Shape.DISC, _NINTENDO_FACES[button], PLATE)
		return Glyph.new(Shape.DISC, _XBOX_FACES[button][0], _XBOX_FACES[button][1])
	if _PAD_BUTTONS.has(button):
		var made: Array = _PAD_BUTTONS[button]
		return Glyph.new(made[0], made[1][style], PLATE, made[2][style])
	return Glyph.new(Shape.SHOULDER, str(button), PLATE)


static func pad_axis_glyph(axis: int, style: int) -> Glyph:
	var made: Array = _PAD_AXES[axis]
	return Glyph.new(made[0], made[1][style], PLATE, made[2][style])


## A key bound by position (the letter keys: DECISIONS「按键」) shows the letter the player's own
## layout prints there (Z for W on AZERTY).
static func key_name(event: InputEventKey) -> String:
	var code: Key = event.keycode
	if code == KEY_NONE and event.physical_keycode != KEY_NONE:
		# A headless run has no keyboard layout to ask (it says so as an error).
		code = KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_label_from_physical(event.physical_keycode)
		if code == KEY_NONE:
			code = event.physical_keycode
	return key_text(code)


## What a key cap says for `code`: the character it types for a printable key (the comma
## key, which an AZERTY layout has where QWERTY's M is, shows ",", not "Comma"), upper case
## for a letter; Godot's short name for the rest (Esc, Space, Up, F1).
static func key_text(code: Key) -> String:
	if code > KEY_SPACE and code < KEY_SPECIAL and code != 127:
		return String.chr(code).to_upper()
	var shown: String = OS.get_keycode_string(code)
	return _KEY_NAMES.get(shown, shown)


static func font() -> Font:
	return GameTheme.text_font()


static func text_width(text: String) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


## Draws `glyph` into `rect` on `item`, tinted by `modulate` (a disabled button's grey).
static func draw(item: RID, rect: Rect2, glyph: Glyph, modulate: Color) -> void:
	if glyph == null:
		return
	if glyph.shape == Shape.KEY:
		_cap(modulate).draw(item, rect)
		_text(item, rect.grow_side(SIDE_BOTTOM, -GameTheme.GRID * 2.0), glyph.text, UiPalette.INK * Color(1, 1, 1, modulate.a))
		return
	var pixels := Pixels.new(item, rect, modulate)
	var light: Color = UiPalette.LIGHT_TEXT
	match glyph.shape:
		Shape.DISC:
			pixels.disc(glyph.color)
			pixels.label(glyph.text, light)
		Shape.CROSS, Shape.RING, Shape.SQUARE, Shape.TRIANGLE:
			pixels.disc(PLATE)
			pixels.picture(_PICTURES[glyph.shape], glyph.color)
		Shape.HOME:
			pixels.disc(PLATE)
			pixels.picture(_PICTURES[glyph.shape], light)
		Shape.STICK:
			pixels.disc(PLATE)
			pixels.ring(PLATE.darkened(0.4))
			pixels.label(glyph.text, light)
		Shape.MENU, Shape.VIEW:
			pixels.plate(PLATE, 3)
			pixels.picture(_PICTURES[glyph.shape], light)
		Shape.SHOULDER:
			pixels.plate(PLATE, 1, true)
			pixels.label(glyph.text, light)
		Shape.TRIGGER:
			pixels.plate(PLATE, 4)
			pixels.label(glyph.text, light)
		Shape.DPAD:
			pixels.dpad(int(glyph.text) if glyph.text.is_valid_int() else -1)


## A pad glyph's pixels: a TEXELS-high grid laid over the glyph's rect, each cell a whole texel.
## A plate is an outline, its face and, under the face, two rows of its darker side (the
## interface's buttons stand the same way).
class Pixels:
	var item: RID
	var origin: Vector2
	var texel: float
	var columns: int
	var modulate: Color

	func _init(p_item: RID, rect: Rect2, p_modulate: Color) -> void:
		item = p_item
		texel = maxf(1.0, rect.size.y / InputGlyphs.TEXELS)
		columns = maxi(1, roundi(rect.size.x / texel))
		origin = rect.position.round()
		modulate = p_modulate

	func cell(x: int, y: int, w: int, h: int, colour: Color) -> void:
		if w > 0 and h > 0:
			RenderingServer.canvas_item_add_rect(item, Rect2(origin + Vector2(x, y) * texel, Vector2(w, h) * texel), colour * modulate)

	## The half-width of a disc `size` texels across on its row `y`.
	static func half(size: int, y: int) -> int:
		var r: float = size / 2.0
		var dy: float = y + 0.5 - r
		return clampi(roundi(sqrt(maxf(r * r - dy * dy, 0.0))), 0, size / 2)

	func _disc_rows(size: int, at: Vector2i, rows: int, colour: Color) -> void:
		for y: int in mini(rows, size):
			var w: int = half(size, y)
			cell(at.x + size / 2 - w, at.y + y, w * 2, 1, colour)

	## A round button: outline, its side under it, its face, a worn highlight upper left.
	func disc(face: Color) -> void:
		var n: int = InputGlyphs.TEXELS
		var left: int = (columns - n) / 2
		_disc_rows(n, Vector2i(left, 0), n, UiPalette.OUTLINE)
		_disc_rows(n - 2, Vector2i(left + 1, 1), n - 2, face.darkened(0.45))
		_disc_rows(n - 2, Vector2i(left + 1, 1), n - 4, face)
		cell(left + 4, 2, 2, 1, face.lightened(0.28))
		cell(left + 3, 3, 1, 1, face.lightened(0.28))

	## A ring inside the disc (a stick's cap).
	func ring(colour: Color) -> void:
		var n: int = InputGlyphs.TEXELS - 6
		var left: int = (columns - n) / 2
		for y: int in n:
			var w: int = half(n, y)
			if y == 0 or y == n - 1:
				cell(left + n / 2 - w, 2 + y, w * 2, 1, colour)
			else:
				cell(left + n / 2 - w, 2 + y, 1, 1, colour)
				cell(left + n / 2 + w - 1, 2 + y, 1, 1, colour)

	## A plate the glyph's width, its corners cut `corner` texels; `bumper` cuts the top
	## corners deeper (a shoulder button's slope).
	func plate(face: Color, corner: int, bumper: bool = false) -> void:
		var n: int = InputGlyphs.TEXELS
		for y: int in n:
			var cut: int = _cut(y, n, corner, bumper)
			cell(cut, y, columns - cut * 2, 1, UiPalette.OUTLINE)
		for y: int in range(1, n - 1):
			var cut: int = _cut(y, n, corner, bumper) + 1
			cell(cut, y, columns - cut * 2, 1, face if y < n - 3 else face.darkened(0.45))
		cell(_cut(2, n, corner, bumper) + 2, 2, 3, 1, face.lightened(0.22))

	static func _cut(y: int, n: int, corner: int, bumper: bool) -> int:
		var top: int = corner + (2 if bumper else 0)
		if y < top:
			return top - y
		if n - 1 - y < corner:
			return corner - (n - 1 - y)
		return 0

	## `rows` ("#" lit) centred on the face (above its side rows).
	func picture(rows: Array, colour: Color) -> void:
		var h: int = rows.size()
		var w: int = String(rows[0]).length()
		var left: int = (columns - w) / 2
		var top: int = (InputGlyphs.TEXELS - 2 - h) / 2
		for y: int in h:
			var row: String = rows[y]
			for x: int in w:
				if row[x] == "#":
					cell(left + x, top + y, 1, 1, colour)

	## The D-pad: a cross of iron, the arm pressed lit (-1: its middle, the whole pad).
	func dpad(arm: int) -> void:
		var n: int = InputGlyphs.TEXELS
		var left: int = (columns - n) / 2
		var arm_w: int = 4
		var mid: int = (n - arm_w) / 2
		cell(left + mid - 1, 0, arm_w + 2, n, UiPalette.OUTLINE)
		cell(left, mid - 1, n, arm_w + 2, UiPalette.OUTLINE)
		cell(left + mid, 1, arm_w, n - 2, InputGlyphs.PLATE)
		cell(left + 1, mid, n - 2, arm_w, InputGlyphs.PLATE)
		var lit: Color = UiPalette.LANTERN
		if arm < 0 or arm >= InputGlyphs._DPAD_ARMS.size():
			cell(left + mid, mid, arm_w, arm_w, lit)
			return
		var way: Vector2i = InputGlyphs._DPAD_ARMS[arm]
		var length: int = mid - 1
		if way.x == 0:
			cell(left + mid, 1 if way.y < 0 else n - 1 - length, arm_w, length, lit)
		else:
			cell(left + 1 if way.x < 0 else left + n - 1 - length, mid, length, arm_w, lit)

	## `text` on the face (above its side rows), with a texel of shadow under it.
	func label(text: String, colour: Color) -> void:
		if text.is_empty():
			return
		var face := Rect2(origin + Vector2(0, texel), Vector2(columns, InputGlyphs.TEXELS - 3) * texel)
		InputGlyphs._text(item, face, text, Color(0, 0, 0, 0.5) * modulate, Vector2(0, texel))
		InputGlyphs._text(item, face, text, colour * modulate)


## The theme's key tile, tinted by `modulate` (a disabled button's grey).
static var _caps: Dictionary[String, StyleBox] = {}


static func _cap(modulate: Color) -> StyleBox:
	var key: String = modulate.to_html()
	if not _caps.has(key):
		var cap: StyleBox = GameTheme.shared().get_stylebox("normal", &"KeyCap")
		if cap is PixelBox and modulate != Color.WHITE:
			cap = cap.duplicate()
			(cap as PixelBox).modulate = modulate
		_caps[key] = cap
	return _caps[key]


static func _text(item: RID, rect: Rect2, text: String, color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var shown_font: Font = font()
	var width: float = shown_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var ascent: float = shown_font.get_ascent(FONT_SIZE)
	var descent: float = shown_font.get_descent(FONT_SIZE)
	var baseline := Vector2(rect.get_center().x - width / 2.0, rect.position.y + (rect.size.y - ascent - descent) / 2.0 + ascent)
	shown_font.draw_string(item, (baseline + offset).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## Shows `action`'s glyph on `button` (as its icon) while the player uses keys or a pad.
static func decorate(button: Button, action: StringName) -> void:
	InputGlyphBinding.attach(button, action)
