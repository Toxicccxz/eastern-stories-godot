class_name UiSkin
extends RefCounted
## The 东方漆木 skin (ui_skin.png, drawn with Pixel Loom: tools/art/ui_atlas.py, at 2x).
##
## Two surfaces: paper (宣纸: the game menu window and the shell's dialogs, ink text) and
## lacquer (漆: everything over the map, light text, so ES2's bright colours stay readable).
## Buttons are paper plaques with ink text on both. Text roles are theme type variations
## (MutedLabel, AccentLabel, NameLabel, WarningLabel), so one label reads right on either.

const ATLAS: Texture2D = preload("res://ui/theme/ui_skin.png")

## Paper: ink and its quieter shades; the accent is lacquer red.
const INK: Color = Color("2b1d1a")
const INK_MUTED: Color = Color("6b5a44")
const INK_ACCENT: Color = Color("8e2a22")
const INK_WARNING: Color = Color("b03a1e")
## Lacquer: paper-coloured text; the accent is gold.
const TEXT: Color = Color("f2e8d2")
const TEXT_MUTED: Color = Color("b8ae98")
const TEXT_ACCENT: Color = Color("e2c27c")
const TEXT_WARNING: Color = Color("ff8a70")
const TEXT_NAME: Color = Color("f6efe0")
## A pressed plaque or a selected tab (vermilion) reads in paper colour.
const ON_LACQUER_BUTTON: Color = Color("f8eedb")
const DISABLED_TEXT: Color = Color("8f8574")
const PAPER: Color = Color("efe3c6")
const LACQUER: Color = Color(0.122, 0.082, 0.071, 0.94)
const GOLD: Color = Color("d4a446")
const GOLD_DARK: Color = Color("9c7230")

# Regions in the 2x atlas.
const PAPER_PANEL := Rect2(0, 0, 96, 96)
const LACQUER_PANEL := Rect2(96, 0, 96, 96)
const BUTTON_NORMAL := Rect2(192, 0, 96, 32)
const BUTTON_HOVER := Rect2(192, 32, 96, 32)
const BUTTON_PRESSED := Rect2(192, 64, 96, 32)
const BUTTON_DISABLED := Rect2(192, 96, 96, 32)
const TAB_SELECTED := Rect2(192, 128, 96, 32)
const PAPER_INSET := Rect2(0, 96, 48, 48)
const DARK_INSET := Rect2(48, 96, 48, 48)
const FOCUS_RING := Rect2(96, 96, 48, 48)

static var _themes: Dictionary = {}


## The theme of a surface; `font_size` 0 keeps the default size.
static func theme(paper: bool, font_size: int = 0) -> Theme:
	var key: String = "%s:%d" % [paper, font_size]
	if not _themes.has(key):
		_themes[key] = _build(paper, font_size)
	return _themes[key]


static func paper_theme() -> Theme:
	return theme(true)


static func lacquer_theme() -> Theme:
	return theme(false)


## A colour made for a dark ground (an ES2 bright colour, a resource bar's) as it reads on paper:
## the same hue, dark enough for ink.
static func on_paper(color: Color) -> Color:
	var light: float = color.get_luminance()
	if light <= 0.4:
		return color
	return color.darkened(clampf(1.0 - 0.32 / light, 0.0, 0.8))


# --- Styleboxes ------------------------------------------------------------------------------

static func panel(paper: bool, padding: float = 18.0) -> StyleBoxTexture:
	var style := _texture_box(PAPER_PANEL if paper else LACQUER_PANEL, 14.0, 14.0)
	style.set_content_margin_all(padding)
	return style


static func button(region: Rect2) -> StyleBoxTexture:
	var style := _texture_box(region, 8.0, 6.0)
	style.texture_margin_bottom = 8.0
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 7.0
	return style


static func inset(paper: bool, padding: float = 10.0) -> StyleBoxTexture:
	var style := _texture_box(PAPER_INSET if paper else DARK_INSET, 4.0, 4.0)
	style.set_content_margin_all(padding)
	return style


static func focus_ring() -> StyleBoxTexture:
	var style := _texture_box(FOCUS_RING, 6.0, 6.0)
	style.draw_center = false
	style.set_expand_margin_all(3.0)
	return style


