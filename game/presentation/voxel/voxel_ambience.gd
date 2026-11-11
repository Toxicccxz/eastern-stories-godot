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
var _bolts: Array[Dictionary] = []
var _sunbeams: Array[Dictionary] = []
var _fish: Array[Dictionary] = []
var _blinks: Array[Dictionary] = []
var _spinning: Array[Dictionary] = []
## How far into night the view is (0 day .. 1 night), set by the view each frame:
## fireflies come out only in the dark.
var night: float = 0.0
## 第十章 A (DECISIONS「风」): the map's guiding wind as the view gives it each frame (px space unit
## vector, ZERO still); dust with `follows_wind` drifts along it instead of its own `wind`.
var guiding_wind: Vector2 = Vector2.ZERO
## DECISIONS「氛围动画」: the view's camera. What stirs out of its sight is not moved (each
## frame's pose is the clock's, so it is where it should be when it comes back into sight), and a
## slow sway is written only once it has moved a step: a moved thing is work for the renderer
## (its bounds, its lights, the shadows it casts), however little it moved. Unset: all of it moves.
var camera: Camera3D
## What the camera sees (local units): the middle of the screen and its right and up, and how
## far the screen reaches along them, grown by SEEN_MARGIN (a flag's cloth, a puff's rise reach
## past where they hang, a waterfall's spray past its foot, a ferry past its middle). The view is
## orthogonal, so a thing is on screen exactly when its offset along right and up is within that;
## `_watching` false (no camera, another projection): all of it.
var _watching: bool = false
var _sight_origin := Vector3.ZERO
var _sight_right := Vector3.RIGHT
var _sight_up := Vector3.UP
var _sight_half := Vector2.ZERO
const SEEN_MARGIN: float = 4.0
## Whether lamps cast shadows now (the view sets it from the lighting): a stirring flag's
## shadow is then cast by a still copy (`_shadow_flag`).
var lamp_shadows: bool = false
var _flags_still_shadow: bool = false
var _flags_shadowed: int = 0
## How a flag's cloth hangs at rest (the middle of its flutter).
const FLAG_REST := Vector3(0.0,0.2,0.0)
## Radians a hanging thing turns before it is written again (a bell's slow swing: well under
## a pixel at the view's scale).
const SWAY_STEP: float = 0.004
## Things that stay put while they stir, each kind's entries near the screen (`_STAYING`), worked
## out again only once the sight has moved: a few hundred hangings on a big map, a few dozen near.
var _near: Dictionary[String, Array] = {}
## The sight `_near` was worked out for (and how many things there were then).
var _near_watching: bool = false
var _near_origin := Vector3.INF
var _near_right := Vector3.ZERO
var _near_up := Vector3.ZERO
var _near_half := Vector2.ZERO
var _near_count: int = -1
## Units past the screen `_near` reaches: the sight may move half of it before it is worked out again.
const SEEN_SLACK: float = 2.0
## Kinds that stay put while they stir: [the entry's node, its rest place in its parent ("": the
## node's own position, which the stirring never moves)].
const _STAYING: Dictionary = {
	"_flags": ["node", ""], "_swaying": ["node", ""], "_floating": ["node", "base"], "_puffs": ["node", "base"],
	"_sprays": ["node", "base"], "_bubbles": ["node", "base"], "_drops": ["drop", "at"], "_flame_entries": ["node", ""],
}
## `_flames` as entries, for `_near`.
var _flame_entries: Array[Dictionary] = []

## `birds`: [{"at": [x, y] px, "radius": px, "count": n, "height": units, "color": hex}],
## `dust`: [{"rect": [x0, y0, x1, y1] px, "count": n, "color": hex, "wind": [x, z], "height": [low, high]}],
## `fall`: pine needles or leaves drifting down from the canopy, [{"rect", "count",
## "colors", "height", "wind"}] (`up`: sparks rising from a fire instead, `glow`: lit by
## themselves), `fireflies`: [{"rect", "count", "color", "height"}]; dust may have a `size`
## (units: a long streak of mist on the wind; `alpha`: seen through), `flit` (moths: quick darting about a lamp),
## `day` (seen only while it is light: motes in a sunbeam), `follows_wind` (carried along the
## map's guiding wind, `guiding_wind`, its `wind` only how fast), `beam` (a faint slanting shaft of
## light from the rect's first edge down into the room, with the motes; day only).
## `lightning`: [{"rect", "every" seconds, "color", "height", "range", "energy"}]: a bolt now
## and then somewhere over the rect, the land lit white. `smoke`: [{"at": [x, y] px, "height"
## units, "color", "count", "size"}]: puffs rising from a spot (a room's stove or lamp when no
## prop of its own smokes there). A flock may have a `size` (a bird's scale: small swallows, big
## birds) and `rise` (units between one bird's height and the next). `fish`: [{"rect", "count",
## "height": [low, high], "color", "size"}]: small dark fish swimming back and forth (lakebottom2.c:
## 能模糊地看到顶外的小鱼游来游去).
func configure(data: Dictionary) -> void:
	add(data)

