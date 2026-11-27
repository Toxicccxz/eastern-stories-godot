extends RefCounted

## What lies where someone died, by how far the body has gone (CorpseState.Stage, obj/corpse.c):
## fresh, the figure as it fell, dressed, slack, its eyes shut (a beast on its side, a crawling
## thing belly up); rotten (开始腐烂了), the same gone grey-green with flies over it; bones (一具
## 枯乾的骸骨), a skeleton lying the way the body lay, rags of its clothes about it. Drawn from the
## look the figure had (PersonLooks), so each keeps its own colours and kind. Presentation only.
const Person = preload("res://presentation/voxel/actors/voxel_person.gd")
const Crawler = preload("res://presentation/voxel/actors/voxel_crawler.gd")
const Snake = preload("res://presentation/voxel/actors/voxel_snake.gd")
const Flyer = preload("res://presentation/voxel/actors/voxel_flyer.gd")
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const BONE: String = "d6cdb4"
const BONE_SHADE: String = "b8ad92"
const HOLLOW: String = "2a2620"
## How far a rotten body has gone toward the colour of rot.
const ROT: float = 0.75
const ROT_COLOR: String = "5e6248"

## The remains into `node` (turned `facing`, else its own way by `seed`). Returns the drawn body's
## node; a fresh person's is named "Body".
static func build(node: Node3D, look: Dictionary, stage: int, facing: float, seed_value: int) -> Node3D:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var holder := Node3D.new()
	holder.name = "Remains"
	holder.rotation.y = facing if not is_nan(facing) else random.randf()*TAU
	node.add_child(holder)
	var kind: String = String(look.get("body", ""))
	var size: float = float(look.get("scale", 1.0))
	var rotten: bool = stage == CorpseState.Stage.ROTTEN
	if stage >= CorpseState.Stage.SKELETON:
		var s := Shapes.new()
		if kind == "snake":
			_snake_bones(s, holder, size, random)
		elif kind == "flyer":
			_wings_left(s, holder, look, random)
		elif kind == "crawler" or look.get("animal", false):
			_beast_bones(s, holder, size*(0.7 if kind == "crawler" else 1.0), random)
		else:
			_person_bones(s, holder, look, random)
		s.flush()
		return holder
	var body: Node3D
	if kind == "crawler":
		var crawler := Crawler.new()
		crawler.colors = _rotted(look.get("colors", crawler.colors), rotten)
		crawler.spots = String(look.get("spots", crawler.spots))
		crawler.scale = Vector3(size, size*0.75, size)
		body = crawler
	elif kind == "snake":
		var snake := Snake.new()
		snake.colors = _rotted(look.get("colors", snake.colors), rotten)
		snake.belly = _rot(String(look.get("belly", snake.belly)), rotten)
		snake.bands = String(look.get("bands", ""))
		snake.crest = String(look.get("crest", ""))
		snake.scale = Vector3.ONE*size
		# Belly up, the pale underside to the sky.
		snake.rotation.z = PI
		snake.position.y = 0.21*size
		body = snake
	elif kind == "flyer":
		var flyer := Flyer.new()
		flyer.wings = _rotted(look.get("wings", flyer.wings), rotten)
		flyer.hover = 0.03
		flyer.scale = Vector3.ONE*size
		body = flyer
	elif look.get("animal", false):
		body = Node3D.new()
		var s := Shapes.new()
		var side := Node3D.new()
		# On its side, the legs out stiff.
		side.rotation.z = PI/2.0
		side.position = Vector3(0.45, 0.25, 0)
		body.add_child(side)
		quadruped(s, side, look, rotten)
		s.flush()
		body.scale = Vector3.ONE*size
	else:
		var person := Person.new()
		person.coat = String(look.get("coat", "817755"))
		person.configure(look)
		person.limp = 1.0
		person.rot = ROT if rotten else 0.0
		body = person
	holder.add_child(body)
	if body is Person or body is Crawler or body is Snake or body is Flyer:
		# One pose, then still: the dead do not breathe.
		body.set("clock", random.randf()*10.0)
		body.call("_process", 0.0)
		body.set_process(false)
		if body is Person:
			(body as Person).eyes.scale.y = 0.12
			if not rotten:
				body.name = "Body"
	if rotten:
		var flies := Flies.new()
		flies.position = Vector3(0, 0.35, 0)
		flies.spread = 0.45*size if kind != "" or look.get("animal", false) else 0.6
		node.add_child(flies)
	return holder

