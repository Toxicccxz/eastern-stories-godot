class_name MapRoute
extends RefCounted

## Test-only: walks a body over a painted map along the cells the runtime's A* grid
## (WorldNpcWalker.Grid) finds, so a suite follows the map's own paths and openings
## instead of fixed waypoints that the next redraw would break.


## Cell centres from `from` to `to` over the whole map, empty when there is no way.
## The bodies in `avoid` (NPCs) count as obstacles.
static func path(map: Node2D, from: Vector2, to: Vector2, avoid: Array[Node2D] = []) -> PackedVector2Array:
	return grid(map, avoid).path(from, to)


## The runtime's A* grid over the whole map, the bodies in `avoid` solid.
static func grid(map: Node2D, avoid: Array[Node2D] = []) -> WorldNpcWalker.Grid:
	var result: WorldNpcWalker.Grid = WorldNpcWalker.Grid.new(map, painted_rect(map))
	for body: Node2D in avoid:
		var centre: Vector2i = result.cell_of(body.global_position)
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				var cell: Vector2i = centre + Vector2i(dx, dy)
				if result._astar.is_in_boundsv(cell):
					result._astar.set_point_solid(cell, true)
	return result


## The map's painted tiles, in map coordinates.
static func painted_rect(map: Node2D) -> Rect2:
	var result: Rect2 = Rect2()
	var first: bool = true
	for layer: TileMapLayer in map.find_children("*", "TileMapLayer", true, false):
		var used: Rect2i = layer.get_used_rect()
		var cell: Vector2 = Vector2(layer.tile_set.tile_size)
		var rect: Rect2 = Rect2(layer.to_global(Vector2(used.position) * cell), Vector2(used.size) * cell)
		result = rect if first else result.merge(rect)
		first = false
	return result


## Walks the body to `target` along the map's path; false with no path or at the first
## collision on the way.
static func walk(body: CharacterBody2D, map: Node2D, target: Vector2, avoid: Array[Node2D] = []) -> bool:
	var points: PackedVector2Array = path(map, body.global_position, target, avoid)
	if points.is_empty():
		return false
	points.append(target)
	for point: Vector2 in points:
		if not await straight(body, point):
			return false
		# A step a frame along the cells, so zone Areas see the body cross them.
		await (Engine.get_main_loop() as SceneTree).physics_frame
	return true


## Walks the body in a straight line to `target`; false at the first collision.
static func straight(body: CharacterBody2D, target: Vector2) -> bool:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	for step: int in range(1000):
		var remaining: Vector2 = target - body.global_position
		if remaining.length() <= 0.5:
			return true
		if body.move_and_collide(remaining.limit_length(5.0)) != null:
			return false
		if step % 10 == 9:
			await (Engine.get_main_loop() as SceneTree).physics_frame
	return false


## Walks the player to `target` with the move actions, as a player would, along the
## map's path; false with no path or when it does not get there.
static func drive(tree: SceneTree, map: Node2D, body: CharacterBody2D, target: Vector2, avoid: Array[Node2D] = []) -> bool:
	var points: PackedVector2Array = path(map, body.global_position, target, avoid)
	if points.is_empty():
		return false
	points.append(target)
	var index: int = 0
	for _frame: int in range(points.size() * 30 + 240):
		while index < points.size() and body.global_position.distance_to(points[index]) <= 8.0:
			index += 1
		if index >= points.size():
			break
		var delta: Vector2 = points[index] - body.global_position
		_press(&"move_right", delta.x > 4.0)
		_press(&"move_left", delta.x < -4.0)
		_press(&"move_down", delta.y > 4.0)
		_press(&"move_up", delta.y < -4.0)
		await tree.physics_frame
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	await tree.physics_frame
	return index >= points.size()


static func _press(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
