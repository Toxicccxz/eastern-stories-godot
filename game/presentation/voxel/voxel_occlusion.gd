class_name VoxelOcclusion
extends RefCounted

## Only the pixels between a subject and the fixed camera open, as a screen-door pattern of
## dots (owner 2026-11-10, after pixel-art games' dithered see-through). The rest of each
## object, its collision and its shadow remain intact. State belongs to this map.
const SHADER = preload("res://presentation/voxel/shaders/local_occlusion.gdshader")
const LIMIT: int = 16
## The share of an occluder's pixels left out at the heart of an opening (owner 2026-11-10:
## the nearer the middle, the clearer): the inner part over the person is clear, and the dots
## thicken evenly to solid at the rim.
const HOLES: float = 1.0
var materials: Dictionary[String, ShaderMaterial] = {}
var subjects := PackedVector4Array()
var roots: Array[Node3D] = []

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
