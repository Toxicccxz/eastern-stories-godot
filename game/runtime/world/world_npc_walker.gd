class_name WorldNpcWalker
extends RefCounted

## How an NPC body crosses from one zone into the next on its map, for a move
## the rules already made (NpcRandomMove, room reset's return_home): a path over
## the walkable tiles around the two zones (AStarGrid2D, one body's width from
## walls and enabled static shapes, so closed doors block), walked at SPEED on
## world time. ES2 moves are instant; the NPC's zone changes when the walk
## starts and a save takes the walk's end as its position.

const CELL: float = 16.0
const SPEED: float = 90.0
## Destination cells tried before a move is given up.
const DESTINATION_TRIES: int = 8
## A walk does not end this close to another character.
const KEEP_CLEAR: float = 48.0

var _map: WorldMapController
var _walks: Dictionary[StringName, PackedVector2Array] = {}


func _init(map: WorldMapController) -> void:
	_map = map


func is_walking(character_id: StringName) -> bool:
	return _walks.has(character_id)


## Where the walk ends (its last point), or the body's position when not walking.
func rest_position(character_id: StringName, body: Node2D) -> Vector2:
	var path: PackedVector2Array = _walks.get(character_id, PackedVector2Array())
	return body.global_position if path.is_empty() else path[path.size() - 1]


## A body-sized free spot in `to_zone` reachable from `body`, with its path; false
## when there is none. `random` draws the spot (legacy_random over candidates).
func walk_into(character_id: StringName, body: Node2D, from_zone: WorldPhysicalZoneArea2D, to_zone: WorldPhysicalZoneArea2D, random: WorldInteractionRandomSource) -> bool:
	if body == null or from_zone == null or to_zone == null or random == null:
		return false
	var grid: Grid = Grid.new(_map, from_zone.global_rect().merge(to_zone.global_rect()))
	var candidates: Array[Vector2i] = []
	var others: Array[Vector2] = _occupied(character_id)
	for cell: Vector2i in grid.free_cells_in(to_zone.global_rect()):
		if others.all(func(other: Vector2) -> bool: return other.distance_to(grid.center_of(cell)) >= KEEP_CLEAR):
			candidates.append(cell)
	for attempt: int in range(mini(DESTINATION_TRIES, candidates.size())):
		var index: int = random.legacy_random(candidates.size())
		if index < 0 or index >= candidates.size():
			return false
		var spot: Vector2 = grid.center_of(candidates[index])
		candidates.remove_at(index)
		if MapPlacementValidator.is_valid_character_position(_map, to_zone.zone_id, spot) and _start(grid, character_id, body, spot):
			return true
	return false


## A walk to a known spot (an NPC's spawn marker); false when no path reaches it.
func walk_to(character_id: StringName, body: Node2D, from_zone: WorldPhysicalZoneArea2D, to_zone: WorldPhysicalZoneArea2D, spot: Vector2) -> bool:
	if body == null or from_zone == null or to_zone == null:
		return false
	return _start(Grid.new(_map, from_zone.global_rect().merge(to_zone.global_rect())), character_id, body, spot)


## Where the player and the other NPCs stand or are going.
func _occupied(character_id: StringName) -> Array[Vector2]:
	var result: Array[Vector2] = [_map.runtime_player_body().global_position]
	for npc: NpcRuntimeState in _map.npc_runtimes():
		var body: Node2D = _map.runtime_body_for_character(npc.character_id)
		if npc.character_id != character_id and npc.exists_in_map and body != null:
			result.append(rest_position(npc.character_id, body))
	return result


func _start(grid: Grid, character_id: StringName, body: Node2D, spot: Vector2) -> bool:
	var path: PackedVector2Array = grid.path(body.global_position, spot)
	if path.is_empty():
		return false
	path.append(spot)
	_walks[character_id] = path
	_set_walking(body, true)
	return true


static func _set_walking(body: Node2D, value: bool) -> void:
	if body is WorldNpcBody2D:
		(body as WorldNpcBody2D).set_walking(value)


## Moves every walking body along its path by `delta` seconds of world time.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for character_id: StringName in _walks.keys():
		var body: Node2D = _map.runtime_body_for_character(character_id)
		if body == null:
			_walks.erase(character_id)
			continue
		var path: PackedVector2Array = _walks[character_id]
		var budget: float = SPEED * delta
		while not path.is_empty() and budget > 0.0:
			var step: float = body.global_position.distance_to(path[0])
			if step <= budget:
				body.global_position = path[0]
				budget -= step
				path.remove_at(0)
			else:
				body.global_position = body.global_position.move_toward(path[0], budget)
				budget = 0.0
		if path.is_empty():
			_walks.erase(character_id)
			_set_walking(body, false)
		else:
			_walks[character_id] = path


