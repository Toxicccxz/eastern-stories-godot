extends RefCounted

## The woods and their waters (美术规划 group B): a great old pine, mossy rocks and fallen
## trunks, ferns, mushrooms and the tracks of beasts, dappled sun, an arched stone bridge,
## a waterfall, a plank road pinned to a cliff, hanging vines and the reeds round a pool.
## Sizes and colours come from the data; what stands on walkable ground is a blocked box
## in the map layout, and the rest stands on rock or hangs in the air.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const FALLING = preload("res://presentation/voxel/shaders/falling_water.gdshader")
var s: Shapes
var root: Node3D
var rng: RandomNumberGenerator
var ambience: VoxelAmbience
var tree_shapes: VoxelTree
var data: Dictionary
var _flecks: Dictionary[String, StandardMaterial3D] = {}

func draw(shapes: Shapes, parent: Node3D, look: Dictionary, w: float, d: float) -> bool:
	s = shapes
	root = parent
	data = look
	match String(look["kind"]):
		"great_pine", "great_tree": _great_pine()
		"pillar_root": _pillar_root()
		"pine_trunk": _pine_trunk()
		"needle_pad": _needle_pad(w,d)
		"mossy_rock": _mossy_rock(w,d)
		"mossy_log": _mossy_log(w,d)
		"mushrooms": _mushrooms(w,d)
		"ferns": _ferns(w,d)
		"tracks": _tracks()
		"sun_flecks": _sun_flecks(w,d)
		"stone_bridge": _stone_bridge(w,d)
		"waterfall": _waterfall(w,d)
		"plank_road": _plank_road()
		"vines": _vines(w)
		"reeds": _reeds(w,d)
		"bubbles": _bubbles()
		"stump": _stump(w)
		"tree": _lone_tree()
		"notice_post": _notice_post(w)
		"far_ground": _far_ground(w,d)
		"great_stump": _great_stump(w,d)
		"paper_slip": _paper_slip()
		_:
			return false
	return true

func _colors(key: String, fallback: Array) -> Array:
	return data.get(key,fallback)

func _pick(colors: Array) -> String:
	return String(colors[rng.randi_range(0,colors.size()-1)])

func _local(at: Array) -> Vector3:
	return Vector3(float(at[0])/32.0,0,float(at[1])/32.0)-root.position

## A beam of wood between two points, `thick` square.
func _beam(from: Vector3, to: Vector3, thick: float, hex: String) -> void:
	var along: Vector3 = to-from
	var length: float = along.length()
	if length<0.01:
		return
	var up: Vector3 = along/length
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z)<0.9 else Vector3.RIGHT).normalized()
	s._instance(root,Transform3D(Basis(side,up,side.cross(up)).scaled_local(Vector3(thick,length,thick)),(from+to)/2.0),hex,s.cube)

func _mesh_node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	root.add_child(instance)
	return instance

## 巨松: the great pine in the clearing, 像平地上撑起一把大伞 — a trunk wide as a hut, roots
## gripping the ground, and limbs holding a broad, dark umbrella of needles over it all.
## `height` to the canopy, `canopy` its radius (units), `roots` how far its roots spread (a
## factor); `great_tree` is the same form in other colours (a crossroad's old 槐). A banyan
## (`aerial_roots`: how many) lets roots down from its limbs, the longest grown into pillars
## that hold its boughs up (像一座凉亭); `fallen`: what lies round its foot (leaves, not
## needles), `cones` false for none. The roots grown into pillars are layout pieces of their own
## (`pillar_root`, each on its blocked cell); these hang clear of the ground.
func _great_pine() -> void:
	var height: float = float(data.get("height",9.0))
	var radius: float = float(data.get("canopy",7.0))
	var trunk: float = float(data.get("trunk",0.9))
	var bark: Array = _colors("bark",["5b4636","6b5341","4a392d","7a604a"])
	_trunk_column(0.0,height*0.92,trunk,bark)
	for i: int in 8:
		var a: float = i*TAU/8.0+0.3
		var reach: float = rng.randf_range(1.6,2.6)*float(data.get("roots",1.0))
		_beam(Vector3(cos(a)*trunk*0.6,0.5,sin(a)*trunk*0.6),Vector3(cos(a)*(trunk+reach),0.06,sin(a)*(trunk+reach)),0.42-i%2*0.1,_pick(bark))
		s.shard(root,Vector3(cos(a)*(trunk+reach*0.7),0.12,sin(a)*(trunk+reach*0.7)),Vector3(0.5,0.12,0.4),String(data.get("moss","56713f")),i,a)
	# The great limbs, then the canopy they hold up: a flattened dome with drooping edges.
	var crown := VoxelCellSurface.new()
	crown.cell_size = 0.42
	var greens: Array[String] = []
	for hex: Variant in _colors("needles",["1c3529","264530","345a3b","4a6f47"]):
		greens.append(String(hex))
	# Three tiers of cloud-like pads: a crown on top, a ring held on the great limbs, and a
	# drooping rim of smaller pads with gaps of sky between them.
	crown.ellipsoid(Vector3(0,height+1.5,0),Vector3(radius*0.42,0.95,radius*0.42),greens,1)
	for i: int in 6:
		var a: float = i*TAU/6.0+0.5
		var from: Vector3 = Vector3(0,height*(0.55+0.05*(i%3)),0)
		var to: Vector3 = Vector3(cos(a)*radius*0.55,height+0.3*(i%2),sin(a)*radius*0.55)
		_beam(from,to,0.4,_pick(bark))
		crown.ellipsoid(to+Vector3(0,0.3,0),Vector3(radius*0.34,0.72,radius*0.3),greens,i+2)
	for i: int in 9:
		var a: float = i*TAU/9.0+0.15
		var edge: Vector3 = Vector3(cos(a)*radius*0.84,height-0.5+0.25*(i%3),sin(a)*radius*0.84)
		_beam(Vector3(cos(a)*radius*0.45,height-0.1,sin(a)*radius*0.45),edge,0.18,_pick(bark))
		crown.ellipsoid(edge,Vector3(radius*0.2,0.5,radius*0.19),greens,i+9)
		var drop: Vector3 = edge+Vector3(rng.randf_range(-0.4,0.4),-0.6,rng.randf_range(-0.4,0.4))
		s.box(root,drop,Vector3(0.16,0.26,0.16),String(data.get("cone","7a5232")))
		if data.has("blossoms"):
			# Hanging sprays of flowers under the rim (a 槐's white blossom).
			for spray: int in 3:
				s.box(root,drop+Vector3(rng.randf_range(-0.6,0.6),-0.15-spray*0.12,rng.randf_range(-0.6,0.6)),Vector3(0.12,0.3,0.12),String(data["blossoms"]))
	_mesh_node(crown.mesh(),tree_shapes.material())
	_aerial_roots(height,radius,trunk,bark)
	# Needles and cones fallen round its foot, roots and all.
	var fallen: Array = _colors("fallen",["8a5a36","9c6a3e","7a4f31"])
	for i: int in 26:
		var a: float = rng.randf()*TAU
		var r: float = rng.randf_range(trunk+0.4,radius*0.9)
		s.tilted_box(root,Vector3(cos(a)*r,0.012,sin(a)*r),Vector3(0.2,0.014,0.03) if not data.has("fallen") else Vector3(0.16,0.014,0.11),_pick(fallen),Vector3(0,rng.randf()*TAU,0))
		if i%5==0 and data.get("cones",true):
			s.box(root,Vector3(cos(a)*r,0.06,sin(a)*r),Vector3(0.12,0.12,0.18),String(data.get("cone","7a5232")))

