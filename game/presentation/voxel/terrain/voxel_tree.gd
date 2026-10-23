class_name VoxelTree
extends RefCounted

## Cached silhouettes, then varied in height, width and rotation at each planting.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var crowns: Dictionary[String, ArrayMesh] = {}
var leaf_material: StandardMaterial3D

func build(root: Node3D, shapes: Shapes, species: String, variant: int) -> void:
	root.set_meta("species",species)
	var crown: ArrayMesh = _crown(species,variant)
	var instance := MeshInstance3D.new()
	instance.mesh = crown
	if leaf_material == null:
		leaf_material = StandardMaterial3D.new()
		leaf_material.vertex_color_use_as_albedo = true
		leaf_material.roughness = 0.97
		leaf_material.metallic_specular = 0.08
	instance.material_override = leaf_material
	root.add_child(instance)
	var height: float = 3.2 if species=="pine" else (1.2 if species=="shrub" else 2.6)
	var lean: float = 0.12 if variant%2==0 else -0.09
	shapes.tilted_box(root,Vector3(0,height/2,0),Vector3(0.28,height,0.32),"65553e",Vector3(0,0,lean))
	if species!="pine" and species!="shrub":
		for side: float in [-1.0,1.0]:
			shapes.tilted_box(root,Vector3(side*0.48,height*0.77,0.07),Vector3(1.25,0.19,0.20),"776046",Vector3(0,side*0.2,side*0.50))
	if species=="pine":
		for tier: int in 3:
			shapes.box(root,Vector3(0,1.8+tier*0.85,0),Vector3(1.8-tier*0.4,0.13,0.16),"61513c")

func _crown(species: String, variant: int) -> ArrayMesh:
	var key: String = species+str(variant)
	if crowns.has(key):
		return crowns[key]
	var surface := VoxelCellSurface.new()
	var random := RandomNumberGenerator.new()
	random.seed = 491+variant*73
	var green: Array[String] = ["315645","456b4a","668752","8ba264"]
	match species:
		"pine":
			green = ["244a43","315e50","48775b","6b9068"]
			for tier: int in 4:
				var span: float = 1.4-tier*0.28
				surface.ellipsoid(Vector3(0.13*sin(tier+variant),2.0+tier*0.76,0),Vector3(span,0.69,span*0.86),green,variant+tier)
		"broadleaf":
			for lobe: int in 4:
				var angle: float = lobe*2.2+variant
				surface.ellipsoid(Vector3(cos(angle)*0.73,2.6+random.randf_range(-0.3,0.65),sin(angle)*0.67),Vector3(1.08,0.85,1.0),green,variant+lobe)
		"blossom":
			var pink: Array[String] = ["995e7c","bf7696","df99b1","efb4c4"]
			for lobe: int in 4:
				var angle: float = lobe*2.0+variant*0.4
				surface.ellipsoid(Vector3(cos(angle)*1.02,2.45+lobe*0.23,sin(angle)*0.73),Vector3(0.85+random.randf()*0.25,0.64,0.84),pink,lobe+variant)
		"slender":
			green = ["3d6549","60834e","89a25c","acb86f"]
			for lobe: int in 3:
				surface.ellipsoid(Vector3(0.16*sin(lobe*2.0),2.15+lobe*0.7,0.10*cos(lobe)),Vector3(0.73,1.1,0.70),green,lobe+variant)
		"shrub":
			surface.cell_size = 0.22
			for lobe: int in 3:
				surface.ellipsoid(Vector3((lobe-1)*0.48,0.7+(lobe%2)*0.24,0),Vector3(0.66,0.63,0.62),green,lobe+variant)
	crowns[key] = surface.mesh()
	return crowns[key]
