class_name MapPlacementValidator
extends RefCounted

const CHARACTER_FOOTPRINT: Vector2 = Vector2(34.0, 34.0)
## A character's body is the circle its 34 px square holds (DECISIONS「手感」): where the
## body can stand, its footprint fits. Tiles are tested against a polygon on that circle.
const CHARACTER_ROUND_SIDES: int = 16
const CORPSE_FOOTPRINT: Vector2 = Vector2(76.0, 18.0)
## nearest_*(): how far from where a thing is it looks for a spot this check accepts, ring by
## ring this many pixels apart, in these directions (the four ways first, as a corpse beside a
## wall is shifted sideways; then the diagonals; then between them).
const NEAREST_STEP_PX: int = 8
const NEAREST_REACH_PX: int = 160
## A corpse is shifted this far at most to fit its own footprint; past it, it lies where a body
## could stand (a way too narrow for it).
const CORPSE_SHIFT_PX: int = 48
const NEAREST_DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.70710678, 0.70710678), Vector2(-0.70710678, 0.70710678), Vector2(0.70710678, -0.70710678), Vector2(-0.70710678, -0.70710678),
	Vector2(0.92387953, 0.38268343), Vector2(-0.92387953, 0.38268343), Vector2(0.92387953, -0.38268343), Vector2(-0.92387953, -0.38268343),
	Vector2(0.38268343, 0.92387953), Vector2(-0.38268343, 0.92387953), Vector2(0.38268343, -0.92387953), Vector2(-0.38268343, -0.92387953),
]


static func is_valid_character_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return _is_valid_position(map, zone_id, position, CHARACTER_FOOTPRINT, true)


## A corpse lies where its own footprint fits, or, where none does near it (a way too narrow
## for it: corpse_position()), where a body could stand. The one check a save is taken by and
## Continue is checked by.
static func is_valid_corpse_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return corpse_fits(map, zone_id, position) or is_valid_character_position(map, zone_id, position)


## Whether a corpse's own footprint fits there.
static func corpse_fits(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return _is_valid_position(map, zone_id, position, CORPSE_FOOTPRINT)


## `position` when a character may stand there in `zone_id`, else the nearest spot in that zone
## where one may (within NEAREST_REACH_PX), else Vector2.INF.
static func nearest_character_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> Vector2:
	return _nearest(map, zone_id, position, CHARACTER_FOOTPRINT, true, NEAREST_REACH_PX)


## Where a corpse falling at `position` lies: there or the nearest spot within CORPSE_SHIFT_PX
## where its own footprint fits, else the nearest where a body could stand (within
## NEAREST_REACH_PX), else Vector2.INF.
static func nearest_corpse_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> Vector2:
	var spot: Vector2 = _nearest(map, zone_id, position, CORPSE_FOOTPRINT, false, CORPSE_SHIFT_PX)
	return spot if spot.is_finite() else nearest_character_position(map, zone_id, position)


static func _nearest(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
	footprint_size: Vector2,
	round: bool,
	reach: int,
) -> Vector2:
	if not position.is_finite():
		return Vector2.INF
	if _is_valid_position(map, zone_id, position, footprint_size, round):
		return position
	for distance: int in range(NEAREST_STEP_PX, reach + 1, NEAREST_STEP_PX):
		for direction: Vector2 in NEAREST_DIRECTIONS:
			var spot: Vector2 = position + direction * distance
			if _is_valid_position(map, zone_id, spot, footprint_size, round):
				return spot
	return Vector2.INF


static func _is_valid_position(
	map: WorldResidentMapController,
	zone_id: StringName,
	position: Vector2,
	footprint_size: Vector2,
	round: bool = false,
) -> bool:
	var world_map: WorldMapController = map as WorldMapController
	if world_map == null or not position.is_finite() or world_map.physical_zone(zone_id) == null:
		return false
	# Doors close again on cold Continue (their state is not saved). Keep the
	# closed footprint save-invalid even while open; never relocate a restored
	# Player to compensate.
	var parts: WorldMapStaticNodes = world_map.static_nodes()
	for world_door: WorldDoor in parts.doors:
		var door: CollisionShape2D = world_door.wall_shape()
		if door != null:
			if door.shape.collide(door.global_transform, _footprint_shape(footprint_size, round), Transform2D(0.0, position)):
				return false
	# Same half-open center ownership as runtime zone tracking.
	for zone: WorldPhysicalZoneArea2D in world_map.physical_zones():
		if zone.contains_center(position) != (zone.zone_id == zone_id):
			return false

	var footprint: Shape2D = _footprint_shape(footprint_size, round)
	var footprint_transform: Transform2D = Transform2D(0.0, position)
	for collision: CollisionShape2D in parts.static_shapes:
		if collision.disabled or collision.shape == null:
			continue
		if collision.shape.collide(
			collision.global_transform,
			footprint,
			footprint_transform,
		):
			return false
	for layer: TileMapLayer in parts.layers:
		if _overlaps_tile_collision(layer, Rect2(position - footprint_size / 2.0, footprint_size), round):
			return false
	return true


static func _footprint_shape(size: Vector2, round: bool) -> Shape2D:
	if round:
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = minf(size.x, size.y) / 2.0
		return circle
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	return rectangle


## Terrain painted with a colliding tile blocks like a wall. Touching an edge is not overlap.
static func _overlaps_tile_collision(layer: TileMapLayer, footprint: Rect2, round: bool = false) -> bool:
	if not layer.collision_enabled or layer.tile_set == null or layer.tile_set.get_physics_layers_count() == 0:
		return false
	var local: Rect2 = layer.global_transform.affine_inverse() * footprint
	var first: Vector2i = layer.local_to_map(local.position)
	var last: Vector2i = layer.local_to_map(local.end)
	var footprint_polygon: PackedVector2Array = [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]
	if round:
		# Corners on the circle: touching a wall is not overlap, as with the square.
		footprint_polygon = PackedVector2Array()
		var radius: float = minf(local.size.x, local.size.y) / 2.0
		for side: int in CHARACTER_ROUND_SIDES:
			footprint_polygon.append(local.get_center() + Vector2.from_angle(TAU * side / CHARACTER_ROUND_SIDES) * radius)
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