## A banyan's roots let down from its boughs: thin strands hanging in the air, and the old ones
## that reached the ground grown thick as posts, flaring where they enter it.
func _aerial_roots(height: float, radius: float, trunk: float, bark: Array) -> void:
	var count: int = int(data.get("aerial_roots",0))
	var strand: String = String(data.get("strands","7d6a4c"))
	for i: int in count:
		var a: float = i*2.39996+0.4
		var r: float = lerpf(trunk+1.0,radius*0.78,fposmod(i*0.618,1.0))
		var top := Vector3(cos(a)*r,height-0.4-0.3*(i%3),sin(a)*r)
		# A hanging strand, swinging a little; it stops well above a walker's head.
		var hang: float = rng.randf_range(1.2,height-3.4)
		var node := Node3D.new()
		node.position = top
		root.add_child(node)
		s._instance(node,Transform3D(Basis.from_scale(Vector3(0.06,hang,0.06)),Vector3(0,-hang/2.0,0)),strand,s.cube)
		s.box(node,Vector3(0.05,-hang*0.6,0),Vector3(0.05,hang*0.5,0.05),strand)
		if ambience != null:
			ambience.sway(node,a*3.1,0.05)

## A banyan's root grown into a pillar (field0.c's banyan, 像一座凉亭): a column from the ground up
## to its bough (`height`), its foot spread into the ground, its top splayed where it joins the
## bough; it stands on its own blocked cell under the tree's canopy.
func _pillar_root() -> void:
	var bark: Array = _colors("bark",["6a5e4c","7a6d58","5a5042","857762"])
	var height: float = float(data.get("height",6.0))
	var thick: float = float(data.get("thick",0.24))
	_beam(Vector3(0,height,0),Vector3.ZERO,thick,_pick(bark))
	for toe: int in 3:
		var t: float = toe*TAU/3.0+float(data.get("seed",0))
		_beam(Vector3(0,0.5,0),Vector3(cos(t)*0.22,0.04,sin(t)*0.22),0.12,_pick(bark))
		_beam(Vector3(0,height-0.5,0),Vector3(cos(t+0.5)*0.3,height,sin(t+0.5)*0.3),0.1,_pick(bark))

func _trunk_column(from: float, to: float, trunk: float, bark: Array) -> void:
	var y: float = from
	var course: int = 0
	while y < to:
		var step: float = 0.8
		var wander := Vector3(sin(course*0.7)*0.08,0,cos(course*0.9)*0.08)
		s.box(root,wander+Vector3(0,y+step/2,0),Vector3(trunk*2.0,step+0.02,trunk*2.0),String(bark[course%2]))
		for plate: int in 5:
			var a: float = plate*TAU/5.0+course*0.6
			s.shard(root,wander+Vector3(cos(a)*trunk*0.98,y+step*0.5,sin(a)*trunk*0.98),Vector3(0.42,step*0.85,0.22),String(bark[2+(plate+course)%2]),plate+course,-a+PI/2)
		if course%3==1:
			# Old knots and footholds: the way up 手脚并用.
			var a: float = course*1.9
			s.box(root,wander+Vector3(cos(a)*trunk,y+0.3,sin(a)*trunk),Vector3(0.26,0.2,0.26),String(bark[2]))
		y += step
		course += 1

