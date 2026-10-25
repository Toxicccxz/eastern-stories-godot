class_name VoxelTree
extends RefCounted

## Cached silhouettes, then varied in height, width and rotation at each planting.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const PINES: Array[String] = ["pine","mountain_pine","old_pine","tall_pine","young_pine","stunted_pine"]
var crowns: Dictionary[String, ArrayMesh] = {}
var leaf_material: StandardMaterial3D
## Crown colours by species, dark to light (layout flora `crown_colors`); bark the same
## (flora `bark_colors`). A map without them keeps the defaults below.
var palettes: Dictionary = {}
var barks: Dictionary = {}

## Draws one tree into `parent`. With `crowns` (mesh -> Array of transforms) the crown is
## collected for a grove's shared MultiMesh instead of getting its own instance, and every
## box is placed by `frame`, so a whole grove batches by colour under one parent.
func build(parent: Node3D, shapes: Shapes, species: String, variant: int, frame := Transform3D.IDENTITY, collect: Variant = null) -> void:
	parent.set_meta("species",species)
	# The forest pines come in three shapes each: a forest of them batches into few crowns.
	if species in ["old_pine","tall_pine","young_pine","stunted_pine"]:
		variant %= 3
	shapes.frame = frame
	if species=="dead":
		_dead(parent,shapes,variant)
		shapes.frame = Transform3D.IDENTITY
		return
	var crown: ArrayMesh = _crown(species,variant)
	if collect is Dictionary:
		var grove: Dictionary = collect
		if not grove.has(crown):
			grove[crown] = []
		(grove[crown] as Array).append(frame)
	else:
		var instance := MeshInstance3D.new()
		instance.mesh = crown
		instance.material_override = material()
		instance.transform = frame
		parent.add_child(instance)
	match species:
		"old_pine": _old_pine_wood(parent,shapes,variant)
		"tall_pine": _tall_pine_wood(parent,shapes,variant)
		"young_pine":
			shapes.box(parent,Vector3(0,0.5,0),Vector3(0.14,1.0,0.15),_bark(species,0))
		"stunted_pine":
			var lean: float = 0.16 if variant%2==0 else -0.2
			shapes.tilted_box(parent,Vector3(sin(lean)*1.0,1.0,0),Vector3(0.18,2.0,0.2),_bark(species,0),Vector3(0,0,-lean))
			for stub: int in 2:
				shapes.tilted_box(parent,Vector3(sin(lean)*(0.7+stub*0.5),0.7+stub*0.5,0.1),Vector3(0.05,0.5,0.05),_bark(species,2),Vector3(0.9,stub*2.0,0.4))
		_:
			var height: float = 3.2 if species in ["pine","mountain_pine"] else (1.2 if species in ["shrub","scrub"] else 2.6)
			var lean: float = 0.12 if variant%2==0 else -0.09
			if species=="mountain_pine":
				# Bent by the wind off the ridge: the trunk leans the way the crown streams.
				lean = 0.28 if variant%2==0 else -0.24
			shapes.tilted_box(parent,Vector3(0,height/2,0),Vector3(0.28,height,0.32),"65553e",Vector3(0,0,lean))
			if not species in ["pine","shrub","scrub","mountain_pine"]:
				for side: float in [-1.0,1.0]:
					shapes.tilted_box(parent,Vector3(side*0.48,height*0.77,0.07),Vector3(1.25,0.19,0.20),"776046",Vector3(0,side*0.2,side*0.50))
			if species in ["pine","mountain_pine"]:
				for tier: int in 3:
					shapes.box(parent,Vector3(0,1.8+tier*0.85,0),Vector3(1.8-tier*0.4,0.13,0.16),"61513c")
	shapes.frame = Transform3D.IDENTITY

func material() -> StandardMaterial3D:
	if leaf_material == null:
		leaf_material = StandardMaterial3D.new()
		leaf_material.vertex_color_use_as_albedo = true
		leaf_material.roughness = 0.97
		leaf_material.metallic_specular = 0.08
	return leaf_material

## Two bark shades per species: each colour is one more batch in every grove.
func _bark(species: String, shade: int) -> String:
	var colors: Array = barks.get(species,["5f4a3b","4e3d31"])
	return String(colors[shade%mini(2,colors.size())])