## Puts every walking body at its walk's end (the map stops being watched).
func finish_all() -> void:
	for character_id: StringName in _walks.keys():
		var body: Node2D = _map.runtime_body_for_character(character_id)
		if body != null:
			body.global_position = rest_position(character_id, body)
			_set_walking(body, false)
	_walks.clear()


func cancel(character_id: StringName) -> void:
	if _walks.has(character_id):
		_walks.erase(character_id)
		_set_walking(_map.runtime_body_for_character(character_id), false)


## Walkable cells of one rectangle of the map: painted, no colliding tile and no
## enabled static shape within one cell (a body is 34 px, a cell 16).
class Grid:
	extends RefCounted
	var _astar: AStarGrid2D = AStarGrid2D.new()
	var _origin: Vector2
	var _size: Vector2i

	func _init(map: Node, area: Rect2) -> void:
		var layers: Array[TileMapLayer] = []
		for node: Node in map.find_children("*", "TileMapLayer", true, false):
			layers.append(node as TileMapLayer)
		# Cells sit on the tiles' own grid.
		var offset: Vector2 = Vector2.ZERO if layers.is_empty() else (layers[0].to_global(layers[0].map_to_local(Vector2i.ZERO)) - Vector2(CELL, CELL) / 2.0).posmod(CELL)
		var region: Rect2 = area.grow(CELL * 2.0)
		_origin = ((region.position - offset) / CELL).floor() * CELL + offset
		_size = Vector2i(ceili((region.end.x - _origin.x) / CELL), ceili((region.end.y - _origin.y) / CELL))
		var blocked: PackedByteArray = PackedByteArray()
		blocked.resize(_size.x * _size.y)
		for y: int in _size.y:
			for x: int in _size.x:
				blocked[y * _size.x + x] = 0 if _walkable_tile(layers, center_of(Vector2i(x, y))) else 1
		for node: Node in map.find_children("*", "CollisionShape2D", true, false):
			var collision: CollisionShape2D = node as CollisionShape2D
			if collision.disabled or collision.shape == null or not collision.get_parent() is StaticBody2D:
				continue
			var bounds: Rect2 = collision.global_transform * collision.shape.get_rect()
			var first: Vector2i = cell_of(bounds.position)
			var last: Vector2i = cell_of(bounds.end)
			for y: int in range(maxi(first.y, 0), mini(last.y + 1, _size.y)):
				for x: int in range(maxi(first.x, 0), mini(last.x + 1, _size.x)):
					blocked[y * _size.x + x] = 1
		_astar.region = Rect2i(Vector2i.ZERO, _size)
		_astar.cell_size = Vector2(CELL, CELL)
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_astar.update()
		for y: int in _size.y:
			for x: int in _size.x:
				_astar.set_point_solid(Vector2i(x, y), _near_blocked(blocked, x, y))

	func cell_of(point: Vector2) -> Vector2i:
		return Vector2i(((point - _origin) / CELL).floor())

	func center_of(cell: Vector2i) -> Vector2:
		return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL

	func free_cells_in(area: Rect2) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for y: int in _size.y:
			for x: int in _size.x:
				var cell := Vector2i(x, y)
				if not _astar.is_point_solid(cell) and area.has_point(center_of(cell)):
					result.append(cell)
		return result

	## Cell centres from `from` to `to`, or empty. A start inside a body's width of
	## a wall (a marker near one) leaves from the nearest free cell.
	func path(from: Vector2, to: Vector2) -> PackedVector2Array:
		var start: Vector2i = _nearest_free(cell_of(from))
		var end: Vector2i = cell_of(to)
		if start.x < 0 or not _astar.is_in_boundsv(end) or _astar.is_point_solid(end):
			return PackedVector2Array()
		var result: PackedVector2Array = PackedVector2Array()
		for cell: Vector2i in _astar.get_id_path(start, end):
			result.append(center_of(cell))
		return result

	func _nearest_free(cell: Vector2i) -> Vector2i:
		for radius: int in range(0, 4):
			for y: int in range(cell.y - radius, cell.y + radius + 1):
				for x: int in range(cell.x - radius, cell.x + radius + 1):
					var candidate := Vector2i(x, y)
					if _astar.is_in_boundsv(candidate) and not _astar.is_point_solid(candidate):
						return candidate
		return Vector2i(-1, -1)

	func _near_blocked(blocked: PackedByteArray, x: int, y: int) -> bool:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or ny < 0 or nx >= _size.x or ny >= _size.y or blocked[ny * _size.x + nx] == 1:
					return true
		return false

	static func _walkable_tile(layers: Array[TileMapLayer], point: Vector2) -> bool:
		var painted: bool = false
		for layer: TileMapLayer in layers:
			var data: TileData = layer.get_cell_tile_data(layer.local_to_map(layer.to_local(point)))
			if data == null:
				continue
			painted = true
			if layer.tile_set != null and layer.tile_set.get_physics_layers_count() > 0 and data.get_collision_polygons_count(0) > 0:
				return false
		return painted