## The great pine's trunk seen from its own boughs: the column going down out of sight
## (into the haze far below) and up past the top bough to the crown.
func _pine_trunk() -> void:
	var bark: Array = _colors("bark",["5b4636","6b5341","4a392d","7a604a"])
	_trunk_column(float(data.get("from",-24.0)),float(data.get("to",3.0)),float(data.get("trunk",0.9)),bark)

## A dense mass of needles at the end of a bough, cones hanging under it.
func _needle_pad(w: float, d: float) -> void:
	var pad := VoxelCellSurface.new()
	pad.cell_size = 0.3
	var greens: Array[String] = []
	for hex: Variant in _colors("needles",["1f3a2c","2b4b35","3b5e40","527550"]):
		greens.append(String(hex))
	var lift: float = float(data.get("height",0.4))
	pad.ellipsoid(Vector3(0,lift,0),Vector3(w*0.55,float(data.get("thick",0.55)),d*0.55),greens,rng.randi_range(0,9))
	pad.ellipsoid(Vector3(w*0.2,lift+0.3,-d*0.15),Vector3(w*0.35,0.4,d*0.3),greens,rng.randi_range(0,9))
	_mesh_node(pad.mesh(),tree_shapes.material())
	for cone: int in int(data.get("cones",4)):
		s.box(root,Vector3(rng.randf_range(-0.4,0.4)*w,lift-0.45,rng.randf_range(-0.4,0.4)*d),Vector3(0.14,0.24,0.14),String(data.get("cone","7a5232")))

## 青苔石: a rock furred with moss over its top, the moss creeping down its shaded side.
func _mossy_rock(w: float, d: float) -> void:
	var rock: Array = _colors("colors",["6f7068","7d7e74","62645d","8a8a7e"])
	var moss: Array = _colors("moss",["4b6a36","58773d","6a8a46","3f5c30"])
	var tall: float = float(data.get("tall",0.65))
	var h: float = tall*minf(w,d)
	s.shard(root,Vector3(0,h*0.42,0),Vector3(w,h,d),_pick(rock),rng.randi(),rng.randf()*TAU)
	s.shard(root,Vector3(w*0.3,h*0.25,d*0.25),Vector3(w*0.45,h*0.5,d*0.4),_pick(rock),rng.randi(),rng.randf()*TAU)
	s.shard(root,Vector3(0,h*0.9,0),Vector3(w*0.8,0.08,d*0.75),_pick(moss),rng.randi(),rng.randf()*TAU)
	for i: int in 4:
		var a: float = i*1.6+rng.randf()
		s.box(root,Vector3(cos(a)*w*0.38,h*rng.randf_range(0.3,0.75),sin(a)*d*0.38),Vector3(0.18,0.2,0.16),_pick(moss))
	if data.get("fern",true):
		_fern_at(Vector3(-w*0.55,0,d*0.3),0.7)

## 倒木: a fallen pine, mossy along its top, shelf fungus on its flank, its root plate torn
## up at one end.
## A fallen trunk: by its place thicker or thinner, lying at its own tilt, the moss, fungus
## and stubs along it where they happen to be.
func _mossy_log(w: float, d: float) -> void:
	var bark: Array = _colors("colors",["5d4b3c","6b5746","4f4034"])
	var moss: Array = _colors("moss",["4b6a36","58773d","6a8a46"])
	var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
	var r: float = float(data.get("thick",0.5))*vary.randf_range(0.88,1.12)
	s.tilted_box(root,Vector3(0,r*0.5,0),Vector3(w,r,r*1.05),String(bark[0]),Vector3(vary.randf_range(-0.04,0.04),0,vary.randf_range(-0.04,0.06)))
	for i: int in ceili(w/0.4):
		var x: float = -w/2+0.2+i*0.4
		if vary.randf()<0.7:
			s.box(root,Vector3(x,r+0.02,vary.randf_range(-0.08,0.08)),Vector3(0.38,0.07,r*0.8),String(moss[vary.randi_range(0,moss.size()-1)]))
		if vary.randf()<0.3:
			s.box(root,Vector3(x,r*0.5,r*0.55),Vector3(0.2,0.05,0.14),String(data.get("fungus","c9a46a")))
		if vary.randf()<0.25:
			s.tilted_box(root,Vector3(x,r*0.9,-r*0.3),Vector3(0.08,0.5,0.08),String(bark[1]),Vector3(-0.8,0,vary.randf_range(-0.4,0.4)))
	# The root plate: a disc of roots and earth stood on edge.
	if data.get("roots",true):
		var end := Vector3(w/2+0.08,0,0)
		s.box(root,end+Vector3(0,r*0.9,0),Vector3(0.18,r*2.2,r*2.4),String(data.get("earth","5a4a36")))
		for root_index: int in 6:
			var a: float = root_index*TAU/6.0
			s.tilted_box(root,end+Vector3(0.1,r*0.9+sin(a)*r*0.9,cos(a)*r*0.9),Vector3(0.08,0.6,0.08),String(bark[2]),Vector3(a,0,0.3))
	s.box(root,Vector3(-w/2,r*0.5,0),Vector3(0.04,r*0.9,r*0.95),"b29a74")