func _greens(species: String, fallback: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for hex: Variant in palettes.get(species,fallback):
		result.append(String(hex))
	return result

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
		"mountain_pine":
			green = ["2c4135","3c5340","546845","6d7a4d"]
			for tier: int in 3:
				var span: float = 1.25-tier*0.3
				surface.ellipsoid(Vector3(0.35+tier*0.22,2.1+tier*0.7,0.1*sin(variant+tier)),Vector3(span*1.25,0.5,span*0.8),green,variant+tier)
		"old_pine":
			# 老松: flat cloud-like pads of needles held out on crooked limbs, one over the top.
			green = _greens(species,["1d362b","294934","3a5d3f","52744b"])
			for pad: Array in _old_pine_plan(variant)["pads"]:
				surface.ellipsoid(pad[0],pad[1],green,variant+int(pad[0].y*7))
		"tall_pine":
			# A forest pine: bare trunk below, a dark spire of tiers above.
			green = _greens(species,["1f3b31","2b4d3b","3c6146","557a52"])
			var tiers: int = 5+variant%2
			for tier: int in tiers:
				var t: float = float(tier)/tiers
				var span: float = lerpf(1.3,0.32,t)
				surface.ellipsoid(Vector3(0.12*sin(tier*1.7+variant),2.8+tier*0.62,0.1*cos(tier+variant)),Vector3(span,0.5,span*0.9),green,variant+tier)
		"young_pine":
			green = _greens(species,["2f5a3f","3f6f48","58884f","74a05c"])
			for tier: int in 3:
				var span: float = 0.75-tier*0.2
				surface.ellipsoid(Vector3(0,0.6+tier*0.48,0),Vector3(span,0.38,span),green,variant+tier)
		"stunted_pine":
			# npath3's pines: shorter and thinner, sparse and yellowed (营养不良).
			surface.cell_size = 0.24
			green = _greens(species,["3c4a2c","4f5c35","68703f","858650"])
			var lean: float = 0.16 if variant%2==0 else -0.2
			for tier: int in 3:
				var span: float = 0.72-tier*0.18
				surface.ellipsoid(Vector3(sin(lean)*(1.4+tier*0.5)+0.18*sin(tier*2.0+variant),1.45+tier*0.5,0.15*cos(tier+variant)),Vector3(span,0.32,span*0.75),green,variant+tier)
		"scrub":
			surface.cell_size = 0.22
			green = ["4d4a2c","646036","7f7843","9c9254"]
			for lobe: int in 3:
				surface.ellipsoid(Vector3((lobe-1)*0.42,0.55+(lobe%2)*0.2,0.08*lobe),Vector3(0.58,0.5,0.55),green,lobe+variant)
		"shrub":
			surface.cell_size = 0.22
			for lobe: int in 3:
				surface.ellipsoid(Vector3((lobe-1)*0.48,0.7+(lobe%2)*0.24,0),Vector3(0.66,0.63,0.62),green,lobe+variant)
	crowns[key] = surface.mesh()
	return crowns[key]

## An old pine's crooked trunk, its limbs and the needle pads at their ends, the same for
## every planting of a variant (the crown mesh is cached; the wood is drawn each time).
static func _old_pine_plan(variant: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = 1301+variant*59
	var lean_low: float = random.randf_range(-0.22,0.22)
	var lean_high: float = -lean_low*random.randf_range(0.6,1.4)
	var low_top := Vector3(sin(lean_low)*2.3,2.3,0)
	var top: Vector3 = low_top+Vector3(sin(lean_high)*2.0,cos(lean_high)*2.0,random.randf_range(-0.2,0.2))
	var limbs: Array = []
	var pads: Array = []
	var count: int = 3+variant%2
	for i: int in count:
		var t: float = 0.35+0.65*float(i)/count
		var from: Vector3 = Vector3.ZERO.lerp(low_top,minf(1.0,t*2.0)) if t<0.5 else low_top.lerp(top,(t-0.5)*2.0)
		var angle: float = i*2.4+variant*0.9+random.randf_range(-0.4,0.4)
		var reach: float = random.randf_range(1.2,1.9)*(1.15-t*0.4)
		var to: Vector3 = from+Vector3(cos(angle)*reach,random.randf_range(0.15,0.5),sin(angle)*reach)
		limbs.append([from,to])
		pads.append([to+Vector3(0,0.22,0),Vector3(random.randf_range(0.95,1.3),0.36,random.randf_range(0.8,1.1))])
	pads.append([top+Vector3(0,0.3,0),Vector3(1.35,0.5,1.15)])
	pads.append([top+Vector3(0.3,0.75,-0.2),Vector3(0.8,0.34,0.7)])
	return {"low_top":low_top,"top":top,"lean_low":lean_low,"lean_high":lean_high,"limbs":limbs,"pads":pads}

func _old_pine_wood(parent: Node3D, shapes: Shapes, variant: int) -> void:
	var plan: Dictionary = _old_pine_plan(variant)
	var low_top: Vector3 = plan["low_top"]
	var top: Vector3 = plan["top"]
	_limb(parent,shapes,Vector3.ZERO,low_top,0.62,_bark("old_pine",0))
	_limb(parent,shapes,low_top,top,0.46,_bark("old_pine",1))
	# Bark in thick plates, darker in the cracks, and roots gripping the ground.
	for plate: int in 6:
		var t: float = (plate+0.5)/6.0
		var at: Vector3 = Vector3.ZERO.lerp(low_top,t)
		var a: float = plate*2.3+variant
		shapes.shard(parent,at+Vector3(cos(a)*0.3,0,sin(a)*0.3),Vector3(0.22,0.34,0.16),_bark("old_pine",2 if plate%2 else 3),plate+variant,a)
	for root: int in 5:
		var a: float = root*TAU/5.0+variant*0.7
		shapes.tilted_box(parent,Vector3(cos(a)*0.42,0.1,sin(a)*0.42),Vector3(0.62,0.2,0.24),_bark("old_pine",root%3),Vector3(0,-a,0.28))
	for limb: Array in plan["limbs"]:
		_limb(parent,shapes,limb[0],limb[1],0.2,_bark("old_pine",1))

func _tall_pine_wood(parent: Node3D, shapes: Shapes, variant: int) -> void:
	var height: float = 5.6+(variant%3)*0.35
	shapes.box(parent,Vector3(0,height/2,0),Vector3(0.34,height,0.36),_bark("tall_pine",0))
	shapes.box(parent,Vector3(0,0.12,0),Vector3(0.62,0.24,0.62),_bark("tall_pine",2))
	# Dead stubs where the lower branches dropped off in the shade.
	for stub: int in 3:
		var a: float = stub*2.1+variant
		shapes.tilted_box(parent,Vector3(cos(a)*0.3,1.3+stub*0.5,sin(a)*0.3),Vector3(0.06,0.45,0.06),_bark("tall_pine",1),Vector3(sin(a)*1.1,0,-cos(a)*1.1))
	for plate: int in 4:
		shapes.box(parent,Vector3(0.17*(1 if plate%2 else -1),0.6+plate*0.9,0.05),Vector3(0.06,0.4,0.2),_bark("tall_pine",3))

func _limb(parent: Node3D, shapes: Shapes, from: Vector3, to: Vector3, thick: float, hex: String) -> void:
	var along: Vector3 = to-from
	var length: float = along.length()
	if length<0.01:
		return
	var up: Vector3 = along/length
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z)<0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side,up,side.cross(up)).scaled_local(Vector3(thick,length+thick*0.4,thick*1.05))
	shapes._instance(parent,Transform3D(basis,(from+to)/2.0),hex,shapes.cube)