## More of the same after `configure` (a room's life adds what its use calls for: VoxelLife).
func add(data: Dictionary) -> void:
	var shapes := Shapes.new()
	var index: int = 0
	for flock: Dictionary in data.get("birds",[]):
		var at: Array = flock["at"]
		for i: int in int(flock.get("count",3)):
			var bird := Node3D.new()
			add_child(bird)
			bird.scale = Vector3.ONE*float(flock.get("size",1.0))
			var color: String = String(flock.get("color","3b332c"))
			shapes.box(bird,Vector3.ZERO,Vector3(0.16,0.12,0.42),color)
			var wings: Array[Node3D] = []
			for side: float in [-1.0,1.0]:
				var wing := Node3D.new()
				bird.add_child(wing)
				shapes.box(wing,Vector3(side*0.32,0,0),Vector3(0.6,0.04,0.24),color)
				wings.append(wing)
			_birds.append({"node":bird,"wings":wings,"centre":Vector3(float(at[0])/32.0,float(flock.get("height",7.0))+i*float(flock.get("rise",0.6)),float(at[1])/32.0),
				"radius":float(flock.get("radius",160))/32.0*(0.7+0.15*i),"speed":0.35+0.07*i,"phase":index*1.7+i*2.3})
		index += 1
	for cloud: Dictionary in data.get("dust",[]):
		var r: Array = cloud["rect"]
		var wind: Array = cloud.get("wind",[1.0,-0.4])
		var grain: Array = cloud.get("size",[0.07,0.05,0.07])
		# One MultiMesh for the cloud (a draw call, not one per mote).
		var alpha: float = float(cloud.get("alpha",1.0))
		# `height`: [low, high] units the motes keep between (moths under a lamp hang high).
		var band: Array = cloud.get("height",[0.2,1.8])
		var flit: float = float(cloud.get("flit",0.0))
		var reach := Vector3(0.22*flit,0.15+0.12*flit,0.22*flit)+Vector3(float(grain[0]),float(grain[1]),float(grain[2]))
		var motes: MultiMesh = _swarm(Vector3(float(grain[0]),float(grain[1]),float(grain[2])),int(cloud.get("count",24)),false,alpha < 1.0,alpha < 1.0,
			_within(r,float(band[0]),float(band[1]),reach))
		var holder := get_child(get_child_count()-1) as MultiMeshInstance3D
		var tone := Color(String(cloud.get("color","c8b48a")),alpha)
		for i: int in motes.instance_count:
			motes.set_instance_color(i,tone)
			var phase: float = i*12.9898+index*3.7
			_motes.append({"multi":motes,"index":i,"holder":holder,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
				"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.7)*24634.6,1.0),"h":float(band[0])+fposmod(sin(phase*2.3)*1531.2,1.0)*(float(band[1])-float(band[0])),
				"wind":Vector2(float(wind[0]),float(wind[1])),"speed":0.06+fposmod(sin(phase*3.1)*812.7,1.0)*0.08,
				"flit":float(cloud.get("flit",0.0)),"day":cloud.get("day",false),"follows":cloud.get("follows_wind",false),"top":float(band[1])+0.5})
		if cloud.get("beam",false):
			_beam(cloud,shapes)
		index += 1
	for drift: Dictionary in data.get("fall",[]):
		var r: Array = drift["rect"]
		var colors: Array = drift.get("colors",["8a5a36","a8794a","6e8a47"])
		var wind: Array = drift.get("wind",[0.4,0.2])
		# One MultiMesh for the whole drift (a draw call, not one per needle).
		var needles: MultiMesh = _swarm(Vector3(0.18,0.018,0.035) if not drift.get("up",false) else Vector3(0.06,0.06,0.06),int(drift.get("count",20)),false,drift.get("glow",false),false,
			_within(r,0.0,float(drift.get("height",5.0)),Vector3(0.4,0.2,0.2)))
		for i: int in needles.instance_count:
			needles.set_instance_color(i,Color(String(colors[i%colors.size()])))
			var phase: float = i*7.3121+index*3.1
			_falling.append({"multi":needles,"index":i,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
				"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.9)*24634.6,1.0),"t":fposmod(sin(phase*2.7)*9137.1,1.0),
				"height":float(drift.get("height",5.0)),"wind":Vector2(float(wind[0]),float(wind[1])),"rate":0.09+fposmod(sin(phase*3.3)*512.9,1.0)*0.06,"up":drift.get("up",false),"top":float(drift.get("height",5.0))})
		index += 1
	for swarm: Dictionary in data.get("fireflies",[]):
		var r: Array = swarm["rect"]
		if _glow == null:
			_glow = StandardMaterial3D.new()
			_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_glow.albedo_color = Color(String(swarm.get("color","d9f27a")))
			_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var flies: MultiMesh = _swarm(Vector3.ONE*0.07,int(swarm.get("count",12)),true,false,false,
			_within(r,float(swarm.get("height",1.0)),float(swarm.get("height",1.0)),Vector3(0.1,0.45,0.1)))
		var holder := get_child(get_child_count()-1) as MultiMeshInstance3D
		for i: int in flies.instance_count:
			var phase: float = i*5.137+index*1.3
			_fireflies.append({"node":holder,"multi":flies,"index":i,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
				"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.3)*24634.6,1.0),"h":float(swarm.get("height",1.0)),"phase":phase,"top":float(swarm.get("height",1.0))+0.5})
		index += 1
	for school: Dictionary in data.get("fish",[]):
		_school(school,index,shapes)
		index += 1
	for storm: Dictionary in data.get("lightning",[]):
		_lightning(storm,index)
		index += 1
	for fire: Dictionary in data.get("smoke",[]):
		var at: Array = fire["at"]
		smoke(self,Vector3(float(at[0])/32.0,float(fire.get("height",1.2)),float(at[1])/32.0),String(fire.get("color","8d877c")),int(fire.get("count",5)),float(fire.get("size",0.26)))
	shapes.flush()

## Small fish going to and fro along the rect, at their own heights, tails beating.
func _school(school: Dictionary, index: int, shapes: Shapes) -> void:
	var r: Array = school["rect"]
	var band: Array = school.get("height",[3.0,7.0])
	var color: String = String(school.get("color","3a5a78"))
	var size: float = float(school.get("size",1.0))
	for i: int in int(school.get("count",8)):
		var fish := Node3D.new()
		add_child(fish)
		fish.scale = Vector3.ONE*size
		shapes.box(fish,Vector3.ZERO,Vector3(0.1,0.12,0.4),color)
		var tail := Node3D.new()
		tail.position = Vector3(0,0,-0.2)
		fish.add_child(tail)
		shapes.box(tail,Vector3(0,0,-0.08),Vector3(0.03,0.16,0.14),color)
		var phase: float = i*4.7+index*2.3
		_fish.append({"node":fish,"tail":tail,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
			"u":fposmod(sin(phase)*43758.5,1.0),"v":fposmod(sin(phase*1.7)*24634.6,1.0),"h":float(band[0])+fposmod(sin(phase*2.3)*1531.2,1.0)*(float(band[1])-float(band[0])),
			"rate":0.012+fposmod(sin(phase*3.1)*812.7,1.0)*0.02,"phase":phase})

## A sunbeam: one faint slanting shaft from high on the rect's near (window) edge down to the
## floor at its far edge, seen through, day only (`_sunbeams` fade with the night).
func _beam(cloud: Dictionary, shapes: Shapes) -> void:
	var r: Array = cloud["rect"]
	var band: Array = cloud.get("height",[0.2,2.2])
	# From the window (`beam_from`, px; else the middle of the rect's top edge), high, down to
	# the floor at the rect's middle.
	var side: Array = cloud.get("beam_from",[(float(r[0])+float(r[2]))/2.0,float(r[1])])
	var from := Vector3(float(side[0])/32.0,float(band[1]),float(side[1])/32.0)
	var to := Vector3((float(r[0])+float(r[2]))/64.0,float(band[0]),(float(r[1])+float(r[3]))/64.0)
	var haze := StandardMaterial3D.new()
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.albedo_color = Color(String(cloud.get("color","f0e6c8")),0.06)
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	var along: Vector3 = to-from
	if along.length()<0.1:
		return
	var width: float = minf(float(r[2])-float(r[0]),float(r[3])-float(r[1]))/32.0*0.7
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,0.08,along.length())
	var shaft := MeshInstance3D.new()
	shaft.mesh = mesh
	shaft.material_override = haze
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.transform = Transform3D(Basis.looking_at(along.normalized(),Vector3.UP if absf(along.normalized().y)<0.99 else Vector3.RIGHT),(from+to)/2.0)
	add_child(shaft)
	_sunbeams.append({"node":shaft,"material":haze,"alpha":0.06})

## A bolt (zigzag of white-hot boxes, lit by itself) and the light it throws, both hidden but
## for a flash or two every `every` seconds; the light's energy is its own (VoxelLighting skips
## it: meta `own_energy`).
func _lightning(storm: Dictionary, index: int) -> void:
	var r: Array = storm["rect"]
	var bolt := Node3D.new()
	add_child(bolt)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(String(storm.get("color","e8f0ff")))
	var top: float = float(storm.get("height",14.0))
	var at := Vector3.ZERO
	var cube := BoxMesh.new()
	for step: int in 9:
		var next := at+Vector3(sin(step*2.7)*0.9,-top/9.0,cos(step*1.9)*0.5)*Vector3(top/14.0,1,top/14.0)
		var piece := MeshInstance3D.new()
		piece.mesh = cube
		piece.material_override = glow
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var along: Vector3 = next-at
		piece.transform = Transform3D(Basis.looking_at(along.normalized(),Vector3.RIGHT).scaled_local(Vector3(0.12,0.12,along.length())),(at+next)/2.0+Vector3(0,top,0))
		bolt.add_child(piece)
		at = next
	bolt.visible = false
	var flash := OmniLight3D.new()
	flash.light_color = Color(String(storm.get("color","e8f0ff")))
	flash.omni_range = float(storm.get("range",34.0))
	flash.omni_attenuation = 0.6
	flash.light_energy = 0.0
	flash.visible = false
	flash.set_meta("own_energy",true)
	add_child(flash)
	_bolts.append({"bolt":bolt,"flash":flash,"x0":float(r[0])/32.0,"z0":float(r[1])/32.0,"w":(float(r[2])-float(r[0]))/32.0,"d":(float(r[3])-float(r[1]))/32.0,
		"every":float(storm.get("every",6.0)),"phase":index*0.37,"strike":-1,"top":top,"energy":float(storm.get("energy",5.0))})

## The box (local units) a swarm's things keep within: its rect (px) between `low` and `high`,
## grown by `reach` (how far a thing strays past its place, and its own size).
func _within(r: Array, low: float, high: float, reach: Vector3) -> AABB:
	var box := AABB(Vector3(float(r[0])/32.0,low,float(r[1])/32.0),Vector3((float(r[2])-float(r[0]))/32.0,high-low,(float(r[3])-float(r[1]))/32.0)).abs()
	return box.expand(box.position-reach).expand(box.end+reach)

## Many small boxes moved together each frame: one MultiMesh (instance colours for needles,
## the shared glow for fireflies) under one instance. `bounds`: where its things keep, the
## MultiMesh's own box (DECISIONS「氛围动画」): without it the renderer works the box out again
## from every thing each frame they move (and the swarm is culled and lit by a box 64 units wide).
func _swarm(size: Vector3, count: int, glowing: bool, lit: bool = false, see_through: bool = false, bounds: AABB = AABB()) -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not glowing
	multi.mesh = cube
	multi.instance_count = count
	multi.custom_aabb = bounds
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Without bounds: never culled by its first frame's box (the things move all over their rect).
	instance.extra_cull_margin = 0.0 if bounds.has_volume() else 64.0
	if glowing:
		instance.material_override = _glow
	else:
		var needle := StandardMaterial3D.new()
		needle.vertex_color_use_as_albedo = true
		needle.roughness = 0.95
		if lit:
			needle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if see_through:
			needle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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

## A thing that turns about its upright (the 云台's whirlwind and the sword in it): `speed` radians
## a second, from where it was put.
func spin(node: Node3D, speed: float) -> void:
	_spinning.append({"node":node,"speed":speed,"turn":node.rotation.y})

## Something seen only for a moment now and then (lake.c: 忽的见白光一闪): `node` shows for the
## first `duty` of every `every` seconds.
func blink(node: Node3D, every: float, duty: float, phase: float = 0.0) -> void:
	_blinks.append({"node":node,"every":every,"duty":duty,"phase":phase})

## Flame tongues that jump in height (the light's own flicker is the lamp's `flicker` meta).
func flame(node: Node3D) -> void:
	_flames.append(node)

## A strip of cloth (a flag's) that stirs about its pole end.
func flutter(node: Node3D, phase: float) -> void:
	_flags.append({"node":node,"phase":phase})

## DECISIONS「氛围动画」: while lamps cast shadows a stirring cloth would have the lamps near it
## draw their shadows again every frame it moves. So then the cloth casts none, and a still copy
## of it, hung as the cloth hangs at rest, casts its shadow instead; without lamp shadows (out of
## doors by day) the cloth casts its own as before.
func _shadow_flag(flag: Dictionary, still: bool) -> bool:
	var cloth: Node3D = flag["node"]
	if not flag.has("twin"):
		if not still:
			return true
		if not cloth.is_inside_tree() or not cloth.get_parent() is Node3D:
			return false
		var twin := Node3D.new()
		twin.transform = Transform3D(Basis.from_euler(FLAG_REST),cloth.position)
		var parts: Array = []
		for part: Node in cloth.find_children("*","GeometryInstance3D",true,false):
			var shape := part as GeometryInstance3D
			if shape.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			parts.append([shape,shape.cast_shadow])
			if shape is Label3D:
				continue
			var copy := shape.duplicate(0) as GeometryInstance3D
			for inner: Node in copy.get_children():
				copy.remove_child(inner)
				inner.free()
			copy.transform = cloth.global_transform.affine_inverse()*shape.global_transform
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			twin.add_child(copy)
		cloth.get_parent().add_child(twin)
		flag["twin"] = twin
		flag["parts"] = parts
	(flag["twin"] as Node3D).visible = still
	for entry: Array in flag["parts"]:
		(entry[0] as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if still else entry[1]
	return true

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

## What the camera sees this frame, in local units (`_watching`).
func _watch() -> void:
	_watching = false
	if camera == null or not camera.is_inside_tree() or not is_inside_tree() or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var screen: Vector2 = camera.get_viewport().get_visible_rect().size
	var to_local: Transform3D = global_transform.affine_inverse()
	var turn: Basis = to_local.basis*camera.global_basis
	_sight_right = turn.x.normalized()
	_sight_up = turn.y.normalized()
	_sight_origin = to_local*camera.project_ray_origin(screen/2.0)
	var corner: Vector3 = to_local*camera.project_ray_origin(Vector2.ZERO)-_sight_origin
	_sight_half = Vector2(absf(corner.dot(_sight_right)), absf(corner.dot(_sight_up)))+Vector2.ONE*SEEN_MARGIN
	_watching = true

## Whether a (local) point, or anything within `reach` units of it, is on screen.
func _seen(at: Vector3, reach: float = 0.0) -> bool:
	var off: Vector3 = at-_sight_origin
	return absf(off.dot(_sight_right)) <= _sight_half.x+reach and absf(off.dot(_sight_up)) <= _sight_half.y+reach

## Where a thing that stays put while it stirs stands (local), from its rest place in its parent.
func _anchor(node: Node3D, rest: Vector3) -> Vector3:
	return to_local(node.get_parent().to_global(rest)) if node.get_parent() is Node3D else rest

## Whether an entry's thing is within `reach` of the camera's sight; its place is worked out once,
## when it first can be (in the tree; till then it counts as seen).
func _in_sight(entry: Dictionary, node: Node3D, rest: Vector3, reach: float = 0.0) -> bool:
	if not _watching:
		return true
	var anchor: Variant = entry.get("anchor")
	if anchor == null:
		if not node.is_inside_tree():
			return true
		anchor = _anchor(node, rest)
		entry["anchor"] = anchor
	return _seen(anchor, reach)

## Whether any of a swarm's rect (local units, its things up to its `top`) is in the camera's sight.
func _rect_in_sight(entry: Dictionary) -> bool:
	if not _watching:
		return true
	var w: float = float(entry["w"])
	var d: float = float(entry["d"])
	var top: float = float(entry["top"])
	var middle := Vector3(float(entry["x0"])+w/2.0, top/2.0, float(entry["z0"])+d/2.0)
	return _seen(middle, Vector3(w, top, d).length()/2.0)

## `_near` worked out again when the sight has moved, turned or widened past what it allowed for,
## or there are more things than then.
func _refresh_near() -> void:
	if _flame_entries.size() != _flames.size():
		_flame_entries.clear()
		for node: Node3D in _flames:
			_flame_entries.append({"node": node})
	var count: int = 0
	for kind: String in _STAYING:
		count += (get(kind) as Array).size()
	if count == _near_count and _watching == _near_watching and (not _watching or (
			_sight_origin.distance_to(_near_origin) <= SEEN_SLACK/2.0 and _sight_right.dot(_near_right) > 0.99995
			and _sight_up.dot(_near_up) > 0.99995 and _sight_half.x <= _near_half.x and _sight_half.y <= _near_half.y)):
		return
	_near_count = count
	_near_watching = _watching
	_near_origin = _sight_origin
	_near_right = _sight_right
	_near_up = _sight_up
	_near_half = _sight_half
	for kind: String in _STAYING:
		var spec: Array = _STAYING[kind]
		var near: Array = []
		for entry: Dictionary in get(kind):
			var node: Node3D = entry[spec[0]]
			if not node.is_inside_tree():
				# Placed later: counted as seen till then, and looked at again.
				_near_count = -1
			if _in_sight(entry, node, node.position if String(spec[1]).is_empty() else entry[spec[1]], SEEN_SLACK):
				near.append(entry)
		_near[kind] = near

## Where a mote is now (its swarm's MultiMesh holds it there).
func _mote_place(mote: Dictionary) -> Vector3:
	var u: float = mote["u"]
	var v: float = mote["v"]
	if not mote["follows"]:
		var travel: float = clock*float(mote["speed"])
		var wind: Vector2 = mote["wind"]
		u = fposmod(u+travel*wind.x,1.0)
		v = fposmod(v+travel*wind.y,1.0)
	var at := Vector3(float(mote["x0"])+u*float(mote["w"]),float(mote["h"])+sin(clock*1.3+float(mote["u"])*9.0)*0.15,float(mote["z0"])+v*float(mote["d"]))
	var flit: float = mote["flit"]
	if flit > 0.0:
		# A moth: quick darts about its lamp, never far from it.
		var t: float = clock*4.5+float(mote["v"])*20.0
		at += Vector3(sin(t*1.9)*0.22,sin(t*3.1)*0.12,cos(t*2.3)*0.22)*flit
	return at

## A falling needle (or a rising spark) now: where it is and how it is turned.
func _needle_pose(needle: Dictionary) -> Transform3D:
	var life: float = fposmod(clock*float(needle["rate"])+float(needle["t"]),1.0)
	var wind: Vector2 = needle["wind"]
	var u: float = fposmod(float(needle["u"])+life*wind.x*0.08,1.0)
	var v: float = fposmod(float(needle["v"])+life*wind.y*0.08,1.0)
	var at := Vector3(float(needle["x0"])+u*float(needle["w"])+sin(clock*1.7+float(needle["t"])*9.0)*0.2,float(needle["height"])*(life if needle["up"] else 1.0-life),float(needle["z0"])+v*float(needle["d"]))
	var turn := Basis.from_euler(Vector3(sin(clock*2.1+float(needle["u"])*7.0)*0.6,clock*1.3+float(needle["v"])*6.0,0))
	return Transform3D(turn,at)

## A firefly now: where it is, and its glow as its size.
func _fly_pose(fly: Dictionary) -> Transform3D:
	var t: float = clock*0.25+float(fly["phase"])
	var at := Vector3(float(fly["x0"])+fposmod(float(fly["u"])+sin(t)*0.08+sin(t*2.3)*0.03,1.0)*float(fly["w"]),float(fly["h"])+sin(t*3.1)*0.35,float(fly["z0"])+fposmod(float(fly["v"])+cos(t*0.8)*0.08,1.0)*float(fly["d"]))
	var glow: float = 0.4+0.6*maxf(0.0,sin(clock*2.7+float(fly["phase"])*3.0))
	return Transform3D(Basis.from_scale(Vector3.ONE*glow),at)

func advance(delta: float) -> void:
	clock += delta
	_watch()
	_refresh_near()
	for bird: Dictionary in _birds:
		var t: float = clock*float(bird["speed"])+float(bird["phase"])
		var node: Node3D = bird["node"]
		var radius: float = bird["radius"]
		node.position = bird["centre"]+Vector3(cos(t)*radius,sin(t*0.7)*0.4,sin(t)*radius)
		node.rotation.y = -t
		var flap: float = sin(clock*9.0+float(bird["phase"]))*0.55 if fposmod(t,6.0)<2.2 else 0.12
		(bird["wings"][0] as Node3D).rotation.z = flap
		(bird["wings"][1] as Node3D).rotation.z = -flap
	var daylight: bool = night < 0.5
	# Whether the swarm of the thing at hand is in sight (a swarm's things come one after another).
	var swarm: MultiMesh = null
	var swarm_seen: bool = true
	for mote: Dictionary in _motes:
		if mote["day"]:
			(mote["holder"] as Node3D).visible = daylight
			if not daylight:
				continue
		if mote["follows"]:
			# Along the guiding wind: carried a little each frame (the wind turns, the motes do not jump).
			var push: Vector2 = guiding_wind*float(mote["speed"])*delta*(mote["wind"] as Vector2).length()*6.0
			mote["u"] = fposmod(float(mote["u"])+push.x,1.0)
			mote["v"] = fposmod(float(mote["v"])+push.y,1.0)
		if mote["multi"] != swarm:
			swarm = mote["multi"]
			swarm_seen = _rect_in_sight(mote)
		if not swarm_seen:
			continue
		(mote["multi"] as MultiMesh).set_instance_transform(int(mote["index"]),Transform3D(Basis.IDENTITY,_mote_place(mote)))
	for beam: Dictionary in _sunbeams:
		var node: MeshInstance3D = beam["node"]
		node.visible = daylight
		(beam["material"] as StandardMaterial3D).albedo_color.a = float(beam["alpha"])*clampf(1.0-night*2.0,0.0,1.0)
	for puff: Dictionary in _near["_puffs"]:
		var node: MeshInstance3D = puff["node"]
		var life: float = fposmod(clock*0.28+float(puff["phase"]),1.0)
		node.position = puff["base"]+Vector3(sin(life*4.0+float(puff["phase"])*6.0)*0.15+life*0.6,life*float(puff["rise"]),life*0.25)
		node.scale = Vector3.ONE*(0.5+life*2.2)*(1.0-smoothstep(0.75,1.0,life))
	if lamp_shadows != _flags_still_shadow or _flags.size() != _flags_shadowed:
		_flags_still_shadow = lamp_shadows
		_flags_shadowed = _flags.size()
		for flag: Dictionary in _flags:
			if not _shadow_flag(flag,lamp_shadows):
				# Not hung yet: tried again next frame.
				_flags_shadowed = -1
	for flag: Dictionary in _near["_flags"]:
		var cloth: Node3D = flag["node"]
		var t: float = clock*3.2+float(flag["phase"])
		cloth.rotation = Vector3(sin(t*1.7)*0.12,sin(t)*0.45+FLAG_REST.y,sin(t*2.3)*0.08)
	for flame: Dictionary in _near["_flame_entries"]:
		var node: Node3D = flame["node"]
		node.scale.y = 0.75+0.35*absf(sin(clock*11.0+node.position.x*7.0))+0.15*sin(clock*23.0)
	for needle: Dictionary in _falling:
		if needle["multi"] != swarm:
			swarm = needle["multi"]
			swarm_seen = _rect_in_sight(needle)
		if not swarm_seen:
			continue
		(needle["multi"] as MultiMesh).set_instance_transform(int(needle["index"]),_needle_pose(needle))
	var dark: float = clampf((night-0.35)/0.5,0.0,1.0)
	if _glow != null:
		_glow.albedo_color.a = dark
	for fly: Dictionary in _fireflies:
		var node: MultiMeshInstance3D = fly["node"]
		node.visible = dark > 0.01
		if not node.visible:
			continue
		if fly["multi"] != swarm:
			swarm = fly["multi"]
			swarm_seen = _rect_in_sight(fly)
		if not swarm_seen:
			continue
		(fly["multi"] as MultiMesh).set_instance_transform(int(fly["index"]),_fly_pose(fly))
	for spray: Dictionary in _near["_sprays"]:
		var node: MeshInstance3D = spray["node"]
		var life: float = fposmod(clock*0.35+float(spray["phase"]),1.0)
		var a: float = float(spray["angle"])+life*0.6
		node.position = spray["base"]+Vector3(cos(a)*float(spray["radius"])*(0.3+life*0.9),0.2+life*2.2,sin(a)*float(spray["radius"])*(0.3+life*0.9)*0.6)
		node.scale = Vector3.ONE*(0.5+life*1.6)*(1.0-smoothstep(0.6,1.0,life))
	for bubble: Dictionary in _near["_bubbles"]:
		var node: MeshInstance3D = bubble["node"]
		var life: float = fposmod(clock*0.45+float(bubble["phase"]),1.0)
		node.visible = life < 0.8
		node.position = bubble["base"]+Vector3(sin(life*12.0)*0.03,-0.35+life*0.42,0)
		node.scale = Vector3.ONE*(0.5+life*0.8)
	for boat: Dictionary in _near["_floating"]:
		var node: Node3D = boat["node"]
		var t: float = clock*1.4+float(boat["phase"])
		node.position = boat["base"]+Vector3(0,sin(t)*float(boat["height"]),0)
		var turn: Vector3 = boat["turn"]
		node.rotation = turn+Vector3(sin(t*0.7+0.6)*float(boat["roll"])*0.4,0,sin(t*0.83)*float(boat["roll"]))
	for turning: Dictionary in _spinning:
		(turning["node"] as Node3D).rotation.y = float(turning["turn"])+clock*float(turning["speed"])
	for mist: Dictionary in _drifting:
		var t: float = clock*0.06+float(mist["phase"])
		(mist["node"] as Node3D).position = mist["base"]+Vector3(sin(t)*float(mist["reach"]),sin(t*0.7)*0.08,sin(t*0.53+1.1)*float(mist["reach"])*0.5)
	for storm: Dictionary in _bolts:
		var cycle: float = clock/float(storm["every"])+float(storm["phase"])
		var strike: int = floori(cycle)
		var t: float = (cycle-strike)*float(storm["every"])
		# Two flashes a tenth of a second apart, then dark till the next.
		var lit: bool = t < 0.09 or t > 0.17 and t < 0.24
		var bolt: Node3D = storm["bolt"]
		var flash: OmniLight3D = storm["flash"]
		if strike != int(storm["strike"]):
			storm["strike"] = strike
			var spot := Vector3(float(storm["x0"])+fposmod(sin(strike*12.9898)*43758.5,1.0)*float(storm["w"]),0,float(storm["z0"])+fposmod(sin(strike*78.233)*24634.6,1.0)*float(storm["d"]))
			bolt.position = spot
			bolt.rotation.y = strike*1.3
			flash.position = spot+Vector3(0,float(storm["top"])*0.6,0)
		bolt.visible = lit
		flash.visible = lit
		flash.light_energy = float(storm["energy"]) if lit else 0.0
	for fish: Dictionary in _fish:
		# A long slow there and back: the turn at each end is the triangle wave's corner.
		var along: float = pingpong(clock*float(fish["rate"])+float(fish["u"]),1.0)
		var node: Node3D = fish["node"]
		node.position = Vector3(float(fish["x0"])+along*float(fish["w"]),float(fish["h"])+sin(clock*0.7+float(fish["phase"]))*0.2,float(fish["z0"])+float(fish["v"])*float(fish["d"])+sin(clock*0.4+float(fish["phase"]))*0.5)
		var heading: float = 1.0 if fposmod(clock*float(fish["rate"])+float(fish["u"]),2.0) < 1.0 else -1.0
		node.rotation.y = heading*PI/2.0
		(fish["tail"] as Node3D).rotation.y = sin(clock*8.0+float(fish["phase"]))*0.5
	for entry: Dictionary in _blinks:
		var cycle: float = fposmod(clock+float(entry["phase"]),float(entry["every"]))
		(entry["node"] as Node3D).visible = cycle < float(entry["duty"])
	for hanging: Dictionary in _near["_swaying"]:
		var node: Node3D = hanging["node"]
		var t: float = clock*1.1+float(hanging["phase"])
		var turn := Vector3(sin(t)*float(hanging["amount"]),0,sin(t*0.73+1.3)*float(hanging["amount"])*0.7)
		var shown: Variant = hanging.get("shown")
		if shown != null and absf(turn.x-(shown as Vector3).x) < SWAY_STEP and absf(turn.z-(shown as Vector3).z) < SWAY_STEP:
			continue
		hanging["shown"] = turn
		node.rotation = turn
	for entry: Dictionary in _near["_drops"]:
		var drop: MeshInstance3D = entry["drop"]
		var ring: MeshInstance3D = entry["ring"]
		var cycle: float = fposmod(clock/2.6+float(entry["phase"]),1.0)
		var fall: float = clampf(cycle/0.35,0.0,1.0)
		drop.visible = cycle<0.35
		drop.position = entry["at"]+Vector3(0,float(entry["height"])*(1.0-fall*fall),0)
		ring.visible = cycle>=0.35 and cycle<0.7
		var spread: float = (cycle-0.35)/0.35
		ring.position = entry["at"]+Vector3(0,0.02,0)
		ring.scale = Vector3(0.4+spread*2.0,1,0.4+spread*2.0)
