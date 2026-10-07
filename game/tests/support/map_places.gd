class_name MapPlaces
extends RefCounted

## Test-only: places on a painted map read from the map itself (zone rectangles, markers,
## service points, doors, passages), and walks to them with the move actions along the
## runtime's A* grid (MapRoute), so a suite names where it goes by id and survives the next
## redraw of the map.


## The centre of a zone's rectangle.
static func zone_centre(map: WorldMapController, zone_id: StringName) -> Vector2:
	return (map.physical_zone(zone_id).get_node("CollisionShape2D") as Node2D).global_position


## A zone's rectangle on the map.
static func zone_rect(map: WorldMapController, zone_id: StringName) -> Rect2:
	var shape: CollisionShape2D = map.physical_zone(zone_id).get_node("CollisionShape2D") as CollisionShape2D
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	return Rect2(shape.global_position - size / 2.0, size)


## The middle of the way through the edge two neighbouring zones share: where the tiles a
## tile deep on either side let a body through (a shop's doorway, the seam of two streets).
## Vector2.INF when the edge is closed.
static func doorway(map: WorldMapController, zone_a: StringName, zone_b: StringName) -> Vector2:
	var a: Rect2 = zone_rect(map, zone_a)
	var b: Rect2 = zone_rect(map, zone_b)
	var vertical: bool = is_equal_approx(a.end.x, b.position.x) or is_equal_approx(b.end.x, a.position.x)
	var edge: float = (a.end.x if is_equal_approx(a.end.x, b.position.x) else a.position.x) if vertical else (a.end.y if is_equal_approx(a.end.y, b.position.y) else a.position.y)
	var lo: float = maxf(a.position.y, b.position.y) if vertical else maxf(a.position.x, b.position.x)
	var hi: float = minf(a.end.y, b.end.y) if vertical else minf(a.end.x, b.end.x)
	var open: Array[float] = []
	var along: float = lo + 8.0
	while along < hi:
		var here: Vector2 = Vector2(edge, along) if vertical else Vector2(along, edge)
		var across: Vector2 = Vector2(16, 0) if vertical else Vector2(0, 16)
		if not TerrainProbe.blocks_at(map, here - across) and not TerrainProbe.blocks_at(map, here + across):
			open.append(along)
		along += 16.0
	if open.is_empty():
		return Vector2.INF
	var middle: float = (open[0] + open[-1]) / 2.0
	return Vector2(edge, middle) if vertical else Vector2(middle, edge)


## Where the player can stand in the zone, as near `near` as there is room: a valid save
## position on a cell a path can end on, clear of the NPC bodies. Vector2.INF when there is
## none within `radius`.
static func spot(map: WorldMapController, zone_id: StringName, near: Vector2, radius: float = 192.0) -> Vector2:
	var grid: WorldNpcWalker.Grid = MapRoute.grid(map, npc_bodies(map))
	var zone: WorldPhysicalZoneArea2D = map.physical_zone(zone_id)
	var candidates: Array[Vector2] = []
	var first: Vector2i = grid.cell_of(near - Vector2(radius, radius))
	var last: Vector2i = grid.cell_of(near + Vector2(radius, radius))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not grid._astar.is_in_boundsv(cell) or grid._astar.is_point_solid(cell):
				continue
			var point: Vector2 = grid.center_of(cell)
			if point.distance_to(near) <= radius and zone.contains_center(point):
				candidates.append(point)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(near) < b.distance_squared_to(near))
	for point: Vector2 in candidates:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, point):
			return point
	return Vector2.INF


## A free spot in the middle of a zone.
static func zone_spot(map: WorldMapController, zone_id: StringName) -> Vector2:
	return spot(map, zone_id, zone_centre(map, zone_id))


## Where to stand to use a service: as near its point (or the NPC offering it) as there is room,
## on the side towards the middle of the room (in front of a counter, not behind it).
static func service_spot(map: WorldMapController, service_id: StringName, zone_id: StringName = &"") -> Vector2:
	var service: WorldService = map.service(service_id)
	var zone: StringName = service.definition.zone_id if zone_id.is_empty() else zone_id
	return spot(map, zone, service.anchor().move_toward(zone_centre(map, zone), 48.0))


## The first point from `from` towards `to` where a tile blocks (a counter, a wall).
static func first_blocked(map: WorldMapController, from: Vector2, to: Vector2) -> Vector2:
	var steps: int = ceili(from.distance_to(to) / 4.0)
	for step: int in range(steps + 1):
		var point: Vector2 = from.lerp(to, float(step) / maxf(steps, 1))
		if TerrainProbe.blocks_at(map, point):
			return point
	return Vector2.INF


