extends RefCounted

## 老松林 laid out as its rooms describe themselves and as their climbs land (DECISIONS
## 「老松林按原文方位排布」): the slope runs south of the clearing with the sign by the south
## way (clearing.c, spath1-4.c); the gorge runs south from the falls under the bridge, and the
## pines and the keep stand on the high ground east of it; cliffdown is on that ground's edge
## straight above epath3, where climbing down by cliff2 lands; the cliffside looks west over the
## gorge it is climbed up from by cliff1; the plank road up from epath3 is the only way from the
## bank onto the high ground.
const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = SessionScene.instantiate() as WorldSessionController
	session.deterministic_npc_seed = true
	session.deterministic_combat_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.physics_frame
	await tree.physics_frame
	var forest: WorldMapController = session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	_check_places(forest)
	_check_climbs(forest)
	_check_plank_road(forest)
	session.queue_free()
	await tree.process_frame
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _check_places(forest: WorldMapController) -> void:
	var clearing: Rect2 = forest.physical_zone(OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID).global_rect()
	var slope: Rect2 = forest.physical_zone(OldPineWorldDefinitions.SLOPE_ZONE_ID).global_rect()
	var bridge: Rect2 = forest.physical_zone(OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID).global_rect()
	_assert_true(slope.position.y >= clearing.end.y, "the slope lies south of the clearing (clearing.c: 往南的小路; spath1.c: 小路往北通往一处空地)")
	var sign: Vector2 = _interaction(forest, &"oldpine.outdoor.landmark.clearing_sign")
	_assert_true(sign.y > clearing.get_center().y + clearing.size.y * 0.3, "the sign stands by the south way (往南的小路旁竖著一个牌子)")
	for zone_id: StringName in [OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID, OldPineWorldDefinitions.PINE_DEEP_ZONE_ID,
			OldPineWorldDefinitions.PINE_CLIFF_EDGE_ZONE_ID, OldPineWorldDefinitions.CLIFFSIDE_ZONE_ID,
			&"oldpine.outdoor.keep_gate", &"oldpine.outdoor.keep_yard"]:
		_assert_true(forest.physical_zone(zone_id).global_rect().position.x >= bridge.end.x, "%s stands on the high ground east of the gorge" % zone_id)
	# The gorge runs on south below the bridge: chasm beside the cliffside, as far south as it goes.
	var chasm_south: bool = false
	for x: int in range(1100, 1500, 16):
		chasm_south = chasm_south or TerrainProbe.terrain_at(forest, Vector2(x, 900)) == "chasm"
	_assert_true(chasm_south, "the gorge runs south past the cliffside")


func _check_climbs(forest: WorldMapController) -> void:
	# cliffdown → cliff2 → epath3: the cliff's top straight above where the climb lands.
	var top: Vector2 = _interaction(forest, &"oldpine.outdoor.landmark.cliffdown_cliff")
	var landing: Vector2 = forest.resolve_spawn_marker(&"oldpine.outdoor.east_bridge.cliff2_landing").global_position
	_assert_true(top.x > landing.x and absf(top.y - landing.y) < 200.0 and top.x - landing.x < 400.0, "cliffdown's top is just above epath3, where climbing down lands (cliff2.c)")
	_assert_true(_crosses(forest, landing, top, "cliff"), "a cliff face stands between epath3 and cliffdown: climbed, never walked")
	# riverbank1 → cliff1 → cliffside: the drop west of the cliffside goes down into the gorge.
	var edge: Vector2 = _interaction(forest, &"oldpine.outdoor.landmark.cliffside_cliff")
	var west_drop: bool = false
	for step: int in range(1, 30):
		var kind: String = TerrainProbe.terrain_at(forest, edge + Vector2(-16.0 * step, 0))
		west_drop = west_drop or kind == "chasm"
	_assert_true(west_drop, "west of the cliffside the drop goes down into the gorge (cliffside.c: 唯独西边是个悬崖, 也许还可以从这里爬下山涧; cliff1.c)")


func _check_plank_road(forest: WorldMapController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_assert_true(catalog.zones_adjacent(OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "the plank road joins epath3 and pine1")
	_assert_false(catalog.zones_adjacent(OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID), "the clearing has no way into the pines")
	var from: Vector2 = Vector2(1430, 400)
	var up: PackedVector2Array = MapRoute.path(forest, from, MapPlaces.zone_spot(forest, OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID))
	_assert_false(up.is_empty(), "from epath3 the plank road leads up into the pines")
	var up_the_road: bool = true
	for point: Vector2 in up:
		if point.x > 1460.0 and point.x < 1580.0:
			up_the_road = up_the_road and point.y > 400.0 and point.y < 540.0
	_assert_true(up_the_road, "the way up is the plank road and nothing else")


func _interaction(map: WorldMapController, id: StringName) -> Vector2:
	for node: Node in map.find_children("*", "Area2D", true, false):
		if "landmark_id" in node and node.get("landmark_id") == id:
			return (node as Node2D).global_position
	_assert_true(false, "%s stands on the forest map" % id)
	return Vector2.ZERO


func _crosses(map: Node2D, from: Vector2, to: Vector2, kind: String) -> bool:
	var steps: int = int(from.distance_to(to) / 8.0)
	for step: int in steps:
		if TerrainProbe.terrain_at(map, from.lerp(to, float(step) / steps)) == kind:
			return true
	return false


func _assert_true(ok: bool, label: String) -> void:
	_assertion_count += 1
	if not ok:
		_failures.append(label)


func _assert_false(ok: bool, label: String) -> void:
	_assert_true(not ok, label)
