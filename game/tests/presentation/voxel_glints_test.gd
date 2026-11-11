extends RefCounted

## 交互闪光点 (owner, 2026-11-11; DECISIONS「交互闪光点」): a twinkling point over each thing that
## does something but may not look it, always on, not only near it. 老松林: the vine, the ancient
## pine, the knife marks and the cliff edge have one; the clearing's sign (only looked at) has none.
## The pass: the iron chain (爬上去) has one; the smooth cliff's oath shows none to a player who was
## never told it. A look that teaches (the dance picture) has one too. On a stage they go away.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(VoxelGlints.worth_a_glint(catalog.landmark(&"oldpine.outdoor.landmark.epath2_vine")) and VoxelGlints.worth_a_glint(catalog.landmark(&"oldpine.outdoor.landmark.ancient_pine")), "a vine and a tree to climb are worth one")
	_check(not VoxelGlints.worth_a_glint(catalog.landmark(&"oldpine.outdoor.landmark.clearing_sign")), "a sign only looked at is not")
	_check(VoxelGlints.worth_a_glint(catalog.landmark(&"latemoon.latebook.landmark.picture")), "a picture that teaches a dance is")
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var outdoor: WorldMapController = MapPlaces.enter(session, &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.central_clearing.player_start")
	_check(outdoor != null, "in 老松林")
	if outdoor != null:
		var view: WorldVoxelView = await _built(tree, outdoor)
		_check(view != null and view.glints != null, "the view has its glints")
		if view != null and view.glints != null:
			var points: Dictionary[StringName, MeshInstance3D] = view.glints.points
			for id: StringName in [&"oldpine.outdoor.landmark.epath2_vine", &"oldpine.outdoor.landmark.ancient_pine", &"oldpine.outdoor.landmark.pine_knife_marks", &"oldpine.outdoor.landmark.cliffdown_cliff"]:
				_check(points.has(id) and points[id].visible, "a glint over %s" % id)
			_check(not points.has(&"oldpine.outdoor.landmark.clearing_sign"), "none over the sign")
			# Always on: the vine is far across the map from the clearing.
			var vine: MeshInstance3D = points.get(&"oldpine.outdoor.landmark.epath2_vine")
			var area: Vector2 = (outdoor.landmark_areas[&"oldpine.outdoor.landmark.epath2_vine"].get_node("CollisionShape2D") as Node2D).global_position
			_check(vine != null and outdoor.runtime_player_body().global_position.distance_to(area) > 600.0 and vine.is_visible_in_tree(), "shown from afar, not only near it")
			_check(vine != null and Vector2(vine.position.x, vine.position.z).is_equal_approx(area / VoxelMapGeometry.UNIT) and is_equal_approx(vine.position.y, VoxelGlints.HEIGHT), "over the vine's own place")
			_check(vine != null and (vine.material_override as StandardMaterial3D).no_depth_test, "out of doors drawn over the tree it hangs from")
			_check(not VoxelGlints._outdoors(&"snow.inn.main_floor") and VoxelGlints._outdoors(&"oldpine.outdoor.east_bridge"), "indoors (behind the roof) and out of doors told apart")
			view.glints.advance(0.3, true)
			_check(not view.glints.visible, "away on a stage")
			view.glints.advance(0.0, false)
			_check(view.glints.visible, "back after it")
	var pass_map: WorldMapController = MapPlaces.enter(session, &"canyon.canyon1", &"canyon.canyon1.chain_arrival")
	_check(pass_map != null, "at the pass")
	if pass_map != null:
		var view: WorldVoxelView = await _built(tree, pass_map)
		if view != null and view.glints != null:
			view.glints.advance(VoxelGlints.REFRESH_SECONDS, false)
			var points: Dictionary[StringName, MeshInstance3D] = view.glints.points
			_check(points.has(&"canyon.canyon1.chain") and points[&"canyon.canyon1.chain"].visible, "a glint over the iron chain up")
			_check(points.has(&"canyon.canyon4.swear") and not points[&"canyon.canyon4.swear"].visible, "none over the oath for one never told it")
		else:
			_check(false, "the pass's view has its glints")
	session.free()
	await _frames(tree, 2)
	return {"assertions": assertions, "failures": failures}


func _built(tree: SceneTree, map: WorldMapController) -> WorldVoxelView:
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	var waited: int = 0
	while view != null and (not view._built or view.glints == null) and waited < 600:
		await tree.process_frame
		waited += 1
	return view


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.process_frame


func _check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
