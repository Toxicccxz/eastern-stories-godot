class_name GameTheme
extends Theme

## The interface's look (界面重做, DECISIONS「界面样式」): block materials from UiBlocks in
## UiPalette's colours, the body text in 霞鹜文楷 (the project theme's default font) and titles
## in 方舟像素 16 px drawn as voxel letters (a face over two darker side layers). Controls take
## a type variation for their role instead of colours of their own:
##   labels   TitleLabel, HeadingLabel, MutedLabel, SmallLabel, WarningLabel, KeyCap
##   panels   PanelContainer (an ebony slab), WellPanel (a recess), PlatePanel (a lacquer
##            name plate), ToastPanel (a small dark plate)
##   buttons  Button (a wood block that sinks when pressed), PrimaryButton (vermilion
##            lacquer), DangerButton (dark lacquer), ChipButton (stone), RowButton (a list
##            row, a block only when chosen), SlotButton (a save slot), ToggleButton (a
##            choice that stays chosen: lacquer while down), TabButton (a page's tab)
##   menu     MenuWindow (the game menu's window: a slab with room inside)
## Focus is a lantern-yellow rim (and FocusCursor's bobbing arrow beside it).

const PIXEL_FONT_PATH: String = "res://assets/fonts/ark-pixel-16px-proportional-zh_cn.otf"
## The text face (the project theme's default font).
const BODY_FONT_PATH: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"
## The pixel face's grid is 16 px; drawn at 32 logical px every grid pixel is 2 logical
## pixels, so a whole number of screen pixels at every 16:9 window (3 at 1920×1080).
const PIXEL_SIZE: int = 32
const PIXEL_STEP: int = 2
const BODY_SIZE: int = 18
const SMALL_SIZE: int = 15

static var _shared: GameTheme


## One built theme for every user (it draws its block textures once).
static func shared() -> GameTheme:
	if _shared == null:
		_shared = GameTheme.new()
	return _shared


## The pixel face, aliased and unhinted so its grid stays square; a glyph it lacks (its 16 px
## set is still small) comes from 霞鹜文楷.
static func pixel_font() -> FontFile:
	var font: FontFile = load(PIXEL_FONT_PATH) as FontFile
	if font != null and font.antialiasing != TextServer.FONT_ANTIALIASING_NONE:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
	if font != null and font.fallbacks.is_empty():
		font.fallbacks = [load(BODY_FONT_PATH) as Font]
	return font


