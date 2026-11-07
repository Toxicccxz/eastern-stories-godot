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
## Owner (polish, A5): a wanderer does not stop this close to where its zone joins
## another (a doorway, a street's mouth) or to a passage or a door, where a body
## stands in everyone's way; a zone too small for it is walked as before.
const SEAM_CLEAR: float = 48.0
## A step aside (step_aside()) goes this far at most, and at least this far across the
## player's push (a body's width), so the way opens.
const STEP_ASIDE_REACH: float = 112.0
const STEP_ASIDE_ACROSS: float = 36.0
## A stroll keeps to cells with this many free cells on every side (NPC 活起来): off the narrowest
## ways (a doorway's throat, a plank bridge); one that stops for the player in a narrow place
## steps aside when pushed (step_aside()). 2 kept most rooms' people still (owner, 2026-11-07).
const STROLL_OPEN_CELLS: int = 1
## How many cells a stroll may take through tight ground before it is out on open ground (one
## whose spawn marker stands by a wall or a counter). Without it, those never stirred (2026-11-07).
const STROLL_LEAD_CELLS: int = 4

var _map: WorldMapController
var _walks: Dictionary[StringName, PackedVector2Array] = {}
## Walks that are a stroll inside the walker's own room (stroll()), at their own speed: the
## body keeps its collision and presence, as it never leaves the room it stands in.
var _strolls: Dictionary[StringName, float] = {}
## What a stroll may use of each zone, by zone ID: {grid, cells: Array[Vector2i] (open ground off
## the seams), allowed: the same as a set, standable: whether a body may stand on a cell, found as
## a walk first crosses it (MapPlacementValidator is dear: not every cell of a big room at once)}.
## Built once per zone and grid: _grid() makes a new grid when a door opens or shuts.
var _ground: Dictionary[StringName, Dictionary] = {}
## Grids built on this map, by area: the tiles never change, so one serves again while
## the same static walls (door wings) stand.
var _grids: Dictionary[Rect2, Grid] = {}


func _init(map: WorldMapController) -> void:
	_map = map


func is_walking(character_id: StringName) -> bool:
	return _walks.has(character_id)


## Whether the walk is a stroll inside its own room (stroll()), not a move the rules made.
func is_strolling(character_id: StringName) -> bool:
	return _strolls.has(character_id)


## Native (NPC 活起来; DECISIONS「街上的人会动」): a few steps about `zone`, the body's own room,
## at `speed`: to a free spot `least`..`most` from where it stands and within `reach` of
## `home` (its own spot), off the zone's seams and clear of everyone; `draw` (0..1) picks
## among the candidates. Its place does not change. False when there is no such spot.
func stroll(character_id: StringName, body: Node2D, zone: WorldPhysicalZoneArea2D, home: Vector2, reach: float, least: float, most: float, speed: float, draw: Callable) -> bool:
	if body == null or zone == null or is_walking(character_id) or speed <= 0.0:
		return false
	var ground: Dictionary = _stroll_ground(zone)
	var grid: Grid = ground["grid"]
	var near: Array[Vector2i] = []
	for cell: Vector2i in ground["cells"]:
		var spot: Vector2 = grid.center_of(cell)
		var step: float = spot.distance_to(body.global_position)
		if step >= least and step <= most and spot.distance_to(home) <= reach:
			near.append(cell)
	var off: Array[Vector2i] = _clear_of(grid, near, _occupied(character_id))
	for attempt: int in range(mini(DESTINATION_TRIES, off.size())):
		var index: int = clampi(int(float(draw.call()) * off.size()), 0, off.size() - 1)
		var spot: Vector2 = grid.center_of(off[index])
		off.remove_at(index)
		if not _standable(grid, zone, ground, grid.cell_of(spot)):
			continue
		var path: PackedVector2Array = grid.path(body.global_position, spot)
		if path.is_empty() or not _stays(grid, zone, path, ground):
			continue
		path.append(spot)
		cancel(character_id)
		_walks[character_id] = path
		_strolls[character_id] = speed
		return true
	return false