## The four-legged beast of a look (`fur` colours, `tail`), facing +z, standing on y = 0.
static func quadruped(s: Shapes, model: Node3D, look: Dictionary, rotten: bool = false) -> void:
	var fur: Array = _rotted(look.get("fur", ["a88a60", "846747", "725638"]), rotten)
	s.box(model, Vector3(0, 0.45, 0), Vector3(0.5, 0.45, 0.95), String(fur[0]))
	s.box(model, Vector3(0, 0.72, 0.5), Vector3(0.4, 0.4, 0.42), String(fur[1]))
	for x: float in [-0.18, 0.18]:
		for z: float in [-0.3, 0.3]:
			s.box(model, Vector3(x, 0.18, z), Vector3(0.12, 0.36, 0.13), String(fur[2]))
	if look.get("tail", false):
		s.tilted_box(model, Vector3(0, 0.34, -0.82), Vector3(0.08, 0.08, 0.78), String(fur[1]), Vector3(-0.35, 0, 0))

static func _rot(hex: String, rotten: bool) -> String:
	if not rotten or not hex.get_slice(":", 0).is_valid_html_color():
		return hex
	return Color(hex.get_slice(":", 0)).lerp(Color(ROT_COLOR), 0.6*ROT).darkened(0.3*ROT).to_html(false)

static func _rotted(colors: Array, rotten: bool) -> Array:
	var result: Array = []
	for hex: Variant in colors:
		result.append(_rot(String(hex), rotten))
	return result

