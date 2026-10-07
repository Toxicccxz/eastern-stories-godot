extends RefCounted

## Map terrain is painted on TileMapLayers with one placeholder TileSet (3B4), and the tiles carry
## the collision: Old Pine since 3B5, Snow since 3B6, counters and furniture too since every map is
## painted. Zones, portals, spawns and the other components stay separate nodes.
const BLOCKING_TERRAIN: Array[String] = ["shop_front", "shutter", "wall", "wall_wood", "boundary", "forest",
	"water", "deep_water", "blocked", "cliff", "chasm"]
const TILE := 16.0

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_tileset()
	for map: MapDefinition in GameContent.catalog().maps():
		_test_map(map)
	_test_terrain_spot_checks()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_tileset() -> void:
	var tile_set: TileSet = load(TerrainProbe.TILESET_PATH) as TileSet
	_assert_eq(tile_set.tile_size, Vector2i(16, 16), "placeholder tiles are 16 px")
	_assert_eq(tile_set.get_physics_layers_count(), 1, "terrain tiles have one physics layer")
	_assert_eq(tile_set.get_custom_data_layer_by_name("terrain"), 0, "every tile names its terrain")
	var source: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
	var names: Dictionary[String, bool] = {}
	for index: int in source.get_tiles_count():
		var data: TileData = source.get_tile_data(source.get_tile_id(index), 0)
		var name: String = str(data.get_custom_data("terrain"))
		_assert_true(not name.is_empty() and not names.has(name), "atlas tile %d has its own terrain name" % index)
		_assert_eq(data.get_collision_polygons_count(0) > 0, BLOCKING_TERRAIN.has(name), "%s collides exactly when it blocks" % name)
		names[name] = true


func _test_map(map: MapDefinition) -> void:
	var scene: Node2D = (load(map.scene_path) as PackedScene).instantiate() as Node2D
	var layers: Array[TileMapLayer] = TerrainProbe.layers(scene)
	_assert_true(not layers.is_empty(), "%s paints terrain on TileMapLayers" % map.map_id)
	for layer: TileMapLayer in layers:
		_assert_eq(layer.tile_set.resource_path, TerrainProbe.TILESET_PATH, "%s/%s uses the shared TileSet" % [map.map_id, layer.name])
		_assert_eq(layer.get_child_count(), 0, "%s/%s holds no zone, portal, spawn or collision node" % [map.map_id, layer.name])
		_assert_true(layer.collision_enabled, "%s/%s collides through its tiles" % [map.map_id, layer.name])
		var unnamed: int = 0
		for cell: Vector2i in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(cell)
			if data == null or str(data.get_custom_data("terrain")).is_empty():
				unnamed += 1
		_assert_eq(unnamed, 0, "%s/%s paints only named terrain tiles" % [map.map_id, layer.name])
	_test_tile_collision_map(map, scene, layers)
	for node: Node in scene.find_children("*", "Area2D", true, false):
		var zone: WorldPhysicalZoneArea2D = node as WorldPhysicalZoneArea2D
		if zone == null:
			continue
		var collision: CollisionShape2D = zone.get_node("CollisionShape2D") as CollisionShape2D
		var center: Vector2 = zone.position + collision.position
		_assert_true(not TerrainProbe.terrain_at(scene, center).is_empty(), "%s has ground under its centre" % zone.zone_id)
	for node: Node in scene.find_children("*", "Marker2D", true, false):
		var marker: WorldSpawnMarker2D = node as WorldSpawnMarker2D
		if marker == null:
			continue
		var terrain: String = TerrainProbe.terrain_at(scene, _map_position(scene, marker))
		_assert_true(not terrain.is_empty() and not BLOCKING_TERRAIN.has(terrain), "%s stands on open ground (%s)" % [marker.spawn_point_id, terrain])
	scene.free()


