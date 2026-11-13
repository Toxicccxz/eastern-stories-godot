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
## Whether a footprint overlaps a layer's colliding tiles (MapPlacementValidator), by layer and
## roundness, then by the footprint's rect; kept to a bound.
var _tile_blocks: Dictionary[int, Dictionary] = {}
const TILE_BLOCKS_KEPT: int = 8192


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


## Whether `footprint` overlaps layer `index`'s colliding tiles: `test` (layer, footprint, round)
## asked once for each, then remembered.
func tiles_block(index: int, footprint: Rect2, round: bool, test: Callable) -> bool:
	var by_rect: Dictionary = _tile_blocks.get(index * 2 + (1 if round else 0), {})
	if by_rect.has(footprint):
		return by_rect[footprint]
	if by_rect.size() >= TILE_BLOCKS_KEPT:
		by_rect.clear()
	var blocks: bool = test.call(layers[index], footprint, round)
	by_rect[footprint] = blocks
	_tile_blocks[index * 2 + (1 if round else 0)] = by_rect
	return blocks
