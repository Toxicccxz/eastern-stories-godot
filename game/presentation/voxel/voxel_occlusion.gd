class_name VoxelOcclusion
extends RefCounted

## Only the pixels between a subject and the fixed camera open, as a screen-door pattern of
## dots (owner 2026-11-10, after pixel-art games' dithered see-through). The rest of each
## object, its collision and its shadow remain intact. State belongs to this map.
const SHADER = preload("res://presentation/voxel/shaders/local_occlusion.gdshader")
const LIMIT: int = 16
## The share of an occluder's pixels left out at the heart of an opening (owner 2026-11-10:
## the nearer the middle, the clearer; fully clear was a touch too much): over the person two
## dots in sixteen stay, and the dots thicken evenly to solid at the rim.
const HOLES: float = 0.9
var materials: Dictionary[String, ShaderMaterial] = {}
var subjects := PackedVector4Array()
var roots: Array[Node3D] = []
## 战斗演出 (owner, 2026-11-12: the gorge's walls hid a stage raised in it): a show's space — a
## fight's stage over the map, from its foot to over the fighters' heads — that every occluder
## standing in it or between it and the eye gives way to outright, with a rim of dots
## (occlusion_mask: show_reveal). Empty: none.
var show: Dictionary = {}
## Materials that are no occluder but give way to the show too (the meadow's grass).
var _sharing: Array[ShaderMaterial] = []

func register(root: Node3D) -> void:
	roots.append(root)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MultiMeshInstance3D or node is MeshInstance3D):
			continue
		var mesh := node as GeometryInstance3D
		var original := mesh.material_override as StandardMaterial3D
		if original == null:
			continue
		var emission: Color = original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK
		var key: String = original.albedo_color.to_html()+str(original.vertex_color_use_as_albedo)+emission.to_html()+str(original.get_meta("night_only",false))
		if not materials.has(key):
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("tint", original.albedo_color)
			material.set_shader_parameter("vertex_tint",original.vertex_color_use_as_albedo)
			material.set_shader_parameter("emission_tint",emission)
			material.set_shader_parameter("night_only",original.get_meta("night_only",false))
			material.set_shader_parameter("holes",HOLES)
			_show_on(material)
			materials[key] = material
		# The opening's dots must not punch holes in sunlight shadows as the player moves.
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var shadow: GeometryInstance3D
			if mesh is MultiMeshInstance3D:
				shadow = MultiMeshInstance3D.new()
				(shadow as MultiMeshInstance3D).multimesh = (mesh as MultiMeshInstance3D).multimesh
			else:
				shadow = MeshInstance3D.new()
				(shadow as MeshInstance3D).mesh = (mesh as MeshInstance3D).mesh
			shadow.material_override = original
			shadow.transform = mesh.transform
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mesh.get_parent().add_child(shadow)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override = materials[key]

## Holds the show's space: `stage` the stage's transform in the world (its middle and foot, its
## turn), `footprint` in its own frame (units; x along its x, y along its z) and `low` .. `high`
## its height over the foot.
func hold_show(stage: Transform3D, footprint: Rect2, low: float, high: float) -> void:
	show = {"inverse": Projection(stage.affine_inverse()), "box": Vector4(footprint.position.x, footprint.position.y, footprint.end.x, footprint.end.y), "span": Vector2(low, high)}
	for material: ShaderMaterial in materials.values():
		_show_on(material)
	for material: ShaderMaterial in _sharing:
		_show_on(material)

## The show is over: every occluder whole again (but where a person opens it).
func clear_show() -> void:
	show = {}
	for material: ShaderMaterial in materials.values():
		_show_on(material)
	for material: ShaderMaterial in _sharing:
		_show_on(material)

## `material` (its shader includes show_space) gives way to the show as the occluders do.
func share_show(material: ShaderMaterial) -> void:
	if material != null and not _sharing.has(material):
		_sharing.append(material)
		_show_on(material)

func _show_on(material: ShaderMaterial) -> void:
	material.set_shader_parameter("show_on", 0.0 if show.is_empty() else 1.0)
	if not show.is_empty():
		material.set_shader_parameter("show_inverse", show["inverse"])
		material.set_shader_parameter("show_box", show["box"])
		material.set_shader_parameter("show_span", show["span"])

func set_night(amount: float) -> void:
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("night_amount",amount)

func update(camera: Camera3D, points: PackedVector4Array) -> void:
	subjects = points.slice(0, LIMIT)
	var padded: PackedVector4Array = subjects.duplicate()
	padded.resize(LIMIT)
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("eye_right", camera.global_basis.x)
		material.set_shader_parameter("eye_up", camera.global_basis.y)
		material.set_shader_parameter("toward_eye", camera.global_basis.z)
		material.set_shader_parameter("subjects", padded)
		material.set_shader_parameter("subject_count", subjects.size())