## A dead tree (枯树): a weathered, leaning trunk and a few bare crooked limbs.
func _dead(root: Node3D, shapes: Shapes, variant: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 811+variant*37
	var bark: Array[String] = ["6e6253","7d705f","5c5246"]
	var lean: float = random.randf_range(-0.22,0.22)
	var height: float = random.randf_range(2.0,2.8)
	shapes.tilted_box(root,Vector3(sin(lean)*height*0.5,height/2,0),Vector3(0.26,height,0.28),bark[0],Vector3(0,0,-lean))
	for limb: int in 4+variant%3:
		var angle: float = limb*2.1+variant
		var at: Vector3 = Vector3(sin(lean)*height*(0.45+limb*0.12),height*(0.45+limb*0.12),0)
		var length: float = random.randf_range(0.6,1.2)
		var reach := Vector3(cos(angle),0.55,sin(angle)).normalized()
		shapes.tilted_box(root,at+reach*length*0.5,Vector3(0.1,length,0.1),bark[(limb+1)%3],Vector3(sin(angle)*0.9,0,-cos(angle)*0.9))
		var tip: Vector3 = at+reach*length
		shapes.tilted_box(root,tip+Vector3(0,0.18,0),Vector3(0.06,0.45,0.06),bark[2],Vector3(0.4,0,0.3*(1 if limb%2 else -1)))
	shapes.shard(root,Vector3(0,0.06,0),Vector3(0.7,0.14,0.62),bark[2],variant)
