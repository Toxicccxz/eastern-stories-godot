class_name TitleLogo
extends Control

## The title's logo (DECISIONS「标题画面」): the title lettered in ink — 东方故事 brushed, every
## character its own size (or EASTERN STORIES in capitals; one language leads at a time) — flat,
## no relief: black ink written on the clouds, turned paper white by a band of light as the
## clouds part; a silk ribbon threaded through it with the title in the other language on it
## (TitleRibbon), its vermilion seal (侠) stamped on the ribbon; and a dusk down the left
## of the screen behind it and the menu.
## It is drawn into a see-through view of its own, whose picture TitleSky reads to cut the sun's
## shafts between the strokes. TitleScreen tweens:
##   write  0 → 1   the ink soaking in, left to right (INK_SECONDS), the ribbon flying in and
##                  threading itself through the lettering (RIBBON_SECONDS), then the seal stamped
##                  down on it with a small rebound (ARRIVAL_SECONDS for 0 → 1)
##   lit    0 → 1   the light crossing: black ink to white, the dusk coming in behind
##   glint          a band of gold passing over the lettering (glint_at: 0 its left, 1 its right)
##   charge         the lettering brightening before it goes
##   burn  -0.2 → 1.15  the ribbon drifting on and fading, the ink lifting off as smoke
##                  (LEAVING_SECONDS for 0 → 1)

const INK: Shader = preload("res://presentation/title/shaders/title_logo.gdshader")
const SEAL: Shader = preload("res://presentation/title/shaders/title_seal.gdshader")
const DIM: Shader = preload("res://presentation/title/shaders/title_dim.gdshader")
## The arrival's beats, in seconds: the writing, the ribbon threading in, the seal's stamp (down from
## 1.6 times its size to 0.96, then settling to 1).
const INK_SECONDS: float = 1.3
const RIBBON_SECONDS: Vector2 = Vector2(0.3, 2.3)
const STAMP_FROM: float = 2.3
const STAMP_SECONDS: float = 0.18
const SETTLE_SECONDS: float = 0.08
const ARRIVAL_SECONDS: float = 2.6
## How much of the leaving the ribbon takes to drift on and fade.
const RIBBON_LEAVING: float = 0.9
const LEAVING_SECONDS: float = 1.0
## The seal against the ribbon's width, and its turn (degrees): stamped on the band where it
## leaves the lettering, like a seal on a letter's fold.
const SEAL_SHARE: float = 0.82
const SEAL_TURN: float = 2.5
## The seal's mask is padded; its square fills this much of it (title_seal.gdshader's inset).
const SEAL_FILL: float = 0.76
## The lettering masks' clear border (tools/ui/bake_title_logo.gd PAD), in mask pixels.
const MASK_PAD: float = 48.0
## How much of the shader's own dry streaks brush lettering gets (the hand has its own rough
## edges; this only adds a little 飞白 inside the strokes).
const DRY: float = 0.45
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
var _ribbon: TitleRibbon
var _seal: TextureRect
var _smoke: CPUParticles2D
var _ink: ShaderMaterial
var _seal_mat: ShaderMaterial
var _dim_mat: ShaderMaterial
var _ink_bottom: float = 0.0
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
	_ribbon = TitleRibbon.new()
	_view.add_child(_ribbon)
	_seal_mat = _material(SEAL)
	_seal = _rect("Seal", _seal_mat)
	_seal.rotation_degrees = SEAL_TURN
	_smoke = _ink_smoke()
	_view.add_child(_smoke)


## Letters `mask_path` (red = ink, green = the ink blurred wide), weaves `ribbon` through its foot
## with `line` on it (or `line_mask`, red = ink, when it is not set in a shipped font), and stamps
## the seal of `seal_path` ("" for none) on the ribbon's twist. `brushed`: the lettering is brush
## calligraphy (its dry streaks show). The line is the title in the other language
## (title_screen.json), never a translation.
func build(mask_path: String, seal_path: String, line: String = "", brushed: bool = true, ribbon: TitleScreenDefinition.Ribbon = null, line_mask: String = "") -> void:
	_letters.texture = _texture(mask_path)
	_ink.set_shader_parameter("mask", _letters.texture)
	_ink.set_shader_parameter("dry", DRY if brushed else 0.0)
	_seal.texture = _texture(seal_path)
	_seal.visible = _seal.texture != null
	_ribbon.config = ribbon if ribbon != null else TitleScreenDefinition.Ribbon.new()
	_ribbon.set_words(line, _texture(line_mask))
	_place()