## A flat lacquer box for what lies over the map (toasts, the place's text, the status chips).
static func overlay(alpha: float = 0.88) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(LACQUER, alpha)
	style.border_color = Color(GOLD_DARK, minf(1.0, alpha + 0.1))
	style.set_border_width_all(2)
	style.anti_aliasing = false
	return style


static func _texture_box(region: Rect2, margin_x: float, margin_y: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = ATLAS
	style.region_rect = region
	style.texture_margin_left = margin_x
	style.texture_margin_right = margin_x
	style.texture_margin_top = margin_y
	style.texture_margin_bottom = margin_y
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return style


# --- Themes ----------------------------------------------------------------------------------

static func _build(paper: bool, font_size: int) -> Theme:
	var t := Theme.new()
	if font_size > 0:
		t.default_font_size = font_size
	var text: Color = INK if paper else TEXT
	t.set_color("font_color", "Label", text)
	t.set_color("default_color", "RichTextLabel", text)
	var roles: Dictionary[StringName, Color] = {
		&"MutedLabel": INK_MUTED if paper else TEXT_MUTED,
		&"AccentLabel": INK_ACCENT if paper else TEXT_ACCENT,
		&"NameLabel": INK if paper else TEXT_NAME,
		&"WarningLabel": INK_WARNING if paper else TEXT_WARNING,
	}
	for role: StringName in roles:
		t.set_type_variation(role, &"Label")
		t.set_color("font_color", role, roles[role])
	t.set_stylebox("panel", "PanelContainer", inset(paper))
	t.set_stylebox("panel", "Panel", inset(paper))
	for control: StringName in [&"Button", &"OptionButton", &"MenuButton", &"CheckBox", &"CheckButton"]:
		_buttons(t, control)
	t.set_type_variation(&"AccentButton", &"Button")
	t.set_stylebox("normal", &"AccentButton", button(BUTTON_HOVER))
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		# A check box shows its box beside the text; its plaque would hide it.
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			t.set_stylebox(state, type, StyleBoxEmpty.new())
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, text)
		t.set_color("font_pressed_color", type, text)
		t.set_color("font_hover_pressed_color", type, text)
		t.set_color("font_focus_color", type, text)
	var entry := inset(true, 8.0)
	t.set_stylebox("normal", "LineEdit", entry)
	t.set_stylebox("read_only", "LineEdit", entry)
	t.set_stylebox("focus", "LineEdit", focus_ring())
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_MUTED)
	t.set_color("caret_color", "LineEdit", INK_ACCENT)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.45))
	t.set_stylebox("panel", "PopupMenu", panel(true, 8.0))
	t.set_stylebox("hover", "PopupMenu", button(BUTTON_PRESSED))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", ON_LACQUER_BUTTON)
	t.set_color("font_disabled_color", "PopupMenu", DISABLED_TEXT)
	t.set_stylebox("panel", "TooltipPanel", overlay(0.95))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", inset(false, 0.0))
	var line := StyleBoxLine.new()
	line.color = Color("c4ae88") if paper else Color("5a4636")
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	for bar: StringName in [&"HScrollBar", &"VScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("dccaa6") if paper else Color(0, 0, 0, 0.35)
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color("8e2a22") if paper else GOLD_DARK
		var grab_hot := grab.duplicate() as StyleBoxFlat
		grab_hot.bg_color = Color("b8402e") if paper else GOLD
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab_hot)
		t.set_stylebox("grabber_pressed", bar, grab_hot)
	return t


static func _buttons(t: Theme, control: StringName) -> void:
	t.set_stylebox("normal", control, button(BUTTON_NORMAL))
	t.set_stylebox("hover", control, button(BUTTON_HOVER))
	t.set_stylebox("pressed", control, button(TAB_SELECTED))
	t.set_stylebox("hover_pressed", control, button(TAB_SELECTED))
	t.set_stylebox("disabled", control, button(BUTTON_DISABLED))
	t.set_stylebox("focus", control, focus_ring())
	t.set_color("font_color", control, INK)
	t.set_color("font_hover_color", control, INK)
	t.set_color("font_focus_color", control, INK)
	t.set_color("font_pressed_color", control, ON_LACQUER_BUTTON)
	t.set_color("font_hover_pressed_color", control, ON_LACQUER_BUTTON)
	t.set_color("font_disabled_color", control, DISABLED_TEXT)
	t.set_constant("outline_size", control, 0)