## Tiles are the walls: no stray StaticBody, doors fill their tile openings, and every walkable
## cell is enclosed by painted cells.
func _test_tile_collision_map(map: MapDefinition, scene: Node2D, layers: Array[TileMapLayer]) -> void:
	var switchable: Array[Node] = []
	for node: Node in scene.find_children("*", "", true, false):
		if node is WorldDoor:
			switchable.append((node as WorldDoor).wall_shape())
			_test_door_fits_opening(map, scene, node as WorldDoor)
		elif node is WorldPassageArea2D and not (node as WorldPassageArea2D).closed_wall_path.is_empty():
			switchable.append(node.get_node((node as WorldPassageArea2D).closed_wall_path))
	for node: Node in scene.find_children("*", "", true, false):
		if (node is CollisionShape2D or node is CollisionPolygon2D) and node.get_parent() is StaticBody2D:
			_assert_true(switchable.has(node), "%s keeps no node collision but %s" % [map.map_id, scene.get_path_to(node)])
	var painted: Dictionary[Vector2i, bool] = {}
	var walkable: Array[Vector2i] = []
	for layer: TileMapLayer in layers:
		for cell: Vector2i in layer.get_used_cells():
			painted[cell] = true
			if layer.get_cell_tile_data(cell).get_collision_polygons_count(0) == 0:
				walkable.append(cell)
	var open_edges: int = 0
	for cell: Vector2i in walkable:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not painted.has(cell + step):
				open_edges += 1
	_assert_eq(open_edges, 0, "%s has no walkable cell next to unpainted void" % map.map_id)


## A closed door blocks exactly its doorway: the walkable cells between two wall tiles, and its
## shutter is drawn over the same cells.
func _test_door_fits_opening(map: MapDefinition, scene: Node2D, door: WorldDoor) -> void:
	var label: String = "%s door %s" % [map.map_id, door.door_id]
	var wall: CollisionShape2D = door.wall_shape()
	var shutter: Polygon2D = door.get_node_or_null(door.shutter) as Polygon2D
	_assert_true(wall != null and wall.shape is RectangleShape2D and shutter != null, "%s has a rectangular wall and a shutter" % label)
	if wall == null or not wall.shape is RectangleShape2D or shutter == null:
		return
	var size: Vector2 = (wall.shape as RectangleShape2D).size
	var rect := Rect2(_map_position(scene, wall) - size / 2.0, size)
	_assert_true(is_zero_approx(fposmod(rect.position.x, TILE)) and is_zero_approx(fposmod(rect.position.y, TILE))
		and is_zero_approx(fposmod(rect.size.x, TILE)) and is_zero_approx(fposmod(rect.size.y, TILE)), "%s sits on the tile grid (%s)" % [label, rect])
	var drawn := Rect2(shutter.polygon[0], Vector2.ZERO)
	for point: Vector2 in shutter.polygon:
		drawn = drawn.expand(point)
	drawn.position += _map_position(scene, shutter)
	_assert_eq(drawn, rect, "%s shutter is drawn where the door blocks" % label)
	var along: Vector2 = Vector2.DOWN if rect.size.y > rect.size.x else Vector2.RIGHT
	var across: Vector2 = Vector2(along.y, along.x)
	var walkable: bool = true
	var jambs: bool = true
	for a: int in int(rect.size.dot(across) / TILE):
		var start: Vector2 = rect.position + across * (a * TILE + TILE / 2.0)
		for b: int in int(rect.size.dot(along) / TILE):
			var terrain: String = TerrainProbe.terrain_at(scene, start + along * (b * TILE + TILE / 2.0))
			walkable = walkable and not terrain.is_empty() and not BLOCKING_TERRAIN.has(terrain)
		jambs = jambs and BLOCKING_TERRAIN.has(TerrainProbe.terrain_at(scene, start - along * (TILE / 2.0)))
		jambs = jambs and BLOCKING_TERRAIN.has(TerrainProbe.terrain_at(scene, start + along * (rect.size.dot(along) + TILE / 2.0)))
	_assert_true(walkable, "%s covers walkable doorway cells only" % label)
	_assert_true(jambs, "%s spans the doorway from wall tile to wall tile" % label)