## Whether every point of `path` past its first (the cell the body leaves from) is a spot a body
## may stand in the zone (`ground`'s standable) and on its open ground (`allowed`): a stroll stopped
## anywhere on it (the player came near, a fight began) leaves the body where it may stay.
func _stays(grid: Grid, zone: WorldPhysicalZoneArea2D, path: PackedVector2Array, ground: Dictionary) -> bool:
	var allowed: Dictionary = ground["allowed"]
	# One whose own spot is tight (by a wall, a counter, a flower bed) steps out to open ground
	# first: the first STROLL_LEAD_CELLS cells may be narrow, then the way keeps to `allowed`.
	var out: bool = false
	for index: int in range(1, path.size()):
		var cell: Vector2i = grid.cell_of(path[index])
		if not _standable(grid, zone, ground, cell):
			return false
		if allowed.has(cell):
			out = true
		elif out or index > STROLL_LEAD_CELLS:
			return false
	return true


## Whether a body may stand on `cell` of `zone` (in it, clear of its walls and doors), remembered
## in `ground`.
func _standable(grid: Grid, zone: WorldPhysicalZoneArea2D, ground: Dictionary, cell: Vector2i) -> bool:
	var standable: Dictionary = ground["standable"]
	if not standable.has(cell):
		var spot: Vector2 = grid.center_of(cell)
		standable[cell] = zone.contains_center(spot) and MapPlacementValidator.is_valid_character_position(_map, zone.zone_id, spot)
	return standable[cell]


## Whether `zone`'s stroll ground is ready (its grid and _ground's entry built for the walls now).
func ground_ready(zone: WorldPhysicalZoneArea2D) -> bool:
	var grid: Grid = _grids.get(zone.global_rect())
	var cached: Dictionary = _ground.get(zone.zone_id, {})
	return grid != null and grid.walls == Grid.walls_up(_map.static_nodes()) and not cached.is_empty() and cached["grid"] == grid


## One step of making `zone`'s stroll ground ready: its grid, or else its ground (each a few
## milliseconds on a big street: WorldMapNpcIdle takes one a tick, so no frame pays for many).
func prepare_ground(zone: WorldPhysicalZoneArea2D) -> void:
	var grid: Grid = _grids.get(zone.global_rect())
	if grid == null or grid.walls != Grid.walls_up(_map.static_nodes()):
		_grid(zone.global_rect())
	else:
		_stroll_ground(zone)


## What a stroll may use of `zone` (_ground's entry), built now if its grid is new.
func _stroll_ground(zone: WorldPhysicalZoneArea2D) -> Dictionary:
	var area: Rect2 = zone.global_rect()
	var grid: Grid = _grid(area)
	var cached: Dictionary = _ground.get(zone.zone_id, {})
	if not cached.is_empty() and cached["grid"] == grid:
		return cached
	var free: Array[Vector2i] = grid.free_cells_in(area)
	# The cells by a seam, marked from each seam's own few cells (as _strictly_off_seams() would
	# find them, without testing every cell of a big street against every door of the map).
	var by_seam: Dictionary[Vector2i, bool] = {}
	for seam: Rect2 in _seams(zone):
		var clipped: Rect2 = seam.intersection(area.grow(CELL))
		if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
			continue
		var first: Vector2i = grid.cell_of(clipped.position)
		var last: Vector2i = grid.cell_of(clipped.end)
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if seam.has_point(grid.center_of(cell)):
					by_seam[cell] = true
	var cells: Array[Vector2i] = []
	var allowed: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in free:
		if not by_seam.has(cell) and grid.open(cell, STROLL_OPEN_CELLS) and zone.contains_center(grid.center_of(cell)):
			allowed[cell] = true
			cells.append(cell)
	var standable: Dictionary[Vector2i, bool] = {}
	cached = {"grid": grid, "cells": cells, "allowed": allowed, "standable": standable}
	_ground[zone.zone_id] = cached
	return cached


## Where the walk ends (its last point), or the body's position when not walking.
func rest_position(character_id: StringName, body: Node2D) -> Vector2:
	var path: PackedVector2Array = _walks.get(character_id, PackedVector2Array())
	return body.global_position if path.is_empty() else path[path.size() - 1]


## A body-sized free spot in `to_zone` reachable from `body`, with its path; false
## when there is none. `random` draws the spot (legacy_random over candidates).
func walk_into(character_id: StringName, body: Node2D, from_zone: WorldPhysicalZoneArea2D, to_zone: WorldPhysicalZoneArea2D, random: WorldInteractionRandomSource) -> bool:
	if body == null or from_zone == null or to_zone == null or random == null:
		return false
	var grid: Grid = _grid(from_zone.global_rect().merge(to_zone.global_rect()))
	var candidates: Array[Vector2i] = _clear_of(grid, grid.free_cells_in(to_zone.global_rect()), _occupied(character_id))
	candidates = _off_seams(grid, to_zone, candidates)
	for attempt: int in range(mini(DESTINATION_TRIES, candidates.size())):
		var index: int = random.legacy_random(candidates.size())
		if index < 0 or index >= candidates.size():
			return false
		var spot: Vector2 = grid.center_of(candidates[index])
		candidates.remove_at(index)
		if MapPlacementValidator.is_valid_character_position(_map, to_zone.zone_id, spot) and _start(grid, character_id, body, spot):
			return true
	return false


