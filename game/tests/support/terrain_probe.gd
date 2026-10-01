class_name TerrainProbe
extends RefCounted

## Reads the placeholder terrain painted on a map's TileMapLayers by the TileSet's
## `terrain` custom data, so tests do not depend on atlas coordinates.
const TILESET_PATH := "res://scenes/world/common/placeholder_terrain_tileset.tres"


static func layers(map: Node) -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	for node: Node in map.find_children("*", "TileMapLayer", true, false):
		result.append(node as TileMapLayer)
	return result


## Top-most terrain at a point in map coordinates (the last layer in tree order wins), "" if bare.
## Works on a scene that is not in the tree.
static func terrain_at(map: Node2D, point: Vector2) -> String:
	var found: String = ""
	for layer: TileMapLayer in layers(map):
		var data: TileData = layer.get_cell_tile_data(_cell(map, layer, point))
		if data != null:
			found = str(data.get_custom_data("terrain"))
	return found


## Whether a colliding terrain tile covers the point (layers with collision enabled only).
static func blocks_at(map: Node2D, point: Vector2) -> bool:
	for layer: TileMapLayer in layers(map):
		var data: TileData = layer.get_cell_tile_data(_cell(map, layer, point))
		if layer.collision_enabled and data != null and data.get_collision_polygons_count(0) > 0:
			return true
	return false


static func _cell(map: Node2D, layer: TileMapLayer, point: Vector2) -> Vector2i:
	var to_map := Transform2D.IDENTITY
	var node: Node = layer
	while node != map:
		to_map = (node as Node2D).transform * to_map if node is Node2D else to_map
		node = node.get_parent()
	return layer.local_to_map(to_map.affine_inverse() * point)
