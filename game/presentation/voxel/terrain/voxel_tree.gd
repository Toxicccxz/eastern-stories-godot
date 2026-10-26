class_name VoxelTree
extends RefCounted

## Cached silhouettes, then varied in height, width and rotation at each planting.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const PINES: Array[String] = ["pine","mountain_pine","old_pine","tall_pine","young_pine","stunted_pine"]
## Bark colours by species where they differ from the default brown.
const BARKS: Dictionary = {"willow": ["6b5a46","5a4b3b"], "bamboo": ["6f8a44","7f9a50"], "locust": ["4f4234","5d4e3e"], "maple": ["5a4436","4a382c"],
	"plum": ["3a2a26","4a3630"], "crabapple": ["4e3a30","5c463a"], "apricot": ["4a3a32","5a463c"], "peach": ["4a3a32","5a463c"],
	"osmanthus": ["5a4e40","6a5c4c"], "banana": ["6a8a48","7a9a52"]}
var crowns: Dictionary[String, ArrayMesh] = {}
var leaf_material: StandardMaterial3D
## Crown colours by species, dark to light (layout flora `crown_colors`); bark the same
## (flora `bark_colors`). A map without them keeps the defaults below.
var palettes: Dictionary = {}
var barks: Dictionary = {}

## Draws one tree into `parent`. With `crowns` (mesh -> Array of transforms) the crown is
## collected for a grove's shared MultiMesh instead of getting its own instance, and every
## box is placed by `frame`, so a whole grove batches by colour under one parent.
## `colors`: this planting's own crown colours, dark to light (a white plum among red ones).
func build(parent: Node3D, shapes: Shapes, species: String, variant: int, frame := Transform3D.IDENTITY, collect: Variant = null, colors: Array = []) -> void:
	parent.set_meta("species",species)
	# The forest pines come in three shapes each: a forest of them batches into few crowns.
	if species in ["old_pine","tall_pine","young_pine","stunted_pine"]:
		variant %= 3
	shapes.frame = frame
	if species=="dead":
		_dead(parent,shapes,variant)
		shapes.frame = Transform3D.IDENTITY
		return
	var crown: ArrayMesh = _crown(species,variant,colors)
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
		"willow": _willow_wood(parent,shapes,variant)
		"bamboo": _bamboo_wood(parent,shapes,variant)
		"plum", "crabapple", "osmanthus", "apricot", "peach": _blossom_wood(parent,shapes,species,variant)
		"banana": _banana_wood(parent,shapes,variant)
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
			shapes.tilted_box(parent,Vector3(0,height/2,0),Vector3(0.28,height,0.32),_bark(species,0) if species=="maple" else "65553e",Vector3(0,0,lean))
			if species=="locust":
				height = 2.9
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
	var colors: Array = barks.get(species,BARKS.get(species,["5f4a3b","4e3d31"]))
	return String(colors[shade%mini(2,colors.size())])