func _init() -> void:
	var pixel: FontFile = pixel_font()
	set_color("font_color", "Label", UiPalette.BONE)
	set_constant("line_spacing", "Label", 3)
	_label(&"TitleLabel", UiPalette.GOLD, PIXEL_SIZE, pixel)
	set_color("font_shadow_color", &"TitleLabel", UiPalette.SIDE_LIGHT)
	set_constant("shadow_offset_x", &"TitleLabel", 0)
	set_constant("shadow_offset_y", &"TitleLabel", PIXEL_STEP)
	_label(&"HeadingLabel", UiPalette.GOLD, 20)
	_label(&"MutedLabel", UiPalette.MUTED, 0)
	_label(&"SmallLabel", UiPalette.MUTED, SMALL_SIZE)
	_label(&"WarningLabel", UiPalette.WARNING, 0)
	_label(&"KeyCap", UiPalette.INK, 14)
	set_stylebox("normal", &"KeyCap", UiBlocks.block(Color("d8cdb6"), Color("8f8574"), 2, Vector4(6, 1, 6, 4)))
	_panels()
	_buttons(&"Button", UiPalette.WOOD, UiPalette.WOOD_SIDE, UiPalette.BONE)
	_variation(&"PrimaryButton", &"Button")
	_buttons(&"PrimaryButton", UiPalette.LACQUER, UiPalette.LACQUER_SIDE, Color("ffe9c2"))
	_variation(&"DangerButton", &"Button")
	_buttons(&"DangerButton", UiPalette.DANGER, UiPalette.DANGER_SIDE, UiPalette.WARNING)
	_variation(&"ChipButton", &"Button")
	_buttons(&"ChipButton", UiPalette.STONE, UiPalette.STONE_SIDE, UiPalette.BONE)
	# A choice that stays chosen (性别): chosen, it is lacquer and stays down.
	_variation(&"ToggleButton", &"Button")
	_buttons(&"ToggleButton", UiPalette.WOOD, UiPalette.WOOD_SIDE, UiPalette.BONE)
	var chosen: StyleBoxTexture = UiBlocks.block(UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 1, Vector4(16, 8, 16, 7))
	set_stylebox("pressed", &"ToggleButton", chosen)
	set_stylebox("hover_pressed", &"ToggleButton", chosen)
	set_color("font_pressed_color", &"ToggleButton", Color("ffe9c2"))
	set_color("font_hover_pressed_color", &"ToggleButton", Color("ffe9c2"))
	_rows()
	_menu()
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
	set_stylebox("panel", "PanelContainer", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY, UiPalette.EBONY_SIDE, 4, true, 32, 26), Vector4i(4, 4, 4, 8), Vector4(8, 8, 8, 14), true))
	_variation(&"WellPanel", &"PanelContainer")
	set_stylebox("panel", &"WellPanel", UiBlocks.box(UiBlocks.well_image(UiPalette.INK.lerp(UiPalette.EBONY, 0.4)), Vector4i(3, 3, 3, 3), Vector4(14, 12, 14, 12)))
	_variation(&"PlatePanel", &"PanelContainer")
	set_stylebox("panel", &"PlatePanel", UiBlocks.box(UiBlocks.slab_image(UiPalette.LACQUER, UiPalette.LACQUER_SIDE, 3, false, 12, 10), Vector4i(2, 2, 2, 5), Vector4(12, 4, 12, 9)))
	_variation(&"ToastPanel", &"PanelContainer")
	set_stylebox("panel", &"ToastPanel", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY.lerp(UiPalette.INK, 0.3), UiPalette.EBONY_SIDE, 2, false, 12, 10), Vector4i(2, 2, 2, 4), Vector4(12, 7, 12, 10)))


