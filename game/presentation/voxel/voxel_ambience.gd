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

## `birds`: [{"at": [x, y] px, "radius": px, "count": n, "height": units, "color": hex}],
## `dust`: [{"rect": [x0, y0, x1, y1] px, "count": n, "color": hex, "wind": [x, z]}].
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
	shapes.flush()

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