func _greens(species: String, fallback: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for hex: Variant in palettes.get(species,fallback):
		result.append(String(hex))
	return result

func _crown(species: String, variant: int, colors: Array = []) -> ArrayMesh:
	var key: String = species+str(variant)+",".join(colors)
	if crowns.has(key):
		return crowns[key]
	var own: Dictionary = palettes
	if not colors.is_empty():
		palettes = palettes.duplicate()
		palettes[species] = colors
	var surface := VoxelCellSurface.new()
	var random := RandomNumberGenerator.new()
	random.seed = 491+variant*73
	var green: Array[String] = ["315645","456b4a","668752","8ba264"]
	match species:
		"pine":
			green = _greens(species,["244a43","315e50","48775b","6b9068"])
			for tier: int in 4:
				var span: float = 1.4-tier*0.28
				surface.ellipsoid(Vector3(0.13*sin(tier+variant),2.0+tier*0.76,0),Vector3(span,0.69,span*0.86),green,variant+tier)
		"broadleaf":
			green = _greens(species,green)
			for lobe: int in 4:
				var angle: float = lobe*2.2+variant
				surface.ellipsoid(Vector3(cos(angle)*0.73,2.6+random.randf_range(-0.3,0.65),sin(angle)*0.67),Vector3(1.08,0.85,1.0),green,variant+lobe)
		"blossom":
			var pink: Array[String] = ["995e7c","bf7696","df99b1","efb4c4"]
			for lobe: int in 4:
				var angle: float = lobe*2.0+variant*0.4
				surface.ellipsoid(Vector3(cos(angle)*1.02,2.45+lobe*0.23,sin(angle)*0.73),Vector3(0.85+random.randf()*0.25,0.64,0.84),pink,lobe+variant)
		"slender":
			green = _greens(species,["3d6549","60834e","89a25c","acb86f"])
			for lobe: int in 3:
				surface.ellipsoid(Vector3(0.16*sin(lobe*2.0),2.15+lobe*0.7,0.10*cos(lobe)),Vector3(0.73,1.1,0.70),green,lobe+variant)
		"mountain_pine":
			green = _greens(species,["2c4135","3c5340","546845","6d7a4d"])
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
			green = _greens(species,green)
			for lobe: int in 3:
				surface.ellipsoid(Vector3((lobe-1)*0.48,0.7+(lobe%2)*0.24,0),Vector3(0.66,0.63,0.62),green,lobe+variant)
		"willow":
			# 垂柳: a light dome; the long hanging strands are drawn with the wood.
			green = _greens(species,["5f7f3e","729048","88a456","a3b866"])
			for lobe: int in 3:
				var angle: float = lobe*2.1+variant*0.5
				surface.ellipsoid(Vector3(cos(angle)*0.45,3.0+(lobe%2)*0.25,sin(angle)*0.4),Vector3(1.05,0.6,1.0),green,lobe+variant)
		"locust":
			# 槐: a broad, rounded head of small pale leaves over a short thick trunk.
			green = _greens(species,["3f6a3a","527d44","6a9450","86aa5e"])
			for lobe: int in 5:
				var angle: float = lobe*1.4+variant
				surface.ellipsoid(Vector3(cos(angle)*0.85,3.1+random.randf_range(-0.2,0.5),sin(angle)*0.8),Vector3(1.15,0.8,1.1),green,variant+lobe)
		"maple":
			# 枫: a spreading head of red leaves in layered lobes (sroad1.c's 茂密的枫树林), darker
			# at its heart, flame-bright at the top.
			green = _greens(species,["6e2420","9a2e26","c4462c","e27a3a"])
			for lobe: int in 5:
				var angle: float = lobe*1.3+variant*0.7
				surface.ellipsoid(Vector3(cos(angle)*0.82,2.45+random.randf_range(-0.2,0.55),sin(angle)*0.76),Vector3(1.02,0.72,0.96),green,variant+lobe)
			surface.ellipsoid(Vector3(0.1*sin(variant),3.2,0),Vector3(0.9,0.6,0.85),green,variant+7)
		"bamboo":
			# 竹: feathery tufts of leaves up a clump of slender culms.
			surface.cell_size = 0.22
			green = _greens(species,["3f6a3a","568246","6f9a52","8db463"])
			for tuft: int in 5:
				var angle: float = tuft*1.3+variant
				surface.ellipsoid(Vector3(cos(angle)*0.35,2.2+tuft*0.45,sin(angle)*0.3),Vector3(0.45,0.32,0.4),green,tuft+variant)
		"plum":
			# 梅: no leaves, only bloom — small clusters along crooked bare limbs.
			surface.cell_size = 0.2
			green = _greens(species,["7a2236","a83450","d0587a","f0a0b8"])
			for spray: Array in _plum_sprays(variant):
				surface.ellipsoid(spray[0],spray[1],green,variant+int(spray[0].y*9))
		"crabapple":
			# 西府海棠: 其势若伞, 丝垂翠缕, 葩吐丹砂 — a broad umbrella of green and red-pink bloom.
			surface.cell_size = 0.22
			green = _greens(species,["4f6e3a","c0485a","e07a8a","f6b4c0"])
			for lobe: int in 6:
				var angle: float = lobe*TAU/6.0+variant*0.5
				surface.ellipsoid(Vector3(cos(angle)*1.05,2.75+0.12*sin(lobe*1.7),sin(angle)*0.95),Vector3(0.82,0.42,0.78),green,lobe+variant)
			surface.ellipsoid(Vector3(0,3.05,0),Vector3(1.0,0.45,0.95),green,variant+9)
		"osmanthus":
			# 桂: a dense rounded evergreen head (its gold flecks of flower: `_blossom_wood`).
			green = _greens(species,["24442c","2e5434","3c6a3e","4e7c48"])
			for lobe: int in 5:
				var angle: float = lobe*1.25+variant
				surface.ellipsoid(Vector3(cos(angle)*0.6,2.05+random.randf_range(-0.15,0.4),sin(angle)*0.55),Vector3(0.95,0.85,0.9),green,variant+lobe)
		"apricot", "peach":
			# 杏 (pink-white, 如喷火蒸霞) and 桃 (deeper pink): a cloud of bloom on bare twigs.
			var bloom: Array[String] = ["b07888","d8a2ae","efc8ce","fbecec"]
			if species=="peach":
				bloom.assign(["a84a6a","cc7090","e898b0","f6c4d2"])
			green = _greens(species,bloom)
			for lobe: int in 5:
				var angle: float = lobe*1.5+variant*0.6
				surface.ellipsoid(Vector3(cos(angle)*0.8,2.4+lobe*0.12,sin(angle)*0.7),Vector3(0.78,0.6,0.74),green,lobe+variant)
		"banana":
			# 芭蕉: the furled new leaf at the top (the broad leaves are drawn with the stem).
			surface.cell_size = 0.2
			green = _greens(species,["4f7a36","5f8c3e","78a24c","98b85e"])
			surface.ellipsoid(Vector3(0,2.3,0),Vector3(0.22,0.5,0.22),green,variant)
	crowns[key] = surface.mesh()
	palettes = own
	return crowns[key]

## A 梅's sprays of bloom: at the ends and middles of its limbs (`_blossom_wood` draws them).
static func _plum_sprays(variant: int) -> Array:
	var sprays: Array = []
	for limb: Array in _limbs("plum",variant):
		var from: Vector3 = limb[0]
		var tip: Vector3 = limb[1]
		sprays.append([tip,Vector3(0.42,0.3,0.4)])
		sprays.append([(from+tip)*0.5+Vector3(0,0.12,0),Vector3(0.3,0.22,0.3)])
	return sprays

## The limbs of a flowering tree, [from, to]: a 梅's few and crooked, the others spreading.
static func _limbs(species: String, variant: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = 613+variant*41
	var crooked: bool = species=="plum"
	var count: int = 5 if crooked else 4
	var fork := Vector3(0.18*sin(variant),1.3 if crooked else 1.7,0.1*cos(variant))
	var limbs: Array = []
	for i: int in count:
		var a: float = i*TAU/count+variant*0.7+random.randf_range(-0.3,0.3)
		var reach: float = random.randf_range(0.7,1.3) if crooked else random.randf_range(0.6,0.9)
		var rise: float = random.randf_range(0.5,1.4) if crooked else random.randf_range(0.6,0.9)
		limbs.append([fork,fork+Vector3(cos(a)*reach,rise,sin(a)*reach)])
	return limbs

## The trunk and limbs of a flowering tree: a 梅 old, dark and crooked; the others straighter.
func _blossom_wood(parent: Node3D, shapes: Shapes, species: String, variant: int) -> void:
	var crooked: bool = species=="plum"
	var lean: float = (0.22 if variant%2==0 else -0.18) if crooked else (0.08 if variant%2==0 else -0.06)
	var fork: float = 1.3 if crooked else 1.7
	shapes.tilted_box(parent,Vector3(0,fork/2,0),Vector3(0.26,fork+0.1,0.28),_bark(species,0),Vector3(0,0,-lean*0.5))
	for limb: Array in _limbs(species,variant):
		var from: Vector3 = limb[0]
		var along: Vector3 = (limb[1] as Vector3)-from
		var axis: Vector3 = Vector3.UP.cross(along.normalized())
		var tilt: Vector3 = Vector3.ZERO if axis.length()<0.001 else Basis(axis.normalized(),Vector3.UP.angle_to(along)).get_euler()
		shapes.tilted_box(parent,from+along/2,Vector3(0.1,along.length(),0.1),_bark(species,1),tilt)
	if species=="osmanthus":
		# 碧海银花: tiny gold flowers in clusters over the dark leaves.
		var random := RandomNumberGenerator.new()
		random.seed = 977+variant*29
		for i: int in 22:
			var a: float = random.randf()*TAU
			var up: float = random.randf_range(0.1,0.9)
			var at := Vector3(cos(a)*sqrt(1.0-up*up),up,sin(a)*sqrt(1.0-up*up))*Vector3(1.25,0.95,1.15)+Vector3(0,2.25,0)
			shapes.box(parent,at,Vector3(0.12,0.1,0.12),"e8c25a" if i%3 else "f2dc8a")
	if species=="crabapple":
		# 丝垂翠缕: short green threads hanging from the rim of the umbrella, a flower here and there.
		for i: int in 16:
			var a: float = i*TAU/16.0+variant*0.4
			shapes.box(parent,Vector3(cos(a)*1.55,2.25,sin(a)*1.4),Vector3(0.05,0.7,0.05),"6f8f44" if i%3 else "e07a8a")

## 芭蕉: a green stem and broad leaves arching out and down from its top.
func _banana_wood(parent: Node3D, shapes: Shapes, variant: int) -> void:
	shapes.box(parent,Vector3(0,0.9,0),Vector3(0.3,1.8,0.3),_bark("banana",0))
	var leaves: Array[String] = _greens("banana_leaves",["5f8c3e","6f9a46","86ae54"])
	for i: int in 6:
		var a: float = i*TAU/6.0+variant*0.5
		var out := Vector3(cos(a),0,sin(a))
		var droop: float = 0.35+0.15*(i%2)
		# Each leaf turned to point along `out` (yaw), its tip drooping (roll before the turn).
		shapes.tilted_box(parent,Vector3(0,1.95,0)+out*0.75,Vector3(1.3,0.05,0.5),leaves[i%leaves.size()],Vector3(0,-a,-droop))

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

## A willow's short trunk and the curtain of strands hanging from its crown to near the
## ground (the strands are leaf-green boxes, batched with the grove's wood).
func _willow_wood(parent: Node3D, shapes: Shapes, variant: int) -> void:
	shapes.tilted_box(parent,Vector3(0,1.3,0),Vector3(0.34,2.6,0.36),_bark("willow",0),Vector3(0,0,0.08 if variant%2 else -0.08))
	for limb: int in 3:
		var a: float = limb*2.1+variant
		shapes.tilted_box(parent,Vector3(cos(a)*0.35,2.5,sin(a)*0.35),Vector3(0.12,0.9,0.12),_bark("willow",1),Vector3(sin(a)*0.7,0,-cos(a)*0.7))
	var strands: Array[String] = _greens("willow_strands",["6f8f44","86a352","9cb664"])
	for i: int in 22:
		var a: float = i*TAU/22.0+variant*0.3
		var r: float = 0.75+0.35*sin(i*1.7+variant)
		var length: float = 1.4+0.6*sin(i*2.3+variant*1.1)
		shapes.box(parent,Vector3(cos(a)*r,3.0-length/2,sin(a)*r),Vector3(0.07,length,0.07),strands[i%strands.size()])

## A clump of bamboo: green jointed culms leaning a little apart.
func _bamboo_wood(parent: Node3D, shapes: Shapes, variant: int) -> void:
	for culm: int in 5:
		var a: float = culm*1.3+variant
		var lean := Vector3(cos(a)*0.08,0,sin(a)*0.08)
		var height: float = 3.2+0.5*sin(culm*2.0+variant)
		shapes.tilted_box(parent,Vector3(cos(a)*0.18,height/2,sin(a)*0.18),Vector3(0.09,height,0.09),_bark("bamboo",culm%2),Vector3(lean.z,0,-lean.x))
		for joint: int in int(height/0.6):
			shapes.box(parent,Vector3(cos(a)*0.18+lean.x*joint*0.6,0.5+joint*0.6,sin(a)*0.18+lean.z*joint*0.6),Vector3(0.11,0.03,0.11),"8a9a52")