func _buttons(kind: StringName, top: Color, side: Color, text: Color) -> void:
	var pad := Vector4(16, 6, 16, 9)
	var sunk := Vector4(16, 8, 16, 7)
	set_stylebox("normal", kind, UiBlocks.block(top, side, 3, pad))
	set_stylebox("hover", kind, UiBlocks.block(top.lightened(0.12), side, 3, pad))
	set_stylebox("pressed", kind, UiBlocks.block(top.darkened(0.08), side, 1, sunk))
	set_stylebox("hover_pressed", kind, UiBlocks.block(top.darkened(0.08), side, 1, sunk))
	set_stylebox("disabled", kind, UiBlocks.block(top.lerp(UiPalette.INK, 0.6), side.lerp(UiPalette.INK, 0.6), 3, pad))
	set_stylebox("focus", kind, UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		set_color(state, kind, text)
	set_color("font_disabled_color", kind, UiPalette.DIM)
	set_color("font_shadow_color", kind, Color(0, 0, 0, 0.35))
	set_constant("shadow_offset_y", kind, 1)
	set_font_size("font_size", kind, BODY_SIZE)


## A list row is flat until chosen: hovered it is a dark block, chosen (pressed) a warm one.
## A save slot is always a block, warmer when hovered.
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
	set_stylebox("hover", &"RowButton", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY.lightened(0.1), UiPalette.EBONY_SIDE, 2, false, 12, 10), Vector4i(2, 2, 2, 4), row_pad))
	for state: String in ["pressed", "hover_pressed"]:
		set_stylebox(state, &"RowButton", UiBlocks.box(UiBlocks.slab_image(Color("5a3a22"), Color("2e1d10"), 2, false, 12, 10), Vector4i(2, 2, 2, 4), row_pad))
	set_stylebox("focus", &"RowButton", UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		set_color(state, &"RowButton", UiPalette.BONE)
	set_color("font_pressed_color", &"RowButton", UiPalette.LANTERN)
	set_color("font_hover_pressed_color", &"RowButton", UiPalette.LANTERN)
	set_color("font_disabled_color", &"RowButton", UiPalette.DIM)
	set_font_size("font_size", &"RowButton", BODY_SIZE)
	_variation(&"SlotButton", &"Button")
	var slot_pad := Vector4(30, 10, 16, 12)
	var base: Color = UiPalette.EBONY.lightened(0.06)
	set_stylebox("normal", &"SlotButton", UiBlocks.box(UiBlocks.slab_image(base, UiPalette.EBONY_SIDE, 3, true, 24, 18), Vector4i(3, 3, 3, 6), slot_pad, true))
	set_stylebox("hover", &"SlotButton", UiBlocks.box(UiBlocks.slab_image(Color("4a3220"), Color("24170e"), 3, true, 24, 18), Vector4i(3, 3, 3, 6), slot_pad, true))
	set_stylebox("pressed", &"SlotButton", UiBlocks.box(UiBlocks.slab_image(Color("5a3a22"), Color("2e1d10"), 1, true, 24, 18), Vector4i(3, 3, 3, 4), slot_pad, true))
	set_stylebox("hover_pressed", &"SlotButton", get_stylebox("pressed", &"SlotButton"))
	set_stylebox("disabled", &"SlotButton", UiBlocks.box(UiBlocks.slab_image(base.lerp(UiPalette.INK, 0.5), UiPalette.EBONY_SIDE, 3, true, 24, 18), Vector4i(3, 3, 3, 6), slot_pad, true))
	set_stylebox("focus", &"SlotButton", UiBlocks.rim())
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		set_color(state, &"SlotButton", UiPalette.BONE)
	set_color("font_disabled_color", &"SlotButton", UiPalette.DIM)
	set_font_size("font_size", &"SlotButton", BODY_SIZE)


## The game menu (DECISIONS「界面样式」): its window a planked ebony slab with room inside, its
## tabs flat until hovered (a dark block) or shown (a plank block, ink letters), a thin rule.
func _menu() -> void:
	_variation(&"MenuWindow", &"PanelContainer")
	set_stylebox("panel", &"MenuWindow", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY, UiPalette.EBONY_SIDE, 4, true, 32, 26), Vector4i(4, 4, 4, 8), Vector4(18, 14, 18, 22), true))
	_variation(&"TabButton", &"Button")
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 6
	flat.content_margin_bottom = 9
	set_stylebox("normal", &"TabButton", flat)
	set_stylebox("disabled", &"TabButton", flat)
	set_stylebox("hover", &"TabButton", UiBlocks.block(UiPalette.EBONY.lightened(0.12), UiPalette.EBONY_SIDE, 3, Vector4(12, 6, 12, 9)))
	for state: String in ["pressed", "hover_pressed"]:
		set_stylebox(state, &"TabButton", UiBlocks.block(UiPalette.PLANK, UiPalette.WOOD_SIDE, 3, Vector4(12, 6, 12, 9)))
	set_stylebox("focus", &"TabButton", UiBlocks.rim())
	set_color("font_color", &"TabButton", UiPalette.MUTED)
	set_color("font_hover_color", &"TabButton", UiPalette.BONE)
	set_color("font_focus_color", &"TabButton", UiPalette.BONE)
	set_color("font_pressed_color", &"TabButton", UiPalette.INK)
	set_color("font_hover_pressed_color", &"TabButton", UiPalette.INK)
	set_color("font_disabled_color", &"TabButton", UiPalette.DIM)
	set_font_size("font_size", &"TabButton", BODY_SIZE)