## A person's bones lying on their back (the head toward -z, as a fallen figure lies), a little
## out of place, rags of the coat and the trousers over them.
static func _person_bones(s: Shapes, at: Node3D, look: Dictionary, random: RandomNumberGenerator) -> void:
	var jitter := func(amount: float) -> Vector3: return Vector3(random.randf_range(-amount, amount), 0, random.randf_range(-amount, amount))
	var skull: Vector3 = Vector3(0, 0.12, -1.42)+jitter.call(0.06)
	var turn: float = random.randf_range(-0.6, 0.6)
	s.tilted_box(at, skull, Vector3(0.28, 0.24, 0.3), BONE, Vector3(0, turn, 0))
	s.tilted_box(at, skull+Vector3(0, 0.015, 0.02), Vector3(0.3, 0.16, 0.26), BONE, Vector3(0, turn, 0))
	var face := Basis(Vector3.UP, turn)
	for x: float in [-0.065, 0.065]:
		s.tilted_box(at, skull+face*Vector3(x, 0.115, 0.06), Vector3(0.07, 0.03, 0.07), HOLLOW, Vector3(0, turn, 0))
	s.tilted_box(at, skull+face*Vector3(0, 0.12, 0.12), Vector3(0.03, 0.02, 0.04), HOLLOW, Vector3(0, turn, 0))
	# The jaw, fallen a little apart.
	s.tilted_box(at, skull+face*Vector3(0, -0.05, 0.17)+Vector3(0, 0, 0.04), Vector3(0.2, 0.06, 0.1), BONE_SHADE, Vector3(0.3, turn, 0))
	for v: int in 7:
		s.box(at, Vector3(random.randf_range(-0.015, 0.015), 0.05, -1.2+v*0.11), Vector3(0.08, 0.07, 0.08), BONE_SHADE if v%2 else BONE)
	for r: int in 4:
		var z: float = -1.1+r*0.11
		for side: float in [-1.0, 1.0]:
			s.tilted_box(at, Vector3(side*0.14, 0.1, z), Vector3(0.22, 0.045, 0.045), BONE, Vector3(0, 0, -side*0.45))
			s.tilted_box(at, Vector3(side*0.23, 0.05, z+0.01), Vector3(0.05, 0.08, 0.045), BONE_SHADE, Vector3(0, 0, 0))
	s.box(at, Vector3(0, 0.15, -0.95), Vector3(0.06, 0.03, 0.26), BONE_SHADE)
	s.box(at, Vector3(0, 0.06, -0.46), Vector3(0.34, 0.08, 0.14), BONE)
	for side: float in [-1.0, 1.0]:
		s.tilted_box(at, Vector3(side*0.13, 0.07, -0.5), Vector3(0.14, 0.1, 0.16), BONE_SHADE, Vector3(0, side*0.4, 0))
		# The arms: upper, lower, the small bones of the hand strewn.
		var shoulder := Vector3(side*0.3, 0.05, -1.1)
		var spread: float = random.randf_range(0.0, 0.5)
		var elbow: Vector3 = shoulder+Vector3(side*sin(spread)*0.3, 0, cos(spread)*0.3)
		s.tilted_box(at, (shoulder+elbow)/2.0, Vector3(0.055, 0.055, 0.3), BONE, Vector3(0, side*spread, 0))
		var bend: float = spread+random.randf_range(-0.4, 0.6)
		var wrist: Vector3 = elbow+Vector3(side*sin(bend)*0.27, 0, cos(bend)*0.27)
		s.tilted_box(at, (elbow+wrist)/2.0, Vector3(0.045, 0.045, 0.27), BONE_SHADE, Vector3(0, side*bend, 0))
		for _bit: int in 3:
			s.box(at, wrist+jitter.call(0.08)+Vector3(0, -0.02, 0.05), Vector3(0.035, 0.025, 0.05), BONE)
		# The legs: thigh, shin, foot.
		var hip := Vector3(side*0.12, 0.05, -0.42)
		var splay: float = random.randf_range(0.02, 0.22)
		var knee: Vector3 = hip+Vector3(side*sin(splay)*0.44, 0, cos(splay)*0.44)
		s.tilted_box(at, (hip+knee)/2.0, Vector3(0.07, 0.07, 0.44), BONE, Vector3(0, side*splay, 0))
		s.box(at, knee, Vector3(0.08, 0.07, 0.06), BONE_SHADE)
		var ankle: Vector3 = knee+Vector3(side*sin(splay*1.4)*0.42, 0, cos(splay*1.4)*0.42)
		s.tilted_box(at, (knee+ankle)/2.0, Vector3(0.06, 0.06, 0.42), BONE, Vector3(0, side*splay*1.4, 0))
		s.tilted_box(at, ankle+Vector3(side*0.03, 0.04, 0.06), Vector3(0.09, 0.05, 0.16), BONE_SHADE, Vector3(-0.9, side*0.4, 0))
	# What is left of the clothes: torn rags of the coat over the chest and hips, of the
	# trousers about the legs, faded.
	var coat := Color(String(look.get("coat", "817755"))).lerp(Color("8a8270"), 0.45)
	var pants := Color(String(look.get("pants", "344047"))).lerp(Color("6a665a"), 0.4)
	for rag: int in random.randi_range(3, 5):
		var spot := Vector3(random.randf_range(-0.22, 0.22), 0.02+rag*0.002, random.randf_range(-1.15, -0.45))
		s.tilted_box(at, spot, Vector3(random.randf_range(0.14, 0.3), 0.02, random.randf_range(0.1, 0.24)), coat.darkened(random.randf_range(0.0, 0.2)).to_html(false), Vector3(0, random.randf()*TAU, 0))
	for rag: int in random.randi_range(2, 3):
		var spot := Vector3(random.randf_range(-0.25, 0.25), 0.02+rag*0.002, random.randf_range(-0.3, 0.3))
		s.tilted_box(at, spot, Vector3(random.randf_range(0.1, 0.2), 0.02, random.randf_range(0.14, 0.26)), pants.darkened(random.randf_range(0.0, 0.2)).to_html(false), Vector3(0, random.randf()*TAU, 0))

