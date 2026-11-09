class_name VoxelBackdrop
extends MeshInstance3D

## 战斗演出 D (DECISIONS「战斗演出 D」): the map turned into a backdrop round a show raised over it
## (a fight's stage) — everything in the view outside the show's own space (the stage's footprint,
## from just under its foot up; hold()) shows soft, darker, a little faded and tinted by the show's
## look; whatever stands inside it (the stage and the fighters on it) is untouched. `amount` 0 .. 1
## brings it in (0: not drawn at all). It is drawn after the map's see-through things; the names
## and the fighters' effects over it draw later still (OVER_BACKDROP).
## Presentation only: nothing of the map, a body or a rule changes.

const SHADER: Shader = preload("res://presentation/voxel/shaders/backdrop_veil.gdshader")
## What must show over the backdrop (a name over a head, an afterimage, a parry's arc) draws at
## this priority among the see-through things; the backdrop just under it.
const OVER_BACKDROP: int = Material.RENDER_PRIORITY_MAX

var amount: float = 0.0:
	set(value):
		amount = clampf(value, 0.0, 1.0)
		visible = amount > 0.001
		if _material != null:
			_material.set_shader_parameter("amount", amount)

var _material: ShaderMaterial
var _look_tween: Tween


func _init() -> void:
	name = "Backdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	# The quad covers the screen from any camera (its vertices are placed in clip space).
	extra_cull_margin = 16384.0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = OVER_BACKDROP - 2
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_look({})
	_material.set_shader_parameter("amount", 0.0)


## The show's space: `stage` the stage's transform in the world (its middle, foot and turn), and
## its footprint in its own frame (units; x along its x, y along its z).
func hold(stage: Transform3D, footprint: Rect2) -> void:
	_material.set_shader_parameter("stage_inverse", Projection(stage.affine_inverse()))
	_material.set_shader_parameter("box", Vector4(footprint.position.x, footprint.position.y, footprint.end.x, footprint.end.y))


## The look (battle_stage.json's `backdrop`: tint, darken, fade, blur), over `seconds` (0: at once).
func set_look(look: Dictionary, seconds: float = 0.0) -> void:
	if _look_tween != null and _look_tween.is_valid():
		_look_tween.kill()
	var tint := Color(String(look.get("tint", "ffffff")))
	var values: Dictionary = {
		# A Color, so the engine turns the authored sRGB into linear (source_color).
		"tint": tint,
		"darken": float(look.get("darken", 0.3)),
		"fade": float(look.get("fade", 0.3)),
		"blur_lod": float(look.get("blur_lod", 3.0)),
		"blur_px": float(look.get("blur_px", 6.0)),
	}
	if seconds <= 0.0 or not is_inside_tree():
		for key: String in values:
			_material.set_shader_parameter(key, values[key])
		return
	_look_tween = create_tween().set_parallel(true)
	for key: String in values:
		var from: Variant = _material.get_shader_parameter(key)
		_look_tween.tween_method(func(value: Variant) -> void: _material.set_shader_parameter(key, value), from, values[key], seconds)


## A shader value now (tests).
func parameter(key: String) -> Variant:
	return _material.get_shader_parameter(key)