## A spot in `to_zone` as walk_into() draws one, the body put there at once: for a move
## that must happen though no path leads there (a doorway the grid keeps shut, a body in
## the way). False when the zone has no room.
func place_into(character_id: StringName, body: Node2D, to_zone: WorldPhysicalZoneArea2D, random: WorldInteractionRandomSource) -> bool:
	if body == null or to_zone == null or random == null:
		return false
	var grid: Grid = _grid(to_zone.global_rect())
	var candidates: Array[Vector2i] = _clear_of(grid, grid.free_cells_in(to_zone.global_rect()), _occupied(character_id))
	candidates = _off_seams(grid, to_zone, candidates)
	for attempt: int in range(mini(DESTINATION_TRIES, candidates.size())):
		var index: int = random.legacy_random(candidates.size())
		if index < 0 or index >= candidates.size():
			return false
		var spot: Vector2 = grid.center_of(candidates[index])
		candidates.remove_at(index)
		if MapPlacementValidator.is_valid_character_position(_map, to_zone.zone_id, spot):
			cancel(character_id)
			body.global_position = spot
			return true
	return false


## A standing NPC the player keeps pushing into steps aside (owner, polish, A5): to the
## nearest free spot of its own zone across the player's way, off the zone's seams, drawn
## from no random stream. Its place does not change; false when there is no such spot.
func step_aside(character_id: StringName, body: Node2D, zone: WorldPhysicalZoneArea2D, pusher: Vector2) -> bool:
	if body == null or zone == null or is_walking(character_id):
		return false
	var area: Rect2 = zone.global_rect()
	var grid: Grid = _grid(area)
	var others: Array[Vector2] = _occupied(character_id)
	var push: Vector2 = (body.global_position - pusher).normalized()
	if push == Vector2.ZERO:
		push = Vector2.RIGHT
	var scored: Array[Array] = []
	var near: Array[Vector2i] = []
	for cell: Vector2i in grid.free_cells_in(area):
		var offset: Vector2 = grid.center_of(cell) - body.global_position
		if offset.length() < CELL * 2.0 or offset.length() > STEP_ASIDE_REACH or offset.dot(push) < -CELL:
			continue
		near.append(cell)
	for cell: Vector2i in _off_seams(grid, zone, _clear_of(grid, near, others)):
		var offset: Vector2 = grid.center_of(cell) - body.global_position
		# Out of the way (a body's width across the push), then the shortest step.
		if absf(offset.cross(push)) < STEP_ASIDE_ACROSS:
			continue
		scored.append([offset.length() + maxf(offset.dot(push), 0.0) * 0.5, cell])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and (a[1] as Vector2i) < (b[1] as Vector2i)))
	for entry: Array in scored.slice(0, DESTINATION_TRIES):
		var spot: Vector2 = grid.center_of(entry[1])
		if MapPlacementValidator.is_valid_character_position(_map, zone.zone_id, spot) and _start(grid, character_id, body, spot):
			return true
	return false


## The cells of `cells`, in order, whose centres keep KEEP_CLEAR from every point of
## `others`: each point marks the cells near it, as testing every cell against every
## point would, without the cost of that on a big map full of people.
static func _clear_of(grid: Grid, cells: Array[Vector2i], others: Array[Vector2]) -> Array[Vector2i]:
	var near: Dictionary[Vector2i, bool] = {}
	var reach: Vector2 = Vector2(KEEP_CLEAR, KEEP_CLEAR)
	for other: Vector2 in others:
		var first: Vector2i = grid.cell_of(other - reach) - Vector2i.ONE
		var last: Vector2i = grid.cell_of(other + reach) + Vector2i.ONE
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if other.distance_to(grid.center_of(cell)) < KEEP_CLEAR:
					near[cell] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not near.has(cell):
			result.append(cell)
	return result


## The cells of `candidates` farther than SEAM_CLEAR from where `zone` joins its map's
## other zones, its passages and its doors; all of them when none is.
func _off_seams(grid: Grid, zone: WorldPhysicalZoneArea2D, candidates: Array[Vector2i]) -> Array[Vector2i]:
	var clear: Array[Vector2i] = _strictly_off_seams(grid, zone, candidates)
	return candidates if clear.is_empty() else clear


