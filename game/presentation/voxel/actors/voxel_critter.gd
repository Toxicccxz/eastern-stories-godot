extends Node3D

## A small animal loose on the map (青石村's hens, the headman's dog): a chicken that struts,
## stops to peck, and flaps off a few steps, or a dog that pads about, sits and wags its tail.
## It wanders on the open ground it was given (`cells`, px centres of walkable floor within its
## range) and never leaves it; presentation only — no 2D body, nothing saved, no gameplay random
## draws (its own seeded source).
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
const UNIT: float = 32.0
var kind: String = "chicken"
var colors: Array = []
var cells: Array[Vector2] = []
var seed: int = 0
var speed: float = 0.9
var _rng := RandomNumberGenerator.new()
var _target: Vector3
var _rest: float = 0.0
var _clock: float = 0.0
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _sitting: bool = false
var _open: Dictionary[Vector2i,bool] = {}

func _ready() -> void:
	_rng.seed = seed
	_clock = _rng.randf()*6.0
	var s := Shapes.new()
	_body = Node3D.new()
	add_child(_body)
	match kind:
		"dog":
			_dog(s)
		_:
			_chicken(s)
	s.flush()
	for cell: Vector2 in cells:
		_open[Vector2i(cell)] = true
	if not cells.is_empty():
		var start: Vector2 = cells[_rng.randi_range(0,cells.size()-1)]
		position = Vector3(start.x/UNIT,0,start.y/UNIT)
	_target = position
	_rest = _rng.randf_range(0.5,2.0)

func _chicken(s: Shapes) -> void:
	var feathers: String = String(colors[0]) if colors.size()>0 else "e8dcc8"
	var wing: String = String(colors[1]) if colors.size()>1 else "c8b89a"
	var comb: String = String(colors[2]) if colors.size()>2 else "c83a2a"
	s.box(_body,Vector3(0,0.3,0),Vector3(0.26,0.24,0.38),feathers)
	s.box(_body,Vector3(0,0.34,-0.2),Vector3(0.18,0.2,0.12),wing)
	s.tilted_box(_body,Vector3(0,0.46,-0.26),Vector3(0.05,0.2,0.1),wing,Vector3(0.6,0,0))
	for side: float in [-1.0,1.0]:
		s.box(_body,Vector3(side*0.14,0.3,0.02),Vector3(0.03,0.16,0.26),wing)
	_head = Node3D.new()
	_head.position = Vector3(0,0.44,0.16)
	_body.add_child(_head)
	s.box(_head,Vector3(0,0.1,0.04),Vector3(0.06,0.22,0.08),feathers)
	s.box(_head,Vector3(0,0.24,0.08),Vector3(0.12,0.12,0.14),feathers)
	s.box(_head,Vector3(0,0.32,0.08),Vector3(0.03,0.07,0.1),comb)
	s.box(_head,Vector3(0,0.22,0.17),Vector3(0.04,0.04,0.08),"e0a040")
	s.box(_head,Vector3(0,0.16,0.14),Vector3(0.04,0.06,0.03),comb)
	for side: float in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.06,0.18,0.02)
		_body.add_child(leg)
		_legs.append(leg)
		s.box(leg,Vector3(0,-0.09,0),Vector3(0.025,0.18,0.025),"e0a040")
		s.box(leg,Vector3(0,-0.175,0.03),Vector3(0.08,0.015,0.1),"e0a040")

func _dog(s: Shapes) -> void:
	var fur: String = String(colors[0]) if colors.size()>0 else "b89a6a"
	var dark: String = String(colors[1]) if colors.size()>1 else "7a6040"
	s.box(_body,Vector3(0,0.42,0),Vector3(0.3,0.3,0.7),fur)
	s.box(_body,Vector3(0,0.5,-0.2),Vector3(0.26,0.18,0.3),dark)
	_head = Node3D.new()
	_head.position = Vector3(0,0.56,0.38)
	_body.add_child(_head)
	s.box(_head,Vector3(0,0.02,0),Vector3(0.24,0.22,0.24),fur)
	s.box(_head,Vector3(0,-0.04,0.16),Vector3(0.14,0.12,0.14),dark)
	s.box(_head,Vector3(0,0.0,0.24),Vector3(0.06,0.05,0.04),"1e1a18")
	for side: float in [-1.0,1.0]:
		s.tilted_box(_head,Vector3(side*0.1,0.12,-0.04),Vector3(0.06,0.14,0.04),dark,Vector3(0,0,side*0.5))
		s.box(_head,Vector3(side*0.07,0.05,0.12),Vector3(0.03,0.03,0.02),"1e1a18")
	for i: int in 4:
		var leg := Node3D.new()
		leg.position = Vector3(-0.1 if i%2==0 else 0.1,0.28,0.24 if i<2 else -0.24)
		_body.add_child(leg)
		_legs.append(leg)
		s.box(leg,Vector3(0,-0.14,0),Vector3(0.08,0.28,0.09),fur if i<2 else dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0,0.5,-0.36)
	_body.add_child(_tail)
	s.tilted_box(_tail,Vector3(0,0.12,-0.1),Vector3(0.05,0.3,0.05),dark,Vector3(0.7,0,0))

