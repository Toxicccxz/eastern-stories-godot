extends Node3D

## Small visual motions only. Uses its own clock; never the game clock or RNG.
const Shapes = preload("res://presentation/voxel/props/voxel_shapes.gd")
var pieces: Array[Dictionary] = []
var clock: float = 0.0

func build(config: Array) -> void:
	var shapes := Shapes.new()
	for effect: Dictionary in config:
		var a: Array = effect["at"]
		var home := Vector3(float(a[0])/32, float(effect.get("height",0)),float(a[1])/32)
		var kind: String = effect["kind"]
		var count: int = int(effect.get("count",6))
		for i: int in count:
			var node := Node3D.new()
			add_child(node)
			var tint: String = String(effect.get("color","b5a078"))
			if kind=="bird":
				for x: float in [-0.15,0.15]:
					shapes.box(node,Vector3(x,0,0),Vector3(0.30,0.045,0.09),tint)
			elif kind=="flag":
				for j: int in 6:
					shapes.box(node,Vector3(j*0.14,0,0),Vector3(0.15,0.55-j*0.05,0.025),tint)
			else:
				var size := Vector3(0.11,0.11,0.11)
				if kind=="drip":
					size = Vector3(0.035,0.15,0.035)
				elif kind=="flame":
					size = Vector3(0.12,0.35,0.12)
				shapes.box(node,Vector3.ZERO,size,tint)
			pieces.append({"node":node,"home":home,"kind":kind,"phase":i*1.37,"radius":float(effect.get("radius",2.0))})
	shapes.flush()
	advance(0)

func advance(delta: float) -> void:
	clock += delta
	for piece: Dictionary in pieces:
		var node: Node3D = piece["node"]
		var t: float = clock+float(piece["phase"])
		var home: Vector3 = piece["home"]
		var radius: float = piece["radius"]
		match String(piece["kind"]):
			"drip":
				var fall: float = fposmod(t*0.75,1.0)
				node.position = home+Vector3(sin(float(piece["phase"]))*radius,-fall*home.y,cos(float(piece["phase"]))*radius)
				node.scale = Vector3.ONE*(0.4+0.6*sin(fall*PI))
			"smoke":
				var rise: float = fposmod(t*0.34,1.0)
				node.position = home+Vector3(rise*0.65+sin(t*1.5)*0.13,rise*2.2,cos(t)*0.15)
				node.scale = Vector3.ONE*(0.7+rise*1.3)*sin(rise*PI)
			"flame":
				node.position = home+Vector3(sin(t*3.0)*0.23,0.18+sin(t*7.0)*0.09,cos(t*4.0)*0.20)
				node.scale.y = 0.8+sin(t*11)*0.3
			"bird":
				node.position = home+Vector3(sin(t*0.19)*radius,sin(t*0.8)*0.25,cos(t*0.19)*radius*0.5)
				node.rotation = Vector3(0,-t*0.19,sin(t*4)*0.20)
			"flag":
				node.position = home
				node.rotation = Vector3(sin(t*4)*0.15,0,sin(t*3.1)*0.09)
			_:
				var drift: float = fposmod(t*0.23,1.0)
				node.position = home+Vector3((drift-0.5)*radius,0.15+sin(t)*0.12,sin(t*0.7)*radius*0.25)
				node.scale = Vector3.ONE*sin(drift*PI)
