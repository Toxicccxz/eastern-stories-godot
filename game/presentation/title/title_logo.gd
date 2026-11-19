class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): the title lettered in ink — 东方故事 brushed, every
## character its own size (or EASTERN STORIES in capitals; one language leads at a time) — flat,
## no relief: black ink written on the clouds, turned paper white by a band of light as the
## clouds part; a vermilion seal (侠) stamped at its foot; the other language spaced out under it
## to the lettering's own width; and a dusk down the left of the screen behind it and the menu.
## It is drawn into a see-through view of its own, whose picture TitleSky reads to cut the sun's
## shafts between the strokes. TitleScreen tweens:
##   write  0 → 1   the ink soaking in, left to right (INK_SECONDS), the line under it coming up,
##                  then the seal stamped down with a small rebound (ARRIVAL_SECONDS for 0 → 1)
##   lit    0 → 1   the light crossing: black ink to white, the dusk coming in behind
##   glint          a band of gold passing over the lettering (glint_at: 0 its left, 1 its right)
##   charge         the lettering brightening before it goes
##   burn  -0.2 → 1.15  the ink lifting off as smoke (LEAVING_SECONDS for 0 → 1)

const INK: Shader = preload("res://presentation/title/shaders/title_logo.gdshader")
const SEAL: Shader = preload("res://presentation/title/shaders/title_seal.gdshader")
const DIM: Shader = preload("res://presentation/title/shaders/title_dim.gdshader")
## The line under the title: Cinzel for Latin letters (EASTERN STORIES), 霞鹜文楷 for Chinese.
const LINE_FONT: FontFile = preload("res://assets/fonts/LXGWWenKaiLite-Medium.ttf")
const LINE_ROMAN: FontFile = preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const LINE_ROMAN_WEIGHT: int = 500
## The arrival's beats, in seconds: the writing, the line under the title coming up, the seal's
## stamp (down from 1.6 times its size to 0.96, then settling to 1).
const INK_SECONDS: float = 1.3
const LINE_SECONDS: Vector2 = Vector2(1.0, 1.45)
const STAMP_FROM: float = 1.4
const STAMP_SECONDS: float = 0.18
const SETTLE_SECONDS: float = 0.08
const ARRIVAL_SECONDS: float = 1.7
const LEAVING_SECONDS: float = 1.0
## The line under the title: its size against the lettering's height (Latin capitals under brush
## characters; characters under a line of capitals), with a floor in UI pixels at 1280 wide; how
## much of the lettering's width it is spaced out to, and the most room between two letters (parts
## of its size); the gap above it.
const LINE_SHARE: float = 0.19
const LINE_SHARE_UNDER_CAPITALS: float = 0.62
const LINE_MIN: float = 22.0
const LINE_WIDE: float = 0.94
const LINE_SPACE_MOST: float = 1.4
const LINE_GAP: float = 0.1
## The seal's side against the lettering's height, the room between it and the last letter (UI
## pixels at 1280 wide), and where its middle stands down the lettering (0 top, 1 foot).
const SEAL_SHARE: float = 0.27
const SEAL_GAP: float = 6.0
const SEAL_DOWN: float = 0.8
## The seal's mask is padded; its square fills this much of it (title_seal.gdshader's inset).
const SEAL_FILL: float = 0.76
## The lettering masks' clear border (tools/ui/bake_title_logo.gd PAD), in mask pixels.
const MASK_PAD: float = 48.0
const INK_BLACK := Color(0.075, 0.065, 0.06)
const PAPER_WHITE := Color(0.96, 0.93, 0.87)

var write: float = 0.0
var lit: float = 0.0
var burn: float = -0.2
var charge: float = 0.0
var glint: float = -9.0
## Where the lettering's middle stands (parts of the screen) and how wide its mask is (UI pixels
## at 1280 wide).
var at: Vector2 = Vector2(0.276, 0.21)
var width_px: float = 560.0