func _mushrooms(w: float, d: float) -> void:
	var caps: Array = _colors("colors",["b8432f","c9563a","d8c49c"])
	for i: int in int(data.get("count",5)):
		var at := Vector3(rng.randf_range(-0.4,0.4)*w,0,rng.randf_range(-0.4,0.4)*d)
		var tall: float = rng.randf_range(0.08,0.2)
		s.box(root,at+Vector3(0,tall/2,0),Vector3(0.04,tall,0.04),"e6dcc4")
		s.box(root,at+Vector3(0,tall+0.025,0),Vector3(0.13,0.05,0.13),_pick(caps))
		if i%2==0:
			s.box(root,at+Vector3(0.02,tall+0.053,0.02),Vector3(0.03,0.01,0.03),"f2eadb")

func _ferns(w: float, d: float) -> void:
	for i: int in int(data.get("count",3)):
		_fern_at(Vector3(rng.randf_range(-0.35,0.35)*w,0,rng.randf_range(-0.35,0.35)*d),rng.randf_range(0.7,1.1)*float(data.get("scale",1.0)))

func _fern_at(at: Vector3, size: float) -> void:
	# `fern`: its greens, or (on a mossy rock) just whether it has one.
	var greens: Array = data["fern"] if data.get("fern") is Array else ["3f6b3a","4f7d42","62914c"]
	for frond: int in 7:
		var a: float = frond*TAU/7.0+rng.randf()*0.4
		for leaf: int in 3:
			var r: float = (0.14+leaf*0.17)*size
			s.tilted_box(root,at+Vector3(cos(a)*r,(0.32-leaf*0.08)*size,sin(a)*r),Vector3(0.2*size,0.035,0.08*size),String(greens[(frond+leaf)%greens.size()]),Vector3(0,-a,0.35+leaf*0.2))

## Tracks pressed into soft ground along `points` (pixels): `print` "paw" (a wolf's),
## "hoof" or "boot"; `wet` leaves them dark and shining (epath3's 湿漉漉的脚印).
func _tracks() -> void:
	var points: Array = data.get("points",[])
	var print_kind: String = String(data.get("print","paw"))
	var color: String = String(data.get("color","4f4030"))+(":gloss" if data.get("wet",false) else "")
	var spacing: float = float(data.get("spacing",0.42))
	var index: int = 0
	for i: int in points.size()-1:
		var a: Vector3 = _local(points[i])
		var b: Vector3 = _local(points[i+1])
		var along: Vector3 = (b-a).normalized()
		var across := Vector3(-along.z,0,along.x)
		var yaw: float = atan2(along.x,along.z)
		var steps: int = maxi(1,floori(a.distance_to(b)/spacing))
		for k: int in steps:
			var at: Vector3 = a.lerp(b,(k+0.5)/steps)+across*(0.08 if index%2 else -0.08)+Vector3(0,0.008,0)
			index += 1
			match print_kind:
				"hoof":
					s.tilted_box(root,at,Vector3(0.11,0.012,0.12),color,Vector3(0,yaw,0))
					s.tilted_box(root,at+along*0.04,Vector3(0.05,0.013,0.05),"7a6a52",Vector3(0,yaw,0))
				"boot":
					s.tilted_box(root,at,Vector3(0.09,0.012,0.2),color,Vector3(0,yaw,0))
				_:
					s.tilted_box(root,at,Vector3(0.07,0.012,0.07),color,Vector3(0,yaw,0))
					for toe: int in 4:
						s.box(root,at+along*0.07+across*(toe-1.5)*0.035,Vector3(0.025,0.012,0.025),color)

## Dappled light through the canopy: warm patches of sun that fade at night or, with
## `night`, pale patches of moonlight that show only then.
func _sun_flecks(w: float, d: float) -> void:
	var moon: bool = data.get("night",false)
	var key: String = String(data.get("color","c6d6ff" if moon else "f3d98c"))+str(moon)
	if not _flecks.has(key):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(key.left(6),0.0)
		material.set_meta("haze",[0.0,float(data.get("alpha",0.22))] if moon else [float(data.get("alpha",0.32)),0.0])
		_flecks[key] = material
	var cube := BoxMesh.new()
	cube.size = Vector3(1,0.01,1)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = cube
	multi.instance_count = int(data.get("count",12))
	for i: int in multi.instance_count:
		var size: float = rng.randf_range(0.25,0.75)
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,1,size*rng.randf_range(0.6,1.0))),Vector3(rng.randf_range(-0.5,0.5)*w,0.02+i*0.0005,rng.randf_range(-0.5,0.5)*d)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = _flecks[key]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

