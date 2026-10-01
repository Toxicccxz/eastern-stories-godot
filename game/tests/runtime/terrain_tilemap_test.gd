extends RefCounted

## Package 3B4: map terrain is painted on TileMapLayers with one placeholder TileSet.
## Collision, zones, portals and spawns stay separate components.
const BLOCKING_TERRAIN: Array[String] = ["wall", "wall_wood", "boundary", "forest", "blocked"]

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_tileset()
	for map: MapDefinition in GameContent.catalog().maps():
		_test_map(map)
	_test_terrain_matches_collision()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_tileset() -> void:
	var tile_set: TileSet = load(TerrainProbe.TILESET_PATH) as TileSet
	_assert_eq(tile_set.tile_size, Vector2i(16, 16), "placeholder tiles are 16 px")
	_assert_eq(tile_set.get_physics_layers_count(), 0, "terrain tiles carry no collision")
	_assert_eq(tile_set.get_custom_data_layer_by_name("terrain"), 0, "every tile names its terrain")
	var source: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
	var names: Dictionary[String, bool] = {}
	for index: int in source.get_tiles_count():
		var name: String = str(source.get_tile_data(source.get_tile_id(index), 0).get_custom_data("terrain"))
		_assert_true(not name.is_empty() and not names.has(name), "atlas tile %d has its own terrain name" % index)
		names[name] = true


func _test_map(map: MapDefinition) -> void:
	var scene: Node2D = (load(map.scene_path) as PackedScene).instantiate() as Node2D
	var layers: Array[TileMapLayer] = TerrainProbe.layers(scene)
	_assert_true(not layers.is_empty(), "%s paints terrain on TileMapLayers" % map.map_id)
	for layer: TileMapLayer in layers:
		_assert_eq(layer.tile_set.resource_path, TerrainProbe.TILESET_PATH, "%s/%s uses the shared TileSet" % [map.map_id, layer.name])
		_assert_eq(layer.get_child_count(), 0, "%s/%s holds no zone, portal, spawn or collision node" % [map.map_id, layer.name])
		var unnamed: int = 0
		for cell: Vector2i in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(cell)
			if data == null or str(data.get_custom_data("terrain")).is_empty():
				unnamed += 1
		_assert_eq(unnamed, 0, "%s/%s paints only named terrain tiles" % [map.map_id, layer.name])
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


## Spot checks that painted terrain sits where the unchanged collision is.
func _test_terrain_matches_collision() -> void:
	var outdoor: Node2D = (load("res://scenes/world/oldpine/oldpine_outdoor.tscn") as PackedScene).instantiate() as Node2D
	for row: Array in [
		["Terrain/Boundaries/RiverWaterBoundary/CollisionShape2D", "water"],
		["Terrain/Boundaries/LakeBounds/Pool", "deep_water"],
		["Terrain/Boundaries/PineMazeObstacles/CentralIsland", "forest"],
		["Terrain/Boundaries/PineMazeObstacles/DeadEndWest", "forest"],
	]:
		_assert_eq(TerrainProbe.terrain_at(outdoor, _map_position(outdoor, outdoor.get_node(row[0]) as Node2D)), row[1], "Old Pine %s is drawn as %s" % row)
	outdoor.free()
	var snow: Node2D = (load("res://scenes/world/snow/snow_outdoor.tscn") as PackedScene).instantiate() as Node2D
	for row: Array in [[Vector2(300, -40), "wall"], [Vector2(100, -1300), "boundary"], [Vector2(1200, -400), "wall_wood"], [Vector2(0, 0), "town_ground"], [Vector2(0, -1000), "street"]]:
		_assert_eq(TerrainProbe.terrain_at(snow, row[0]), row[1], "Snow %s is drawn as %s" % row)
	snow.free()
	var inn: Node2D = (load("res://scenes/world/snow/snow_inn.tscn") as PackedScene).instantiate() as Node2D
	_assert_eq(TerrainProbe.terrain_at(inn, Vector2(0, -316)), "wall_wood", "Inn north wall is drawn where it collides")
	_assert_eq(TerrainProbe.terrain_at(inn, Vector2(496, 0)), "", "Inn east doorway is left open")
	inn.free()


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