var _view: SubViewport
var _dim: ColorRect
var _letters: TextureRect
var _line: Label
var _seal: TextureRect
var _smoke: CPUParticles2D
var _ink: ShaderMaterial
var _seal_mat: ShaderMaterial
var _dim_mat: ShaderMaterial
var _line_at: Vector2 = Vector2.ZERO
var _was_leaving: bool = false


func _init() -> void:
	name = "TitleLogo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_mat = _material(DIM)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.material = _dim_mat
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_view = SubViewport.new()
	_view.name = "LogoView"
	_view.transparent_bg = true
	_view.disable_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_view)
	var shown := TextureRect.new()
	shown.name = "Shown"
	shown.texture = _view.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var premul := CanvasItemMaterial.new()
	premul.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	shown.material = premul
	add_child(shown)
	_ink = _material(INK)
	_letters = _rect("Letters", _ink)
	_seal_mat = _material(SEAL)
	_seal = _rect("Seal", _seal_mat)
	_line = Label.new()
	_line.name = "Line"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_constant_override("shadow_offset_x", 0)
	_line.add_theme_constant_override("shadow_offset_y", 2)
	_line.add_theme_constant_override("shadow_outline_size", 6)
	_view.add_child(_line)
	_smoke = _ink_smoke()
	_view.add_child(_smoke)


## Letters `mask_path` (red = ink, green = the ink blurred wide), stamps the seal of `seal_path`
## ("" for none) and spaces `line` out under it. `brushed`: the lettering is brush calligraphy
## (its dry streaks show).
func build(mask_path: String, seal_path: String, line: String = "", brushed: bool = true) -> void:
	_letters.texture = _texture(mask_path)
	_ink.set_shader_parameter("mask", _letters.texture)
	_ink.set_shader_parameter("dry", 1.0 if brushed else 0.0)
	_seal.texture = _texture(seal_path)
	_seal.visible = _seal.texture != null
	_line.text = line
	_place()


func texture() -> Texture2D:
	return _view.get_texture()


## The glint's place across the title: 0 its left, 1 its right.
func glint_at(part: float) -> float:
	return part


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()


func _process(_delta: float) -> void:
	var t: float = write * ARRIVAL_SECONDS
	_ink.set_shader_parameter("write", clampf(t / INK_SECONDS, 0.0, 1.0))
	_ink.set_shader_parameter("lit", lit)
	_ink.set_shader_parameter("burn", burn)
	_ink.set_shader_parameter("glint", glint)
	_ink.set_shader_parameter("charge", charge)
	var leaving: float = clampf(burn, 0.0, 1.0)
	# The line: up with a small rise, black on the clouds and white once the light has passed.
	var line_up: float = smoothstep(LINE_SECONDS.x, LINE_SECONDS.y, t)
	var white: float = smoothstep(0.3, 0.8, lit)
	_line.modulate = Color(INK_BLACK.lerp(PAPER_WHITE, white), line_up * (1.0 - smoothstep(0.0, 0.5, leaving)))
	_line.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.7 * white))
	_line.position = _line_at + Vector2(0.0, (1.0 - line_up) * 8.0)
	var down: float = clampf((t - STAMP_FROM) / STAMP_SECONDS, 0.0, 1.0)
	var settle: float = clampf((t - STAMP_FROM - STAMP_SECONDS) / SETTLE_SECONDS, 0.0, 1.0)
	var scale_now: float = lerpf(1.6, 0.96, down * down) if down < 1.0 else lerpf(0.96, 1.0, smoothstep(0.0, 1.0, settle))
	_seal.scale = Vector2.ONE * scale_now
	_seal_mat.set_shader_parameter("fade", smoothstep(0.0, 0.35, down) * (1.0 - smoothstep(0.2, 0.7, leaving)))
	# The dusk comes with the light and stays until the smoke has gone.
	_dim_mat.set_shader_parameter("strength", smoothstep(0.0, 1.0, lit) * (1.0 - smoothstep(0.85, 1.15, burn)))
	var going: bool = burn > 0.0 and burn < 1.0
	if going and not _was_leaving:
		_smoke.restart()
	_smoke.emitting = going
	_was_leaving = going


