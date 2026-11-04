class_name TitleSky
extends Control

## The title's sky (DECISIONS「标题画面」): a dusk grade over the 沙盘, clouds that cover the
## screen and part from the sun (拨云见日), and the light — the sun's halo and the shafts that
## fall through gaps in the clouds and between the logo's strokes. Clouds are drawn at half size
## (they are soft) and read back by the light, drawn at a quarter. The wisps in front of the
## logo are a separate control (front()), added above it. The numbers are tweened by TitleScreen.

const CLOUDS: Shader = preload("res://presentation/title/shaders/title_clouds.gdshader")
const RAYS: Shader = preload("res://presentation/title/shaders/title_rays.gdshader")
const WISPS: Shader = preload("res://presentation/title/shaders/title_wisps.gdshader")
const VEIL: Shader = preload("res://presentation/title/shaders/title_veil.gdshader")

## 1: all cloud; 0: parted to what stays.
var cover: float = 1.0
## The radius of the hole that opens round the sun.
var open_r: float = 0.0
## How far the clouds have swollen outward from the sun (negative: closing in).
var push: float = 0.0
## How much cloud stays once the sky is open.
var residual: float = 0.0
## The sun glowing through the cover before it parts.
var dawn: float = 0.25
var rays: float = 0.0
var glow: float = 0.3
## The light flooding the screen as a journey begins.
var flare: float = 0.0
## The front wisps join the cover only as the clouds close (entering the game).
var wisp_close: float = 0.0
## Where the sun stands, in parts of the screen.
var sun: Vector2 = Vector2(0.28, 0.2)
var clock: float = 0.0

var _cloud_view: SubViewport
var _ray_view: SubViewport
var _veil_mat: ShaderMaterial
var _cloud_mat: ShaderMaterial
var _ray_mat: ShaderMaterial
var _wisp_mat: ShaderMaterial
var _front: ColorRect


func _init() -> void:
	name = "TitleSky"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil_mat = _material(VEIL)
	add_child(_rect("Veil", _veil_mat))
	_cloud_view = _viewport("CloudView", true)
	_cloud_mat = _material(CLOUDS)
	_cloud_view.add_child(_paint(_cloud_mat))
	add_child(_shown("Clouds", _cloud_view, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA))
	_ray_view = _viewport("RayView", false)
	_ray_mat = _material(RAYS)
	_ray_mat.set_shader_parameter("cloud_tex", _cloud_view.get_texture())
	_ray_view.add_child(_paint(_ray_mat))
	add_child(_shown("Light", _ray_view, CanvasItemMaterial.BLEND_MODE_ADD))
	_wisp_mat = _material(WISPS)
	_wisp_mat.set_shader_parameter("grain", 1.4)
	_wisp_mat.set_shader_parameter("speed", 2.6)
	_wisp_mat.set_shader_parameter("seed", Vector2(40.0, 13.0))
	_front = _rect("Wisps", _wisp_mat)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## The wisps that drift in front of the logo: TitleScreen adds them above it.
func front() -> Control:
	return _front


## The logo's view: its strokes cut the light into shafts.
func set_logo_texture(texture: Texture2D) -> void:
	_ray_mat.set_shader_parameter("logo_tex", texture)


func cloud_texture() -> Texture2D:
	return _cloud_view.get_texture()


## A bank of cloud under the logo (one of its grounds); 0 = none.
func set_bank(amount: float) -> void:
	_cloud_mat.set_shader_parameter("bank", amount)


func _process(delta: float) -> void:
	clock += delta
	var aspect: float = size.x / maxf(size.y, 1.0)
	for mat: ShaderMaterial in [_cloud_mat, _ray_mat, _wisp_mat]:
		mat.set_shader_parameter("time", clock)
		mat.set_shader_parameter("cover", cover)
		mat.set_shader_parameter("open_r", open_r)
		mat.set_shader_parameter("push", push)
		mat.set_shader_parameter("residual", residual)
		mat.set_shader_parameter("sun", sun)
		mat.set_shader_parameter("aspect", aspect)
	_veil_mat.set_shader_parameter("sun", sun)
	_veil_mat.set_shader_parameter("aspect", aspect)
	_cloud_mat.set_shader_parameter("dawn", dawn)
	_ray_mat.set_shader_parameter("strength", rays)
	_ray_mat.set_shader_parameter("glow", glow)
	_ray_mat.set_shader_parameter("flare", flare)
	_wisp_mat.set_shader_parameter("residual", residual * 0.32)
	_wisp_mat.set_shader_parameter("cover", cover * wisp_close)
	_wisp_mat.set_shader_parameter("opacity", 0.45 + wisp_close * 0.55)
	_wisp_mat.set_shader_parameter("warm", flare * 0.5)


## The cloud and light views follow the window's size (half and a quarter of it).
func _fit() -> void:
	var window: Vector2i = get_tree().root.size.max(Vector2i(64, 64))
	_cloud_view.size = window / 2
	_ray_view.size = window / 4
	for view: SubViewport in [_cloud_view, _ray_view]:
		(view.get_child(0) as Control).size = Vector2(view.size)


static func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _rect(node_name: String, material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


## A view's canvas: sized with the view (_fit), not anchored.
static func _paint(material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Paint"
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _viewport(node_name: String, transparent: bool) -> SubViewport:
	var view := SubViewport.new()
	view.name = node_name
	view.transparent_bg = transparent
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	view.size = Vector2i(640, 360)
	return view


func _shown(node_name: String, view: SubViewport, blend: CanvasItemMaterial.BlendMode) -> TextureRect:
	add_child(view)
	var shown := TextureRect.new()
	shown.name = node_name
	shown.texture = view.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := CanvasItemMaterial.new()
	material.blend_mode = blend
	shown.material = material
	return shown