## 小石桥: an old arched stone bridge, mossy, its parapet worn and broken in places. The
## span runs along the box's length; `height` is the deck's top (0 to walk on it, high for
## one seen from the gorge below), `arch` how far under the deck the arch springs.
func _stone_bridge(w: float, d: float) -> void:
	var stone: Array = _colors("colors",["7c7a70","8a877b","6f6d64","959183"])
	var moss: Array = _colors("moss",["4b6a36","58773d","6a8a46","3f5c30"])
	var top: float = float(data.get("height",0.0))
	var arch: float = float(data.get("arch",3.0))
	var span: float = float(data.get("span",w))/2.0
	var deck: float = 0.34
	var steps: int = ceili(w/0.5)
	for i: int in steps:
		var x: float = -w/2+0.25+i*0.5
		for row: int in 3:
			var z: float = (row-1)*d/3.0
			s.shard(root,Vector3(x+rng.randf_range(-0.02,0.02),top-deck/2,z),Vector3(0.49,deck,d/3.0-0.02),_pick(stone),rng.randi(),rng.randf_range(-0.03,0.03))
			if rng.randf()<0.18:
				s.shard(root,Vector3(x,top+0.005,z+rng.randf_range(-0.1,0.1)),Vector3(rng.randf_range(0.2,0.4),0.02,rng.randf_range(0.15,0.3)),_pick(moss),rng.randi(),rng.randf()*TAU)
		# The arch below: the spandrel down to the curve, voussoirs along it.
		var t: float = clampf(absf(x)/span,0.0,1.0)
		var under: float = top-deck-arch*t*t
		if absf(x) <= span and under < top-deck-0.05:
			s.box(root,Vector3(x,(under+top-deck)/2.0,0),Vector3(0.5,top-deck-under,d*0.92),_pick(stone))
		if absf(x) <= span:
			s.box(root,Vector3(x,under-0.12,0),Vector3(0.48,0.24,d*0.96),String(data.get("voussoir","9a968a")))
			if rng.randf()<0.3:
				s.box(root,Vector3(x,under-0.3-rng.randf()*0.4,rng.randf_range(-0.4,0.4)*d),Vector3(0.06,rng.randf_range(0.3,0.8),0.06),_pick(moss))
		# Parapets: low stone with posts, a stone gone here and there.
		for side: float in [-1.0,1.0]:
			if data.get("parapet",true) and rng.randf()>0.12:
				s.shard(root,Vector3(x,top+0.18,side*(d/2+0.1)),Vector3(0.48,0.36,0.2),_pick(stone),rng.randi())
				if rng.randf()<0.25:
					s.box(root,Vector3(x,top+0.37,side*(d/2+0.1)),Vector3(0.4,0.04,0.22),_pick(moss))
			if i%3==0 and data.get("parapet",true):
				s.box(root,Vector3(x,top+0.3,side*(d/2+0.1)),Vector3(0.26,0.6,0.26),_pick(stone))
	# Piers where the arch meets the gorge's walls, going down into the dark.
	var piers: float = float(data.get("piers",0.0))
	if piers>0.0:
		for end: float in [-1.0,1.0]:
			var y: float = top-deck-arch
			while y > top-piers:
				s.shard(root,Vector3(end*span,y-0.35,rng.randf_range(-0.05,0.05)),Vector3(1.0,0.7,d*1.15),_pick(stone),rng.randi(),rng.randf_range(-0.1,0.1))
				y -= 0.65

## 瀑布: a white sheet (白练) pouring from `top` down to `bottom` (units), facing +z; foam
## where it leaves the lip and where it strikes, spray and mist rising at its foot.
func _waterfall(w: float, d: float) -> void:
	var top: float = float(data.get("top",8.0))
	var bottom: float = float(data.get("bottom",0.0))
	var fall: float = top-bottom
	var material := ShaderMaterial.new()
	material.shader = FALLING
	material.set_shader_parameter("speed",float(data.get("speed",3.0)))
	material.set_shader_parameter("water",Color(String(data.get("color","dceaee"))))
	material.set_shader_parameter("shade",Color(String(data.get("shade","8fb0ba"))))
	# Seen from behind, on the camera's side of a room, the sheet is thin enough to see through.
	material.set_shader_parameter("opacity",float(data.get("opacity",0.92)))
	for layer: int in 2:
		var sheet := QuadMesh.new()
		sheet.size = Vector2(w*(1.0-layer*0.35),fall)
		var instance: MeshInstance3D = _mesh_node(sheet,material)
		instance.position = Vector3(0,bottom+fall/2.0,layer*0.12-d*0.3)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam: Array = _colors("foam",["eef4f2","dfeae8","f7fbfa"])
	for i: int in ceili(w/0.3):
		var x: float = -w/2+0.15+i*0.3
		s.box(root,Vector3(x,top-0.05,-d*0.3),Vector3(0.32,0.16,0.3),_pick(foam))
		s.box(root,Vector3(x,top-0.05,-d*0.3-0.4),Vector3(0.32,0.06,0.5),String(data.get("lip","8fb3b0"))+":gloss")
		s.box(root,Vector3(x+rng.randf_range(-0.05,0.05),bottom+0.1,-d*0.1+rng.randf_range(-0.1,0.2)),Vector3(0.34,0.22,0.4),_pick(foam))
	# Ledges the water bounces off on the way down: white ribbons across the sheet.
	for ledge: Variant in data.get("ledges",[]):
		var y: float = float(ledge)
		for i: int in ceili(w/0.35):
			s.box(root,Vector3(-w/2+0.17+i*0.35,y,-d*0.2),Vector3(0.36,0.2,0.24),_pick(foam))
	var wet: Array = _colors("rock",["3d4a4c","4a5658","33403f"])
	for i: int in 10:
		var side: float = -1.0 if i%2 else 1.0
		s.shard(root,Vector3(side*(w/2+rng.randf_range(0.1,0.4)),bottom+rng.randf()*fall,-d*0.35),Vector3(0.5,0.4,0.4),_pick(wet)+":gloss",rng.randi(),rng.randf()*TAU)
	if ambience != null:
		ambience.mist(root,Vector3(0,bottom,0.2),maxf(0.8,w*0.6),String(data.get("mist","e8f0f2")),int(data.get("puffs",10)))