func _test_terrain_spot_checks() -> void:
	var forest: Node2D = _scene("res://scenes/world/oldpine/oldpine_outdoor.tscn")
	for row: Array in [
		[Vector2(450, -250), "path", false], [Vector2(1200, 100), "chasm", true], [Vector2(1200, 300), "bridge", false],
		[Vector2(150, 845), "forest", true], [Vector2(-820, 700), "forest", true], [Vector2(-1480, 850), "cliff", true],
		[Vector2(880, 860), "forest_floor", false], [Vector2(325, 1250), "cliff", true], [Vector2(450, 616), "path", false],
	]:
		_spot(forest, "Old Pine forest", row)
	forest.free()
	var gorge: Node2D = _scene("res://scenes/world/oldpine/oldpine_gorge.tscn")
	for row: Array in [
		[Vector2(1200, 850), "shallow_water", false], [Vector2(1200, 640), "water", true], [Vector2(1200, 1650), "water", true],
		[Vector2(1420, 1650), "riverbank", false], [Vector2(1090, 2625), "deep_water", true], [Vector2(890, 1650), "cliff", true],
	]:
		_spot(gorge, "Old Pine gorge", row)
	gorge.free()
	var cave: Node2D = _scene("res://scenes/world/oldpine/oldpine_cave.tscn")
	_spot(cave, "Old Pine cave", [Vector2(0, -240), "cave_floor", false])
	_spot(cave, "Old Pine cave", [Vector2(0, -420), "blocked", true])
	_spot(cave, "Old Pine cave", [Vector2(0, 400), "shallow_water", false])
	cave.free()
	var snow: Node2D = _scene("res://scenes/world/snow/snow_outdoor.tscn")
	for row: Array in [
		[Vector2(0, 0), "town_ground", false], [Vector2(0, -1000), "street", false],
		# the square's old wooden frame, the inn's front on its west side with the door's step
		[Vector2(0, -88), "blocked", true], [Vector2(-312, 0), "town_ground", false], [Vector2(-328, 0), "wall_wood", true],
		# the counters and the millstone are tiles, not node collision
		[Vector2(-312, -384), "blocked", true], [Vector2(248, -1080), "blocked", true], [Vector2(344, -744), "blocked", true],
		# the mountain wall east of the 山路; the road south to Old Pine runs to the map's closed edge
		[Vector2(1296, 500), "cliff", true], [Vector2(1160, 920), "path", false], [Vector2(1160, 944), "boundary", true],
		# beyond the col east of the track to the next village
		[Vector2(300, -1680), "boundary", true],
	]:
		_spot(snow, "Snow", row)
	snow.free()
	var inn: Node2D = _scene("res://scenes/world/snow/snow_inn.tscn")
	_spot(inn, "Inn", [Vector2(0, -304), "wall_wood", true])
	_spot(inn, "Inn", [Vector2(0, -200), "blocked", true])
	_spot(inn, "Inn", [Vector2(432, 0), "floor_wood", false])
	_spot(inn, "Inn", [Vector2(464, 0), "boundary", true])
	_spot(inn, "Inn", [Vector2(432, 100), "wall_wood", true])
	inn.free()


func _spot(map: Node2D, label: String, row: Array) -> void:
	_assert_eq(TerrainProbe.terrain_at(map, row[0]), row[1], "%s %s is drawn as %s" % [label, row[0], row[1]])
	_assert_eq(TerrainProbe.blocks_at(map, row[0]), row[2], "%s %s blocks: %s" % [label, row[0], row[2]])


func _scene(path: String) -> Node2D:
	return (load(path) as PackedScene).instantiate() as Node2D


func _map_position(map: Node2D, node: Node2D) -> Vector2:
	var position: Vector2 = node.position
	var parent: Node = node.get_parent()
	while parent != map:
		position = (parent as Node2D).transform * position if parent is Node2D else position
		parent = parent.get_parent()
	return position


func _assert_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append("TERRAIN: " + message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("TERRAIN: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
