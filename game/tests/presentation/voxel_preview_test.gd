extends RefCounted

## The dev preview (tests/dev/voxel_preview.tscn) shows every voxel map from the game's own
## view and leaves the world alone: nothing moves, nobody fights, no save can be written.
const PREVIEW := preload("res://tests/dev/voxel_preview.tscn")
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	var preview: Node = PREVIEW.instantiate()
	preview.set("remember", false)
	tree.root.add_child(preview)
	await preview.prepared
	var session: WorldSessionController = preview.get("session")
	_check(session.autosave_moment.get_connections().is_empty(), "nothing listens for an autosave moment: no save can be written")
	await _check_every_map(preview, session)
	await _check_view(tree, preview, session)
	await _check_keeps_still(tree, preview, session)
	preview.queue_free()
	await tree.process_frame
	await tree.process_frame
	return {"assertions": assertions, "failures": failures}


## Without a frame between them, so no world is built: every map the list offers can be entered.
func _check_every_map(preview: Node, session: WorldSessionController) -> void:
	var maps: Array[StringName] = preview.get("_maps")
	_check(maps.size() >= 40, "the list offers the voxel maps: %d" % maps.size())
	_check(maps.has(&"snow.outdoor") and maps.has(&"snow.inn_upstairs"), "street and room are both listed")
	var refused: Array[StringName] = []
	for id: StringName in maps:
		if not preview.call("show_map", id) or session.active_map_id() != id:
			refused.append(id)
	_check(refused.is_empty(), "every listed map can be shown: %s" % [refused])
	_check(not preview.call("show_map", &"no.such_map"), "an unknown map is refused")


func _check_view(tree: SceneTree, preview: Node, session: WorldSessionController) -> void:
	_check(preview.call("show_map", &"snow.outdoor"), "onto 雪亭镇")
	await _frames(tree, 4)
	var view: WorldVoxelView = preview.get("view")
	_check(view._built and view.camera.current, "the map's own view is built and looking")
	_check(not session.shared_ui().visible and not session.shared_ui().view_overlay.visible, "the HUD and the room card stay out of the picture")
	_check(view.quest_marker == null or not view.quest_marker.visible, "so does the quest marker")
	_check(not view.is_processing_unhandled_input(), "a click picks nobody")
	var map: WorldMapController = preview.get("map")
	_check(not map.player_body.visible and map.player_body.collision_layer == 0, "the player's body is unseen and touches nothing")
	var zones: Array[StringName] = preview.get("_zones")
	_check(zones.size() > 10, "the zone list fills from the map: %d" % zones.size())
	var location: StringName = session.player_runtime().world_location().zone_id
	var far: StringName = zones[-1] if zones[-1] != location else zones[0]
	preview.call("show_zone", far)
	await _frames(tree, 4)
	_check(map.player_body.global_position.is_equal_approx(map.physical_zone(far).global_rect().get_center()), "the view stands in the chosen zone")
	_check(session.player_runtime().world_location().zone_id == location, "the world's own place for the player does not follow the camera")
	preview.call("set_frame", "night")
	preview.call("set_cloud", 4)
	preview.call("set_side", true)
	await _frames(tree, 2)
	_check(view.held_frame == "night" and view.held_cloud == 4 and view.left_view, "hour, cloud and side reach the view")
	var game_size: float = float(view.layout.get("camera_size", 24.0))
	_check(is_equal_approx(view.camera.size, game_size), "at zoom 1 the camera is the game's")
	preview.call("fit_map")
	await _frames(tree, 2)
	_check(view.camera.size > game_size * 2.0, "the whole town needs more than the game's framing: %.1f" % view.camera.size)
	_check(not view.lighting.environment.fog_enabled, "the fog is lifted from far out")
	var seen: Vector2 = view.camera.unproject_position(VoxelMapGeometry.point(preview.get("focus"), 0.7))
	var middle: Vector2 = view.get_viewport().get_visible_rect().size / 2.0
	_check(seen.distance_to(middle) < 16.0, "the camera stands back along its axis, still on the focus: %s" % seen)
	# The test map's own frame cannot pick up an edit, but a rebuild must come back whole.
	preview.call("reload_view")
	_check(not view._built, "reload lets the world go")
	await _frames(tree, 3)
	_check(view._built and view.held_frame == "night", "the view rebuilds with the hour it was held at")


## A hostile map: the bandits stand where they stand, time does not pass, no fight opens.
func _check_keeps_still(tree: SceneTree, preview: Node, session: WorldSessionController) -> void:
	_check(preview.call("show_map", &"oldpine.outdoor"), "onto 老松岭")
	await _frames(tree, 2)
	var map: WorldMapController = preview.get("map")
	var minutes: float = session.day_clock().day_minutes()
	var before: Dictionary[StringName, Vector2] = {}
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
		if body != null:
			before[npc.character_id] = body.global_position
	# Over the bandits: the unseen body stands among them and nobody notices.
	for id: StringName in before:
		preview.set("focus", before[id])
		await _frames(tree, 1)
	await tree.create_timer(0.5).timeout
	var moved: int = 0
	for id: StringName in before:
		if map.runtime_body_for_character(id).global_position != before[id]:
			moved += 1
	_check(moved == 0, "nobody moves: %d moved" % moved)
	_check(is_equal_approx(session.day_clock().day_minutes(), minutes), "world time stands still")
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "no fight opens")


func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in count:
		await tree.process_frame


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
