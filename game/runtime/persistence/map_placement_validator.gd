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
	return true
