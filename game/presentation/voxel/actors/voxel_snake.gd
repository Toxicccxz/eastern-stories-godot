extends Node3D

## A snake: a long body laid in an S on the ground that ripples as it goes, its head held
## low or reared up to strike (`rear`: 昂首吐信), a forked tongue flicking. Faces +z like
## the other figures; banded colours, belly and an optional crest (the serpent's 肉瘤)
## from the look.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var colors: Array = ["2b2a26","3a3833","23221f"]
var belly: String = "8a7f62"
var bands: String = ""
var crest: String = ""
var rear: bool = false
var segments_count: int = 10
var clock: float = 0.0
var walking: bool = false
var _segments: Array[Node3D] = []
var _tongue: Node3D

func _ready() -> void:
	clock = float(get_index())*1.37
	var s := Shapes.new()
	for i: int in segments_count:
		var segment := Node3D.new()
		add_child(segment)
		_segments.append(segment)
		var t: float = float(i)/(segments_count-1)
		var thick: float = lerpf(0.2,0.08,t*t) if i>0 else 0.18
		s.box(segment,Vector3(0,thick*0.5,0),Vector3(thick*1.25,thick,0.2),String(colors[i%colors.size()]))
		s.box(segment,Vector3(0,0.012,0),Vector3(thick*1.1,0.024,0.18),belly)
		if not bands.is_empty() and i%2==1:
			s.box(segment,Vector3(0,thick*0.5,0),Vector3(thick*1.3,thick*1.04,0.07),bands)
	var head: Node3D = _segments[0]
	s.box(head,Vector3(0,0.12,0.13),Vector3(0.22,0.14,0.2),String(colors[0]))
	for side: float in [-1.0,1.0]:
		s.box(head,Vector3(side*0.08,0.17,0.17),Vector3(0.04,0.04,0.04),"d8c24a")
	if not crest.is_empty():
		s.box(head,Vector3(0,0.24,0.08),Vector3(0.16,0.12,0.18),crest)
	_tongue = Node3D.new()
	_tongue.position = Vector3(0,0.1,0.24)
	head.add_child(_tongue)
	for side: float in [-1.0,1.0]:
		s.tilted_box(_tongue,Vector3(side*0.015,0,0.06),Vector3(0.015,0.012,0.12),"c43a32",Vector3(0,side*0.25,0))
	s.flush()

func _process(delta: float) -> void:
	clock += delta*(3.0 if walking else 1.0)
	for i: int in _segments.size():
		var z: float = 0.2-i*0.17
		var wave: float = sin(clock*2.2-i*0.75)*(0.09+i*0.012)
		var lift: float = 0.0
		if rear and i<3:
			# The fore-body raised in a curve, the head level and watching.
			lift = (3-i)*0.17
			wave *= 0.3
		_segments[i].position = Vector3(wave,lift,z+(0.1 if rear and i<3 else 0.0))
		_segments[i].rotation.y = cos(clock*2.2-i*0.75)*0.35
	_tongue.visible = fposmod(clock*0.7,1.0) < 0.3