## Where `zone` meets the map's other zones, its passages and its doors, each grown by SEAM_CLEAR.
func _seams(zone: WorldPhysicalZoneArea2D) -> Array[Rect2]:
	var seams: Array[Rect2] = []
	for other: WorldPhysicalZoneArea2D in _map.physical_zones():
		if other != zone and other.global_rect().grow(1.0).intersects(zone.global_rect()):
			seams.append(other.global_rect().grow(SEAM_CLEAR))
	for passage: WorldPassageArea2D in _map.static_nodes().passages:
		seams.append(passage.global_rect().grow(SEAM_CLEAR))
	for door: WorldDoor in _map.static_nodes().doors:
		var wall: CollisionShape2D = door.wall_shape()
		var rectangle: RectangleShape2D = null if wall == null else wall.shape as RectangleShape2D
		if rectangle != null:
			seams.append(Rect2(wall.global_position - rectangle.size / 2.0, rectangle.size).grow(SEAM_CLEAR))
	return seams


## The cells of `candidates` farther than SEAM_CLEAR from the zone's seams, maybe none.
func _strictly_off_seams(grid: Grid, zone: WorldPhysicalZoneArea2D, candidates: Array[Vector2i]) -> Array[Vector2i]:
	var seams: Array[Rect2] = _seams(zone)
	var clear: Array[Vector2i] = []
	for cell: Vector2i in candidates:
		var point: Vector2 = grid.center_of(cell)
		var off: bool = true
		for seam: Rect2 in seams:
			if seam.has_point(point):
				off = false
				break
		if off:
			clear.append(cell)
	return clear


## A walk across the map to `spot` or the free cell nearest it a body may reach (a way out: a
## passage, a door's wall), through people as a room move walks (D: one going indoors at night,
## coming out at dawn). False when no such cell can be reached.
func walk_across(character_id: StringName, body: Node2D, spot: Vector2) -> bool:
	if body == null or not spot.is_finite():
		return false
	var grid: Grid = Grid.new(_map, Rect2(body.global_position, Vector2.ZERO).expand(spot).grow(CELL * 6.0))
	var target: Vector2i = grid.cell_of(spot)
	var ends: Array[Vector2i] = []
	for radius: int in range(0, 4):
		for y: int in range(target.y - radius, target.y + radius + 1):
			for x: int in range(target.x - radius, target.x + radius + 1):
				var cell := Vector2i(x, y)
				if grid._astar.is_in_boundsv(cell) and not grid._astar.is_point_solid(cell) and not ends.has(cell):
					ends.append(cell)
	ends.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return grid.center_of(a).distance_squared_to(spot) < grid.center_of(b).distance_squared_to(spot))
	for cell: Vector2i in ends.slice(0, 6):
		# Onto the spot itself when its own cell is free (a spawn marker), else the cell's middle.
		if _start(grid, character_id, body, spot if cell == target else grid.center_of(cell)):
			return true
	return false


## The grid of `area` as Grid.new() would build it now.
func _grid(area: Rect2) -> Grid:
	var walls: PackedByteArray = Grid.walls_up(_map.static_nodes())
	var grid: Grid = _grids.get(area)
	if grid == null or grid.walls != walls:
		grid = Grid.new(_map, area)
		_grids[area] = grid
	return grid


## A walk to a known spot (an NPC's spawn marker); false when no path reaches it. A body
## still on its way into `from_zone` (a follower the player outpaced) walks on from where it
## is.
func walk_to(character_id: StringName, body: Node2D, from_zone: WorldPhysicalZoneArea2D, to_zone: WorldPhysicalZoneArea2D, spot: Vector2) -> bool:
	if body == null or from_zone == null or to_zone == null:
		return false
	var area: Rect2 = from_zone.global_rect().merge(to_zone.global_rect())
	if not area.has_point(body.global_position):
		area = area.expand(body.global_position).grow(CELL)
	return _start(Grid.new(_map, area), character_id, body, spot)


## Where the player and the other NPCs stand or are going.
func _occupied(character_id: StringName) -> Array[Vector2]:
	var result: Array[Vector2] = [_map.runtime_player_body().global_position]
	for npc: NpcRuntimeState in _map.npc_runtimes():
		var body: Node2D = _map.runtime_body_for_character(npc.character_id)
		if npc.character_id != character_id and npc.exists_in_map and body != null:
			result.append(rest_position(npc.character_id, body))
	return result


