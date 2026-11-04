class_name GameTheme
extends Theme

## The interface's look (像素界面, DECISIONS「像素界面」): parchment materials from UiBlocks in
## UiPalette's colours, all text in one pixel face. Controls take a type variation for their
## role instead of colours of their own:
##   labels   TitleLabel, HeadingLabel, MutedLabel, SmallLabel, WarningLabel, KeyCap
##   panels   PanelContainer (a parchment sheet), WellPanel (a recess), PlatePanel (a lacquer
##            name plate), ToastPanel (a small parchment plate)
##   buttons  Button (a parchment pill that sinks when pressed), PrimaryButton (vermilion
##            lacquer), DangerButton (dark lacquer), ChipButton (stone), RowButton (a list
##            row, a pill only when chosen), SlotButton (a save slot), ToggleButton (a
##            choice that stays chosen: lacquer while down), TabButton (a page's tab)
##   menu     MenuWindow (the game menu's window: a sheet with room inside)
##   world    HudCard (the status card), DialoguePanel (the talk box), PaperPanel (a speech
##            bubble: bare, its letters ringed), BannerPanel (the arrival banner, a room's
##            text) with PlaceCaption (a place's name), VerdictGood / VerdictEven /
##            VerdictBad (the fight forecast's word as a little plate); bars through
##            dress_bar()
## Focus is a deep red rim (and FocusCursor's bobbing arrow beside it).

## 像素界面 (DECISIONS「像素界面」): every text in 缝合像素 12 px, drawn at 18 logical pixels (one
## font pixel GRID = 1.5 logical pixels, a whole number of screen pixels at the snapped scale,
## ApplicationUiScale.pixel_factor) or twice that for titles; frames on the same grid
## (UiBlocks, PixelBox). A glyph the pixel face lacks comes from 霞鹜文楷.
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
## A button's text room: raised (three pixels of shade and the shadow under its face) and
## pressed (one), the same height so nothing moves but the face.
const BUTTON_PAD := Vector4(16, 6, 16, 11)
const SUNK_PAD := Vector4(16, 9, 16, 8)

static var _shared: GameTheme


## One built theme for every user (it draws its block textures once).
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


func _init() -> void:
	var pixel: FontFile = pixel_font()
	default_font = pixel
	default_font_size = BODY_SIZE
	set_color("font_color", "Label", UiPalette.BONE)
	set_constant("line_spacing", "Label", 3)
	set_color("default_color", "RichTextLabel", UiPalette.BONE)
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		set_font_size(key, "RichTextLabel", BODY_SIZE)
	_label(&"TitleLabel", UiPalette.GOLD, PIXEL_SIZE, pixel)
	_label(&"HeadingLabel", UiPalette.GOLD, BODY_SIZE)
	_label(&"MutedLabel", UiPalette.MUTED, 0)
	_label(&"SmallLabel", UiPalette.MUTED, SMALL_SIZE)
	_label(&"WarningLabel", UiPalette.WARNING, 0)
	_label(&"KeyCap", UiPalette.LIGHT_TEXT, BODY_SIZE)
	set_stylebox("normal", &"KeyCap", UiBlocks.block(Color("5a4733"), Color("2e2319"), 1, Vector4(7, 2, 7, 6)))
	_panels()
	_buttons(&"Button", UiPalette.WOOD, UiPalette.WOOD_SIDE, UiPalette.BONE)
	_variation(&"PrimaryButton", &"Button")
	_buttons(&"PrimaryButton", UiPalette.LACQUER, UiPalette.LACQUER_SIDE, UiPalette.LIGHT_TEXT)
	_variation(&"DangerButton", &"Button")
	_buttons(&"DangerButton", UiPalette.DANGER, UiPalette.DANGER_SIDE, Color("ffd2bf"))
	_variation(&"ChipButton", &"Button")
	_buttons(&"ChipButton", UiPalette.STONE, UiPalette.STONE_SIDE, UiPalette.BONE)
	# A choice that stays chosen (性别): chosen, it is lacquer and stays down.
	_variation(&"ToggleButton", &"Button")
	_buttons(&"ToggleButton", UiPalette.WOOD, UiPalette.WOOD_SIDE, UiPalette.BONE)
	var chosen: StyleBox = UiBlocks.block(UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 1, SUNK_PAD)
	set_stylebox("pressed", &"ToggleButton", chosen)
	set_stylebox("hover_pressed", &"ToggleButton", chosen)
	set_color("font_pressed_color", &"ToggleButton", UiPalette.LIGHT_TEXT)
	set_color("font_hover_pressed_color", &"ToggleButton", UiPalette.LIGHT_TEXT)
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