## 栈道: a broken plank road pinned to a rock face along `points` ([x, y, height] px and
## units); `out` [x, z] is the way off the face. Beams driven into the rock carry planks,
## some gone; a rope rail sags along the outer edge.
func _plank_road() -> void:
	var points: Array = data.get("points",[])
	var out_dir: Array = data.get("out",[0,1])
	var out := Vector3(float(out_dir[0]),0,float(out_dir[1])).normalized()
	var wood: Array = _colors("colors",["7a6a55","6b5c49","877660","5e5142"])
	var width: float = float(data.get("width",0.9))
	var index: int = 0
	for i: int in points.size()-1:
		var a: Vector3 = _local(points[i])+Vector3(0,float(points[i][2]),0)
		var b: Vector3 = _local(points[i+1])+Vector3(0,float(points[i+1][2]),0)
		var steps: int = maxi(1,ceili(a.distance_to(b)/0.3))
		var along: Vector3 = (b-a).normalized()
		var yaw: float = atan2(along.x,along.z)
		for k: int in steps:
			var at: Vector3 = a.lerp(b,(k+0.5)/steps)
			index += 1
			if index%5==3 or rng.randf()<float(data.get("gaps",0.12)):
				continue
			s.tilted_box(root,at+out*width*0.5,Vector3(width,0.06,0.24),_pick(wood),Vector3(0,yaw+PI/2,rng.randf_range(-0.06,0.06)))
			if index%4==0:
				# A beam into the rock and a strut braced beneath it.
				_beam(at-Vector3(0,0.06,0)-out*0.3,at-Vector3(0,0.06,0)+out*width*1.05,0.1,String(wood[3]))
				_beam(at-Vector3(0,0.9,0)-out*0.1,at-Vector3(0,0.08,0)+out*width*0.8,0.07,String(wood[1]))
			if index%6==0 and data.get("rail",true):
				s.box(root,at+out*width+Vector3(0,0.35,0),Vector3(0.07,0.7,0.07),String(wood[2]))
		var rope: Vector3 = out*width+Vector3(0,0.62,0)
		for k: int in steps:
			var at: Vector3 = a.lerp(b,(k+0.5)/steps)+rope-Vector3(0,sin(float(k)/steps*PI)*0.12,0)
			s.box(root,at,Vector3(0.035,0.035,0.32),String(data.get("rope","a08e62")))

## Vines hanging down a rock face or from a bridge, from `height` down `length` units,
## spread along the box's width; each sways on its own.
func _vines(w: float) -> void:
	var leaves: Array = _colors("colors",["3e6a37","4f7d40","5f8f48","2f5530"])
	var top: float = float(data.get("height",3.0))
	var lengths: Array = data.get("length",[2.0,4.0])
	for i: int in int(data.get("count",5)):
		var vine := Node3D.new()
		vine.position = Vector3(-w/2+(i+0.5)*w/float(data.get("count",5))+rng.randf_range(-0.1,0.1),top,rng.randf_range(-0.05,0.05))
		root.add_child(vine)
		var length: float = rng.randf_range(float(lengths[0]),float(lengths[1]))
		var y: float = 0.0
		var leaf: int = 0
		while y < length:
			s.box(vine,Vector3(sin(y*1.7)*0.05,-y-0.15,0),Vector3(0.04,0.3,0.04),String(data.get("stem","4a5a32")))
			var side: float = 1.0 if leaf%2 else -1.0
			s.box(vine,Vector3(side*0.08+sin(y*1.7)*0.05,-y-0.1,0.02),Vector3(0.14,0.06,0.1),String(leaves[leaf%leaves.size()]))
			y += 0.28
			leaf += 1
		if ambience != null:
			ambience.sway(vine,i*1.3,float(data.get("swing",0.06)))

## Strange reeds round a pool (lake.c's 黄色叶子的怪草): clumps of tall, pale-yellow blades.
func _reeds(w: float, d: float) -> void:
	var blades: Array = _colors("colors",["c9b44a","b39a3a","d8c86a","9e8a34"])
	var tall: float = float(data.get("height",0.9))
	for clump: int in int(data.get("count",6)):
		var at := Vector3(rng.randf_range(-0.45,0.45)*w,0,rng.randf_range(-0.45,0.45)*d)
		for blade: int in 6:
			var a: float = blade*TAU/6.0+rng.randf()*0.5
			var h: float = tall*rng.randf_range(0.6,1.1)
			s.tilted_box(root,at+Vector3(cos(a)*0.06,h/2,sin(a)*0.06),Vector3(0.05,h,0.03),String(blades[(blade+clump)%blades.size()]),Vector3(sin(a)*0.25,a,cos(a)*0.25))

