extends RefCounted

## The ways of 雪亭镇, 卧龙岗 and 绮云镇, 老松林 and 野羊山 are sized for the voxel view (DECISIONS
## 「地图尺寸以体素视角为准」): along each main route a body standing anywhere on the way can be
## walked round without touching it; no NPC stands where it closes a way; an aggressive NPC
## outdoors can be passed outside its notice, but for those that hold the way in the source (a
## gate, a gang on the road, a maze's mouth: HOLDS).
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
## Main routes per map, as chains of neighbouring zones; a portal ID is the way out of the zone
## before it.
const ROUTES: Dictionary[StringName, Array] = {
	&"snow.outdoor": [
		[&"snow.square", &"snow.mstreet1", &"snow.mstreet2", &"snow.mstreet3", &"snow.mstreet4", &"snow.crossroad"],
		[&"snow.square", &"snow.sroad1", &"snow.sroad2", &"snow.sroad3", &"snow.sroad4", &"snow.sroad5", &"snow.sroad5.west"],
		[&"snow.sroad4", &"snow.sroad4.southwest"],
		[&"snow.sroad1", &"snow.eroad1", &"snow.eroad2", &"snow.eroad3"],
		[&"snow.mstreet1", &"snow.school1"],
	],
	&"cloud.outdoor": [
		[&"cloud.dragonhill.nroad", &"cloud.dragonhill.nhillfoot", &"cloud.dragonhill.hummock", &"cloud.dragonhill.shillfoot",
			&"cloud.entrance", &"cloud.nwroad1", &"cloud.nwroad2", &"cloud.nwroad3", &"cloud.nroad1", &"cloud.nroad2", &"cloud.cross",
			&"cloud.sroad1", &"cloud.dukou"],
		[&"cloud.wroad0", &"cloud.wroad1", &"cloud.wroad2", &"cloud.cross", &"cloud.eroad1", &"cloud.eroad2", &"cloud.eroad3",
			&"cloud.eroad4"],
		[&"cloud.eroad2", &"cloud.park"],
		[&"cloud.dragonhill.sroad", &"cloud.entrance"],
	],
	&"oldpine.outdoor": [
		[&"oldpine.outdoor.north_approach", &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.east_bridge"],
		[&"oldpine.outdoor.central_clearing", &"oldpine.outdoor.slope"],
		[&"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.keep_gate"],
		[&"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.pine_deep", &"oldpine.outdoor.pine_cliff_edge"],
		[&"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.cliffside"],
	],
	&"goathill.mountain": [
		[&"goathill.mroad1", &"goathill.mroad2", &"goathill.mroad3", &"goathill.mroad4", &"goathill.mroad5", &"goathill.mroad6",
			&"goathill.canyon1", &"goathill.canyon2", &"goathill.canyon3"],
	],
	&"goathill.caverns": [
		[&"goathill.cavern1", &"goathill.cavern2", &"goathill.cavern3"],
		[&"goathill.cavern1", &"goathill.cavern4"],
	],
}
## Aggressive NPCs that hold the way as the source has them: 野羊山's gang at the road's turn,
## 老松寨's guards at its gate and in its yard, the two bandits at the pine maze's mouth, the wolf
## dog in the maze, the slope's bandits on their dead end.
const HOLDS: Array[String] = ["goathill.mroad4.", "oldpine.outdoor.keep_gate.", "oldpine.outdoor.keep_yard.",
	"oldpine.outdoor.pine_entrance.pine1.", "oldpine.outdoor.pine_cliff_edge.pine7.", "oldpine.outdoor.slope.spath1."]
## The player's half width: a presence circle reaches the body's edge.
const HALF_BODY: float = 17.0
## How far (in grid cells) the way round a body may stray from the way itself: no other branch of
## a loop stands in for a stretch too narrow to pass someone.
const DETOUR: int = 8
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	for map_id: StringName in ROUTES:
		var spawn: String = String(GameContent.catalog().map(map_id).entry_spawn_id)
		var map: WorldMapController = MapPlaces.enter(session, StringName(spawn.substr(0, spawn.rfind("."))), StringName(spawn))
		_check(map != null and map.map_id() == map_id, "on %s" % map_id)
		if map == null:
			continue
		await _frames(tree, 4)
		var ways: Array = []
		for route: Array in ROUTES[map_id]:
			for i: int in route.size() - 1:
				var from: Vector2 = _spot(map, route[i])
				var to: Vector2 = _spot(map, route[i + 1])
				ways.append([route[i], route[i + 1], from, to, MapRoute.path(map, from, to)])
		_check_passing(map, ways)
		_check_npcs(map, ways)
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


## A zone's middle, or the spot before a way out of the zone named before it.
func _spot(map: WorldMapController, place: StringName) -> Vector2:
	var portal: PortalDefinition = GameContent.catalog().portal(place)
	if portal == null:
		return MapPlaces.zone_spot(map, place)
	return MapPlaces.spot(map, portal.source_zone_id, MapPlaces.passage(map, place).global_position, 96.0)


## Each stretch, with a body standing anywhere on it, can still be walked (a 5-cell square about
## the body solid, as voxel_waterfog_test), close to the way itself (DETOUR).
func _check_passing(map: WorldMapController, ways: Array) -> void:
	var blocked: Array[String] = []
	for way: Array in ways:
		var points: PackedVector2Array = way[4]
		if points.is_empty():
			blocked.append("%s-%s: no way" % [way[0], way[1]])
			continue
		var grid: WorldNpcWalker.Grid = MapRoute.grid(map)
		MapRoute._shut_passages(grid, map, way[2], way[3])
		var near: Dictionary[Vector2i, bool] = {}
		for point: Vector2 in points:
			var middle: Vector2i = grid.cell_of(point)
			for dy: int in range(-DETOUR, DETOUR + 1):
				for dx: int in range(-DETOUR, DETOUR + 1):
					near[middle + Vector2i(dx, dy)] = true
		for y: int in grid._size.y:
			for x: int in grid._size.x:
				if not near.has(Vector2i(x, y)):
					grid._astar.set_point_solid(Vector2i(x, y), true)
		for step: int in range(4, points.size() - 4, 5):
			var body: Vector2i = grid.cell_of(points[step])
			var made: Array[Vector2i] = []
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var cell: Vector2i = body + Vector2i(dx, dy)
					if grid._astar.is_in_boundsv(cell) and not grid._astar.is_point_solid(cell):
						grid._astar.set_point_solid(cell, true)
						made.append(cell)
			if grid.path(way[2], way[3]).is_empty():
				blocked.append("%s-%s at %s" % [way[0], way[1], points[step]])
			for cell: Vector2i in made:
				grid._astar.set_point_solid(cell, false)
	_check(blocked.is_empty(), "every stretch on %s can be walked round a body standing in it: %s" % [map.map_id(), blocked])


## Where the NPCs stand, every stretch near one can still be walked round it; one that would
## fight the player on sight outdoors can be passed outside its presence, unless it holds the way.
func _check_npcs(map: WorldMapController, ways: Array) -> void:
	var closing: Array[String] = []
	var noticed: Array[String] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: Node2D = map.npcs._npc_bodies.get(npc.character_id)
		if not npc.exists_in_map or body == null:
			continue
		var at: Vector2 = body.global_position
		var aggressive: bool = npc.definition().attitude == NpcDefinition.Attitude.AGGRESSIVE and not WorldMapHostilities.notices_room(npc)
		var holds: bool = HOLDS.any(func(prefix: String) -> bool: return String(npc.spawn_point_id).begins_with(prefix))
		var reach: float = _presence(map, npc) + HALF_BODY
		for way: Array in ways:
			var points: PackedVector2Array = way[4]
			var near: float = INF
			for point: Vector2 in points:
				near = minf(near, point.distance_to(at))
			if near < 48.0 and MapRoute.path(map, way[2], way[3], [body]).is_empty():
				closing.append("%s closes %s-%s" % [npc.spawn_point_id, way[0], way[1]])
			if aggressive and not holds and near < reach and not _passes_outside(map, way[2], way[3], at, reach):
				noticed.append("%s on %s-%s" % [npc.spawn_point_id, way[0], way[1]])
	_check(closing.is_empty(), "no NPC on %s stands where it closes a way: %s" % [map.map_id(), closing])
	_check(noticed.is_empty(), "every aggressive NPC on %s that does not hold the way can be passed outside its notice: %s" % [map.map_id(), noticed])


func _presence(map: WorldMapController, npc: NpcRuntimeState) -> float:
	var area: Area2D = map.npcs.npc_presence.get(npc.character_id)
	var shape: CollisionShape2D = null if area == null else area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var circle: CircleShape2D = null if shape == null else shape.shape as CircleShape2D
	return 0.0 if circle == null else circle.radius


func _passes_outside(map: WorldMapController, from: Vector2, to: Vector2, centre: Vector2, reach: float) -> bool:
	if from.distance_to(centre) < reach or to.distance_to(centre) < reach:
		return false
	var grid: WorldNpcWalker.Grid = MapRoute.grid(map)
	var cells: int = ceili(reach / WorldNpcWalker.CELL) + 1
	var middle: Vector2i = grid.cell_of(centre)
	for dy: int in range(-cells, cells + 1):
		for dx: int in range(-cells, cells + 1):
			var cell: Vector2i = middle + Vector2i(dx, dy)
			if grid._astar.is_in_boundsv(cell) and grid.center_of(cell).distance_to(centre) < reach + WorldNpcWalker.CELL / 2.0:
				grid._astar.set_point_solid(cell, true)
	return not grid.path(from, to).is_empty()


func _frames(tree: SceneTree, count: int) -> void:
	for i: int in count:
		await tree.physics_frame
		await tree.process_frame


func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
