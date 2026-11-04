class_name GameTheme
extends Theme

## The interface's look (界面重做 / 像素界面, DECISIONS「界面样式」「像素界面」): old, used
## materials from UiBlocks in UiPalette's colours — ebony planks in chipped, iron-bound frames,
## iron buttons with rust and hack marks, bronze gone green, worn red lacquer, torn paper —
## and every text in one pixel face. Controls take a type variation for their role instead of
## colours of their own:
##   labels   TitleLabel, HeadingLabel, MutedLabel, SmallLabel, WarningLabel, KeyCap
##   panels   PanelContainer (an iron-bound ebony panel), WellPanel (a recess), PlatePanel (a
##            lacquer name plate), ToastPanel (a small cracked board)
##   buttons  Button (an iron plate that sinks when pressed), PrimaryButton (worn vermilion
##            lacquer), DangerButton (dark lacquer), ChipButton (bronze), RowButton (a list
##            row, a board only when chosen), SlotButton (an iron-banded board), ToggleButton
##            (a choice that stays chosen: lacquer while down), TabButton (a page's tab)
##   menu     MenuWindow (the game menu's window: a panel with room inside)
##   world    HudCard (the status card), DialoguePanel (the talk box), PaperPanel (a speech
##            bubble: a torn scrap), BannerPanel (the arrival banner, a room's text) with
##            PlaceCaption (a place's name), VerdictGood / VerdictEven / VerdictBad (the fight
##            forecast's word as a little plate); bars through dress_bar()
## Focus is a lantern-yellow rim (and FocusCursor's bobbing arrow beside it).
##
## 像素界面: every text in 缝合像素 12 px, drawn at 18 logical pixels (one font pixel GRID = 1.5
## logical pixels, a whole number of screen pixels at the snapped scale,
## ApplicationUiScale.pixel_factor) or twice that for titles; the materials on the same grid
## (PixelBox). A glyph the pixel face lacks comes from 霞鹜文楷.

const PIXEL_FONT_PATH: String = "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"
## The text face (the project theme's default font): the same pixel face.
const BODY_FONT_PATH: String = PIXEL_FONT_PATH
## Glyphs the pixel face lacks.
const FALLBACK_FONT_PATH: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"
## The brush hand (志莽行书): only the fight's end stamp keeps it.
const BRUSH_FONT_PATH: String = "res://assets/fonts/ZhiMangXing-Regular.ttf"
const GRID: float = UiBlocks.GRID
## Titles: two font pixels a grid pixel (3 logical); PIXEL_STEP is one of their pixels.
const PIXEL_SIZE: int = 36
const PIXEL_STEP: int = 3
const BODY_SIZE: int = 18
const SMALL_SIZE: int = 18
## A button's text room: raised (three texels of edge and the shadow under its face) and
## pressed (the face two texels lower), the same height so nothing moves but the face.
const BUTTON_PAD := Vector4(16, 6, 16, 9)
const SUNK_PAD := Vector4(16, 9, 16, 6)
const KIND := UiBlocks.Kind

static var _shared: GameTheme


## One built theme for every user (it draws its materials once).
static func shared() -> GameTheme:
	if _shared == null:
		_shared = GameTheme.new()
	return _shared


## A size the pixel face is crisp at for one asked in the old way: a whole number of its
## 18-logical-pixel steps, the nearest (never none).
static func text_size(asked: int) -> int:
	return BODY_SIZE * maxi(1, roundi(float(asked) / float(BODY_SIZE)))


## The pixel face, aliased and unhinted so its grid stays square; a glyph it lacks comes
## from 霞鹜文楷.
static func pixel_font() -> FontFile:
	var font: FontFile = load(PIXEL_FONT_PATH) as FontFile
	if font != null and font.antialiasing != TextServer.FONT_ANTIALIASING_NONE:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
	if font != null and font.fallbacks.is_empty():
		font.fallbacks = [load(FALLBACK_FONT_PATH) as Font]
	return font


static var _text_font: FontVariation


## The interface's text face: the pixel face with its line trimmed to 21 px at 18 (it carries
## 3–4 px of leading; 霞鹜文楷's line was 22), so every layout keeps its rhythm. Titles use the
## pixel face itself.
static func text_font() -> FontVariation:
	if _text_font == null:
		_text_font = FontVariation.new()
		_text_font.base_font = pixel_font()
		_text_font.spacing_top = -2
		_text_font.spacing_bottom = -2
	return _text_font