## The ribbon woven through the lettering.
func ribbon() -> TitleRibbon:
	return _ribbon


## How low the title reaches in the view (pixels): the lettering's ink or the ribbon, whichever is
## lower. The menu stays under it.
func bottom() -> float:
	return maxf(_ribbon.bottom, _ink_bottom)


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
	# The ribbon drifts in, easing to rest; it leaves easing out.
	var arrived: float = clampf((t - RIBBON_SECONDS.x) / (RIBBON_SECONDS.y - RIBBON_SECONDS.x), 0.0, 1.0)
	var gone: float = clampf(leaving / RIBBON_LEAVING, 0.0, 1.0)
	_ribbon.show_part(1.0 - pow(1.0 - arrived, 2.0), smoothstep(0.0, 1.0, gone))
	var down: float = clampf((t - STAMP_FROM) / STAMP_SECONDS, 0.0, 1.0)
	var settle: float = clampf((t - STAMP_FROM - STAMP_SECONDS) / SETTLE_SECONDS, 0.0, 1.0)
	var scale_now: float = lerpf(1.6, 0.96, down * down) if down < 1.0 else lerpf(0.96, 1.0, smoothstep(0.0, 1.0, settle))
	_seal.scale = Vector2.ONE * scale_now
	_seal_mat.set_shader_parameter("fade", smoothstep(0.0, 0.35, down) * (1.0 - smoothstep(0.0, 0.15, leaving)))
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
	place_for(Vector2(window))


## Lays the title out for a window `screen` pixels big. A screen wider than 16:9 (a phone, an
## ultrawide monitor) keeps the title it has at 16:9 for its height, at the left: the extra width
## goes to the 沙盘, and the menu's column stays under the line (owner, 2026-11-20: grown with the
## width, the lettering came down over the menu on a 20:9 phone).
func place_for(screen: Vector2) -> void:
	var box: Vector2 = title_box(screen)
	var unit: float = box.x / 1280.0
	var letters: Texture2D = _letters.texture
	if letters == null:
		return
	var size_px := Vector2(width_px * unit, width_px * unit * letters.get_height() / letters.get_width())
	var middle: Vector2 = at * box
	_letters.size = size_px
	_letters.position = middle - size_px / 2.0
	# The ink's own box inside the padded mask.
	var pad: Vector2 = Vector2(MASK_PAD, MASK_PAD) * size_px.x / letters.get_width()
	var ink_left: float = _letters.position.x + pad.x
	var ink_top: float = _letters.position.y + pad.y
	var ink_wide: float = size_px.x - pad.x * 2.0
	var ink_tall: float = size_px.y - pad.y * 2.0
	_ink_bottom = ink_top + ink_tall
	_ribbon.lay(Rect2(ink_left, ink_top, ink_wide, ink_tall), letters, _letters.get_rect(), screen, unit)
	var side: float = _ribbon.band * SEAL_SHARE / SEAL_FILL
	_seal.size = Vector2(side, side)
	_seal.pivot_offset = _seal.size / 2.0
	# On the band where it leaves the lettering.
	_seal.position = _ribbon.seal_at - _seal.size / 2.0
	_smoke.position = middle
	_smoke.emission_rect_extents = Vector2(ink_wide, ink_tall) * 0.5
	_smoke.scale_amount_min = 10.0 * unit / 32.0
	_smoke.scale_amount_max = 26.0 * unit / 32.0


## The part of a `screen` the title is laid out in: all of it up to 16:9, the 16:9 at its left
## beyond that.
static func title_box(screen: Vector2) -> Vector2:
	return Vector2(minf(screen.x, screen.y * 16.0 / 9.0), screen.y)


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


static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
