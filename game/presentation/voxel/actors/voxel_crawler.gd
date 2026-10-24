extends Node3D

## A crawling, segmented body (a rock leech): low on the ground and never still, its
## segments rippling (蠕蠕而动). Faces +z like the other figures; colours from the look.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var colors: Array = ["8f8c84","a29f96","7b786f"]
var spots: String = "dedad0"
var mouth: String = "e8e2d0"
var clock: float = 0.0
var walking: bool = false
var _segments: Array[Node3D] = []

func _ready() -> void:
	clock = float(get_index())*0.91
	var s := Shapes.new()
	for i: int in 6:
		var segment := Node3D.new()
		segment.position = Vector3(0,0,0.42-i*0.16)
		add_child(segment)
		_segments.append(segment)
		var span: float = 0.34-absf(i-1.5)*0.035
		s.box(segment,Vector3(0,0.13,0),Vector3(span,0.22,0.17),String(colors[i%colors.size()]))
		if i%2==1:
			s.box(segment,Vector3(span*0.22,0.245,0),Vector3(0.06,0.02,0.06),spots)
	# The head: a round sucker ringed with pale teeth (六对白森森的牙齿).
	s.box(_segments[0],Vector3(0,0.13,0.1),Vector3(0.24,0.18,0.06),"5b4c47")
	for tooth: int in 6:
		var a: float = tooth*TAU/6.0
		s.box(_segments[0],Vector3(cos(a)*0.08,0.13+sin(a)*0.06,0.135),Vector3(0.035,0.035,0.03),mouth)
	s.flush()

func _process(delta: float) -> void:
	clock += delta*(2.6 if walking else 1.0)
	for i: int in _segments.size():
		var wave: float = sin(clock*3.0-i*0.9)
		_segments[i].position.x = wave*0.05
		_segments[i].position.y = maxf(0.0,wave)*0.05
		_segments[i].scale = Vector3(1.0-wave*0.06,1.0+wave*0.08,1.0)