func _init() -> void:
	var pixel: FontFile = pixel_font()
	default_font = text_font()
	default_font_size = BODY_SIZE
	set_color("font_color", "Label", UiPalette.BONE)
	set_constant("line_spacing", "Label", 3)
	set_color("default_color", "RichTextLabel", UiPalette.BONE)
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		set_font_size(key, "RichTextLabel", BODY_SIZE)
	_label(&"TitleLabel", UiPalette.GOLD, PIXEL_SIZE, pixel)
	set_color("font_shadow_color", &"TitleLabel", UiPalette.SIDE_LIGHT)
	set_constant("shadow_offset_x", &"TitleLabel", 0)
	set_constant("shadow_offset_y", &"TitleLabel", PIXEL_STEP)
	_label(&"HeadingLabel", UiPalette.GOLD, BODY_SIZE)
	_label(&"MutedLabel", UiPalette.MUTED, 0)
	_label(&"SmallLabel", UiPalette.MUTED, SMALL_SIZE)
	_label(&"WarningLabel", UiPalette.WARNING, 0)
	_label(&"KeyCap", UiPalette.INK, BODY_SIZE)
	set_stylebox("normal", &"KeyCap", _mat(KIND.BONE, UiPalette.BONE_TILE, UiPalette.BONE_TILE_SIDE, 12, 10, 4, 2, 31, Vector4(6, 1, 6, 4), false))
	_panels()
	_buttons(&"Button", KIND.IRON, UiPalette.IRON, UiPalette.IRON_SIDE, UiPalette.BONE, 41)
	_variation(&"PrimaryButton", &"Button")
	_buttons(&"PrimaryButton", KIND.LACQUER, UiPalette.LACQUER, UiPalette.LACQUER_SIDE, Color("ffe9c2"), 43)
	_variation(&"DangerButton", &"Button")
	_buttons(&"DangerButton", KIND.LACQUER, UiPalette.DANGER, UiPalette.DANGER_SIDE, UiPalette.WARNING, 47)
	_variation(&"ChipButton", &"Button")
	_buttons(&"ChipButton", KIND.BRONZE, UiPalette.BRONZE, UiPalette.BRONZE_SIDE, UiPalette.BONE, 53)
	# A choice that stays chosen (性别): chosen, it is lacquer and stays down.
	_variation(&"ToggleButton", &"Button")
	_buttons(&"ToggleButton", KIND.IRON, UiPalette.IRON, UiPalette.IRON_SIDE, UiPalette.BONE, 41)
	var chosen: StyleBox = _plate(KIND.LACQUER, UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 1, 2, 43, SUNK_PAD)
	set_stylebox("pressed", &"ToggleButton", chosen)
	set_stylebox("hover_pressed", &"ToggleButton", chosen)
	set_color("font_pressed_color", &"ToggleButton", Color("ffe9c2"))
	set_color("font_hover_pressed_color", &"ToggleButton", Color("ffe9c2"))
	_rows()
	_menu()
	_title(pixel)
	_world()
	_fields()
	_option_button()
	_check_button()
	_popup()
	_scroll()
	_tooltip()


func _variation(name: StringName, base: StringName) -> void:
	set_type_variation(name, base)


func _label(name: StringName, colour: Color, size: int, font: Font = null) -> void:
	_variation(name, &"Label")
	set_color("font_color", name, colour)
	if size > 0:
		set_font_size("font_size", name, size)
	if font != null:
		set_font("font", name, font)


## A material box: `kind` with `face` over `side`, a `w`×`h` face (texels) with `margin`
## corners and `depth` of edge under it.
func _mat(kind: int, face: Color, side: Color, w: int, h: int, margin: int, depth: int, seed: int, content: Vector4, marked: bool = true, frame: int = 0, fittings: bool = false, sunk: int = 0, modulate: Color = Color.WHITE) -> PixelBox:
	var made: UiBlocks.Spec = UiBlocks.spec(kind, face, side, w, h, margin, depth, seed)
	made.frame = frame
	made.fittings = fittings
	made.sunk = sunk
	return UiBlocks.material(made, content, 3, marked, modulate)