## The view follows the window: the lettering stands at `at`, `width_px` wide, the line under it
## spaced to its width, the seal by its last letter's foot.
func _place() -> void:
	if not is_inside_tree():
		return
	var window: Vector2i = get_tree().root.size.max(Vector2i(64, 64))
	_view.size = window
	var screen := Vector2(window)
	var unit: float = screen.x / 1280.0
	var letters: Texture2D = _letters.texture
	if letters == null:
		return
	var size_px := Vector2(width_px * unit, width_px * unit * letters.get_height() / letters.get_width())
	var middle: Vector2 = at * screen
	_letters.size = size_px
	_letters.position = middle - size_px / 2.0
	# The ink's own box inside the padded mask.
	var pad: Vector2 = Vector2(MASK_PAD, MASK_PAD) * size_px.x / letters.get_width()
	var ink_left: float = _letters.position.x + pad.x
	var ink_top: float = _letters.position.y + pad.y
	var ink_wide: float = size_px.x - pad.x * 2.0
	var ink_tall: float = size_px.y - pad.y * 2.0
	var latin: bool = _latin(_line.text)
	var font_size: int = maxi(8, roundi(maxf(ink_tall * (LINE_SHARE if latin else LINE_SHARE_UNDER_CAPITALS), LINE_MIN * unit)))
	var face := FontVariation.new()
	face.base_font = LINE_ROMAN if latin else LINE_FONT
	if latin:
		face.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): LINE_ROMAN_WEIGHT}
	# Spaced out to the lettering's width (never tighter than the font's own setting).
	var natural: float = face.get_string_size(_line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gaps: int = maxi(1, _line.text.length() - 1)
	face.spacing_glyph = clampi(roundi((ink_wide * LINE_WIDE - natural) / gaps), 0, roundi(font_size * LINE_SPACE_MOST))
	_line.add_theme_font_override("font", face)
	_line.add_theme_font_size_override("font_size", font_size)
	_line.size = Vector2(ink_wide, font_size * 1.6)
	# The last gap trails the last letter: half of it back, so the letters sit centred.
	_line_at = Vector2(ink_left + face.spacing_glyph / 2.0, ink_top + ink_tall + maxf(ink_tall * LINE_GAP, font_size * 0.3))
	_line.position = _line_at
	var square: float = ink_tall * SEAL_SHARE
	var side: float = square / SEAL_FILL
	_seal.size = Vector2(side, side)
	_seal.pivot_offset = _seal.size / 2.0
	_seal.position = Vector2(ink_left + ink_wide + SEAL_GAP * unit + square / 2.0, ink_top + ink_tall * SEAL_DOWN) - _seal.size / 2.0
	_smoke.position = middle
	_smoke.emission_rect_extents = Vector2(ink_wide, ink_tall) * 0.5
	_smoke.scale_amount_min = 10.0 * unit / 32.0
	_smoke.scale_amount_max = 26.0 * unit / 32.0


func _rect(node_name: String, mat: ShaderMaterial) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.material = mat
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(rect)
	return rect


## What the lettering leaves as it goes: soft pale wisps drifting up and away. Their size is set
## in _place (a wisp's texture is 32 pixels across).
static func _ink_smoke() -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.emitting = false
	smoke.amount = 90
	smoke.lifetime = 1.3
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	smoke.texture = dot
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.direction = Vector2(0.5, -1.0)
	smoke.spread = 30.0
	smoke.gravity = Vector2(14.0, -26.0)
	smoke.initial_velocity_min = 12.0
	smoke.initial_velocity_max = 46.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(PAPER_WHITE, 0.0))
	ramp.add_point(0.25, Color(PAPER_WHITE, 0.3))
	ramp.set_color(ramp.get_point_count() - 1, Color(PAPER_WHITE, 0.0))
	smoke.color_ramp = ramp
	return smoke


## Whether `text` is all Latin letters (it is set in Cinzel, else in 霞鹜文楷).
static func _latin(text: String) -> bool:
	for i: int in text.length():
		if text.unicode_at(i) > 0x24F:
			return false
	return true


static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