func _process(delta: float) -> void:
	_clock += delta
	var flat: Vector3 = _target-position
	flat.y = 0.0
	if _rest > 0.0:
		_rest -= delta
		_idle()
		if _rest <= 0.0 and not cells.is_empty():
			# Off to another spot nearby, never far in one go, and only where the way there is
			# open ground all along (no cutting through a wall's corner or a cart).
			var here := Vector2(position.x,position.z)*UNIT
			for pick: int in 8:
				var spot: Vector2 = cells[_rng.randi_range(0,cells.size()-1)]
				if spot.distance_to(here) > (128.0 if kind=="dog" else 96.0) or not _clear(here,spot):
					continue
				_target = Vector3(spot.x/UNIT,0,spot.y/UNIT)
				break
			_sitting = false
		return
	if flat.length() < 0.05:
		position = Vector3(_target.x,0,_target.z)
		_rest = _rng.randf_range(1.0,4.0) if kind=="chicken" else _rng.randf_range(2.0,6.0)
		_sitting = kind=="dog" and _rng.randf() < 0.4
		return
	var step: Vector3 = flat.normalized()*minf(speed*delta,flat.length())
	position += step
	rotation.y = atan2(flat.x,flat.z)
	_walk()

## Whether every step of the straight way from `from` to `to` (px) is on open ground.
func _clear(from: Vector2, to: Vector2) -> bool:
	var steps: int = maxi(1,ceili(from.distance_to(to)/6.0))
	for i: int in steps+1:
		var at: Vector2 = from.lerp(to,float(i)/steps)
		if not _open.has(Vector2i(floori(at.x/16)*16+8,floori(at.y/16)*16+8)):
			return false
	return true

func _idle() -> void:
	match kind:
		"dog":
			var sit: float = 1.0 if _sitting else 0.0
			_body.rotation.x = lerpf(_body.rotation.x,-0.45*sit,0.1)
			_body.position.y = lerpf(_body.position.y,-0.12*sit,0.1)
			_tail.rotation.y = sin(_clock*6.0)*0.6
			_head.rotation.y = sin(_clock*0.7)*0.5
			for i: int in _legs.size():
				_legs[i].rotation.x = lerpf(_legs[i].rotation.x,0.0,0.2)
		_:
			# Pecking: the head dips to the ground in quick nods, then looks about.
			var peck: float = fposmod(_clock,3.0)
			_head.rotation.x = 1.1*maxf(0.0,sin(peck*9.0)) if peck < 1.4 else 0.0
			_head.rotation.y = sin(_clock*1.3)*0.4 if peck >= 1.4 else 0.0
			_body.position.y = 0.0
			for leg: Node3D in _legs:
				leg.rotation.x = 0.0

func _walk() -> void:
	var t: float = _clock*(9.0 if kind=="chicken" else 7.0)
	for i: int in _legs.size():
		_legs[i].rotation.x = sin(t+i*PI)*0.6
	match kind:
		"dog":
			_body.rotation.x = 0.0
			_body.position.y = absf(sin(t))*0.03
			_tail.rotation.y = sin(_clock*4.0)*0.3
			_head.rotation.y = 0.0
			_head.rotation.x = 0.0
		_:
			# The head jabs forward with each step.
			_head.rotation.x = 0.0
			_head.position.z = 0.16+maxf(0.0,sin(t))*0.06
			_body.position.y = absf(sin(t))*0.02