## A window: ebony planks in a frame, iron at its corners.
func _window(seed: int, content: Vector4, modulate: Color = Color.WHITE) -> PixelBox:
	var box: PixelBox = _mat(KIND.WOOD, UiPalette.EBONY, UiPalette.EBONY_SIDE, 192, 128, 18, 4, 11, content, true, 5, true, 0, modulate)
	# Every window shares the images; its marks are its own.
	box.mark_seed = seed
	return box


## A small plate or button of `kind`: `depth` of edge, `sunk` rows lower (pressed).
func _plate(kind: int, face: Color, side: Color, depth: int, sunk: int, seed: int, content: Vector4, fittings: bool = true) -> PixelBox:
	return _mat(kind, face, side, 48, 20, 5, depth, seed, content, true, 0, fittings, sunk)


func _panels() -> void:
	set_stylebox("panel", "PanelContainer", _window(11, Vector4(8, 8, 8, 14)))
	_variation(&"WellPanel", &"PanelContainer")
	set_stylebox("panel", &"WellPanel", UiBlocks.box(UiBlocks.well_image(UiPalette.WELL.lerp(UiPalette.EBONY, 0.3), 48, 32), Vector4i(3, 3, 3, 3), Vector4(14, 12, 14, 12), true))
	_variation(&"PlatePanel", &"PanelContainer")
	set_stylebox("panel", &"PlatePanel", _mat(KIND.LACQUER, UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 32, 18, 5, 3, 61, Vector4(12, 4, 12, 9), true, 0, true))
	_variation(&"ToastPanel", &"PanelContainer")
	set_stylebox("panel", &"ToastPanel", _mat(KIND.WOOD, UiPalette.EBONY.lerp(UiPalette.INK, 0.3), UiPalette.EBONY_SIDE, 64, 20, 5, 2, 67, Vector4(12, 7, 12, 10)))