func _fields() -> void:
	var well := UiBlocks.box(UiBlocks.well_image(UiPalette.INK.lerp(UiPalette.EBONY, 0.4)), Vector4i(3, 3, 3, 3), Vector4(12, 8, 12, 8))
	set_stylebox("normal", "LineEdit", well)
	set_stylebox("read_only", "LineEdit", well)
	set_stylebox("focus", "LineEdit", UiBlocks.rim())
	set_color("font_color", "LineEdit", UiPalette.BONE)
	set_color("font_placeholder_color", "LineEdit", UiPalette.DIM)
	set_color("caret_color", "LineEdit", UiPalette.LANTERN)
	set_color("selection_color", "LineEdit", Color(UiPalette.LACQUER, 0.6))
	set_font_size("font_size", "LineEdit", BODY_SIZE)


func _option_button() -> void:
	_buttons(&"OptionButton", UiPalette.WOOD, UiPalette.WOOD_SIDE, UiPalette.BONE)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBoxTexture = get_stylebox(state, &"OptionButton").duplicate() as StyleBoxTexture
		style.content_margin_right = 34
		set_stylebox(state, &"OptionButton", style)
	var arrow := Image.create_empty(7, 4, false, Image.FORMAT_RGBA8)
	for y: int in 4:
		for x: int in range(y, 7 - y):
			arrow.set_pixel(x, y, UiPalette.BONE)
	arrow.resize(7 * UiBlocks.PX, 4 * UiBlocks.PX, Image.INTERPOLATE_NEAREST)
	set_icon("arrow", &"OptionButton", ImageTexture.create_from_image(arrow))
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
	set_icon("checked", &"CheckButton", ImageTexture.create_from_image(UiBlocks.switch_image(true)))
	set_icon("unchecked", &"CheckButton", ImageTexture.create_from_image(UiBlocks.switch_image(false)))
	set_icon("checked_disabled", &"CheckButton", ImageTexture.create_from_image(UiBlocks.switch_image(true, true)))
	set_icon("unchecked_disabled", &"CheckButton", ImageTexture.create_from_image(UiBlocks.switch_image(false, true)))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		set_color(state, &"CheckButton", UiPalette.BONE)
	set_color("font_disabled_color", &"CheckButton", UiPalette.DIM)
	set_font_size("font_size", &"CheckButton", BODY_SIZE)


func _popup() -> void:
	set_stylebox("panel", "PopupMenu", UiBlocks.box(UiBlocks.slab_image(UiPalette.EBONY, UiPalette.EBONY_SIDE, 3, false, 16, 12), Vector4i(3, 3, 3, 6), Vector4(6, 6, 6, 10)))
	set_stylebox("hover", "PopupMenu", UiBlocks.block(UiPalette.WOOD, UiPalette.WOOD_SIDE, 1, Vector4(8, 4, 8, 4)))
	set_color("font_color", "PopupMenu", UiPalette.BONE)
	set_color("font_hover_color", "PopupMenu", Color("fff6dc"))
	set_color("font_disabled_color", "PopupMenu", UiPalette.DIM)
	set_font_size("font_size", "PopupMenu", BODY_SIZE)
	set_constant("v_separation", "PopupMenu", 8)


func _scroll() -> void:
	var track := UiBlocks.box(UiBlocks.well_image(UiPalette.INK.lerp(UiPalette.EBONY, 0.3), 6, 8), Vector4i(2, 2, 2, 2), Vector4(4, 4, 4, 4))
	var grab := UiBlocks.block(UiPalette.WOOD, UiPalette.WOOD_SIDE, 1, Vector4(4, 4, 4, 4))
	var lit := UiBlocks.block(UiPalette.PLANK, UiPalette.WOOD_SIDE, 1, Vector4(4, 4, 4, 4))
	for bar: String in ["VScrollBar", "HScrollBar"]:
		set_stylebox("scroll", bar, track)
		set_stylebox("grabber", bar, grab)
		set_stylebox("grabber_highlight", bar, lit)
		set_stylebox("grabber_pressed", bar, lit)


func _tooltip() -> void:
	set_stylebox("panel", "TooltipPanel", get_stylebox("panel", &"ToastPanel"))
	set_color("font_color", "TooltipLabel", UiPalette.BONE)
	set_font_size("font_size", "TooltipLabel", SMALL_SIZE)
