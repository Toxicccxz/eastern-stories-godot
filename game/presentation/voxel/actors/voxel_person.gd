extends Node3D

const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var walking: bool = false
var pace: float = 0.0
var clock: float = 0.0
var torso: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var eyes: Node3D
var hat: bool = false
var coat: String = "397c87"
## A statue (神像, a figure that never moves): every part in shades of this stone or gilt.
var stone: String = ""

func _ready() -> void:
	clock = float(get_index()) * 1.73
	var s := Shapes.new()
	torso = Node3D.new()
	add_child(torso)
	s.box(torso,Vector3(0,0.91,0),Vector3(0.55,0.58,0.34),_tone(coat))
	s.box(torso,Vector3(0,0.6,0),Vector3(0.62,0.22,0.41),_tone(coat))
	s.box(torso,Vector3(0,0.76,0.015),Vector3(0.57,0.12,0.37),_tone("a34f3c"))
	s.box(torso,Vector3(0.17,0.6,0.23),Vector3(0.1,0.34,0.07),_tone("bc6943"))
	s.box(torso,Vector3(0,1.14,0.15),Vector3(0.23,0.16,0.08),_tone("e9cfa0"))
	s.box(torso,Vector3(-0.08,1.04,0.19),Vector3(0.11,0.12,0.06),_tone("d5c49d"))
	s.box(torso,Vector3(0,1.42,0.035),Vector3(0.43,0.43,0.38),_tone("d7a36c"))
	s.box(torso,Vector3(0,1.59,-0.035),Vector3(0.48,0.18,0.43),_tone("30323b"))
	s.box(torso,Vector3(0,1.4,-0.19),Vector3(0.45,0.37,0.1),_tone("30323b"))
	s.box(torso,Vector3(-0.17,1.46,0.17),Vector3(0.1,0.2,0.07),_tone("30323b"))
	s.box(torso,Vector3(0.12,1.53,0.21),Vector3(0.14,0.12,0.05),_tone("30323b"))
	s.box(torso,Vector3(0,1.75,-0.08),Vector3(0.2,0.19,0.2),_tone("30323b"))
	s.box(torso,Vector3(0,1.67,-0.08),Vector3(0.22,0.06,0.22),_tone("b5573f"))
	s.box(torso,Vector3(0,1.37,0.25),Vector3(0.08,0.08,0.09),_tone("e5b77d"))
	eyes = Node3D.new()
	torso.add_child(eyes)
	eyes.position = Vector3(0,1.45,0.235)
	for x: float in [-0.09,0.09]:
		s.box(eyes,Vector3(x,0,0),Vector3(0.055,0.06,0.035),_tone("242d30"))
	for side: float in [-1.0,1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*0.36,1.12,0)
		torso.add_child(arm)
		arms.append(arm)
		s.box(arm,Vector3(0,-0.14,0),Vector3(0.2,0.34,0.29),_tone(coat))
		s.box(arm,Vector3(0,-0.37,0.02),Vector3(0.17,0.16,0.19),_tone("d7a36c"))
		var leg := Node3D.new()
		leg.position = Vector3(side*0.17,0.57,0)
		add_child(leg)
		legs.append(leg)
		s.box(leg,Vector3(0,-0.2,0),Vector3(0.2,0.4,0.23),_tone("344047"))
		s.box(leg,Vector3(0,-0.43,0.06),Vector3(0.23,0.16,0.35),_tone("524737"))
	if hat:
		for layer: int in 4:
			s.box(torso,Vector3(0,1.7+layer*0.08,0),Vector3(1.0-layer*0.2,0.08,0.9-layer*0.18),_tone(["ad8147","b28d50","bc985d","caa76b"][layer]))
	s.flush()

## A part's colour, or for a statue the stone's shade nearest its lightness.
func _tone(hex: String) -> String:
	if stone.is_empty():
		return hex
	var base := Color(stone)
	var shade: float = Color(hex).get_luminance()-0.45
	return (base.lightened(shade*0.5) if shade>0 else base.darkened(-shade*0.6)).to_html(false)

func _process(delta: float) -> void:
	if not stone.is_empty():
		return
	clock += delta
	pace += delta * (10.5 if walking else 1.0)
	var stride: float = sin(pace)*0.55 if walking else 0.0
	legs[0].rotation.x = stride
	legs[1].rotation.x = -stride
	arms[0].rotation.x = -stride*0.75
	arms[1].rotation.x = stride*0.75
	torso.position.y = absf(sin(pace))*0.045 if walking else sin(clock*2.1)*0.012
	eyes.scale.y = 0.12 if fmod(clock,4.3)<0.13 else 1.0
	if not walking and fmod(clock,7.2)>5.8:
		arms[1].rotation.x = -sin((fmod(clock,7.2)-5.8)/1.4*PI)*0.8