func _buttons(kind_name: StringName, kind: int, top: Color, side: Color, text: Color, seed: int) -> void:
	set_stylebox("normal", kind_name, _plate(kind, top, side, 3, 0, seed, BUTTON_PAD))
	set_stylebox("hover", kind_name, _plate(kind, top.lightened(0.12), side, 3, 0, seed, BUTTON_PAD))
	set_stylebox("pressed", kind_name, _plate(kind, top.darkened(0.08), side, 1, 2, seed, SUNK_PAD))
	set_stylebox("hover_pressed", kind_name, get_stylebox("pressed", kind_name))
	set_stylebox("disabled", kind_name, _plate(kind, top.lerp(UiPalette.INK, 0.55), side.lerp(UiPalette.INK, 0.55), 3, 0, seed, BUTTON_PAD))
	set_stylebox("focus", kind_name, UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		set_color(state, kind_name, text)
	set_color("font_disabled_color", kind_name, UiPalette.DIM)
	set_color("font_shadow_color", kind_name, Color(0, 0, 0, 0.45))
	set_constant("shadow_offset_y", kind_name, 2)
	set_font_size("font_size", kind_name, BODY_SIZE)


## A list row is flat until chosen: hovered it is a dark board, chosen (pressed) a warm one.
## A save slot is an iron-banded board, warmer when hovered.
func _rows() -> void:
	var row_pad := Vector4(30, 8, 12, 8)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = row_pad.x
	flat.content_margin_top = row_pad.y
	flat.content_margin_right = row_pad.z
	flat.content_margin_bottom = row_pad.w
	_variation(&"RowButton", &"Button")
	set_stylebox("normal", &"RowButton", flat)
	set_stylebox("disabled", &"RowButton", flat)
	set_stylebox("hover", &"RowButton", _mat(KIND.WOOD, UiPalette.EBONY.lightened(0.1), UiPalette.EBONY_SIDE, 64, 20, 5, 1, 71, row_pad))
	var chosen: PixelBox = _mat(KIND.WOOD, Color("5a3a22"), Color("2e1d10"), 64, 20, 5, 1, 71, row_pad)
	for state: String in ["pressed", "hover_pressed"]:
		set_stylebox(state, &"RowButton", chosen)
	set_stylebox("focus", &"RowButton", UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		set_color(state, &"RowButton", UiPalette.BONE)
	set_color("font_pressed_color", &"RowButton", UiPalette.LANTERN)
	set_color("font_hover_pressed_color", &"RowButton", UiPalette.LANTERN)
	set_color("font_disabled_color", &"RowButton", UiPalette.DIM)
	set_font_size("font_size", &"RowButton", BODY_SIZE)
	_variation(&"SlotButton", &"Button")
	var slot_pad := Vector4(30, 10, 16, 12)
	var slot_sunk := Vector4(30, 13, 16, 9)
	var board: Color = UiPalette.EBONY.lightened(0.06)
	set_stylebox("normal", &"SlotButton", _mat(KIND.WOOD, board, UiPalette.EBONY_SIDE, 64, 22, 6, 3, 79, slot_pad, true, 0, true))
	set_stylebox("hover", &"SlotButton", _mat(KIND.WOOD, Color("4a3220"), Color("24170e"), 64, 22, 6, 3, 79, slot_pad, true, 0, true))
	set_stylebox("pressed", &"SlotButton", _mat(KIND.WOOD, Color("5a3a22"), Color("2e1d10"), 64, 22, 6, 1, 79, slot_sunk, true, 0, true, 2))
	set_stylebox("hover_pressed", &"SlotButton", get_stylebox("pressed", &"SlotButton"))
	set_stylebox("disabled", &"SlotButton", _mat(KIND.WOOD, board.lerp(UiPalette.INK, 0.5), UiPalette.EBONY_SIDE, 64, 22, 6, 3, 79, slot_pad, true, 0, true))
	set_stylebox("focus", &"SlotButton", UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		set_color(state, &"SlotButton", UiPalette.BONE)
	set_color("font_disabled_color", &"SlotButton", UiPalette.DIM)
	set_font_size("font_size", &"SlotButton", BODY_SIZE)


## The game menu (DECISIONS「界面样式」): its window a panel with room inside, its tabs flat
## until hovered (a dark board) or shown (a plank, ink letters), a thin rule.
func _menu() -> void:
	_variation(&"MenuWindow", &"PanelContainer")
	set_stylebox("panel", &"MenuWindow", _window(13, Vector4(18, 14, 18, 22)))
	_variation(&"TabButton", &"Button")
	var tab_pad := Vector4(12, 6, 12, 9)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = tab_pad.x
	flat.content_margin_right = tab_pad.z
	flat.content_margin_top = tab_pad.y
	flat.content_margin_bottom = tab_pad.w
	set_stylebox("normal", &"TabButton", flat)
	set_stylebox("disabled", &"TabButton", flat)
	set_stylebox("hover", &"TabButton", _mat(KIND.WOOD, UiPalette.EBONY.lightened(0.12), UiPalette.EBONY_SIDE, 32, 20, 5, 2, 83, tab_pad))
	var shown: PixelBox = _mat(KIND.WOOD, UiPalette.PLANK, UiPalette.WOOD_SIDE, 32, 20, 5, 2, 83, tab_pad)
	for state: String in ["pressed", "hover_pressed"]:
		set_stylebox(state, &"TabButton", shown)
	set_stylebox("focus", &"TabButton", UiBlocks.rim())
	set_color("font_color", &"TabButton", UiPalette.MUTED)
	set_color("font_hover_color", &"TabButton", UiPalette.BONE)
	set_color("font_focus_color", &"TabButton", UiPalette.BONE)
	set_color("font_pressed_color", &"TabButton", UiPalette.INK)
	set_color("font_hover_pressed_color", &"TabButton", UiPalette.INK)
	set_color("font_disabled_color", &"TabButton", UiPalette.DIM)
	set_font_size("font_size", &"TabButton", BODY_SIZE)


## The world's surfaces (界面重做 3): the status card a panel a little see-through, the talk box
## a deeper one, a speech bubble a torn scrap of paper, the banner and a room's text a cracked
## dark board, the fight forecast's word on a jade, stone or lacquer plate.
func _world() -> void:
	_variation(&"HudCard", &"PanelContainer")
	set_stylebox("panel", &"HudCard", _window(17, Vector4(16, 12, 16, 16), Color(1, 1, 1, 0.95)))
	# Touch screens: narrower sides, so five 64 px buttons fit a row at 480 px.
	_variation(&"HudCardTouch", &"PanelContainer")
	set_stylebox("panel", &"HudCardTouch", _window(17, Vector4(10, 10, 10, 14), Color(1, 1, 1, 0.95)))
	_variation(&"DialoguePanel", &"PanelContainer")
	set_stylebox("panel", &"DialoguePanel", _window(19, Vector4(26, 18, 26, 24)))
	_variation(&"PaperPanel", &"PanelContainer")
	set_stylebox("panel", &"PaperPanel", _mat(KIND.PAPER, UiPalette.PAPER, UiPalette.PAPER_SIDE, 64, 20, 5, 2, 97, Vector4(10, 5, 10, 8)))
	_variation(&"BannerPanel", &"PanelContainer")
	set_stylebox("panel", &"BannerPanel", _mat(KIND.WOOD, UiPalette.INK.lerp(UiPalette.EBONY, 0.4), UiPalette.EBONY_SIDE, 80, 24, 6, 2, 101, Vector4(18, 10, 18, 14), true, 0, false, 0, Color(1, 1, 1, 0.9)))
	for entry: Array in [[&"VerdictGood", Color("3f7a5a"), Color("234a35"), 103], [&"VerdictEven", UiPalette.STONE, UiPalette.STONE_SIDE, 107], [&"VerdictBad", UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 109]]:
		_variation(entry[0], &"PanelContainer")
		set_stylebox("panel", entry[0], _mat(KIND.LACQUER, entry[1], entry[2], 16, 10, 4, 2, entry[3], Vector4(8, 1, 8, 6), false))
	_label(&"PaperLabel", UiPalette.INK, BODY_SIZE)
	# A place's name as one arrives: the title's pixel size, a dark side under it.
	_label(&"PlaceCaption", Color("fff3dc"), PIXEL_SIZE)
	set_color("font_shadow_color", &"PlaceCaption", Color(0, 0, 0, 0.45))
	set_constant("shadow_offset_y", &"PlaceCaption", PIXEL_STEP)
	_label(&"NameLabel", UiPalette.LANTERN, BODY_SIZE)


## A bar in the interface's way: square, on a dark groove, its fill a block with a darker
## side under it (精气神, a wait, a run's progress).
static func dress_bar(bar: ProgressBar, colour: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = UiPalette.INK
	track.border_width_top = 2
	track.border_color = Color(0, 0, 0, 0.45)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.border_width_bottom = maxi(2, int(bar.custom_minimum_size.y / 3.0))
	fill.border_color = colour.darkened(0.4)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false


## The forecast's plate for `verdict` (CombatForecast.Verdict): jade for a win, dark lacquer
## for a loss, stone between.
static func verdict_plate(verdict: int) -> StringName:
	if verdict <= CombatForecast.Verdict.FAVOURED:
		return &"VerdictGood"
	if verdict >= CombatForecast.Verdict.UNFAVOURED:
		return &"VerdictBad"
	return &"VerdictEven"


## The title (DECISIONS「标题画面」): its menu buttons are flat with their own text clear
## (TitleMenuFx draws voxel letters over them), a place's name in the pixel face ringed dark,
## the menu's panel is bare.
func _title(pixel: FontFile) -> void:
	_variation(&"TitleMenuItem", &"Button")
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = 14
	bare.content_margin_right = 12
	bare.content_margin_top = 6
	bare.content_margin_bottom = 9
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		set_stylebox(state, &"TitleMenuItem", bare)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_shadow_color"]:
		set_color(state, &"TitleMenuItem", Color(0, 0, 0, 0))
	set_font("font", &"TitleMenuItem", pixel)
	set_font_size("font_size", &"TitleMenuItem", PIXEL_SIZE)
	_label(&"TitleMenuLetters", UiPalette.LETTER, PIXEL_SIZE, pixel)
	_label(&"TitleCaption", Color("fff3dc"), PIXEL_SIZE, pixel)
	set_color("font_outline_color", &"TitleCaption", Color(0.08, 0.05, 0.04, 0.85))
	set_constant("outline_size", &"TitleCaption", 6)
	set_color("font_shadow_color", &"TitleCaption", Color(0, 0, 0, 0.35))
	set_constant("shadow_offset_y", &"TitleCaption", PIXEL_STEP)
	_variation(&"BarePanel", &"PanelContainer")
	set_stylebox("panel", &"BarePanel", StyleBoxEmpty.new())


func _fields() -> void:
	var well := UiBlocks.box(UiBlocks.well_image(UiPalette.WELL), Vector4i(3, 3, 3, 3), Vector4(12, 8, 12, 8), true)
	set_stylebox("normal", "LineEdit", well)
	set_stylebox("read_only", "LineEdit", well)
	set_stylebox("focus", "LineEdit", UiBlocks.rim())
	set_color("font_color", "LineEdit", UiPalette.BONE)
	set_color("font_placeholder_color", "LineEdit", UiPalette.DIM)
	set_color("caret_color", "LineEdit", UiPalette.LANTERN)
	set_color("selection_color", "LineEdit", Color(UiPalette.LACQUER, 0.6))
	set_font_size("font_size", "LineEdit", BODY_SIZE)


func _option_button() -> void:
	_buttons(&"OptionButton", KIND.IRON, UiPalette.IRON, UiPalette.IRON_SIDE, UiPalette.BONE, 113)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBox = get_stylebox(state, &"OptionButton").duplicate() as StyleBox
		style.content_margin_right = 34
		set_stylebox(state, &"OptionButton", style)
	var arrow := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	for y: int in 4:
		for x: int in range(y, 7 - y):
			arrow.set_pixel(x, y, UiPalette.BONE)
	set_icon("arrow", &"OptionButton", UiBlocks.icon(arrow))
	set_constant("arrow_margin", &"OptionButton", 12)


func _check_button() -> void:
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	flat.content_margin_top = 4
	flat.content_margin_bottom = 4
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		set_stylebox(state, &"CheckButton", flat)
	set_stylebox("focus", &"CheckButton", UiBlocks.rim())
	set_icon("checked", &"CheckButton", UiBlocks.icon(UiBlocks.switch_image(true)))
	set_icon("unchecked", &"CheckButton", UiBlocks.icon(UiBlocks.switch_image(false)))
	set_icon("checked_disabled", &"CheckButton", UiBlocks.icon(UiBlocks.switch_image(true, true)))
	set_icon("unchecked_disabled", &"CheckButton", UiBlocks.icon(UiBlocks.switch_image(false, true)))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		set_color(state, &"CheckButton", UiPalette.BONE)
	set_color("font_disabled_color", &"CheckButton", UiPalette.DIM)
	set_font_size("font_size", &"CheckButton", BODY_SIZE)


func _popup() -> void:
	set_stylebox("panel", "PopupMenu", _mat(KIND.WOOD, UiPalette.EBONY, UiPalette.EBONY_SIDE, 48, 20, 5, 2, 127, Vector4(6, 6, 6, 10)))
	set_stylebox("hover", "PopupMenu", _mat(KIND.WOOD, UiPalette.WOOD, UiPalette.WOOD_SIDE, 24, 10, 4, 1, 131, Vector4(8, 4, 8, 4), false))
	set_color("font_color", "PopupMenu", UiPalette.BONE)
	set_color("font_hover_color", "PopupMenu", Color("fff6dc"))
	set_color("font_disabled_color", "PopupMenu", UiPalette.DIM)
	set_font_size("font_size", "PopupMenu", BODY_SIZE)
	set_constant("v_separation", "PopupMenu", 9)


func _scroll() -> void:
	var track := UiBlocks.box(UiBlocks.well_image(UiPalette.WELL, 6, 8), Vector4i(2, 2, 2, 2), Vector4(4, 4, 4, 4))
	var grab: PixelBox = _mat(KIND.IRON, UiPalette.IRON, UiPalette.IRON_SIDE, 8, 10, 3, 1, 137, Vector4(4, 4, 4, 4), false)
	var lit: PixelBox = _mat(KIND.IRON, UiPalette.IRON.lightened(0.15), UiPalette.IRON_SIDE, 8, 10, 3, 1, 137, Vector4(4, 4, 4, 4), false)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		set_stylebox("scroll", bar, track)
		set_stylebox("grabber", bar, grab)
		set_stylebox("grabber_highlight", bar, lit)
		set_stylebox("grabber_pressed", bar, lit)


func _tooltip() -> void:
	set_stylebox("panel", "TooltipPanel", get_stylebox("panel", &"ToastPanel"))
	set_color("font_color", "TooltipLabel", UiPalette.BONE)
	set_font_size("font_size", "TooltipLabel", SMALL_SIZE)
