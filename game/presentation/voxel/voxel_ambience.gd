class_name VoxelAmbience
extends Node3D

## Small moving things that make a place feel alive: birds wheeling overhead, dust on the
## wind, smoke from a fire, water dripping in a cave. Layout `ambience` places the birds
## and dust; props add their own smoke and drips. Presentation only: no collision, no
## gameplay random draws, nothing saved.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var clock: float = 0.0
var _birds: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _flames: Array[Node3D] = []
var _flags: Array[Dictionary] = []
var _hazes: Dictionary[String, StandardMaterial3D] = {}
var _liquids: Dictionary[String, StandardMaterial3D] = {}
var _falling: Array[Dictionary] = []
var _fireflies: Array[Dictionary] = []
var _glow: StandardMaterial3D
var _sprays: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _swaying: Array[Dictionary] = []
var _floating: Array[Dictionary] = []
var _drifting: Array[Dictionary] = []
## How far into night the view is (0 day .. 1 night), set by the view each frame:
## fireflies come out only in the dark.
var night: float = 0.0

## `birds`: [{"at": [x, y] px, "radius": px, "count": n, "height": units, "color": hex}],
## `dust`: [{"rect": [x0, y0, x1, y1] px, "count": n, "color": hex, "wind": [x, z]}],
## `fall`: pine needles or leaves drifting down from the canopy, [{"rect", "count",
## "colors", "height", "wind"}], `fireflies`: [{"rect", "count", "color", "height"}].
func configure(data: Dictionary) -> void:
	var shapes := Shapes.new()
	var index: int = 0
	for flock: Dictionary in data.get("birds",[]):
		var at: Array = flock["at"]
		for i: int in int(flock.get("count",3)):
			var bird := Node3D.new()
			add_child(bird)
			var color: String = String(flock.get("color","3b332c"))
			shapes.box(bird,Vector3.ZERO,Vector3(0.16,0.12,0.42),color)
			var wings: Array[Node3D] = []
			for side: float in [-1.0,1.0]:
				var wing := Node3D.new()
				bird.add_child(wing)
				shapes.box(wing,Vector3(side*0.32,0,0),Vector3(0.6,0.04,0.24),color)
				wings.append(wing)
			_birds.append({"node":bird,"wings":wings,"centre":Vector3(float(at[0])/32.0,float(flock.get("height",7.0))+i*0.6,float(at[1])/32.0),
				"radius":float(flock.get("radius",160))/32.0*(0.7+0.15*i),"speed":0.35+0.07*i,"phase":index*1.7+i*2.3})
		index += 1
	for cloud: Dictionary in data.get("dust",[]):
		var r: Array = cloud["rect"]
		var wind: Array = cloud.get("wind",[1.0,-0.4])
		for i: int in int(cloud.get("count",24)):
			var mote := Node3D.new()
			add_child(mote)
			shapes.box(mote,Vector3.ZERO,Vector3(0.07,0.05,0.07),String(cloud.get("color","c8b48a")))
			var phase: float = i*12.9898
			_motes.append({"node":mote,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
				"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.7)*24634.6,1.0),"h":0.2+fposmod(sin(phase*2.3)*1531.2,1.0)*1.6,
				"wind":Vector2(float(wind[0]),float(wind[1])),"speed":0.06+fposmod(sin(phase*3.1)*812.7,1.0)*0.08})
	for drift: Dictionary in data.get("fall",[]):
		var r: Array = drift["rect"]
		var colors: Array = drift.get("colors",["8a5a36","a8794a","6e8a47"])
		var wind: Array = drift.get("wind",[0.4,0.2])
		# One MultiMesh for the whole drift (a draw call, not one per needle).
		var needles: MultiMesh = _swarm(Vector3(0.18,0.018,0.035),int(drift.get("count",20)),false)
		for i: int in needles.instance_count:
			needles.set_instance_color(i,Color(String(colors[i%colors.size()])))
			var phase: float = i*7.3121+index*3.1
			_falling.append({"multi":needles,"index":i,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
				"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.9)*24634.6,1.0),"t":fposmod(sin(phase*2.7)*9137.1,1.0),
				"height":float(drift.get("height",5.0)),"wind":Vector2(float(wind[0]),float(wind[1])),"rate":0.09+fposmod(sin(phase*3.3)*512.9,1.0)*0.06})
		index += 1
	for swarm: Dictionary in data.get("fireflies",[]):
		var r: Array = swarm["rect"]
		if _glow == null:
			_glow = StandardMaterial3D.new()
			_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_glow.albedo_color = Color(String(swarm.get("color","d9f27a")))
			_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var flies: MultiMesh = _swarm(Vector3.ONE*0.07,int(swarm.get("count",12)),true)
		var holder := get_child(get_child_count()-1) as MultiMeshInstance3D
		for i: int in flies.instance_count:
			var phase: float = i*5.137+index*1.3
			_fireflies.append({"node":holder,"multi":flies,"index":i,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
				"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.3)*24634.6,1.0),"h":float(swarm.get("height",1.0)),"phase":phase})
		index += 1
	shapes.flush()

## Many small boxes moved together each frame: one MultiMesh (instance colours for needles,
## the shared glow for fireflies) under one instance.
func _swarm(size: Vector3, count: int, glowing: bool) -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not glowing
	multi.mesh = cube
	multi.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Never culled by its first frame's bounds: the instances move all over their rect.
	instance.extra_cull_margin = 64.0
	if glowing:
		instance.material_override = _glow
	else:
		var needle := StandardMaterial3D.new()
		needle.vertex_color_use_as_albedo = true
		needle.roughness = 0.95
		instance.material_override = needle
	add_child(instance)
	return multi

## Spray and mist where falling water strikes (a waterfall's foot): pale puffs billowing
## out across `radius` (units) about a (local) point and rising as they thin.
func mist(parent: Node3D, at: Vector3, radius: float, color: String = "e4eef0", count: int = 10) -> void:
	if not _hazes.has(color+"mist"):
		var haze := StandardMaterial3D.new()
		haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		haze.albedo_color = Color(color,0.16)
		_hazes[color+"mist"] = haze
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*0.3
	for i: int in count:
		var puff := MeshInstance3D.new()
		puff.mesh = cube
		puff.material_override = _hazes[color+"mist"]
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(puff)
		_sprays.append({"node":puff,"base":at,"phase":float(i)/count,"angle":i*2.39996,"radius":radius})

## Bubbles rising in still water and breaking at the surface (lake.c's 气泡), within
## `radius` units of a (local) point at the water's level.
func bubbles(parent: Node3D, at: Vector3, radius: float, color: String = "c9d8c4", count: int = 6) -> void:
	if not _liquids.has(color+"bubble"):
		var liquid := StandardMaterial3D.new()
		liquid.albedo_color = Color(color)
		liquid.roughness = 0.05
		liquid.metallic = 0.3
		_liquids[color+"bubble"] = liquid
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE*0.09
	for i: int in count:
		var bubble := MeshInstance3D.new()
		bubble.mesh = mesh
		bubble.material_override = _liquids[color+"bubble"]
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(bubble)
		var a: float = i*2.39996
		_bubbles.append({"node":bubble,"base":at+Vector3(cos(a),0,sin(a))*radius*sqrt(float(i+1)/count),"phase":fposmod(i*0.618,1.0)})

## A hanging thing (a vine, a curtain's strip) that swings gently about its top.
func sway(node: Node3D, phase: float, amount: float = 0.08) -> void:
	_swaying.append({"node":node,"phase":phase,"amount":amount})

## A floating thing (a moored boat) riding the swell: it rises and falls by `height` units
## and rolls by `roll` radians about where it was put.
func bob(node: Node3D, phase: float, height: float = 0.08, roll: float = 0.05) -> void:
	_floating.append({"node":node,"phase":phase,"height":height,"roll":roll,"base":node.position,"turn":node.rotation})

## Mist (a cloud sea's billows) that drifts slowly back and forth about where it was put, up
## to `reach` units, never leaving its bed.
func drift(node: Node3D, phase: float, reach: float = 1.2) -> void:
	_drifting.append({"node":node,"phase":phase,"reach":reach,"base":node.position})

## Grey puffs rising from a fire's (local) point, swelling and thinning as they go.
## `size`: a puff's width at the start (a thread of incense smoke is thin).
func smoke(parent: Node3D, at: Vector3, color: String = "8d877c", count: int = 6, size: float = 0.3) -> void:
	if not _hazes.has(color):
		var haze := StandardMaterial3D.new()
		haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		haze.albedo_color = Color(color,0.42)
		_hazes[color] = haze
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*size
	for i: int in count:
		var puff := MeshInstance3D.new()
		puff.mesh = cube
		puff.material_override = _hazes[color]
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(puff)
		_puffs.append({"node":puff,"base":at,"phase":float(i)/count,"rise":3.2 if size>=0.2 else 1.4})

## Flame tongues that jump in height (the light's own flicker is the lamp's `flicker` meta).
func flame(node: Node3D) -> void:
	_flames.append(node)

## A strip of cloth (a flag's) that stirs about its pole end.
func flutter(node: Node3D, phase: float) -> void:
	_flags.append({"node":node,"phase":phase})

## A drop falling from `height` onto the floor at a (local) point, every few seconds:
## water by default, or grit (`color`) trickling from loose rock.
func drip(parent: Node3D, at: Vector3, height: float, color: String = "") -> void:
	if not _liquids.has(color):
		var liquid := StandardMaterial3D.new()
		liquid.albedo_color = Color("9fc3cc") if color.is_empty() else Color(color)
		liquid.roughness = 0.05 if color.is_empty() else 1.0
		liquid.metallic = 0.4 if color.is_empty() else 0.0
		if color.is_empty():
			liquid.emission_enabled = true
			liquid.emission = Color("6f98a3")
			liquid.emission_energy_multiplier = 0.4
		_liquids[color] = liquid
	var material: StandardMaterial3D = _liquids[color]
	var drop := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06,0.12,0.06)
	drop.mesh = mesh
	drop.material_override = material
	parent.add_child(drop)
	var ring := MeshInstance3D.new()
	var flat := BoxMesh.new()
	flat.size = Vector3(0.3,0.01,0.3)
	ring.mesh = flat
	ring.material_override = material
	parent.add_child(ring)
	_drops.append({"drop":drop,"ring":ring,"at":at,"height":height,"phase":fposmod(at.x*0.37+at.z*0.71,1.0)})

func advance(delta: float) -> void:
	clock += delta
	for bird: Dictionary in _birds:
		var t: float = clock*float(bird["speed"])+float(bird["phase"])
		var node: Node3D = bird["node"]
		var radius: float = bird["radius"]
		node.position = bird["centre"]+Vector3(cos(t)*radius,sin(t*0.7)*0.4,sin(t)*radius)
		node.rotation.y = -t
		var flap: float = sin(clock*9.0+float(bird["phase"]))*0.55 if fposmod(t,6.0)<2.2 else 0.12
		(bird["wings"][0] as Node3D).rotation.z = flap
		(bird["wings"][1] as Node3D).rotation.z = -flap
	for mote: Dictionary in _motes:
		var travel: float = clock*float(mote["speed"])
		var wind: Vector2 = mote["wind"]
		var u: float = fposmod(float(mote["u"])+travel*wind.x,1.0)
		var v: float = fposmod(float(mote["v"])+travel*wind.y,1.0)
		(mote["node"] as Node3D).position = Vector3(float(mote["x0"])+u*float(mote["w"]),float(mote["h"])+sin(clock*1.3+float(mote["u"])*9.0)*0.15,float(mote["z0"])+v*float(mote["d"]))
	for puff: Dictionary in _puffs:
		var life: float = fposmod(clock*0.28+float(puff["phase"]),1.0)
		var node: MeshInstance3D = puff["node"]
		node.position = puff["base"]+Vector3(sin(life*4.0+float(puff["phase"])*6.0)*0.15+life*0.6,life*float(puff["rise"]),life*0.25)
		node.scale = Vector3.ONE*(0.5+life*2.2)*(1.0-smoothstep(0.75,1.0,life))
	for flag: Dictionary in _flags:
		var t: float = clock*3.2+float(flag["phase"])
		(flag["node"] as Node3D).rotation = Vector3(sin(t*1.7)*0.12,sin(t)*0.45+0.2,sin(t*2.3)*0.08)
	for node: Node3D in _flames:
		node.scale.y = 0.75+0.35*absf(sin(clock*11.0+node.position.x*7.0))+0.15*sin(clock*23.0)
	for needle: Dictionary in _falling:
		var life: float = fposmod(clock*float(needle["rate"])+float(needle["t"]),1.0)
		var wind: Vector2 = needle["wind"]
		var u: float = fposmod(float(needle["u"])+life*wind.x*0.08,1.0)
		var v: float = fposmod(float(needle["v"])+life*wind.y*0.08,1.0)
		var at := Vector3(float(needle["x0"])+u*float(needle["w"])+sin(clock*1.7+float(needle["t"])*9.0)*0.2,float(needle["height"])*(1.0-life),float(needle["z0"])+v*float(needle["d"]))
		var turn := Basis.from_euler(Vector3(sin(clock*2.1+float(needle["u"])*7.0)*0.6,clock*1.3+float(needle["v"])*6.0,0))
		(needle["multi"] as MultiMesh).set_instance_transform(int(needle["index"]),Transform3D(turn,at))
	var dark: float = clampf((night-0.35)/0.5,0.0,1.0)
	if _glow != null:
		_glow.albedo_color.a = dark
	for fly: Dictionary in _fireflies:
		var node: MultiMeshInstance3D = fly["node"]
		node.visible = dark > 0.01
		if not node.visible:
			continue
		var t: float = clock*0.25+float(fly["phase"])
		var at := Vector3(float(fly["x0"])+fposmod(float(fly["u"])+sin(t)*0.08+sin(t*2.3)*0.03,1.0)*float(fly["w"]),float(fly["h"])+sin(t*3.1)*0.35,float(fly["z0"])+fposmod(float(fly["v"])+cos(t*0.8)*0.08,1.0)*float(fly["d"]))
		var glow: float = 0.4+0.6*maxf(0.0,sin(clock*2.7+float(fly["phase"])*3.0))
		(fly["multi"] as MultiMesh).set_instance_transform(int(fly["index"]),Transform3D(Basis.from_scale(Vector3.ONE*glow),at))
	for spray: Dictionary in _sprays:
		var life: float = fposmod(clock*0.35+float(spray["phase"]),1.0)
		var a: float = float(spray["angle"])+life*0.6
		var node: MeshInstance3D = spray["node"]
		node.position = spray["base"]+Vector3(cos(a)*float(spray["radius"])*(0.3+life*0.9),0.2+life*2.2,sin(a)*float(spray["radius"])*(0.3+life*0.9)*0.6)
		node.scale = Vector3.ONE*(0.5+life*1.6)*(1.0-smoothstep(0.6,1.0,life))
	for bubble: Dictionary in _bubbles:
		var life: float = fposmod(clock*0.45+float(bubble["phase"]),1.0)
		var node: MeshInstance3D = bubble["node"]
		node.visible = life < 0.8
		node.position = bubble["base"]+Vector3(sin(life*12.0)*0.03,-0.35+life*0.42,0)
		node.scale = Vector3.ONE*(0.5+life*0.8)
	for boat: Dictionary in _floating:
		var t: float = clock*1.4+float(boat["phase"])
		var node: Node3D = boat["node"]
		node.position = boat["base"]+Vector3(0,sin(t)*float(boat["height"]),0)
		var turn: Vector3 = boat["turn"]
		node.rotation = turn+Vector3(sin(t*0.7+0.6)*float(boat["roll"])*0.4,0,sin(t*0.83)*float(boat["roll"]))
	for mist: Dictionary in _drifting:
		var t: float = clock*0.06+float(mist["phase"])
		(mist["node"] as Node3D).position = mist["base"]+Vector3(sin(t)*float(mist["reach"]),sin(t*0.7)*0.08,sin(t*0.53+1.1)*float(mist["reach"])*0.5)
	for hanging: Dictionary in _swaying:
		var t: float = clock*1.1+float(hanging["phase"])
		(hanging["node"] as Node3D).rotation = Vector3(sin(t)*float(hanging["amount"]),0,sin(t*0.73+1.3)*float(hanging["amount"])*0.7)
	for entry: Dictionary in _drops:
		var cycle: float = fposmod(clock/2.6+float(entry["phase"]),1.0)
		var fall: float = clampf(cycle/0.35,0.0,1.0)
		var drop: MeshInstance3D = entry["drop"]
		var ring: MeshInstance3D = entry["ring"]
		drop.visible = cycle<0.35
		drop.position = entry["at"]+Vector3(0,float(entry["height"])*(1.0-fall*fall),0)
		ring.visible = cycle>=0.35 and cycle<0.7
		var spread: float = (cycle-0.35)/0.35
		ring.position = entry["at"]+Vector3(0,0.02,0)
		ring.scale = Vector3(0.4+spread*2.0,1,0.4+spread*2.0)