func _panels() -> void:
	set_stylebox("panel", "PanelContainer", _sheet(UiPalette.EBONY, Vector4(18, 15, 18, 18)))
	_variation(&"WellPanel", &"PanelContainer")
	set_stylebox("panel", &"WellPanel", UiBlocks.box(UiBlocks.well_image(UiPalette.WELL), Vector4i(3, 3, 3, 3), Vector4(14, 12, 14, 12)))
	_variation(&"PlatePanel", &"PanelContainer")
	set_stylebox("panel", &"PlatePanel", UiBlocks.box(UiBlocks.slab_image(UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 2, false, 12, 10), Vector4i(3, 3, 3, 6), Vector4(12, 5, 12, 10)))
	_variation(&"ToastPanel", &"PanelContainer")
	set_stylebox("panel", &"ToastPanel", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY, UiPalette.WOOD_SIDE, 1, false, 12, 10), Vector4i(3, 3, 3, 5), Vector4(12, 6, 12, 9)))


## A parchment sheet (a window): outline, frame band, inner line, mottled face, shadow.
func _sheet(face: Color, content: Vector4) -> StyleBox:
	return UiBlocks.box(UiBlocks.slab_image(face, face.darkened(0.25), 0, true, 32, 32), Vector4i(6, 6, 6, 7), content, true)


