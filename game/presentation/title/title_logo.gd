class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): the title in gold leaf — 东方故事 in a brush hand (or
## EASTERN STORIES in capitals, one language at a time) gilded by title_logo.gdshader, a line of
## the other language spaced out under it, a vermilion seal (侠) stamped at its foot, and a soft
## dark oval behind it so the gold stands off the 沙盘. It is drawn into a see-through view of its
## own, whose picture TitleSky reads to cut the sun's shafts between the strokes. TitleScreen
## tweens:
##   write  0 → 1   the gold laid from left to right behind a glowing front, then the line under
##                  it and the seal stamped (ARRIVAL_SECONDS for 0 → 1)
##   glint          a band of light passing over the gold (glint_at: 0 its left, 1 its right)
##   charge         the gold brightening before it goes
##   burn  -0.2 → 1.15  the gold blown away as glittering dust (LEAVING_SECONDS for 0 → 1)

const GOLD: Shader = preload("res://presentation/title/shaders/title_logo.gdshader")
const SEAL: Shader = preload("res://presentation/title/shaders/title_seal.gdshader")
const DIM: Shader = preload("res://presentation/title/shaders/title_dim.gdshader")
const LINE_FONT: FontFile = preload("res://assets/fonts/LXGWWenKaiLite-Medium.ttf")
const ARRIVAL_SECONDS: float = 2.4
const LEAVING_SECONDS: float = 1.5
## Of the 0 → 1 arrival, when the line under the title comes up and when the seal is stamped.
const LINE_AT: Vector2 = Vector2(0.62, 0.92)
const STAMP_AT: Vector2 = Vector2(0.86, 0.98)
## The line under the title: its size (UI pixels at 1280 wide) and the room between its letters
## (parts of its size).
const LINE_SIZE: float = 21.0
const LINE_SPACING: float = 0.55
## The seal's side against the title's height, and how dark the oval behind it gets.
const SEAL_SHARE: float = 0.3
const DIM_STRENGTH: float = 0.7

var write: float = 0.0
var burn: float = -0.2
var charge: float = 0.0
var glint: float = -9.0
## Where the title's middle stands (parts of the screen) and how wide it is (UI pixels at 1280
## wide).
var at: Vector2 = Vector2(0.3, 0.22)
var width_px: float = 660.0

var _view: SubViewport
var _dim: ColorRect
var _letters: TextureRect
var _line: Label
var _seal: TextureRect
var _dust: CPUParticles2D
var _gold: ShaderMaterial
var _seal_mat: ShaderMaterial
var _dim_mat: ShaderMaterial
var _was_burning: bool = false


func _init() -> void:
	name = "TitleLogo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_mat = _material(DIM)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.material = _dim_mat
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_gold = _material(GOLD)
	_letters = _rect("Letters", _gold)
	_seal_mat = _material(SEAL)
	_seal = _rect("Seal", _seal_mat)
	_line = Label.new()
	_line.name = "Line"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_color_override("font_color", Color("e9c77e"))
	_line.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.85))
	_line.add_theme_constant_override("shadow_offset_x", 0)
	_line.add_theme_constant_override("shadow_offset_y", 2)
	_line.add_theme_constant_override("shadow_outline_size", 6)
	_view.add_child(_line)
	_dust = _gold_dust()
	_view.add_child(_dust)


## Gilds `mask_path` (white = ink), stamps the seal of `seal_path` ("" for none) and spaces
## `line` out under it.
func build(mask_path: String, seal_path: String, line: String = "") -> void:
	_letters.texture = _texture(mask_path)
	_gold.set_shader_parameter("mask", _letters.texture)
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
	_gold.set_shader_parameter("write", write)
	_gold.set_shader_parameter("burn", burn)
	_gold.set_shader_parameter("glint", glint)
	_gold.set_shader_parameter("charge", charge)
	var leaving: float = clampf(burn, 0.0, 1.0)
	var line_up: float = smoothstep(LINE_AT.x, LINE_AT.y, write)
	_line.modulate.a = line_up * (1.0 - smoothstep(0.0, 0.5, leaving))
	var stamp: float = clampf((write - STAMP_AT.x) / (STAMP_AT.y - STAMP_AT.x), 0.0, 1.0)
	var settle: float = 1.0 - pow(1.0 - stamp, 3.0)
	_seal.scale = Vector2.ONE * lerpf(1.6, 1.0, settle)
	_seal_mat.set_shader_parameter("fade", stamp * (1.0 - smoothstep(0.3, 0.8, leaving)))
	_dim_mat.set_shader_parameter("strength", DIM_STRENGTH * smoothstep(0.0, 0.5, write) * (1.0 - leaving))
	var burning: bool = burn > 0.0 and burn < 1.0
	if burning and not _was_burning:
		_dust.restart()
	_dust.emitting = burning
	_was_burning = burning


## The view follows the window: the title stands at `at`, `width_px` wide, the line under it, the
## seal at its lower right; the dark oval behind all of it.
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
	var font_size: int = maxi(8, roundi(LINE_SIZE * unit))
	var face := FontVariation.new()
	face.base_font = LINE_FONT
	face.spacing_glyph = roundi(font_size * LINE_SPACING)
	_line.add_theme_font_override("font", face)
	_line.add_theme_font_size_override("font_size", font_size)
	_line.size = Vector2(size_px.x, font_size * 1.6)
	_line.position = Vector2(_letters.position.x, _letters.position.y + size_px.y * 0.86)
	var side: float = size_px.y * SEAL_SHARE
	_seal.size = Vector2(side, side)
	_seal.pivot_offset = _seal.size / 2.0
	_seal.position = _letters.position + Vector2(size_px.x * 0.94 - side * 0.3, size_px.y * 0.72 - side * 0.5)
	_dust.position = middle
	_dust.emission_rect_extents = size_px * 0.42
	_dust.scale_amount_min = 1.5 * unit
	_dust.scale_amount_max = 4.0 * unit
	var to_ui: Vector2 = size / screen
	var reach := Vector2(size_px.x * 1.35, size_px.y * 2.4)
	_dim.position = (middle - reach / 2.0) * to_ui
	_dim.size = reach * to_ui


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


## The gold blown off the title as it goes: glittering flakes drifting up and away.
static func _gold_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.emitting = false
	dust.amount = 220
	dust.lifetime = 1.8
	dust.explosiveness = 0.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.direction = Vector2(0.6, -1.0)
	dust.spread = 35.0
	dust.gravity = Vector2(30.0, -40.0)
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 110.0
	dust.angular_velocity_min = -180.0
	dust.angular_velocity_max = 180.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	ramp.set_color(1, Color(0.9, 0.55, 0.2, 0.0))
	dust.color_ramp = ramp
	return dust


static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
