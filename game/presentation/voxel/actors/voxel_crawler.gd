extends Node3D

## Segmented, low crawling beasts. Presentation motion never moves their 2D body.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var color: String = "a7ada2"
var segments: Array[Node3D] = []
var clock: float = 0.0

func _ready() -> void:
	var shapes := Shapes.new()
	for i: int in 7:
		var segment := Node3D.new()
		add_child(segment)
		segments.append(segment)
		var width: float = 0.22+sin((i+0.5)*PI/7)*0.27
		shapes.box(segment,Vector3(0,0.20,0),Vector3(width,0.27,0.22),color)
		shapes.box(segment,Vector3(width*0.23,0.34,0),Vector3(0.09,0.025,0.08),"e0e0c9")
		if i==6:
			shapes.box(segment,Vector3(0,0.22,0.12),Vector3(0.25,0.16,0.03),"554d3c")
			for tooth: int in 6:
				shapes.box(segment,Vector3((tooth-2.5)*0.04,0.26,0.145),Vector3(0.025,0.07,0.04),"e4dfc2")
	shapes.flush()
	advance(0)

func advance(delta: float) -> void:
	clock += delta
	for i: int in segments.size():
		segments[i].position = Vector3(sin(clock*2.1+i*0.72)*0.07,0,(i-3)*0.18)
		segments[i].scale.y = 0.95+sin(clock*2.1+i*0.8)*0.12