## A four-legged beast's bones on its side: the long skull, the spine and its ribs, the legs.
static func _beast_bones(s: Shapes, at: Node3D, size: float, random: RandomNumberGenerator) -> void:
	var k: float = size
	var skull := Vector3(random.randf_range(-0.05, 0.05), 0.1*k, 0.62*k)
	s.box(at, skull, Vector3(0.24, 0.18, 0.3)*k, BONE)
	s.box(at, skull+Vector3(0, -0.03, 0.2)*k, Vector3(0.14, 0.1, 0.18)*k, BONE)
	for x: float in [-0.07, 0.07]:
		s.box(at, skull+Vector3(x, 0.08, 0.04)*k, Vector3(0.06, 0.03, 0.06)*k, HOLLOW)
	s.tilted_box(at, skull+Vector3(0.05, -0.08, 0.16)*k, Vector3(0.1, 0.04, 0.24)*k, BONE_SHADE, Vector3(0, 0.25, 0))
	for v: int in 9:
		s.box(at, Vector3(0, 0.05*k, (0.42-v*0.13)*k), Vector3(0.08, 0.07, 0.08)*k, BONE_SHADE if v%2 else BONE)
	for r: int in 5:
		var z: float = (0.28-r*0.11)*k
		for side: float in [-1.0, 1.0]:
			s.tilted_box(at, Vector3(side*0.12*k, 0.13*k, z), Vector3(0.05, 0.22, 0.045)*k, BONE, Vector3(0, 0, side*0.7))
	s.box(at, Vector3(0, 0.07*k, -0.4*k), Vector3(0.26, 0.08, 0.14)*k, BONE)
	for z: float in [0.2, -0.4]:
		for side: float in [-1.0, 1.0]:
			var lie: float = random.randf_range(0.2, 0.9)
			var foot := Vector3(side*0.12*k, 0.04*k, z*k)+Vector3(side*sin(lie), 0, cos(lie)*0.4)*0.36*k
			s.tilted_box(at, (Vector3(side*0.12*k, 0.04*k, z*k)+foot)/2.0, Vector3(0.05, 0.05, 0.38)*k, BONE, Vector3(0, side*lie*0.9, 0))
	for t: int in 4:
		s.box(at, Vector3(random.randf_range(-0.03, 0.03), 0.03*k, (-0.55-t*0.09)*k), Vector3(0.05, 0.04, 0.06)*k*(1.0-t*0.15), BONE_SHADE)

## A snake's bones: its spine in the S it died in, a fringe of fine ribs, the small skull.
static func _snake_bones(s: Shapes, at: Node3D, size: float, random: RandomNumberGenerator) -> void:
	var k: float = size
	var phase: float = random.randf()*TAU
	for i: int in 16:
		var z: float = (0.5-i*0.1)*k
		var x: float = sin(phase+i*0.6)*0.16*k
		var thin: float = lerpf(1.0, 0.45, float(i)/15.0)
		s.box(at, Vector3(x, 0.035*k, z), Vector3(0.06, 0.05, 0.07)*k*thin, BONE if i%2 else BONE_SHADE)
		for side: float in [-1.0, 1.0]:
			s.tilted_box(at, Vector3(x+side*0.06*k*thin, 0.03*k, z), Vector3(0.09, 0.015, 0.015)*k*thin, BONE, Vector3(0, side*0.4, 0))
	s.box(at, Vector3(sin(phase-0.6)*0.16*k, 0.05*k, 0.62*k), Vector3(0.12, 0.08, 0.16)*k, BONE)
	for x: float in [-0.035, 0.035]:
		s.box(at, Vector3(sin(phase-0.6)*0.16*k+x*k, 0.09*k, 0.66*k), Vector3(0.03, 0.015, 0.03)*k, HOLLOW)

## A flying thing leaves only its wings, faded, on the ground.
static func _wings_left(s: Shapes, at: Node3D, look: Dictionary, random: RandomNumberGenerator) -> void:
	var wings: Array = look.get("wings", ["e8c45a", "d98a3a"])
	var k: float = float(look.get("scale", 1.0))
	for side: float in [-1.0, 1.0]:
		var tone := Color(String(wings[0])).lerp(Color("b8b0a0"), 0.5)
		s.tilted_box(at, Vector3(side*0.12, 0.012, 0.03)*k, Vector3(0.22, 0.012, 0.18)*k, tone.to_html(false), Vector3(0, random.randf_range(-0.3, 0.3), 0))

## Flies over a rotting body: a few specks darting about above it.
class Flies extends Node3D:
	var spread: float = 0.5
	var clock: float = 0.0
	var _flies: Array[Node3D] = []

	func _ready() -> void:
		clock = float(get_instance_id()%1000)*0.37
		var s := Shapes.new()
		for i: int in 7:
			var fly := Node3D.new()
			add_child(fly)
			s.box(fly, Vector3.ZERO, Vector3(0.07, 0.05, 0.08), "1c1c18")
			s.box(fly, Vector3(0, 0.025, 0), Vector3(0.11, 0.01, 0.04), "8a9090")
			_flies.append(fly)
		s.flush()

	func _process(delta: float) -> void:
		clock += delta
		for i: int in _flies.size():
			var t: float = clock*(1.6+i*0.37)+i*2.1
			_flies[i].position = Vector3(sin(t)*spread*(0.5+0.5*sin(t*0.31+i)), 0.15*sin(t*1.7+i)+0.1*i/_flies.size(), cos(t*1.13)*spread*0.8)