func _bubbles() -> void:
	if ambience != null:
		ambience.bubbles(root,Vector3(0,float(data.get("level",-0.22)),0),float(data.get("radius",1.5)),String(data.get("color","c9d8c4")),int(data.get("count",8)))

## A sawn or broken stump, rings on its top, moss at its foot.
## A stump: by its place cut higher or lower, turned, its roots and moss its own.
func _stump(w: float) -> void:
	var bark: Array = _colors("colors",["5d4b3c","6b5746","4f4034"])
	var vary: RandomNumberGenerator = Shapes.spot_rng(root.position)
	var tall: float = float(data.get("height",0.5))*vary.randf_range(0.85,1.15)
	var turn: float = vary.randf()*TAU
	s.tilted_box(root,Vector3(0,tall/2,0),Vector3(w*0.7,tall,w*0.7),String(bark[0]),Vector3(0,turn,0))
	s.tilted_box(root,Vector3(0,tall+0.01,0),Vector3(w*0.6,0.03,w*0.6),String(data.get("rings","b39a72")),Vector3(0,turn,0))
	for i: int in vary.randi_range(3,5):
		var a: float = i*TAU/4.0+0.4+turn+vary.randf_range(-0.3,0.3)
		s.tilted_box(root,Vector3(cos(a)*w*0.42,0.08,sin(a)*w*0.42),Vector3(0.3*vary.randf_range(0.8,1.2),0.14,0.14),String(bark[1]),Vector3(0,-a,0.3))
	var moss_at: float = vary.randf()*TAU
	s.shard(root,Vector3(cos(moss_at)*w*0.3,0.03,sin(moss_at)*w*0.3),Vector3(0.4,0.05,0.3),String(data.get("moss","58773d")),vary.randi())
	if data.get("axe",false):
		# A chopping stump: the axe left in it, chips about.
		s.tilted_box(root,Vector3(0.05,tall+0.3,0),Vector3(0.06,0.7,0.06),"7a5a3e",Vector3(0,0,0.5))
		s.tilted_box(root,Vector3(-0.08,tall+0.06,0),Vector3(0.22,0.14,0.04),"8a8e8a",Vector3(0,0,0.5))
		for chip: int in 5:
			s.box(root,Vector3(cos(chip*1.3)*w*0.6,0.02,sin(chip*1.9)*w*0.6),Vector3(0.12,0.03,0.06),"c9ad7c")

## 树王坟 (tree_tomb.c: 一截巨大的树桩, 少说有三, 四十人合抱那么粗, 树桩中间有一个大洞): a stump as
## wide as the box, its bark in deep ridges, the top broken off unevenly at `height`, the hole
## black in its middle, roots spreading out over the stones, moss and bracket fungus on it.
func _great_stump(w: float, d: float) -> void:
	var bark: Array = _colors("colors",["5a4836","6a5642","4a3a2c","7a6450"])
	var tall: float = float(data.get("height",1.4))
	var r: float = minf(w,d)*0.46
	var segments: int = 18
	for i: int in segments:
		var a: float = i*TAU/segments
		var h: float = tall*(0.78+0.22*absf(sin(i*2.3)))
		var wide: float = r*0.42
		s.tilted_box(root,Vector3(cos(a)*r*0.86,h/2,sin(a)*r*0.86),Vector3(wide,h,wide*0.9),String(bark[i%bark.size()]),Vector3(0,-a,0))
		if i%3==0:
			s.tilted_box(root,Vector3(cos(a)*r*1.02,h*0.3,sin(a)*r*1.02),Vector3(wide*0.5,h*0.6,wide*0.5),String(bark[(i+2)%bark.size()]),Vector3(0,-a,0))
	# The top: pale ring of wood, the black hole in the middle (a body can go down it).
	s.box(root,Vector3(0,tall*0.7,0),Vector3(r*1.5,tall*0.2,r*1.5),String(data.get("rings","9a8460")))
	s.box(root,Vector3(0,tall*0.8+0.01,0),Vector3(r*1.1,0.03,r*1.1),String(data.get("rings","9a8460")))
	s.box(root,Vector3(0,tall*0.5,0),Vector3(r*0.7,tall*0.7,r*0.7),"0d0b0a")
	# Roots over the stones, moss, fungus shelves.
	for i: int in 10:
		var a: float = i*TAU/10.0+0.3
		_beam(Vector3(cos(a)*r*0.9,0.3,sin(a)*r*0.9),Vector3(cos(a)*(r+1.2+0.4*(i%3)),0.05,sin(a)*(r+1.2+0.4*(i%3))),0.3-0.06*(i%2),_pick(bark))
		if i%2==0:
			s.shard(root,Vector3(cos(a)*(r+0.6),0.1,sin(a)*(r+0.6)),Vector3(0.5,0.1,0.4),String(data.get("moss","56713f")),i,a)
	for shelf: int in 5:
		var a: float = shelf*1.9+0.4
		s.box(root,Vector3(cos(a)*r*1.06,tall*(0.3+0.1*shelf),sin(a)*r*1.06),Vector3(0.22,0.05,0.18),["d8c8a0","c0a880"][shelf%2])