func _buttons(kind: StringName, top: Color, side: Color, text: Color) -> void:
	set_stylebox("normal", kind, UiBlocks.block(top, side, 3, BUTTON_PAD))
	set_stylebox("hover", kind, UiBlocks.block(top.lightened(0.1), side, 3, BUTTON_PAD))
	set_stylebox("pressed", kind, UiBlocks.block(top.darkened(0.06), side, 1, SUNK_PAD))
	set_stylebox("hover_pressed", kind, UiBlocks.block(top.darkened(0.06), side, 1, SUNK_PAD))
	set_stylebox("disabled", kind, UiBlocks.block(top.lerp(UiPalette.WELL, 0.6), side.lerp(UiPalette.WELL, 0.6), 3, BUTTON_PAD))
	set_stylebox("focus", kind, UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		set_color(state, kind, text)
	set_color("font_disabled_color", kind, UiPalette.DIM)
	set_color("font_shadow_color", kind, Color(0, 0, 0, 0))
	set_font_size("font_size", kind, BODY_SIZE)


## A list row is flat until chosen: hovered it is a dark block, chosen (pressed) a warm one.
## A save slot is always a block, warmer when hovered.
func _rows() -> void:
	var row_pad := Vector4(30, 7, 12, 9)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = row_pad.x
	flat.content_margin_top = row_pad.y
	flat.content_margin_right = row_pad.z
	flat.content_margin_bottom = row_pad.w
	_variation(&"RowButton", &"Button")
	set_stylebox("normal", &"RowButton", flat)
	set_stylebox("disabled", &"RowButton", flat)
	set_stylebox("hover", &"RowButton", UiBlocks.block(UiPalette.EBONY.darkened(0.05), UiPalette.EBONY.darkened(0.18), 1, row_pad))
	for state: String in ["pressed", "hover_pressed"]:
		set_stylebox(state, &"RowButton", UiBlocks.block(UiPalette.PLANK, UiPalette.PLANK.darkened(0.22), 1, row_pad))
	set_stylebox("focus", &"RowButton", UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		set_color(state, &"RowButton", UiPalette.BONE)
	set_color("font_pressed_color", &"RowButton", UiPalette.GOLD)
	set_color("font_hover_pressed_color", &"RowButton", UiPalette.GOLD)
	set_color("font_disabled_color", &"RowButton", UiPalette.DIM)
	set_font_size("font_size", &"RowButton", BODY_SIZE)
	_variation(&"SlotButton", &"Button")
	var slot_pad := Vector4(30, 10, 16, 14)
	var slot_sunk := Vector4(30, 13, 16, 11)
	set_stylebox("normal", &"SlotButton", UiBlocks.block(UiPalette.WOOD, UiPalette.WOOD_SIDE, 3, slot_pad))
	set_stylebox("hover", &"SlotButton", UiBlocks.block(UiPalette.WOOD.lightened(0.1), UiPalette.WOOD_SIDE, 3, slot_pad))
	set_stylebox("pressed", &"SlotButton", UiBlocks.block(UiPalette.PLANK, UiPalette.PLANK.darkened(0.22), 1, slot_sunk))
	set_stylebox("hover_pressed", &"SlotButton", get_stylebox("pressed", &"SlotButton"))
	set_stylebox("disabled", &"SlotButton", UiBlocks.block(UiPalette.WOOD.lerp(UiPalette.WELL, 0.6), UiPalette.WOOD_SIDE.lerp(UiPalette.WELL, 0.6), 3, slot_pad))
	set_stylebox("focus", &"SlotButton", UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		set_color(state, &"SlotButton", UiPalette.BONE)
	set_color("font_disabled_color", &"SlotButton", UiPalette.DIM)
	set_font_size("font_size", &"SlotButton", BODY_SIZE)


## The game menu (DECISIONS「界面样式」): its window a planked ebony slab with room inside, its
## tabs flat until hovered (a dark block) or shown (a plank block, ink letters), a thin rule.
func _menu() -> void:
	_variation(&"MenuWindow", &"PanelContainer")
	set_stylebox("panel", &"MenuWindow", _sheet(UiPalette.EBONY, Vector4(22, 18, 22, 22)))
	_variation(&"TabButton", &"Button")
	var tab_pad := Vector4(12, 6, 12, 9)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = tab_pad.x
	flat.content_margin_right = tab_pad.z
	flat.content_margin_top = tab_pad.y
	flat.content_margin_bottom = tab_pad.w
	set_stylebox("normal", &"TabButton", flat)
	set_stylebox("disabled", &"TabButton", flat)
	set_stylebox("hover", &"TabButton", UiBlocks.block(UiPalette.EBONY.darkened(0.05), UiPalette.EBONY.darkened(0.18), 1, tab_pad))
	for state: String in ["pressed", "hover_pressed"]:
		set_stylebox(state, &"TabButton", UiBlocks.block(UiPalette.WOOD, UiPalette.WOOD_SIDE, 2, tab_pad))
	set_stylebox("focus", &"TabButton", UiBlocks.rim())
	set_color("font_color", &"TabButton", UiPalette.MUTED)
	set_color("font_hover_color", &"TabButton", UiPalette.BONE)
	set_color("font_focus_color", &"TabButton", UiPalette.BONE)
	set_color("font_pressed_color", &"TabButton", UiPalette.GOLD)
	set_color("font_hover_pressed_color", &"TabButton", UiPalette.GOLD)
	set_color("font_disabled_color", &"TabButton", UiPalette.DIM)
	set_font_size("font_size", &"TabButton", BODY_SIZE)


## The world's surfaces (界面重做 3): the status card a planked ebony slab a little see-through,
## the talk box a deeper one, a speech bubble paper on a darker edge, the banner and a room's
## text a dark plate, the fight forecast's word on a jade, stone or dark-lacquer plate.
func _world() -> void:
	_variation(&"HudCard", &"PanelContainer")
	set_stylebox("panel", &"HudCard", _sheet(Color(UiPalette.EBONY, 0.97), Vector4(18, 15, 18, 17)))
	# Touch screens: narrower sides, so five 64 px buttons fit a row at 480 px.
	_variation(&"HudCardTouch", &"PanelContainer")
	set_stylebox("panel", &"HudCardTouch", _sheet(Color(UiPalette.EBONY, 0.97), Vector4(12, 12, 12, 15)))
	_variation(&"DialoguePanel", &"PanelContainer")
	set_stylebox("panel", &"DialoguePanel", _sheet(UiPalette.EBONY, Vector4(30, 21, 30, 24)))
	# A said line floats over the speaker's head, light letters ringed dark (no paper).
	_variation(&"PaperPanel", &"PanelContainer")
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = 4
	bare.content_margin_right = 4
	bare.content_margin_top = 2
	bare.content_margin_bottom = 2
	set_stylebox("panel", &"PaperPanel", bare)
	_variation(&"BannerPanel", &"PanelContainer")
	set_stylebox("panel", &"BannerPanel", _sheet(Color(UiPalette.EBONY, 0.96), Vector4(20, 14, 20, 16)))
	for entry: Array in [[&"VerdictGood", Color("3f7a5a"), Color("234a35")], [&"VerdictEven", Color("6f7a80"), Color("454d52")], [&"VerdictBad", UiPalette.LACQUER, UiPalette.LACQUER_SIDE]]:
		_variation(entry[0], &"PanelContainer")
		set_stylebox("panel", entry[0], UiBlocks.box(UiBlocks.slab_image(entry[1], entry[2], 2, false, 10, 8), Vector4i(3, 3, 3, 6), Vector4(8, 2, 8, 8)))
	_label(&"PaperLabel", UiPalette.LIGHT_TEXT, BODY_SIZE)
	set_color("font_outline_color", &"PaperLabel", Color(UiPalette.INK, 0.9))
	set_constant("outline_size", &"PaperLabel", 4)
	# A place's name as one arrives: the title size, on the banner's parchment.
	_label(&"PlaceCaption", UiPalette.GOLD, PIXEL_SIZE)
	_label(&"NameLabel", UiPalette.LIGHT_TEXT, BODY_SIZE)


## A bar in the interface's way: square, on a dark groove, its fill a block with a darker
## side under it (精气神, a wait, a run's progress).
static func dress_bar(bar: ProgressBar, colour: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = UiPalette.OUTLINE
	track.border_width_top = 2
	track.border_color = Color(0, 0, 0, 0.35)
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
## (TitleMenuFx draws voxel letters over them), a place's name is in the brush hand, the menu's
## panel is bare.
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
	var well := UiBlocks.box(UiBlocks.well_image(UiPalette.WELL), Vector4i(3, 3, 3, 3), Vector4(12, 8, 12, 8))
	set_stylebox("normal", "LineEdit", well)
	set_stylebox("read_only", "LineEdit", well)
	set_stylebox("focus", "LineEdit", UiBlocks.rim())
	set_color("font_color", "LineEdit", UiPalette.BONE)
	set_color("font_placeholder_color", "LineEdit", UiPalette.DIM)
	set_color("caret_color", "LineEdit", UiPalette.FOCUS)
	set_color("selection_color", "LineEdit", Color(UiPalette.LACQUER, 0.35))
	set_font_size("font_size", "LineEdit", BODY_SIZE)


func _option_button() -> void:
	_buttons(&"OptionButton", UiPalette.WOOD, UiPalette.WOOD_SIDE, UiPalette.BONE)
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
	set_stylebox("panel", "PopupMenu", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY, UiPalette.WOOD_SIDE, 1, false, 16, 12), Vector4i(3, 3, 3, 5), Vector4(8, 8, 8, 10)))
	set_stylebox("hover", "PopupMenu", UiBlocks.block(UiPalette.PLANK, UiPalette.PLANK.darkened(0.22), 1, Vector4(8, 4, 8, 4)))
	set_color("font_color", "PopupMenu", UiPalette.BONE)
	set_color("font_hover_color", "PopupMenu", UiPalette.GOLD)
	set_color("font_disabled_color", "PopupMenu", UiPalette.DIM)
	set_font_size("font_size", "PopupMenu", BODY_SIZE)
	set_constant("v_separation", "PopupMenu", 9)


func _scroll() -> void:
	var track := UiBlocks.box(UiBlocks.well_image(UiPalette.WELL, 6, 8), Vector4i(2, 2, 2, 2), Vector4(4, 4, 4, 4))
	var grab := UiBlocks.block(UiPalette.WOOD_SIDE, UiPalette.WOOD_SIDE.darkened(0.25), 1, Vector4(4, 4, 4, 4))
	var lit := UiBlocks.block(UiPalette.PLANK.darkened(0.1), UiPalette.WOOD_SIDE.darkened(0.25), 1, Vector4(4, 4, 4, 4))
	for bar: String in ["VScrollBar", "HScrollBar"]:
		set_stylebox("scroll", bar, track)
		set_stylebox("grabber", bar, grab)
		set_stylebox("grabber_highlight", bar, lit)
		set_stylebox("grabber_pressed", bar, lit)


func _tooltip() -> void:
	set_stylebox("panel", "TooltipPanel", get_stylebox("panel", &"ToastPanel"))
	set_color("font_color", "TooltipLabel", UiPalette.BONE)
	set_font_size("font_size", "TooltipLabel", SMALL_SIZE)