func _start(grid: Grid, character_id: StringName, body: Node2D, spot: Vector2, through: bool = true) -> bool:
	var path: PackedVector2Array = grid.path(body.global_position, spot)
	if path.is_empty():
		return false
	path.append(spot)
	# A move the rules made replaces a stroll under way, and walks as such.
	_strolls.erase(character_id)
	_walks[character_id] = path
	_set_walking(body, through)
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
		var budget: float = _strolls.get(character_id, SPEED) * delta
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
			_strolls.erase(character_id)
			_set_walking(body, false)
		else:
			_walks[character_id] = path


## Puts every walking body at its walk's end (the map stops being watched); a stroll stops
## where it is (every spot of its way is one a body may stand on).
func finish_all() -> void:
	for character_id: StringName in _walks.keys():
		var body: Node2D = _map.runtime_body_for_character(character_id)
		if body != null and not _strolls.has(character_id):
			body.global_position = rest_position(character_id, body)
			_set_walking(body, false)
	_walks.clear()
	_strolls.clear()


func cancel(character_id: StringName) -> void:
	_strolls.erase(character_id)
	if _walks.has(character_id):
		_walks.erase(character_id)
		_set_walking(_map.runtime_body_for_character(character_id), false)


## Walkable cells of one rectangle of the map: painted, no colliding tile and no
## enabled static shape within one cell (a body is 34 px, a cell 16).
class Grid:
	extends RefCounted
	var _astar: AStarGrid2D = AStarGrid2D.new()
	## walls_up() when it was built.
	var walls: PackedByteArray
	var _origin: Vector2
	var _size: Vector2i

	func _init(map: Node, area: Rect2) -> void:
		var parts: WorldMapStaticNodes = (map as WorldMapController).static_nodes() if map is WorldMapController else WorldMapStaticNodes.new(map)
		var layers: Array[TileMapLayer] = parts.layers
		walls = walls_up(parts)
		# Cells sit on the tiles' own grid.
		var offset: Vector2 = Vector2.ZERO if layers.is_empty() else (layers[0].to_global(layers[0].map_to_local(Vector2i.ZERO)) - Vector2(CELL, CELL) / 2.0).posmod(CELL)
		var region: Rect2 = area.grow(CELL * 2.0)
		_origin = ((region.position - offset) / CELL).floor() * CELL + offset
		_size = Vector2i(ceili((region.end.x - _origin.x) / CELL), ceili((region.end.y - _origin.y) / CELL))
		var blocked: PackedByteArray = PackedByteArray()
		blocked.resize(_size.x * _size.y)
		for y: int in _size.y:
			for x: int in _size.x:
				blocked[y * _size.x + x] = 0 if parts.walkable_tile(center_of(Vector2i(x, y))) else 1
		for collision: CollisionShape2D in parts.static_shapes:
			if collision.disabled or collision.shape == null:
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
		# Solid within one cell of a blocked one, as two passes: blocked along the row, then down the
		# column; a cell on the edge has a neighbour outside and is solid.
		var across: PackedByteArray = PackedByteArray()
		across.resize(blocked.size())
		for y: int in _size.y:
			var row: int = y * _size.x
			for x: int in range(1, _size.x - 1):
				across[row + x] = blocked[row + x - 1] | blocked[row + x] | blocked[row + x + 1]
		for y: int in _size.y:
			var row: int = y * _size.x
			var edge_row: bool = y == 0 or y == _size.y - 1
			for x: int in _size.x:
				if edge_row or x == 0 or x == _size.x - 1 or (across[row - _size.x + x] | across[row + x] | across[row + _size.x + x]) == 1:
					_astar.set_point_solid(Vector2i(x, y), true)

	## Which of the map's static collision shapes block now (a door wing opens and shuts).
	static func walls_up(parts: WorldMapStaticNodes) -> PackedByteArray:
		var result: PackedByteArray = PackedByteArray()
		for collision: CollisionShape2D in parts.static_shapes:
			result.append(0 if collision.disabled or collision.shape == null else 1)
		return result

	## Whether every cell within `reach` cells of `cell` is free.
	func open(cell: Vector2i, reach: int) -> bool:
		for y: int in range(cell.y - reach, cell.y + reach + 1):
			for x: int in range(cell.x - reach, cell.x + reach + 1):
				var near := Vector2i(x, y)
				if not _astar.is_in_boundsv(near) or _astar.is_point_solid(near):
					return false
		return true

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
