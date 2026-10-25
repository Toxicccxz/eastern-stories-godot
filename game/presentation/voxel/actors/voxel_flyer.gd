extends Node3D

## A small flying thing (a butterfly): a body hovering at head height and bobbing, wings
## beating. The 2D body still decides where it is; this only floats above that spot.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var wings: Array = ["e8c45a","d98a3a"]
var body_color: String = "3a2f26"
var hover: float = 1.1
var clock: float = 0.0
var walking: bool = false
var _body: Node3D
var _wings: Array[Node3D] = []

func _ready() -> void:
	clock = float(get_index())*0.77
	var s := Shapes.new()
	_body = Node3D.new()
	add_child(_body)
	s.box(_body,Vector3.ZERO,Vector3(0.05,0.05,0.2),body_color)
	for side: float in [-1.0,1.0]:
		var wing := Node3D.new()
		_body.add_child(wing)
		_wings.append(wing)
		s.box(wing,Vector3(side*0.12,0,0.04),Vector3(0.22,0.02,0.18),String(wings[0]))
		s.box(wing,Vector3(side*0.1,0,-0.09),Vector3(0.16,0.02,0.12),String(wings[1%wings.size()]))
		s.box(wing,Vector3(side*0.17,0.005,0.06),Vector3(0.05,0.02,0.05),"2f2a24")
	s.flush()

func _process(delta: float) -> void:
	clock += delta
	_body.position = Vector3(sin(clock*1.3)*0.15,hover+sin(clock*2.4)*0.18,cos(clock*1.1)*0.1)
	var beat: float = sin(clock*19.0)*0.9
	_wings[0].rotation.z = beat
	_wings[1].rotation.z = -beat