## In front of a door on the side of `zone_id`, clear of where it shuts.
static func door_spot(map: WorldMapController, door_id: StringName, zone_id: StringName) -> Vector2:
	var wall: CollisionShape2D = door_wall(map, door_id)
	var size: Vector2 = (wall.shape as RectangleShape2D).size
	var across: Vector2 = Vector2.RIGHT if size.x < size.y else Vector2.DOWN
	var side: float = signf((zone_centre(map, zone_id) - wall.global_position).dot(across))
	return spot(map, zone_id, wall.global_position + across * side * (minf(size.x, size.y) / 2.0 + 41.0))


## The door's wall shape (it blocks while the door is shut).
static func door_wall(map: WorldMapController, door_id: StringName) -> CollisionShape2D:
	for door: WorldDoor in map.doors():
		if door.door_id == door_id:
			return door.wall_shape()
	return null


## As near a passage's middle as a body can stand, in the zone it leaves from.
static func passage_spot(map: WorldMapController, portal_id: StringName) -> Vector2:
	var area: WorldPassageArea2D = passage(map, portal_id)
	return spot(map, GameContent.catalog().portal(portal_id).source_zone_id, area.global_position)


static func passage(map: WorldMapController, portal_id: StringName) -> WorldPassageArea2D:
	for node: Node in map.find_children("*", "Area2D", true, false):
		if node is WorldPassageArea2D and (node as WorldPassageArea2D).portal_id == portal_id:
			return node as WorldPassageArea2D
	return null


static func npc_bodies(map: WorldMapController) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var player: Node2D = map.runtime_player_body()
	for node: Node in map.find_children("*", "CharacterBody2D", true, false):
		if node != player:
			result.append(node as Node2D)
	return result


## Walks the player to `target` with the move actions along the map's path, round the NPCs.
static func drive(tree: SceneTree, map: WorldMapController, target: Vector2) -> bool:
	if not target.is_finite():
		return false
	# A door opened or shut this frame changes its wall only at the frame's end.
	await tree.physics_frame
	var body: WorldCharacterBody2D = map.runtime_player_body()
	var arrived: bool = await MapRoute.drive(tree, map, body, target, npc_bodies(map))
	# The last steps onto the spot itself (the route stops within a few pixels).
	for _frame: int in range(20):
		var delta: Vector2 = target - body.global_position
		if absf(delta.x) <= 3.0 and absf(delta.y) <= 3.0:
			break
		_press(&"move_right", delta.x > 3.0)
		_press(&"move_left", delta.x < -3.0)
		_press(&"move_down", delta.y > 3.0)
		_press(&"move_up", delta.y < -3.0)
		await tree.physics_frame
	release()
	# The zone Areas report the last crossing a frame later.
	await tree.physics_frame
	await tree.physics_frame
	return arrived


static func drive_to_zone(tree: SceneTree, map: WorldMapController, zone_id: StringName) -> bool:
	return await drive(tree, map, zone_spot(map, zone_id))


## Through each zone's middle in turn, so the walk takes exactly that order of rooms.
static func drive_through(tree: SceneTree, map: WorldMapController, zone_ids: Array[StringName]) -> bool:
	for zone_id: StringName in zone_ids:
		if not await drive_to_zone(tree, map, zone_id):
			return false
	return true


## Walks onto a passage with the move actions until it takes the player off this map (the map
## leaves the tree); false when that does not happen within `frames`.
static func take_passage(tree: SceneTree, map: WorldMapController, portal_id: StringName, frames: int = 600) -> bool:
	var area: WorldPassageArea2D = passage(map, portal_id)
	var body: CharacterBody2D = map.runtime_player_body()
	if area == null:
		return false
	var points: PackedVector2Array = MapRoute.path(map, body.global_position, area.global_position, npc_bodies(map))
	points.append(area.global_position)
	var index: int = 0
	var left: bool = false
	for _frame: int in range(frames):
		if not map.is_inside_tree():
			left = true
			break
		while index < points.size() - 1 and body.global_position.distance_to(points[index]) <= 8.0:
			index += 1
		var delta: Vector2 = points[index] - body.global_position
		_press(&"move_right", delta.x > 4.0)
		_press(&"move_left", delta.x < -4.0)
		_press(&"move_down", delta.y > 4.0)
		_press(&"move_up", delta.y < -4.0)
		await tree.physics_frame
	release()
	await tree.physics_frame
	return left


## Holds one move action for `frames` physics frames (a push against a wall or a shut door).
static func push(tree: SceneTree, action: StringName, frames: int) -> void:
	Input.action_press(action)
	for _frame: int in range(frames):
		await tree.physics_frame
	Input.action_release(action)
	await tree.physics_frame
	await tree.physics_frame


static func release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


static func _press(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
