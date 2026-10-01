class_name MapPlacementValidator
extends RefCounted

const CHARACTER_FOOTPRINT: Vector2 = Vector2(34.0, 34.0)
const CORPSE_FOOTPRINT: Vector2 = Vector2(76.0, 18.0)


static func is_valid_character_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return _is_valid_position(map, zone_id, position, CHARACTER_FOOTPRINT)


static func is_valid_corpse_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return _is_valid_position(map, zone_id, position, CORPSE_FOOTPRINT)


static func _is_valid_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
	footprint_size: Vector2,
) -> bool:
	var world_map: WorldMapController = map as WorldMapController
	if world_map == null or not position.is_finite() or world_map.physical_zone(zone_id) == null:
		return false
	# Doors close again on cold Continue (their state is not saved). Keep the
	# closed footprint save-invalid even while open; never relocate a restored
	# Player to compensate.
	for world_door: WorldDoor in world_map.doors():
		var door: CollisionShape2D = world_door.wall_shape()
		if door != null:
			var saved_footprint: RectangleShape2D = RectangleShape2D.new()
			saved_footprint.size = footprint_size
			if door.shape.collide(door.global_transform, saved_footprint, Transform2D(0.0, position)):
				return false
	# Same half-open center ownership as runtime zone tracking.
	for zone: WorldPhysicalZoneArea2D in world_map.physical_zones():
		if zone.contains_center(position) != (zone.zone_id == zone_id):
			return false

	var footprint: RectangleShape2D = RectangleShape2D.new()
	footprint.size = footprint_size
	var footprint_transform: Transform2D = Transform2D(0.0, position)
	for node: Node in map.find_children("*", "CollisionShape2D", true, false):
		var collision: CollisionShape2D = node as CollisionShape2D
		if (
			collision == null
			or collision.disabled
			or collision.shape == null
			or not (collision.get_parent() is StaticBody2D)
		):
			continue
		if collision.shape.collide(
			collision.global_transform,
			footprint,
			footprint_transform,
		):
			return false
	for node: Node in map.find_children("*", "TileMapLayer", true, false):
		if _overlaps_tile_collision(node as TileMapLayer, Rect2(position - footprint_size / 2.0, footprint_size)):
			return false
	return true


## Terrain painted with a colliding tile blocks like a wall. Touching an edge is not overlap.
static func _overlaps_tile_collision(layer: TileMapLayer, footprint: Rect2) -> bool:
	if not layer.collision_enabled or layer.tile_set == null or layer.tile_set.get_physics_layers_count() == 0:
		return false
	var local: Rect2 = layer.global_transform.affine_inverse() * footprint
	var first: Vector2i = layer.local_to_map(local.position)
	var last: Vector2i = layer.local_to_map(local.end)
	var footprint_polygon: PackedVector2Array = [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			var data: TileData = layer.get_cell_tile_data(cell)
			if data == null:
				continue
			var center: Vector2 = layer.map_to_local(cell)
			for index: int in data.get_collision_polygons_count(0):
				var polygon: PackedVector2Array = data.get_collision_polygon_points(0, index)
				for point: int in polygon.size():
					polygon[point] += center
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(polygon, footprint_polygon):
					if absf(_area(overlap)) > 0.01:
						return true
	return false


static func _area(polygon: PackedVector2Array) -> float:
	var twice: float = 0.0
	for index: int in polygon.size():
		twice += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return twice / 2.0
