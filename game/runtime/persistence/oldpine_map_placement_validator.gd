class_name OldPineMapPlacementValidator
extends RefCounted

const CHARACTER_FOOTPRINT: Vector2 = Vector2(34.0, 34.0)
const CORPSE_FOOTPRINT: Vector2 = Vector2(76.0, 18.0)


static func is_valid_character_position(
	map: OldPineResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return _is_valid_position(map, zone_id, position, CHARACTER_FOOTPRINT)


static func is_valid_corpse_position(
	map: OldPineResidentMapController,
	zone_id: StringName,
	position: Vector2,
) -> bool:
	return _is_valid_position(map, zone_id, position, CORPSE_FOOTPRINT)


static func _is_valid_position(
	map: OldPineResidentMapController,
	zone_id: StringName,
	position: Vector2,
	footprint_size: Vector2,
) -> bool:
	if map == null or not position.is_finite():
		return false
	var zone_paths: Dictionary[StringName, NodePath] = _zone_paths(map.map_id())
	if not zone_paths.has(zone_id):
		return false
	var containing_zones: Array[StringName] = []
	for candidate_id: StringName in zone_paths:
		var collision: CollisionShape2D = map.get_node_or_null(
			zone_paths[candidate_id]
		) as CollisionShape2D
		if collision != null and _point_inside(collision, position):
			containing_zones.append(candidate_id)
	if containing_zones.size() != 1 or containing_zones[0] != zone_id:
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


static func _point_inside(collision: CollisionShape2D, position: Vector2) -> bool:
	if collision.shape is RectangleShape2D:
		var rectangle: RectangleShape2D = collision.shape
		var local: Vector2 = collision.global_transform.affine_inverse() * position
		return (
			absf(local.x) < rectangle.size.x / 2.0
			and absf(local.y) < rectangle.size.y / 2.0
		)
	if collision.shape is CircleShape2D:
		var circle: CircleShape2D = collision.shape
		var local: Vector2 = collision.global_transform.affine_inverse() * position
		return local.length_squared() < circle.radius * circle.radius
	return false


static func _zone_paths(map_id: StringName) -> Dictionary[StringName, NodePath]:
	if map_id == OldPineWorldDefinitions.OUTDOOR_MAP_ID:
		return {
			OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID: ^"Zones/CentralClearingZone/CollisionShape2D",
			OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID: ^"Zones/SouthSlopeZone/CollisionShape2D",
			OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID: ^"Zones/NorthApproachZone/CollisionShape2D",
			OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID: ^"Zones/EastBridgeZone/CollisionShape2D",
			OldPineWorldDefinitions.TREE_CANOPY_ZONE_ID: ^"Zones/TreeCanopyZone/CollisionShape2D",
			OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID: ^"Zones/PineEntranceZone/CollisionShape2D",
			OldPineWorldDefinitions.PINE_DEEP_ZONE_ID: ^"Zones/PineDeepZone/CollisionShape2D",
			OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID: ^"Zones/PineCliffEdgeZone/CollisionShape2D",
			OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID: ^"Zones/WaterfallBasinZone/CollisionShape2D",
			OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID: ^"Zones/RiverGorgeZone/CollisionShape2D",
			OldPineWorldDefinitions.CLIFF_LEDGE_ZONE_ID: ^"Zones/CliffLedgeZone/CollisionShape2D",
		}
	if map_id == OldPineWorldDefinitions.CAVE_MAP_ID:
		return {
			OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID: ^"Zones/PassageZone/CollisionShape2D",
		}
	return {}
