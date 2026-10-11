class_name WorldMapStaticNodes
extends RefCounted

## The nodes of a map scene that stay as they are once it is built: its tile layers,
## the collision shapes of its static bodies (walls, door wings), its doors and its
## passages. Nothing added at runtime (NPC bodies, corpses, floor items, services) is one
## of these, so they are found once instead of by walking the whole map tree on every
## placement check or NPC walk. Whether a door or passage is open is read from the node.
var layers: Array[TileMapLayer] = []
var static_shapes: Array[CollisionShape2D] = []
var doors: Array[WorldDoor] = []
var passages: Array[WorldPassageArea2D] = []
## Painted tiles never change at runtime: walkability by point, worked out once.
var _walkable: Dictionary[Vector2i, bool] = {}


func _init(map: Node) -> void:
	for node: Node in map.find_children("*", "", true, false):
		if node is TileMapLayer:
			layers.append(node as TileMapLayer)
		elif node is CollisionShape2D and node.get_parent() is StaticBody2D:
			static_shapes.append(node as CollisionShape2D)
		elif node is WorldDoor:
			doors.append(node as WorldDoor)
		elif node is WorldPassageArea2D:
			passages.append(node as WorldPassageArea2D)


## WorldNpcWalker.Grid's test of one cell centre, remembered (half-pixel key).
func walkable_tile(point: Vector2) -> bool:
	var key := Vector2i(roundi(point.x * 2.0), roundi(point.y * 2.0))
	if not _walkable.has(key):
		_walkable[key] = WorldNpcWalker.Grid._walkable_tile(layers, point)
	return _walkable[key]