## 字条 (taolin.c: 一些先行者在桃树枝上挂了些字条以指示道路): a paper slip on a string from a bough,
## at `height`, turning in the wind.
func _paper_slip() -> void:
	var slip := Node3D.new()
	slip.position = Vector3(0,float(data.get("height",2.3)),0)
	root.add_child(slip)
	s.box(slip,Vector3(0,0.15,0),Vector3(0.012,0.3,0.012),"8a7a5a")
	s.box(slip,Vector3(0,-0.2,0),Vector3(0.16,0.4,0.012),String(data.get("paper","efe6cc")))
	for mark: int in 4:
		s.box(slip,Vector3(0,-0.06-mark*0.08,0.008),Vector3(0.07,0.03,0.004),"3a3430")
	if ambience != null:
		ambience.flutter(slip,root.position.x*0.3)

## One tree placed by hand (a ring round a clearing, a pine marked by knives): `species`,
## `scale`, `variant`; `marks` cuts pale slashes in its bark toward +z (epath1.c's 记号).
func _lone_tree() -> void:
	var size: float = float(data.get("scale",1.0))
	root.scale = Vector3.ONE*size
	var variant: int = int(data.get("variant",rng.randi_range(0,5)))
	tree_shapes.build(root,s,String(data.get("species","tall_pine")),variant,Transform3D.IDENTITY,null,data.get("colors",[]))
	if data.get("marks",false):
		for cut: int in 3:
			s.tilted_box(root,Vector3(-0.06+cut*0.07,1.0+cut*0.18,0.2),Vector3(0.04,0.3,0.03),"d9c39a",Vector3(0,0,0.5-cut*0.4))

## A notice on a post by a path (clearing.c's 牌子: 官府告示), its words in `text`.
func _notice_post(w: float) -> void:
	var wood: Array = _colors("colors",["6a5038","7d6044","8e7352"])
	s.tilted_box(root,Vector3(0,0.75,0),Vector3(0.14,1.5,0.14),String(wood[0]),Vector3(0,0,0.04))
	s.box(root,Vector3(0,1.42,0.04),Vector3(maxf(w,0.9),0.62,0.08),String(wood[2]))
	s.box(root,Vector3(0,1.42,0.085),Vector3(maxf(w,0.9)-0.1,0.52,0.02),String(data.get("paper","d8ccaa")))
	s.box(root,Vector3(0,1.78,0.04),Vector3(maxf(w,0.9)+0.12,0.08,0.14),String(wood[1]))
	if data.has("text"):
		var title := Label3D.new()
		title.text = tr(String(data["text"]))
		title.position = Vector3(0,1.42,0.1)
		title.pixel_size = 0.0045
		title.font_size = 40
		title.width = 180.0
		title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		title.modulate = Color("3a2a1e")
		title.outline_size = 0
		root.add_child(title)

## The ground far below (under a tree's crown, a ledge): a slab of forest floor and the
## tops of the trees on it, set down by `elevation` into the haze, a lighter `clearing` patch
## (`roofs`: that many little houses in it, a town far below).
func _far_ground(w: float, d: float) -> void:
	var floor_colors: Array = _colors("colors",["3f4a2e","465233","4d5a37"])
	s.box(root,Vector3(0,-0.2,0),Vector3(w,0.4,d),String(floor_colors[0]))
	if data.has("clearing"):
		var c: Array = data["clearing"]
		s.box(root,Vector3(float(c[0]),0.01,float(c[1])),Vector3(float(c[2]),0.04,float(c[3])),String(data.get("clearing_color","5f7a3e")))
	if data.has("clearing") and int(data.get("roofs",0)) > 0:
		# A town seen far down in its clearing (ladder3.c: 雪亭镇就在西边不远的山下): little
		# houses of pale walls under dark roofs, packed together.
		var c: Array = data["clearing"]
		for i: int in int(data["roofs"]):
			var size := Vector2(rng.randf_range(0.7,1.4),rng.randf_range(0.6,1.0))
			var at := Vector3(float(c[0])+rng.randf_range(-0.42,0.42)*float(c[2]),0,float(c[1])+rng.randf_range(-0.42,0.42)*float(c[3]))
			s.box(root,at+Vector3(0,0.3,0),Vector3(size.x,0.6,size.y),_pick(_colors("walls",["c8c0ac","b8b09c","d0c8b4"])))
			s.box(root,at+Vector3(0,0.68,0),Vector3(size.x+0.2,0.2,size.y+0.2),_pick(_colors("roof_colors",["4a4e50","3e4446","565a58"])))
	var crowns: Array = _colors("crowns",["1f3a2c","2b4b35","264430","345a3b"])
	for i: int in int(data.get("trees",40)):
		var at := Vector3(rng.randf_range(-0.48,0.48)*w,0,rng.randf_range(-0.48,0.48)*d)
		if data.has("clearing"):
			var c: Array = data["clearing"]
			if absf(at.x-float(c[0]))<float(c[2])*0.5 and absf(at.z-float(c[1]))<float(c[3])*0.5:
				continue
		var size: float = rng.randf_range(0.8,1.6)
		s.box(root,at+Vector3(0,size*0.9,0),Vector3(size*1.6,size*1.4,size*1.5),_pick(crowns))
		s.box(root,at+Vector3(0,size*1.8,0),Vector3(size*0.9,size*0.8,size*0.9),_pick(crowns))
